# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- CASMCMS-8368 - add an arm64 image to the build

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

