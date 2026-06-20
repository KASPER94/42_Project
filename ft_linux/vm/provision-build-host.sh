#!/bin/bash
# vm/provision-build-host.sh — prepare the Debian/Ubuntu BUILD HOST for LFS
# =============================================================================
# Purpose : Install every package the LFS build host needs (build toolchain,
#           bison, gawk, texinfo, python3, m4, xz, ...), explicitly add the
#           spec-mandated downloaders (curl + wget) and git, re-point /bin/sh
#           at bash (LFS requires sh=bash, NOT dash), then run version-check.sh
#           and ABORT if any prerequisite is unmet.
# LFS ref : Chapter 2 — Host System Requirements.
# Context : RUNS INSIDE the build-host VM (Debian/Ubuntu), as root (or sudo).
#           Authored on macOS. Used by both the Vagrantfile provisioner and a
#           manual `sudo bash vm/provision-build-host.sh` invocation.
# Make exe: chmod +x vm/provision-build-host.sh
# =============================================================================
set -euo pipefail

# --- Resolve repo root & load the contract (robust regardless of depth). -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do
	REPO_ROOT="$(dirname "$REPO_ROOT")"
done
if [ -f "$REPO_ROOT/env/lfs.env" ]; then
	# shellcheck source=/dev/null
	source "$REPO_ROOT/env/lfs.env"
	# shellcheck source=/dev/null
	source "$REPO_ROOT/lib/common.sh"
else
	# Fallback minimal logging if the contract is not reachable (e.g. when this
	# file was copied standalone into the VM by Vagrant). The script still works.
	REPO_ROOT="$SCRIPT_DIR/.."
	log_info()  { printf 'INFO  %s\n' "$*" >&2; }
	log_warn()  { printf 'WARN  %s\n' "$*" >&2; }
	log_error() { printf 'ERROR %s\n' "$*" >&2; }
	log_ok()    { printf 'OK    %s\n' "$*" >&2; }
	die()       { log_error "$@"; exit 1; }
fi

# Must be root to apt-get install and relink /bin/sh.
if [ "$(id -u)" -ne 0 ]; then
	die "must run as root — try: sudo bash $0"
fi

log_info "Provisioning the LFS build host (Debian/Ubuntu)…"

# -----------------------------------------------------------------------------
# 1. Install host requirements.
# -----------------------------------------------------------------------------
# LFS host packages + explicit downloaders (curl, wget — spec) + git. We use a
# generous superset so the whole 12.x systemd build works without surprises.
export DEBIAN_FRONTEND=noninteractive

HOST_PKGS=(
	build-essential        # gcc, g++, make, libc-dev
	gcc g++ make
	binutils
	bison
	flex
	gawk
	m4
	texinfo
	patch
	gzip bzip2 xz-utils
	tar
	perl
	python3
	gettext
	libtool
	pkg-config
	gperf
	autoconf automake
	bc
	file
	findutils
	diffutils
	sed grep
	coreutils
	ncurses-bin libncurses-dev
	zlib1g-dev
	libssl-dev             # speeds host-side ssl tooling; not strictly required
	curl wget              # spec REQUIRES a downloader
	git                    # for fetching patches / VCS sources
	ca-certificates        # so https downloads validate
	parted gdisk dosfstools e2fsprogs   # disk partitioning/format on the TARGET disk
	sudo
)

log_info "apt-get update…"
apt-get update -y

log_info "Installing ${#HOST_PKGS[@]} host packages…"
# --no-install-recommends keeps the host lean; add ca-certificates etc. above.
apt-get install -y --no-install-recommends "${HOST_PKGS[@]}"

log_ok "Host packages installed."

# -----------------------------------------------------------------------------
# 2. Re-point /bin/sh at bash (NOT dash). LFS requires sh=bash.
# -----------------------------------------------------------------------------
log_info "Ensuring /bin/sh -> bash (LFS requires sh=bash, not dash)…"
if command -v dpkg-reconfigure >/dev/null 2>&1 && dpkg -s dash >/dev/null 2>&1; then
	# Non-interactive: tell debconf NOT to use dash as /bin/sh, then reconfigure.
	echo "dash dash/sh boolean false" | debconf-set-selections
	dpkg-reconfigure -f noninteractive dash || true
fi
# Belt-and-braces: if it is still not bash, relink directly.
sh_target="$(readlink -f /bin/sh 2>/dev/null || echo "")"
case "$sh_target" in
	*bash) log_ok "/bin/sh -> $sh_target" ;;
	*)
		log_warn "/bin/sh still not bash ($sh_target); relinking directly."
		ln -sfv /bin/bash /bin/sh
		;;
esac

# -----------------------------------------------------------------------------
# 3. Final verification — abort on any failure.
# -----------------------------------------------------------------------------
log_info "Running version-check.sh to confirm the host is LFS-ready…"
if bash "$SCRIPT_DIR/version-check.sh"; then
	log_ok "Build host is fully provisioned and LFS-ready."
	log_info "Next: attach the TARGET disk (e.g. /dev/sdb) and run scripts/00-partition-disk.sh."
else
	die "version-check.sh reported failures — host is NOT ready. Fix the items above and re-run."
fi
