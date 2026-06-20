#!/bin/bash
# =============================================================================
# scripts/toolchain/12-linux-api-headers.sh
#   LFS Ch.5 — Linux API Headers.
#
# PURPOSE   Expose the kernel's API headers to Glibc (and the rest of the
#           system). We DO NOT build the kernel here — only sanitize and copy
#           the userspace-facing headers into $LFS/usr/include.
#             make mrproper        # pristine tree
#             make headers         # generate ./usr/include
#             find ... -not -name '*.h' -delete   # drop non-header cruft
#             cp -r usr/include -> $LFS/usr/include
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
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
# the other sourced helpers stay in scope — a `bash -c` child would not).
_do_linux_headers() {
	set -euo pipefail
	local src
	src="$(extract_only "linux-$KERNEL_VERSION.tar.xz")"
	cd "$src"

	# Ensure a pristine tree (removes any stale config/objects).
	make mrproper

	# Generate the sanitized userspace headers into ./usr/include.
	make headers

	# Keep only header files; the headers target leaves a few stray files.
	find usr/include -type f ! -name "*.h" -delete

	# Install into the target. -m 0755 dir / preserve header tree.
	mkdir -p "$LFS/usr"
	cp -rv usr/include "$LFS/usr"

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "12-linux-api-headers" "Linux API Headers -> $LFS/usr/include" -- _do_linux_headers

log_ok "Linux API headers installed into $LFS/usr/include"
