FROM quay.io/rhqp/deliverest:v0.0.7

LABEL org.opencontainers.image.authors="Ondrej Dockal<odockal@redhat.com> Anton Misskii<amisskii@redhat.com>"

# Expects one of windows, darwin, or rhel as build args
ARG OS
ARG ENTRYPOINT_OS

ENV ASSETS_FOLDER=/opt/pde2e-podman

COPY /lib/${OS}/* ${ASSETS_FOLDER}/

ENV OS=${ENTRYPOINT_OS}
