#!/usr/bin/env sh
# Copyright 2019-2020, Cray Inc.

function set_job_status() {
  local status=$1
  python3 -m ims_python_helper image set_job_status $IMS_JOB_ID $status
  if [[ $? -ne 0 ]]; then
    echo "Warning: Could not set job status for job $IMS_JOB_ID to $status"
  fi
}

function fail_if_error() {
  local retVal=$?
  if [[ $retVal -ne 0 ]]; then
    echo "Error: $1 return_code = $retVal"
    set_job_status "error"
    exit $retVal
  fi
}
