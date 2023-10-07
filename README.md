# monorail-external

For a record of recent changes, please see the [CHANGELOG](https://github.com/langmead-lab/monorail-external/blob/master/CHANGELOG.md)

For convenience, the latest stable versions of the images are:

* Pump: `1.1.3` (as of 2023-06-03) https://quay.io/broadsword/recount-pump?tab=tags
* Unify: `1.1.1` (as of 2022-10-05) https://quay.io/repository/broadsword/recount-unify?tab=tags

We *strongly* suggest all users update their Unify image to 1.1.0 (or later) due to the rejoin gene collision bug fixed on 2022-02-19.
Also, any studies unified with Unifier images from before that date should be re-unified with the updated image (SHA256 2a1b0cfa005a or later).
Please see:
https://github.com/langmead-lab/monorail-external/tree/master/fixes#rejoin-gene-collision-fix-2022-02-19

If you do use the Unifier as of 1.1.0, please ensure you have all additional reference-related files as well, as these were expanded with that release:
https://github.com/langmead-lab/monorail-external/commit/646c59124d546da63cbb73356273bb174b2a63ea

The full source for recount (both pump and unify) is now public:

https://github.com/langmead-lab/recount-pump

https://github.com/langmead-lab/recount-unify

If you find Monorail and/or recount3 useful, please cite this paper:

Wilks, C., Zheng, S.C., Chen, F.Y. et al. recount3: summaries and queries for large-scale RNA-seq expression and splicing. Genome Biol 22, 323 (2021). https://doi.org/10.1186/s13059-021-02533-6

While we don't control (or specifically support) the following, users may find it useful:

David McGaughey (@davemcg) has graciously made public both [notes/example](https://github.com/langmead-lab/monorail-external/issues/10) and a wrapper Snakemake [script](https://github.com/davemcg/Snakerail) to run monorail, which works around some existing issues with the current implementation.  

## Summary

This is for helping potential users of the Monorail RNA-seq processing pipeline (alignment/quantification) get started running their own data through it.

Caveat emptor: both the Monorail pipeline itself and this repo are a work in process, not the final product.

If you're reading this and decide to use the pipeline that's great, but you are beta testing it.

Please file issues here as you find them.

Monorail is split into 2 parts:

* recount-pump
* recount-unify

`recount` comes from the fact that Monorail is the way that the data in `recount3+` is refreshed.

However, Monorail also creates data for https://github.com/ChristopherWilks/snaptron

## Requirements

* Container platform (Singularity)
* Pre-downloaded (or pre-built) genome-of-choice reference indexes (e.g. HG38 or GRCM38), see next section of the README for more details
* List of SRA accessions to process or locally accessible file paths of runs to process
* Computational resources (memory, CPU, disk space)

You can specify the number of CPUs to use but the amount of memory used will be dictated by how large the STAR reference index is.
For human it's *30 GBs of useable RAM*.  

Multiple CPUs (cores/threads) are used by the following processes run within the pipeline:

* STAR (uses all CPUs given)
* Salmon (upto 8 CPUs given)
* parallel-fastq-dump (upto 4 CPUs given)
* bamcount (upto 4 CPUs given)

Snakemake itself will parallelize the various steps in the pipeline if they can be run indepdendently and are not taking all the CPUs.

The amount of disk space will be run-dependent, but typically varies from 10's of MBs to 100's of MBs per *run accession* (for human/mouse).

## Getting Reference Indexes

You will need to either download or pre-build the reference index files including the STAR, Salmon, the transcriptome, and HISAT2 indexes used in the Monorail pipeline.

Reference indexes + annotations are already built/extracted for human (HG38, Gencode V26) and mouse (GRCM38, Gencode M23).

For human hg38, `cd` into the path you will use for the `$RECOUNT_REF_HOST` path in the `singularity/run_recount_pump.sh` runner script and then run this script from the root of this repo:

`get_human_ref_indexes.sh`

Similarly for mouse GRCM38, do the same as above but run:

`get_mouse_ref_indexes.sh`

For the purpose of building your own reference indexes, the versions of the 3 tools that use them in recount-pump are:

* STAR 2.7.3a
* Salmon 0.12.0
* HISAT2 2.1.0

For the unifier, run the `get_unify_refs.sh` script with either `hg38` or `grcm38` as the one argument.

## Pump (per-sample alignment stage)

You need to have Singularity running, I'll be using singularity 2.6.0 here because it's what we have been running.

Singularity versions 3.x and up will probably work, but I haven't tested them extensively.

We 2 modes of input: 

* downloading a sequence run from SRA
* local FASTQ files

For local runs, both gzipped and uncompressed FASTQs are supported as well as paired/single ended runs.

The example script below assumes the recount-pump Singularity image is already downloaded/converted and is present in the working directory.
e.g. `recount-rs5-1.0.6.simg`

Check the quay.io listing for up-to-date Monorail Docker images (which can be converted into Singularity images):

https://quay.io/repository/benlangmead/recount-rs5?tab=tags

As of 2020-10-20 version `1.0.6` is a stable release.

### Conversion from Docker to Singularity

We store versions of the monorail pipeline as Docker images in quay.io, however, they can easily be converted to Singularity images once downloaded locally:

```singularity pull docker://quay.io/benlangmead/recount-rs5:1.0.6```

will result in a Singularity image file in the current working directory:

`recount-rs5-1.0.6.simg`

If using the Docker version of the `recount-pump` image, supply the docker URI+version in the pump commands below instead of the path to the singularity file, e.g. `quay.io/benlangmead/recount-rs5:1.0.6` instead of `/path/to/recount-pump-singularity.simg`.

NOTE: any host filesystem path mapped into a running container *must not* be a symbolic link, as the symlink will not be able to be followed within the container.

Also, you will need to set the `$RECOUNT_HOST_REF` path in the script to where ever you download/build the relevant reference indexes (see below for more details).


### SRA input

All you need to provide is the run accession of the sequencing run you want to process via monorail:

Example:

`/bin/bash run_recount_pump.sh /path/to/recount-pump-singularity.simg SRR390728 SRP020237 hg38 10 /path/to/references`

The `/path/to/references` is the full path to whereever the appropriate reference getter script put them.
Note: this path should not include the final subdirectory named for the reference version e.g. `hg38` or `grcm38`.

This will startup a container, download the SRR390728 run accession (paired) from the study SRP020237 using upto 10 CPUs/cores.


### Local input

You will need to provide a label/ID for the dataset (in place of "my_local_run") and the path to at least one FASTQ file.

Example:

Download the following two, tiny FASTQ files:

http://snaptron.cs.jhu.edu/data/temp/SRR390728_1.fastq.gz

http://snaptron.cs.jhu.edu/data/temp/SRR390728_2.fastq.gz

```
/bin/bash run_recount_pump.sh /path/to/recount-pump-singularity.simg SRR390728 local hg38 20 /path/to/references /path/to/SRR390728_1.fastq.gz /path/to/SRR390728_2.fastq.gz SRP020237
```

This will startup a container, attempt to hardlink the fastq filepaths into a temp directory, and process them using up to 20 CPUs/cores.

Important: the script assumes that the input fastq files reside on the same filesystem as where the working directory is, this is required for the container to be able to access the files as the script *hardlinks* them for access by the container (the container can't follow symlinks).

The 2nd mates file path is optional as is the gzip compression.
The pipeline uses the `.gz` extension to figure out if gzip compression is being used or not.

The final parameter is the *actual* study name, `SRP020237`, since we're overloading the normal study position with `local`.

### Additional Options

As of 1.0.5 there is some support for altering how the workflow is run with the following environment variables:

* KEEP_BAM=1
* KEEP_FASTQ=1
* NO_SHARED_MEM=1

An example with all three options using the test local example:

```
export KEEP_BAM=1 && export KEEP_FASTQ=1 && export NO_SHARED_MEM=1 && /bin/bash run_recount_pump.sh /path/to/recount-pump-singularity.simg SRR390728 local hg38 20 /path/to/references /path/to/SRR390728_1.fastq.gz /path/to/SRR390728_2.fastq.gz
```

This will keep the first pass alignment BAM, the original FASTQ files, and will force STAR to be run in NoSharedMemory mode with respect to it's genome index for the first pass alignment.


## Unifier (aggregation over per-sample pump outputs)

Run `get_unify_refs.sh <organism_ref_shortname>` to get the appropriate reference related files for the unifier (this is in addition to the reference related files for the pump downloaded above), where `<organism_ref_shortname>` is currently either `hg38` for human or `grcm38` for mouse.

WARNING: the current version of the unifier reference related files *only* work with the recount-unifier image version 1.0.4, earlier versions of the image or the reference related files *will not work* with newer versions of the other.

Follow the same process as for recount-pump (above) to convert to singularity.

The unifier aggregates the following cross sample outputs:

* gene sums
* exon sums
* junction split read counts

The Unifier assumes the directory/file layout and naming of default runs of recount-pump, where a single sample's output is stored like this under one main parent directory:

`<parent_directory>/<sampleID>_att0/`

e.g.

`pump_output/sample1_att0/`
`pump_output/sample2_att0/`
`pump_output/sample3_att0/`
....

The `/path/to/pump/output` argument below references the path to the `<parent_directory>` above.  This path *must* be on the same filesystem as the unifier's working directory (`path/to/working/directory` below).  Also, it must *not* be a symbolic link itself. This is because the unifier script will use `find` (w/o `-L`) to hardlink the pump's output files into the expected directry hierarchy it needs to run.  That said, the  `/path/to/pump/output` must not be a `parent` directory to the unifier's working directory, or else the unifier will exhibit undefined behavior.  The two directories must be on the same filesystem but they should be kept separate as far as neither should be a subdirectory of the other.

An example of the two might be:

* `/data/recount-pump/output/study1` where the output from recount pump run on "study1" is stored as defined above
* `/data/recount-unify/study1_working` where the unifier is run for "study1"


To run the Unifier:

```
/bin/bash run_recount_unify.sh /path/to/recount-unifier-singularity.simg <reference_version> /path/to/references /path/to/working/directory /path/to/pump/output /path/to/sample_metadata.tsv <number_cores> <project_short_name:project_id>
```

`/path/to/references` here may be the same path as used in recount-pump, but it must contain an additional directory: `<reference_version>_unify`.

where `reference_version` is either `hg38` or `grcm38`.

`sample_metadata.tsv` *must* have a header line and at least the following first 2 columns in exactly this order (it can have as many additional columns as desired):

```
study_id<TAB>sample_id...
<study_id1>TAB<sample_id1>...
...
```

`<study_id>` and `<sample_id>` can be anything that is unique within the set, however, `<study_id>` must match what the study was when `recount-pump` was run, or the filenames of the output files from pump must be changed to reflect the different `<study_id>`, e.g.

pump file prefix: `'ERR248710!ERP002416!grcm38!sra'`

either run with `<study_id>` set to `ERP002416` or change all the filenames to have the prefix `'ERR248710!<new_study_id>!grcm38!sra'` for all affected samples.

Finally, you (now) must pass in a project short name (string) and a project_id (integer) to be compatible with recount3.
The project short name should be unique for your organization or 'sra' if you're pulling from the Sequence Read Archive.
The project_id should also be unique among projects in your organization. The project ID should also be between 100 and 250 (exclusive).

Example:

`sra:101`

If you only want to run one of the 2 steps in the unifier (either gene+exon sums OR junction counts), you can skip the other operation:

```export SKIP_JUNCTIONS=1 && /bin/bash run_recount_unify.sh ...```
to run only gene+exon sums

or

```export SKIP_SUMS=1 && /bin/bash run_recount_unify.sh ...```
to run only junction counts

### Unifier outputs

#### Multi study mode (default)

recount3 compatible sums/counts matrix output directories are in the `/path/to/working/directory` under:

* `gene_sums_per_study` (content goes into `gene_sums` in recount3 layout section below)
* `exon_sums_per_study` (content goes into `exon_sums` in recount3 layout section below)
* `junction_counts_per_study` (content goes into `junctions` in recount3 layout section below)

The first 2 are run together and then the junctions are aggregated.

The outputs are further organized by:
`study_loworder/study/`

where `study_loworder` is the last 2 characters of the study ID, e.g. if study is ERP001942, then the output for gene sums will be saved under:
`gene_sums_per_study/42/ERP001942`

Additionally, the Unifier outputs Snaptron ready junction databases and indices:

* `junctions.bgz`
* `junctions.bgz.tbi`
* `junctions.sqlite`

`rail_id`s are also created for every sample_id submitted in the `/path/to/sample_metadata.tsv` file and stored in:

`samples.tsv`

Further, the Unifier will generate Lucene metadata indices based on the `samples.tsv` file for Snaptron:

* `samples.fields.tsv`
* `lucene_full_standard`
* `lucene_full_ws`
* `lucene_indexed_numeric_types.tsv`

Taken together, the above junctions block gzipped files & indices along with the Lucene indices is enough for a minimally viable Snaptron instance.

Intermediate and log files for the Unifier run can be found in `run_files`

### Loading custom Unifier runs into recount3

recount3 http://bioconductor.org/packages/release/bioc/html/recount3.html requires a specific directory/path/folder layout to be present, either on 1) local filesystem from which the R package can load from or a 2) URL using HTTP (not HTTPS).

We suggest installing the latest version of the recount3 package direct from github (in R, requires Bioconductor):
`remotes::install_github("LieberInstitute/recount3")`

An example layout that loads into recount3 is rooted here (DO NOT USE ANY DATA AT THIS URL FOR REAL ANALYSES):
http://snaptron.cs.jhu.edu/data/temp/recount3test

You should browse the subdirectories of that URL as an example of how to layout your own custom recount3 data directory hierarchy.

To load that test custom recount3 root URL (but it could be either URL or local directory) in R after installing the recount3 package:

```
library(recount3)
recount3_cache_rm()
options(recount3_url = "http://snaptron.cs.jhu.edu/data/temp/recount3test")
hp<-available_projects()
rse_gene = create_rse(hp[hp$project == 'ERP001942',])
```

You will see warnings about the following metadata files being missing (they'll be errors if on an earlier version of recount3):
```
Warning messages:
1: The 'url' <http://snaptron.cs.jhu.edu/data/temp/recount3test/human/data_sources/sra/metadata/42/ERP001942/sra.recount_seq_qc.ERP001942.MD.gz> does not exist or is not available.
2: The 'url' <http://snaptron.cs.jhu.edu/data/temp/recount3test/human/data_sources/sra/metadata/42/ERP001942/sra.recount_pred.ERP001942.MD.gz> does not exist or is not available.
```

This is expected and will happen with your own custom studies as well.  While these files were generated for recount3, they were never part of Monorail proper (i.e. not an automated part). You should still be able to successfully load your custom data into recount3.

The `gene_sums`, `exon_sums`, and `junctions` directories can be populated by the output of the Unifier (see the layout above) using the naming as output by the unifier, expcept in the case of the junctions files where the case of `.all.` and `.unique.` needs to be changed to all upper case for recount3 to work with them (this will be fixed shortly).

The `base_sums` directory can be populated by renamed `*.all.bw` files in the *pump* output, one per sample (the Unifier doesn't do anything with these files).

To populate the `annotation` directories for each organism, the default recount3 annotation files (fixed as of Unifier version 1.0.4 as noted above) are at these URLs:

Human Gencode V26:
* http://duffel.rail.bio/recount3/human/new_annotations/exon_sums/human.exon_sums.G026.gtf.gz
* http://duffel.rail.bio/recount3/human/new_annotations/gene_sums/human.gene_sums.G026.gtf.gz

Mouse Gencode V23:
* http://duffel.rail.bio/recount3/mouse/new_annotations/exon_sums/mouse.exon_sums.M023.gtf.gz
* http://duffel.rail.bio/recount3/mouse/new_annotations/gene_sums/mouse.gene_sums.M023.gtf.gz

Simply replace `G026` in the URLs above with one or more of the following to get the rest of the annotations (if so desired):

Human:
* `G029` (Gencode V29)
* `R109` (RefSeq release 109)
* `F006` (FANTOM-CAT release 6)
* `SIRV` (synthetic spike-in alt. splicing isoforms)
* `ERCC` (synthetic spike-in genes)

Mouse:
* `SIRV` (synthetic spike-in alt. splicing isoforms)
* `ERCC` (synthetic spike-in genes)

Finally, the `<data_source>.recount_project.MD.gz` (e.g. `sra.recount_project.MD.gz`) file is cross-study for a given data_source so it falls outside of the running of any given study. If you run another study through Monorail (assuming the same datasource, e.g. "internal" or your own version of `sra`) you'd want to append the new runs/samples to `<data_source>.recount_project.MD.gz` rather than overwrite it as it's the main list of all runs/studies in the data source used by recount3 to load them.

### Download from SRA/dbGaP/GDC Details

Monorail already downloads from SRA automatically if given an SRA accession, however for dbGaP protected downloads:

* Need to have the study-specific dbGaP key file (`prj_<study_id>.ngc`)
* Have the key file in a container accessible path (e.g. `/path/to/monorail/refs/.ncbi/`)
* Specify this as an environmental variable before running `run_recount_pump.sh`: `export NGC=/container-mounts/recount/ref/.ncbi/prj_<study_id>.ngc`


Direct GDC downloads are not currently supported by Monorail-external.  However, following the instructions below you can download the data to a local filesystem separately and then run Monorail-external on the files locally:

Details for downloading from the GDC (TCGA/TARGET) are [here](https://github.com/langmead-lab/monorail-external/blob/master/gdc/README.md)

Pre-SRAToolKit 3.0.0 info for SRA and dbGaP downloads:

Specific help in downloading from SRA can be found [here](https://github.com/langmead-lab/monorail-external/blob/master/sra/README.md)

Additional details for dbGaP are [here](https://github.com/langmead-lab/monorail-external/blob/master/dbgap/README.md)


### [Historical background] Layout of links to recount-pump output for recount-unifier

If compatibility with recount3 gene/exon/junction matrix formats is required, the output of recount-pump needs to be organized in a specific way for the Unifier to properly produce per-study level matrices as in recount3. 

For example, if you find that you're getting blanks instead of actual integers in the `all.exon_bw_count.pasted.gz` file, it's likely a sign that the input directory hierarchy was not laid out correctly.

Assuming your top level directory for input is called `recount_pump_full`, the expected directory hierarchy for each sequencing run/sample is:

`pump_output_full/study_loworder/study/sample_loworder/sample/monorail_assigned_unique_sample_attempt_id/`

e.g.
`pump_output_full/42/ERP001942/25/ERR204925/ERP001942_in3_att0`

where `ERP001942_in3_att0` contains the original output of recount-pump for the `ERR204925` sample.

The format of the `monorail_assigned_unique_sample_attempt_id` is `originalsampleid_in#_att0`.  `in#` should be unique across all samples.

`study_loworder` and `sample_loworder` are *always* the last 2 characters of the study and sample IDs respectively.

Your study and  sample IDs may be very different the SRA example here, but they should still work in this setup.  However, single letter studies/runs probably won't.
