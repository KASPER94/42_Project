#!/bin/bash
# =============================================================================
# scripts/chroot/33-additional-tools.sh
#   LFS Ch.7 — Additional Temporary Tools (built natively inside the chroot).
#
# PURPOSE   Build the remaining temporary tools that need a working chroot
#           environment (they run/test programs that must execute on the target
#           ABI). In LFS Ch.7 order:
#               Gettext  -> Bison -> Perl -> Python -> Texinfo -> Util-linux
#           These are *temporary* builds (some are minimal / install only the
#           binaries the rest of the temp phase needs); the FINAL versions are
#           rebuilt in Ch.8 by agent A3. Inside the chroot the cross toolchain
#           IS the native toolchain, so the plain --prefix=/usr autotools path
#           applies (build_package's default), with the few special flags below.
#
# RUN CONTEXT  *** RUNS INSIDE THE CHROOT ***  (root, under $LFS as "/").
#           Does NOT call enter_chroot. The orchestrator (A8) stages it under
#           $LFS and invokes it via 31-enter-chroot.sh, e.g.:
#               sudo ./scripts/chroot/31-enter-chroot.sh \
#                    /opt/ft_linux/scripts/chroot/33-additional-tools.sh
#
# ASSUMPTION  The repo is reachable inside the chroot (bind-mounted/copied to
#           /opt/ft_linux), AND the source tarballs are under $SOURCES_DIR which,
#           inside the chroot, resolves to /mnt/lfs/sources — i.e. they must be
#           visible at that path inside the chroot. The standard LFS layout
#           ($LFS=/mnt/lfs, sources at $LFS/sources) makes /sources... wait:
#           inside the chroot the book bind-mounts/keeps sources at /sources.
#           To stay consistent with env/paths.sh (SOURCES_DIR=$LFS/sources) the
#           orchestrator must ensure SOURCES_DIR points at the in-chroot sources
#           dir; we re-point it to /sources here if /sources exists (the usual
#           in-chroot location), else fall back to the env value.
#
# AUTHORED  on macOS — RUN by the operator (via the orchestrator) inside the VM.
# =============================================================================
set -euo pipefail

# --- Foundation bootstrap (tolerant: must work from inside the chroot) ------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
if [ ! -f "$REPO_ROOT/env/lfs.env" ]; then
	echo "FATAL: cannot locate env/lfs.env above $SCRIPT_DIR" >&2
	echo "       This script runs INSIDE the chroot — stage the repo under \$LFS" >&2
	echo "       first (e.g. bind-mount/copy to /opt/ft_linux)." >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/package.sh"

require_root

# Inside the chroot the sources usually live at /sources (the LFS convention).
# Re-point SOURCES_DIR there if present so extract_only finds the tarballs.
if [ -d /sources ]; then
	SOURCES_DIR=/sources
	export SOURCES_DIR
fi

# NOTE on implementation: each builder below is a script-local function handed
# to run_step. run_step executes it IN-PROCESS, so the sourced helper
# extract_only stays in scope. (A `bash -c '...'` child shell would NOT see the
# sourced functions and would fail with "extract_only: command not found".)

# --- Gettext (temp): we only need msgfmt/msgmerge/xgettext for later builds --
_do_gettext() {
	set -euo pipefail
	local src
	src="$(extract_only "gettext-$GETTEXT_VERSION.tar.xz")"
	cd "$src"
	./configure --disable-shared
	make
	cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
	cd "$SOURCES_DIR" && rm -rf "$src"
}
run_step "33a-gettext" "Gettext (temp) -> /usr" -- _do_gettext

# --- Bison (temp) -----------------------------------------------------------
_do_bison() {
	set -euo pipefail
	local src
	src="$(extract_only "bison-$BISON_VERSION.tar.xz")"
	cd "$src"
	./configure --prefix=/usr --docdir="/usr/share/doc/bison-$BISON_VERSION"
	make
	make install
	cd "$SOURCES_DIR" && rm -rf "$src"
}
run_step "33b-bison" "Bison (temp) -> /usr" -- _do_bison

# --- Perl (temp): configured non-interactively via Configure ----------------
_do_perl() {
	set -euo pipefail
	local src pv
	src="$(extract_only "perl-$PERL_VERSION.tar.xz")"
	cd "$src"
	pv="${PERL_VERSION%.*}"
	sh Configure -des \
		-Dprefix=/usr \
		-Dvendorprefix=/usr \
		-Duseshrplib \
		-Dprivlib="/usr/lib/perl5/$pv/core_perl" \
		-Darchlib="/usr/lib/perl5/$pv/core_perl" \
		-Dsitelib="/usr/lib/perl5/$pv/site_perl" \
		-Dsitearch="/usr/lib/perl5/$pv/site_perl" \
		-Dvendorlib="/usr/lib/perl5/$pv/vendor_perl" \
		-Dvendorarch="/usr/lib/perl5/$pv/vendor_perl"
	make
	make install
	cd "$SOURCES_DIR" && rm -rf "$src"
}
run_step "33c-perl" "Perl (temp) -> /usr" -- _do_perl

# --- Python (temp): minimal, no optimizations, shared libpython -------------
_do_python() {
	set -euo pipefail
	local src
	src="$(extract_only "Python-$PYTHON_VERSION.tar.xz")"
	cd "$src"
	./configure --prefix=/usr --enable-shared --without-ensurepip
	make
	make install
	cd "$SOURCES_DIR" && rm -rf "$src"
}
run_step "33d-python" "Python (temp) -> /usr" -- _do_python

# --- Texinfo (temp) ---------------------------------------------------------
_do_texinfo() {
	set -euo pipefail
	local src
	src="$(extract_only "texinfo-$TEXINFO_VERSION.tar.xz")"
	cd "$src"
	./configure --prefix=/usr
	make
	make install
	cd "$SOURCES_DIR" && rm -rf "$src"
}
run_step "33e-texinfo" "Texinfo (temp) -> /usr" -- _do_texinfo

# --- Util-linux (temp): ADM/log dirs + the book's temp configure flags ------
_do_util_linux() {
	set -euo pipefail
	local src
	src="$(extract_only "util-linux-$UTIL_LINUX_VERSION.tar.xz")"
	cd "$src"
	mkdir -pv /var/lib/hwclock
	./configure \
		--libdir=/usr/lib \
		--runstatedir=/run \
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
		--docdir="/usr/share/doc/util-linux-$UTIL_LINUX_VERSION"
	make
	make install
	cd "$SOURCES_DIR" && rm -rf "$src"
}
run_step "33f-util-linux" "Util-linux (temp) -> /usr" -- _do_util_linux

log_ok "Ch.7 additional temporary tools built inside chroot"
