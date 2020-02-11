# monorail-external
examples to run monorail externally

NOTE: any host filesystem path mapped into the container *must* not be a symbolic link, as the symlink will not be able to be followed within the container.

## Requirements

* Container platform (Docker or Singularity)
* Pre-downloaded genome-of-choicee reference indexes (e.g. HG38 or GRCM38)
* Computational resources (memory, CPU, disk space)
* List of SRA accessions to process or locally accessible file paths

## Overview

You need to have either docker or singularity running, I'm using singularity 2.6.0 here because it's what we have been running.

Significantly newer versions of Singularity may not work (e.g. 3.x and up).

The following is provided in an example shell script (e.g. bash):

```###start of shell script
#make sure singularity is available in the path
export RECOUNT_JOB_ID=<descriptive_short_job_id_string>
export RECOUNT_INPUT=/path/to/input/job_attempt_dir/
export RECOUNT_OUTPUT= /path/to/output/job_attempt_dir/
export RECOUNT_TEMP= /path/to/temp/job_attempt_dir/
export RECOUNT_CPUS=# of parallel threads used in the job (e.g. in the alignment and pseudoalignment portions primarily)
export RECOUNT_REF=/path/to/genome_reference_files
singularity exec /path/to/singularity_image/recount-rs5-1.0.2.simg /bin/bash -c "source activate recount && /startup.sh && /workflow.bash"
###end of shell script
```

within the input directory you should have a single file, accessions.txt with the following line (this is for local FASTQs only):

```<run_accession>,<study_accession>,<reference_short_name>,local,</path/to/mates1.fastq>;<path/to/mates2.fastq>```

e.g for a single end, uncompressed read set:

```ERR3379340,TEST_STUDY,hg38,local,/tmp/ERR3379340.fastq```

for a paired end, compressed read set:

```ERR3379340,TEST_STUDY,hg38,local,/tmp/ERR3379340_1.fastq.gz;/tmp/ERR3379340_2.fastq.gz```

(note the ";" separating the mates files in the 2nd line)

Both gzipped and non-compressed FASTQs are supported. 

We also support downloading from SRA and the GDC (TCGA), but those follow a different format.

RECOUNT_OUTPUT stores the final set of files and some of the intermediate files while the process is running.

RECOUNT_TEMP stores the initial download of sequence files, typically this should be on a fast filesystem as it's the most IO intensive from our experience (use either a performance oriented distributed FS like Lustre or GPFS, or a ramdisk).

One somewhat complicating factor is that you'll need to run the pipeline
with a separate job attempt directory (one each for INPUT, OUTPUT, and TEMP) for each job/readset.

If you try to list multiple items in a single accessions.txt file you'll get a mixed run which will fail.

## Getting Reference Indexes

RECOUNT_REF is the path to the reference files including the STAR, Salmon, transcriptome, and HISAT2 indexes used in the monorail pipeline.

It should have a subdirectory named exactly the same as the reference short name used in the input file (accessions.txt), in this case "hg38" (for human).

The list of human indexes to populate this hg38 directory are here (these should be decompressed within the RECOUNT_REF/hg38/ directory):
* https://recount-ref.s3.amazonaws.com/hg38/star_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/salmon_index.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/unmapped_hisat2_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/gtf.tar.gz
* https://recount-ref.s3.amazonaws.com/hg38/fasta.tar.gz

This list for mouse are here:

* https://recount-ref.s3.amazonaws.com/grcm38/star_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/salmon_index.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/unmapped_hisat2_idx.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/gtf.tar.gz
* https://recount-ref.s3.amazonaws.com/grcm38/fasta.tar.gz
