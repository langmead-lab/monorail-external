#!/bin/bash -l
#fill these in as per your HPC cluster setup (default is for SLURM)
#SBATCH --partition=
#SBATCH --job-name=
#SBATCH --nodes=
#SBATCH --ntasks-per-node=
#SBATCH --time=

#requires GNU parallel to run pump intra-node processes
module load gnuparallel
module load singularity

dir=./
export IMAGE=/path/to/singularity_cache/recount-rs5-1.0.6.simg
#e.g. hg38 or grcm38
export REF=hg38
#this containers the subdirs hg38 (grcm38) and hg38_unify (grcm38_unify)
export REFS_DIR=/path/to/refs
#number of pump processes to run on a single node, default is for Stampede2 Skylakes (96 cores)
export NUM_PUMP_PROCESSES=16
#number of cores per pump process
export NUM_CORES=8

#study name/accession, e.g. ERP001942
study=$1
#file with list of runs accessions to process from study
runs_file=$2
#e.g. /scratch/04620/cwilks/workshop
export WORKING_DIR=$3

for f in input output temp temp_big; do mkdir -p $WORKING_DIR/$f ; done
#set this to whatever your HPC uses for the per-job ID
JOB_ID=$SLURM_JOB_ID
#store the log for each job run
mkdir -p $WORKING_DIR/jobs_run/${JOB_ID}

echo -n "" > $WORKING_DIR/${JOB_ID}.jobs
for r in `cat $runs_file`; do
    echo "/bin/bash -x $dir/run_recount_pump.sh $IMAGE $r $study $REF $NUM_CORES $REFS_DIR > $WORKING_DIR/jobs_run/${JOB_ID}/${r}.${study}.pump.run 2>&1" >> $WORKING_DIR/${JOB_ID}.jobs
done

parallel -j $NUM_PUMP_PROCESSES < $WORKING_DIR/${JOB_ID}.jobs
