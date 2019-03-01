fold=srl_verb_lyu
model_path=/disk/scratch1/s1847450/model/$fold/model.tar.gz
#context_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.45.lemma.small
#appendix_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.arg.verb.small
#output_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.tag.verb.small
context_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.45.lemma.part2
appendix_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.pre.verb.part2
output_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.tag.verb.part2.idx
indxes_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.pre.verb.cnt.part2
log_file=/disk/scratch1/s1847450/data/nyt_annotated/xchen/nytimes.tag.verb.part2.idx.log
bsize=300
cuda_id=3
predictor=srl_naive

library="nlpmimic"

nohup python -m nlpmimic.run srler_gan --batch-size $bsize --cuda-device $cuda_id \
    --output-file $output_file --indxes-file $indxes_file $model_path $context_file $appendix_file \
    --predictor $predictor --include-package $library > $log_file 2>&1 &
