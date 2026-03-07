#!/usr/bin/env python3
#[Claude Sonnet 4.6 generated, edited and tested by CW]
"""
GTF to BED-like converter with exon overlap segmentation.

Coordinates are output as-is from the GTF (1-based, no BED shift applied).

For each gene, exons are output as follows:
  1. The original full exon row is always written (gene_id|exon_id).
  2. If an exon does NOT overlap any other exon in the same gene:
       → label is  gene_id|exon_id|full_exon
  3. If an exon DOES overlap one or more other exons in the same gene:
       → original row has no extra suffix  (gene_id|exon_id)
       → additional segment rows are written after all original exon rows
         for that gene, labelled  gene_id|exon_id|exon_segment

Segmentation logic (all coords are raw GTF values, no shifting):
  Cut points are built from:
    • Every overlapping exon's  start       (left edge)
    • Every overlapping exon's  end + 1     (one past right edge)
  Consecutive cut-point pairs [s, e) define slices.
  Each slice [s, e) is output as the interval [s, e-1] (i.e. start=s, end=e-1).
  A slice is attributed to the most-downstream (latest start) exon that fully
  covers it.

Example
-------
  Exon A: [11869, 12227]   Exon B: [12220, 12261]
  Cut points: 11869, 12220, 12228, 12262  (starts, and end+1 values)
  Slices → segments:
    [11869, 12220) → [11869, 12219]  attributed to A  (A only)
    [12220, 12228) → [12220, 12227]  attributed to B  (overlap, B is later)
    [12228, 12262) → [12228, 12261]  attributed to B  (B only)

CW: FINALLY: remove 1 from each start to make this truly a BEF file (but do this last to avoid over-complicating the segmenting logic)

Usage
-----
    python exons_from_GTF2monorail_input_BED_file.py input.gtf output.bed
"""

import sys
import re
from collections import defaultdict


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_attribute(attributes_str, key):
    """Return the first quoted value for *key* in a GTF attributes string."""
    match = re.search(rf'{re.escape(key)}\s+"([^"]+)"', attributes_str)
    return match.group(1) if match else None


def find_overlapping_ids(exons):
    """Return set of exon_ids that overlap at least one other exon (closed GTF coords)."""
    overlapping = set()
    for i, a in enumerate(exons):
        for j, b in enumerate(exons):
            if i >= j:
                continue
            if a["start"] <= b["end"] and b["start"] <= a["end"]:
                overlapping.add(a["exon_id"])
                overlapping.add(b["exon_id"])
    return overlapping


def compute_segments(exons):
    """
    Given exon dicts (with keys: chrom, start, end, strand, gene_id, exon_id)
    for one gene, return (overlapping_ids, segments).

    segments is a list of dicts {chrom, start, end, gene_id, exon_id, strand}.
    All coordinates are raw GTF values — no shifting.
    """
    overlapping_ids = find_overlapping_ids(exons)
    if not overlapping_ids:
        return overlapping_ids, []

    ov_exons = [e for e in exons if e["exon_id"] in overlapping_ids]

    # Cut points: each exon's start and end+1
    cut_points = set()
    for e in ov_exons:
        cut_points.add(e["start"])
        cut_points.add(e["end"] + 1)

    sorted_cuts = sorted(cut_points)

    segments = []
    for k in range(len(sorted_cuts) - 1):
        seg_s = sorted_cuts[k]          # inclusive start
        seg_e = sorted_cuts[k + 1] - 1  # inclusive end  (= next_cut - 1)

        # Exons that fully cover this slice [seg_s, seg_e]
        covering = [
            e for e in ov_exons
            if e["start"] <= seg_s and e["end"] >= seg_e
        ]
        if not covering:
            continue

        # Attribute to the most-downstream exon (latest start; exon_id as tiebreak)
        chosen = max(covering, key=lambda e: (e["start"], e["exon_id"]))

        segments.append({
            "chrom":   chosen["chrom"],
            "start":   seg_s,
            "end":     seg_e,
            "gene_id": chosen["gene_id"],
            "exon_id": chosen["exon_id"],
            "strand":  chosen["strand"],
        })

    return overlapping_ids, segments


# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def gtf_to_bed(input_path, output_path):
    # ── Pass 1: read all exon records ────────────────────────────────────────
    raw_exons = []
    skipped   = 0

    with open(input_path) as fh:
        for line_num, line in enumerate(fh, start=1):
            if line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 9:
                skipped += 1
                continue
            if fields[2] != "exon":
                continue

            gene_id = parse_attribute(fields[8], "gene_id")
            exon_id = parse_attribute(fields[8], "exon_id")
            if gene_id is None or exon_id is None:
                print(f"  Warning: line {line_num} missing gene_id or exon_id — skipping.",
                      file=sys.stderr)
                skipped += 1
                continue

            raw_exons.append({
                "chrom":   fields[0],
                "start":   int(fields[3]),
                "end":     int(fields[4]),
                "strand":  fields[6],
                "gene_id": gene_id,
                "exon_id": exon_id,
            })

    # ── Group by (chrom, gene_id) and compute overlap / segment info ─────────
    groups = defaultdict(list)
    for e in raw_exons:
        groups[(e["chrom"], e["gene_id"])].append(e)

    exon_tag     = {}   # exon_id → "full_exon" or None (overlapping)
    gene_segs    = {}   # (chrom, gene_id) → list of segment dicts

    for (chrom, gene_id), group in groups.items():
        overlapping_ids, segments = compute_segments(group)
        for e in group:
            exon_tag[e["exon_id"]] = None if e["exon_id"] in overlapping_ids else "full_exon"
        gene_segs[(chrom, gene_id)] = segments

    # ── Find the last input index per gene (so we know when to flush segments) 
    last_idx     = {}
    for idx, e in enumerate(raw_exons):
        last_idx[(e["chrom"], e["gene_id"])] = idx

    genes_flushed = set()

    # ── Pass 2: build output lines in input order ─────────────────────────────
    output_lines = []

    for idx, e in enumerate(raw_exons):
        tag = exon_tag[e["exon_id"]]

        # Original full exon row
        if tag == "full_exon":
            name = f"{e['gene_id']}|{e['exon_id']}|full_exon"
        else:
            name = f"{e['gene_id']}|{e['exon_id']}"

        segstart=e['start']-1
        if segstart < 0:
            segstart = 0
        output_lines.append(
            f"{e['chrom']}\t{segstart}\t{e['end']}\t{name}\t0\t{e['strand']}"
        )

        # After the last exon of this gene, flush its segment rows
        gene_key = (e["chrom"], e["gene_id"])
        if idx == last_idx[gene_key] and gene_key not in genes_flushed:
            genes_flushed.add(gene_key)
            for seg in gene_segs.get(gene_key, []):
                seg_name = f"{seg['gene_id']}|{seg['exon_id']}|exon_segment"
                segstart=seg['start']-1
                if segstart < 0:
                    segstart = 0
                output_lines.append(
                    f"{seg['chrom']}\t{segstart}\t{seg['end']}\t{seg_name}\t0\t{seg['strand']}"
                )

    # ── Write output ──────────────────────────────────────────────────────────
    with open(output_path, "w") as out:
        for line in output_lines:
            out.write(line + "\n")

    return len(output_lines), skipped


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 3:
        print(f"Usage: python {sys.argv[0]} input.gtf output.bed")
        sys.exit(1)

    input_path, output_path = sys.argv[1], sys.argv[2]
    print(f"Reading:  {input_path}")
    print(f"Writing:  {output_path}")

    written, skipped = gtf_to_bed(input_path, output_path)
    print(f"Done — {written:,} output rows written, {skipped:,} input lines skipped.")


if __name__ == "__main__":
    main()
