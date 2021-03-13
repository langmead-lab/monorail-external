#!/usr/bin/env bash

dir=$(dirname $0)
#study name/accession, e.g. ERP001942
study=$1
#file with list of runs accessions to process from study
runs_file=$2
#e.g. /scratch/04620/cwilks/workshop
export WORKING_DIR=$3

for f in input output temp temp_big; do mkdir -p $WORKING_DIR/$f ; done

cat $dir/tacc_pump.sh | sed 's#study=..#study='$study'#' | sed 's#runs_file=..#runs_file='$runs_file'#' | sed 's#WORKING_DIR=..#WORKING_DIR='$WORKING_DIR'#' | sed 's#^dir=..#dir='$dir'#' > tacc_pump.${study}.sh
