#!/bin/bash
# =============================================================================
# scripts/kernel/61-kernel-build.sh
#   LFS Ch.10.3 — Compile the kernel and install its modules.
#
# PURPOSE   In /usr/src/kernel-$KERNEL_VERSION:
#             * `make`                 — build the kernel image + modules using
#                                        the .config produced by 60-prepare.
#             * `make modules_install` — install loadable modules into
#                                        /lib/modules/<kernelrelease>.
#
#           The actual /boot/vmlinuz-...-skapers copy + the spec-critical naming
#           assertions live in 62-kernel-install.sh (kept separate so a failed
#           build never produces a half-named kernel).
#
# RUN AS    root, INSIDE the chroot. This is the longest single step of the
#           whole build (tens of minutes); MAKEFLAGS=-j$(nproc) parallelises it.
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

KERNEL_SRC="/usr/src/kernel-${KERNEL_VERSION}"
[ -d "$KERNEL_SRC" ] || die "kernel source dir not found: $KERNEL_SRC (run 60-kernel-prepare.sh first)"
[ -f "$KERNEL_SRC/.config" ] || die ".config not found in $KERNEL_SRC (run 60-kernel-prepare.sh first)"

run_step "61-kernel-build" "Compile kernel $KERNEL_VERSION + install modules" -- bash -c '
	set -euo pipefail
	kernel_src="$1"
	cd "$kernel_src"

	# Build the compressed image (bzImage) and all configured modules.
	# MAKEFLAGS (from env/lfs.env) supplies -j$(nproc).
	make

	# Install loadable modules under /lib/modules/<kernelrelease>. The release
	# string already embeds -skapers via CONFIG_LOCALVERSION, so this lands in
	# /lib/modules/$KERNEL_VERSION-skapers — matching the booted uname -r.
	make modules_install

	echo "----- kernelrelease -----"
	make -s kernelrelease
	echo "----- installed module tree -----"
	ls -d /lib/modules/*/ 2>/dev/null || true
' _ "$KERNEL_SRC"

log_ok "Kernel built and modules installed (release: $(make -s -C "$KERNEL_SRC" kernelrelease))"
