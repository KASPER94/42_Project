# shellcheck shell=bash
#
# env/paths.sh — derived & host paths (target disk, partitions, state, logs)
# =============================================================================
# Sourced by env/lfs.env AFTER the core variables ($LFS, etc.) are defined, so
# everything here may reference $LFS safely.
#
# These describe WHERE things live on the host/VM filesystem. Versions and
# package URLs live in env/versions.sh; the core build identity lives in
# env/lfs.env.
# =============================================================================

# -----------------------------------------------------------------------------
# Target disk  (the SECOND virtual disk that becomes ft_linux / disk.vdi)
# -----------------------------------------------------------------------------
# !!! DESTRUCTIVE !!!  $LFS_DISK is wiped and repartitioned by
# scripts/00-partition-disk.sh. ALWAYS confirm this points at the *target*
# disk and NOT the build host's own disk before running anything that touches
# it. In a standard VirtualBox setup the build host is /dev/sda and the
# ft_linux target is the second attached disk /dev/sdb. Override per-run with:
#     LFS_DISK=/dev/sdX ./run-all.sh ...
LFS_DISK="${LFS_DISK:-/dev/sdb}"

# Partition layout (>= 3 partitions: /boot, swap, root — satisfies the spec).
#   p1 = /boot   (~512 MB, ext4)
#   p2 = swap    (~2 GB)
#   p3 = root    (remainder, ext4)
# NOTE on naming: for /dev/sdX devices partitions are ${LFS_DISK}1; for NVMe or
# loop devices they are ${LFS_DISK}p1. We default to the sdX convention (the
# VirtualBox SATA default). Override LFS_DISK_BOOT/SWAP/ROOT directly if your
# device uses the pN suffix.
LFS_DISK_BOOT="${LFS_DISK_BOOT:-${LFS_DISK}1}"
LFS_DISK_SWAP="${LFS_DISK_SWAP:-${LFS_DISK}2}"
LFS_DISK_ROOT="${LFS_DISK_ROOT:-${LFS_DISK}3}"

# -----------------------------------------------------------------------------
# Sources — downloaded tarballs + patches live here (Ch.3)
# -----------------------------------------------------------------------------
SOURCES_DIR="${SOURCES_DIR:-$LFS/sources}"

# -----------------------------------------------------------------------------
# State markers — idempotency / resume support (see lib/state.sh)
# -----------------------------------------------------------------------------
# Lives under $LFS so it survives the host->chroot->booted transitions on the
# same target filesystem. lib/state.sh writes "<step-id>.done" files here.
FT_STATE_DIR="${FT_STATE_DIR:-$LFS/.ft_state}"

# -----------------------------------------------------------------------------
# Logs — per-step tee output (see lib/common.sh run_step + lib/package.sh)
# -----------------------------------------------------------------------------
# Two contexts:
#   * On the macOS/Linux build *host* (before reboot) we cannot reliably write
#     to /var/log, so default to a repo-local ./logs directory.
#   * On the booted ft_linux *system* the canonical location is
#     /var/log/ft_linux.
# We auto-pick: if /var/log is writable AND we appear to be inside the target
# system (FT_IN_SYSTEM=1, set by the runbook after reboot) use the system path;
# otherwise the repo-local ./logs. Always overridable via FT_LOG_DIR.
if [ -n "${FT_LOG_DIR:-}" ]; then
	: # honour an explicit override
elif [ "${FT_IN_SYSTEM:-0}" = "1" ] && [ -w /var/log ] 2>/dev/null; then
	FT_LOG_DIR=/var/log/ft_linux
else
	FT_LOG_DIR=./logs
fi

export LFS_DISK LFS_DISK_BOOT LFS_DISK_SWAP LFS_DISK_ROOT
export SOURCES_DIR FT_STATE_DIR FT_LOG_DIR
