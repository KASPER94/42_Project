#!/bin/bash
# scripts/final-system/130-tcl.sh — build Tcl (Tool Command Language; for test suites)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Tcl: configure lives in the unix/ subdir; the build also installs the private
# headers (needed by Expect) and fixes the *Config.sh build-dir references.
# Tarball top-level dir is tcl<version> (no dash). Drive manually.
src="$(extract_only "tcl$TCL_VERSION-src.tar.gz")"
run_step final/tcl "Build & install tcl $TCL_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		SRCDIR="$(pwd)"
		cd unix
		./configure --prefix=/usr \
			--mandir=/usr/share/man \
			--disable-rpath
		make

		# Fix references to the build directory in the generated *Config.sh files
		# so other packages do not pick up the throwaway source path.
		sed -e "s|$SRCDIR/unix|/usr/lib|" \
			-e "s|$SRCDIR|/usr/include|" \
			-i tclConfig.sh
		# (pkgs sub-configs, if present)
		if [ -d pkgs ]; then
			find pkgs -name "*Config.sh" -exec sed \
				-e "s|$SRCDIR/unix/pkgs/[^/]*|/usr/lib|" \
				-e "s|$SRCDIR/pkgs/[^/]*|/usr/include|" \
				-i {} \; 2>/dev/null || true
		fi

		if ! make test; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: tcl test suite reported failures (non-fatal)" >&2
		fi

		make install
		# Make the installed Tcl library writable so it can be stripped later.
		chmod -v u+w /usr/lib/libtcl'"${TCL_VERSION%.*}"'.so 2>/dev/null || true
		# Install the private headers required by Expect.
		make install-private-headers
		# Create the version-agnostic symlink and the man page.
		ln -sfv tclsh'"${TCL_VERSION%.*}"' /usr/bin/tclsh
		mv /usr/share/man/man3/{Thread,Tcl_Thread}.3 2>/dev/null || true
	' _ "$src"
