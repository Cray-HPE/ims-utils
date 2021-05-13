#!/bin/sh
# Copyright 2018-2021 Hewlett Packard Enterprise Development LP
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# (MIT License)
set -x

# This script performs the following actions:
#
#   1. Copy the CA Public certificate into the target image root
#   2. Creates a Squashfs archive of the target image root
#   3. Uploads the image root squashfs archive, kernel, and initrd to ARS.
#
# The following environment variables can be used to modify the location and names
# of artifacts: IMAGE_ROOT_PARENT, KERNEL_FILENAME, INITRD_FILENAME.
#
#   Usage:
#     /scripts/package_and_upload.sh

source /scripts/helper.sh

IMS_PYTHON_HELPER_TIMEOUT=${IMS_PYTHON_HELPER_TIMEOUT:-720}
IMAGE_ROOT_PARENT=${IMAGE_ROOT_PARENT:-/mnt/image}
IMAGE_ROOT_DIR=${IMAGE_ROOT_DIR:-/mnt/image/build/image-root/}
KERNEL_FILENAME=${KERNEL_FILENAME:-vmlinuz}
INITRD_FILENAME=${INITRD_FILENAME:-initrd}
IMAGE_ROOT_ARCHIVE_NAME=${IMAGE_ROOT_ARCHIVE_NAME:-$KIWI_RECIPE_NAME}

# Set ims job status
set_job_status "packaging_artifacts"

check_image_artifact_exists() {
  local FILE=$1
  if [[ ! -f "$FILE" ]]; then
    echo "Error: Image artifact $FILE does not exist."
    set_job_status "error"
    exit 1
  fi
}

check_image_artifact_exists "$IMAGE_ROOT_DIR/boot/$KERNEL_FILENAME"
check_image_artifact_exists "$IMAGE_ROOT_DIR/boot/$INITRD_FILENAME"

# Make the squashfs formatted archive
time mksquashfs "$IMAGE_ROOT_DIR" "$IMAGE_ROOT_PARENT/$IMAGE_ROOT_ARCHIVE_NAME.sqsh"
fail_if_error "Creating squashfs of image root"

# Check to see if we have a kernel-parameters file. If so, upload the rootfs, initrd, kernel and kernel-parameters file
if [[ -n "$KERNEL_PARAMETERS_FILENAME" ]]; then
  if [[ -f "$IMAGE_ROOT_DIR/boot/$KERNEL_PARAMETERS_FILENAME" ]]; then
    # Upload the artifacts, including the boot parameters file
    echo "Found /boot/$KERNEL_PARAMETERS_FILENAME."
    echo "Uploading 4 image artifacts."
    time python3 -m ims_python_helper image upload_artifacts "$IMAGE_ROOT_ARCHIVE_NAME" "$IMS_JOB_ID" \
      -t "$IMS_PYTHON_HELPER_TIMEOUT" \
      -r "$IMAGE_ROOT_PARENT/$IMAGE_ROOT_ARCHIVE_NAME.sqsh" \
      -k "$IMAGE_ROOT_DIR/boot/$KERNEL_FILENAME" \
      -i "$IMAGE_ROOT_DIR/boot/$INITRD_FILENAME" \
      -p "$IMAGE_ROOT_DIR/boot/$KERNEL_PARAMETERS_FILENAME"
    fail_if_error "Uploading and registering IMS artifacts"
    exit 0
  fi
  echo "Did not find /boot/$KERNEL_PARAMETERS_FILENAME"
  fi

# There was no kernel-parameters file found, so just upload the rootfs, initrd and kernel.
echo "Uploading 3 image artifacts."
time python3 -m ims_python_helper image upload_artifacts "$IMAGE_ROOT_ARCHIVE_NAME" "$IMS_JOB_ID" \
  -t "$IMS_PYTHON_HELPER_TIMEOUT" \
  -r "$IMAGE_ROOT_PARENT/$IMAGE_ROOT_ARCHIVE_NAME.sqsh" \
  -k "$IMAGE_ROOT_DIR/boot/$KERNEL_FILENAME" \
  -i "$IMAGE_ROOT_DIR/boot/$INITRD_FILENAME"
fail_if_error "Uploading and registering IMS artifacts"
exit 0
