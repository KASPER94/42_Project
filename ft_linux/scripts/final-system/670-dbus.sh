#!/bin/bash
# scripts/final-system/670-dbus.sh — build D-Bus (system message bus)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant (systemd requires
# the D-Bus system bus). Not in the spec's 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# ORDERING: D-Bus MUST be built before systemd (680), which links against it.
# dbus 1.16 builds with meson (installed at 500).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# dbus 1.16 ships a meson build. Configure the system socket path under /run and
# disable doxygen/xml docs to avoid extra deps. Tests need a session, so skip.
build_package final/dbus "dbus-$DBUS_VERSION.tar.xz" --type=meson \
	--configure-args="-Druntime_dir=/run -Dsystemd=enabled -Dsystemd_system_unitdir=/usr/lib/systemd/system -Dsystemd_user_unitdir=/usr/lib/systemd/user --wrap-mode=nofallback" \
	--no-check

# Create the machine-id symlink + the dbus user/group the daemon needs. systemd
# will own /etc/machine-id later; here we just ensure the messagebus identity.
run_step final/dbus-setup "Create dbus messagebus user/group" -- \
	bash -c '
		set -euo pipefail
		if ! getent group  messagebus >/dev/null 2>&1; then
			groupadd -g 18 messagebus 2>/dev/null || groupadd messagebus
		fi
		if ! getent passwd messagebus >/dev/null 2>&1; then
			useradd -c "D-Bus Message Daemon User" -d /run/dbus \
				-u 18 -g messagebus -s /usr/bin/false messagebus 2>/dev/null || \
			useradd -c "D-Bus Message Daemon User" -d /run/dbus \
				-g messagebus -s /usr/bin/false messagebus
		fi
	'
