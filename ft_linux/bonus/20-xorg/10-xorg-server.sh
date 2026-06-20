#!/bin/bash
# bonus/20-xorg/10-xorg-server.sh — build the Xorg X server (BLFS)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# This is the heart of the bonus: the X11 display server. We build it with the
# built-in 'modesetting' driver (DDX) which drives ANY DRM/KMS device through
# the kernel — including VirtualBox's in-kernel vboxvideo. That means NO
# separate video-driver package and NO Guest Additions are required.
#
# Key choices:
#   * xorg-server 21.x uses MESON (the old autotools build was dropped). We use
#     --type=meson.
#   * suid_wrapper enabled  -> installs /usr/libexec/Xorg.wrap, the small setuid
#     helper that lets a non-root user start X via startx without the whole
#     server being setuid-root. (Needed because we run X as $BONUS_DEMO_USER.)
#   * glamor ENABLED at build time (cheap, links libepoxy) but the modesetting
#     driver will fall back to software (shadow fb / softpipe) at runtime in the
#     VBox guest — so we get a working server with or without GL acceleration.
#   * Xvfb/Xnest/Xephyr off, dri/glx on for the software GL path.
#
# After install we drop the modesetting Device/Monitor config so a VBox guest
# WITHOUT Guest Additions still gets a sane fixed resolution.
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

# Build the server. -Dsuid_wrapper=true gives us Xorg.wrap for rootless startx.
build_package bonus/xorg-server "xorg-server-$XORG_SERVER_VERSION.tar.xz" \
	--type=meson \
	--configure-args="-Dxorg=true -Dudev=true -Dudev_kms=true -Dglamor=true -Ddri3=true -Dsuid_wrapper=true -Dxkb_dir=/usr/share/X11/xkb -Dxkb_output_dir=/var/lib/xkb -Dsystemd_logind=true -Dxvfb=false -Dxnest=false -Dxephyr=false -Ddocs=false" \
	--no-check

# ---------------------------------------------------------------------------
# Install the modesetting Device + Monitor drop-in so a VBox guest without
# Guest Additions still negotiates a usable fixed resolution. The file is
# version-controlled at bonus/xorg.conf.d/10-monitor.conf.
# ---------------------------------------------------------------------------
run_step bonus/xorg-server-conf "Install /etc/X11/xorg.conf.d/10-monitor.conf" -- \
	bash -c '
		set -euo pipefail
		install -d -m755 /etc/X11/xorg.conf.d
		install -m644 "$1/bonus/xorg.conf.d/10-monitor.conf" \
			/etc/X11/xorg.conf.d/10-monitor.conf
		echo "installed modesetting Device/Monitor drop-in"
	' _ "$REPO_ROOT"

log_ok "Xorg server installed (modesetting driver, Xorg.wrap suid helper)"
