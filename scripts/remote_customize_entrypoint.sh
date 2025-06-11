#!/bin/sh
#
# MIT License
#
# (C) Copyright 2023-2025 Hewlett Packard Enterprise Development LP
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

# Entrypoint script for remote customize image job
# NOTE: this is run from WITHIN the docker image running on the remote build node.
set -x
echo on

# Let the root dirs be overridden by arguments to the script
IMAGE_ROOT_PARENT=${2:-$IMAGE_ROOT_PARENT}
IMAGE_ROOT_DIR=${IMAGE_ROOT_DIR:-${IMAGE_ROOT_PARENT}/image-root/}

# set up file locations
SIGNAL_FILE_REMOTE_EXITING=$IMAGE_ROOT_PARENT/remote_exiting

SSHD_CONFIG_FILE=/etc/cray/ims/sshd_config

setup_resolv() {
    # Copy the container's /etc/resolv.conf to the image root for customization
    local IMAGE_ROOT_RESOLV=$IMAGE_ROOT_DIR/etc/resolv.conf
    local TMP_RESOLV=$IMAGE_ROOT_DIR/tmp/resolv.conf
    if [ -f "$IMAGE_ROOT_RESOLV" -o -L "$IMAGE_ROOT_RESOLV" ]; then
        mv "$IMAGE_ROOT_RESOLV" "$TMP_RESOLV"
    else
        echo "Did not find an existing /etc/resolv.conf file"
    fi
    cp --remove-destination /etc/resolv.conf "$IMAGE_ROOT_RESOLV"
}

restore_resolv() {
    # Restore the image root's old /etc/resolv.conf after customization
    local IMAGE_ROOT_RESOLV=$IMAGE_ROOT_DIR/etc/resolv.conf
    local TMP_RESOLV=$IMAGE_ROOT_DIR/tmp/resolv.conf
    rm "$IMAGE_ROOT_RESOLV"
    if [ -f "$TMP_RESOLV" -o -L "$TMP_RESOLV" ]; then
        mv "$TMP_RESOLV" "$IMAGE_ROOT_RESOLV"
    fi
}

copy_ca_root_key() {
    echo "Copying SMS CA Public Certificate to target image root"
    mkdir -p "$IMAGE_ROOT_DIR/etc/cray"
    cp -r /etc/cray/ca "$IMAGE_ROOT_DIR/etc/cray/"
}

# check the contents of the imported env vars
echo "Checking env vars"
IMPORTED_VALS=('OAUTH_CONFIG_DIR' 'BUILD_ARCH' 'IMS_JOB_ID' 'IMAGE_ROOT_PARENT')
for item in "${IMPORTED_VALS[@]}"; do
  if [[ -z "${!item}" ]]; then
    echo ERROR: $item not set in Environment
    exit 1
  fi
done

# Set up location of complete flag files depending on if this is a jailed env
## NOTE: there are 2 possible file locations going on here.
#  If this is a jailed env, then the user signal files will be in the /tmp dir of the jailed env
#  If this is not a jailed env, then the signal files will be in $IMAGE_ROOT_PARENT
#  The IMS pod will be looking in $IMAGE_ROOT_PARENT, so a jailed env will need to transfer
#   the signal files to the correct location
SIGNAL_FILE_COMPLETE=$IMAGE_ROOT_PARENT/complete
SIGNAL_FILE_FAILED=$IMAGE_ROOT_PARENT/failed
USER_SIGNAL_FILE_COMPLETE=$IMAGE_ROOT_PARENT/complete
USER_SIGNAL_FILE_FAILED=$IMAGE_ROOT_PARENT/failed
if [ "$SSH_JAIL" = "True" ]; then
  USER_SIGNAL_FILE_COMPLETE=${IMAGE_ROOT_DIR}tmp/complete
  USER_SIGNAL_FILE_FAILED=${IMAGE_ROOT_DIR}tmp/failed
fi

# Make Cray's CA certificate a trusted system certificate within the container
# This will not install the CA certificate into the kiwi imageroot.
echo "setting up certs..."
CA_CERT='/etc/cray/ca/certificate_authority.crt'
if [[ -e $CA_CERT ]]; then
  cp $CA_CERT  /usr/share/pki/trust/anchors/.
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

# unpack the image file
mkdir -p $IMAGE_ROOT_PARENT
unsquashfs -f -d $IMAGE_ROOT_DIR /data/image.sqsh

# clear any signal flags that were left in the image
rm $USER_SIGNAL_FILE_FAILED
rm $USER_SIGNAL_FILE_COMPLETE

# Copy cray certs into image
copy_ca_root_key

# Copy the container's resolv.conf to the image root
setup_resolv

# If setting up for dkms permissions, do that now
echo "JOB_ENABLE_DKMS: $JOB_ENABLE_DKMS"
is_dkms=$(echo $JOB_ENABLE_DKMS | tr '[:upper:]' '[:lower:]')
echo "is_dkms=$is_dkms"
if [ "$is_dkms" = "true" ]; then
    if mount -t sysfs /sysfs /mnt/image/image-root/sys; then
        echo "Mounted /sys"
    else
        echo "Failed to mount /sys"
    fi
    if mount -t proc /proc /mnt/image/image-root/proc; then
        echo "Mounted /proc"
    else
        echo "Failed to mount /proc"
    fi
    if mount -t devtmpfs /devtmpfs /mnt/image/image-root/dev; then
        echo "Mounted /dev"
    else
        echo "Failed to mount /dev"
    fi
else
    echo "DKMS not enabled"
fi

# Configure the sshd_config file for jailed chroot dir if needed
if [ "$SSH_JAIL" = "True" ]; then
  echo "ChrootDirectory $IMAGE_ROOT_DIR" >> $SSHD_CONFIG_FILE
fi

# set up keys for ssh access
mkdir -p ~/.ssh
ssh-keygen -A

# add env vars the incoming users need
echo "SetEnv IMS_JOB_ID=$IMS_JOB_ID IMS_ARCH=$BUILD_ARCH IMS_DKMS_ENABLED=$JOB_ENABLE_DKMS" >> $SSHD_CONFIG_FILE

# Start the SSH server daemon
/usr/sbin/sshd -E /etc/cray/ims/sshd.log -f $SSHD_CONFIG_FILE

# don't spam the log with waiting on user
set +x
echo off
echo "Waiting for signal file"

# set up trap for termination signals
trap "echo TERM; exit 1" SIGTERM SIGINT

# Wait for the user to signal they are done
until [ -f "$USER_SIGNAL_FILE_COMPLETE" ] || [ -f "$USER_SIGNAL_FILE_FAILED" ]
do
  sleep 5;
done

# enable logging for the final packaging
set -x
echo on

# if dkms was used, unmount the extra dirs before packaging
if [ "$is_dkms" = "true" ]; then
  echo "Unmounting system directories"
  if umount /mnt/image/image-root/sys; then
    echo "Unmounted /sys"
  else
    echo "Failed to unmount /sys"
  fi
  if umount /mnt/image/image-root/proc; then
    echo "Unmounted /proc"
  else
    echo "Failed to unmount /proc"
  fi
  if umount /mnt/image/image-root/dev; then
    echo "Unmounted /dev"
  else
    echo "Failed to unmount /dev"
  fi
fi

# restore the original resolv.conf if there was one
restore_resolv

# if successful, package up the results into a squashfs file to transfer back to worker node
if [ -f "$USER_SIGNAL_FILE_COMPLETE" ]; then
  # Remove the signal flags before squash and put failed flag in place in case squash fails
  # NOTE: the sshd entrypoint script will be waiting for $SIGNAL_FILE_REMOTE_EXITING
  rm $USER_SIGNAL_FILE_FAILED
  rm $USER_SIGNAL_FILE_COMPLETE
  touch $SIGNAL_FILE_FAILED

  # Make the squashfs formatted archive to transfer results back to job
  time mksquashfs "$IMAGE_ROOT_DIR" "$IMAGE_ROOT_PARENT/transfer.sqsh"
  RC=$?

  # handle if the squash fails
  if [[ ! $RC ]]; then
    # Already marked as error - just exit
    echo "ERROR: Squashfs reported an error."
  else
    # success, so remove failed flag and add success flag file
    rm $SIGNAL_FILE_FAILED
    touch $SIGNAL_FILE_COMPLETE
  fi
else
  # failed so set the correct signal files
  rm $USER_SIGNAL_FILE_FAILED
  touch $SIGNAL_FILE_FAILED
fi

# Signal that this is finished
touch $SIGNAL_FILE_REMOTE_EXITING

exit 0
