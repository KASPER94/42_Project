#!/bin/bash
# scripts/02-setup-env.sh — create the 'lfs' build user + its clean environment
# =============================================================================
# Purpose : Create the lfs group + lfs user, build the $LFS directory skeleton
#           and chown it to lfs, and install lfs's ~/.bash_profile + ~/.bashrc
#           EXACTLY per the LFS book (clean env via `env -i`, LFS, LC_ALL=POSIX,
#           LFS_TGT, PATH=$LFS/tools/bin:/usr/bin:/bin, umask 022, MAKEFLAGS).
# LFS ref : Chapter 4 — "Adding the LFS User" / "Setting Up the Environment".
# Context : RUNS INSIDE the build-host VM, as ROOT, AFTER 01-format-mount.sh.
#           Authored on macOS. NB: this creates the build-host helper account
#           literally named "lfs"; it is NOT the student login (skapers) — that
#           login is created later inside the target system (system-config).
# Make exe: chmod +x scripts/02-setup-env.sh
# =============================================================================
set -euo pipefail

# --- Resolve repo root & load the contract (robust regardless of depth). -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do
	REPO_ROOT="$(dirname "$REPO_ROOT")"
done
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"

require_root

# The target root must be mounted (01-format-mount.sh does this).
mountpoint -q "$LFS" || die "$LFS is not mounted — run scripts/01-format-mount.sh first."

LFS_BUILD_USER="lfs"   # the build-host helper account (LFS Ch.4), not 'skapers'

# -----------------------------------------------------------------------------
# 1. Create the lfs group + user with a clean, predictable shell.
# -----------------------------------------------------------------------------
do_user() {
	if getent group "$LFS_BUILD_USER" >/dev/null 2>&1; then
		log_info "group '$LFS_BUILD_USER' already exists."
	else
		log_info "Creating group '$LFS_BUILD_USER'…"
		groupadd "$LFS_BUILD_USER"
	fi

	if id "$LFS_BUILD_USER" >/dev/null 2>&1; then
		log_info "user '$LFS_BUILD_USER' already exists."
	else
		log_info "Creating user '$LFS_BUILD_USER'…"
		# -s bash, -g lfs, -m home, -k /dev/null (no skel), per the book.
		useradd -s /bin/bash -g "$LFS_BUILD_USER" -m -k /dev/null "$LFS_BUILD_USER"
	fi

	# Give the lfs user a password-less but locked-then-set sentinel is overkill;
	# the book sets a password interactively. For an automated build we instead
	# allow root to `su - lfs` (no password needed for root). Leave as-is.
	log_info "lfs user ready (root can 'su - $LFS_BUILD_USER')."
}
run_step 02-lfs-user "Create the lfs build user + group" -- do_user

# -----------------------------------------------------------------------------
# 2. Build the $LFS directory skeleton and hand it to lfs.
# -----------------------------------------------------------------------------
do_skeleton() {
	log_info "Creating the \$LFS directory skeleton…"
	mkdir -pv "$LFS"/{etc,var} "$LFS"/usr/{bin,lib,sbin}
	# Standard FHS symlink targets for the merged-/usr layout.
	for _d in bin lib sbin; do
		if [ ! -e "$LFS/$_d" ]; then
			ln -sv "usr/$_d" "$LFS/$_d"
		fi
	done
	case "$(uname -m)" in
		x86_64) mkdir -pv "$LFS/lib64" ;;
	esac
	# The toolchain lives here during Ch.5/6.
	mkdir -pv "$LFS/tools"
	# Sources (may already exist from 01-format-mount.sh).
	mkdir -pv "$SOURCES_DIR"

	log_info "chown'ing the build skeleton to '$LFS_BUILD_USER'…"
	# Per the requirement: chown the build skeleton to the lfs user so it can
	# write without root. (On a booted system root would own these; during the
	# Ch.5/6 build the lfs user must.)
	chown -v "$LFS_BUILD_USER" "$LFS"/{usr,lib,var,etc,bin,sbin,tools,sources}
	case "$(uname -m)" in
		x86_64) chown -v "$LFS_BUILD_USER" "$LFS/lib64" ;;
	esac

	unset _d
}
run_step 02-skeleton "Create + chown the \$LFS directory skeleton" -- do_skeleton

# -----------------------------------------------------------------------------
# 3. Install lfs's ~/.bash_profile and ~/.bashrc EXACTLY per the LFS book.
# -----------------------------------------------------------------------------
do_bashfiles() {
	_home="$(getent passwd "$LFS_BUILD_USER" | cut -d: -f6)"
	[ -n "$_home" ] && [ -d "$_home" ] || die "could not resolve home dir for $LFS_BUILD_USER"

	log_info "Writing $_home/.bash_profile …"
	# `exec env -i` wipes the inherited environment and re-enters a clean login
	# shell, so the build can never be polluted by the host's variables.
	cat > "$_home/.bash_profile" <<'EOF'
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

	log_info "Writing $_home/.bashrc …"
	# These literals MUST match the contract in env/lfs.env:
	#   LC_ALL=POSIX, LFS=/mnt/lfs, LFS_TGT=x86_64-lfs-linux-gnu,
	#   PATH=$LFS/tools/bin:/usr/bin:/bin, umask 022.
	# CONFIG_SITE points autotools at $LFS/usr/share/config.site (book).
	# MAKEFLAGS uses all cores. We expand $LFS / $LFS_TGT NOW (heredoc unquoted)
	# so the file embeds concrete values matching this build's contract.
	cat > "$_home/.bashrc" <<EOF
set +h
umask 022
LFS=$LFS
LC_ALL=POSIX
LFS_TGT=$LFS_TGT
PATH=\$LFS/tools/bin:/usr/bin:/bin
CONFIG_SITE=\$LFS/usr/share/config.site
MAKEFLAGS='-j\$(nproc)'
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE MAKEFLAGS
EOF

	# Belt-and-braces: ensure the lfs login does not source the host's global
	# profile (which could re-add /usr/local etc. ahead of our toolchain).
	# The book relies on .bash_profile's `exec env -i`; nothing more needed.

	chown "$LFS_BUILD_USER:$LFS_BUILD_USER" "$_home/.bash_profile" "$_home/.bashrc"
	log_info "Installed lfs .bash_profile + .bashrc:"
	log_info "  LFS=$LFS  LFS_TGT=$LFS_TGT  PATH=\$LFS/tools/bin:/usr/bin:/bin  LC_ALL=POSIX  umask 022"
	unset _home
}
run_step 02-bashfiles "Install lfs ~/.bash_profile + ~/.bashrc (LFS book)" -- do_bashfiles

log_ok "Build environment ready."
log_info "Next: become the lfs user to start the toolchain:  su - $LFS_BUILD_USER"
log_info "Then run the orchestrator / scripts/toolchain/* (authored by agent A2)."
