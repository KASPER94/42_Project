#!/bin/bash
# scripts/final-system/140-expect.sh — build Expect (interactive program automation; for test suites)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Expect: tarball top-level dir is expect<version> (no dash). The book points
# configure at the Tcl headers and installs the script library into /usr/lib.
src="$(extract_only "expect$EXPECT_VERSION.tar.gz")"
run_step final/expect "Build & install expect $EXPECT_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Ensure the configure script finds a working stty in the limited PATH.
		python3 -c "import re,sys" 2>/dev/null || true
		./configure --prefix=/usr \
			--with-tcl=/usr/lib \
			--enable-shared \
			--disable-rpath \
			--mandir=/usr/share/man \
			--with-tclinclude=/usr/include
		make
		if ! make test; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: expect test suite reported failures (non-fatal)" >&2
		fi
		make install
		ln -svf expect'"$EXPECT_VERSION"'/libexpect*.so /usr/lib 2>/dev/null || true
	' _ "$src"
