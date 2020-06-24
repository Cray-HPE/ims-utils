## Cray Image Management Service image build environment utilities Dockerfile
## Copyright 2018-2020, Cray Inc.
FROM dtr.dev.cray.com/baseos/alpine:3.11.5

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
        && pip3 install --upgrade pip \
            --trusted-host dst.us.cray.com \
            --index-url http://dst.us.cray.com/dstpiprepo/simple \
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
