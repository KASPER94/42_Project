#!/bin/bash
# bonus/40-wm/20-terminal.sh — build the terminal emulator (st default)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent (run_step / build_package markers).
#
# A window manager is useless without a terminal. Default = st (suckless simple
# terminal): one small C binary, deps = libX11 + libXft + fontconfig + freetype,
# all already built. We set the default font to DejaVu Sans Mono so text renders
# immediately, then make install — same suckless edit-config.h workflow as dwm.
#
# BONUS_TERMINAL=xterm is noted as a fallback but NOT built here (xterm pulls
# extra deps — libXaw/Xt, which we did build — but st is the lighter, more
# reliable default; if you prefer xterm, build it from BLFS and update the
# xinitrc terminal keybind).
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

case "$BONUS_TERMINAL" in
st)
	log_info "Building st $ST_VERSION (suckless simple terminal)"
	src="$(extract_only "st-$ST_VERSION.tar.gz")"
	run_step bonus/st "Configure + build + install st" -- \
		bash -c '
			set -euo pipefail
			cd "$1"
			cp -f config.def.h config.h
			# Default to a DejaVu monospace face at a comfortable size so st has
			# a real, installed font (we shipped DejaVu in 20-xorg/40-fonts.sh).
			sed -i "s/\"Liberation Mono:pixelsize=12:antialias=true:autohint=true\"/\"DejaVu Sans Mono:pixelsize=14:antialias=true:autohint=true\"/" config.h
			make clean
			make PREFIX=/usr X11INC=/usr/include X11LIB=/usr/lib \
				FREETYPEINC=/usr/include/freetype2
			make PREFIX=/usr install
			# st ships a terminfo entry; install it so ncurses apps work in st.
			if command -v tic >/dev/null 2>&1 && [ -f st.info ]; then
				tic -sx st.info || true
			fi
			echo "st installed to /usr/bin/st"
		' _ "$src"
	rm -rf "$src"
	log_ok "st built and installed"
	;;
xterm)
	log_warn "BONUS_TERMINAL=xterm selected, but this script only builds 'st'."
	log_warn "xterm is a valid fallback: build it from BLFS (deps: libXaw/Xt — already present),"
	log_warn "then ensure your WM terminal keybind launches 'xterm'. Skipping build here."
	;;
*)
	die "20-terminal.sh: unknown BONUS_TERMINAL='$BONUS_TERMINAL' (expected 'st' or 'xterm')"
	;;
esac
