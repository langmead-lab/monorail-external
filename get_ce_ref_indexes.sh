#!/usr/bin/env bash
mkdir -p ce10
pushd ce10
for f in star_idx salmon_index unmapped_hisat2_idx gtf fasta; do
    wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/ce10/${f}.tar.gz
    tar -zxvf ${f}.tar.gz
done
popd
