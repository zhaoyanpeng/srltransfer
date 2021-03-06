from typing import Dict, List, TextIO, Optional, Any
from overrides import overrides
import torch
import torch.nn.functional as F

from allennlp.data import Vocabulary
from allennlp.models.model import Model
from allennlp.nn import InitializerApplicator, RegularizerApplicator

@Model.register("srl_vae")
class VaeSemanticRoleLabeler(Model):
    def __init__(self, vocab: Vocabulary,
                 classifier: Model,
                 autoencoder: Model,
                 alpha: float = 0.0,
                 nsampling: int = 10,
                 kl_prior: str = None,
                 reweight: bool = True,
                 straight_through: bool = True,
                 continuous_label: bool = True,
                 initializer: InitializerApplicator = InitializerApplicator(),
                 regularizer: Optional[RegularizerApplicator] = None) -> None:
        super(VaeSemanticRoleLabeler, self).__init__(vocab, regularizer)
        self.minimum_float = 1e-25

        self.classifier = classifier
        self.autoencoder = autoencoder

        self.alpha = alpha
        self.nsampling = nsampling
        self.kl_prior = kl_prior
        self.reweight = reweight
        self.straight_through = straight_through
        self.continuous_label = continuous_label

        # auto-regressive model of the decoder will need lemma weights 
        lemma_embedder = getattr(self.classifier.lemma_embedder, 'token_embedder_{}'.format('lemmas'))
        self.autoencoder.add_parameters(self.classifier.nclass,
                                        self.vocab.get_vocab_size("lemmas"),
                                        lemma_embedder.weight)

        self.tau = self.classifier.tau
        initializer(self)
    
    def forward(self,  # type: ignore
                tokens: Dict[str, torch.LongTensor],
                lemmas: Dict[str, torch.LongTensor],
                predicates: torch.LongTensor,
                predicate_indicators: torch.LongTensor,
                argument_indices: torch.LongTensor = None,
                predicate_index: torch.LongTensor = None,
                argument_mask: torch.LongTensor = None,
                srl_frames: torch.LongTensor = None,
                retrive_crossentropy: bool = False,
                supervisely_training: bool = False, # deliberately added here
                compute_mutual_infos: bool = False,
                metadata: List[Dict[str, Any]] = None) -> Dict[str, torch.Tensor]:
        pivot = 0 # either labeled or unlabeled data
        out_dict = self.classifier(tokens, predicate_indicators) 
        embedded_seqs = out_dict['embedded_seqs']
        logits, mask = out_dict['logits'], out_dict['mask']

        arg_logits, arg_labels, arg_lemmas = self.classifier.select_args(
            logits, srl_frames, lemmas['lemmas'], argument_indices) 

        if compute_mutual_infos: # stopping criterion 
            embedded_nodes = self.classifier.encode_args(
                lemmas, predicates, predicate_indicators, argument_indices, embedded_seqs) 
            return self.autoencoder.compute_mutual_info(
                argument_mask, arg_lemmas, embedded_nodes, arg_labels, edge_type_onehots=None)
        
        # basic output stuff 
        output_dict = {"logits": logits[pivot:],
                       "logits_softmax": out_dict['logits_softmax'][pivot:],
                       "mask": mask[pivot:]}
        
        if not supervisely_training: # do not need to evaluate labeled data
            self.classifier.add_outputs(pivot, mask, logits, srl_frames, output_dict, \
                arg_mask=argument_mask, arg_indices=argument_indices, metadata=metadata) 

        if retrive_crossentropy:
            output_dict['ce_loss'] = self.classifier.labeled_loss(
                argument_mask[pivot:], arg_logits[pivot:], arg_labels[pivot:])
        

        ### evaluation only
        if not self.training: 
            return output_dict 
        ### evaluation over

        
        # below we finalize all the training stuff
        embedded_nodes = self.classifier.encode_args(
            lemmas, predicates, predicate_indicators, argument_indices, embedded_seqs) 

        ### labeled halve
        if supervisely_training:
            # classification loss for the labeled data
            C = self.classifier.labeled_loss(argument_mask, arg_logits, arg_labels, average=None) 
            # used in decoding
            encoded_labels = self.classifier.embed_labels(arg_labels, labels_add_one=True)  

            L = self.autoencoder(argument_mask, arg_lemmas, embedded_nodes, arg_labels, encoded_labels)
            L = -L
            L, C = torch.mean(L), torch.mean(C) 

            output_dict['L'] = L 
            output_dict['C'] = C 
            output_dict['loss'] = L + self.alpha * C 
            output_dict['LL'] = torch.mean(self.autoencoder.likelihood)
            output_dict['KL'] = torch.mean(self.autoencoder.kldistance)
        else: ### unlabled halve
            y_logs, y_ls, lls, kls = [], [], [], []
            for _ in range(self.nsampling):
                # gumbel relaxation for unlabeled halve
                gumbel_hard, gumbel_soft, gumbel_soft_log, sampled_labels = \
                    self.classifier.gumbel_relax(argument_mask, arg_logits)
                # used in decoding
                labels_relaxed = gumbel_hard if self.straight_through else gumbel_false
                encoded_labels = self.classifier.embed_labels(None, labels_relaxed=labels_relaxed)  
                
                onehots = labels_relaxed if self.continuous_label else None
                L_y = self.autoencoder(argument_mask, arg_lemmas, embedded_nodes, sampled_labels, 
                    encoded_labels, edge_type_onehots = onehots)
                lls.append(self.autoencoder.likelihood)
                kls.append(self.autoencoder.kldistance)
                
                hard_lprobs = (gumbel_hard * gumbel_soft_log).sum(-1)
                hard_lprobs = hard_lprobs.masked_fill(argument_mask == 0, 0)
                y_log = torch.sum(hard_lprobs, -1)

                y_logs.append(y_log)
                y_ls.append(L_y)

            # average    
            y_logs = torch.stack(y_logs, 0)
            y_ls = torch.stack(y_ls, 0)
            # along sample dimension
            y_probs = torch.exp(y_logs)
            if self.reweight:
                y_probs = y_probs.softmax(0)
            y_ls = y_ls * y_probs
            
            H = torch.log(y_probs + self.minimum_float) * y_probs

            H = -H.sum(0)
            L_u = -y_ls.sum(0)
            L_u, H = torch.mean(L_u), torch.mean(H) 

            output_dict['L_u'] = L_u 
            output_dict['H'] = H 
            output_dict['loss'] = L_u + H 

            lls = torch.stack(lls, 0)
            kls = torch.stack(kls, 0)
            if (kls < 0).any():
                raise ValueError('KL should be non-negative.') 
            output_dict['KL'] = torch.mean(kls) 
            output_dict['LL'] = torch.mean(lls)

        return output_dict 

    @overrides
    def decode(self, output_dict: Dict[str, torch.Tensor]) -> Dict[str, torch.Tensor]:
        return self.classifier.decode(output_dict)

    @overrides       
    def get_metrics(self, reset: bool = False) -> Dict[str, float]:
        return self.classifier.get_metrics(reset=reset)

