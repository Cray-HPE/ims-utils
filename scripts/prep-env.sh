#!/bin/bash
#
# MIT License
#
# (C) Copyright 2018-2025 Hewlett Packard Enterprise Development LP
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

REMOTE_PORT_FILE=$IMAGE_ROOT_PARENT/remote_port
REMOTE_PORT=""
FIRST_REMOTE_PORT="2022"

function find_free_port {
    # Set up the regex search to pull the port for NAT iptable rules.
    # NOTE: this is safer than querying podman since other applications may be using ports
    #    or podman may not clean up ports properly.
    # NOTE: lines with ports expected to be something like (output from iptables):
    # "0 0 CNI-HOSTPORT-SETMARK  tcp  --  *  *   127.0.0.1  0.0.0.0/0  tcp dpt:2022"
    # "0 0 DNAT                  tcp  --  *  *   0.0.0.0/0  0.0.0.0/0  tcp dpt:2022 to:10.88.0.15:22"
    re="^(.*)tcp dpt:([0-9]{4})$"

    # get a list of all ports currently in use
    allPorts=()
    while read -r i; do
        if [[ "${i}" =~ $re && -n ${BASH_REMATCH[1]} && -n ${BASH_REMATCH[2]} ]] ; then
            allPorts+=(${BASH_REMATCH[2]})
        fi
    done < <(ssh  -o StrictHostKeyChecking=no "root@${REMOTE_BUILD_NODE}" "iptables -L -v -n -t nat")

    # sort the ports and remove duplicates
    allPorts=($(printf "%s\n" "${allPorts[@]}" | sort -u))

    # Find an available port, starting at FIRST_REMOTE_PORT
    # NOTE: list is sorted, so first != in our search range we can take
    REMOTE_PORT=${FIRST_REMOTE_PORT}
    for value in "${allPorts[@]}"
    do
        if (( value < FIRST_REMOTE_PORT )); then
            # ignore ports below our starting point
            continue
        elif (( REMOTE_PORT != value )); then
            # found a gap - use this port
            break
        else
            # port is in use - try the next one
            (( ++REMOTE_PORT ))
            echo "Port ${value} in use, trying the next: ${REMOTE_PORT}"
        fi
    done
}

function prep_remote_build() {
    # prepare the ssh keys to access the remote node
    mkdir -p ~/.ssh
    cp /etc/cray/remote-keys/id_ecdsa ~/.ssh
    chmod 600 ~/.ssh/id_ecdsa
    ssh-keygen -y -f ~/.ssh/id_ecdsa > ~/.ssh/id_ecdsa.pub

    echo "Configuring remote job on host: $REMOTE_BUILD_NODE"

    # set the arch on this job
    PODMAN_ARCH="linux/amd64"
    if [ "$BUILD_ARCH" == "aarch64" ]; then
        PODMAN_ARCH="linux/arm64"
    fi

    # the presence of this dir will serve as notification there is a job underway on this remote node
    ssh -o StrictHostKeyChecking=no "root@${REMOTE_BUILD_NODE}" "mkdir -p /tmp/ims_${IMS_JOB_ID}/image/"

    # copy the squashfs file to the remote node
    scp -o StrictHostKeyChecking=no /mnt/image/image.sqsh "root@${REMOTE_BUILD_NODE}:/tmp/ims_${IMS_JOB_ID}/image/image.sqsh"
    if [[ $? -ne 0 ]]; then
      echo "Copying image to remote node failed - check available space on the remote node"
      exit 1
    fi

    # Make Cray's CA certificate a trusted system certificate within the container
    # This will not install the CA certificate into the kiwi image root.
    echo "setting up certs..."
    CA_CERT='/etc/cray/ca/certificate_authority.crt'
    if [[ -e $CA_CERT ]]; then
      cp $CA_CERT  /usr/local/share/ca-certificates
    else
      echo "The CA certificate file: $CA_CERT is missing"
      exit 1
    fi
    update-ca-certificates
    if [[ $? -ne 0 ]]; then
      echo "update-ca-certificates exited with return code: $RC"
      exit 1
    fi

    # Add user ssh public key to the remote node access public key
    # NOTE: /etc/cray/ims/authorized_keys is mounted from the ims job config map
    # NOTE: used in Dockerfile.remote to set up the ssh server on the remote container
    cat ~/.ssh/id_ecdsa.pub /etc/cray/authorized_keys >> /root/remote_authorized_keys

    # Apply env vars to dockerfile template
    (echo "cat <<EOF" ; cat Dockerfile.remote ; echo EOF ) | sh > Dockerfile

    # build the docker image
    podman build --platform ${PODMAN_ARCH} -t ims-remote-${IMS_JOB_ID}:1.0.0 .
    if [[ $? -ne 0 ]]; then
      echo "Remote image build failed with error code: $RC"
      exit 1
    fi

    # Copy docker image to remote node
    podman save ims-remote-${IMS_JOB_ID}:1.0.0 | ssh -o StrictHostKeyChecking=no root@${REMOTE_BUILD_NODE} podman load
    if [[ $? -ne 0 ]]; then
      echo "Copying image to remote node failed - check available space on the remote node"
      exit 1
    fi

    # There is a faint possibility another job will start between querying for
    # open ports and starting the remote container. Add a while loop to keep
    # trying when the port is in use.
    while [ true ]; do
      # find an empty port on the remote node
      find_free_port

      # start the image on the remote node
      # NOTE: this will just run indefinitely until a complete flag is created
      #  -p -> port forwarding into the container
      #  -v -> mount the image root dir into the container
      #  -name -> name the container so we can remove it later
      #  --privileged -> needed for dkms operations
      #  --detach -> run in the background
      ssh -o StrictHostKeyChecking=no "root@${REMOTE_BUILD_NODE}" "podman run -p ${REMOTE_PORT}:22 -v /tmp/ims_${IMS_JOB_ID}/image:/mnt/image:U,Z --name ims-${IMS_JOB_ID} --privileged --detach ims-remote-${IMS_JOB_ID}:1.0.0"

      # if the ssh command failed
      RC=$?
      if [[ RC -eq 255 ]]; then
        echo "Connection issue with remote host - starting remote job failed"
        exit 1
      elif [[ RC -eq 126 ]]; then
        # RC=126 means that the bind failed due to port already in use
        echo "Warning: Empty port failed to start job - trying again. RC: ${rc}"

        # since this is a named container, we need to remove the failed container before trying again
        ssh -o StrictHostKeyChecking=no root@${REMOTE_BUILD_NODE} "podman rm ims-${IMS_JOB_ID}"

        # something else may be using the first port podman thinks is free - try the next higher one
        FIRST_REMOTE_PORT=$((REMOTE_PORT + 1))

        sleep 5
      elif [[ RC -ne 0 ]]; then
        # failed for some other reason - bail
        echo "Error - unknown problem starting remote container. RC: ${rc} - job failed"
        exit 1
      else
        break
      fi

    done

    # write port to shared file so sshd container can pick it up
    echo "${REMOTE_PORT}" > "${REMOTE_PORT_FILE}"
}

# configure for remote build
if [[ -z ${REMOTE_BUILD_NODE} ]]; then
  UNPACK="True"
else
  UNPACK="False"
fi

# fetch the image from S3 - unpack if local job
python3 /scripts/fetch.py --image "${UNPACK}" "$@"
fail_if_error "Downloading image"

# if this is a remote job set up the remote server
if [[ -n "${REMOTE_BUILD_NODE}" ]]; then
  prep_remote_build
fi
