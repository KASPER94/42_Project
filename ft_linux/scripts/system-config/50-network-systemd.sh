#!/bin/bash
# =============================================================================
# scripts/system-config/50-network-systemd.sh
#   LFS Ch.9 — General Network Configuration (systemd variant).
#
# PURPOSE   Wire up networking so the booted ft_linux can reach the Internet
#           over the VirtualBox NAT adapter via DHCP. This satisfies the spec's
#           "Connect to the Internet" evaluation prerequisite:
#             * install files/20-wired.network into /etc/systemd/network/
#             * enable systemd-networkd  (brings the interface up + DHCP)
#             * enable systemd-resolved   (DNS)
#             * symlink /etc/resolv.conf -> the resolved stub, with a static
#               files/resolv.conf fallback if the symlink cannot be made.
#
# RUN AS    root, INSIDE the chroot (LFS Ch.9 system configuration).
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

run_step "50-network-systemd" "Configure systemd-networkd + resolved (DHCP over NAT)" -- bash -c '
	set -euo pipefail
	files="$1"

	# 1) Install the wired network unit. systemd-networkd reads every *.network
	#    file in /etc/systemd/network/ in lexical order.
	install -v -d -m 755 /etc/systemd/network
	install -v -m 644 "$files/20-wired.network" /etc/systemd/network/20-wired.network

	# 2) Enable the network + DNS daemons by creating the systemd "wants"
	#    symlinks directly (the chroot has no running systemd to talk to, so we
	#    cannot use `systemctl enable`). These are the exact links systemctl
	#    would create. multi-user.target.wants pulls networkd in at boot.
	install -v -d -m 755 /etc/systemd/system/multi-user.target.wants
	install -v -d -m 755 /etc/systemd/system/sockets.target.wants
	install -v -d -m 755 /etc/systemd/system/sysinit.target.wants

	ln -sfv /usr/lib/systemd/system/systemd-networkd.service \
		/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
	ln -sfv /usr/lib/systemd/system/systemd-networkd.socket \
		/etc/systemd/system/sockets.target.wants/systemd-networkd.socket
	ln -sfv /usr/lib/systemd/system/systemd-networkd-wait-online.service \
		/etc/systemd/system/multi-user.target.wants/systemd-networkd-wait-online.service
	ln -sfv /usr/lib/systemd/system/systemd-resolved.service \
		/etc/systemd/system/dbus-org.freedesktop.resolve1.service
	ln -sfv /usr/lib/systemd/system/systemd-resolved.service \
		/etc/systemd/system/multi-user.target.wants/systemd-resolved.service

	# 3) DNS: prefer the resolved stub symlink so DNS follows the DHCP lease.
	#    If /run/systemd/resolve does not exist yet (chroot, resolved not run),
	#    the symlink target is simply created ahead of time — systemd-resolved
	#    will populate stub-resolv.conf at boot. If we cannot create the symlink
	#    at all, drop the static fallback so name resolution still works.
	if ln -sfv /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf; then
		echo "resolv.conf -> systemd-resolved stub (DNS via DHCP lease)"
	else
		echo "WARNING: could not symlink resolv.conf; installing static fallback" >&2
		install -v -m 644 "$files/resolv.conf" /etc/resolv.conf
	fi
' _ "$FILES"

log_ok "Networking configured (systemd-networkd + resolved, DHCP over VirtualBox NAT)"
