#!/bin/bash
# scripts/final-system/710-procps-ng.sh — build Procps-ng (ps, top, free, sysctl, ...)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Spec entry #52 is "Procps"; procps-ng is its current upstream. Tarball stem is
# procps-ng-<version>.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools; build with systemd support (for the journal in top etc.)
# and the wide-char ncurses. Test suite is optional.
build_package final/procps-ng "procps-ng-$PROCPS_VERSION.tar.xz" \
	--configure-args="--docdir=/usr/share/doc/procps-ng-$PROCPS_VERSION --disable-static --disable-kill --enable-watch8bit --with-systemd" \
	--no-check
