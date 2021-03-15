#!/usr/bin/env python3
#script to write out jobs to download all of SRA human & mouse RNA-seq metadata
import sys
import os
import argparse
import shutil
import re
from Bio import Entrez as e
import xml.dom.minidom
import xml.etree.ElementTree as ET

scriptpath = os.path.dirname(sys.argv[0])
#required to set an email
e.email="downloadsRUs@dos.com"

#always query for: Illumina + RNA-seq + Transcriptomic source + public while skipping smallRNAs
#base_query = '(((((illumina[Platform]) AND rna seq[Strategy]) AND transcriptomic[Source]) AND public[Access]) NOT size fractionation[Selection])'
base_query = '(((illumina[Platform]) AND rna seq[Strategy]) NOT size fractionation[Selection])'
public_only = 'public[Access]'

parser = argparse.ArgumentParser(description='query NCBI SRA for run accessions associated with passed in study accessions, e.g. ERP001942')
parser.add_argument('--orgn', metavar='[SRA organism string]', type=str, default='human', help='biological organism to query ([default: human], mouse)')
parser.add_argument('--tmp', metavar='[path string]', type=str, default='/tmp', help='DTD files from SRA will be stored here, default="/tmp/<study>"')
parser.add_argument('--batch-size', metavar='[integer]', type=int, default=50, help='number of full records to retrieve in a single curl job')
parser.add_argument('--study', metavar='[accession string]', type=str, help='search for a single SRA accession (typically a study one e.g. ERP001942)')

parser.add_argument('--exclude-protected', action='store_const', const=True, default=False, help='will query only from public, default will include protected (dbGaP) as well as public runs')

parser.add_argument('--base-query', metavar='[SRA query string]', type=str, default=None, help='override base query, default: \'%s\'' % base_query)

args = parser.parse_args()

args.tmp=args.tmp+'/'+args.study
os.makedirs(args.tmp, exist_ok=True)

if args.exclude_protected:
    base_query = '(' + base_query + ' AND ' + public_only + ')'

if args.study is not None:
    base_query = '(' + base_query + ' AND %s[Accession])' % args.study

if args.base_query is not None:
    base_query = args.base_query

patt = re.compile(r'\s+')
orgn_nospace = 'all_organisms'
if args.orgn != 'all':
    orgn_nospace = re.sub(patt, r'_', args.orgn)
    base_query += " AND %s[Organism]" % args.orgn

es_ = e.esearch(db='sra', term=base_query, usehistory='y')
#workaround for non-home directories for writing DTDs locally:
#https://github.com/biopython/biopython/issues/918
def _Entrez_read(handle, validate=True, escape=False):
    from Bio.Entrez import Parser
    from Bio import Entrez
    handler = Entrez.Parser.DataHandler(validate, escape)
    handler.directory = args.tmp # the only difference between this and `Entrez.read`
    record = handler.read(handle)
    return record
es = _Entrez_read(es_)

#number of records is # of EXPERIMENTs (SRX) NOT # RUNs (SRR)
total_records = int(es["Count"])
sys.stderr.write("Total # of records is %d for %s using query %s\n" % (total_records, args.orgn, base_query))

num_fetches = int(total_records / args.batch_size) + 1

try:
    for retstart_idx in range(0,num_fetches):
        start_idx = retstart_idx * args.batch_size
        end_idx = (start_idx + args.batch_size)-1
        fetch_handle = e.efetch(db='sra',retstart=start_idx, retmax=args.batch_size,retmode='xml',webenv=es['WebEnv'],query_key=es['QueryKey'])
        #biopython's Entrez module doesn't parse SRA's raw XML return format
        #so use Python's built-in ElementTree parser
        root = ET.fromstring(fetch_handle.read())
        #Top Level: EXPERIMENT_PACKAGE
        for exp in root.findall('EXPERIMENT_PACKAGE'):
            #<RUN alias="GSM2837679_r1" accession="SRR6246154...
            run_set = exp.find('RUN_SET')
            exp = run_set
            for run in exp.findall('RUN'):
                run_acc = run.get('accession',default="")
                if len(run_acc) == 0:
                    continue
                #useful fields for the future
                #published = run.get('published', default="")
                #size = run.get('size', default="")
                #total_bases = run.get('total_bases', default="")
                #total_spots = run.get('total_spots', default="")
                sys.stdout.write(run_acc+"\n")
except Exception as e:
    raise e
finally:
    #cleanup
    shutil.rmtree(args.tmp, ignore_errors=True)
