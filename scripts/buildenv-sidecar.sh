#!/bin/sh
#
# MIT License
#
# (C) Copyright 2018-2022, 2024 Hewlett Packard Enterprise Development LP
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
# "Entrypoint" script for the build environment sidecar container used
# in the image customization process.
#
#   Usage:
#     /scripts/buildenv-sidecar.sh [/mnt/image]
#
# +--------------------------------------------+         +--------------------------------------------+
# |             Sidecar Container              |         |                SSH Container               |
# +--------------------------------------------+         +--------------------------------------------+
# |                                            |         |                                            |
# |  1. Sidecar container creates              |         |                                            |
# |     SSHD and authorized_keys               |         |                                            |
# |     config files in shared                 |         |                                            |
# |     /etc/cray/ims volume                   |         |                                            |
# |  2. Remove SIGNAL_FILE_COMPLETE            |         |                                            |
# |     and SIGNAL_FILE_EXITING flags          |         |                                            |
# |     if they exist.                         |         |                                            |
# |  3. Touch SIGNAL_FILE_READY +-------------------------> 4. Wait for $SIGNAL_FILE_READY            |
# |                                            |         |  5. Start SSHD daemon using config <---------+ User accesses SSH environment
# |                                            |         |     files in /etc/cray/ims shared          |
# |                                            |         |     volume (see $SSHD_OPTIONS)             |
# |                                            |         |  6. Wait for user to touch  <----------------+ User touches SIGNAL_FILE_COMPLETE file
# |                                            |         |     $SIGNAL_FILE_COMPLETE or               |
# |                                            |         |     $SIGNAL_FILE_FAILED                    |
# |                                            |         |  7. Start orderly shutdown of SSH          |
# |                                            |         |     Container                              |
# |                                            |         |     a) Remove SIGNAL_FILE_COMPLETE file    |
# |  8. Wait for SIGNAL_FILE_EXITING <-----------------------+ b) Touch SIGNAL_FILE_EXITING           |
# |  9. Remove SIGNAL_FILE_EXITING file        |         |                                            |
# | 10. Remove SIGNAL_FILE_COMPLETE file       |         |                                            |
# |     (should be removed by SSH Container,   |         |                                            |
# |      but just in case...)                  |         |                                            |
# | 11. Call package_and_upload.sh if          |         |                                            |
# |     appropriate.                           |         |                                            |
# |                                            |         |                                            |
# +--------------------------------------------+         +--------------------------------------------+

set -e
source /scripts/helper.sh

IMAGE_ROOT_PARENT=$1
SIGNAL_FILE_READY=$IMAGE_ROOT_PARENT/ready
SIGNAL_FILE_COMPLETE=$IMAGE_ROOT_PARENT/complete
SIGNAL_FILE_EXITING=$IMAGE_ROOT_PARENT/exiting
SIGNAL_FILE_FAILED=$IMAGE_ROOT_PARENT/failed

PARAMETER_FILE_BUILD_FAILED=$IMAGE_ROOT_PARENT/build_failed

# Make the parent directory where the build environment signal files
mkdir -p "$IMAGE_ROOT_PARENT"

copy_ca_root_key() {
    local IMAGE_ROOT_DIR=$1
    echo "Copying SMS CA Public Certificate to target image root"
    mkdir -p "$IMAGE_ROOT_DIR/etc/cray"
    cp -r /etc/cray/ca "$IMAGE_ROOT_DIR/etc/cray/"
    fail_if_error "Creating SMS CA Public Key directory"
}

setup_user_shell() {
    # Copy the default SSHD configuration into a shared volume with the buildenv
    cp /config/sshd_config /etc/cray/ims/sshd_config

    # Copy the public key for SSH access into the shared volume
    # This comes from a Kubernetes secret.
    cp /etc/cray/authorized_keys /etc/cray/ims/

    # Set the permissions on the folder holding the keys
    chmod 600 /etc/cray/ims

    # Change signal location if user if jailed and not running on remote
    if [ "$SSH_JAIL" = "True" -a -z "$REMOTE_BUILD_NODE"]
    then
        SIGNAL_FILE_COMPLETE=$IMAGE_ROOT_PARENT/image-root/tmp/complete
        SIGNAL_FILE_FAILED=$IMAGE_ROOT_PARENT/image-root/tmp/failed
    fi

    # Make sure that the signal file doesn't exist yet
    if [ -f "$SIGNAL_FILE_COMPLETE" ]
    then
        echo "Found $SIGNAL_FILE_COMPLETE. Removing."
        rm "$SIGNAL_FILE_COMPLETE"
    fi

    # Make sure that the signal file doesn't exist yet
    if [ -f "$SIGNAL_FILE_FAILED" ]
    then
        echo "Found $SIGNAL_FILE_FAILED. Removing."
        rm "$SIGNAL_FILE_FAILED"
    fi

    # Make sure that the signal file doesn't exist yet
    if [ -f "$SIGNAL_FILE_EXITING" ]
    then
        echo "Found $SIGNAL_FILE_EXITING. Removing."
        rm "$SIGNAL_FILE_EXITING"
    fi

    # Give user instructions on how to exit this script
    echo "IMS SSH shell environment is ready."
    echo "To mark this shell as successful, touch the file \"$SIGNAL_FILE_COMPLETE\"."
    echo "To mark this shell as failed, touch the file \"$SIGNAL_FILE_FAILED\"."
    echo "Waiting for User to mark this shell as either successful or failed."
    echo ""

    # Signal that the buildenv is ready and enter wait loop
    touch "$SIGNAL_FILE_READY"

    # Sleep for changing the status in case the buildenv is still sleeping in the wait_for_ready loop
    sleep 5;
    set_job_status "waiting_on_user"

    echo "Waiting for SSH container to set $SIGNAL_FILE_EXITING flag"
    until [ -f "$SIGNAL_FILE_EXITING" ]
    do
        sleep 5;
    done
    echo "SSH Shell is exiting; tearing down build environment"

    # Remove the exiting file now that we're done
    echo "Removing $SIGNAL_FILE_EXITING"
    rm "$SIGNAL_FILE_EXITING"

    # SSH Container should have already removed the complete flag, but just in case
    if [ -f "$SIGNAL_FILE_COMPLETE" ]
    then
        echo "Found $SIGNAL_FILE_COMPLETE. Removing."
        rm "$SIGNAL_FILE_COMPLETE"
    fi
}

setup_resolv() {
    # Copy the container's /etc/resolv.conf to the image root for customization
    local IMAGE_ROOT_DIR=$1
    local IMAGE_ROOT_RESOLV=$IMAGE_ROOT_DIR/etc/resolv.conf
    local TMP_RESOLV=$IMAGE_ROOT_DIR/tmp/resolv.conf
    if [ -f "$IMAGE_ROOT_RESOLV" -o -L "$IMAGE_ROOT_RESOLV" ]; then
        mv "$IMAGE_ROOT_RESOLV" "$TMP_RESOLV"
    fi
    cp --remove-destination /etc/resolv.conf "$IMAGE_ROOT_RESOLV"
}

restore_resolv() {
    # Restore the image root's old /etc/resolv.conf after customization
    local IMAGE_ROOT_DIR=$1
    local IMAGE_ROOT_RESOLV=$IMAGE_ROOT_DIR/etc/resolv.conf
    local TMP_RESOLV=$IMAGE_ROOT_DIR/tmp/resolv.conf
    rm "$IMAGE_ROOT_RESOLV"
    if [ -f "$TMP_RESOLV" -o -L "$TMP_RESOLV" ]; then
        mv "$TMP_RESOLV" "$IMAGE_ROOT_RESOLV"
    fi
}

case "$IMS_ACTION" in
    create)
        if [ -f "$PARAMETER_FILE_BUILD_FAILED" ]; then
            if [[ $(echo "$ENABLE_DEBUG" | tr [:upper:] [:lower:]) = "true" ]]; then
                echo "Running user shell for failed create action"
                setup_user_shell
            else
                echo "Not running user shell for failed create action"
            fi

            set_job_status "error"
            exit 1
        else
            echo "Not running user shell for successful create action"

            # copy ca root key into the image after Kiwi has run
            copy_ca_root_key "$IMAGE_ROOT_PARENT/build/image-root"

            # Package the image and send it back to the artifact repository
            IMAGE_ROOT_DIR=$IMAGE_ROOT_PARENT/build/image-root /scripts/package_and_upload.sh
            fail_if_error "Packaging and uploading image create artifacts"
            set_job_status "success"
        fi
        ;;
    customize)
        # copy ca root key into the image before user shell if running locally
        if [[ -z "${REMOTE_BUILD_NODE}" ]]; then
            copy_ca_root_key "$IMAGE_ROOT_PARENT/image-root"
            setup_resolv "$IMAGE_ROOT_PARENT/image-root"
        fi

        echo "Running user shell for customize action"
        setup_user_shell
        
        # only restore the resolv file if running locally
        if [[ -z "${REMOTE_BUILD_NODE}" ]]; then
            restore_resolv "$IMAGE_ROOT_PARENT/image-root"
        fi

        if [ -f "$SIGNAL_FILE_FAILED" ]; then
            echo "Customization of image root marked as failed. A new IMS image will not be created."
            set_job_status "error"
        else
            # Package the image and send it back to the artifact repository
            IMAGE_ROOT_DIR=$IMAGE_ROOT_PARENT/image-root /scripts/package_and_upload.sh
            fail_if_error "Packaging and uploading image customize artifacts"
            set_job_status "success"
        fi
        ;;
     *)
        echo "Unknown IMS Action: $IMS_ACTION. Not running user shell."
        set_job_status "error"
        exit 1
        ;;
esac


