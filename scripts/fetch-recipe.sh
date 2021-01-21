#!/usr/bin/env sh
# Copyright 2019-2020, Cray Inc.
# Prepares the build environment used for creating an image root.
#   Usage:
#     /scripts/fetch-recipe.sh /mnt/recipe http://example.com/path/to/recipe.tgz

source /scripts/helper.sh
python3 /scripts/fetch.py --recipe "$@"
fail_if_error "Downloading recipe"