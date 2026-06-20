#!/bin/bash
# scripts/final-system/220-libcap.sh — build Libcap (POSIX capabilities)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# libcap has no configure; it uses a plain Makefile. The book disables building
# the static lib via a sed, builds, tests, and installs.
src="$(extract_only "libcap-$LIBCAP_VERSION.tar.xz")"
run_step final/libcap "Build & install libcap $LIBCAP_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Do not install the static library.
		sed -i "/install -m.*STA/d" libcap/Makefile
		make prefix=/usr lib=lib
		if ! make test; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: libcap test suite reported failures (non-fatal)" >&2
		fi
		make prefix=/usr lib=lib install
	' _ "$src"
