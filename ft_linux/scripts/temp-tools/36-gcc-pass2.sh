#!/bin/bash
# =============================================================================
# scripts/temp-tools/36-gcc-pass2.sh — LFS Ch.6 — GCC-Pass2.
#
# PURPOSE   Rebuild GCC, now cross-compiled to RUN on the target
#           (--host=$LFS_TGT) and installed into $LFS/usr, this time WITH a full
#           C++ standard library (glibc + libstdc++ exist). After install, the
#           book creates the conventional `cc -> gcc` symlink so build systems
#           that invoke `cc` work inside the chroot. As with pass1, the bundled
#           GMP/MPFR/MPC are unpacked into the GCC tree first, and the x86_64
#           multilib path is collapsed to /lib.
#
# RUN AS    the `lfs` build user (NOT root), on the build HOST.
# DEPENDS   35-binutils-pass2 + the full Ch.5 toolchain.
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
_do_gcc_pass2() {
	set -euo pipefail
	local src
	src="$(extract_only "gcc-$GCC_VERSION.tar.xz")"
	cd "$src"

	# --- Bundled math libs into the GCC tree (renamed) ----------------------
	tar -xf "$SOURCES_DIR/mpfr-$MPFR_VERSION.tar.xz"
	mv -v "mpfr-$MPFR_VERSION" mpfr
	tar -xf "$SOURCES_DIR/gmp-$GMP_VERSION.tar.xz"
	mv -v "gmp-$GMP_VERSION" gmp
	tar -xf "$SOURCES_DIR/mpc-$MPC_VERSION.tar.gz"
	mv -v "mpc-$MPC_VERSION" mpc

	# --- Collapse the x86_64 lib64 multilib to a pure /lib layout -----------
	case "$(uname -m)" in
		x86_64)
			sed -e "/m64=/s/lib64/lib/" -i.orig gcc/config/i386/t-linux64
			;;
	esac

	# --- Book step: override the bootstrap build-time limits ----------------
	# Required so the cross build does not pick up the host limits.h.
	mkdir -p build
	cd build

	../configure \
		--build="$(../config.guess)" \
		--host="$LFS_TGT" \
		--target="$LFS_TGT" \
		LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc" \
		--prefix=/usr \
		--with-build-sysroot="$LFS" \
		--enable-default-pie \
		--enable-default-ssp \
		--disable-nls \
		--disable-multilib \
		--disable-libatomic \
		--disable-libgomp \
		--disable-libquadmath \
		--disable-libsanitizer \
		--disable-libssp \
		--disable-libvtv \
		--enable-languages=c,c++

	make
	make DESTDIR="$LFS" install

	# Conventional cc -> gcc symlink inside the target.
	ln -sfv gcc "$LFS/usr/bin/cc"

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "36-gcc-pass2" "GCC-Pass2 (full cross compiler) -> $LFS/usr" -- _do_gcc_pass2

log_ok "GCC-Pass2 installed into $LFS/usr (cc -> gcc symlink created)"
