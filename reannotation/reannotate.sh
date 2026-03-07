#!/usr/bin/env bash
#REQUIRED: wget, GNU parallel and a reasonably modern version of Python3 (e.g. >=3.7) NEED to be installed and in the $PATH
#reAnnotation for samples which have been run through Monorail (pump at least, need to have bigwig files)
#but need additional genes/transcripts/exons computed in a compatible manner to what's in Monorail output and/or recount3.
#defaults to # of processors (cores + hyptherthreads typically) as number of concurrent processes to run
set -exo pipefail
dir=$(dirname $0)
#set FORCE_FULL_RERUN=1 to force a full rerun of the script, recreating everything, otherwise
#script will try to skip over steps where the output files already exist (to save time on re-runs)

#change the following as needed
#assumes GNU sort
export SORT=sort
#set to do byte-by-byte string comparisons (i.e. c-style), can be faster for string sorts
export LC_ALL=C
export PYTHON=python3
export MEGADEPTH=./megadepth120
#used for sorting, set this to a larger filesystem if /tmp is really small
if [[ -z $TEMPDIR ]]; then
    export TEMPDIR=/tmp
fi

#e.g. gencode.v39.chr_patch_hapl_scaff.annotation.gtf or gencode.v39.chr_patch_hapl_scaff.annotation.gtf.gz
new_annotation_gtfF=$1
#format (tab-delimited): sample_id<TAB>/path/to/BigWigfile.bw
list_of_bigwig_pathsF=$2
#e.g. 4
number_of_concurrent_processes=$3
if [[ -z $number_of_concurrent_processes ]]; then
    #a little hacky, could change in future to something more portable
    number_of_concurrent_processes=$(fgrep "processor" /proc/cpuinfo | wc -l)
fi

## New Annotation Preparation
new_annotation_bedF=$(echo "$new_annotation_gtfF" | sed 's#.gz$##' | sed 's#.gtf$#.bed#')
if [[ -n $FORCE_FULL_RERUN || ! -e $new_annotation_bedF ]]; then
    $PYTHON $dir/exons_from_GTF2monorail_input_BED_file.py $new_annotation_gtfF $new_annotation_bedF
    #sort twice: 1) to remove exact duplicate rows (can be produced by the previous script)
    #and 2) sort BED file by chromosome, start, and end coordinates to allow Megadepth to run potentially faster
    #don't use more than 50% of main memory
    $SORT --buffer-size '50%' --batch-size=${number_of_concurrent_processes} -T$TEMPDIR --parallel=$number_of_concurrent_processes -t$'\t' -u $new_annotation_bedF > ${new_annotation_bedF}.unique
    $SORT --buffer-size '50%' --batch-size=${number_of_concurrent_processes} -T$TEMPDIR --parallel=$number_of_concurrent_processes -t$'\t' -k1,1 -k2,2n -k3,3n ${new_annotation_bedF}.unique > ${new_annotation_bedF}
fi

## Computing Sums for the New Annotation
if [[ -n $FORCE_FULL_RERUN || ! -e $MEGADEPTH ]]; then
    wget https://github.com/ChristopherWilks/megadepth/releases/download/1.2.0/megadepth -O $MEGADEPTH
    chmod a+x $MEGADEPTH
fi
#generate list of Megadepth jobs to be run in parallel (or at least partially depending on # of samples):
if [[ -n $FORCE_FULL_RERUN || ! -e megadepth.jobs || ! -e resum_by_gene_and_exon.jobs ]]; then
    cat $list_of_bigwig_pathsF | perl -ne 'BEGIN { open(OUT,">resum_by_gene_and_exon.jobs"); } chomp; $f=$_; ($sample_id,$fp)=split(/\t/,$f,-1); print "'$MEGADEPTH' $fp --annotation '$new_annotation_bedF' --sums-only > $sample_id.exon_segment.sums 2>$sample_id.exon_segment.sums.mdrun\n"; print OUT "'$PYTHON' '$dir'/sum_by_gene_and_exon.py '$new_annotation_bedF' $sample_id.exon_segment.sums --gene-out $sample_id.gene_sums.tsv --exon-out $sample_id.exon_sums.tsv --integers-only\n"; END { close(OUT); }' > megadepth.jobs
fi

#can be 0 if not run yet:
set +eo pipefail
num_sums_files_found=$(ls -l *.sums | tr -s " " $'\t' | cut -f 1,5,9 | fgrep -v $'\t0\t' | wc -l)
set -eo pipefail
num_sums_files_expected=$(cat megadepth.jobs | wc -l)
if [[ -n $FORCE_FULL_RERUN || $num_sums_files_found -ne $num_sums_files_expected ]]; then
    parallel -j${number_of_concurrent_processes} < ./megadepth.jobs > megadepth.jobs.run${number_of_concurrent_processes} 2>&1
fi

## Aggregate and further Sum Coverage
set +eo pipefail
num_gene_sums_files_produced=$(ls -l *.gene_sums.tsv | tr -s " " $'\t' | cut -f 1,5,9 | fgrep -v $'\t0\t' | wc -l)
num_exon_sums_files_produced=$(ls -l *.exon_sums.tsv | tr -s " " $'\t' | cut -f 1,5,9 | fgrep -v $'\t0\t' | wc -l)
set -eo pipefail
num_sums_files_expected=$(cat resum_by_gene_and_exon.jobs | wc -l)
if [[ -n $FORCE_FULL_RERUN || $num_gene_sums_files_produced -ne $num_sums_files_expected || $num_gene_sums_files_produced -ne $num_sums_files_expected ]]; then
    parallel -j${number_of_concurrent_processes} < ./resum_by_gene_and_exon.jobs > resum_by_gene_and_exon.jobs.run${number_of_concurrent_processes} 2>&1
fi

## Final Aggregation into Single Gene and Exon Coverate Sum Matrices
#TODO...
echo "Now aggregate the gene and exon sums into two separate matrices (2 .tsv files)"
