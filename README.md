# monorail-external
examples to run monorail externally

NOTE: any host filesystem path mapped into the container *must* not be a symbolic link, as the symlink will not be able to be followed within the container.

## Requirements

* Container platform (Docker or Singularity)
* Pre-downloaded genome-of-choicee reference indexes (e.g. HG38 or GRCM38)
* List of SRA accessions to process or locally accessible file paths
* Computational resources (memory, CPU, disk space)
You can specify the number of CPUs to use but the amount of memory used will be dictated by how large the STAR reference index is.
For human it's 30 GBs.  The amount of disk space will be run dependent but typically varies from 10's of MBs to 100's of MBs per run accession.

## Overview

You need to have either docker or singularity running, I'm using singularity 2.6.0 here because it's what we have been running.

Significantly newer versions of Singularity may not work (e.g. 3.x and up).

An example shell script is provided in `run_monorail_container.sh`.

Both gzipped and non-compressed FASTQs are supported as well as paired/single ended runs.

We also support downloading from SRA and the GDC (TCGA), but those follow a different format.

## Getting Reference Indexes

You will need to either download or pre-build the reference index files including the STAR, Salmon, the transcriptome, and HISAT2 indexes used in the monorail pipeline.

It should have a subdirectory named exactly the same as the reference short name used in the input file (accessions.txt), in this case "hg38" (for human).

The list of human indexes to populate this hg38 directory are here (these should be decompressed within the RECOUNT_REF/hg38/ directory):
* https://recount-ref.s3.amazonaws.com/hg38/star_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/salmon_index.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/unmapped_hisat2_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/gtf.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/fasta.tar.gz

This list for mouse are here, "grcm38":

* https://recount-ref.s3.amazonaws.com/grcm38/star_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/salmon_index.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/unmapped_hisat2_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/gtf.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/fasta.tar.gz
