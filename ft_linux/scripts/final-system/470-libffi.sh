#!/bin/bash
# scripts/final-system/470-libffi.sh — build Libffi (foreign function interface)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant (Python ctypes,
# gobject). Not in the spec's 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. --disable-static + the book's --with-gcc-arch=native is
# AVOIDED on purpose (it bakes in host CPU features and can break on other
# hardware); leave the safe default so the VDI runs anywhere.
build_package final/libffi "libffi-$LIBFFI_VERSION.tar.gz" \
	--configure-args="--disable-static"
