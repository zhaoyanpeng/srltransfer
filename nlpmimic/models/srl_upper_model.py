from typing import Dict, List, TextIO, Optional, Any

from overrides import overrides
import torch
from torch.nn.modules import Linear, Dropout
import torch.nn.functional as F

from allennlp.common.checks import check_dimensions_match
from allennlp.data import Vocabulary
from allennlp.modules import Seq2SeqEncoder, Seq2VecEncoder, TimeDistributed, TextFieldEmbedder
from allennlp.modules.token_embedders import Embedding
from allennlp.models.model import Model
from allennlp.nn import InitializerApplicator, RegularizerApplicator
from allennlp.nn.util import get_text_field_mask, sequence_cross_entropy_with_logits
from allennlp.nn.util import get_lengths_from_binary_sequence_mask, viterbi_decode

from nlpmimic.training.metrics import DependencyBasedF1Measure


@Model.register("srl_upper")
class UpperSemanticRoleLabeler(Model):
    def __init__(self, vocab: Vocabulary,
                 classifier: Model, 
                 initializer: InitializerApplicator = InitializerApplicator(),
                 regularizer: Optional[RegularizerApplicator] = None) -> None:
        super(UpperSemanticRoleLabeler, self).__init__(vocab, regularizer)
        self.minimum_float = 1e-25

        self.classifier = classifier

        self.tau = self.classifier.tau

        initializer(self)
    
    def forward(self,  # type: ignore
                tokens: Dict[str, torch.LongTensor],
                lemmas: Dict[str, torch.LongTensor],
                predicate_indicators: torch.LongTensor,
                predicates: torch.LongTensor,
                argument_indices: torch.LongTensor = None,
                predicate_index: torch.LongTensor = None,
                argument_mask: torch.LongTensor = None,
                srl_frames: torch.LongTensor = None,
                reconstruction_loss: bool = False,
                metadata: List[Dict[str, Any]] = None) -> Dict[str, torch.Tensor]:
        """ purely supervised learning of semantic role labels.
        """
        # shared by labeled and unlabeled halves
        batch_size = predicate_indicators.size(0) // 2 
        pivot = batch_size if False else 0
        
        out_dict = self.classifier(tokens, predicate_indicators) 
        embedded_seqs = out_dict['embedded_seqs']
        logits, mask = out_dict['logits'], out_dict['mask']

        arg_logits, arg_labels, arg_lemmas = self.classifier.select_args(
            logits, srl_frames, lemmas['lemmas'], argument_indices) 
        
        # basic output stuff 
        output_dict = {"logits": logits[pivot:],
                       "logits_softmax": out_dict['logits_softmax'][pivot:],
                       "mask": mask[pivot:]}
        
        self.classifier.add_outputs(pivot, mask, logits, srl_frames, output_dict, \
            arg_mask=argument_mask, arg_indices=argument_indices, metadata=metadata) 
        if reconstruction_loss:
            output_dict['rec_loss'] = self.classifier.labeled_loss(
                argument_mask[pivot:], arg_logits[pivot:], arg_labels[pivot:])
        

        ### evaluation only
        if not self.training: 
            return output_dict 
        ### evaluation over

        # classification loss for the labeled data
        C = self.classifier.labeled_loss(
            argument_mask, arg_logits, arg_labels, average=None) 
        
        # batch dimension
        output_dict['loss'] = torch.mean(C) 
        return output_dict 

    @overrides
    def decode(self, output_dict: Dict[str, torch.Tensor]) -> Dict[str, torch.Tensor]:
        return self.classifier.decode(output_dict)

    @overrides       
    def get_metrics(self, reset: bool = False) -> Dict[str, float]:
        return self.classifier.get_metrics(reset=reset)

