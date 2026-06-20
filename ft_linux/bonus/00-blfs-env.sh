# shellcheck shell=bash
#
# bonus/00-blfs-env.sh — BLFS bonus versions, URLs, and toggles
# =============================================================================
# SOURCED (never executed) by the bonus scripts AFTER env/lfs.env + lib/*.
#
#     source "$REPO_ROOT/bonus/00-blfs-env.sh"
#
# Why this file (and not env/versions.sh)?
#   env/versions.sh is owned by agent A0 and pins the MANDATORY package set.
#   The bonus (BLFS Xorg + window manager) is graded ONLY if the mandatory part
#   is perfect, so it must never touch or risk the mandatory contract. All
#   bonus-only versions/URLs/toggles therefore live HERE, in a file sourced
#   only by bonus/* scripts.
#
# CONVENTION (same as env/versions.sh)
#   <PKG>_VERSION  exact version string
#   <PKG>_URL      full source tarball URL
#   versions are pinned to a coherent recent-BLFS set; the downloader / build
#   step fails loudly if a URL or version is wrong, so a mismatch is visible.
#
# IMPORTANT: This file is idempotent and POSIX-sourceable. It must NOT run any
# build step — it only declares variables.
# =============================================================================

# Guard against double-sourcing (the bonus sub-stages each source it).
[ -n "${_BONUS_BLFS_ENV_LOADED:-}" ] && return 0
_BONUS_BLFS_ENV_LOADED=1

# -----------------------------------------------------------------------------
# Toggles — override any of these in the environment before run-bonus.sh.
# -----------------------------------------------------------------------------
# Window manager: dwm (default — single tiny binary, near-zero deps, lowest
# "won't compile" risk) or i3 (heavier; pulls xcb-util/cairo/pango/yajl/libev).
BONUS_WM="${BONUS_WM:-dwm}"

# Mesa LLVM path. 0 (default) = softpipe, NO LLVM — saves ~1h of LLVM build and
# is perfectly adequate for a 2D window manager in a VirtualBox guest. 1 =
# llvmpipe (needs a prebuilt LLVM on the system; much longer build).
BONUS_MESA_LLVM="${BONUS_MESA_LLVM:-0}"

# Terminal emulator: st (default — suckless, tiny) or xterm (fallback note in
# 40-wm/20-terminal.sh).
BONUS_TERMINAL="${BONUS_TERMINAL:-st}"

# A non-root user to own the X session. X should NOT run as root. The bonus
# creates this user if it does not already exist (see ensure_bonus_demo_user).
# The fixed project login is 'skapers'; that account exists from system-config,
# so by default we reuse a dedicated demo user to keep the GUI demo isolated.
BONUS_DEMO_USER="${BONUS_DEMO_USER:-student}"

# -----------------------------------------------------------------------------
# Mirrors (kept as variables so a mirror swap is one line).
# -----------------------------------------------------------------------------
XORG_MIRROR="https://www.x.org/pub/individual"
FREEDESKTOP="https://gitlab.freedesktop.org"
MESA_MIRROR="https://mesa.freedesktop.org/archive"
SOURCEFORGE_BONUS="https://downloads.sourceforge.net"

# =============================================================================
# 10-deps — pre-Xorg libraries (BLFS order)
# =============================================================================

# --- libpng / freetype / fontconfig ---
LIBPNG_VERSION=1.6.45
LIBPNG_URL="${SOURCEFORGE_BONUS}/libpng/libpng-${LIBPNG_VERSION}.tar.xz"

FREETYPE_VERSION=2.13.3
FREETYPE_URL="${SOURCEFORGE_BONUS}/freetype/freetype-${FREETYPE_VERSION}.tar.xz"

FONTCONFIG_VERSION=2.16.0
# Official release tarball ships a generated meson build (and configure); the
# GitLab -/archive/ snapshots do NOT, so always use this URL.
FONTCONFIG_URL="https://gitlab.freedesktop.org/fontconfig/fontconfig/-/releases/${FONTCONFIG_VERSION}/downloads/fontconfig-${FONTCONFIG_VERSION}.tar.xz"

# --- Xorg build infrastructure ---
UTIL_MACROS_VERSION=1.20.2
UTIL_MACROS_URL="${XORG_MIRROR}/util/util-macros-${UTIL_MACROS_VERSION}.tar.xz"

XORGPROTO_VERSION=2024.1
XORGPROTO_URL="${XORG_MIRROR}/proto/xorgproto-${XORGPROTO_VERSION}.tar.xz"

LIBXAU_VERSION=1.0.12
LIBXAU_URL="${XORG_MIRROR}/lib/libXau-${LIBXAU_VERSION}.tar.xz"

LIBXDMCP_VERSION=1.1.5
LIBXDMCP_URL="${XORG_MIRROR}/lib/libXdmcp-${LIBXDMCP_VERSION}.tar.xz"

XCB_PROTO_VERSION=1.17.0
XCB_PROTO_URL="${XORG_MIRROR}/proto/xcb-proto-${XCB_PROTO_VERSION}.tar.xz"

LIBXCB_VERSION=1.17.0
LIBXCB_URL="${XORG_MIRROR}/lib/libxcb-${LIBXCB_VERSION}.tar.xz"

# --- the full Xorg library set (100-xorg-libs.sh drives a single ordered
#     list; the version variables are read by name as XORG_LIB_<NAME>_VERSION).
#     These are deliberately grouped here so a version bump is one place.
XTRANS_VERSION=1.5.2
LIBX11_VERSION=1.8.10
LIBXEXT_VERSION=1.3.6
LIBICE_VERSION=1.1.2
LIBSM_VERSION=1.2.5
LIBXT_VERSION=1.3.1
LIBXMU_VERSION=1.2.1
LIBXPM_VERSION=3.5.17
LIBXAW_VERSION=1.0.16
LIBXFIXES_VERSION=6.0.1
LIBXRENDER_VERSION=0.9.11
LIBXCURSOR_VERSION=1.2.3
LIBXDAMAGE_VERSION=1.1.6
LIBFONTENC_VERSION=1.1.8
LIBXFONT2_VERSION=2.0.7
LIBXFT_VERSION=2.3.8
LIBXI_VERSION=1.8.2
LIBXINERAMA_VERSION=1.1.5
LIBXRANDR_VERSION=1.5.4
LIBXTST_VERSION=1.2.5
LIBXKBFILE_VERSION=1.1.3
LIBXSHMFENCE_VERSION=1.3.3
LIBPCIACCESS_VERSION=0.18.1

# --- rendering stack ---
PIXMAN_VERSION=0.44.2
PIXMAN_URL="${XORG_MIRROR}/lib/pixman-${PIXMAN_VERSION}.tar.xz"

LIBDRM_VERSION=2.4.124
LIBDRM_URL="https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VERSION}.tar.xz"

MESA_VERSION=24.3.4
MESA_URL="${MESA_MIRROR}/mesa-${MESA_VERSION}.tar.xz"

LIBEPOXY_VERSION=1.5.10
LIBEPOXY_URL="https://github.com/anholt/libepoxy/releases/download/${LIBEPOXY_VERSION}/libepoxy-${LIBEPOXY_VERSION}.tar.xz"

# =============================================================================
# 20-xorg — server, keymaps, startx, fonts
# =============================================================================
XORG_SERVER_VERSION=21.1.16
XORG_SERVER_URL="${XORG_MIRROR}/xserver/xorg-server-${XORG_SERVER_VERSION}.tar.xz"

XKEYBOARD_CONFIG_VERSION=2.44
XKEYBOARD_CONFIG_URL="${XORG_MIRROR}/data/xkeyboard-config/xkeyboard-config-${XKEYBOARD_CONFIG_VERSION}.tar.xz"

XINIT_VERSION=1.4.4
XINIT_URL="${XORG_MIRROR}/app/xinit-${XINIT_VERSION}.tar.xz"

FONT_UTIL_VERSION=1.4.1
FONT_UTIL_URL="${XORG_MIRROR}/font/font-util-${FONT_UTIL_VERSION}.tar.xz"

# DejaVu TTF fonts — a clean, complete base font family for the desktop.
DEJAVU_VERSION=2.37
DEJAVU_URL="https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_${DEJAVU_VERSION//./_}/dejavu-fonts-ttf-${DEJAVU_VERSION}.tar.bz2"

# A small bitmap "fixed" font set so X always has a usable default font even
# before fontconfig is consulted (xorg-server expects 'fixed' to resolve).
FONT_ALIAS_VERSION=1.0.5
FONT_ALIAS_URL="${XORG_MIRROR}/font/font-alias-${FONT_ALIAS_VERSION}.tar.xz"

ENCODINGS_VERSION=1.1.0
ENCODINGS_URL="${XORG_MIRROR}/font/encodings-${ENCODINGS_VERSION}.tar.xz"

FONT_MISC_MISC_VERSION=1.1.3
FONT_MISC_MISC_URL="${XORG_MIRROR}/font/font-misc-misc-${FONT_MISC_MISC_VERSION}.tar.xz"

MKFONTSCALE_VERSION=1.2.3
MKFONTSCALE_URL="${XORG_MIRROR}/app/mkfontscale-${MKFONTSCALE_VERSION}.tar.xz"

BDFTOPCF_VERSION=1.1.1
BDFTOPCF_URL="${XORG_MIRROR}/app/bdftopcf-${BDFTOPCF_VERSION}.tar.xz"

# =============================================================================
# 40-wm — window manager + terminal + launcher (suckless defaults)
# =============================================================================
DWM_VERSION=6.5
DWM_URL="https://dl.suckless.org/dwm/dwm-${DWM_VERSION}.tar.gz"

DMENU_VERSION=5.3
DMENU_URL="https://dl.suckless.org/tools/dmenu-${DMENU_VERSION}.tar.gz"

SLSTATUS_VERSION=1.0
SLSTATUS_URL="https://dl.suckless.org/tools/slstatus-${SLSTATUS_VERSION}.tar.gz"

ST_VERSION=0.9.2
ST_URL="https://dl.suckless.org/st/st-${ST_VERSION}.tar.gz"

# --- i3 alternative (only built when BONUS_WM=i3) + its dependency chain ---
XCB_UTIL_VERSION=0.4.1
XCB_UTIL_URL="${XORG_MIRROR}/../../releases/individual/xcb/xcb-util-${XCB_UTIL_VERSION}.tar.xz"

XCB_UTIL_CURSOR_VERSION=0.1.5
XCB_UTIL_CURSOR_URL="${XORG_MIRROR}/../../releases/individual/xcb/xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz"

XCB_UTIL_KEYSYMS_VERSION=0.4.1
XCB_UTIL_KEYSYMS_URL="${XORG_MIRROR}/../../releases/individual/xcb/xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz"

XCB_UTIL_WM_VERSION=0.4.2
XCB_UTIL_WM_URL="${XORG_MIRROR}/../../releases/individual/xcb/xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz"

XCB_UTIL_XRM_VERSION=1.3
XCB_UTIL_XRM_URL="https://github.com/Airblader/xcb-util-xrm/releases/download/v${XCB_UTIL_XRM_VERSION}/xcb-util-xrm-${XCB_UTIL_XRM_VERSION}.tar.bz2"

CAIRO_VERSION=1.18.2
CAIRO_URL="https://www.cairographics.org/releases/cairo-${CAIRO_VERSION}.tar.xz"

PANGO_VERSION=1.56.1
PANGO_URL="https://download.gnome.org/sources/pango/${PANGO_VERSION%.*}/pango-${PANGO_VERSION}.tar.xz"

YAJL_VERSION=2.1.0
YAJL_URL="https://github.com/lloyd/yajl/archive/${YAJL_VERSION}/yajl-${YAJL_VERSION}.tar.gz"

LIBEV_VERSION=4.33
LIBEV_URL="http://dist.schmorp.de/libev/libev-${LIBEV_VERSION}.tar.gz"

I3_VERSION=4.24
I3_URL="https://i3wm.org/downloads/i3-${I3_VERSION}.tar.xz"

# -----------------------------------------------------------------------------
# Export everything declared above so that:
#   * the downloader (sources/) can read every <PKG>_URL,
#   * the build scripts can read every <PKG>_VERSION (the Xlib set reads them by
#     name via indirect expansion ${!var} in 10-deps/100-xorg-libs.sh), and
#   * child processes inherit the toggles.
# Re-exported by name to keep the list auditable, exactly as env/versions.sh.
# -----------------------------------------------------------------------------
export BONUS_WM BONUS_MESA_LLVM BONUS_TERMINAL BONUS_DEMO_USER
export XORG_MIRROR FREEDESKTOP MESA_MIRROR SOURCEFORGE_BONUS
export LIBPNG_VERSION LIBPNG_URL FREETYPE_VERSION FREETYPE_URL
export FONTCONFIG_VERSION FONTCONFIG_URL
export UTIL_MACROS_VERSION UTIL_MACROS_URL XORGPROTO_VERSION XORGPROTO_URL
export LIBXAU_VERSION LIBXAU_URL LIBXDMCP_VERSION LIBXDMCP_URL
export XCB_PROTO_VERSION XCB_PROTO_URL LIBXCB_VERSION LIBXCB_URL
export XTRANS_VERSION LIBX11_VERSION LIBXEXT_VERSION LIBICE_VERSION LIBSM_VERSION
export LIBXT_VERSION LIBXMU_VERSION LIBXPM_VERSION LIBXAW_VERSION
export LIBXFIXES_VERSION LIBXRENDER_VERSION LIBXCURSOR_VERSION LIBXDAMAGE_VERSION
export LIBFONTENC_VERSION LIBXFONT2_VERSION LIBXFT_VERSION LIBXI_VERSION
export LIBXINERAMA_VERSION LIBXRANDR_VERSION LIBXTST_VERSION LIBXKBFILE_VERSION
export LIBXSHMFENCE_VERSION LIBPCIACCESS_VERSION
export PIXMAN_VERSION PIXMAN_URL LIBDRM_VERSION LIBDRM_URL
export MESA_VERSION MESA_URL LIBEPOXY_VERSION LIBEPOXY_URL
export XORG_SERVER_VERSION XORG_SERVER_URL
export XKEYBOARD_CONFIG_VERSION XKEYBOARD_CONFIG_URL XINIT_VERSION XINIT_URL
export FONT_UTIL_VERSION FONT_UTIL_URL DEJAVU_VERSION DEJAVU_URL
export FONT_ALIAS_VERSION FONT_ALIAS_URL ENCODINGS_VERSION ENCODINGS_URL
export FONT_MISC_MISC_VERSION FONT_MISC_MISC_URL
export MKFONTSCALE_VERSION MKFONTSCALE_URL BDFTOPCF_VERSION BDFTOPCF_URL
export DWM_VERSION DWM_URL DMENU_VERSION DMENU_URL
export SLSTATUS_VERSION SLSTATUS_URL ST_VERSION ST_URL
export XCB_UTIL_VERSION XCB_UTIL_URL XCB_UTIL_CURSOR_VERSION XCB_UTIL_CURSOR_URL
export XCB_UTIL_KEYSYMS_VERSION XCB_UTIL_KEYSYMS_URL
export XCB_UTIL_WM_VERSION XCB_UTIL_WM_URL XCB_UTIL_XRM_VERSION XCB_UTIL_XRM_URL
export CAIRO_VERSION CAIRO_URL PANGO_VERSION PANGO_URL
export YAJL_VERSION YAJL_URL LIBEV_VERSION LIBEV_URL I3_VERSION I3_URL

# -----------------------------------------------------------------------------
# ensure_bonus_demo_user — make sure a non-root user exists for startx.
#   Idempotent. Creates $BONUS_DEMO_USER (with a home dir + bash shell) if it
#   is not already present in /etc/passwd. Adds it to the 'video' and 'input'
#   groups (created if missing) so DRM/evdev devices are usable without root.
#   Called by run-bonus.sh and by 40-wm/40-install-xinitrc.sh.
# -----------------------------------------------------------------------------
ensure_bonus_demo_user() {
	require_root
	# Make sure the helper groups exist (harmless if they already do).
	getent group video >/dev/null 2>&1 || groupadd -r video
	getent group input >/dev/null 2>&1 || groupadd -r input

	if getent passwd "$BONUS_DEMO_USER" >/dev/null 2>&1; then
		log_info "demo user '$BONUS_DEMO_USER' already exists"
	else
		log_info "creating non-root demo user '$BONUS_DEMO_USER' for the X session"
		useradd -m -s /bin/bash -c "ft_linux bonus X demo user" "$BONUS_DEMO_USER"
		# No password set: lock it but allow su/login via the console as needed.
		# An evaluator can `passwd $BONUS_DEMO_USER` or `su - $BONUS_DEMO_USER`.
		passwd -l "$BONUS_DEMO_USER" >/dev/null 2>&1 || true
	fi

	# Ensure membership in video + input regardless of how the user was made.
	usermod -aG video,input "$BONUS_DEMO_USER"
}

# -----------------------------------------------------------------------------
# bonus_demo_home — echo the home directory of $BONUS_DEMO_USER.
# -----------------------------------------------------------------------------
bonus_demo_home() {
	getent passwd "$BONUS_DEMO_USER" | cut -d: -f6
}
