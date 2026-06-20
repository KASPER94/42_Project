#!/bin/bash
# =============================================================================
# scripts/temp-tools/21-ncurses.sh — LFS Ch.6 — Ncurses (temporary tool).
#
# PURPOSE   Cross-compile Ncurses for $LFS. Because the build needs the `tic`
#           program to run on the BUILD machine (not the cross target), the LFS
#           book first builds a throwaway native `tic` in a build/ subdir, then
#           cross-compiles the libraries proper using that tic. We follow that
#           "tic trick" exactly. Also patches the manifest so a `libncursesw`
#           is built and the non-wide names are linker scripts pointing at it.
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
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
_do_ncurses() {
	set -euo pipefail
	local src
	src="$(extract_only "ncurses-$NCURSES_VERSION.tar.gz")"
	cd "$src"

	# 1) Build a native tic for the BUILD machine in a throwaway build/ subdir.
	mkdir -v build
	pushd build
		../configure AWK=gawk
		make -C include
		make -C progs tic
	popd

	# 2) Cross-compile the real libraries, telling configure where the build
	#    tic lives (TIC_PATH) so terminfo can be generated.
	./configure \
		--prefix=/usr \
		--host="$LFS_TGT" \
		--build="$(uname -m)-pc-linux-gnu" \
		--mandir=/usr/share/man \
		--with-manpage-format=normal \
		--with-shared \
		--without-normal \
		--with-cxx-shared \
		--without-debug \
		--without-ada \
		--disable-stripping \
		AWK=gawk

	make
	make DESTDIR="$LFS" TIC_PATH="$(pwd)/build/progs/tic" install

	# 3) Provide the legacy non-wide names as linker scripts -> wide library,
	#    and a libncurses.so for packages that link plain -lncurses.
	ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"
	sed -e "s/^#if.*XOPEN.*$/#if 1/" \
		-i "$LFS/usr/include/curses.h"

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "21-ncurses" "Ncurses (temp tool, tic trick) -> $LFS/usr" -- _do_ncurses

log_ok "Ncurses (temp tool) installed"
