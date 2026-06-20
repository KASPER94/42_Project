#!/bin/bash
# =============================================================================
# scripts/chroot/30-prepare-virtual-fs.sh
#   LFS Ch.7 — Changing Ownership + Preparing Virtual Kernel File Systems.
#
# PURPOSE   Get $LFS ready to be chrooted into:
#             1. chown -R root:root $LFS/*   (the temp tools were built by the
#                unprivileged `lfs` user; ownership must flip to root before we
#                run a root chroot, per the LFS book). lib64 chowned too.
#             2. mount_virtual_fs (lib/chroot-helpers.sh): bind /dev, devpts,
#                proc, sysfs, tmpfs /run, plus /dev/shm.
#             3. Create the /dev/console and /dev/null device NODES the book
#                requires (the bind mount of /dev provides the rest).
#
# RUN AS    ROOT, on the build HOST (this is the transition from the lfs-user
#           cross-build to the root chroot phase).
#
# AUTHORED  on macOS — RUN by the operator inside the Linux build VM.
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
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/package.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/chroot-helpers.sh"

# This whole phase is privileged.
require_root

# --- 1) Flip ownership of the target tree to root ---------------------------
run_step "30a-chown-lfs" "chown root:root the entire \$LFS tree" -- bash -c '
	set -euo pipefail
	chown -R root:root "$LFS"/{usr,lib,var,etc,bin,sbin,tools} 2>/dev/null || true
	case "$(uname -m)" in
		x86_64) [ -e "$LFS/lib64" ] && chown -R root:root "$LFS/lib64" ;;
	esac
'

# --- 2) Mount the kernel virtual filesystems (helper is idempotent) ---------
run_step "30b-mount-vkfs" "Mount virtual kernel filesystems under \$LFS" -- \
	mount_virtual_fs

# --- 3) Create the device nodes the book requires ---------------------------
# The /dev bind mount usually already provides these, but the book has us
# create them explicitly so the chroot has a console + null even on minimal
# hosts. Guard so a re-run does not error (idempotent).
run_step "30c-device-nodes" "Create /dev/console and /dev/null nodes" -- bash -c '
	set -euo pipefail
	mkdir -pv "$LFS/dev"
	[ -e "$LFS/dev/console" ] || mknod -m 600 "$LFS/dev/console" c 5 1
	[ -e "$LFS/dev/null" ]    || mknod -m 666 "$LFS/dev/null" c 1 3
'

log_ok "Virtual FS prepared — ready to enter chroot (run 31-enter-chroot.sh)"
