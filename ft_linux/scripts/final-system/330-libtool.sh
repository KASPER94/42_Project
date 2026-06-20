#!/bin/bash
# scripts/final-system/330-libtool.sh — build Libtool (generic library support script)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools; the test suite is long and a couple of tests are expected
# to fail until automake is installed — the book marks it optional here.
build_package final/libtool "libtool-$LIBTOOL_VERSION.tar.xz" --no-check

# The book removes the libltdl static archive after install.
run_step final/libtool-cleanup "Remove libltdl static archive" -- \
	bash -c 'rm -fv /usr/lib/libltdl.a'
