ARG OS

FROM quay.io/rhqp/deliverest:v0.0.7 AS base

LABEL org.opencontainers.image.authors="Ondrej Dockal<odockal@redhat.com> Anton Misskii<amisskii@redhat.com>"

ENV ASSETS_FOLDER=/opt/pde2e-podman

FROM base AS darwin
COPY /lib/darwin/* ${ASSETS_FOLDER}/
ENV OS=darwin

FROM base AS windows
COPY /lib/windows/* ${ASSETS_FOLDER}/
ENV OS=windows

# Linux distributions
FROM base AS linux
ENV OS=linux

FROM linux AS rhel
COPY /lib/rhel/* ${ASSETS_FOLDER}/

FROM ${OS}
