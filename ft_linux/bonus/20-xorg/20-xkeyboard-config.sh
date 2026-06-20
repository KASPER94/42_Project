#!/bin/bash
# bonus/20-xorg/20-xkeyboard-config.sh — build xkeyboard-config (BLFS)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# xkeyboard-config supplies the keymap data the X server compiles with xkbcomp.
# Without it the server cannot map a keyboard and X fails to start. meson build;
# the data is installed under /usr/share/X11/xkb (matching the server's
# -Dxkb_dir above).
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

build_package bonus/xkeyboard-config "xkeyboard-config-$XKEYBOARD_CONFIG_VERSION.tar.xz" \
	--type=meson --no-check
