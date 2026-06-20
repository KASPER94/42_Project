#!/bin/bash
# =============================================================================
# scripts/temp-tools/34-xz.sh — LFS Ch.6 — Xz (temporary tool).
# RUN AS the `lfs` build user (NOT root), on the build HOST. Cross-compiled.
# AUTHORED on macOS — RUN by the operator inside the Linux build VM.
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
_do_xz() {
	set -euo pipefail
	local src
	src="$(extract_only "xz-$XZ_VERSION.tar.xz")"
	cd "$src"

	./configure \
		--prefix=/usr \
		--host="$LFS_TGT" \
		--build="$(uname -m)-pc-linux-gnu" \
		--disable-static \
		--docdir="/usr/share/doc/xz-$XZ_VERSION"
	make
	make DESTDIR="$LFS" install

	# Drop the libtool archive (interferes with later cross linking).
	rm -v "$LFS/usr/lib/liblzma.la" 2>/dev/null || true

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "34-xz" "Xz (temp tool) -> $LFS/usr" -- _do_xz

log_ok "Xz (temp tool) installed"
