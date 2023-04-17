#!/usr/bin/env bash
set -x
dir=$(dirname $0)
export LC_ALL=C
#assumes current working directory is the unifier output of the study we want to test

#path to previous unifier run on same study
path=$1

#cwd=$(pwd)
for f in `find . -name '*.gz' | fgrep -v "run_files" | fgrep -v "genotypes"`; do
    if [[ $f == *"gene_sums"* || $f == *"exon_sums"* ]]; then
        #diff <(pcat $path/$f | tail -n+3) <(pcat $f | tail -n+3) > ${f}.diff
        Rscript $dir/compare_unifier_sums.R --f1 $path/$f --f2 $f
        continue
    fi
    if [[ $f == *"metadata"* ]]; then
        diff <(pcat $path/$f | sort) <(pcat $f | sort) > ${f}.diff
        continue
    fi
    diff <(pcat $path/$f) <(pcat $f) > ${f}.diff
done
find . -name "*.diff" -exec ls -l {} \;
