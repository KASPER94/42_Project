#!/bin/bash
# bonus/10-deps/50-xorgproto.sh — build Xorg protocol headers (BLFS)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# xorgproto provides the X11 protocol headers (Xproto.h, the extension protocol
# defs, etc.) consumed at compile time by libX11 and nearly every Xorg lib.
# It is a meson package and installs headers only.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"
source "$REPO_ROOT/bonus/00-blfs-env.sh"

require_root

# xorgproto ships both autotools and meson; we use meson (BLFS current).
build_package bonus/xorgproto "xorgproto-$XORGPROTO_VERSION.tar.xz" \
	--type=meson --no-check
