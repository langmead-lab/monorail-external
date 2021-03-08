#!/usr/bin/env bash
set -exo pipefail
##IMPORTANT: $pump_input_dir and $unifier_input_dir HAVE to be on the SAME filesystem (hardlinks) for this to work!!
pump_input_dir=$1
unifier_input_dir=$2
#optional, path to file w/ list of runs to include (white listing, for subsetting studies/projects)
#format: list of run accessions (e.g. SRR001234)
whitelisted_runs=$3

rm -f stream2
mkfifo stream2

if [[ -n $whitelisted_runs ]]; then
    rm -f stream1
    mkfifo stream1
    cat $whitelisted_runs | sed 's/$/!/' > stream1 &
    find $pump_input_dir -name "*" -type f | fgrep -v done | fgrep -v "std.out" | fgrep -v "stats.json" | fgrep -f stream1 > stream2 &
else
    find $pump_input_dir -name "*" -type f | fgrep -v done | fgrep -v "std.out" | fgrep -v "stats.json" > stream2 &
fi

cat stream2 | perl -ne 'chomp; $f=$_; @f=split(/\//,$f); $f2=pop(@f); @f2=split(/!/,$f2); $run=shift(@f2); $study=shift(@f2); $study=~/(..)$/; $lo1=$1; $run=~/(..)$/; $lo2=$1; $ff="'$unifier_input_dir'/$lo1/$study/$lo2/$run/$study"."_0_att0"; `mkdir -p $ff`; `ln -f $f $ff/$f2`;'
rm -f stream1
rm -f stream2
#absolutely need the ".done" files
find $unifier_input_dir -name "*att0" | perl -ne 'chomp; $f=$_; `touch $f.done`;'
