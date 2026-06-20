#!/bin/bash
# =============================================================================
# scripts/toolchain/10-binutils-pass1.sh
#   LFS Ch.5 — Binutils-Pass1 (the cross-toolchain assembler/linker).
#
# PURPOSE   Build the first-pass Binutils that targets $LFS_TGT and installs
#           into $LFS/tools. This is the very first piece of the cross-toolchain;
#           every later tool (GCC pass1, glibc, libstdc++) links through it.
#
# RUN AS    the unprivileged `lfs` build user (NOT root). On the build HOST,
#           before chroot. The lfs user's environment already puts
#           $LFS/tools/bin first on PATH (see env/lfs.env).
#
# AUTHORED  on macOS — this script is RUN by the operator inside the Linux
#           build VM. chmod +x or invoke via `bash`.
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

# This step must run as the lfs build user, not root.
require_not_root

# Binutils pass1 needs custom cross-compile flags + an out-of-tree build dir,
# so we drive it manually. We define the work as a script-local function and
# hand it to run_step (which executes it IN-PROCESS, so the sourced helpers
# like extract_only stay in scope — a `bash -c` child would NOT see them).
_do_binutils_pass1() {
	set -euo pipefail
	local src
	src="$(extract_only "binutils-$BINUTILS_VERSION.tar.xz")"
	cd "$src"

	# LFS builds Binutils out-of-tree in a dedicated build/ directory.
	rm -rf build
	mkdir -v build
	cd build

	../configure \
		--prefix="$LFS/tools" \
		--with-sysroot="$LFS" \
		--target="$LFS_TGT" \
		--disable-nls \
		--enable-gprofng=no \
		--disable-werror \
		--enable-default-hash-style=gnu

	make
	make install

	# Clean up the extracted tree (build_package would do this for us; here we
	# do it explicitly since we drove the build manually).
	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "10-binutils-pass1" "Binutils-Pass1 -> $LFS/tools" -- _do_binutils_pass1

log_ok "Binutils-Pass1 installed into $LFS/tools"
