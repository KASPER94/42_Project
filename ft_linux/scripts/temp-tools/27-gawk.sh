#!/bin/bash
# =============================================================================
# scripts/temp-tools/27-gawk.sh — LFS Ch.6 — Gawk (temporary tool).
# RUN AS the `lfs` build user (NOT root), on the build HOST. Cross-compiled.
# AUTHORED on macOS — RUN by the operator inside the Linux build VM.
#
# NOTE: the LFS book first removes the `extras` Makefile fragment so unneeded
# components are not built. We do that via a pre-extract patch-in-the-builder
# is not possible with build_package, so this one runs manually.
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
_do_gawk() {
	set -euo pipefail
	local src
	src="$(extract_only "gawk-$GAWK_VERSION.tar.xz")"
	cd "$src"

	# Do not build the extras (need to run on the target; not wanted as temp).
	sed -i "s/extras//" Makefile.in

	./configure \
		--prefix=/usr \
		--host="$LFS_TGT" \
		--build="$(uname -m)-pc-linux-gnu"
	make
	make DESTDIR="$LFS" install

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "27-gawk" "Gawk (temp tool) -> $LFS/usr" -- _do_gawk

log_ok "Gawk (temp tool) installed"
