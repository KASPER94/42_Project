#!/bin/bash
# =============================================================================
# scripts/kernel/62-kernel-install.sh
#   LFS Ch.10.3 — Install the kernel image into /boot with the SPEC name.
#
# PURPOSE   This is the MOST spec-critical script in the suite. It enforces two
#           of the three naming rules from the subject:
#
#     R5  The kernel binary in /boot MUST be named
#         vmlinuz-<linux_version>-<student_login>
#           ->  /boot/vmlinuz-${KERNEL_VERSION}-skapers
#
#     R4  The kernel version string MUST contain the student login
#           ->  `uname -r` (== `make kernelrelease`) MUST end with "-skapers"
#
#         (R3, sources in /usr/src/kernel-<version>, is enforced in 60-prepare.)
#
#   Steps (verbatim from the task spec):
#     cp -iv arch/x86/boot/bzImage /boot/vmlinuz-${KERNEL_VERSION}-skapers
#     cp -iv System.map           /boot/System.map-${KERNEL_VERSION}
#     cp -iv .config              /boot/config-${KERNEL_VERSION}
#
#   Then ASSERT loudly (die on failure):
#     * /boot/vmlinuz-${KERNEL_VERSION}-skapers exists
#     * the kernelrelease string ends with "-skapers"
#
#   The login is taken from $LFS_USER_LOGIN (single source of truth); we still
#   spell the literal "-skapers" in the asserts/messages for spec readability.
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

KERNEL_SRC="/usr/src/kernel-${KERNEL_VERSION}"
[ -d "$KERNEL_SRC" ] || die "kernel source dir not found: $KERNEL_SRC (run 60/61 first)"

# The spec-mandated binary name. Derived from KERNEL_VERSION + the login.
VMLINUZ="/boot/vmlinuz-${KERNEL_VERSION}-${LFS_USER_LOGIN}"
# The login MUST be 'skapers' per the fixed decisions; guard against a drift.
[ "$LFS_USER_LOGIN" = "skapers" ] || die "LFS_USER_LOGIN is '$LFS_USER_LOGIN', expected 'skapers' (spec-fixed)"

run_step "62-kernel-install" "Install /boot/vmlinuz-${KERNEL_VERSION}-${LFS_USER_LOGIN} + maps" -- bash -c '
	set -euo pipefail
	kernel_src="$1"; vmlinuz="$2"; kver="$3"
	cd "$kernel_src"

	mkdir -pv /boot

	# bzImage path is fixed for x86_64.
	[ -f arch/x86/boot/bzImage ] || { echo "FATAL: arch/x86/boot/bzImage missing — build the kernel first" >&2; exit 1; }

	# --- The SPEC-CRITICAL copies (verbatim) ---
	cp -iv arch/x86/boot/bzImage "$vmlinuz"
	cp -iv System.map            "/boot/System.map-$kver"
	cp -iv .config               "/boot/config-$kver"

	echo "----- /boot contents -----"
	ls -l /boot/vmlinuz-* /boot/System.map-* /boot/config-* 2>/dev/null || true
' _ "$KERNEL_SRC" "$VMLINUZ" "$KERNEL_VERSION"

# =============================================================================
# LOUD spec assertions. Any failure here MUST stop the build.
# =============================================================================

# (R5) The named binary must exist in /boot.
test -f "$VMLINUZ" \
	|| die "ASSERT FAILED (R5): kernel binary $VMLINUZ does not exist"
log_ok "ASSERT OK (R5): $VMLINUZ present"

# (R4) The kernel release string must end with -skapers. Prefer the live
# `make kernelrelease`; fall back to the recorded include/config/kernel.release.
KRELEASE=""
if KRELEASE="$(make -s -C "$KERNEL_SRC" kernelrelease 2>/dev/null)"; then
	:
elif [ -f "$KERNEL_SRC/include/config/kernel.release" ]; then
	KRELEASE="$(cat "$KERNEL_SRC/include/config/kernel.release")"
fi
[ -n "$KRELEASE" ] || die "ASSERT FAILED (R4): could not determine kernelrelease"

case "$KRELEASE" in
	*-skapers)
		log_ok "ASSERT OK (R4): kernelrelease '$KRELEASE' ends with -skapers (uname -r will match)"
		;;
	*)
		die "ASSERT FAILED (R4): kernelrelease '$KRELEASE' does NOT end with -skapers — fix CONFIG_LOCALVERSION in scripts/kernel/kernel-config"
		;;
esac

# Cross-check: the binary name embeds the same version as the release string.
case "$KRELEASE" in
	"${KERNEL_VERSION}-skapers")
		log_ok "ASSERT OK: release '$KRELEASE' == \${KERNEL_VERSION}-skapers (binary name consistent)"
		;;
	*)
		log_warn "kernelrelease '$KRELEASE' != '${KERNEL_VERSION}-skapers' — binary name and uname -r differ in their version part (GRUB still boots $VMLINUZ); verify expectations"
		;;
esac

log_ok "Kernel installed: $VMLINUZ (uname -r => $KRELEASE)"
