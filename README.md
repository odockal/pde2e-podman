# pde2e-podman
Podman Desktop E2E tests podman engine preparation on windows and mac OS systems.

# Purpose
Image downloads given podman client, extract it and put on the PATH. Initalize the machine and start it if necessary.

## Usage, building and pushing the image
The repository structure:
* `lib` folder contains platform specific (`windows/podman.ps1`, `darwin/podman.sh`) execution scripts that are shipped using `deliverest` image into a target host machine
* `Containerfile` is a build image configuration file that accepts `--build-args`: `OS` to determine the platform for which the particulat image is being built
* `Makefile` build instructions for building the image using `Containerfile` and pushing it into image registry
* `builder.sh` script that executes makefile for Windows and Mac OS platforms

In order to push an image, user needs to be logged in before executing building scipts.

## Run the image examples

Run the with this setup in order to install podman 4.7.0 (determined by version parameter), initialize the podman machine with a flag `--rooftul` and start it
```sh
# Running the image on windows
podman run --rm -d --name pde2e-podman-run \
  -e TARGET_HOST=$(cat host) \
  -e TARGET_HOST_USERNAME=$(cat username) \
  -e TARGET_HOST_KEY_PATH=/data/id_rsa \
  -e TARGET_FOLDER=pd-e2e \
  -e TARGET_RESULTS=results \
  -e OUTPUT_FOLDER=/data \
  -e DEBUG=true \
  -v $PWD:/data:z \
  quay.io/odockal/pde2e-podman:v0.0.1-windows  \
    pd-e2e/podman.ps1 \
      -downloadUrl "https://github.com/containers/podman/releases/download/v4.9.0/podman-remote-release-windows_amd64.zip" \
      -version '4.9.0' \
      -targetFolder pd-e2e \
      -resultsFolder results \
      -initialize 1 \
      -rootful 1 \
      -start 1 \
      -userNetworking 0

# Running the image on Mac OS
podman run --rm -d --name pde2e-podman-run \
          -e TARGET_HOST=$(cat host) \
          -e TARGET_HOST_USERNAME=$(cat username) \
          -e TARGET_HOST_KEY_PATH=/data/id_rsa \
          -e TARGET_FOLDER=pd-e2e \
          -e TARGET_RESULTS=results \
          -e OUTPUT_FOLDER=/data \
          -e DEBUG=true \
          -v $PWD:/data:z \
          quay.io/odockal/pde2e-podman:v0.0.1-darwin  \
            pd-e2e/podman.sh \
            --targetFolder pd-e2e \
            --resultsFolder results \
            --downloadUrl "https://github.com/containers/podman/releases/download/v4.9.0/podman-remote-release-darwin_arm64.zip" \
            --version '4.9.0' \
            --initialize 1 \
            --rootful 1 \
            --start 1
```

Run this image setup in order to install latest podman nightly on the host and initialize the machine in rootless mode
```sh
# Running the image on windows
podman run --rm -d --name pde2e-podman-run \
  -e TARGET_HOST=$(cat host) \
  -e TARGET_HOST_USERNAME=$(cat username) \
  -e TARGET_HOST_KEY_PATH=/data/id_rsa \
  -e TARGET_FOLDER=pd-e2e \
  -e TARGET_RESULTS=results \
  -e OUTPUT_FOLDER=/data \
  -e DEBUG=true \
  -v $PWD:/data:z \
  quay.io/odockal/pde2e-podman:v0.0.1-windows  \
    pd-e2e/podman.ps1 \
      -downloadUrl "https://github.com/containers/podman/releases/download/v4.9.0/podman-remote-release-windows_amd64.zip" \
      -version '4.9.0' \
      -targetFolder pd-e2e \
      -resultsFolder results \
      -initialize 1 \
      -rootful 0 \
      -start 0 \
      -userNetworking 0
```

## Get the image logs
```sh
podman logs -f pde2e-podman-run
```
