# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Dependencies
- Resolve CVES:
  - Bump `certifi` from 2019.11.28 to 2023.7.22
  - Require `setuptools` >= 70.0

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

