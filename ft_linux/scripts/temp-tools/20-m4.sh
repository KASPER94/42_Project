#!/bin/bash
# =============================================================================
# scripts/temp-tools/20-m4.sh — LFS Ch.6 — M4 (cross-compiled temporary tool).
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
#           Cross-compiled with the Ch.5 toolchain ($LFS/tools/bin first on PATH).
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

# Cross-compiled temp tool: --host = the cross target, --build = the host triplet.
build_package temp/m4 "m4-$M4_VERSION.tar.xz" --no-check \
	--configure-args="--host=$LFS_TGT --build=$(uname -m)-pc-linux-gnu"
