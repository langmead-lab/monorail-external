# CHANGELOG for all things Monorail

# 20221012
updated recount-pump `download.sh` (again) to use 1) sratoolkit 3.0.0 *for downloading via prefetch* to fix issues with dbGaP in 2.11.2

Outputs are still backwards compatible with previous Pump runs, so no need to re-run Pump runs from before this.

Pump image now at 1.1.1

## 20221011
updated recount-pump `download.sh` to use 1) sratoolkit 2.11.2 *for downloading via prefetch* to fix issues with 2.9.1 and the cloud 2) support limited download-from-S3 *from within AWS* (e.g. on an EC2 instance, download method is `s3` instead of e.g. `local`).  Also, the main Snakemake configuration file can be overridden from the command line by setting `CONFIGFILE=/container/visible/path/to/monorail_config.json`.  This can be used to modify the `download_exe` setting to a user-developed script to support other download methods, e.g. `{"download_exe":"/container/visible/path/to/my_download.sh"}`.

Outputs are still backwards compatible with previous Pump runs, so no need to re-run Pump runs from before this.

Pump image now at 1.1.0

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
