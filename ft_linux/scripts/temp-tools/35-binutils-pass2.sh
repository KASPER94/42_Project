#!/bin/bash
# =============================================================================
# scripts/temp-tools/35-binutils-pass2.sh — LFS Ch.6 — Binutils-Pass2.
#
# PURPOSE   Rebuild Binutils, this time cross-compiled to RUN on the target
#           (--host=$LFS_TGT) and installed into $LFS/usr. The pass-1 binutils
#           in $LFS/tools was only good enough to bootstrap glibc/gcc; pass2
#           produces the assembler/linker the chrooted final system will use.
#           Out-of-tree build/ dir. Removes the libtool archives the book flags.
#
# RUN AS    the `lfs` build user (NOT root), on the build HOST.
# DEPENDS   the full Ch.5 toolchain + Ch.6 tools up to here.
# AUTHORED  on macOS — RUN by the operator inside the Linux build VM.
# =============================================================================
set -euo pipefail

# --- Foundation bootstrap (A0 contract — verbatim) --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
[ -f "$REPO_ROOT/env/lfs.env" ] || { echo "FATAL: cannot locate env/lfs.env above $SCRIPT_DIR" >&2; exit 1; }
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/package.sh"

require_not_root

# Script-local function handed to run_step (runs IN-PROCESS so extract_only and
# the sourced helpers stay in scope — a `bash -c` child would not see them).
_do_binutils_pass2() {
	set -euo pipefail
	local src
	src="$(extract_only "binutils-$BINUTILS_VERSION.tar.xz")"
	cd "$src"

	# The book disables one gprofng test artifact regeneration that breaks under
	# the cross sysroot; the documented fix is to clean the ld testsuite tree.
	sed "/R_386_TLS_LE /d" -i bfd/elfxx-x86.h 2>/dev/null || true

	rm -rf build
	mkdir -v build
	cd build

	../configure \
		--prefix=/usr \
		--build="$(../config.guess)" \
		--host="$LFS_TGT" \
		--disable-nls \
		--enable-shared \
		--enable-gprofng=no \
		--disable-werror \
		--enable-64-bit-bfd \
		--enable-new-dtags \
		--enable-default-hash-style=gnu

	make
	make DESTDIR="$LFS" install

	# Remove libtool archives + unused static libs (book step).
	rm -v "$LFS"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la} 2>/dev/null || true

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "35-binutils-pass2" "Binutils-Pass2 -> $LFS/usr" -- _do_binutils_pass2

log_ok "Binutils-Pass2 installed into $LFS/usr"
