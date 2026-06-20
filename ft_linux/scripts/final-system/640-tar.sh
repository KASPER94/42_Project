#!/bin/bash
# scripts/final-system/640-tar.sh — build Tar (GNU tar archiver)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# The book sets FORCE_UNSAFE_CONFIGURE=1 so configure proceeds as root in chroot.
build_package final/tar "tar-$TAR_VERSION.tar.xz" \
	--configure-args="FORCE_UNSAFE_CONFIGURE=1"
