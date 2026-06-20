#!/bin/bash
# =============================================================================
# scripts/toolchain/11-gcc-pass1.sh
#   LFS Ch.5 — GCC-Pass1 (the cross C/C++ compiler + libgcc).
#
# PURPOSE   Build the first-pass cross compiler targeting $LFS_TGT into
#           $LFS/tools. GCC's bundled math libraries (GMP/MPFR/MPC) are unpacked
#           INTO the GCC source tree (renamed gmp/mpfr/mpc) so GCC builds them
#           in-tree. We apply the book's two source edits:
#             * point the 64-bit dynamic linker at /tools/lib  (mh-x86_64 / t-linux64)
#             * cap a couple of header-related constants (limits.h is generated)
#           Then configure for the cross target and build only:
#             make all-gcc all-target-libgcc
#           (the full libstdc++ etc. is deferred to 14-libstdcxx.sh).
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
#
# DEPENDS   10-binutils-pass1.sh must have completed ($LFS_TGT-as/ld present).
#
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
# the other sourced helpers remain in scope — a `bash -c` child would not see
# them).
_do_gcc_pass1() {
	set -euo pipefail
	local src
	src="$(extract_only "gcc-$GCC_VERSION.tar.xz")"
	cd "$src"

	# --- Unpack the bundled math libs into the GCC tree, renamed -------------
	tar -xf "$SOURCES_DIR/mpfr-$MPFR_VERSION.tar.xz"
	mv -v "mpfr-$MPFR_VERSION" mpfr
	tar -xf "$SOURCES_DIR/gmp-$GMP_VERSION.tar.xz"
	mv -v "gmp-$GMP_VERSION" gmp
	tar -xf "$SOURCES_DIR/mpc-$MPC_VERSION.tar.gz"
	mv -v "mpc-$MPC_VERSION" mpc

	# --- Book edit: put the 64-bit dynamic linker under /lib (not /lib64) ----
	# On x86_64 the default GCC config builds a "lib64" multilib; LFS makes it a
	# pure /lib layout and points the dynamic loader there.
	case "$(uname -m)" in
		x86_64)
			sed -e "/m64=/s/lib64/lib/" \
				-i.orig gcc/config/i386/t-linux64
			;;
	esac

	# --- Out-of-tree build dir ----------------------------------------------
	rm -rf build
	mkdir -v build
	cd build

	../configure \
		--target="$LFS_TGT" \
		--prefix="$LFS/tools" \
		--with-glibc-version="$GLIBC_VERSION" \
		--with-sysroot="$LFS" \
		--with-newlib \
		--without-headers \
		--enable-default-pie \
		--enable-default-ssp \
		--disable-nls \
		--disable-shared \
		--disable-multilib \
		--disable-threads \
		--disable-libatomic \
		--disable-libgomp \
		--disable-libquadmath \
		--disable-libssp \
		--disable-libvtv \
		--disable-libstdcxx \
		--enable-languages=c,c++

	make all-gcc all-target-libgcc
	make install-gcc install-target-libgcc

	# --- Book step: generate a full internal limits.h -----------------------
	# GCC pass1 ships a partial limits.h; build the complete header so glibc and
	# later passes see the right limits. Run from the GCC SOURCE root.
	cd ..
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
		"$(dirname "$("$LFS/tools/bin/$LFS_TGT-gcc" -print-libgcc-file-name)")/include/limits.h"

	# Clean up the extracted source tree.
	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "11-gcc-pass1" "GCC-Pass1 (cross compiler + libgcc) -> $LFS/tools" -- _do_gcc_pass1

log_ok "GCC-Pass1 installed into $LFS/tools"
