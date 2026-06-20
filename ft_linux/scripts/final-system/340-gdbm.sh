#!/bin/bash
# scripts/final-system/340-gdbm.sh — build GDBM (GNU dbm database library)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. --enable-libgdbm-compat builds the legacy dbm/ndbm API
# (needed by Man-DB & Perl).
build_package final/gdbm "gdbm-$GDBM_VERSION.tar.gz" \
	--configure-args="--disable-static --enable-libgdbm-compat"
