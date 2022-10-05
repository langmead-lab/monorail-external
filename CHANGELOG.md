# CHANGELOG for all things Monorail

## 20221005
updated recount-unify's workflow.bash to support more than just human G026 annotation for gene sums checking via Megadepth
(was hanging at this step for non-human organisms). Only applies to non-human organism Unifier runs (should not longer stall at check step).

Unifier image now at 1.1.1

## 20220219
fixed recount-unify's rejoin collision bug causing a number of genes to have wrong sums, update is not compatible with previous versions of the Unifier. Users should re-run unifier on all pump outputs with this release!

Unifier image now at 1.1.0

## 20210408
added post-run row count checks to Unifier

## 20210315
added some support for dbGaP runs via the `docker/run_recount_unify.sh` script
