#make sure singularity is loaded/in $PATH
umask 0077

#singularity_image_file=recount-unify_latest.sif

#e.g. recount-unify_latest.sif
singularity_image_file=$1

#hg38 or grcm38
REF=$2

#full path on host to where get_human_unify_REFs.sh deposited it's files
REF_DIR_HOST=$3

#full path on host to where we should actually run the unifier
WORKING_DIR_HOST=$4

#full path on host to where the output from recount-pump resides
INPUT_DIR_HOST=$5

#list of 2 or more study_id<TAB>sample_id
SAMPLE_ID_MANIFEST_HOST=$6

#number of processes to start within container, 10-40 are reasonable depending on the system/run
NUM_CPUS=$7

#only used if you explicitly want recount-unify to build multiple studies
#this is usually true only for specific cases (e.g. recount)
MULTIPLE_STUDIES=$8

#optional, this is used as the compilation_id in the jx output, defaults to 0
export PROJECT_ID=$9

mkdir -p $WORKING_DIR_HOST

#inside container mount for REF files
export REF_DIR=/container-mounts/ref

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

export MULTI_STUDY=$MULTIPLE_STUDIES

sample_id_manfest_fn=$(basename $SAMPLE_ID_MANIFEST_HOST)
export SAMPLE_ID_MANIFEST=$WORKING_DIR/$sample_id_manfest_fn
cp $SAMPLE_ID_MANIFEST_HOST $WORKING_DIR_HOST/$sample_id_manfest_fn

singularity exec -B $INPUT_DIR_HOST:$INPUT_DIR -B $WORKING_DIR_HOST:$WORKING_DIR -B $REF_DIR_HOST:$REF_DIR $singularity_image_file /bin/bash -x -c "source activate recount-unify && /recount-unify/workflow.bash"
