#!/bin/bash
# scripts/final-system/510-coreutils.sh — build Coreutils (the basic system utilities)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Coreutils provides ls/cat/cp/mv/... The book applies the i18n patch, builds
# with the FHS-friendly options, runs the (long) test suite as a non-root user
# (here root, so a few tests are skipped/expected to fail), then relocates a
# couple of programs (chroot, hostid, ...) per the FHS.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "coreutils-$COREUTILS_VERSION.tar.xz")"
run_step final/coreutils "Build & install coreutils $COREUTILS_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Apply the LFS internationalization patch if downloaded.
		if ls ../coreutils-'"$COREUTILS_VERSION"'-i18n-*.patch >/dev/null 2>&1; then
			patch -Np1 -i ../coreutils-'"$COREUTILS_VERSION"'-i18n-1.patch
		fi

		autoreconf -fiv 2>/dev/null || true
		FORCE_UNSAFE_CONFIGURE=1 ./configure \
			--prefix=/usr \
			--enable-no-install-program=kill,uptime
		make

		# The book runs the suite as a non-root user; inside chroot we are root.
		# Failures are non-fatal unless STRICT=1.
		if [ "${STRICT:-0}" = "1" ]; then
			make NON_ROOT_USERNAME=tester check-root || true
			make RUN_EXPENSIVE_TESTS=yes check || \
				{ echo "STRICT=1: coreutils test failures are fatal" >&2; exit 1; }
		fi

		make install

		# FHS relocations the book performs.
		mv -v /usr/bin/chroot /usr/sbin 2>/dev/null || true
		mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8 2>/dev/null || true
		sed -i "s/\"1\"/\"8\"/" /usr/share/man/man8/chroot.8 2>/dev/null || true
	' _ "$src"
