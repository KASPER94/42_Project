# KFS_1 build toolchain.
# Host is Apple Silicon (arm64); we build an amd64 image so that grub-pc-bin
# (i386-pc GRUB modules) and the standard x86 toolchain are available. The
# kernel itself targets i386 and runs under qemu-system-i386.
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        nasm \
        make \
        grub-pc-bin \
        grub-common \
        xorriso \
        mtools \
        qemu-system-x86 \
        gdb \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Nightly Rust + the components needed to recompile `core` for a custom target.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain nightly --profile minimal \
    && rustup component add rust-src llvm-tools-preview \
    && rustc --version && cargo --version

# netpbm provides ppm->png conversion used by `make screenshot`.
RUN apt-get update \
    && apt-get install -y --no-install-recommends netpbm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /kfs
