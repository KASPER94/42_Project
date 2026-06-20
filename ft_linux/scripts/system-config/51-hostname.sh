#!/bin/bash
# =============================================================================
# scripts/system-config/51-hostname.sh
#   LFS Ch.9 — Configuring the system hostname (systemd variant).
#
# PURPOSE   Set the distribution hostname to the student login `skapers`
#           (spec rule R7: "The distribution hostname MUST be your student
#           login") and install /etc/hosts mapping that name to loopback.
#
#           The hostname is taken from $LFS_USER_LOGIN (the single source of
#           truth in env/lfs.env) — it MUST equal the login. files/hostname is
#           also shipped and asserted to contain the same value so the static
#           template can never drift from the variable.
#
# RUN AS    root, INSIDE the chroot.
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

FILES="$SCRIPT_DIR/files"

# Defensive: the shipped files/hostname template MUST match $LFS_USER_LOGIN so
# the static file can never silently disagree with the contract variable.
shipped_hostname="$(tr -d '[:space:]' < "$FILES/hostname")"
if [ "$shipped_hostname" != "$LFS_USER_LOGIN" ]; then
	die "files/hostname ('$shipped_hostname') != LFS_USER_LOGIN ('$LFS_USER_LOGIN') — fix the template"
fi

run_step "51-hostname" "Set hostname to $LFS_USER_LOGIN + install /etc/hosts" -- bash -c '
	set -euo pipefail
	login="$1"; files="$2"

	# Hostname is the login (spec R7). Write it without a trailing newline noise.
	echo "$login" > /etc/hostname
	echo "hostname set to: $(cat /etc/hostname)"

	# /etc/hosts maps 127.0.1.1 -> skapers (see the shipped template).
	install -v -m 644 "$files/hosts" /etc/hosts

	# Assert the hosts file references the login (compliance guard).
	grep -qw "$login" /etc/hosts || { echo "FATAL: /etc/hosts missing login $login" >&2; exit 1; }
' _ "$LFS_USER_LOGIN" "$FILES"

# Final loud assertion: hostname file MUST equal the login.
test "$(cat /etc/hostname)" = "$LFS_USER_LOGIN" \
	|| die "ASSERT FAILED: /etc/hostname != $LFS_USER_LOGIN"

log_ok "Hostname = $LFS_USER_LOGIN (matches the student login, spec R7)"
