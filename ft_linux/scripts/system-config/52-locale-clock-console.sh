#!/bin/bash
# =============================================================================
# scripts/system-config/52-locale-clock-console.sh
#   LFS Ch.9 — Locale, hardware clock, and virtual console (systemd variant).
#
# PURPOSE   Configure, the systemd way:
#             * /etc/locale.conf      (LANG=en_US.UTF-8)         from files/
#             * /etc/vconsole.conf    (console keymap + font)    from files/
#             * /etc/localtime        symlink into the tz database (UTC)
#             * /etc/adjtime          declares the RTC is in UTC (no DST drift)
#
#           systemd reads locale.conf and vconsole.conf at boot
#           (systemd-vconsole-setup.service) and uses /etc/localtime for the
#           local time zone. We keep the hardware clock in UTC, which is the
#           recommended setting and what VirtualBox provides by default.
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

# Time zone used for /etc/localtime. UTC is the safe default for a VM whose RTC
# is in UTC; override via TIMEZONE=Region/City when running this script.
TIMEZONE="${TIMEZONE:-UTC}"

run_step "52-locale-clock-console" "Install locale.conf + vconsole.conf, set clock=UTC ($TIMEZONE)" -- bash -c '
	set -euo pipefail
	files="$1"; tz="$2"

	# 1) Locale + console config files (read by systemd at boot).
	install -v -m 644 "$files/locale.conf"   /etc/locale.conf
	install -v -m 644 "$files/vconsole.conf" /etc/vconsole.conf

	# 2) Time zone symlink. /usr/share/zoneinfo is provided by glibc/tzdata.
	if [ -f "/usr/share/zoneinfo/$tz" ]; then
		ln -sfv "/usr/share/zoneinfo/$tz" /etc/localtime
	else
		echo "WARNING: zoneinfo for $tz not found; falling back to UTC" >&2
		ln -sfv /usr/share/zoneinfo/UTC /etc/localtime
	fi

	# 3) Hardware clock in UTC. systemd reads /etc/adjtime; "UTC" (the absence of
	#    the LOCAL keyword) tells it the RTC runs in UTC. This is the LFS-systemd
	#    recommended configuration and matches the VirtualBox default.
	cat > /etc/adjtime <<-EOF
		0.0 0 0.0
		0
		UTC
	EOF
	echo "hardware clock declared UTC in /etc/adjtime"
' _ "$FILES" "$TIMEZONE"

# Assert the locale file is the UTF-8 English one (compliance with the plan).
grep -q "LANG=en_US.UTF-8" /etc/locale.conf \
	|| die "ASSERT FAILED: /etc/locale.conf does not set LANG=en_US.UTF-8"

log_ok "Locale (en_US.UTF-8), console keymap/font, and UTC clock configured"
