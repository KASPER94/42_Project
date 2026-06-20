#!/bin/bash
# scripts/final-system/380-less.sh — build Less (terminal pager)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools; no test suite. The book puts the config in /etc.
build_package final/less "less-$LESS_VERSION.tar.gz" \
	--configure-args="--with-regex=gnu" \
	--no-check
