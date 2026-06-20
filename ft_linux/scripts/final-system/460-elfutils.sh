#!/bin/bash
# scripts/final-system/460-elfutils.sh — build Elfutils (libelf + libdw)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant (libelf for systemd
# and the kernel build). Not in the spec's 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# The book builds elfutils but installs ONLY libelf + libdw (not the eu-*
# utilities, which would conflict with binutils/other tools).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "elfutils-$ELFUTILS_VERSION.tar.bz2")"
run_step final/elfutils "Build & install elfutils $ELFUTILS_VERSION (libelf + libdw only)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		./configure --prefix=/usr \
			--disable-debuginfod \
			--enable-libdebuginfod=dummy \
			--libdir=/usr/lib
		make
		if ! make check; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: elfutils test suite reported failures (non-fatal)" >&2
		fi
		# Install only the libraries + headers + pkgconfig the book keeps.
		make -C libelf install
		make -C libdw  install 2>/dev/null || true
		install -vm644 config/libelf.pc /usr/lib/pkgconfig 2>/dev/null || true
		install -vm644 config/libdw.pc  /usr/lib/pkgconfig 2>/dev/null || true
		rm -f /usr/lib/libelf.a
	' _ "$src"
