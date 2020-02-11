#!/usr/bin/env bash
mkdir -p grcm38
pushd grcm38
for f in star_idx salmon_index unmapped_hisat2_idx gtf fasta; do
    wget https://recount-ref.s3.amazonaws.com/grcm38/${f}.tar.gz
    tar -zxvf ${f}.tar.gz
done
popd
