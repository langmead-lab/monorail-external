#make sure singularity/docker are in PATH
umask 0077
export PERL5LIB=

#if running a sample from dbGaP (hosted by SRA), you must
#use >=recount-pump:1.1.1 and you'll need to provide the path to the key file (*.ngc)
#via the NGC environmental variable, e.g.: 
#export NGC=/container-mounts/recount/ref/.ncbi/prj_<study_id>.ngc
#where /container-mounts/recount/ref is the *within* container path to the same path as $ref_path below 

#this script will automatically attempt to determine whether Singularity or Docker should be run
#based on whether or not the argument to $container_image image below has a ".simg" or a ".sif" suffix
#if not, it will run Docker

#e.g. if Singularity, then something like recount-rs5-1.0.2.simg or recount-rs5-1.0.2.sif
#OR if Docker, the name of the image in the local repo or the full name:version
container_image=$1

#run accession (sra, e.g. SRR390728), or internal ID (local), 
#this can be anything as long as its consistently used to identify the particular sample
run_acc=$2
#"local", "copy" (still local), or the SRA study accession (e.g. SRP020237) if downloading from SRA
study=$3
#"hg38" (human) or "grcm38" (mouse)
ref_name=$4
#number of processes to start within container, 4-16 are reasonable depending on the system/run
num_cpus=$5
#full path to location of downloaded refs
#this directory should contain either "hg38" or "grcm38" subdirectories (or both)
ref_path=$6

#full file path to first read mates (optional)
fp1=$7
#full file path to second read mates (optional)
fp2=$8

#if running "local" (or "copy"), then use this to pass the real study name (optional)
actual_study=$9

#if overriding pump Snakemake parameters (see recount-pump/workflow/rs5/workflow.bash comments)
#set CONFIGFILE=/container/reachable/path/to/config.json
#if using a different version of sratoolkit than what's in the base recount-pump container
#you will need to set the VDB_CONFIG to a container reachable path for this sratoolkit's version of user-settings.mkfg is located

#change this if you want a different root path for all the outputs
#(Docker needs absolute paths to be volume bound in the container)
if [[ -z $WORKING_DIR ]]; then
    root=`pwd`
else
    root=$WORKING_DIR
fi

export RECOUNT_JOB_ID=${run_acc}_in0_att0

#assumes these directories are subdirs in current working directory
export RECOUNT_INPUT_HOST=$root/input/${run_acc}_att0
#RECOUNT_OUTPUT_HOST stores the final set of files and some of the intermediate files while the process is running.
export RECOUNT_OUTPUT_HOST=$root/output/${run_acc}_att0
#RECOUNT_TEMP_HOST stores the initial download of sequence files, typically this should be on a fast filesystem as it's the most IO intensive from our experience (use either a performance oriented distributed FS like Lustre or GPFS, or a ramdisk).
export RECOUNT_TEMP_HOST=$root/temp/${run_acc}_att0
#the *full* path to the reference indexes on the host (this directory should contain the ref_name passed in as a subdir e.g. "hg38")
export RECOUNT_REF_HOST=$ref_path

mkdir -p $RECOUNT_TEMP_HOST/input
mkdir -p $RECOUNT_INPUT_HOST
mkdir -p $RECOUNT_OUTPUT_HOST

if [[ -z $RECOUNT_TEMP ]]; then
    export RECOUNT_TEMP=/container-mounts/recount/temp 
fi

#expects at least $fp1 to be passed in
if [[ $study == 'local' || $study == 'copy' ]]; then
    if [[ -z "$actual_study" ]]; then
        actual_study="LOCAL_STUDY"
    fi

    if [[ $study == 'local' ]]; then
        #hard link the input FASTQ(s) into input directory
        #THIS ASSUMES input files are *on the same filesystem* as the input directory!
        #this is required for accessing the files in the container
        ln -f $fp1 $RECOUNT_TEMP_HOST/input/
    else
        cp $fp1 $RECOUNT_TEMP_HOST/input/
    fi
    fp1_fn=$(basename $fp1)
    fp_string="$RECOUNT_TEMP/input/$fp1_fn"
    if [[ ! -z $fp2 ]]; then
        if [[ $study == 'local' ]]; then
            ln -f $fp2 $RECOUNT_TEMP_HOST/input/
        else
            cp $fp2 $RECOUNT_TEMP_HOST/input/
        fi
        fp2_fn=$(basename $fp2)
        fp_string="$RECOUNT_TEMP/input/$fp1_fn;$RECOUNT_TEMP/input/$fp2_fn"
    fi
    #only one run accession per run of this file
    #If you try to list multiple items in a single accessions.txt file you'll get a mixed run which will fail.
    echo -n "${run_acc},${actual_study},${ref_name},local,$fp_string" > ${RECOUNT_INPUT_HOST}/accession.txt
else
    echo -n "${run_acc},${study},${ref_name},sra,${run_acc}" > ${RECOUNT_INPUT_HOST}/accession.txt
fi

export RECOUNT_INPUT=/container-mounts/recount/input
export RECOUNT_OUTPUT=/container-mounts/recount/output
export RECOUNT_REF=/container-mounts/recount/ref

export RECOUNT_CPUS=$num_cpus

export RECOUNT_TEMP_BIG_HOST=$root/temp_big/${run_acc}_att0
mkdir -p $RECOUNT_TEMP_BIG_HOST
if [[ -z $RECOUNT_TEMP_BIG ]]; then
    export RECOUNT_TEMP_BIG=/container-mounts/recount/temp_big
fi

use_singularity=$(perl -e 'print "1\n" if("'$container_image'"=~/(\.sif$)|(\.simg$)/);')
if [[ -z $CONFIGFILE ]]; then
    CONFIGFILE=""
fi
if [[ -z $use_singularity ]]; then
    echo "running Docker"
    if [[ -n $DOCKER_USER ]]; then
        DOCKER_USER="--user $DOCKER_USER"
    fi
    if [[ -n $NGC ]]; then
        extra="-e NGC $extra"
    fi
    docker run $DOCKER_USER --rm -e VDB_CONFIG -e RECOUNT_INPUT -e RECOUNT_OUTPUT -e RECOUNT_REF -e RECOUNT_TEMP -e RECOUNT_TEMP_BIG -e RECOUNT_CPUS -e KEEP_BAM -e KEEP_FASTQ -e KEEP_UNMAPPED_FASTQ -e NO_SHARED_MEM -e CONFIGFILE -v $RECOUNT_REF_HOST:$RECOUNT_REF -v $RECOUNT_TEMP_BIG_HOST:$RECOUNT_TEMP_BIG -v $RECOUNT_TEMP_HOST:$RECOUNT_TEMP -v $RECOUNT_INPUT_HOST:$RECOUNT_INPUT -v $RECOUNT_OUTPUT_HOST:$RECOUNT_OUTPUT $extra --name recount-pump${run_acc} $container_image
else
    echo "running Singularity"
    singularity exec -B $RECOUNT_REF_HOST:$RECOUNT_REF -B $RECOUNT_TEMP_BIG_HOST:$RECOUNT_TEMP_BIG -B $RECOUNT_TEMP_HOST:$RECOUNT_TEMP -B $RECOUNT_INPUT_HOST:$RECOUNT_INPUT -B $RECOUNT_OUTPUT_HOST:$RECOUNT_OUTPUT $extra $container_image /bin/bash -x -c "source activate recount && /startup.sh && /workflow.bash"
fi
