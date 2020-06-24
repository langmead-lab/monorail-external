#make sure singularity is loaded/in $PATH
umask 0077

#e.g. recount-rs5-1.0.2.simg or recount-rs5-1.0.2.sif
singularity_image_file=$1

#run accession (sra, e.g. SRR390728), or internal ID (local), 
#this can be anything as long as its consistently used to identify the particular sample
run_acc=$2
#"local" or the SRA study accession (e.g. SRP020237) if downloading from SRA
study=$3
#"hg38" (human) or "grcm38" (mouse)
ref_name=$4
#number of processes to start within container, 4-16 are reasonable depending on the system/run
num_cpus=$5
#full file path to first read mates (optional)
fp1=$6
#full file path to second read mates (optional)
fp2=$7

export RECOUNT_JOB_ID=${run_acc}_in0_att0

#assumes these directories are subdirs in current working directory
export RECOUNT_INPUT_HOST=input/${run_acc}_att0
#RECOUNT_OUTPUT_HOST stores the final set of files and some of the intermediate files while the process is running.
export RECOUNT_OUTPUT_HOST=output/${run_acc}_att0
#RECOUNT_TEMP_HOST stores the initial download of sequence files, typically this should be on a fast filesystem as it's the most IO intensive from our experience (use either a performance oriented distributed FS like Lustre or GPFS, or a ramdisk).
export RECOUNT_TEMP_HOST=temp/${run_acc}_att0
#may need to change this to real path to the reference indexes (this directory should contain the ref_name passed in e.g. "hg38")
export RECOUNT_REF_HOST=refs

mkdir -p $RECOUNT_TEMP_HOST/input
mkdir -p $RECOUNT_INPUT_HOST
mkdir -p $RECOUNT_OUTPUT_HOST

export RECOUNT_TEMP=/container-mounts/recount/temp 
#expects at least $fp1 to be passed in
if [[ $study == 'local' ]]; then
    #hard link the input FASTQ(s) into input directory
    #THIS ASSUMES input files are *on the same filesystem* as the input directory!
    #this is required for accessing the files in the container
    ln $fp1 $RECOUNT_TEMP_HOST/input/
    fp_string="$RECOUNT_TEMP/input/$fp1"
    if [[ ! -z $fp2 ]]; then
        ln $fp2 $RECOUNT_TEMP_HOST/input/
        fp_string="$RECOUNT_TEMP/input/$fp1;$RECOUNT_TEMP/input/$fp2"
    fi
    #only one run accession per run of this file
    #If you try to list multiple items in a single accessions.txt file you'll get a mixed run which will fail.
    echo -n "${run_acc},LOCAL_STUDY,${ref_name},local,$fp_string" > ${RECOUNT_INPUT_HOST}/accession.txt
else
    echo -n "${run_acc},${study},${ref_name},sra,${run_acc}" > ${RECOUNT_INPUT_HOST}/accession.txt
fi

export RECOUNT_INPUT=/container-mounts/recount/input
export RECOUNT_OUTPUT=/container-mounts/recount/output
export RECOUNT_REF=/container-mounts/recount/ref

export RECOUNT_CPUS=$num_cpus

singularity exec -B $RECOUNT_REF_HOST:$RECOUNT_REF -B $RECOUNT_TEMP_HOST:$RECOUNT_TEMP -B $RECOUNT_INPUT_HOST:$RECOUNT_INPUT -B $RECOUNT_OUTPUT_HOST:$RECOUNT_OUTPUT $singularity_image_file /bin/bash -x -c "source activate recount && /startup.sh && /workflow.bash"
