#!/bin/bash
# scripts/final-system/260-ncurses.sh — build Ncurses (terminal control library)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# The final Ncurses builds wide-character libraries (libncursesw) and creates a
# set of compatibility symlinks so packages that ask for the non-wide names
# (libncurses, libtinfo, etc.) still link. Manual per the book.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "ncurses-$NCURSES_VERSION.tar.gz")"
run_step final/ncurses "Build & install ncurses $NCURSES_VERSION (widec)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"

		./configure --prefix=/usr \
			--mandir=/usr/share/man \
			--with-shared \
			--without-debug \
			--without-normal \
			--with-cxx-shared \
			--enable-pc-files \
			--enable-widec \
			--with-pkg-config-libdir=/usr/lib/pkgconfig
		make

		# No useful test suite ships with ncurses; the book installs directly.
		make install

		# Move the shared libraries into /usr/lib if make put them in /lib (older
		# layouts); on a modern merged-/usr system they are already in /usr/lib.

		# Create compatibility .so symlinks so libncurses -> libncursesw, etc., for
		# packages that ask for the non-wide names.
		for lib in ncurses form panel menu; do
			ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
			ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc 2>/dev/null || true
		done
		# libcurses compatibility, and a linker-script libncurses.so that pulls in
		# the wide library (the book uses exactly this trick).
		ln -sfv libncursesw.so /usr/lib/libcurses.so
		echo "INPUT(-lncursesw)" > /usr/lib/libncurses.so

		# Install documentation.
		mkdir -pv      /usr/share/doc/ncurses-'"$NCURSES_VERSION"'
		cp -v -R doc/* /usr/share/doc/ncurses-'"$NCURSES_VERSION"' 2>/dev/null || true
	' _ "$src"
