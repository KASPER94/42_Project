#!/bin/bash
# scripts/final-system/160-binutils.sh — build FINAL Binutils (assembler, linker, etc.)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# This is the FINAL Binutils. The book runs the full test suite (a few tests are
# expected to fail). Failures are warnings unless STRICT=1.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "binutils-$BINUTILS_VERSION.tar.xz")"
run_step final/binutils "Build & install FINAL binutils $BINUTILS_VERSION (run test suite)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		mkdir -v build
		cd build
		../configure \
			--prefix=/usr \
			--sysconfdir=/etc \
			--enable-ld=default \
			--enable-plugins \
			--enable-shared \
			--disable-werror \
			--enable-64-bit-bfd \
			--enable-new-dtags \
			--with-system-zlib \
			--enable-default-hash-style=gnu
		make tooldir=/usr

		# Run the full Binutils test suite (the book emphasises it here). Some
		# tests are expected to fail; non-fatal unless STRICT=1.
		if ! make -k check; then
			if [ "${STRICT:-0}" = "1" ]; then
				echo "STRICT=1: binutils test failures are fatal" >&2
				exit 1
			fi
			echo "WARNING: binutils test suite reported failures (non-fatal; set STRICT=1 to enforce)" >&2
		fi

		make tooldir=/usr install
		# Remove static libs and the libtool .la files the book deletes.
		rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
		rm -fv /usr/share/man/man1/{gprofng,gp-*}.1 2>/dev/null || true
	' _ "$src"
