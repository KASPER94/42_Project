#!/bin/bash
# =============================================================================
# scripts/temp-tools/28-grep.sh — LFS Ch.6 — Grep (temporary tool).
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

build_package temp/grep "grep-$GREP_VERSION.tar.xz" --no-check \
	--configure-args="--host=$LFS_TGT --build=$(uname -m)-pc-linux-gnu"
