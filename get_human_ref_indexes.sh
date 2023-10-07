#!/usr/bin/env bash
mkdir -p hg38
pushd hg38
for f in star_idx salmon_index unmapped_hisat2_idx gtf fasta; do
    wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/hg38/${f}.tar.gz
    tar -zxvf ${f}.tar.gz
done
popd
