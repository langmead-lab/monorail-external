#!/usr/bin/env bash
#make sure singularity is loaded/in $PATH ahead of time
set -exo pipefail

#singularity_image_file=recount-unify_latest.sif

#e.g. recount-unify_latest.sif
singularity_image_file=$1

#hg38 or grcm38
REF=$2

#full path on host to one direcotry above where get_unify_refs.sh deposited its files
REF_DIR_HOST=$3

#full path on host to where we should actually run the unifier
WORKING_DIR_HOST=$4

#full path on host to where the output from recount-pump resides
#this needs to be writable by this script!
INPUT_DIR_HOST=$5

#list of 2 or more study_id<TAB>sample_id + any number of tab delimited optional fields
#this file MUST have a header otherwise the first row will be skipped!
SAMPLE_ID_MANIFEST_HOST=$6

#number of processes to start within container, 10-40 are reasonable depending on the system/run
NUM_CPUS=$7

export MULTI_STUDY=1
#optional, only used if you explicitly want recount-unify to build a single study
#this is usually true only when you want to skip producing recount3 formatted data
#e.g. you only want Snaptron-ready output
SINGLE_STUDY_ONLY=$8
if [[ ! -z $SINGLE_STUDY_ONLY ]]; then
    MULTI_STUDY=
fi

#optional, this is used as the compilation_id in the jx output, defaults to 0
export PROJECT_ID=$9

#compilation short name (e.g. "sra", "gtex", or "tcga", to be compatible with recount3 outputs)
#custom denotes a non-recount project
export PROJECT_SHORT_NAME='custom'

INPUT_FROM_PUMP_DIR=$WORKING_DIR_HOST/input_from_pump
mkdir -p $INPUT_FROM_PUMP_DIR

#NOTE: the following assumes the unifier is being run on the *same filesystem* as the pump
#as it makes hard links to the pump output
#make sure input data is properly organized for the Unifier
#assumes an original output format: $INPUT_DIR_HOST/sampleID_att0/sampleID!studyID!*.manifest
#we can skip this if $SKIP_FIND is set in the running environment
#../geuvadis_small_output/ERR188431_att0/ERR188431!ERP001942!hg38!sra.align.log
if [[ ! -z $MULTI_STUDY  && -z $SKIP_FIND ]]; then
    find $INPUT_DIR_HOST -name '*!*' | perl -ne 'BEGIN { $run_id=1; } $working_dir="'$INPUT_FROM_PUMP_DIR'"; chomp; $f=$_; @f=split(/\//,$f); $fm=pop(@f); $original=join("/",@f); $run_dir=pop(@f); @f2=split(/!/,$fm); $sample=shift(@f2); if(!$h{$sample}) { $h{$sample}=$run_id++; } $i=$h{$sample}; $study=shift(@f2); $study=~/(..)$/; $lo1=$1; $sample=~/(..)$/; $lo2=$1; $parent=join("/",@f); $newsub="$working_dir/$lo1/$study/$lo2/$sample"; $i++; $run_dir=~s/(_att\d+)$/_in$i$1/;  `mkdir -p $newsub/$run_dir ; ln -f $f $newsub/$run_dir/ ; touch $newsub/$run_dir.done`;'
fi

#inside container mount for REF files
export REF_DIR=/container-mounts/ref

REF_DIR_HOST=$REF_DIR_HOST/$REF"_unify"

#human
if [[ $REF == 'hg38' ]]; then
    export LIST_OF_ANNOTATIONS='G026,G029,R109,F006,ERCC,SIRV'
#mouse
else 
    if [[ $REF == 'grcm38' ]]; then
        export LIST_OF_ANNOTATIONS='M023,ERCC,SIRV'a
    else
        echo "ERROR: unrecognized organism: $REF, exiting"
        exit
    fi
fi

#generic names are used for the organism specific REF files upstream
#so just need to assign them to the ENV vars expected by the container
export ANNOTATED_JXS=$REF_DIR/annotated_junctions.tsv.gz
export EXON_COORDINATES_BED=$REF_DIR/exons.w_header.bed.gz
export EXON_REJOIN_MAPPING=$REF_DIR/disjoint2exons.bed
export GENE_REJOIN_MAPPING=$REF_DIR/disjoint2exons2genes.bed
export GENE_ANNOTATION_MAPPING=$REF_DIR/disjoint2exons2genes.rejoin_genes.bed
export REF_FASTA=$REF_DIR/recount_pump.fa
export REF_SIZES=$REF_DIR/recount_pump.chr_sizes.tsv
export EXON_BITMASKS=$REF_DIR/exon_bitmasks.tsv
export EXON_BITMASK_COORDS=$REF_DIR/exon_bitmask_coords.tsv

export INPUT_DIR=/container-mounts/input
export WORKING_DIR=/container-mounts/working
export REF_DIR=/container-mounts/ref

export RECOUNT_CPUS=$NUM_CPUS


#do some munging of the passed in sample IDs + optional metadata files
sample_id_manfest_fn=$(basename $SAMPLE_ID_MANIFEST_HOST)
#first copy the full original samples manifest into a directory visible to the container
cp $SAMPLE_ID_MANIFEST_HOST $WORKING_DIR_HOST/$sample_id_manfest_fn
export SAMPLE_ID_MANIFEST_HOST_ORIG=$WORKING_DIR_HOST/$sample_id_manfest_fn
export SAMPLE_ID_MANIFEST_HOST=$WORKING_DIR_HOST/ids.input
#now cut out just the 1st 2 columns (study, sample_id), expecting a header
cut -f 1,2 $SAMPLE_ID_MANIFEST_HOST_ORIG | tail -n+2 > $SAMPLE_ID_MANIFEST_HOST
export SAMPLE_ID_MANIFEST=$WORKING_DIR/ids.input
export SAMPLE_ID_MANIFEST_ORIG=$WORKING_DIR/$sample_id_manfest_fn

singularity exec -B $INPUT_FROM_PUMP_DIR:$INPUT_DIR -B $WORKING_DIR_HOST:$WORKING_DIR -B $REF_DIR_HOST:$REF_DIR $singularity_image_file /bin/bash -x -c "source activate recount-unify && /recount-unify/workflow.bash"

#putting all relevant final output files in one directory
mkdir -p ../run_files
mv * ../run_files/
mv ../run_files/ ./
pushd run_files
mv ids.tsv junctions.* lucene* samples.* gene_sums_per_study exon_sums_per_study junction_counts_per_study ../
popd
