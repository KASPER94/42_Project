#!/bin/bash
# scripts/final-system/090-readline.sh — build Readline (command-line editing)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Readline: the book reinstalls over a possibly-running older copy, so it moves
# any existing shared libs aside first, builds with SHLIB_LIBS=-lncursesw, and
# installs the docs. No test suite. Drive manually for the pre-install step.
src="$(extract_only "readline-$READLINE_VERSION.tar.gz")"
run_step final/readline "Build & install readline $READLINE_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Prevent installing static libs and move the docs into a versioned dir.
		sed -i "/MV.*old/d" Makefile.in
		sed -i "/{OLDSUFF}/c:" support/shlib-install
		# Fix a SIGINT/readline race the book patches (if patch was downloaded).
		if ls ../readline-'"$READLINE_VERSION"'-upstream_fixes-*.patch >/dev/null 2>&1; then
			patch -Np1 -i ../readline-'"$READLINE_VERSION"'-upstream_fixes-3.patch
		fi
		./configure --prefix=/usr \
			--disable-static \
			--with-curses \
			--docdir=/usr/share/doc/readline-'"$READLINE_VERSION"'
		make SHLIB_LIBS="-lncursesw"
		make SHLIB_LIBS="-lncursesw" install
	' _ "$src"
