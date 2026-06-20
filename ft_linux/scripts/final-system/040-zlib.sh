#!/bin/bash
# scripts/final-system/040-zlib.sh — build Zlib (compression library)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# zlib uses a configure script close enough to autotools (no --sysconfdir/
# --localstatedir support), so drive it manually under run_step.
src="$(extract_only "zlib-$ZLIB_VERSION.tar.gz")"
run_step final/zlib "Build & install zlib $ZLIB_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		./configure --prefix=/usr
		make
		if ! make check; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: zlib test suite reported failures (non-fatal)" >&2
		fi
		make install
		# The book removes the static library so nothing links against it.
		rm -fv /usr/lib/libz.a
	' _ "$src"
