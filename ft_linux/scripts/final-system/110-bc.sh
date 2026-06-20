#!/bin/bash
# scripts/final-system/110-bc.sh — build Bc (arbitrary-precision calculator)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Gavin Howard's bc uses a custom configure.sh (CC + the GD options), not
# autotools. The book builds with readline support and runs `make test`.
src="$(extract_only "bc-$BC_VERSION.tar.xz")"
run_step final/bc "Build & install bc $BC_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		CC=gcc ./configure.sh --prefix=/usr -G -O3 -r
		make
		if ! make test; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: bc test suite reported failures (non-fatal)" >&2
		fi
		make install
	' _ "$src"
