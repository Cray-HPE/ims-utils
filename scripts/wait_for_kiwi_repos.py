#! /usr/bin/env python3
# Cray Image Management Service - Wait for repos referenced in the kiwi-ng recipe to be available
# Copyright 2018-2020, Cray Inc.

import logging
import oauthlib.oauth2
import os
import requests
import requests_oauthlib
import sys
import time
import xml.etree.ElementTree as ET
from ims_python_helper import ImsHelper
from requests.packages.urllib3.exceptions import InsecureRequestWarning

LOGGER = logging.getLogger(__name__)

IMS_JOB_STATUS = "waiting_for_repos"
DEFAULT_LOG_LEVEL = 'INFO'
DEFAULT_API_GW_PROTOCOL = 'https'
DEFAULT_API_GW_HOST = 'api-gw-service-nmn.local'
DEFAULT_IMS_URL = '%s://%s/apis/ims' % (DEFAULT_API_GW_PROTOCOL, DEFAULT_API_GW_HOST)


def _setup_logging():
    log_format = "%(asctime)-15s - %(levelname)-7s - %(name)s - %(message)s"
    requested_log_level = os.environ.get("LOG_LEVEL", DEFAULT_LOG_LEVEL).upper()
    log_level = logging.getLevelName(requested_log_level)

    bad_log_level = None
    if type(log_level) != int:
        bad_log_level = requested_log_level
        log_level = getattr(logging, DEFAULT_LOG_LEVEL)
    logging.basicConfig(level=log_level, format=log_format)

    if bad_log_level:
        LOGGER.warning('Log level %r is not valid. Falling back to %r', bad_log_level, DEFAULT_LOG_LEVEL)


def _set_ims_job_status(ims_job_id, ims_url, session):
    try:
        if ims_job_id:
            LOGGER.info("Setting job status to '%s'", IMS_JOB_STATUS)
            result = ImsHelper(
                ims_url=ims_url,
                session=session,
                s3_host=os.environ.get('S3_HOST', None),
                s3_secret_key=os.environ.get('S3_SECRET_KEY', None),
                s3_access_key=os.environ.get('S3_ACCESS_KEY', None),
                s3_bucket=os.environ.get('S3_BUCKET', None)
            )._ims_job_patch_job_status(ims_job_id, IMS_JOB_STATUS)
            LOGGER.info("Result of setting job status: %s", result)
    except requests.exceptions.HTTPError as exc:
        LOGGER.warn("Error setting job status %s" % exc)


def log_request(resp, *args, **kwargs):
    """
    This function logs the request.

    Args:
        resp : The response
    """
    if LOGGER.isEnabledFor(logging.DEBUG):
        LOGGER.debug('\n%s\n%s\n%s\n\n%s',
                     '-----------START REQUEST-----------',
                     resp.request.method + ' ' + resp.request.url,
                     '\n'.join('{}: {}'.format(k, v) for k, v in list(resp.request.headers.items())),
                     resp.request.body)


def log_response(resp, *args, **kwargs):
    """
    This function logs the response.

    Args:
        resp : The response
    """
    if LOGGER.isEnabledFor(logging.DEBUG):
        LOGGER.debug('\n%s\n%s\n%s\n\n%s',
                     '-----------START RESPONSE----------',
                     resp.status_code,
                     '\n'.join('{}: {}'.format(k, v) for k, v in list(resp.headers.items())),
                     resp.content)


def _create_session(ssl_cert):
    """ Create Session object and set verify and hook options. """
    session = requests.Session()
    session.verify = ssl_cert
    session.hooks['response'].append(log_request)
    session.hooks['response'].append(log_response)

    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
    if not ssl_cert:
        LOGGER.warn("Warning: Unverified HTTPS request is being made. Use CA_CERT environment variable "
                    "to add certificate verification.")

    return session


def _get_admin_client_auth():
    """
    This function loads the information necessary to authenticate and obtain an oauth
    credential needed to talk to various services behind the api-gateway.
    :return: tuple of oauth_client_id, oauth_client_secret, oauth_client_endpoint
    """
    default_oauth_client_id = ""
    default_oauth_client_secret = ""
    default_oauth_endpoint = ""

    oauth_config_dir = os.environ.get("OAUTH_CONFIG_DIR", "/etc/admin-client-auth")
    if os.path.isdir(oauth_config_dir):
        oauth_client_id_path = os.path.join(oauth_config_dir, 'client-id')
        if os.path.exists(oauth_client_id_path):
            with open(oauth_client_id_path) as auth_client_id_f:
                default_oauth_client_id = auth_client_id_f.read().strip()
        oauth_client_secret_path = os.path.join(oauth_config_dir, 'client-secret')
        if os.path.exists(oauth_client_secret_path):
            with open(oauth_client_secret_path) as oauth_client_secret_f:
                default_oauth_client_secret = oauth_client_secret_f.read().strip()
        oauth_endpoint_path = os.path.join(oauth_config_dir, 'endpoint')
        if os.path.exists(oauth_endpoint_path):
            with open(oauth_endpoint_path) as oauth_endpoint_f:
                default_oauth_endpoint = oauth_endpoint_f.read().strip()

    oauth_client_id = os.environ.get("OAUTH_CLIENT_ID", default_oauth_client_id)
    oauth_client_secret = os.environ.get("OAUTH_CLIENT_SECRET", default_oauth_client_secret)
    oauth_client_endpoint = os.environ.get("OAUTH_CLIENT_ENDPOINT", default_oauth_endpoint)

    if not all([oauth_client_id, oauth_client_secret, oauth_client_endpoint]):
        LOGGER.error("Invalid oauth configuration. Determine the specific information that "
                     "is missing or invalid and then re-run the request with valid information.")
        sys.exit(1)

    return oauth_client_id, oauth_client_secret, oauth_client_endpoint


def _create_oauth_session(ssl_cert):
    """
    Create and return an oauth2 python requests session object
    """
    oauth_client_id, oauth_client_secret, oauth_client_endpoint = _get_admin_client_auth()

    oauth_client = oauthlib.oauth2.BackendApplicationClient(
        client_id=oauth_client_id)

    session = requests_oauthlib.OAuth2Session(
        client=oauth_client,
        auto_refresh_url=oauth_client_endpoint,
        auto_refresh_kwargs={
            'client_id': oauth_client_id,
            'client_secret': oauth_client_secret,
        },
        token_updater=lambda t: None)

    session.verify = ssl_cert
    session.hooks['response'].append(log_request)
    session.hooks['response'].append(log_response)
    session.fetch_token(
        token_url=oauth_client_endpoint, client_id=oauth_client_id,
        client_secret=oauth_client_secret, timeout=500)

    return session


def is_repo_available(session, repo_url, timeout):
    """ Try to determine if the repo is available by getting the repodata/repomd.xml file"""
    try:
        repo_md_xml = "/".join(arg.strip("/") for arg in [repo_url, 'repodata', 'repomd.xml'])
        LOGGER.info("Attempting to get {}".format(repo_md_xml))
        response = session.head(repo_md_xml, timeout=timeout)
        response.raise_for_status()
        LOGGER.info("{} response getting {}".format(response.status_code, repo_md_xml))
        return True
    except requests.exceptions.RequestException as err:
        LOGGER.warn(err)
        if hasattr(err, "response") and hasattr(err.response, "text"):
            LOGGER.debug(err.response.text)
    return False


def _wait_for_repos(repos, session, timeout):
    """ Wait for all the defined repos to become available. """
    if repos:
        LOGGER.info("Recipe contains the following repos: %s" % repos)
        # Wait for all the defined repos to be available via HTTP/HTTPS
        while not all([is_repo_available(session, repo, timeout) for repo in repos]):
            LOGGER.info("Sleeping for 10 seconds")
            time.sleep(10)
    else:
        LOGGER.info("No matching http(s) repos found. Exiting.")


def _wait_for_kiwi_ng_repos(recipe_root, session, timeout):
    """ Load kiwi-ng recipe and introspect to find list of repos """
    # Load config.xml file
    config_xml_file = os.path.join(recipe_root, 'config.xml')
    if not os.path.isfile(config_xml_file):
        sys.exit("%s does not exist." % config_xml_file)

    # introspect the recipe and look for any defined repos
    root = ET.parse(config_xml_file).getroot()
    repos = [type_tag.get('path') for type_tag in root.findall('repository/source')
             if type_tag is not None and type_tag.get('path') and
             type_tag.get('path').lower().startswith(('http://', 'https://'))]

    _wait_for_repos(repos, session, timeout)


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

    _setup_logging()
    _set_ims_job_status(ims_job_id, ims_url, _create_oauth_session(ca_cert))
    _wait_for_kiwi_ng_repos(recipe_root, _create_session(ca_cert), timeout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
