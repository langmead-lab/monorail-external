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

def count_queued(job_tag, user='cwilks'):
    return int(subprocess.check_output('squeue -u %s | grep %s | wc -l' % (user,job_tag),shell=True))

def check_capacity(limit, job_tag, user='cwilks'):
    queued = count_queued(job_tag, user=user)
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
    user = 'cwilks'
    if len(sys.argv) > 1:
        user = sys.argv[1]
    script = 'job-skx-normal_short.sh' 
    if len(sys.argv) > 2:
        script = sys.argv[2]
    while(True):
        capacity = check_capacity(TOTAL, JOB_TAG, user=user)
        sys.stdout.write("capacity is %d\n" % capacity)
        current_idx = submit_new_jobs(capacity, 'sbatch %s' % script, 0)
        time.sleep(TIME_TO_SLEEP)
