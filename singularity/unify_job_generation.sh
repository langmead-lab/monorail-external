#!/usr/bin/env bash

dir=$(dirname $0)
#study name/accession, e.g. ERP001942
study=$1
#e.g. /scratch/04620/cwilks/workshop/pump/<study>.<slurm_job_id>/output
export PUMP_OUTPUT_DIR=$2
#e.g. /scratch/04620/cwilks/workshop
export WORKING_DIR=$3

cat $dir/tacc_unify.sh | sed 's#^WORKING_DIR=..$#WORKING_DIR='$WORKING_DIR'#' | sed 's#^STUDY=..$#STUDY='$study'#' | sed 's#^dir=..$#dir='$dir'#' | sed 's#^PUMP_OUTPUT_DIR=..$#PUMP_OUTPUT_DIR='$PUMP_OUTPUT_DIR'#' > tacc_unify.${study}.sh
