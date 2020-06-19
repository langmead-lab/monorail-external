#make sure singularity is loaded/in $PATH
umask 0077

SINGULARITY_MONORAIL_IMAGE=recount-unify_latest.sif

#hg38 or grcm38
ref=$1

#full path on host to where get_human_unify_refs.sh deposited it's files
REF_DIR_HOST=$2

#full path on host to where we should actually run the unifier
WORKING_DIR_HOST=$3

#full path on host to where the output from recount-pump resides
INPUT_DIR_HOST=$4

#list of 2 or more study_id<TAB>sample_id
SAMPLE_ID_MANIFEST_HOST=$5

#number of processes to start within container, 10-40 are reasonable depending on the system/run
num_cpus=$6

#optional, this is used as the compilation_id in the jx output, defaults to 0
export PROJECT_ID=$7

mkdir -p $WORKING_DIR_HOST

#inside container mount for ref files
export REF_DIR=/container-mounts/ref

#human
if [[ $ref == 'hg38' ]]; then
    export LIST_OF_ANNOTATIONS='G026,G029,R109,ERCC,SIRV,F006'
#mouse
else 
    if [[ $ref == 'grcm38' ]]; then
        export LIST_OF_ANNOTATIONS='M023,ERCC,SIRV'a
    else
        echo "ERROR: unrecognized organism: $org, exiting"
        exit
    fi
fi

#generic names are used for the organism specific ref files upstream
#so just need to assign them to the ENV vars expected by the container
export ANNOTATED_JXS=$REF_DIR/annotated_junctions.tsv.gz
export EXON_COORDINATES_BED=$REF_DIR/exons.w_header.bed.gz
export EXON_REJOIN_MAPPING=$REF_DIR/disjoint2exons.bed
export GENE_REJOIN_MAPPING=$REF_DIR/disjoint2exons2genes.bed
export GENE_ANNOTATION_MAPPING=$REF_DIR/disjoint2exons2genes.rejoin_genes.bed
export REF_FASTA=$REF_DIR/recount_pump.fa
export REF_SIZES=$REF_DIR/recount_pump.chr_sizes.tsv

export INPUT_DIR=/container-mounts/input
export WORKING_DIR=/container-mounts/working
export REF_DIR=/container-mounts/ref

export RECOUNT_CPUS=$num_cpus

sample_id_manfest_fn=$(basename $SAMPLE_ID_MANIFEST_HOST)
export SAMPLE_ID_MANIFEST=$WORKING_DIR/$sample_id_manfest_fn
cp $SAMPLE_ID_MANIFEST_HOST $WORKING_DIR_HOST/$sample_id_manfest_fn

singularity exec -B $INPUT_DIR_HOST:$INPUT_DIR -B $WORKING_DIR_HOST:$WORKING_DIR -B $REF_DIR_HOST:$REF_DIR $SINGULARITY_MONORAIL_IMAGE /bin/bash -x -c "source activate recount-unify && /recount-unify/workflow.bash"
