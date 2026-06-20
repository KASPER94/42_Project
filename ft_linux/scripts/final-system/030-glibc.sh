#!/bin/bash
# scripts/final-system/030-glibc.sh — build & install FINAL Glibc
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# This is the FINAL C library. Steps (per the LFS systemd book):
#   1. Out-of-tree configure/build/check/install of glibc.
#   2. Fix the ldd bash-script path; install nscd config; generate locales.
#   3. Install /etc/nsswitch.conf and the timezone data (tzdata).
#   4. Configure the dynamic loader: /etc/ld.so.conf (+ /etc/ld.so.conf.d).
# The glibc test suite is kept (the book emphasises it). Failures are warnings
# unless STRICT=1; here we drive the suite manually so we surface a clear note.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# ---------------------------------------------------------------------------
# 1) Build & install glibc (out-of-tree). build_package cannot express the
#    book's required tweaks (the /etc/ld.so.preload touch, the build-dir
#    configure flags, the localedef-driven locale generation), so we do it
#    manually under run_step for logging + idempotency.
# ---------------------------------------------------------------------------
src="$(extract_only "glibc-$GLIBC_VERSION.tar.xz")"
run_step final/glibc "Build & install FINAL glibc $GLIBC_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"

		# The LFS book applies the upstream FHS patch so glibc uses /var/lib/nss_db
		# instead of /var/db. The patch tarball is fetched alongside the sources;
		# apply it if present (filename per the book).
		if ls ../glibc-'"$GLIBC_VERSION"'-fhs-*.patch >/dev/null 2>&1; then
			patch -Np1 -i ../glibc-'"$GLIBC_VERSION"'-fhs-1.patch
		fi

		mkdir -v build
		cd build

		# Ensure ldconfig and sln land in /usr/sbin (book requirement).
		echo "rootsbindir=/usr/sbin" > configparms

		../configure \
			--prefix=/usr \
			--disable-werror \
			--enable-kernel=5.4 \
			--enable-stack-protector=strong \
			--disable-nscd \
			libc_cv_slibdir=/usr/lib

		make

		# Run the test suite. The book notes a small number of tests are known
		# to fail depending on host kernel/hardware; treat failures as a warning
		# unless STRICT=1 so automation does not abort the whole final system.
		if ! make check; then
			if [ "${STRICT:-0}" = "1" ]; then
				echo "STRICT=1: glibc test failures are fatal" >&2
				exit 1
			fi
			echo "WARNING: glibc test suite reported failures (non-fatal; set STRICT=1 to enforce)" >&2
		fi

		# Prevent a harmless warning from "make install" about a missing file.
		touch /etc/ld.so.conf

		# Skip the sanity check that fails inside the limited chroot environment
		# (the book patches the test Makefile this way).
		sed "/test-installation/s@\$(PERL)@echo not running@" -i ../Makefile

		make install

		# Fix a hard-coded path in the ldd shell script.
		sed "/RTLDLIST=/s@/usr@@g" -i /usr/bin/ldd
	' _ "$src"

# ---------------------------------------------------------------------------
# 2) Generate locales. The LFS book installs a minimal, predictable set used by
#    the test suites and a few utilities. localedef is now available (just
#    installed above). C.UTF-8 + en_US are the practical defaults.
# ---------------------------------------------------------------------------
run_step final/glibc-locales "Generate glibc locales" -- \
	bash -c '
		set -euo pipefail
		mkdir -pv /usr/lib/locale
		localedef -i C -f UTF-8 C.UTF-8 || true
		localedef -i en_US -f ISO-8859-1 en_US
		localedef -i en_US -f UTF-8 en_US.UTF-8
		localedef -i de_DE -f ISO-8859-1 de_DE
		localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
		localedef -i de_DE -f UTF-8 de_DE.UTF-8
		localedef -i fr_FR -f ISO-8859-1 fr_FR
		localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
		localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
		localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2>/dev/null || true
		localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
		localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
		localedef -i el_GR -f ISO-8859-7 el_GR
		localedef -i is_IS -f ISO-8859-1 is_IS
		localedef -i is_IS -f UTF-8 is_IS.UTF-8
		localedef -i it_IT -f ISO-8859-1 it_IT
		localedef -i it_IT -f UTF-8 it_IT.UTF-8
		localedef -i es_ES -f ISO-8859-15 es_ES@euro
		localedef -i zh_CN -f GB18030 zh_CN.GB18030
		localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS 2>/dev/null || true
		localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
	'

# ---------------------------------------------------------------------------
# 3) /etc/nsswitch.conf (glibc ships none) + timezone data (tzdata).
# ---------------------------------------------------------------------------
run_step final/glibc-nsswitch "Install /etc/nsswitch.conf" -- \
	bash -c '
		set -euo pipefail
		cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
	'

run_step final/glibc-tzdata "Install timezone data (tzdata $TZDATA_VERSION)" -- \
	bash -c '
		set -euo pipefail
		# tzdata is a flat tarball with no top-level dir; unpack into a temp dir.
		tmp="$(mktemp -d)"
		tar -xf "$SOURCES_DIR/tzdata'"$TZDATA_VERSION"'.tar.gz" -C "$tmp"
		cd "$tmp"
		ZONEINFO=/usr/share/zoneinfo
		mkdir -pv "$ZONEINFO"/{posix,right}
		for tz in etcetera southamerica northamerica europe africa antarctica \
				asia australasia backward; do
			zic -L /dev/null   -d "$ZONEINFO"       "${tz}"
			zic -L /dev/null   -d "$ZONEINFO"/posix "${tz}"
			zic -L leapseconds -d "$ZONEINFO"/right "${tz}"
		done
		cp -v zone.tab zone1970.tab iso3166.tab "$ZONEINFO"
		zic -d "$ZONEINFO" -p America/New_York
		rm -rf "$tmp"
		# Set a default local time zone; the user may re-run tzselect later.
		# /etc/localtime points at UTC by default (overridable in system-config).
		ln -sfv /usr/share/zoneinfo/UTC /etc/localtime
	'

# ---------------------------------------------------------------------------
# 4) Configure the dynamic loader: /etc/ld.so.conf (+ a conf.d include dir).
# ---------------------------------------------------------------------------
run_step final/glibc-ldconfig "Configure dynamic loader /etc/ld.so.conf" -- \
	bash -c '
		set -euo pipefail
		cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

# Add an include directory
include /etc/ld.so.conf.d/*.conf

# End /etc/ld.so.conf
EOF
		mkdir -pv /etc/ld.so.conf.d
		ldconfig
	'
