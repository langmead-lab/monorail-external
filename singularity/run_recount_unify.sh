#make sure singularity is loaded/in $PATH
umask 0077

SINGULARITY_MONORAIL_IMAGE=recount-unify.simg

#hg38 or grcm38
ref=$1

#full path on host to where get_human_unify_refs.sh deposited it's files
REF_DIR_HOST=$2

#full path on host to where we should actually run the unifier
WORKING_DIR_HOST=$3

#number of processes to start within container, 10-40 are reasonable depending on the system/run
num_cpus=$4

#optional, this is used as the compilation_id in the jx output, defaults to 0
PROJECT_ID=$5


#inside container mount for ref files
REF_DIR=/container-mounts/ref

#human
if [[ $ref == 'hg38' ]]; then
    LIST_OF_ANNOTATIONS='G026,G029,R109,ERCC,SIRV,F006'
#mouse
else if [[ $ref == 'grcm38' ]]; then
    LIST_OF_ANNOTATIONS='M023,ERCC,SIRV'
else
    echo "ERROR: unrecognized organism: $org, exiting"
    exit
fi

#generic names are used for the organism specific ref files upstream
#so just need to assign them to the ENV vars expected by the container
ANNOTATED_JXS=$REF_DIR/annotated_junctions.tsv.gz
EXON_COORDINATES_BED=$REF_DIR/exons.w_header.bed.gz
EXON_REJOIN_MAPPING=$REF_DIR/disjoint2exons.bed
GENE_REJOIN_MAPPING=$REF_DIR/disjoint2exons2genes.bed
GENE_ANNOTATION_MAPPING=$REF_DIR/disjoint2exons2genes.rejoin_genes.bed
REF_FASTA=$REF_DIR/recount_pump.fa
REF_SIZES=$REF_DIR/recount_pump.chr_sizes.tsv

export INPUT_DIR=/container-mounts/input
export WORKING_DIR=/container-mounts/working
export REF_DIR=/container-mounts/ref

export RECOUNT_CPUS=$num_cpus

singularity exec -B $INPUT_DIR_HOST:$INPUT_DIR -B $WORKING_DIR_HOST:$WORKING_DIR -B $REF_DIR_HOST:$REF_DIR $SINGULARITY_MONORAIL_IMAGE /bin/bash -x -c "source activate recount-unify && /workflow.bash"
