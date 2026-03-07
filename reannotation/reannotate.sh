#!/usr/bin/env bash
#REQUIRED: GNU parallel and a reasonably modern version of Python3 (e.g. >=3.7) NEED to be installed and in the $PATH!!
#reAnnotation for samples which have been run through Monorail (pump at least, need to have bigwig files)
#but need additional genes/transcripts/exons computed in a compatible manner to what's in Monorail output and/or recount3.
set -exo pipefail
dir=$(dirname $0)
#change as needed
#prefer GNU time if installed
export TIME=/usr/bin/time
export PYTHON=python3
export MEGADEPTH=./megadepth120
export PARALLEL=parallel

#e.g. gencode.v39.chr_patch_hapl_scaff.annotation.gtf or gencode.v39.chr_patch_hapl_scaff.annotation.gtf.gz
new_annotation_gtfF=$1
#format (tab-delimited): sample_id<TAB>/path/to/BigWigfile.bw
list_of_bigwig_pathsF=$2
#e.g. 4
number_of_concurrent_processes=$3
if [[ -z $number_of_concurrent_processes ]]; then
    number_of_concurrent_processes=$(fgrep "processor" /proc/cpuinfo | wc -l)
fi

## New Annotation Preparation
new_annotation_bedF=$(echo "$new_annotation_gtfF" | sed 's#.gz$##' | sed 's#.gtf$#.bed#')
python3 $dir/exons_from_GTF2monorail_input_BED_file.py $new_annotation_gtfF $new_annotation_bedF

## Computing Sums for the New Annotation
if [[ ! -e $MEGADEPTH ]]; then
    curl https://github.com/ChristopherWilks/megadepth/releases/download/1.2.0/megadepth > $MEGADEPTH
    chmod a+x $MEGADEPTH
fi
#generate list of Megadepth jobs to be run in parallel (or at least partially depending on # of samples):
cat $list_of_bigwig_pathsF | perl -ne 'BEGIN { open(OUT,"resum_by_gene_and_exon.jobs"); } "chomp; $f=$_; ($sample_id,$fp)=split(/\t/,$f,-1); print "'$TIME' '$MEGADEPTH' $fp --annotation '$new_annotation_bedF' --sums-only > $sample_id.exon_segment.sums 2>$sample_id.exon_segment.sums.mdrun\n"; print OUT "python3 '$dir'/sum_by_gene_and_exon.py '$new_annotation_bedF' --gene-out $sample_id.gene_sums.tsv --exon-out $sample_id.exon_sums.tsv --integers-only\n"; END { close(OUT); }' > megadepth.jobs

$TIME $PARALLEL -j$number_of_concurrent_processes < megadepth.jobs > megadepth.jobs.run${number_of_concurrent_processes} 2>&1

## Aggregate and further Sum Coverage
$TIME $PARALLEL -j$number_of_concurrent_processes < resum_by_gene_and_exon.jobs > resum_by_gene_and_exon.jobs.run${number_of_concurrent_processes} 2>&1

## Final Aggregation into Single Gene and Exon Coverate Sum Matrices
#TODO...
