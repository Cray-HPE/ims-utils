#!/usr/bin/env sh
#
# MIT License
#
# (C) Copyright 2019-2022, 2025 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
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

function check_image_artifact_exists() {
  local FILE=$1
  if [[ ! -f $FILE ]]; then
    echo "Error: Image artifact $FILE does not exist or is not a regular file."
    set_job_status "error"
    exit 1
  fi
}

# Set up the resolv.conf file for the image root
# This is used to ensure that the image root can resolve DNS names during customization.
function setup_resolv() {
    # Copy the container's /etc/resolv.conf to the image root for customization
    local IMAGE_ROOT_DIR=$1
    local IMAGE_ROOT_RESOLV=${IMAGE_ROOT_DIR}/etc/resolv.conf
    local TMP_RESOLV=${IMAGE_ROOT_DIR}/tmp/resolv.conf

    # Validate input parameter
    if [[ -z $IMAGE_ROOT_DIR || ! -d $IMAGE_ROOT_DIR ]]; then
        echo "Error: Invalid or missing image root directory: ${IMAGE_ROOT_DIR}"
        return 1
    fi

    # Ensure required directories exist
    if [[ ! -d $IMAGE_ROOT_DIR/etc ]]; then
        echo "Error: /etc directory not found in image root"
        return 1
    fi

    if [[ ! -d $IMAGE_ROOT_DIR/tmp ]]; then
        echo "Creating tmp directory in image root"
        mkdir -p "${IMAGE_ROOT_DIR}/tmp" || {
            echo "Error: Failed to create tmp directory in image root"
            return 1
        }
    fi

    if [[ -f $IMAGE_ROOT_RESOLV || -L $IMAGE_ROOT_RESOLV ]]; then
        mv "$IMAGE_ROOT_RESOLV" "$TMP_RESOLV"
    fi
    cp -v --remove-destination /etc/resolv.conf "${IMAGE_ROOT_RESOLV}"
}

# Restore the image root's old /etc/resolv.conf after customization
function restore_resolv() {
    # Restore the image root's old /etc/resolv.conf after customization
    local IMAGE_ROOT_DIR=$1
    if [[ ! -d $IMAGE_ROOT_DIR ]]; then
        echo "Error: Invalid or missing image root directory: ${IMAGE_ROOT_DIR}"
        return 0
    fi

    # Remove the installed resolv.conf
    local IMAGE_ROOT_RESOLV=${IMAGE_ROOT_DIR}/etc/resolv.conf
    local TMP_RESOLV=${IMAGE_ROOT_DIR}/tmp/resolv.conf
    rm "${IMAGE_ROOT_RESOLV}"

    # Restore the original resolv.conf if it existed
    if [[ -f $TMP_RESOLV || -L $TMP_RESOLV ]]; then
        mv "$TMP_RESOLV" "$IMAGE_ROOT_RESOLV"
    fi
}

# Fix permissions on /image dir if it exists
function check_image_dir() {
    # Change ownership and permissions on /image dir if it exists.
    #  This dir contains config files that may have sensitive information
    #  in them and should only be readable by root.
    local IMAGE_ROOT_DIR=$1
    if [[ -d ${IMAGE_ROOT_DIR}/image ]]; then
      # change read/write permissions of dir to root only
      chown root "${IMAGE_ROOT_DIR}/image"
      chmod 700 "${IMAGE_ROOT_DIR}/image"

      # change files in the dir to root ownership and only rw for root
      chown root "${IMAGE_ROOT_DIR}/image/*"
      chmod 600 "${IMAGE_ROOT_DIR}/image/*"

      # change the .sh file to rwx for root
      chmod 700 "${IMAGE_ROOT_DIR}/image/*.sh"
    fi
}

# Wait for a file to be created to proceed
function wait_for_file() {
    # Wait for the user to signal they are done
    echo "Waiting for $1 to be created"
    until [[ -e $1 ]]
    do
      sleep 5;
    done
}
