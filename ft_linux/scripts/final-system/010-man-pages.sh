#!/bin/bash
# scripts/final-system/010-man-pages.sh — install Man-pages
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Man-pages ships only documentation: no configure/make/check — extract and
# `make install` only. Remove the man3 pages that conflict with glibc/Perl
# functions per the book, then install.
src="$(extract_only "man-pages-$MAN_PAGES_VERSION.tar.xz")"
run_step final/man-pages "Install man-pages $MAN_PAGES_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Per LFS: drop the man3 pages that document functions provided by other
		# packages (avoids overwriting their manuals).
		rm -v man3/crypt*
		make prefix=/usr install
	' _ "$src"
