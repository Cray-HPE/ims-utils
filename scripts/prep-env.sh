#!/usr/bin/env sh
# Copyright 2018-2020, Cray Inc.
# Prepares the build environment used for customizing an image root.
#   Usage:
#     /scripts/prep-env.sh /mnt/image http://example.com/path/to/image.sqsh

source /scripts/helper.sh
python3 /scripts/fetch.py --image "$@"
fail_if_error "Downloading image"