#!/bin/sh
#
# MIT License
#
# (C) Copyright 2018-2024 Hewlett Packard Enterprise Development LP
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
# Prepares the build environment used for customizing an image root.
#   Usage:
#     /scripts/prep-env.sh /mnt/image http://example.com/path/to/image.sqsh

set -x
source /scripts/helper.sh

function prep_remote_build() {
    # prepare the ssh keys to access the remote node
    mkdir -p ~/.ssh
    cp /etc/cray/remote-keys/id_ecdsa ~/.ssh
    chmod 600 ~/.ssh/id_ecdsa
    ssh-keygen -y -f ~/.ssh/id_ecdsa > ~/.ssh/id_ecdsa.pub

    echo "Configuring remote job on host: $REMOTE_BUILD_NODE"

    # the presence of this dir will serve as notification there is a job underway on this remote node 
    ssh -o StrictHostKeyChecking=no root@${REMOTE_BUILD_NODE} "mkdir -p /tmp/ims_${IMS_JOB_ID}/"

    # Make Cray's CA certificate a trusted system certificate within the container
    # This will not install the CA certificate into the kiwi imageroot.
    echo "setting up certs..."
    CA_CERT='/etc/cray/ca/certificate_authority.crt'
    if [[ -e $CA_CERT ]]; then
      cp $CA_CERT  /usr/local/share/ca-certificates
    else
      echo "The CA certificate file: $CA_CERT is missing"
      exit 1
    fi
    update-ca-certificates
    RC=$?
    if [[ ! $RC ]]; then
      echo "update-ca-certificates exited with return code: $RC"
      exit 1
    fi

    # Apply env vars to dockerfile template
    (echo "cat <<EOF" ; cat Dockerfile.remote ; echo EOF ) | sh > Dockerfile

    # build the docker image
    podman build -t ims-remote-${IMS_JOB_ID}:1.0.0 .
    RC=$?
    if [[ ! $RC ]]; then
      echo "Remote image build failed with error code: $RC"
      exit 1
    fi

    # Copy docker image to remote node
    podman save ims-remote-${IMS_JOB_ID}:1.0.0 | ssh -o StrictHostKeyChecking=no root@${REMOTE_BUILD_NODE} podman load
    RC=$?
    if [[ ! $RC ]]; then
      echo "Copying image to remote node failed"
      exit 1
    fi

    # start the image on the remote node
    # NOTE: this will just run indefinately until a complete flag is created
    # TODO: for now hard-coded to port 2022 - this only allows ONE customize job per node
    #          - must add code to look for an open port (ie run podman port -a, parse results)
    ssh -o StrictHostKeyChecking=no root@${REMOTE_BUILD_NODE} "podman run -p 2022:22 --name ims-${IMS_JOB_ID} --privileged --detach ims-remote-${IMS_JOB_ID}:1.0.0"
}

# configure for remote build
if [[ -z "${REMOTE_BUILD_NODE}" ]]; then
  UNPACK="True"
else
  UNPACK="False"
fi

# fetch the image from S3 - unpack if local job
python3 /scripts/fetch.py --image "$UNPACK" "$@"
fail_if_error "Downloading image"

# if this is a remote job set up the remote server
if [[ -n "${REMOTE_BUILD_NODE}" ]]; then
  prep_remote_build
fi
