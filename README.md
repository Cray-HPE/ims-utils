#  ims-utils
An Alpine-based Docker image which contains utilities that are required for
image creation and customization. This image is typically used to run simple
commands in sidecar/init containers that support the image creation and
customization workflow.

This image exists in the image creation and customization workflows so that
the image creation and user-supplied image customization docker images don't
have to include dependencies related to setting up the build environment.

This is part of the CMS Image Management and Image Customization
toolset for Shasta-based systems.

## Getting Started
### Prerequisites
To build and use the ims-utils Docker image, you will need Docker installed on
your system.

### Installation
Just clone this repo and `cd` into it. Bang! You're done.

### Build the Docker Image
```
docker build -t ims-utils:dev .
```

### Usage
1. Run the container and include the command that you want to execute on the
   `docker run` command line. A volume mounted at '/tmp/ims' is provided in the
   image definition if a mounted volume is required.
```
$ docker run ims-utils:dev /bin/sh -c "echo this"
this
```

### Kubernetes Container Usage
An example of using this container (as an `initContainer`) is provided below.

```
      initContainers:
      - image: dtr.dev.cray.com:443/jdeveloper/ims-utils:dev
        name: fetch-recipe
        env:
        - name: API_GATEWAY_HOSTNAME
          value: {{ api_gw_service_name }}.{{ api_gw_service_namespace }}.svc.cluster.local
        - name: CA_CERT
          value: /etc/cray/ca/certificate_authority.crt
        - name: OAUTH_CONFIG_DIR
          value: '/etc/admin-client-auth'
        - name: IMS_JOB_ID
          value: "$id"
        - name: IMS_PYTHON_HELPER_TIMEOUT
          value: 720
        envFrom:
        - configMapRef:
            name: cray-ims-$id-configmap
        volumeMounts:
        - name: recipe-vol
          mountPath: /mnt/recipe
        - name: ca-pubkey
          mountPath: /etc/cray/ca
          readOnly: true
        - name: admin-client-auth
          mountPath: '/etc/admin-client-auth'
          readOnly: true
        command: [ "sh", "-ce", "/scripts/fetch-recipe.sh /mnt/recipe $download_url" ]
```

## Deployment
This Docker image will be deployed as part of the Shasta management plane
stack via Kubernetes, specifically as a part of the Image Management Service.

## Development
Development on this repository should follow the standard CMS development
[process](https://connect.us.cray.com/confluence/x/fFGfBQ).

### Versioning
We use [SemVer](http://semver.org/) for versioning. See the `.version` file in
the repository root for the current version. Please update that version when
making changes.

## Authors
* Randy Kleinman
* Eric Cozzi
* (Add your name here if you want praise or blame later)

## License
Copyright 2018-2020, Cray Inc.


