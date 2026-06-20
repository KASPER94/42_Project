#!/bin/bash
# scripts/final-system/150-dejagnu.sh — build DejaGNU (test framework; for GCC/Binutils suites)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# DejaGNU builds out-of-tree; the book installs the docs too. Drive manually.
src="$(extract_only "dejagnu-$DEJAGNU_VERSION.tar.gz")"
run_step final/dejagnu "Build & install dejagnu $DEJAGNU_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		mkdir -v build
		cd build
		../configure --prefix=/usr
		makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi 2>/dev/null || true
		makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi 2>/dev/null || true
		if ! make check; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: dejagnu test suite reported failures (non-fatal)" >&2
		fi
		make install
		install -v -dm755  /usr/share/doc/dejagnu-'"$DEJAGNU_VERSION"'
		install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-'"$DEJAGNU_VERSION"' 2>/dev/null || true
	' _ "$src"
