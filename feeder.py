#!/bin/env python2.7
import sys
import os
import time
import subprocess

#sleep for 1 min.
TIME_TO_SLEEP=60

#total number of concurrent jobs (either running or pending)
TOTAL=25
JOB_TAG='skx-normal'
STARTING_IDX=0
#JOB_LIST_FILE='gtf.jobs.remaining'

def count_queued(job_tag):
    return int(subprocess.check_output('squeue -u cwilks | grep %s | wc -l' % job_tag,shell=True))

def check_capacity(limit, job_tag):
    queued = count_queued(job_tag)
    return limit - queued

def submit_job(job_str):
    subprocess.call(job_str, shell=True)

def submit_new_jobs(capacity, job_str, current_idx):
    if capacity <= 0:
        return current_idx
    for i in range(0,capacity):
        submit_job(job_str)
    return current_idx + capacity

if __name__ == '__main__':
    while(True):
        capacity = check_capacity(TOTAL, JOB_TAG)
        sys.stdout.write("capacity is %d\n" % capacity)
        current_idx = submit_new_jobs(capacity, 'sbatch job-skx-normal_short.sh', 0)
        time.sleep(TIME_TO_SLEEP)
