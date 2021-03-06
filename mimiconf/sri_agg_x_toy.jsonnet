{
    "vocabulary": {
        "tokens_to_add": {"lemmas": ["NULL_LEMMA"]}
    },
    "dataset_reader":{
        "type":"conll2009",
        "feature_labels": ["pos", "dep"],
        "move_preposition_head": true,
        "max_num_argument": 7,
        "instance_type": "srl_graph"
    },
  
    "reader_mode": "srl_gan",
    "dis_param_name": ["classifier.seq_encoder",
                       "classifier.label_projection_layer",
                       "classifier.psign_embedder",
                       "classifier.token_embedder", 
                       "classifier.lemma_embedder", 
                       "classifier.predt_embedder", 
                       "autoencoder.encoder",
                       "autoencoder.sampler"],

    "train_dx_path": "/disk/scratch1/s1847450/data/conll09/bitgan/trial.bit",
    "train_dy_path": "/disk/scratch1/s1847450/data/conll09/bitgan/verb.bit",
    "validation_data_path": "/disk/scratch1/s1847450/data/conll09/bitgan/trial.bit",

    "model": {
        "autoencoder": {
            "type": "srl_graph_ae",
            "kl_alpha": 0.5,
            "nsample": 2,
            "b_use_z": true,
            "b_ctx_predicate": true,
            "encoder": {
                "type": "srl_graph_encoder",
                "input_dim": 2, 
                "layer_timesteps": [2, 2, 2, 2],
                "residual_connection_layers": {"2": [0], "3": [0, 1]},
                "dense_layer_dims": [2],
                "node_msg_dropout": 0.3,
                "residual_dropout": 0.3,
                "aggregation_type": "a",
                "combined_vectors": false,
            },
            "decoder": {
                "type": "srl_lstms_decoder",
                //"type": "srl_basic_decoder",
                "input_dim": 6, //  3 + 2 + 2
                "hidden_dim": 3, 
                "always_use_predt": true,
                //"dense_layer_dims": [5, 5],
            },
            "sampler": {
                "type": "gaussian",
                "input_dim": 2, 
                "output_dim": 3,  
            },
        },

        "classifier": {
            "type": "srl_vae_classifier",
            "token_embedder": {
                "token_embedders": {
                    "tokens": {
                        "type": "embedding",
                        "embedding_dim": 2,
                        "vocab_namespace": "tokens",
                        "trainable": true 
                    }
                }
            },
            "lemma_embedder": {
                "token_embedders": {
                    "lemmas": {
                        "type": "embedding",
                        "embedding_dim": 2,
                        "vocab_namespace": "lemmas",
                        "trainable": false 
                    }
                }
            },
            "label_embedder": {
                "embedding_dim": 2,
                "vocab_namespace": "srl_tags",
                "trainable": true,
                "sparse": false 
            },
            "predt_embedder": {
                "embedding_dim": 2,
                "vocab_namespace": "predicates",
                "trainable": true, 
                "sparse": false 
            },
            "seq_encoder": {
                "type": "stacked_bidirectional_lstm",
                "input_size": 4,
                "hidden_size": 2,
                "num_layers": 1,
                "recurrent_dropout_probability": 0.0,
                "use_highway": true
            },
            "tau": 1,
            "tunable_tau": false,
            "psign_dim": 2,
            "seq_projection_dim": null,
            "embedding_dropout": 0.0,
            "suppress_nonarg": true,
        },

        "type": "srl_vae",
        "alpha": 0.5,
        "nsampling": 2,
        "reweight": true, 
        "straight_through": true,
        "continuous_label": false,
        "kl_prior": "null",

    },
    "iterator": {
        "type": "bucket",
        "sorting_keys": [["tokens", "num_tokens"]],
        "batch_size": 5 
    },
    "trainer": {
        "type": "sri_aggressive",
        "num_epochs": 3,
        "grad_clipping": 1.0,
        "patience": 20,
        "shuffle": false,
        "validation_metric": "+f1-measure-overall",
        "cuda_device": -1,
        "dis_max_nbatch": 2,
        "dis_min_nbatch": 2,
        "aggressive_vae": true,
        "gen_loss_scalar": 1.0,
        "kld_loss_scalar": 0.5,
        "kld_update_rate": 0.05,
        "kld_update_unit": 5,
        "bpr_loss_scalar": 1.0,
        "sort_by_length": false,
        "shuffle_arguments": true,
        "optimizer": {
            "type": "adadelta",
            "rho": 0.95
        },
        "optimizer_dis": {
          "type": "adadelta",
          "rho": 0.95
        }
    }
}
