# monorail-external

This is for helping potential users of the monorail RNA-seq processing pipeline (alignment/quantification) get started running their own data through it.

Caveat emptor: both the monorail pipeline itself and this repo are a work in process, not the final product.

If you're reading this and decide to use the pipeline that's great, but you are beta testing it.

Please file issues here as you find them.

## Requirements

* Container platform (Docker or Singularity)
* Pre-downloaded (or pre-built) genome-of-choice reference indexes (e.g. HG38 or GRCM38), see below for more details
* List of SRA accessions to process or locally accessible file paths of runs to process
* Computational resources (memory, CPU, disk space)

You can specify the number of CPUs to use but the amount of memory used will be dictated by how large the STAR reference index is.
For human it's 30 GBs.  

Multiple CPUs (cores/threads) are used by the following processes run within the pipeline:

* STAR (uses all CPUs given)
* Salmon (upto 8 CPUs given)
* parallel-fastq-dump (upto 4 CPUs given)
* bamcount (upto 4 CPUs given)

Snakemake itself will parallelize the various steps in the pipeline if they can be run indepdendently and are not taking all the CPUs.


The amount of disk space will be run-dependent, but typically varies from 10's of MBs to 100's of MBs per run accession (for human/mouse).

## Overview

You need to have either docker or singularity running, I'm using singularity 2.6.0 here because it's what we have been running.

Singularity versions 3.x and up will probably work, but I haven't tested them.

An example shell script is provided in `singularity/run_monorail_container.sh`.

Both gzipped and uncompressed FASTQs are supported as well as paired/single ended runs.

We also support downloading from SRA and local files.

The example script assumes the monorail image is already downloaded/converted and is present in the working directory.
e.g. `recount-rs5-1.0.6.simg`

But this can be changed via the `SINGULARITY_MONORAIL_IMAGE` variable near the top of the example script.

Check the quay.io listing for up-to-date Monorail Docker images (which can be converted into Singularity images):

https://quay.io/repository/benlangmead/recount-rs5?tab=tags

As of 2020-10-20 version `1.0.6` is a stable release.

### Conversion from Docker to Singularity

We store versions of the monorail pipeline as Docker images in quay.io, however, they can easily be converted to Singularity images once downloaded locally:

```singularity pull docker://quay.io/benlangmead/recount-rs5:1.0.6```

will result in a Singularity image file in the current working directory:

`recount-rs5-1.0.6.simg`

NOTE: any host filesystem path mapped into a running container *must not* be a symbolic link, as the symlink will not be able to be followed within the container.

Also, you will need to set the `$RECOUNT_HOST_REF` path in the script to where ever you download/build the relevant reference indexes (see below for more details).

### SRA

All you need to provide is the run accession of the sequencing run you want to process via monorail:

Example:

`/bin/bash run_recount_pump.sh /path/to/recount-pump-singularity.simg SRR390728 SRP020237 hg38 10 /path/to/references`

The `/path/to/references` is the full path to whereever the appropriate reference getter script put them.
Note: this path should not include the final subdirectory named for the reference version e.g. `hg38` or `grcm38`.

This will startup a container, download the SRR390728 run accession (paired) from the study SRP020237 using upto 10 CPUs/cores.

### Local

You will need to provide a label/ID for the dataset (in place of "my_local_run") and the path to at least one FASTQ file.

Example:

Download the following two, tiny FASTQ files:

http://snaptron.cs.jhu.edu/data/temp/SRR390728_125_1.fastq.gz

http://snaptron.cs.jhu.edu/data/temp/SRR390728_125_2.fastq.gz

```/bin/bash run_recount_pump.sh /path/to/recount-pump-singularity.simg SRR390728 local hg38 20 /path/to/SRR390728_125_1.fastq.gz /path/to/SRR390728_125_2.fastq.gz```

This will startup a container, attempt to hardlink the fastq filepaths into a temp directory, and process them using up to 20 CPUs/cores.

Important: the script assumes that the input fastq files reside on the same filesystem as where the working directory is, this is required for the container to be able to access the files as the script *hardlinks* them for access by the container (the container can't follow symlinks).

The 2nd mates file path is optional as is the gzip compression.
The pipeline uses the `.gz` extension to figure out if gzip compression is being used or not.

### Additional Options

As of 1.0.5 there is some support for altering how the workflow is run with the following environment variables:

* KEEP_BAM=1
* KEEP_FASTQ=1
* NO_SHARED_MEM=1

An example with all three options using the test local example:

```export KEEP_BAM=1 && export KEEP_FASTQ=1 && export NO_SHARED_MEM=1 && /bin/bash run_recount_pump.sh /path/to/recount-pump-singularity.simg SRR390728 local hg38 20 /path/to/SRR390728_125_1.fastq.gz /path/to/SRR390728_125_2.fastq.gz```

This will keep the first pass alignment BAM, the original FASTQ files, and will force STAR to be run in NoSharedMemory mode with respect to it's genome index for the first pass alignment.

## Getting Reference Indexes

You will need to either download or pre-build the reference index files including the STAR, Salmon, the transcriptome, and HISAT2 indexes used in the monorail pipeline.

Reference indexes + annotations are already built/extracted for human (HG38, Gencode V26) and mouse (GRCM38, Gencode M23).

For human HG38, `cd` into the path you will use for the `$RECOUNT_REF_HOST` path in the `singularity/run_monorail_container.sh` runner script and then run this script from the root of this repo:

`get_human_ref_indexes.sh`

Similarly for mouse GRCM38, do the same as above but run:

`get_mouse_ref_indexes.sh`

For the purpose of building your own reference indexes, the versions of the 3 tools that use them are:

* STAR 2.7.3a
* Salmon 0.12.0
* HISAT2 2.1.0

For the unifier, run the `get_unify_refs.sh` script with either `hg38` or `grcm38` as the one argument.

## Layout of links to recount-pump output for recount-unifier

Due to the importance of this part, this get its own section.

The `scripts/find_done.sh` script that gets run automatically in the `recount-unifier` container *should* organize the symlinks to the original, recount-pump output directories correctly, however, it's worth checking given that the rest of the Unifier is critically sensitive to how the links are organized.

For example, if you find that you're getting blanks instead of actual integers in the `all.exon_bw_count.pasted.gz` file, it's likely a sign that the input directory hierarchy was not laid out correctly.

Assuming your top level directory for input is called `links`, the expected directory hierarchy for each sequencing run/sample is:

`links/study_loworder/study/run_loworder/run/symlink_to_recount-pump_attempt_directory_for_this_run`

e.g.:

`links/94/SRP019994/83/SRR797083/sra_human_v3_41_in26354_att2`

where `sra_human_v3_41_in26354_att2` is the symlink to the actual recount-pump generated attempt director for run `SRR797083` in study `SRP019994`.

`study_loworder` and `run_loworder` are *always* the last 2 characters of the study and run accessions/IDs respectively.

Your study and run accessions/IDs may be very different the SRA example here, but they should still work in this setup.  However, single letter studies/runs probably won't.
