#! /usr/bin/env python3
# Copyright 2019-2021 Hewlett Packard Enterprise Development LP
# Author: Eric Cozzi

import os
import shutil
import subprocess
import errno

RPM_NAME = "cray_ca_cert"
RPM_VERSION = "1.0.1"

ETC_CRAY_CA_DIR = "etc/cray/ca"
CERTIFICATE_AUTHORITY_NAME = "certificate_authority.crt"
ETC_CRAY_CA_CERT_FILE = os.path.join("/", ETC_CRAY_CA_DIR, CERTIFICATE_AUTHORITY_NAME)

SOURCE_ARCHIVE_ROOT = os.path.expanduser(os.path.join("~", "{}-{}".format(RPM_NAME, RPM_VERSION)))
SOURCE_ARCHIVE_ETC_CRAY_CA_DIR = os.path.join(SOURCE_ARCHIVE_ROOT, ETC_CRAY_CA_DIR)
SOURCE_ARCHIVE_ETC_CRAY_CA_CERT_FILE = os.path.join(SOURCE_ARCHIVE_ETC_CRAY_CA_DIR, CERTIFICATE_AUTHORITY_NAME)
SOURCE_TAR_FILE = "{}-{}.tar.gz".format(RPM_NAME, RPM_VERSION)

RPM_BUILD_ROOT = os.path.expanduser("~/rpmbuild/")
SPECFILE_NAME = "cray_ca_cert.spec"
SPECFILE_SOURCE_FILE = os.path.join("/mnt/specfile/", SPECFILE_NAME)


def main():

    os.chdir(os.path.expanduser("~"))

    # Create SOURCE archive root and sub directories
    try:
        os.makedirs(SOURCE_ARCHIVE_ETC_CRAY_CA_DIR)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(SOURCE_ARCHIVE_ETC_CRAY_CA_DIR):
            pass
        else:
            raise

    # Copy CA Certificate into SOURCE directory
    shutil.copyfile(ETC_CRAY_CA_CERT_FILE, SOURCE_ARCHIVE_ETC_CRAY_CA_CERT_FILE)
    os.chmod(SOURCE_ARCHIVE_ETC_CRAY_CA_CERT_FILE, 0o644)

    # Archive SOURCE archive using tar
    subprocess.check_call(["tar", "-zcvf", SOURCE_TAR_FILE, "{}-{}".format(RPM_NAME, RPM_VERSION)])

    # Make RPMBUILD directories
    for rpmbuild_directory in ["{}{}".format(RPM_BUILD_ROOT, subdir) for subdir in
                               ("SOURCES", "RPMS", "SRPMS", "SPECS", "BUILD", "BUILDROOT")]:
        try:
            os.makedirs(os.path.expanduser(rpmbuild_directory))
        except OSError as exc:  # Python >2.5
            if exc.errno == errno.EEXIST and os.path.isdir(rpmbuild_directory):
                pass
            else:
                raise

    # Copy source archive and spec file into RPMBUILD directories
    shutil.copyfile(SOURCE_TAR_FILE, os.path.join(RPM_BUILD_ROOT, "SOURCES", SOURCE_TAR_FILE))
    shutil.copyfile(SPECFILE_SOURCE_FILE, os.path.join(RPM_BUILD_ROOT, "SPECS", SPECFILE_NAME))

    subprocess.check_call(["rpmbuild", "-bb", os.path.join(RPM_BUILD_ROOT, "SPECS", SPECFILE_NAME)])
    shutil.copyfile(os.path.join(RPM_BUILD_ROOT, "RPMS", "x86_64", "cray_ca_cert-1.0.0-1.x86_64.rpm"), "/mnt/ca-rpm/cray_ca_cert-1.0.0-1.x86_64.rpm")


if __name__ == "__main__":
    main()
