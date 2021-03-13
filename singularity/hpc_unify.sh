#!/bin/bash -l
#fill these in as per your HPC cluster setup (default is for SLURM)
#SBATCH --partition=
#SBATCH --job-name=
#SBATCH --nodes=
#SBATCH --ntasks-per-node=
#SBATCH --time=
#runner for recount-unify (post-pump Monorail) on HPC
sed -exo pipefail

#requires GNU parallel to run pump intra-node processes
module load gnuparallel
module load singularity

dir=$(dirname $0)
export IMAGE=/path/to/singularity_cache/recount-unify-1.0.4.simg
#e.g. hg38 or grcm38
export REF=hg38
#this containers the subdirs hg38 (grcm38) and hg38_unify (grcm38_unify)
export REFS_DIR=/path/to/refs
#number of CPU cores to use for the entire job (usually only 1 for the unifier)
export NUM_CORES=40

#default project name (sra, tcga, gtex, etc...) and compilation ID (for rail_id generation)
export PROJECT_SHORT_NAME_AND_ID='sra:101'

#e.g. /scratch/04620/cwilks/workshop
working_dir=$1

mkdir -p $working_dir/unify

pump_study_output_path=$working_dir/output
pump_study_samples_file=$working_dir/samples.tsv
#find $pump_study_output_path  -name "*.manifest" | perl -ne 'BEGIN { print "study\tsample\n"; } chomp; $f=$_; @f=split(/\//,$f); $fname=pop(@f); @f=split(/!/,$fname); $run=shift(@f); $study=shift(@f); print "$study\t$run\n";' > $pump_study_samples_file
echo "study	sample" > $pump_study_samples_file
find $pump_study_output_path  -name "*.manifest" | sed 's/^.+\/([^\/!])+!([^!]+)!.+$/$1\t$2/'

num_samples=$(tail n+2 $pump_study_samples_file | wc -l)
echo "number of samples in pump output for $working_dir/output: $num_samples"

/bin/bash $dir/run_recount_unify.sh $IMAGE $REF $REFS_DIR $working_dir/unify $pump_study_output_path $pump_study_samples_file $NUM_CORES $REFS_DIR > $working_dir/${run}.${study}.unify.run 2>&1
