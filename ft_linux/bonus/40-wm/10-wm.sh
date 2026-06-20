#!/bin/bash
# bonus/40-wm/10-wm.sh — build the window manager (dwm default, i3 alternative)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent (build_package / run_step markers).
#
# BONUS_WM selects the WM (default dwm):
#   dwm — suckless dynamic window manager: ONE tiny C binary, deps = the Xlib
#         set + libXft we already built. Lowest "won't compile" risk, which is
#         exactly what we want for a graded bonus. We customise config.def.h to
#         set the MODKEY to the Super/Windows key and bind it+Enter to our
#         terminal so the demo is usable out of the box, THEN make install.
#   i3  — full tiling WM; pulls a heavier dep chain (xcb-util*, cairo, pango,
#         yajl, libev). Built only when BONUS_WM=i3.
#
# We must edit dwm's config.h BEFORE building, and build_package builds in a
# throwaway dir, so the suckless path uses extract_only + run_step (edit -> make
# -> make install). This matches the suckless "edit config.h, make install"
# workflow the plan calls for.
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

case "$BONUS_WM" in
# ---------------------------------------------------------------------------
dwm)
	log_info "Building dwm $DWM_VERSION (terminal keybind = $BONUS_TERMINAL)"
	src="$(extract_only "dwm-$DWM_VERSION.tar.gz")"
	# Export the chosen terminal so the heredoc-free sed can reference it.
	export _BONUS_TERMINAL="$BONUS_TERMINAL"
	run_step bonus/dwm "Configure + build + install dwm" -- \
		bash -c '
			set -euo pipefail
			cd "$1"
			term="$2"

			# Start from the upstream defaults, then customise.
			cp -f config.def.h config.h

			# 1) MODKEY: use the Super/Windows key (Mod4) instead of Alt (Mod1),
			#    so dwk keybinds do not clash with terminal/app Alt shortcuts.
			sed -i "s/#define MODKEY Mod1Mask/#define MODKEY Mod4Mask/" config.h

			# 2) Terminal keybind: dwm spawns the command named by the "termcmd"
			#    array (default "st"). Point it at the chosen terminal so
			#    MODKEY+Shift+Enter launches OUR terminal.
			sed -i "s/\"st\", NULL/\"${term}\", NULL/g" config.h

			# Build against the system Xlib/Xft. dwm honours CFLAGS/LDFLAGS from
			# config.mk; pkg-config picks up our freetype2/fontconfig.
			make clean
			make PREFIX=/usr X11INC=/usr/include X11LIB=/usr/lib \
				FREETYPEINC=/usr/include/freetype2
			make PREFIX=/usr install
			echo "dwm installed to /usr/bin/dwm"
		' _ "$src" "$BONUS_TERMINAL"
	unset _BONUS_TERMINAL
	rm -rf "$src"
	log_ok "dwm built and installed"
	;;
# ---------------------------------------------------------------------------
i3)
	log_info "Building i3 $I3_VERSION and its dependency chain (heavier path)"
	# i3 dependency chain (each idempotent; meson/autotools per upstream).
	build_package bonus/wm-deps/xcb-util         "xcb-util-$XCB_UTIL_VERSION.tar.xz" --no-check
	build_package bonus/wm-deps/xcb-util-keysyms "xcb-util-keysyms-$XCB_UTIL_KEYSYMS_VERSION.tar.xz" --no-check
	build_package bonus/wm-deps/xcb-util-wm      "xcb-util-wm-$XCB_UTIL_WM_VERSION.tar.xz" --no-check
	build_package bonus/wm-deps/xcb-util-cursor  "xcb-util-cursor-$XCB_UTIL_CURSOR_VERSION.tar.xz" --no-check
	build_package bonus/wm-deps/xcb-util-xrm     "xcb-util-xrm-$XCB_UTIL_XRM_VERSION.tar.bz2" --no-check
	build_package bonus/wm-deps/yajl             "yajl-$YAJL_VERSION.tar.gz" --type=cmake --no-check
	build_package bonus/wm-deps/libev            "libev-$LIBEV_VERSION.tar.gz" --no-check
	build_package bonus/wm-deps/cairo            "cairo-$CAIRO_VERSION.tar.xz" --type=meson --no-check
	build_package bonus/wm-deps/pango            "pango-$PANGO_VERSION.tar.xz" --type=meson --no-check
	# i3 itself uses meson.
	build_package bonus/i3 "i3-$I3_VERSION.tar.xz" --type=meson --no-check
	log_ok "i3 built and installed"
	;;
# ---------------------------------------------------------------------------
*)
	die "10-wm.sh: unknown BONUS_WM='$BONUS_WM' (expected 'dwm' or 'i3')"
	;;
esac
