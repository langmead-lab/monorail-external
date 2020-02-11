# monorail-external
examples to run monorail externally

NOTE: any host filesystem path mapped into the container *must not* be a symbolic link, as the symlink will not be able to be followed within the container.

## Requirements

* Container platform (Docker or Singularity)
* Pre-downloaded genome-of-choicee reference indexes (e.g. HG38 or GRCM38)
* List of SRA accessions to process or locally accessible file paths
* Computational resources (memory, CPU, disk space)

You can specify the number of CPUs to use but the amount of memory used will be dictated by how large the STAR reference index is.
For human it's 30 GBs.  

Multiple CPUs (cores/threads) are used by the following processes run within the pipeline:

* STAR (uses all CPUs given)
* Salmon (upto 8 CPUs given)
* parallel-fastq-dump (upto 4 CPUs given)
* bamcount (upto 4 CPUs given)


Snakemake itself will parallelize the various steps in the pipeline if they can be run indepdendently and are not taking all the CPUs (e.g. not STAR, but other single CPU steps).


The amount of disk space will be run dependent but typically varies from 10's of MBs to 100's of MBs per run accession.

## Overview

You need to have either docker or singularity running, I'm using singularity 2.6.0 here because it's what we have been running.

Significantly newer versions of Singularity may not work (e.g. 3.x and up).

An example shell script is provided in `run_monorail_container.sh`.

Both gzipped and uncompressed FASTQs are supported as well as paired/single ended runs.

We also support downloading from SRA and local files.

### SRA

All you need to provide is the run accession of the sequencing run you want to process via monorail:

Example:

`/bin/bash -x run_monorail_container_local.sh SRR390728 SRP020237 10`

This will startup a container, download the SRR390728 run accession (paired) from the study SRP020237 using upto 10 CPUs/cores.

### Local

You will need to provide a label/ID for the dataset (in place of "my_local_run") and the path to at least one FASTQ file.

Example:

```/bin/bash -x run_monorail_container_local.sh my_local_run local 20 /path/to/first_read_mates.fastq.gz /path/to/second_read_mates.fastq.gz```

This will startup a container, attempt to hardlink the fastq filepaths into a temp directory and process them using upto 20 CPUs/cores.  The 2nd mates file path is optional as is the gzip compression (the pipeline uses the extension to figure out if gzip compression is being used or not).

## Getting Reference Indexes

You will need to either download or pre-build the reference index files including the STAR, Salmon, the transcriptome, and HISAT2 indexes used in the monorail pipeline.

It should have a subdirectory named exactly the same as the reference short name used in the input file (accessions.txt), in this case "hg38" (for human).

The list of human indexes to populate this hg38 directory are here (these should be decompressed within the `$RECOUNT_REF_HOST/hg38` directory):
* https://recount-ref.s3.amazonaws.com/hg38/star_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/salmon_index.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/unmapped_hisat2_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/gtf.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/fasta.tar.gz

This list for mouse are here (these should be decompressed within the `$RECOUNT_REF_HOST/grcm38` directory):

* https://recount-ref.s3.amazonaws.com/grcm38/star_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/salmon_index.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/unmapped_hisat2_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/gtf.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/fasta.tar.gz
