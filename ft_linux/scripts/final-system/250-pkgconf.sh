#!/bin/bash
# scripts/final-system/250-pkgconf.sh — build Pkg-config (provides pkg-config)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# NOTE: env/versions.sh pins the classic freedesktop pkg-config
# (PKGCONFIG_VERSION). The spec lists "Pkg-config"; this is its canonical
# implementation and provides the /usr/bin/pkg-config binary the rest of the
# build relies on.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Tarball is pkg-config-<version>.tar.gz. Standard autotools; bundled glib.
build_package final/pkg-config "pkg-config-$PKGCONFIG_VERSION.tar.gz" \
	--configure-args="--with-internal-glib --disable-host-tool --docdir=/usr/share/doc/pkg-config-$PKGCONFIG_VERSION" \
	--no-check
