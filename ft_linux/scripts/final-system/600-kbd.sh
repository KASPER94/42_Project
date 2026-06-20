#!/bin/bash
# scripts/final-system/600-kbd.sh — build Kbd (keyboard maps & console fonts)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Kbd: the book applies the backspace/delete-key patch, then a couple of seds to
# fix the program names, before a standard autotools build. Drive manually.
src="$(extract_only "kbd-$KBD_VERSION.tar.xz")"
run_step final/kbd "Build & install kbd $KBD_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Fix the broken Backspace/Delete behaviour (LFS patch) if downloaded.
		if ls ../kbd-'"$KBD_VERSION"'-backspace-*.patch >/dev/null 2>&1; then
			patch -Np1 -i ../kbd-'"$KBD_VERSION"'-backspace-1.patch
		fi
		# Remove the redundant resizecons program (needs an obsolete video mode db).
		sed -i "/RESIZECONS_PROGS=/s/yes/no/" configure
		sed -i "s/resizecons.8 //"            docs/man/man8/Makefile.in

		./configure --prefix=/usr --disable-vlock
		make
		if ! make check; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: kbd test suite reported failures (non-fatal)" >&2
		fi
		make install
		# Install documentation.
		cp -R -v docs/doc -T /usr/share/doc/kbd-'"$KBD_VERSION"' 2>/dev/null || true
	' _ "$src"
