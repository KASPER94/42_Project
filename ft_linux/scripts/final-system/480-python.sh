#!/bin/bash
# scripts/final-system/480-python.sh — build FINAL Python 3 (with ensurepip)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Python 3 is required to build Meson (and thus systemd). The book builds it
# with the shared library, the system expat/libffi/openssl, and --enable-pip so
# pip is bootstrapped (ensurepip). Tarball top dir is Python-<version>.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "Python-$PYTHON_VERSION.tar.xz")"
run_step final/python "Build & install FINAL Python $PYTHON_VERSION (ensurepip)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		./configure --prefix=/usr \
			--enable-shared \
			--with-system-expat \
			--enable-optimizations \
			--with-ensurepip=install
		make
		# The Python test suite is extremely long; the book marks it optional.
		if [ "${STRICT:-0}" = "1" ]; then
			make test || echo "WARNING: python test suite reported failures" >&2
		fi
		make install

		# Create the unversioned symlinks the rest of the system expects.
		ln -sfv python3 /usr/bin/python 2>/dev/null || true

		# Upgrade the bootstrapped pip/setuptools wheels (best-effort; offline OK).
		pip3 install --upgrade pip 2>/dev/null || true
	' _ "$src"
