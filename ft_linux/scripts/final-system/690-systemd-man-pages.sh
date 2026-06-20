#!/bin/bash
# scripts/final-system/690-systemd-man-pages.sh — install systemd man pages
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# This is the LFS "systemd-man-pages" tarball that, in the SysV book, would be
# the "Udev-lfs" man-page companion. It is pre-rendered documentation only: no
# configure/compile — just unpack the man pages into /usr/share/man.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# The tarball is a flat collection of pre-built man pages (man{1,5,8}). The book
# unpacks it directly into /usr (tar --no-overwrite-dir into /usr/share/man).
run_step final/systemd-man-pages "Install systemd man pages $SYSTEMD_MAN_PAGES_VERSION" -- \
	bash -c '
		set -euo pipefail
		tarball="$SOURCES_DIR/systemd-man-pages-'"$SYSTEMD_MAN_PAGES_VERSION"'.tar.xz"
		[ -f "$tarball" ] || { echo "ERROR: systemd-man-pages tarball not found: $tarball" >&2; exit 1; }
		# Most distributions of this tarball expand into a man*/ tree; install it
		# under /usr/share/man. Use --no-same-owner so files are root-owned.
		tar -xf "$tarball" --strip-components=0 --no-same-owner -C /usr/share/man 2>/dev/null \
			|| tar -xf "$tarball" --no-same-owner -C /usr/share/man
		mandb -q 2>/dev/null || true
	'
