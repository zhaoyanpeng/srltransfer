{
    "vocabulary": {
        "tokens_to_add": {"lemmas": ["NULL_LEMMA"]}
    },
    "dataset_reader":{
        "type":"conll2009",
        "lazy": true,
        "maximum_length": 80,
        "valid_srl_labels": ["A0", "A1", "A2", "A3", "A4", "A5", "AM-ADV", "AM-CAU", "AM-DIR", 
                             "AM-EXT", "AM-LOC", "AM-MNR", "AM-NEG", "AM-PRD", "AM-TMP"],
        "lemma_file":  "/disk/scratch1/s1847450/data/conll09/all.moved.arg.vocab",
        "lemma_use_firstk": 5,
        "feature_labels": ["pos", "dep"],
        "move_preposition_head": true,
        "max_num_argument": 7,
        "instance_type": "srl_graph",
        "token_indexers": {
            "elmo": {
                "type": "elmo_characters"
            }
        }
    },

    "nytimes_reader": {
        "type":"conllx_unlabeled",
        "lazy": true,
        "maximum_length": 80,
        "valid_srl_labels": ["A0", "A1", "A2", "A3", "A4", "A5", "AM-ADV", "AM-CAU", "AM-DIR", 
                             "AM-EXT", "AM-LOC", "AM-MNR", "AM-NEG", "AM-PRD", "AM-TMP"],
        "lemma_file":  "/disk/scratch1/s1847450/data/conll09/all.moved.arg.vocab",
        "lemma_use_firstk": 5,
        "feature_labels": ["pos", "dep"],
        "move_preposition_head": false,
        "max_num_argument": 7,
        "min_valid_lemmas": 0.5,
        "instance_type": "srl_graph",
        "token_indexers": {
            "elmo": {
                "type": "elmo_characters"
            }
        }
    },

    "reader_mode": "srl_nyt",
    "validation_ontraining_data": false,

    "add_unlabeled_noun": true,
    //"train_dx_firstk": 5000000,

    //"train_dx_path": "/disk/scratch1/s1847450/data/conll09/morph.word/v20.0/train.verb",
    //"test_data_path": "/disk/scratch1/s1847450/data/conll09/morph.word/v20.0/test.verb",
    //"validation_data_path": "/disk/scratch1/s1847450/data/conll09/morph.word/v20.0/devel.verb",

    //"train_dx_context_path":  "/disk/scratch1/s1847450/data/nytimes/morph.word/v100.0/nytimes.verb.ctx",
    //"train_dx_appendix_path": "/disk/scratch1/s1847450/data/nytimes/morph.word/v100.0/nytimes.verb.sel",

    "train_dx_path": "/disk/scratch1/s1847450/data/conll09/separated/train.verb",
    "test_data_path": "/disk/scratch1/s1847450/data/conll09/separated/test.verb",
    "validation_data_path": "/disk/scratch1/s1847450/data/conll09/separated/devel.verb",

    //"train_dx_context_path":  "/disk/scratch1/s1847450/data/nytimes/morph.word/v100.0/nytimes.verb.ctx",
    //"train_dx_appendix_path": "/disk/scratch1/s1847450/data/nytimes/morph.word/v100.0/nytimes.verb.sel",
    "train_dx_context_path":  "/disk/scratch1/s1847450/data/nytimes/morph.only/nytimes.45.only",
    "train_dx_appendix_path": "/disk/scratch1/s1847450/data/nytimes/morph.only/nytimes.45.verb.only",

    "vocab_src_path": "/disk/scratch1/s1847450/data/conll09/separated/vocab.src",
    "datasets_for_vocab_creation": ["vocab"],

    "model": {
        "autoencoder": {
            "type": "srl_lemma_ae",
            "decoder": {
                "type": "srl_basic_decoder",
                "input_dim": 200, // predicate + label,
                "b_use_bilinear": true,
                "dense_layer_dims": [200],
                "dropout": 0.1,
            },
        },
        "classifier": {
            "type": "srl_vae_classifier",
            "lemma_embedder": {
                "token_embedders": {
                    "lemmas": {
                        "type": "embedding",
                        "embedding_dim": 100,
                        "pretrained_file": "/disk/scratch1/s1847450/data/lemmata/en.lemma.100.20.vec.morph",
                        "vocab_namespace": "lemmas",
                        "trainable": false 
                    }
                }
            },
            "label_embedder": {
                "embedding_dim": 100,
                "vocab_namespace": "srl_tags",
                "trainable": true,
                "sparse": false 
            },
            "predt_embedder": {
                "embedding_dim": 100,
                "pretrained_file": "/disk/scratch1/s1847450/data/lemmata/en.lemma.100.20.vec.morph",
                "vocab_namespace": "predicates",
                "trainable": true, 
                "sparse": false 
            },
            "tau": 1.0,
            "tunable_tau": false,
            "psign_dim": 100,
            "seq_projection_dim": null,
            "token_dropout": 0.1,
            "lemma_dropout": 0.1,
            "label_dropout": 0.1,
            "predt_dropout": 0.5,
            "suppress_nonarg": true,
        },

        "type": "srl_vae_lhood",
    },
    "iterator": {
        "type": "bucket",
        "sorting_keys": [["tokens", "num_tokens"]],
        "batch_size": 1024 
    },
    "trainer": {
        "type": "sri_vae_lemma",
        "num_epochs": 1000,
        "grad_norm": 5.0,
        "grad_clipping": 1.0,
        "patience": 200,
        "shuffle": true,
        "num_serialized_models_to_keep": 3,
        "validation_metric": "+f1-measure-overall",
        //"validation_metric": "-loss",
        "cuda_device": 1,
        "optimizer": {
            "type": "adadelta",
            "rho": 0.95
        },
    }
}
