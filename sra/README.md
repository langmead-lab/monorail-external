Downloading from SRA is a common task for us.
It's also not completely straightforward.

While many of the sequence run accessions *may* be found on the European mirror of SRA (ENA), not all will be there.
See the last section of this document for downloading from ENA.

First, it's helpful to know there's some fairly up-to-date info from the SRA folks themselves:
https://github.com/ncbi/sra-tools/wiki

Second, you will need to install a version (preferably the latest) of SRA-tools
to download from SRA.

If you're on a well maintained HPC system (e.g. TACC) there's probably a form of the `module` system running.

`module spider sra` may result in a module you can `module load <sratool_module_name>`

Otherwise conda's probably the easiest:

`conda install -c bioconda sra-tools`

As of 2019-07-29 the most consistently stable approach to downloading
from SRA (public data) is to use the following strategy:

* prefetch HTTPS to download cSRA formatted files
* parallel-fastq-dump to convert from cSRA to actual FASTQ

# Downloading a sequence run
generic `prefetch` command line:

`prefetch --max-size 200G -L info -t http -O <outputdir> <RUN_ACCESSION>`

working example:

`prefetch --max-size 200G -L info -t http -O ./ ERR204946`

If you do want to use Aspera for speed (and you know it'll work on your particular accession), just swap the `http` in the `-t` option with `fasp`.

# Converting a downloaded cSRA file to FASTQ file(s)
By leveraging the `-N` and `-X` (range of spots) options of `fastq-dump`, `parallel-fastq-dump` can run multiple `fastq-dump`s in parallel on the same downloaded cSRA file.

https://github.com/rvalieris/parallel-fastq-dump

We have found `parallel-fastq-dump` to consistently work with certain `fastq-dump` options better than `fasterq-dump`.

generic `parallel-fastq-dump` command line:

```
parallel-fastq-dump --sra-id /path/to/downloaded_cSRA_files --threads <num_fastq_dump_processes> --tmpdir /path/to/temporary_working_dir -L info --split-3 --skip-technical --outdir ./ --gzip
```

NOTE: the argument to `--tmpdir` needs to exist before running the command.

working example:
```
parallel-fastq-dump --sra-id ./ERR204946.sra --threads 4 --tmpdir ./tmp -L info --split-3 --skip-technical --outdir ./ --gzip 
```

If for some reason `parallel-fastq-dump` isn't available, you can fall back to using good old `fastq-dump` it'll just be slower (and the options may be a little different).

# Pipeline specific information
The above will work in either a one-off way or for a pipeline.

However, additional consideration should be taken in the case of a pipeline processing many run accessions in a batch.

* To save temporary working space, configure SRA-tools to NOT "Enable Local File Caching (2)"
* If running downloads from within in a container (Docker/Singularity) you *may* need to modify the SRA-tools configuration paths for downloading files to work within the container context


# Downloading a sequence run from ENA

On occasion we may want to download FASTQs from ENA rather than SRA.

This would mainly be because ENA supports 1) direct compressed FASTQ download 2) from an FTP.
These features obviate the need of using SRA-tools to 1) download and 2) convert to FASTQ.

ENA also supports Globus:

https://www.ebi.ac.uk/about/news/service-news/read-data-through-globus-gridftp

However, *not all* SRA runs are available from ENA!

Quick example of a direct FASTQ sequence run download link via HTTP/FTP for a 6-digit run:

ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR204/ERR204946/ERR204946_1.fastq.gz

ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR204/ERR204946/ERR204946_2.fastq.gz

Single end, 7-digit run:

ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR101/006/SRR1016916/SRR1016916.fastq.gz

See the ENA examples page for more details:
https://www.ebi.ac.uk/ena/browse/read-download
