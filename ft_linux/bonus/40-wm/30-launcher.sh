#!/bin/bash
# bonus/40-wm/30-launcher.sh — application launcher (dmenu) + optional status bar
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent (run_step markers).
#
# dmenu is the suckless dynamic menu — dwm's standard app launcher (MODKEY+p).
# It is a tiny binary with the same Xlib/Xft deps as dwm. slstatus is the
# optional suckless status monitor that feeds dwm's bar (clock/load/etc.).
#
# For i3 these are not strictly needed (i3 ships i3bar + i3-dmenu-desktop), but
# dmenu is still a useful generic launcher, so we always build it.
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

# --- dmenu ------------------------------------------------------------------
log_info "Building dmenu $DMENU_VERSION (suckless launcher)"
src="$(extract_only "dmenu-$DMENU_VERSION.tar.gz")"
run_step bonus/dmenu "Build + install dmenu" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		cp -f config.def.h config.h
		make clean
		make PREFIX=/usr X11INC=/usr/include X11LIB=/usr/lib \
			FREETYPEINC=/usr/include/freetype2
		make PREFIX=/usr install
		echo "dmenu installed to /usr/bin/dmenu"
	' _ "$src"
rm -rf "$src"

# --- slstatus (optional, only meaningful with dwm) --------------------------
if [ "$BONUS_WM" = "dwm" ]; then
	log_info "Building slstatus $SLSTATUS_VERSION (optional dwm status bar feeder)"
	src="$(extract_only "slstatus-$SLSTATUS_VERSION.tar.gz")"
	run_step bonus/slstatus "Build + install slstatus" -- \
		bash -c '
			set -euo pipefail
			cd "$1"
			cp -f config.def.h config.h
			make clean
			make PREFIX=/usr
			make PREFIX=/usr install
			echo "slstatus installed to /usr/bin/slstatus"
		' _ "$src"
	rm -rf "$src"
else
	log_info "BONUS_WM=$BONUS_WM: skipping slstatus (i3 has its own i3bar/i3status)."
fi

log_ok "Launcher (dmenu) + optional status bar installed"
