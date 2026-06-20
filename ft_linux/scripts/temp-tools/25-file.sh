#!/bin/bash
# =============================================================================
# scripts/temp-tools/25-file.sh — LFS Ch.6 — File (temporary tool).
#
# PURPOSE   Cross-compile File for $LFS. File's build needs to RUN the `file`
#           program on the BUILD machine to compile the magic database, so the
#           LFS book builds a throwaway native `file` in a build/ subdir first,
#           then cross-compiles the package proper pointing at that build file.
#
# RUN AS    the `lfs` build user (NOT root), on the build HOST.
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
_do_file() {
	set -euo pipefail
	local src
	src="$(extract_only "file-$FILE_VERSION.tar.gz")"
	cd "$src"

	# 1) Native build (build machine) so we have a working `file` for the
	#    magic-database compilation step of the cross build.
	mkdir -v build
	pushd build
		../configure \
			--disable-bzlib \
			--disable-libseccomp \
			--disable-xzlib \
			--disable-zlib
		make
	popd

	# 2) Cross build of the real package, using the native file just built.
	./configure \
		--prefix=/usr \
		--host="$LFS_TGT" \
		--build="$(uname -m)-pc-linux-gnu"
	make FILE_COMPILE="$(pwd)/build/src/file"
	make DESTDIR="$LFS" install

	# Remove the libtool archive (interferes with later cross linking).
	rm -v "$LFS/usr/lib/libmagic.la" 2>/dev/null || true

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "25-file" "File (temp tool, native-then-cross) -> $LFS/usr" -- _do_file

log_ok "File (temp tool) installed"
