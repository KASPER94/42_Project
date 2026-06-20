#!/bin/bash
# scripts/final-system/300-bison.sh — build Bison (parser generator)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools; test suite is long, mark optional.
build_package final/bison "bison-$BISON_VERSION.tar.xz" \
	--configure-args="--docdir=/usr/share/doc/bison-$BISON_VERSION" \
	--no-check
