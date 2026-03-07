#!/usr/bin/env python3
#[Claude Sonnet 4.6 generated, heavily edited and tested by CW]

"""
Sums per-row floating point values from a scores file against a BED file,
aggregating by gene_id and exon_id.

Inputs
------
  bed_file    : BED-like file produced by gtf_to_bed.py (tab-delimited).
                The 4th column (name) has the format:
                    gene_id|exon_id
                    gene_id|exon_id|full_exon
                    gene_id|exon_id|exon_segment
  scores_file : One floating-point number per line, same row count as bed_file.

Aggregation rules
-----------------
  gene_id sums : ALL rows contribute, regardless of tag.
  exon_id sums : Only rows with tag "full_exon" OR no tag at all contribute.
                 Rows tagged "exon_segment" are skipped for exon-level sums.

Outputs
-------
  gene_sums.tsv  : gene_id <TAB> sum
  exon_sums.tsv  : exon_id <TAB> sum

Usage
-----
    python sum_by_feature.py <bed_file> <scores_file>
    python sum_by_feature.py <bed_file> <scores_file> --gene-out gene_sums.tsv --exon-out exon_sums.tsv
"""

import sys
import argparse
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("bed_file",    help="BED file from gtf_to_bed.py")
    parser.add_argument("scores_file", help="One float per line, same row order as BED file")
    parser.add_argument("--gene-out",  default="gene_sums.tsv",
                        help="Output file for gene-level sums (default: gene_sums.tsv)")
    parser.add_argument("--exon-out",  default="exon_sums.tsv",
                        help="Output file for exon-level sums (default: exon_sums.tsv)")
    parser.add_argument("--integers-only", action="store_true", default=False,
                        help="Truncate all floating point values to integers (if all in puts are integetrs, this is fine)")
    parser.add_argument("--include-ids-for-exon", action="store_true", default=False,
                        help="Default is to only output the recount_exon_id: \"chrom|start|end|strand\" (where start/end begin at 1), this forces the gene_id and exon_id from gencode (or whereever) to be output as well.")
    return parser.parse_args()


def main():
    args = parse_args()

    gene_sums = defaultdict(float)   # gene_id  → cumulative sum
    exon_sums = defaultdict(float)   # exon_id  → cumulative sum

    bed_rows    = 0
    score_rows  = 0
    
    # ── Verify row counts matched ─────────────────────────────────────────────
    # Peek to see if one file had more lines than the other
    with open(args.bed_file) as bed_fh, open(args.scores_file) as score_fh:
        n_bed   = sum(1 for l in bed_fh)
        n_score = sum(1 for l in score_fh if l.strip())
    
    if n_bed != n_score:
        print(f"  Error: BED file has {n_bed} rows but scores "
              f"file has {n_score} non-empty rows — files may be misaligned, terminating early!",
              file=sys.stderr)
        sys.exit(-1)

    recount_exon_id2others_ids = defaultdict(set)
    with open(args.bed_file) as bed_fh, open(args.scores_file) as score_fh:
        for line_num, (bed_line, score_line) in enumerate(
                zip(bed_fh, score_fh), start=1):

            bed_line   = bed_line.rstrip("\n")
            score_line = score_line.strip()

            bed_rows   += 1
            score_rows += 1

            # ── Parse score ───────────────────────────────────────────────
            try:
                value = float(score_line)
            except ValueError:
                print(f"  Warning: line {line_num} — cannot parse score "
                      f"'{score_line}' as float; skipping.", file=sys.stderr)
                continue

            if value < 0.0:
                print(f"  Warning: line {line_num} — negative score {value}; "
                      f"skipping.", file=sys.stderr)
                continue

            # ── Parse BED name field (column 4, 0-indexed col 3) ─────────
            bed_fields = bed_line.split("\t")
            if len(bed_fields) < 4:
                print(f"  Warning: line {line_num} — BED row has fewer than "
                      f"4 fields; skipping.", file=sys.stderr)
                continue

            chrom = bed_fields[0]
            start = str(int(bed_fields[1])+1)
            end = bed_fields[2]
            strand = bed_fields[5]
            recount_exon_id = "|".join([chrom,start,end,strand])

            name_parts = bed_fields[3].split("|")
            gene_id = name_parts[0]
            exon_id = name_parts[1] if len(name_parts) >= 2 else None
            tag     = name_parts[2] if len(name_parts) >= 3 else None

            # ── Accumulate gene sum (rows with tags: full_exon or exon_segment) ────────────────────────────
            if exon_id is not None and (tag == "exon_segment" or tag == "full_exon"):
                gene_sums[gene_id] += value

            # ── Record exon sum (full_exon or no tag; skip exon_segment)
            if exon_id is not None and tag != "exon_segment":
                k = f"{gene_id}\t{exon_id}"
                if k in recount_exon_id2others_ids[recount_exon_id]:
                    print(f"  Error: line {line_num} — BED gene_id+exon_id+coordinate_id {gene_id} + {exon_id} + {recount_exon_id}, already seen, shouldn't happen, terminating early!", file=sys.stderr)
                    sys.exit(-1)
                recount_exon_id2others_ids[recount_exon_id].add(k)
                if recount_exon_id in exon_sums:
                    if value != exon_sums[recount_exon_id]: 
                        print(f"  Error: line {line_num} — BED exon (by coordinate_id {recount_exon_id} for gene_id {gene_id} and exon_id {exon_id}) has different value then it's previously encountered instance, shouldn't happen, terminating early!", file=sys.stderr)
                        sys.exit(-1)
                    else:
                        #not an error, but to be fully comparable with recount3/monorail output exon sums
                        #we drop sum where the exon coordinates (and therefore sum) is the same but the gene_id and/or exon_id is different due to the same exon showing up in different genes and/or transcripts
                        continue
                exon_sums[recount_exon_id] = value



    # ── Write gene sums ───────────────────────────────────────────────────────
    with open(args.gene_out, "w") as fh:
        fh.write("gene_id\tsum\n")
        for gene_id, total in sorted(gene_sums.items()):
            if args.integers_only:
                fh.write(f"{gene_id}\t{total:.0f}\n")
            else:
                fh.write(f"{gene_id}\t{total:.3f}\n")

    # ── Write exon sums ───────────────────────────────────────────────────────
    with open(args.exon_out, "w") as fh:
        if args.include_ids_for_exon:
            fh.write("gene_id\texon_id\trecount_exon_id\tsum\n")
        else:
            fh.write("recount_exon_id\tsum\n")
        for exon_id0, total in sorted(exon_sums.items()):
            ids2print = [exon_id0]
            if args.include_ids_for_exon:
                ids2print = [f"{gene_exon_ids}\t{exon_id0}" for gene_exon_ids in recount_exon_id2others_ids[exon_id0]]
            for exon_id in ids2print:
                if args.integers_only:
                    fh.write(f"{exon_id}\t{total:.0f}\n")
                else:
                    fh.write(f"{exon_id}\t{total:.3f}\n")

    print(f"Processed {bed_rows:,} BED rows.")
    print(f"  {len(gene_sums):,} unique gene_ids  → {args.gene_out}")
    print(f"  {len(exon_sums):,} unique exon_ids  → {args.exon_out}")


if __name__ == "__main__":
    main()
