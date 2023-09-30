# pde2e-builder
Podman Desktop E2E tests podman engine preparation on windows and mac OS systems

# Usage

## Run the image
```sh
podman run -d --name pde2e-podman-run \
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
              -version "4.7.0"

```

## Get the image logs
```sh
podman logs -f pde2e-podman-run
```
