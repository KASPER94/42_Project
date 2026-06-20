#!/bin/bash
# =============================================================================
# scripts/system-config/53-fstab.sh
#   LFS Ch.9 — Creating /etc/fstab.
#
# PURPOSE   Render files/fstab.template -> /etc/fstab, substituting the real
#           partition UUIDs (read at runtime with `blkid`) for root, /boot, and
#           swap. Using UUIDs rather than /dev/sdXN keeps the table valid after
#           ft_linux boots standalone and the target disk becomes /dev/sda.
#
#           Partitions come from env/paths.sh:
#             $LFS_DISK_ROOT  -> /        (ext4)
#             $LFS_DISK_BOOT  -> /boot    (ext4)
#             $LFS_DISK_SWAP  -> swap
#
# RUN AS    root, INSIDE the chroot (blkid must see the target partitions; they
#           are visible because the host's /dev was bind-mounted into chroot).
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

TEMPLATE="$SCRIPT_DIR/files/fstab.template"
[ -f "$TEMPLATE" ] || die "fstab template missing: $TEMPLATE"
command -v blkid >/dev/null 2>&1 || die "blkid not found (util-linux must be installed)"

# Read a partition UUID via blkid; die loudly if the device has none.
get_uuid() {
	_dev="$1"; _label="$2"
	[ -b "$_dev" ] || die "$_label device is not a block device: $_dev (check LFS_DISK*)"
	_uuid="$(blkid -s UUID -o value "$_dev" 2>/dev/null || true)"
	[ -n "$_uuid" ] || die "could not read UUID for $_label ($_dev) — is it formatted?"
	printf '%s' "$_uuid"
	unset _dev _label _uuid
}

log_info "Reading partition UUIDs via blkid:"
ROOT_UUID="$(get_uuid "$LFS_DISK_ROOT" root)"
BOOT_UUID="$(get_uuid "$LFS_DISK_BOOT" /boot)"
SWAP_UUID="$(get_uuid "$LFS_DISK_SWAP" swap)"
log_info "  root  ($LFS_DISK_ROOT) = $ROOT_UUID"
log_info "  /boot ($LFS_DISK_BOOT) = $BOOT_UUID"
log_info "  swap  ($LFS_DISK_SWAP) = $SWAP_UUID"

run_step "53-fstab" "Generate /etc/fstab from template (UUIDs via blkid)" -- bash -c '
	set -euo pipefail
	template="$1"; root_uuid="$2"; boot_uuid="$3"; swap_uuid="$4"

	# Substitute placeholders. Use sed with @@..@@ markers (UUIDs contain no
	# special sed metacharacters, so plain substitution is safe).
	sed -e "s|@@ROOT_UUID@@|$root_uuid|g" \
	    -e "s|@@BOOT_UUID@@|$boot_uuid|g" \
	    -e "s|@@SWAP_UUID@@|$swap_uuid|g" \
	    "$template" > /etc/fstab

	echo "----- generated /etc/fstab -----"
	cat /etc/fstab
' _ "$TEMPLATE" "$ROOT_UUID" "$BOOT_UUID" "$SWAP_UUID"

# Assert no placeholder leaked through (a missing UUID would break boot).
if grep -q "@@" /etc/fstab; then
	die "ASSERT FAILED: /etc/fstab still contains @@ placeholders — UUID substitution failed"
fi

log_ok "/etc/fstab written with root//boot/swap UUIDs"
