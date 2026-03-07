# Monorail reAnnotation
One fairly major component that's been missing for a while with the Monorail pipeline, is a streamlined way to run additional annotations/genes/transcripts/exons and have compatible outputs with the existing pipeline outputs and/or recount3.

This part of the repo attempts to at least partially address that.

## New Annotation Preparation
Whether you have a few additional genes or a whole new annotation (e.g. Gencode v45 human), the steps will be the same.

First, you need to have your new annotation in a GTF format.
Specifically, you need all exons that make up your new genes/transcripts, along with their gene_id and exon_id.

Now run this command on the GTF file:

```python3 reannotation/exons_from_GTF2monorail_input_BED_file.py <input.gtf> <output.bed>```

## Computing Sums for the New Annotation
This assumes you're already running the latest version of Monorail on your samples.

That is, you should have two BigWig files per input sample (with suffixes: `.all.bw` and `.unique.bw`).

Depending on what your goal is, you can choose to use either or both of the BigWig files.

For compatiblity with the default Monorail sums or the recont3 sums, use the `.all.bw` BigWig file and ignore the `.unique.bw` file, per sample.

You will need Megadepth (>=v1.2.0):

A minimally dynamic-linked megadepth binary v1.2.0 for a modern Linux using x86_64 architecture:
https://github.com/ChristopherWilks/megadepth/releases/download/1.2.0/megadepth

`chmod a+x megadepth`

Then run something like this (per-sample BigWig file):

```./megadepth <sample.all.bw> --annotation <exon_annotations_from_previous_step.bed> --sums-only > sample.all.bw.sums```

Given the size of the sample BigWig file and the # of annotation rows, the time taken per-sample will vary, but expect between a few seconds and ~1-2 minutes.

If it takes much longer than that for a single BigWig, there's likely a problem somehwere (or you're running this on an Etch A Sketch, which is still a problem).

## Aggregate and further Sum Coverage

The output format of Megadepth is a bit at the exon_segment level, rather than at the annotated gene/exon level.  It also doesn't include any of the ids except for the chromosome, start, and end coordinates. So we need to do another step to get it into a set of aggregate sums that can be compared with recount3 with the proper gene and exon IDs.

Run this per-sample output from Megadepth:

```python3 reannotation/sum_by_gene_and_exon.py <exon_annotations_from_first_step.bed> sample.all.bw.sums --gene-out sample.all.bw.gene_sums --exon-out sample.all.bw.exon_sums --integers-only```


## Final Aggregation into Single Gene and Exon Coverate Sum Matrices
The output from the previous step has the correct sums and IDs but is still in a one-file-per-sample format.

We need to get it into a single matrix (tab-delimited file with header, a `.tsv`) for the study/project/experiment (>=2 samples).
