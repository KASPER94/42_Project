#!/bin/bash
# scripts/final-system/290-gettext.sh — build Gettext (internationalization)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Standard autotools. The book's test suite is very long; mark optional. Then
# fix permissions on the installed autopoint helper as the book does.
build_package final/gettext "gettext-$GETTEXT_VERSION.tar.xz" \
	--configure-args="--disable-static --docdir=/usr/share/doc/gettext-$GETTEXT_VERSION" \
	--no-check

run_step final/gettext-perms "Fix gettext autopoint permissions" -- \
	bash -c 'chmod -v 0755 /usr/lib/preloadable_libintl.so 2>/dev/null || true'
