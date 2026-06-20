#!/bin/bash
# scripts/final-system/200-attr.sh — build Attr (extended-attribute utilities)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. The book's `make check` requires a filesystem that
# supports xattrs; inside the chroot it may report failures (non-fatal here).
# NB: build_package's autotools path already supplies --prefix=/usr
# --sysconfdir=/etc --localstatedir=/var.
build_package final/attr "attr-$ATTR_VERSION.tar.gz" \
	--configure-args="--disable-static --docdir=/usr/share/doc/attr-$ATTR_VERSION"
