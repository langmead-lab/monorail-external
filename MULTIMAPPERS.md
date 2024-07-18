# How multimapping reads are handled in recount

This question comes up from time to time and is an important one for downstream analyses using recount sums.

First and foremost, handling multimapping reads, especially at the almost universal scale that recount projects attempt to do, is a very tricky problem. Thus we are *not* not saying that the following approaches are best/optimal for all cases.

Due to the differences between recount2 and recount3 in terms of aligners, we cover them each in their own section.

Much of the following was taken from an email thread answering a question around multimappers and their effect on the recount2 and recount3 bigwigs (per-base coverage tracks stored at the per-sample level).  Special thanks to Dr. Abhi Nellore---author of Rail-RNA, the aligner used to build recount2---for much of this detail and wording.

## recount2

Multimappers for recount2 (i.e., Rail-RNA) are handled differently in different cases. When a read doesn't align across junctions and there are alignments with tied scores, the primary alignment is chosen uniformly at random.

When a read aligns across junctions and there are multiple possible alignments, Rail-RNA attempts to minimize the number of junctions that explain the read; that is, if a read can be explained just as well by aligning it across a junction with greater coverage rather than introducing a new junction to the picture, it will do that.

Secondary alignments are excluded from recount2 and recount3 bigwigs.
Also, recount2 bigwigs incorrectly double-count when a read pair aligns twice across the same base(s).
recount3 bigwigs do not contain this double-counting error.

Please see the Rail-RNA [paper](https://academic.oup.com/bioinformatics/article/33/24/4033/2525684) and the supplement for more details, specifically pages 17-18 of the supplement, including the start of S.20.
Additionally, how recount2 bigwigs are compiled is summarized in S.25 of the Rail-RNA supplement.


## recount3

In recount3, multimappers are handled the way STAR 2.7.3a handles them. From the STAR 2.7.3a [manual](http://gensoft.pasteur.fr/docs/STAR/2.7.3a/STARmanual.pdf): "For multi-mappers, all alignments except one are marked with 0x100 (secondary alignment) in the FLAG (column 2 of the SAM). The unmarked alignment is selected from the best ones (i.e. highest scoring)." Note "selected from the best ones" may not mean "selected uniformly at random from the best ones" here.

Also from the STAR manual: "By default, the order of the multi-mapping alignments for each read is not truly random. The --outMultimapperOrder Random option outputs multiple alignments for each read in random order, and also randomizes the choice of the primary alignment from the highest scoring alignments."  However, the `--outMultimapperOrder Old_2.4` parameter was specified for Monorail when generating recount3 data not `Random`.

For reference, the STAR 2.7.3a parameters used to generate recount3 data by Monorail are [here](https://github.com/langmead-lab/recount-pump/blob/d2a0327a8c344fa8edc088cf2ae73e85390deab3/workflow/rs5/Snakefile#L891-L910).
All other STAR parameters were left at STAR 2.7.3a's default, e.g. `--alignSJoverhangMin` is 5 by default in that version (for splice junction calling in STAR).

Reads which have a primary and one or more secondary alignments are still included by Megadepth (used to generate bigwigs in recount3 but not in recount2), but only the primary alignment is counted in the coverage sum, as the secondary alignments are excluded from consideration. However, this is not exactly the same thing as only counting unique alignments, as that would mean also filtering out the *primary* alignments of those reads which also have secondary alignments which *is not* done for the recount3 bigwigs by Megadepth.

Fully unique bigwigs, those which only count primary alignments from those reads which *only have* primary alignments were produced as part of the Monorail pipeline during the generation of the recount3 data, but are not currently public and are thus not technically considered part of recount3 at this time.
