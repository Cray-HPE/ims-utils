# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- CASMCMS-9560 - better checking for remote build node port availability.
- CASMTRIAGE-8568 - better handling of remote build node container failures.

## [2.20.0] - 2025-10-01
## Changed
- CASMCMS-8904 - optimize remote node builds.

## [2.19.0] - 2025-08-19
### Dependencies
- Update `kubernetes` module to match CSM Kubernetes version
- CASMCMS-9510: Updated ims-python-helper version to 3.3.x

## [2.18.0] - 2025-06-17
### Dependencies
- CASMCMS-9455: Updated ims-python-helper version to 3.2.x
- CASMCMS-8022:  update python modules

- Bumped dependency patch versions:
| Package                | From      | To        |
|------------------------|-----------|-----------|
| `botocore`             | 1.36.2    | 1.36.26   |
| `cachetools`           | 3.0.0     | 5.3.3     |
| `certifi`              | 2023.7.22 | 2025.6.15 |
| `chardet`              | 3.0.4     | 5.2.0     |
| `docutils`             | 0.14      | 0.21      |
| `google-auth`          | 1.6.3     | 2.29.0    |
| `idna`                 | 2.8       | 3.10.0    |
| `Jinja2`               | 2.10.3    | 3.1.6     |
| `jmespath`             | 0.9.5     | 1.0.1     |
| `MarkupSafe`           | <2.1.0    | 2.1.5     |
| `oauthlib`             | 2.1.0     | 3.2.2     |
| `pyasn1`               | 0.4.8     | 0.6.1     |
| `pyasn1-modules`       | 0.2.8     | 0.4.0     |
| `requests`             | 2.27.1    | 2.32.4    |
| `requests-oauthlib`    | 1.0.0     | 2.0.0     |
| `rsa`                  | 4.7.2     | 4.9       |
| `s3transfer`           | 0.11.1    | 0.11.3    |
| `urllib3`              | 1.26.18   | 2.4.0     |
| `websocket-client`     | 0.54.0    | 1.8.0     |

## [2.17.0] - 2025-06-10
### Changed
- CASMCMS-8939 - better port forwarding for remote jobs.

## [2.16.3] - 2025-05-01
### Fixed
- CASMTRIAGE-8161: setting up certs failing with `update-ca-certificates: command not found`

## [2.16.2] - 2025-03-04
### Dependencies
- CASMTRIAGE-7899: Update installed packages to make rpmbuild work.

## [2.16.1] - 2025-02-27
### Dependencies
- CASMTRIAGE-7899: Bump dependency versions to work with Python 3.12

## [2.16.0] - 2025-02-13
### Dependencies
- CASMCMS-9282: Bump Alpine version from 3.15 to 3.21, because 3.15 no longer receives security patches

## [2.15.0] - 2024-12-10
## Fixed
- CASMCMS-9226 - fix mis-spelling.
- CASMCMS-9037 - remove parts of openssh that are not being used for security.

## [2.14.0] - 2024-08-29
### Dependencies
- CSM 1.6 moved to Kubernetes 1.24, so use client v24.x to ensure compatibility
- Simplify how `ims-python-helper` major/minor version is pinned

### Changed
- CASMCMS-9040 - change permissions on image config files after recipe build.

## [2.13.2] - 2024-07-25
### Dependencies
- Resolve CVES:
  - Bump `certifi` from 2019.11.28 to 2023.7.22
  - Require `setuptools` >= 70.0
  - Use CSM re-built Alpine container as base of Docker image

## [2.13.1] - 2024-04-12
### Changed
- CASMTRIAGE-6885 - fix etc/resolv.conf resolution when it is a broken symlink.

## [2.13.0] - 2024-03-01
### Added
- CASMCMS-8821 - add support for remote build jobs.
- CASMCMS-8818 - ssh key injection into jobs.
- CASMCMS-8897 - changes for aarch64 remote build.
- CASMCMS-8895 - allow multiple concurrent remote customize jobs.
- CASMCMS-8923 - better cleanup on unexpected exit.

## [2.12.0] - 2024-02-22
### Dependencies
- Bump `kubernetes` from 11.0.0 to 22.6.0 to match CSM 1.6 Kubernetes version

## [2.11.0] - 2023-09-15
### Changed
- Disabled concurrent Jenkins builds on same branch/commit
- Added build timeout to avoid hung builds
- CASMCMS-8801 - changed the image volume mounts to ude PVC's instead of ephemeral storage.

### Dependencies
- CASMCMS-8656: Use `update_external_version` to get latest `ims-python-helper` Python module
- Bumped dependency patch versions:
| Package                  | From     | To       |
|--------------------------|----------|----------|
| `boto3`                  | 1.12.9   | 1.12.49  |
| `botocore`               | 1.15.9   | 1.15.49  |
| `google-auth`            | 1.6.1    | 1.6.3    |
| `Jinja2`                 | 2.10.1   | 2.10.3   |
| `jmespath`               | 0.9.4    | 0.9.5    |
| `pyasn1-modules`         | 0.2.2    | 0.2.8    |
| `python-dateutil`        | 2.8.1    | 2.8.2    |
| `rsa`                    | 4.7      | 4.7.2    |
| `s3transfer`             | 0.3.0    | 0.3.7    |
| `urllib3`                | 1.25.9   | 1.25.11  |

## [2.10.4] - 2023-07-18
### Dependencies
- Bump `PyYAML` from 5.4.1 to 6.0.1 to avoid build issue caused by https://github.com/yaml/pyyaml/issues/601

## [2.10.3] - 2023-07-11
### Changed
- CASMCMS-8708 - fix build to include metadata needed for nightly rebuilds.

## [2.10.2] - 2023-06-05
### Changed
- CASM-4232: Require at least version 2.14.0 of `ims-python-helper` in order to get associated logging enhancements.

## [2.10.1] - 2023-05-16
### Changed
- CASMCMS-8365 - tweaks to get arm64 recipe building

## [2.10.0] - 2023-05-03
### Added
- CASMCMS-8368 - add an arm64 image to the build
- CASMCMS-8459 - more arm64 image support
- CASMCMS-8595 - rename platform to arch

### Removed
- Removed defunct files leftover from previous versioning system

## [2.9.4] - 2023-01-11
### Changed
- CASMTRIAGE-4784 - Preserve file permissions when applying recipe templates.

## [2.9.3] - 2022-12-20
### Added
- Add Artifactory authentication to Jenkinsfile

## [2.9.2] - 2022-12-02
### Added
- Authenticate to CSM's artifactory

## [2.9.1] - 2022-11-09
### Changed
- CASMCMS-8316 - Added a retry to the file download so it doesn't fail once and quit.

## [2.9.0] - 2022-09-28
### Changed
- CASMTRIAGE-4268 - Increased the s3 file download chunk size for better performance.

## [2.8.1] - 2022-08-01
### Changed
- CASMCMS-7970 - fix ims-python-helper version.

## [2.8.0] - 2022-08-01
### Changed
- CASMCMS-8093 - fix the python dependencies.
- CASMCMS-7970 - update dev.cray.com server addresses.

## [2.7.0] - 2022-06-28
### Added
- Add support for templating IMS recipes during IMS create jobs

