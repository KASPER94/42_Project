#!/bin/bash
# =============================================================================
# scripts/boot/70-grub-install.sh
#   LFS Ch.10 — Install the GRUB boot loader onto the TARGET disk (BIOS).
#
# PURPOSE   Write GRUB's boot code to the MBR / boot track of the ft_linux
#           TARGET disk so the machine boots ft_linux standalone (spec rule:
#           "Your distro MUST boot with a bootloader, like LILO or GRUB").
#
#           BIOS (i386-pc) is used because the VirtualBox VM is created with a
#           legacy BIOS firmware (the suite's default). For an EFI VM, see the
#           EFI ALTERNATIVE note below.
#
#   grub-install --target=i386-pc "$LFS_DISK"
#
#   $LFS_DISK is the WHOLE target disk (e.g. /dev/sdb in the build VM), NOT a
#   partition and NOT the build host's own disk. The destructive-guard in
#   env/paths.sh + run-all.sh ensures this points at the target.
#
#   EFI ALTERNATIVE (if the VM uses EFI firmware): mount the ESP at
#   /boot/efi (vfat) and run instead:
#       grub-install --target=x86_64-efi --efi-directory=/boot/efi \
#           --bootloader-id=ft_linux
#   (requires the GRUB efi modules + efivarfs; not used by default here.)
#
# RUN AS    root, INSIDE the chroot. The chroot must have /dev, /proc, /sys
#           bind-mounted (done in Ch.7) so grub can probe the disk.
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

command -v grub-install >/dev/null 2>&1 || die "grub-install not found (GRUB must be built/installed first)"

# Safety: target must be a whole-disk block device, not a partition.
[ -b "$LFS_DISK" ] || die "LFS_DISK '$LFS_DISK' is not a block device — set it to the TARGET disk"
case "$LFS_DISK" in
	*[0-9]) log_warn "LFS_DISK '$LFS_DISK' ends in a digit — confirm this is a whole disk, not a partition" ;;
esac

log_warn "About to install GRUB (BIOS/i386-pc) to the WHOLE disk: $LFS_DISK"
if ! confirm "Proceed with grub-install to $LFS_DISK?"; then
	die "aborted by operator (set ASSUME_YES=1 to skip this prompt)"
fi

run_step "70-grub-install" "grub-install --target=i386-pc $LFS_DISK" -- bash -c '
	set -euo pipefail
	disk="$1"
	# --recheck re-probes the device map; keeps boot files under /boot/grub.
	grub-install --target=i386-pc --boot-directory=/boot --recheck "$disk"
	echo "----- /boot/grub -----"
	ls -l /boot/grub 2>/dev/null || true
' _ "$LFS_DISK"

# Sanity: GRUB must have laid down its modules + the i386-pc image.
[ -d /boot/grub/i386-pc ] || die "ASSERT FAILED: /boot/grub/i386-pc not created — grub-install did not complete"

log_ok "GRUB (BIOS) installed to $LFS_DISK; boot files in /boot/grub"
