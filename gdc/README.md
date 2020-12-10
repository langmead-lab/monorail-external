The protected cancer projects TCGA & TARGET and the publicly accessible cancer cell line project (CCLE) sequence data (old, 2012 version) are all hosted on the Genomic Data Commons (GDC) maintained by the University of Chicago.

They can be accessed via the "legacy" portal:

https://portal.gdc.cancer.gov/legacy-archive/search/f

NOTE: There is an updated version of the CCLE sequence data done by Broad (who also did the original, 2012 version) available from the SRA with more samples (total of 1019 in SRA vs. 935 in GDC).  This newer version was uploaded to SRA 03/2019:

https://www.ncbi.nlm.nih.gov/Traces/study/?acc=SRP186687

# GDC Access Key
NOTE: for CCLE files only, you DO NOT NEED a token file, they are publicly accessible, no special access required.

Similar to SRA (but entirely distinct) the GDC issues an access key/token.

HOWEVER, GDC's access keys expire in a month from the time they're issued/downloaded (SRA's do not expire for several months=>a few years).

To get the GDC access key you must have a current eRA username/password (for users internal to NIH it may be different). This should be the same as the username/password you use to login to dbGaP.

Once you have this, you can navigate to the main GDC legacy portal page listed above and click on the "Login" link in the upper right hand corner of the page.

This will pop-up a separate  window for the eRA login site, just enter your current eRA username/password on the left-hand pane and click the "Log in" blue button. This window will then close and the GDC legacy portal page will refresh but now should see your eRA/dbGaP username in the upper right hand corner in place of "Login".  Click your user name to see a drop down where you can "Download Token" as a file to your local machine.

KEEP THIS FILE SECURE! `chmod` it so only you have READ/WRITABLE permissions on it!

This key file will be needed as a command line argument to the GDC transfer tool.

# GDC File Transfer

You'll need the GDC-specific file transfer tool:

`conda install -c bioconda gdc-client`

Legacy projects in the GDC use UUIDs (verion 4) to uniquely identify sequence read files (and BAMs).

e.g. `3d94efb8-94d4-4fde-97d8-18a159279996`

This file UUID will be used to reference the specific sequence read file you want to download in the GDC transfer tool.

general example:
```
gdc-client download /path/to/GDC_TOKEN_FILE -n <threads> -d /path/to/download/dir --retry-amount 3 --wait-time 3 <GDC_FILE_UUID> 
```
As noted above, you don't need a token file for CCLE data.

The command above includes a retry parameter and a wait-time parameter which control 1) how many retries to attempt and 2) the amount of time (sec.) to wait between retries.

The `gdc-client` can also take a "manifest" file either downloaded from the shopping-cart-esque interface linked above or hand created, the main part of that file is a list of GDC file UUIDs that the client will download (serially?) if you want to download more than one at a time for a given session.

There are times where  the `gdc-client` appeared to stall, these may be due to filesystem issues or it may be the client itself.  Using the `timeout` command from `bash` in front of a `gdc-client` command may help get around this in the context of a pipeline where you want to quickly fail individual files which can't download or are too slow.

# Post download extraction operation

RNA-seq files from GDC are typically packaged as either gzipped TAR files containing FASTQ files *OR* as tar files containing gzipped FASTQs.

Before running the downloaded files from GDC through Monorail-external, you *must* extract the FASTQs ahead of time.

# Running with Monorail's Containers

Monorail run its alignment workflow (the `pump`), including downloads in Docker/Singularity containers. 
Therefore, the GDC_TOKEN_FILE must be accessible to the container when it's running the download.

Every file UUID to be downloaded must reference the full path to the GDC_TOKEN_FILE *within the container*, e.g.:

```/container-mounts/recount/ref/gdc_creds/gdc-user-token.2019-12-26T23_45_00-08_00.txt```

This requires that the GDC_TOKEN_FILE is stored under the references directory on the host filesystem, which is already mounted into the container under `/container-mounts/recount/ref` (by default).
