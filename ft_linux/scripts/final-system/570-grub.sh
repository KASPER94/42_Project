#!/bin/bash
# scripts/final-system/570-grub.sh — build GRUB (bootloader TOOLING only)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# SCOPE: this script only BUILDS and `make install`s the GRUB tooling
# (grub-install, grub-mkconfig, the platform modules). Actually installing GRUB
# to the target disk and writing grub.cfg happens later in scripts/boot/ (owned
# by another agent). Do NOT run grub-install here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Build the BIOS (i386-pc) platform tooling natively — that is what a
# VirtualBox VM with a standard MBR/legacy-BIOS setup uses. This matches the LFS
# book's GRUB build (the default --with-platform on a BIOS host is pc). No test
# suite ships.
src="$(extract_only "grub-$GRUB_VERSION.tar.xz")"
run_step final/grub "Build & install GRUB $GRUB_VERSION tooling (no disk install)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# The book disables a couple of unimplemented features and the FUSE util
		# (which would pull in an extra dependency).
		./configure --prefix=/usr \
			--sysconfdir=/etc \
			--disable-efiemu \
			--disable-werror
		make
		make install
		# Install the bash completion script in the canonical location.
		mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions/grub 2>/dev/null || true
	' _ "$src"
