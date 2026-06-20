#!/bin/bash
# scripts/final-system/050-bzip2.sh — build Bzip2 (compression library + tools)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# bzip2 has no configure; it ships two makefiles (one shared, one static) and
# requires the book's documentation/man-path patch + sed tweaks. Drive manually.
src="$(extract_only "bzip2-$BZIP2_VERSION.tar.gz")"
run_step final/bzip2 "Build & install bzip2 $BZIP2_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Apply the LFS docs patch if it was downloaded alongside the sources.
		if ls ../bzip2-'"$BZIP2_VERSION"'-install_docs-*.patch >/dev/null 2>&1; then
			patch -Np1 -i ../bzip2-'"$BZIP2_VERSION"'-install_docs-1.patch
		fi
		# Ensure relative symlinks and the correct man page directory.
		sed -i "s@\(ln -s -f \)\$(PREFIX)/bin/@\1@" Makefile
		sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

		# Build the shared library first, then the static + binaries.
		make -f Makefile-libbz2_so
		make clean
		make
		make PREFIX=/usr install

		# Install the shared library and fix up the symlinks/binaries per the book.
		cp -av libbz2.so.* /usr/lib
		ln -sv libbz2.so.'"$BZIP2_VERSION"' /usr/lib/libbz2.so
		cp -v bzip2-shared /usr/bin/bzip2
		for i in /usr/bin/{bzcat,bunzip2}; do
			ln -sfv bzip2 "$i"
		done
		rm -fv /usr/lib/libbz2.a
	' _ "$src"
