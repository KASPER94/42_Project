#!/bin/bash
# scripts/00-partition-disk.sh — GPT-partition the ft_linux TARGET disk
# =============================================================================
# Purpose : Create a fresh GPT label on $LFS_DISK and lay down the >=3 required
#           partitions:
#               p1  /boot  ~512 MB   (ext4, later)
#               p2  swap   ~2   GB
#               p3  root   remainder (ext4, later)
#           Satisfies the spec's "at least 3 partitions: root, /boot, swap" rule.
#           Formatting + mounting happens in scripts/01-format-mount.sh.
# LFS ref : Chapter 2 — "Creating a New Partition" / partitioning.
# Context : RUNS INSIDE the build-host VM, as ROOT. Authored on macOS.
#           !!! DESTRUCTIVE !!! This ERASES the target disk.
# Make exe: chmod +x scripts/00-partition-disk.sh
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

# -----------------------------------------------------------------------------
# Tunable sizes (override via env, e.g. BOOT_SIZE=1G ./00-partition-disk.sh).
# -----------------------------------------------------------------------------
BOOT_SIZE="${BOOT_SIZE:-512M}"   # /boot
SWAP_SIZE="${SWAP_SIZE:-2G}"     # swap
# root = the remainder of the disk (no explicit size).

# -----------------------------------------------------------------------------
# SAFETY: identify and refuse to wipe the host's own root disk.
# -----------------------------------------------------------------------------
[ -b "$LFS_DISK" ] || die "target $LFS_DISK is not a block device (set LFS_DISK correctly; in the VM the target is usually /dev/sdb)"

# Find the device backing the host root filesystem ("/"), e.g. /dev/sda.
host_root_src="$(findmnt -n -o SOURCE / 2>/dev/null || echo "")"
# Reduce a partition path to its parent disk (sda1 -> sda, nvme0n1p2 -> nvme0n1).
disk_of() {
	_d="$1"
	# Prefer lsblk's PKNAME (parent kernel name); fall back to a regex strip.
	_p="$(lsblk -no PKNAME "$_d" 2>/dev/null | head -n1 || true)"
	if [ -n "$_p" ]; then printf '/dev/%s\n' "$_p"; return 0; fi
	case "$_d" in
		*[0-9]p[0-9]*) printf '%s\n' "${_d%p[0-9]*}" ;;
		*[0-9])        printf '%s\n' "$(printf '%s' "$_d" | sed -E 's/[0-9]+$//')" ;;
		*)             printf '%s\n' "$_d" ;;
	esac
	unset _d _p
}
host_root_disk="$(disk_of "$host_root_src")"

if [ -n "$host_root_disk" ] && [ "$host_root_disk" = "$LFS_DISK" ]; then
	die "REFUSING: \$LFS_DISK ($LFS_DISK) is the host's ROOT disk! Set LFS_DISK to the target (e.g. /dev/sdb)."
fi

# Extra guard: warn if the target appears mounted anywhere.
if lsblk -no MOUNTPOINT "$LFS_DISK" 2>/dev/null | grep -q '[^[:space:]]'; then
	log_warn "$LFS_DISK has mounted partitions:"
	lsblk "$LFS_DISK" >&2 || true
fi

# -----------------------------------------------------------------------------
# Show the plan + DESTRUCTIVE confirmation (ASSUME_YES bypasses; test the rc).
# -----------------------------------------------------------------------------
log_warn "TARGET DISK : $LFS_DISK   (host root disk is: ${host_root_disk:-unknown})"
log_info  "Planned layout (GPT):"
log_info  "  ${LFS_DISK_BOOT}  /boot  $BOOT_SIZE  (ext4 later)"
log_info  "  ${LFS_DISK_SWAP}  swap   $SWAP_SIZE"
log_info  "  ${LFS_DISK_ROOT}  root   remainder (ext4 later)"
log_info  "Current state of $LFS_DISK:"
lsblk "$LFS_DISK" >&2 2>/dev/null || true

if ! confirm "This will ERASE ALL DATA on $LFS_DISK and repartition it. Continue?"; then
	die "aborted by user (no changes made)."
fi

# -----------------------------------------------------------------------------
# Choose a partitioner: prefer sgdisk (scriptable, exact), else parted.
# -----------------------------------------------------------------------------
partition_with_sgdisk() {
	log_info "Partitioning with sgdisk…"
	# Wipe any existing GPT/MBR structures, then create the 3 partitions.
	sgdisk --zap-all "$LFS_DISK"
	# p1 /boot, p2 swap (type 8200), p3 root (rest, type 8300).
	sgdisk \
		--new=1:0:+"$BOOT_SIZE" --typecode=1:8300 --change-name=1:bootfs \
		--new=2:0:+"$SWAP_SIZE" --typecode=2:8200 --change-name=2:swap \
		--new=3:0:0             --typecode=3:8300 --change-name=3:rootfs \
		"$LFS_DISK"
}

# to_mib <size> — convert a 512M / 2G style size to an integer count of MiB.
# Pure shell arithmetic (no python dependency in the fallback path).
to_mib() {
	_s="$1"
	_n="${_s%[MmGg]}"          # numeric part
	_u="${_s#"$_n"}"          # unit part (M or G)
	case "$_u" in
		M|m) printf '%s\n' "$_n" ;;
		G|g) printf '%s\n' "$(( _n * 1024 ))" ;;
		*)   die "to_mib: unsupported size '$_s' (use e.g. 512M or 2G)" ;;
	esac
	unset _s _n _u
}

partition_with_parted() {
	log_info "Partitioning with parted…"
	# Compute cumulative MiB offsets (1MiB start for alignment).
	_boot_mib="$(to_mib "$BOOT_SIZE")"
	_swap_mib="$(to_mib "$SWAP_SIZE")"
	_p1_start=1
	_p1_end=$(( _p1_start + _boot_mib ))     # /boot end
	_p2_end=$(( _p1_end + _swap_mib ))       # swap end
	parted -s "$LFS_DISK" mklabel gpt
	parted -s "$LFS_DISK" -- \
		mkpart bootfs ext4       "${_p1_start}MiB" "${_p1_end}MiB" \
		mkpart swap   linux-swap "${_p1_end}MiB"   "${_p2_end}MiB" \
		mkpart rootfs ext4       "${_p2_end}MiB"   100%
	unset _boot_mib _swap_mib _p1_start _p1_end _p2_end
}

do_partition() {
	if command -v sgdisk >/dev/null 2>&1; then
		partition_with_sgdisk
	elif command -v parted >/dev/null 2>&1; then
		partition_with_parted
	else
		die "neither sgdisk nor parted found — install gdisk or parted (vm/provision-build-host.sh installs both)."
	fi

	# Re-read the partition table so the kernel sees the new partitions.
	if command -v partprobe >/dev/null 2>&1; then
		partprobe "$LFS_DISK" || true
	fi
	command -v udevadm >/dev/null 2>&1 && udevadm settle 2>/dev/null || true
	# Give the kernel a moment to materialise the partition device nodes.
	for _i in 1 2 3 4 5; do
		[ -b "$LFS_DISK_BOOT" ] && [ -b "$LFS_DISK_SWAP" ] && [ -b "$LFS_DISK_ROOT" ] && break
		command -v udevadm >/dev/null 2>&1 && udevadm settle 2>/dev/null || true
	done

	log_info "Resulting layout:"
	lsblk "$LFS_DISK" || true

	# Sanity: all three partition nodes must now exist.
	[ -b "$LFS_DISK_BOOT" ] || die "expected $LFS_DISK_BOOT after partitioning (does your device use a 'pN' suffix? set LFS_DISK_BOOT/SWAP/ROOT)."
	[ -b "$LFS_DISK_SWAP" ] || die "expected $LFS_DISK_SWAP after partitioning."
	[ -b "$LFS_DISK_ROOT" ] || die "expected $LFS_DISK_ROOT after partitioning."
}

run_step 00-partition-disk "GPT-partition $LFS_DISK (/boot, swap, root)" -- do_partition

log_ok "Partitioned $LFS_DISK. Next: scripts/01-format-mount.sh"
