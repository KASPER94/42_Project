#!/bin/bash
# bonus/10-deps/100-xorg-libs.sh — build the full Xorg Xlib set (BLFS)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent — each lib is its own build_package
# marker (bonus/xlib/<name>), so a re-run resumes mid-set after a failure.
#
# This builds, IN DEPENDENCY ORDER, the Xorg client libraries that the server,
# the WM, the terminal and the fonts stack need. We drive it from ONE ordered
# list (NAME VERSION) to avoid drift: the tarball is "<Name>-<ver>.tar.xz" and
# (for all of these) lives under ${XORG_MIRROR}/lib/. Versions come from
# bonus/00-blfs-env.sh.
#
# Order rationale (BLFS "Xorg Libraries" page order):
#   xtrans (transport)            -> libX11 needs it
#   libX11 (core Xlib)            -> everything client-side
#   libXext (common extensions)
#   libICE, libSM (session mgmt)  -> libXt needs them
#   libXt (X Toolkit intrinsics)  -> libXmu/libXaw need it
#   libXmu, libXpm, libXaw (widgets / pixmaps)
#   libXfixes (fixes ext)         -> libXcursor/libXdamage/libXrandr need it
#   libXrender (Render ext)       -> libXcursor/libXft need it
#   libXcursor, libXdamage
#   libfontenc, libXfont2         -> font handling in the server
#   libXft (client-side AA fonts) -> st / dmenu / dwm
#   libXi, libXinerama, libXrandr, libXtst (input / RandR / test ext)
#   libxkbfile (keymap files)     -> setxkbmap / xkbcomp
#   libxshmfence (shm fences)     -> Mesa / DRI3
#   libpciaccess (PCI access)     -> Xorg server / DRM
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

# ---------------------------------------------------------------------------
# The single ordered list. Each row: "<tarball-stem> <version-var-name>".
# tarball-stem is the case-correct package name (e.g. libX11); the tarball is
# "<stem>-<version>.tar.xz". We look up the version by variable name so there
# is exactly one place per lib to bump a version (bonus/00-blfs-env.sh).
# A few packages take extra configure args; handled by name in the loop.
# ---------------------------------------------------------------------------
XORG_LIBS="
xtrans       XTRANS_VERSION
libX11       LIBX11_VERSION
libXext      LIBXEXT_VERSION
libICE       LIBICE_VERSION
libSM        LIBSM_VERSION
libXt        LIBXT_VERSION
libXmu       LIBXMU_VERSION
libXpm       LIBXPM_VERSION
libXaw       LIBXAW_VERSION
libXfixes    LIBXFIXES_VERSION
libXrender   LIBXRENDER_VERSION
libXcursor   LIBXCURSOR_VERSION
libXdamage   LIBXDAMAGE_VERSION
libfontenc   LIBFONTENC_VERSION
libXfont2    LIBXFONT2_VERSION
libXft       LIBXFT_VERSION
libXi        LIBXI_VERSION
libXinerama  LIBXINERAMA_VERSION
libXrandr    LIBXRANDR_VERSION
libXtst      LIBXTST_VERSION
libxkbfile   LIBXKBFILE_VERSION
libxshmfence LIBXSHMFENCE_VERSION
libpciaccess LIBPCIACCESS_VERSION
"

# Read the list two tokens at a time.
set -- $XORG_LIBS
while [ "$#" -ge 2 ]; do
	_stem="$1"; _vervar="$2"; shift 2
	# Indirect-expand the version variable (e.g. LIBX11_VERSION -> 1.8.10).
	_ver="${!_vervar:-}"
	[ -n "$_ver" ] || die "100-xorg-libs: version variable $_vervar is unset (check bonus/00-blfs-env.sh)"

	# Per-package configure tweaks. Most take none.
	_extra=""
	case "$_stem" in
		libX11)
			# Disable docs (no xmlto/fop in the minimal system).
			_extra="--disable-specs" ;;
		libXt)
			# Point app-defaults at the standard /etc/X11 location.
			_extra="--with-appdefaultdir=/etc/X11/app-defaults" ;;
		libpciaccess)
			# meson-only package; handled below, _extra unused.
			: ;;
	esac

	# libpciaccess and libxshmfence ship meson builds in current BLFS; the rest
	# are autotools. Build accordingly.
	case "$_stem" in
		libpciaccess|libxshmfence)
			build_package "bonus/xlib/$_stem" "$_stem-$_ver.tar.xz" \
				--type=meson --no-check
			;;
		*)
			# shellcheck disable=SC2086  # intentional split of $_extra
			build_package "bonus/xlib/$_stem" "$_stem-$_ver.tar.xz" \
				--no-check $_extra
			;;
	esac
done

log_ok "Xorg Xlib set built"
