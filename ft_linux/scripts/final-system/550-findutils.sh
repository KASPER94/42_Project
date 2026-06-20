#!/bin/bash
# scripts/final-system/550-findutils.sh — build Findutils (find, locate, xargs)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Put the locate database under /var/lib/locate (FHS) per the book.
build_package final/findutils "findutils-$FINDUTILS_VERSION.tar.xz" \
	--configure-args="--localstatedir=/var/lib/locate"
