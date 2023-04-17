#!/usr/bin/env Rscript
library(argparser, quietly=TRUE)
library(data.table)

p <- arg_parser("compare two matrices with assumed same columns/values but in different orders")
p <- add_argument(p, "--f1", help="first sums file to compare, use this one to get columns from the other")
p <- add_argument(p, "--f2", help="second sums file to compare")
argv <- parse_args(p)

#f1=fread(file=argv$f1,data.table=FALSE)
f1=fread(file=argv$f1,data.table=TRUE)
n1=names(f1)
f2=fread(file=argv$f2,data.table=TRUE)
all.equal(f1,f2[,..n1])
