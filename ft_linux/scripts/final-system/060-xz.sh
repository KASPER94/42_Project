#!/bin/bash
# scripts/final-system/060-xz.sh — build Xz Utils (LZMA compression)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. Disable static lib per the book.
build_package final/xz "xz-$XZ_VERSION.tar.xz" \
	--configure-args="--disable-static --docdir=/usr/share/doc/xz-$XZ_VERSION"
