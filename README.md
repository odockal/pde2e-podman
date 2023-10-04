# pde2e-podman
Podman Desktop E2E tests podman engine preparation on windows and mac OS systems.
Download given podman client, extract it and put on the PATH. Initalize the machine and start it if necessary.

# Usage

## Run the image examples

Run the with this setup in order to install podman 4.7.0, initialize the podman machine with a flag `--rooftul` and start it
```sh
podman run --rm -d --name pde2e-podman-run \                              
          -e TARGET_HOST=$(cat host) \
          -e TARGET_HOST_USERNAME=$(cat username) \
          -e TARGET_HOST_KEY_PATH=/data/id_rsa \
          -e TARGET_FOLDER=pd-e2e-podman \
          -e TARGET_RESULTS=results \
          -e OUTPUT_FOLDER=/data \
          -e DEBUG=true \
          -v $PWD:/data:z \
          quay.io/odockal/pde2e-podman:v0.0.1-snapshot  \
            pd-e2e-podman/run.ps1 \
            -downloadUrl "https://github.com/containers/podman/releases/download/v4.7.0/podman-remote-release-windows_amd64.zip" \
            -version '4.7.0' \
            -targetFolder pd-e2e-podman \
            -resultsFolder results \
            -initialize 1
            -rootful 1
            -start 1
```

Run this image setup in order to install latest podman nightly on the host and initialize the machine in rootless mode
```sh
podman run --rm -d --name pde2e-podman-run \                              
          -e TARGET_HOST=$(cat host) \
          -e TARGET_HOST_USERNAME=$(cat username) \
          -e TARGET_HOST_KEY_PATH=/data/id_rsa \
          -e TARGET_FOLDER=pd-e2e-podman \
          -e TARGET_RESULTS=results \
          -e OUTPUT_FOLDER=/data \
          -e DEBUG=true \
          -v $PWD:/data:z \
          quay.io/odockal/pde2e-podman:v0.0.1-snapshot  \
            pd-e2e-podman/run.ps1 \
            -downloadUrl "https://api.cirrus-ci.com/v1/artifact/github/containers/podman/Artifacts/binary/podman-remote-release-windows_amd64.zip" \
            -version '4.8.0-dev' \
            -targetFolder pd-e2e-podman \
            -resultsFolder results \
            -initialize 1
            -rootful 0
            -start 0
```

## Get the image logs
```sh
podman logs -f pde2e-podman-run
```
