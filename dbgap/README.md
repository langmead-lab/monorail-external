This page documents the specific issues with downloading dbGaP (protected) data from SRA.

This does NOT cover TCGA/CCLE/TARGET data from the GDC.  That is an entirely separate process covered [here](https://github.com/langmead-lab/monorail-external/blob/master/gdc/README.md).

For the general approach to downloading data from SRA, please see the [Download data from SRA](https://github.com/langmead-lab/monorail-external/blob/master/sra/README.md) page first:


While the download/convert mechanisms are the same for public and protected data (as documented in the page referenced above), the additional nuances of protected data can potentially add significant trouble to the process.

# Setting up your dbGaP project secure key
First, you need to "import" the correct key for SRA-tools to use via `vdb-tools` in the compute environment where you're doing the downloading.  This is a *per-project* key.  So you'll have a different key for GTEx than for some other dbGaP project.

This project key should be downloadable from dbGaP after 1) logging in using your eRA/other dbGaP username/password and 2) gaining access to a specific dbGaP protected project (e.g. GTEx).  The exact flow is:

* Click on the "dbGaP Data Browser" from the dbGaP main page
* Click the "My Projects" sub-tab under the "Authorized Access" tab (this should be default), you should then see a list of projects your dbGaP user is authorized to download from
* To the far right of the project you want to download from there should be a list of links, click the last one "get dbGaP repository key"

The key filename will look something like:
`prj_8716_D19642.ngc`

where the `8716` denotes the project ID and it'll have what is essentially a password string (mine has 16 characters) within it.

MAKE SURE YOU `chmod` THE FILE PERMISSIONS TO BE READ/WRITABLE ONLY BY YOU!

This is the key file to import into SRA Tools.
You should use `vdb-config -i` to 1) import the key file and 2) update the path of the destination where you plan to at least initially download the SRA files.
  
Once imported, it will create a new file in the config directory, e.g.:
 `$HOME/.ncbi/dbGap-8716.enc_key`

Once you've run `vdb-config -i` initially, you can also directly edit the `$HOME/.ncbi/user-settings.mkfg` to at least change paths, despite the warning not to do this.

# Determining the correct project filesystem path to download to
Second, you need to be careful about the filesystem path you download/convert the protected data to/in using `prefetch` and `fastq-dump`.  

If you're not, you *will* receive errors of the type:
```
prefetch.2.9.1 err: query unauthorized while resolving query within virtual file system module - failed to resolve accession 'SRR1440541' - Access denied - please request permission to access phs000424/GRU in dbGaP ( 403 )
```
(substituting the version of prefetch/run_accession/study_accession you're using)

This is referenced in this issue:
https://github.com/ncbi/sra-tools/issues/9

and appears very briefly in the dbGap-specific section of the SRA-tools official wiki (near the end):
https://github.com/ncbi/sra-tools/wiki/HowTo:-Access-SRA-Data

The best approach is to initially configure SRA-tools to use the actual path you want to download the dbGaP data to; e.g. probably a filesystem which is 1) large and 2) performant for concurrent read/writes (such as a Lustre-based FS).

* The directory referenced in the SRA-tool configuration (e.g. via `vdb-config -i`) needs to be the parent of *all* download directories/files for the specific dbGaP project
* The directory cannot be NFS mounted

Contrary to my previous understanding, the path in the configuration does NOT need to have the `dbGaP-<projID>` as part of its path.

You may also want to use a symlink.

## Symlinks
This does work, however, the non-NFS FS requirement still applies and it still needs to be the root of all downloads/conversions.

This becomes slightly trickier when run within a container (Docker/Singularity).

The way to do this in a container is to create the "root" path referenced in the `vdb-config` for the specific dbGaP project to be a symlink to a path *within* the container where the data will be saved.  

The path will be marked as broken by the filesystem *outside* of the container, but as long as it's valid within the container this is fine.  This path can then separately be mapped via the container to a real filesystem path elsewhere.  

An example of this on a local HPC at JHU (MARCC) for GTEx is (where `$HOME` is my MARCC home directory):

`$HOME/ncbi/dbGaP-8716`

which in turn is symlinked to:

`/home/recount-pump/dbGaP-8716`

which only resolves inside a properly configured *Singularity* container.
This may not work with Docker due to home directories not being automatically mounted in Docker containers.

For Docker, you may need to reconfigure SRA Tools via `vdb-config -i` (or directly editing the config file as above) to ensure that the key file path (e.g. `$HOME/.ncbi/dbGap-8716.enc_key`) and download data root directory (e.g. `<prefix>/storage/cwilks/recount-pump/recount/dbGaP-8716` below) are on a path visible to the Docker container.

In the Monorail (recount-pump portion) pipeline, the `creds/cluster.ini` for this example GTEx run on MARCC looks like:
```
...
temp_base=<prefix>/storage/cwilks/recount-pump/recount/dbGaP-8716
input_base=<prefix>/storage/cwilks/recount-pump/recount/input
output_base=<prefix>/storage/cwilks/recount-pump/recount/output
ref_mount=/container-mounts/recount/ref
temp_mount=/container-mounts/recount/dbGaP-8716
input_mount=/container-mounts/recount/input
output_mount=/container-mounts/recount/output
...
```
(`<prefix>` used to obscure full path for security reasons)

# SRA/vdb-config Problems
Listed here are a few problem you might encounter when trying to get dbGaP downloads to work via SRA tools (by error).

## Ongoing access denied errors

First I've noticed on some systems (e.g. JHPCE) that unless you're running the `prefetch` command *under* the authorized download directory as your current working directory, the download will still result in an `access denied` error.  This is not true on MARCC even for the same version of SRA-toolkit.

The fix then on these systems is to temporarily `cd` into the authorized download directory, run the `prefetch` command, then `cd` back to your original working directory (using `pushd <authorized_download_dir> ; prefetch ... ; popd` is a convenient way to do this).

If you think you've done everything above correctly, but are still getting an `...Access denied - please request permission to access...` error, redownload and re-import your dbGaP key, it may be out of date/corrupted for some reason.
To do this cleanly, it's best to completely remove your current SRA tools/vdb-config and start from scratch, then import the new key as if for the first time, otherwise, vdb-config may not update anything.

## Re-creating SRA tools config directory error

If in the process of resetting your SRA tools configuration (as in the problem above), you might get an error about setting `config in $HOME`, this appears to be related to the directory permissions of the `$HOME/.ncbi` directory, best to remove it, then recreate it with default permissions, then try `vdb-config -i` again.
