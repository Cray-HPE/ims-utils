#
# MIT License
#
# (C) Copyright 2018-2025 Hewlett Packard Enterprise Development LP
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
# Cray Image Management Service image build environment utilities Dockerfile
#

FROM artifactory.algol60.net/docker.io/library/alpine:3.21 as base

# Add utilities that are required for this command
WORKDIR /
COPY requirements.txt constraints.txt /
RUN apk add --upgrade --no-cache apk-tools \
        && apk update \
        && apk add --update --no-cache \
            curl \
            rpm \
            squashfs-tools \
            tar \
            python3 \
            py3-pip \
            gcc \
            python3-dev \
            libc-dev \
            podman \
            openssh-client \
            bash \
            findutils \
            grep \
            ca-certificates \
            fuse-overlayfs \
        && apk -U upgrade --no-cache \
        &&  rm -rf \
           /var/cache/apk/* \
           /root/.cache \
           /tmp/* \
        && mkdir -p \
           /scripts \
           /config

# There is a problem with the script brp-remove-la-files in alpine where
#  it uses the wrong 'force' option for the rm installed here. Modify
#  the script so the rpmbuild command will work in build-ca-rpm
RUN sed -i 's/--force/-f/g' /usr/lib/rpm/brp-remove-la-files
# To resolve issue overlay is not supported over overlayfs CASMTRIAGE-8161
RUN sed -i 's/#mount_program/mount_program/' /etc/containers/storage.conf

ENV VIRTUAL_ENV=/scripts/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN --mount=type=secret,id=netrc,target=/root/.netrc \
    pip3 install --upgrade pip && \
    pip3 install \
      --no-cache-dir \
      -r requirements.txt

COPY scripts/* /scripts/
COPY config/* /config/
COPY Dockerfile.remote /Dockerfile.remote
