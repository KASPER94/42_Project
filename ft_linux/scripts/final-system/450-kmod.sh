#!/bin/bash
# scripts/final-system/450-kmod.sh — build Kmod (kernel module utilities)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Kmod provides modprobe/insmod/lsmod etc. systemd-udevd uses libkmod to load
# drivers.
#
# ORDERING NOTE: in the build order Meson/Ninja are NOT yet installed when kmod
# is built (they come later, at 490/500). kmod >=31 ships ONLY a meson build,
# so KMOD_VERSION (34) cannot be configured with autotools. We therefore build
# kmod's required meson here ad-hoc only if meson is missing — but the cleaner,
# book-faithful path is to keep kmod's autotools `configure` (kmod through 33
# shipped it). If env/versions.sh pins a meson-only kmod, set the version to a
# <=33 release OR move 490/500 (ninja/meson) ahead of this script. We detect at
# runtime and use whichever build system the tarball provides.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Build kmod, auto-selecting the build system the tarball ships:
#   * ./configure present  -> autotools (kmod <= 33; the LFS book path)
#   * meson.build present  -> meson (kmod >= 31; needs meson, installed at 500)
src="$(extract_only "kmod-$KMOD_VERSION.tar.xz")"
run_step final/kmod "Build & install kmod $KMOD_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		if [ -x ./configure ]; then
			# autotools path (LFS book) — enable compressed-module + openssl support.
			./configure --prefix=/usr \
				--sysconfdir=/etc \
				--with-openssl \
				--with-xz \
				--with-zstd \
				--with-zlib
			make
			make install
		elif [ -f meson.build ]; then
			# meson path — requires meson/ninja to already be installed. If they
			# are not, this is a hard error pointing at the ordering note above.
			command -v meson >/dev/null 2>&1 || {
				echo "ERROR: kmod $KMOD_VERSION needs meson, which is not yet installed." >&2
				echo "       Either pin kmod <= 33 in env/versions.sh or build ninja/meson first." >&2
				exit 1
			}
			meson setup build --prefix=/usr --buildtype=release \
				-Dmanpages=true -Dzstd=enabled -Dxz=enabled -Dzlib=enabled -Dopenssl=enabled
			ninja -C build
			ninja -C build install
		else
			echo "ERROR: kmod source has neither ./configure nor meson.build" >&2
			exit 1
		fi
	' _ "$src"
