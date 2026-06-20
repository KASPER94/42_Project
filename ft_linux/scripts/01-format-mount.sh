#!/bin/bash
# scripts/01-format-mount.sh — format + mount the ft_linux TARGET partitions
# =============================================================================
# Purpose : mkfs.ext4 on root and /boot, mkswap + swapon on the swap partition,
#           create the $LFS mount point, mount root at $LFS, /boot at $LFS/boot,
#           and create $LFS/sources with the sticky bit (per the LFS book).
# LFS ref : Chapter 2 — "Creating a File System" / "Mounting the New Partition".
# Context : RUNS INSIDE the build-host VM, as ROOT, AFTER 00-partition-disk.sh.
#           Authored on macOS.
# Make exe: chmod +x scripts/01-format-mount.sh
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

# The partitions must exist (00-partition-disk.sh creates them).
[ -b "$LFS_DISK_BOOT" ] || die "$LFS_DISK_BOOT missing — run scripts/00-partition-disk.sh first."
[ -b "$LFS_DISK_SWAP" ] || die "$LFS_DISK_SWAP missing — run scripts/00-partition-disk.sh first."
[ -b "$LFS_DISK_ROOT" ] || die "$LFS_DISK_ROOT missing — run scripts/00-partition-disk.sh first."

# -----------------------------------------------------------------------------
# Format. Guarded by confirm because mkfs is destructive (ASSUME_YES bypasses).
# -----------------------------------------------------------------------------
do_format() {
	if ! confirm "Format $LFS_DISK_ROOT (root) and $LFS_DISK_BOOT (/boot) as ext4, and $LFS_DISK_SWAP as swap?"; then
		die "aborted by user (no filesystems created)."
	fi
	log_info "mkfs.ext4 on root ($LFS_DISK_ROOT)…"
	mkfs.ext4 -F -L rootfs "$LFS_DISK_ROOT"
	log_info "mkfs.ext4 on /boot ($LFS_DISK_BOOT)…"
	mkfs.ext4 -F -L bootfs "$LFS_DISK_BOOT"
	log_info "mkswap on $LFS_DISK_SWAP…"
	mkswap -L swap "$LFS_DISK_SWAP"
}
run_step 01-format "Create filesystems on the target partitions" -- do_format

# -----------------------------------------------------------------------------
# Mount. NOT marker-skipped on its own because mounts do not survive a reboot;
# this step is cheap and idempotent (we check mountpoint before mounting), so
# it is safe to re-run. We still wrap it for logging.
# -----------------------------------------------------------------------------
do_mount() {
	log_info "Enabling swap on $LFS_DISK_SWAP…"
	# swapon is idempotent-ish: ignore "already active".
	swapon "$LFS_DISK_SWAP" 2>/dev/null || log_warn "swap already on (or swapon failed) — continuing."

	log_info "Creating mount point $LFS…"
	mkdir -pv "$LFS"

	if mountpoint -q "$LFS"; then
		log_info "$LFS already mounted — skipping root mount."
	else
		log_info "Mounting root ($LFS_DISK_ROOT) at $LFS…"
		mount -v -t ext4 "$LFS_DISK_ROOT" "$LFS"
	fi

	log_info "Creating $LFS/boot…"
	mkdir -pv "$LFS/boot"
	if mountpoint -q "$LFS/boot"; then
		log_info "$LFS/boot already mounted — skipping."
	else
		log_info "Mounting /boot ($LFS_DISK_BOOT) at $LFS/boot…"
		mount -v -t ext4 "$LFS_DISK_BOOT" "$LFS/boot"
	fi

	# Sources dir with the sticky bit (LFS book convention).
	log_info "Creating $SOURCES_DIR (sticky)…"
	mkdir -pv "$SOURCES_DIR"
	chmod -v a+wt "$SOURCES_DIR"

	# State dir lives under $LFS so markers survive host->chroot->boot.
	mkdir -pv "$FT_STATE_DIR"

	log_info "Mounted layout:"
	findmnt -R "$LFS" 2>/dev/null || mount | grep -- "$LFS" || true
}
# Use FORCE so a re-run always re-checks/re-mounts after a reboot, while the
# format step above stays protected by its own marker.
FORCE=1 run_step 01-mount "Mount target partitions under $LFS" -- do_mount

log_ok "Filesystems formatted and mounted. Next: scripts/02-setup-env.sh"
