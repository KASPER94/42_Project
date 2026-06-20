#!/bin/bash
# scripts/final-system/070-zstd.sh — build Zstd (Zstandard compression)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant (systemd, kernel
# module/initramfs compression). Not in the spec's 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# zstd ships a plain Makefile (no configure). prefix is passed on the make line;
# the book builds, then installs with the static lib removed.
src="$(extract_only "zstd-$ZSTD_VERSION.tar.gz")"
run_step final/zstd "Build & install zstd $ZSTD_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		make prefix=/usr
		make prefix=/usr install
		rm -v /usr/lib/libzstd.a
	' _ "$src"
