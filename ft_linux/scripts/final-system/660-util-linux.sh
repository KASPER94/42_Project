#!/bin/bash
# scripts/final-system/660-util-linux.sh — build FINAL Util-linux (system utilities)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Util-linux provides mount, fdisk, blkid, lscpu, agetty, dmesg, etc. — many of
# them needed before AND after systemd. The book builds with an explicit set of
# --disable/--without flags so it does not collide with systemd-provided tools.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "util-linux-$UTIL_LINUX_VERSION.tar.xz")"
run_step final/util-linux "Build & install FINAL util-linux $UTIL_LINUX_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# The book ensures the runtime state dir exists.
		mkdir -pv /var/lib/hwclock

		./configure \
			--bindir=/usr/bin \
			--libdir=/usr/lib \
			--runstatedir=/run \
			--sbindir=/usr/sbin \
			--disable-chfn-chsh \
			--disable-login \
			--disable-nologin \
			--disable-su \
			--disable-setpriv \
			--disable-runuser \
			--disable-pylibmount \
			--disable-static \
			--disable-liblastlog2 \
			--without-python \
			ADJTIME_PATH=/var/lib/hwclock/adjtime \
			--docdir=/usr/share/doc/util-linux-'"$UTIL_LINUX_VERSION"'
		make

		# The test suite must run as a non-root user and is destructive in places;
		# the book runs it as the unprivileged tester. We skip unless STRICT=1.
		if [ "${STRICT:-0}" = "1" ]; then
			make check || echo "WARNING: util-linux test suite reported failures" >&2
		fi

		make install
	' _ "$src"
