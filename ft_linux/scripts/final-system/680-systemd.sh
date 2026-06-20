#!/bin/bash
# scripts/final-system/680-systemd.sh — build systemd (PID 1, udev, journald)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# SPEC SUBSTITUTION: systemd REPLACES three packages from the spec's SysV path:
#     * systemd-udevd  <- replaces Eudev + the Udev-lfs tarball (module loader)
#     * systemd (PID1) <- replaces Sysvinit (central process management / init)
#     * systemd-journald <- replaces Sysklogd (system logging)
# The spec explicitly permits "SysV OR SystemD" and allows swapping udev/init
# for equivalents — see docs/03-systemd-deviation.md.
#
# systemd builds with meson + ninja (installed at 490/500). After install we run
# the canonical post-install steps: create the machine-id, run the unit preset,
# and set up the first-boot-less defaults.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Tarball top dir is systemd-<version> (GitHub archive). Build with the book's
# meson options. We do NOT enable homed/userdb/repart, keep sysusers/firstboot
# off, disable the bundled ldconfig (glibc owns it), and turn off the test
# install. man=auto builds man pages if the tools are present.
src="$(extract_only "systemd-$SYSTEMD_VERSION.tar.gz")"
run_step final/systemd "Build & install systemd $SYSTEMD_VERSION (init + udev + journald)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"

		# Remove an unneeded sysusers rule the book deletes so we are not asked
		# to create extra accounts.
		sed -i -e "s/GROUP=\"render\"/GROUP=\"video\"/" \
			-e "s/GROUP=\"sgx\", //" rules.d/50-udev-default.rules.in 2>/dev/null || true

		meson setup build \
			--prefix=/usr \
			--buildtype=release \
			-Dmode=release \
			-Ddefault-dnssec=no \
			-Dfirstboot=false \
			-Dinstall-tests=false \
			-Dldconfig=false \
			-Dsysusers=false \
			-Drpmmacrosdir=no \
			-Dhomed=disabled \
			-Duserdb=false \
			-Dman=auto \
			-Dnss-systemd=true \
			-Ddefault-keymap=us \
			-Ddev-kvm-mode=0660 \
			-Dnobody-user=nobody \
			-Dnobody-group=nobody \
			-Dsysupdate=disabled \
			-Dukify=disabled \
			-Ddocdir=/usr/share/doc/systemd-'"$SYSTEMD_VERSION"'

		ninja -C build
		ninja -C build install

		# ---- Post-install (per the LFS systemd book) ---------------------------
		# 1) Create a basic machine-id (replaced on first real boot).
		systemd-machine-id-setup 2>/dev/null || \
			tr -dc "a-f0-9" </dev/urandom 2>/dev/null | head -c 32 > /etc/machine-id || true

		# 2) Apply the default unit presets (enable/disable per the shipped policy).
		systemctl preset-all 2>/dev/null || true

		# 3) Provide an empty /etc/resolv.conf target dir for resolved (system-config
		#    sets the real symlink later).
		mkdir -pv /etc/systemd/system

		# 4) Disable the systemd "first boot" interactive setup (firstboot=false
		#    already; this guards a stray flag file).
		rm -f /etc/machine-id.firstboot 2>/dev/null || true
	' _ "$src"

log_info "systemd installed — it now provides /sbin/init (PID 1), systemd-udevd (module loader) and systemd-journald (logging)."
