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

#e.g. /path/to/monorail-external/singularity
dir=./
export IMAGE=/path/to/singularity_cache/recount-rs5-1.0.6.simg
export REF=hg38
#this containers the subdirs hg38 (grcm38) and hg38_unify (grcm38_unify)
export REFS_DIR=/path/to/refs
export NUM_PUMP_PROCESSES=16
export NUM_CORES=8

#study name/accession, e.g. ERP001942
study=$1
#file with list of runs accessions to process from study
#e.g. /home1/04620/cwilks/scratch/workshop/SRP096788.runs.txt
runs_file=$2
#e.g. /scratch/04620/cwilks/workshop
WORKING_DIR=$3

JOB_ID=$SLURM_JOB_ID
export WORKING_DIR=$WORKING_DIR/pump/${study}.${JOB_ID}
for f in input output temp temp_big; do mkdir -p $WORKING_DIR/$f ; done

#store the log for each job run
mkdir -p $WORKING_DIR/jobs_run/${JOB_ID}

echo -n "" > $WORKING_DIR/pump.jobs
for r in `cat $runs_file`; do
    echo "LD_PRELOAD=/work/00410/huang/share/patch/myopen.so /bin/bash -x $dir/run_recount_pump.sh $IMAGE $r $study $REF $NUM_CORES $REFS_DIR > $WORKING_DIR/${r}.${study}.pump.run 2>&1" >> $WORKING_DIR/pump.jobs
done

#ignore failures to get done as many as possible (e.g. don't want to lose the node if only one sub run/sample fails)
parallel -j $NUM_PUMP_PROCESSES < $WORKING_DIR/pump.jobs || true
