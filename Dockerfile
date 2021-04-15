## Cray Image Management Service image build environment utilities Dockerfile
# Copyright 2018-2021 Hewlett Packard Enterprise Development LP
FROM arti.dev.cray.com/baseos-docker-master-local/alpine:3.12.4

# Add utilities that are required for this command
WORKDIR /
COPY requirements.txt constraints.txt /
RUN apk update \
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
        && pip3 install --upgrade pip \
            --trusted-host dst.us.cray.com \
            --index-url http://dst.us.cray.com/piprepo/simple \
        && pip3 install \
           --no-cache-dir \
           -r requirements.txt \
        &&  rm -rf \
           /var/cache/apk/* \
           /root/.cache \
           /tmp/* \
       && mkdir -p \
           /scripts \
           /config

COPY scripts/* /scripts/
COPY config/* /config/
