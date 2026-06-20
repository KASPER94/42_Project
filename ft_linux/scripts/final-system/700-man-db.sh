#!/bin/bash
# scripts/final-system/700-man-db.sh — build Man-DB (the man-page system)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. The book's flags disable the setuid cache owner and point
# at the system gdbm/libpipeline; uses the system groff for rendering.
build_package final/man-db "man-db-$MAN_DB_VERSION.tar.xz" \
	--configure-args="--docdir=/usr/share/doc/man-db-$MAN_DB_VERSION --sysconfdir=/etc --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap" \
	--no-check
