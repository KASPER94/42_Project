#!/bin/bash
# scripts/final-system/440-openssl.sh — build OpenSSL (TLS/crypto library)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant (systemd, dbus,
# https source fetches). Not in the spec's 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# OpenSSL uses a custom `config` script (not autotools). Drive manually.
src="$(extract_only "openssl-$OPENSSL_VERSION.tar.gz")"
run_step final/openssl "Build & install openssl $OPENSSL_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		./config --prefix=/usr \
			--openssldir=/etc/ssl \
			--libdir=lib \
			shared \
			zlib-dynamic
		make
		if ! make test; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: openssl test suite reported failures (non-fatal)" >&2
		fi
		# Do not install the (large) static HTML docs; the book uses MANSUFFIX.
		sed -i "/INSTALL_LIBS/s/libcrypto.a libssl.a//" Makefile
		make MANSUFFIX=ssl install
		# Versioned docs dir.
		mv -v /usr/share/doc/openssl /usr/share/doc/openssl-'"$OPENSSL_VERSION"' 2>/dev/null || true
	' _ "$src"
