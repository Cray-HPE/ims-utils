#! /usr/bin/env python3
#
# MIT License
#
# (C) Copyright 2018-2023 Hewlett Packard Enterprise Development LP
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
# Cray Image Management Service - Wait for repos referenced in the kiwi-ng recipe to be available

import logging
import os
import sys

from ims_python_helper.wait_for_kiwi_repos import wait_for_kiwi_repos

DEFAULT_LOG_LEVEL = 'INFO'
DEFAULT_API_GW_PROTOCOL = 'https'
DEFAULT_API_GW_HOST = 'api-gw-service-nmn.local'
DEFAULT_IMS_URL = '%s://%s/apis/ims' % (DEFAULT_API_GW_PROTOCOL, DEFAULT_API_GW_HOST)


def _setup_logging(logger: logging.Logger) -> None:
    log_format = "%(asctime)-15s - %(levelname)-7s - %(name)s - %(message)s"
    requested_log_level = os.environ.get("LOG_LEVEL", DEFAULT_LOG_LEVEL).upper()
    log_level = logging.getLevelName(requested_log_level)

    bad_log_level = None
    if type(log_level) != int:
        bad_log_level = requested_log_level
        log_level = getattr(logging, DEFAULT_LOG_LEVEL)
    logging.basicConfig(level=log_level, format=log_format)

    if bad_log_level:
        logger.warning('Log level %r is not valid. Falling back to %r', bad_log_level, DEFAULT_LOG_LEVEL)

def main():
    """ Main function """
    try:
        ca_cert = os.environ.get("CA_CERT", None)
        timeout = int(os.environ.get("TIMEOUT", 500))
        recipe_root = os.environ["RECIPE_ROOT_PARENT"]
        ims_job_id = os.environ.get("IMS_JOB_ID", None)
        ims_url = os.environ.get("IMS_URL", DEFAULT_IMS_URL)
    except KeyError as ke:
        sys.exit("Missing required environment variable: %s" % ke)

    # create and customize the logger
    logger = logging.getLogger(__name__)
    _setup_logging(logger)

    # check for the repos
    return wait_for_kiwi_repos(ims_job_id, ims_url, ca_cert, recipe_root, timeout, logger)

if __name__ == "__main__":
    sys.exit(main())
