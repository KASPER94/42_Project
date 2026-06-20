#!/bin/bash
# =============================================================================
# scripts/finalize/81-end-message.sh
#   LFS Ch.11 — Distro identity files (/etc/os-release + /etc/ft_linux-release).
#
# PURPOSE   Identify the finished distribution as "ft_linux":
#             * /etc/os-release       the systemd-standard identity file
#                                     (NAME, PRETTY_NAME including the login,
#                                     VERSION derived from KERNEL_VERSION).
#             * /etc/ft_linux-release a tiny human-readable banner.
#           Also drops /etc/issue + /etc/motd so the console login shows the
#           distro name. These make the system self-identifying at evaluation.
#
# RUN AS    root, INSIDE the chroot (or on the booted system).
#
# AUTHORED  on macOS — RUN by the operator inside the build VM. chmod +x.
# =============================================================================
set -euo pipefail

# --- Foundation bootstrap (A0 contract — verbatim) --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
[ -f "$REPO_ROOT/env/lfs.env" ] || { echo "FATAL: cannot locate env/lfs.env above $SCRIPT_DIR" >&2; exit 1; }
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"

require_root

run_step "81-end-message" "Write /etc/os-release + /etc/ft_linux-release" -- bash -c '
	set -euo pipefail
	login="$1"; kver="$2"

	# /etc/os-release — systemd reads this; PRETTY_NAME carries the login so the
	# build is unmistakably the student is.
	cat > /etc/os-release <<-EOF
		NAME="ft_linux"
		ID=ft_linux
		ID_LIKE=lfs
		PRETTY_NAME="ft_linux (LFS systemd) — $login"
		VERSION="$kver-$login"
		VERSION_ID="$kver"
		BUILD_ID="$kver-$login"
		HOME_URL="https://www.linuxfromscratch.org/"
		ANSI_COLOR="0;34"
	EOF

	# Small standalone release file.
	cat > /etc/ft_linux-release <<-EOF
		ft_linux — Linux From Scratch (systemd) build by $login
		Kernel: $kver-$login
	EOF

	# Console identity: /etc/issue (pre-login) + /etc/motd (post-login).
	cat > /etc/issue <<-EOF
		ft_linux \r (\l) — built by $login

	EOF
	cat > /etc/motd <<-EOF
		Welcome to ft_linux ($login) — Linux From Scratch, systemd variant.
	EOF

	echo "----- /etc/os-release -----"
	cat /etc/os-release
	echo "----- /etc/ft_linux-release -----"
	cat /etc/ft_linux-release
' _ "$LFS_USER_LOGIN" "$KERNEL_VERSION"

# Assert the identity files name the distro + the login.
grep -q "^NAME=\"ft_linux\"" /etc/os-release || die "ASSERT FAILED: /etc/os-release NAME != ft_linux"
grep -q "$LFS_USER_LOGIN" /etc/os-release || die "ASSERT FAILED: /etc/os-release missing login $LFS_USER_LOGIN"
[ -s /etc/ft_linux-release ] || die "ASSERT FAILED: /etc/ft_linux-release missing or empty"

log_ok "Distro identity written (ft_linux, login=$LFS_USER_LOGIN)"
