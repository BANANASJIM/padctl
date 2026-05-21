# syntax=docker/dockerfile:1
#
# Canonical padctl build image (ADR-019).
#
# debian:bookworm-slim ships glibc 2.36, which avoids the Zig issue #147
# `R_X86_64_PC64 in .sframe` linker error seen on glibc 2.43+ hosts.
#
# ZIG_VERSION and ZIG_SHA256 are mandatory build-args with NO defaults: a bare
# `docker build .` fails by design. Builds must go through scripts/padctl-docker
# so the Zig version and its verified checksum stay in sync with .zigversion.
FROM debian:bookworm-slim

ARG ZIG_VERSION
ARG ZIG_SHA256
# TARGETARCH is a predefined build arg populated by BuildKit from --platform;
# it must be re-declared inside the stage to be visible to RUN.
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
      libusb-1.0-0-dev \
      linux-libc-dev \
      curl \
      ca-certificates \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

# TARGETARCH (set by buildx) maps to the Zig release arch name.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) _arch=x86_64 ;; \
      arm64) _arch=aarch64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    _tarball="zig-${_arch}-linux-${ZIG_VERSION}.tar.xz"; \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/${_tarball}" -o /tmp/zig.tar.xz; \
    echo "${ZIG_SHA256}  /tmp/zig.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/zig.tar.xz -C /usr/local; \
    ln -s "/usr/local/zig-${_arch}-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig; \
    rm /tmp/zig.tar.xz

WORKDIR /src
