#!/usr/bin/env bash
set -x
export LC_ALL=C
#assumes current working directory is the pump output of accession/sample we want to test
#expect the following legit differences (all diffed below except manifest), which have no significant bearing on recount3/snaptron:
#*.manifest
#*.Chimeric.out.sam.zst (CO and PG headers maybe slightly different due to differences in filenames/paths, and/or order)
#*.Chimeric.out.junction.zst (header may be slightly different due to same reason as Chimeric.out.sam.zst, and/or order)
#*.salmon.tsv.zst (small changes in floating point coverage output, likely due to stochastic nature of computation)
#*.jx_bed.zst (purely order)
#*.bamcount_jx.tsv.zst (purely order)
#*.bamcount_nonref.csv.zst (purely order)
#any files in one directory not in the other

#*.exon_bw_count.zst SHOULD NOT BE DIFFERENT AT ALL, or there's something wrong!!

#path to previous pump run on same accession/sample (assumes "sra" is download method)
path=$1

ls -l | tr -s " " \\t | cut -f 5,9  | sort > one.list
ls -l $path | tr -s " " \\t | cut -f 5,9  | sort > two.list
diff one.list two.list | fgrep -v log | fgrep -v unmapped | fgrep -v summary | fgrep sra > list.diff

for suffix in exon_bw_count.zst salmon.tsv.zst jx_bed.zst bamcount_jx.tsv.zst bamcount_nonref.csv.zst Chimeric.out.sam.zst Chimeric.out.junction.zst; do
    fn1=$(ls *.${suffix})
    fn2=$(ls $path/*.${suffix})
    zstd -cd $fn1 > one
    zstd -cd $fn2 > two
    cmd="cat "
    if [[ "$suffix" == "salmon.tsv.zst" || "$suffix" == "jx_bed.zst" ]]; then
        cmd="cut -f 1-3,5-"
    fi 
    diff <($cmd one | sort) <($cmd two | sort) > ${suffix}.diff
done
rm -f one two
