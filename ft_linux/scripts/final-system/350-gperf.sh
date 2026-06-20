#!/bin/bash
# scripts/final-system/350-gperf.sh — build Gperf (perfect-hash function generator)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. The book notes `make check` can fail when run in parallel,
# so we leave the suite enabled (build_package treats failures as warnings).
build_package final/gperf "gperf-$GPERF_VERSION.tar.gz" \
	--configure-args="--docdir=/usr/share/doc/gperf-$GPERF_VERSION"
