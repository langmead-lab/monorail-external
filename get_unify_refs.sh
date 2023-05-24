#!/usr/bin/env bash
#either hg38 or grcm38
set -ex

org=$1

mkdir -p ${org}_unify
pushd ${org}_unify

#first grab all the disjoint exon mapping files (mapping back to annotated exons & genes)
#as well as a stand in file with 0's for those samples w/o any exon sums (blank_exon_sums)
#finally get the chromosome sizes for the genome reference used in recount-pump
for f in disjoint2exons.bed.gz disjoint2exons2genes.bed.gz disjoint2exons2genes.rejoin_genes.bed.gz recount_pump.chr_sizes.tsv.gz blank_exon_sums.gz exon_bitmasks.tsv.gz exon_bitmask_coords.tsv.gz ; do
    unzipped=$(echo $f | sed 's/\.gz$//')
    if [[ ! -e "$unzipped" ]]; then
        wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}_unify/$f
        gunzip $f
    fi
done

#get rows counts for Unify post-run validation
wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}_unify/gene_exon_annotation_row_counts.tsv

#next get list of annotated jx's which is separate the main annotations used in recount-pump
#annotated junctions stay gzipped
wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}_unify/annotated_junctions.tsv.gz

#now get genome ref FASTA file, this is part of the recount-pump refs
#so just get it from there
if [[ ! -e ../${org}/fasta/genome.fa ]]; then
    mkdir -p ../${org}
    pushd ../${org}
    wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}/fasta.tar.gz
    tar -zxvf fasta.tar.gz
    popd
fi
#can't be symbolic since the container won't be able to follow it
ln -f ../${org}/fasta/genome.fa recount_pump.fa

#now get disjoint of annotated exons, which is also part of the recount-pump refs
if [[ ! -e ../${org}/gtf/exons.bed ]]; then
    mkdir -p ../${org}
    pushd ../${org}
    wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}/gtf.tar.gz
    tar -zxvf gtf.tar.gz
    popd
fi
#need to add a header to the exons file and gzip it
#slight misnomer in the header, "gene" is really "chromosome" but leave for backwards compatibility
cat <(echo "gene	start	end	name	score	strand") ../${org}/gtf/exons.bed | gzip > exons.w_header.bed.gz

#finally, grab per-annotation ordering and default annotation disjoin-exon-per-gene BED file for post-run resum check
annotations="G026 G029 R109 F006 ERCC SIRV"
default="G026"
if [[ $org == "grcm38" ]]; then
    annotations="M023 ERCC SIRV"
    default="M023"
fi
if [[ ! -e disjoint2exons2genes.${default}.sorted.cut.bed ]]; then
    wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}_unify/disjoint2exons2genes.${default}.sorted.cut.bed.gz
    gunzip disjoint2exons2genes.${default}.sorted.cut.bed.gz
fi
for f in $annotations; do
    f="${f}.gene_sums.gene_order.tsv.gz"
    unzipped=$(echo $f | sed 's/\.gz$//')
    if [[ ! -e "$unzipped" ]]; then
        wget https://genome-idx.s3.amazonaws.com/recount/recount-ref/${org}_unify/$f
        gunzip $f
    fi
done

popd
