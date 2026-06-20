#!/bin/bash
# =============================================================================
# scripts/boot/71-grub-cfg.sh
#   LFS Ch.10 — Generate /boot/grub/grub.cfg (spec-critical: kernel name).
#
# PURPOSE   Render scripts/boot/grub.cfg.template -> /boot/grub/grub.cfg with:
#             * the `linux` line referencing the EXACT spec-named kernel
#               binary  /boot/vmlinuz-${KERNEL_VERSION}-skapers  (spec rule R5;
#               "Adapt your bootloader configuration to that"), and
#             * root=UUID=<root-uuid>, with the UUID read via blkid at runtime
#               (robust to device renaming once ft_linux boots standalone).
#           Also sets a sane default entry + timeout.
#
#           This script and 62-kernel-install.sh are the two places that enforce
#           the spec-critical kernel naming end-to-end: 62 produces the named
#           binary; 71 makes the boot loader point at exactly that name.
#
# RUN AS    root, INSIDE the chroot.
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

TEMPLATE="$SCRIPT_DIR/grub.cfg.template"
[ -f "$TEMPLATE" ] || die "grub.cfg template missing: $TEMPLATE"
command -v blkid >/dev/null 2>&1 || die "blkid not found (util-linux must be installed)"

# Menu timeout (seconds) — override with GRUB_TIMEOUT=<n>.
GRUB_TIMEOUT="${GRUB_TIMEOUT:-5}"

# The EXACT kernel basename (must match what 62-kernel-install.sh wrote).
KERNEL_NAME="vmlinuz-${KERNEL_VERSION}-${LFS_USER_LOGIN}"
VMLINUZ="/boot/$KERNEL_NAME"

# Hard precondition: the named kernel binary must already be in /boot.
[ -f "$VMLINUZ" ] || die "kernel binary $VMLINUZ not found — run 62-kernel-install.sh first"

# Read the root + /boot partition UUIDs.
get_uuid() {
	_dev="$1"; _label="$2"
	[ -b "$_dev" ] || die "$_label device is not a block device: $_dev (check LFS_DISK*)"
	_uuid="$(blkid -s UUID -o value "$_dev" 2>/dev/null || true)"
	[ -n "$_uuid" ] || die "could not read UUID for $_label ($_dev)"
	printf '%s' "$_uuid"
	unset _dev _label _uuid
}
ROOT_UUID="$(get_uuid "$LFS_DISK_ROOT" root)"
BOOT_UUID="$(get_uuid "$LFS_DISK_BOOT" /boot)"
log_info "root UUID  = $ROOT_UUID"
log_info "/boot UUID = $BOOT_UUID"
log_info "kernel     = $KERNEL_NAME"

run_step "71-grub-cfg" "Render grub.cfg -> /boot/grub/grub.cfg (kernel=$KERNEL_NAME)" -- bash -c '
	set -euo pipefail
	template="$1"; kname="$2"; root_uuid="$3"; boot_uuid="$4"; timeout="$5"

	mkdir -pv /boot/grub
	sed -e "s|@@KERNEL_NAME@@|$kname|g" \
	    -e "s|@@ROOT_UUID@@|$root_uuid|g" \
	    -e "s|@@BOOT_UUID@@|$boot_uuid|g" \
	    -e "s|@@TIMEOUT@@|$timeout|g" \
	    "$template" > /boot/grub/grub.cfg

	echo "----- /boot/grub/grub.cfg -----"
	cat /boot/grub/grub.cfg
' _ "$TEMPLATE" "$KERNEL_NAME" "$ROOT_UUID" "$BOOT_UUID" "$GRUB_TIMEOUT"

# =============================================================================
# LOUD spec assertions on the rendered grub.cfg.
# =============================================================================
CFG=/boot/grub/grub.cfg
[ -f "$CFG" ] || die "ASSERT FAILED: $CFG not produced"

# No placeholder may survive.
grep -q "@@" "$CFG" && die "ASSERT FAILED: $CFG still contains @@ placeholders"

# (R5) The linux line must reference the EXACT spec-named kernel.
grep -Eq "^[[:space:]]*linux[[:space:]]+/${KERNEL_NAME}([[:space:]]|$)" "$CFG" \
	|| die "ASSERT FAILED (R5): grub.cfg 'linux' line does not reference /$KERNEL_NAME"
log_ok "ASSERT OK (R5): grub.cfg boots /$KERNEL_NAME"

# root= must be by UUID and match the root partition.
grep -q "root=UUID=$ROOT_UUID" "$CFG" \
	|| die "ASSERT FAILED: grub.cfg root=UUID does not match root partition UUID $ROOT_UUID"
log_ok "ASSERT OK: grub.cfg uses root=UUID=$ROOT_UUID"

log_ok "grub.cfg generated and verified (timeout=${GRUB_TIMEOUT}s, kernel=$KERNEL_NAME)"
