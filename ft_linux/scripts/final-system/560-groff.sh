#!/bin/bash
# scripts/final-system/560-groff.sh — build Groff (document formatting; for man pages)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# PAGE=letter|A4 controls the default paper size. The book sets it explicitly;
# no test suite. Single-threaded build is recommended (parallel can fail), but
# MAKEFLAGS comes from env; we leave it as-is for throughput.
build_package final/groff "groff-$GROFF_VERSION.tar.gz" \
	--configure-args="PAGE=A4" \
	--no-check
