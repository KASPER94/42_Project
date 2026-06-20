#!/bin/bash
# scripts/final-system/170-gmp.sh — build GMP (GNU Multiple Precision arithmetic)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. --enable-cxx builds the C++ wrapper; the book builds docs
# and runs `make check` (GMP's suite is important — it self-tests the arithmetic).
# NOTE: the book warns against --build-time CPU tuning that could break on other
# hosts; the default ABI=64 detection is fine inside the VM.
build_package final/gmp "gmp-$GMP_VERSION.tar.xz" \
	--configure-args="--enable-cxx --disable-static --docdir=/usr/share/doc/gmp-$GMP_VERSION"
