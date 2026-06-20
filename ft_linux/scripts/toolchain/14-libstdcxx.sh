#!/bin/bash
# =============================================================================
# scripts/toolchain/14-libstdcxx.sh
#   LFS Ch.5 — Libstdc++ (from the GCC source tree, deferred from GCC-Pass1).
#
# PURPOSE   GCC-Pass1 built only the compiler + libgcc; the C++ standard library
#           needs a working Glibc, so it is built now (Glibc is installed). We
#           re-extract the SAME gcc tarball, then configure ONLY the libstdc++-v3
#           subdirectory against the cross target, build, and install into
#           $LFS/usr. This provides libstdc++ for the Ch.6 temp tools that need
#           C++ (e.g. GCC-Pass2 itself).
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
#
# DEPENDS   11-gcc-pass1.sh and 13-glibc.sh complete.
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
# the sourced helpers stay in scope — a `bash -c` child would not see them).
_do_libstdcxx() {
	set -euo pipefail
	local src gcc_major
	src="$(extract_only "gcc-$GCC_VERSION.tar.xz")"
	cd "$src"

	# Out-of-tree build dir; configure only the libstdc++-v3 subtree.
	rm -rf build
	mkdir -v build
	cd build

	# GCC_VER is the major version; libstdc++ headers go under .../include/c++/<ver>.
	gcc_major="${GCC_VERSION%%.*}"

	../libstdc++-v3/configure \
		--host="$LFS_TGT" \
		--build="$(../config.guess)" \
		--prefix=/usr \
		--disable-multilib \
		--disable-nls \
		--disable-libstdcxx-pch \
		--with-gxx-include-dir="/tools/$LFS_TGT/include/c++/$gcc_major"

	make
	make DESTDIR="$LFS" install

	# Remove the libtool archive files (they harm later cross builds).
	rm -v "$LFS"/usr/lib/lib{stdc++{,exp,fs},supc++}.la 2>/dev/null || true

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "14-libstdcxx" "Libstdc++ (from GCC tree) -> $LFS/usr" -- _do_libstdcxx

log_ok "Libstdc++ installed into $LFS/usr"
