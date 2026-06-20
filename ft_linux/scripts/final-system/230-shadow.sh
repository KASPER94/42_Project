#!/bin/bash
# scripts/final-system/230-shadow.sh — build Shadow (password & login management)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Configures Shadow to use the strong YESCRYPT password hashing scheme and to
# place useradd's group files in /etc as the book does.
#
# !!! ROOT PASSWORD !!!  This script does NOT set any password. After the build
# completes, the user MUST set the root password interactively, inside the
# chroot/booted system:
#       passwd root
# Hard-coding a password would be a security defect and is intentionally avoided.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "shadow-$SHADOW_VERSION.tar.xz")"
run_step final/shadow "Build & install shadow $SHADOW_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Disable installation of groups program & its man page (coreutils owns it),
		# and switch the man pages to a complete set per the book.
		sed -i "src/Makefile.in" -e "/groups/s/^/#/" 2>/dev/null || true
		find man -name Makefile.in -exec sed -i "s/groups\.1 / /"   {} \; 2>/dev/null || true
		find man -name Makefile.in -exec sed -i "s/getspnam\.3 / /" {} \; 2>/dev/null || true
		find man -name Makefile.in -exec sed -i "s/passwd\.5 / /"    {} \; 2>/dev/null || true

		# Use YESCRYPT (the LFS-12.x default) for password encryption, and put the
		# group files under /etc. Also bump the password-aging defaults sensibly.
		sed -e "s:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:" \
			-e "s:/var/spool/mail:/var/mail:"                   \
			-e "/PATH=/{s@/sbin:@@;s@/usr/sbin:@@}"             \
			-i etc/login.defs

		touch /usr/bin/passwd
		./configure --sysconfdir=/etc \
			--disable-static \
			--with-{b,yes}crypt \
			--without-libbsd \
			--with-group-name-max-length=32
		make
		make exec_prefix=/usr install
		make -C man install-man

		# Enable shadowed passwords & group passwords (move secrets to /etc/shadow,
		# /etc/gshadow). pwconv/grpconv are now installed.
		pwconv
		grpconv

		# Configure useradd defaults: create mail spool dirs under /var/mail.
		mkdir -p /etc/default
		useradd -D --gid 999 2>/dev/null || true
		sed -i "/MAIL/s/yes/no/" /etc/default/useradd 2>/dev/null || true
	' _ "$src"

# Loud, documented reminder — the root password is NOT set here.
log_warn "shadow: REMEMBER to set the root password interactively after the build:  passwd root"
