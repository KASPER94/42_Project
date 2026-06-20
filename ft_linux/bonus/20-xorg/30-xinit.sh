#!/bin/bash
# bonus/20-xorg/30-xinit.sh — build xinit (provides startx) (BLFS)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# xinit provides `startx` and `xinit`, the simple session launchers the demo
# user runs to bring up the WM (no display manager needed). Autotools.
#
# We point --with-xinitdir at /etc/X11/xinit so the system xinitrc lives in a
# standard place; per-user ~/.xinitrc still takes precedence (installed by
# bonus/40-wm/40-install-xinitrc.sh).
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

build_package bonus/xinit "xinit-$XINIT_VERSION.tar.xz" \
	--configure-args="--with-xinitdir=/etc/X11/xinit" \
	--no-check
