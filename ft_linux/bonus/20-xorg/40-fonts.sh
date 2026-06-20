#!/bin/bash
# bonus/20-xorg/40-fonts.sh — base fonts: font-util, a 'fixed' bitmap, DejaVu TTF
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent — each package is its own marker.
#
# A fresh Xorg has NO fonts. We install the minimum a usable desktop needs:
#   * font-util        — fontconfig/font metadata helpers + the font-dir macros
#   * mkfontscale      — provides mkfontscale + mkfontdir (index TTF/bitmap dirs)
#   * bdftopcf         — compiles BDF bitmap fonts to PCF
#   * encodings        — encoding tables the bitmap fonts reference
#   * font-alias       — the X core 'fixed'/'cursor' font aliases
#   * font-misc-misc   — the classic 'fixed' / 6x13 bitmap fonts (so the server's
#                        default 'fixed' font always resolves; many old X apps,
#                        and the server itself, fall back to it)
# Then we install the DejaVu TrueType family for crisp scalable text in st/dwm,
# and finally index every font dir (mkfontscale/mkfontdir) and rebuild the
# fontconfig cache (fc-cache -v).
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

# --- font tooling + metadata ------------------------------------------------
build_package bonus/font-util "font-util-$FONT_UTIL_VERSION.tar.xz" --no-check
build_package bonus/mkfontscale "mkfontscale-$MKFONTSCALE_VERSION.tar.xz" --no-check
build_package bonus/bdftopcf "bdftopcf-$BDFTOPCF_VERSION.tar.xz" --no-check
build_package bonus/encodings "encodings-$ENCODINGS_VERSION.tar.xz" --no-check
build_package bonus/font-alias "font-alias-$FONT_ALIAS_VERSION.tar.xz" --no-check

# font-misc-misc carries the bitmap 'fixed' font. It installs under
# /usr/share/fonts/X11/misc; encodingsdir keeps it pointed at the encodings.
build_package bonus/font-misc-misc "font-misc-misc-$FONT_MISC_MISC_VERSION.tar.xz" \
	--configure-args="--with-fontrootdir=/usr/share/fonts/X11" \
	--no-check

# --- DejaVu TrueType family -------------------------------------------------
run_step bonus/fonts-dejavu "Install DejaVu TTF fonts" -- \
	bash -c '
		set -euo pipefail
		src="$(extract_only "dejavu-fonts-ttf-'"$DEJAVU_VERSION"'.tar.bz2")"
		install -d -m755 /usr/share/fonts/dejavu
		install -m644 "$src"/ttf/*.ttf /usr/share/fonts/dejavu/
		# Drop the upstream fontconfig snippets so DejaVu is preferred for the
		# generic families (sans/serif/monospace).
		if [ -d "$src/fontconfig" ]; then
			install -d -m755 /etc/fonts/conf.d
			install -m644 "$src"/fontconfig/*.conf /etc/fonts/conf.d/ 2>/dev/null || true
		fi
		rm -rf "$src"
		echo "DejaVu installed to /usr/share/fonts/dejavu"
	'

# --- index every font directory + rebuild the fontconfig cache --------------
run_step bonus/fonts-index "Index font dirs + fc-cache" -- \
	bash -c '
		set -euo pipefail
		# Index scalable + bitmap dirs so the X core font path resolves names
		# (mkfontscale builds fonts.scale, mkfontdir builds fonts.dir).
		for d in /usr/share/fonts/dejavu /usr/share/fonts/X11/misc; do
			if [ -d "$d" ]; then
				mkfontscale "$d" || true
				mkfontdir   "$d" || true
			fi
		done
		# Rebuild the fontconfig cache for all configured dirs (verbose).
		fc-cache -v
		echo "font indexes + fontconfig cache rebuilt"
	'

log_ok "Base fonts installed (fixed bitmap + DejaVu TTF), caches rebuilt"
