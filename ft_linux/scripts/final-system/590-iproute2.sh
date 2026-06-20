#!/bin/bash
# scripts/final-system/590-iproute2.sh — build IPRoute2 (ip, ss, bridge, ...)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# iproute2 has no configure; it uses a plain Makefile. The book disables the
# arpd/netem bits that need extra deps, then builds + installs with docs in a
# versioned dir. No test suite.
src="$(extract_only "iproute2-$IPROUTE2_VERSION.tar.xz")"
run_step final/iproute2 "Build & install iproute2 $IPROUTE2_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# arpd needs Berkeley DB; the book disables it.
		sed -i /ARPD/d Makefile 2>/dev/null || true
		rm -fv man/man8/arpd.8
		make NETNS_RUN_DIR=/run/netns
		make SBINDIR=/usr/sbin DOCDIR=/usr/share/doc/iproute2-'"$IPROUTE2_VERSION"' install
	' _ "$src"
