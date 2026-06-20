#!/bin/bash
# bonus/30-driver/10-vbox-guest-notes.sh — validate the VirtualBox graphics path
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent (read-only checks; writes no files).
#
# This script does NOT build a video driver. In a VirtualBox guest the correct,
# Guest-Additions-free graphics stack is:
#
#     kernel: vboxvideo  (in-tree DRM/KMS driver, CONFIG_DRM_VBOXVIDEO)
#        |  exposes a /dev/dri/cardN KMS device
#        v
#     Xorg:   modesetting DDX  (built into xorg-server, no separate package)
#
# So there is nothing to compile here — the kernel provides the device and the
# server's built-in modesetting driver consumes it. This script VALIDATES that
# path on the running system and prints clear guidance if something is missing.
#
# It also documents the one setting that is NOT controllable from inside the
# guest: the VM's Graphics Controller, chosen in the VirtualBox HOST UI.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"
source "$REPO_ROOT/bonus/00-blfs-env.sh"

require_root

_warn=0

log_info "=== VirtualBox guest graphics validation (vboxvideo DRM + Xorg modesetting) ==="

# ---------------------------------------------------------------------------
# 1) Is the vboxvideo DRM driver available? It may be built-in (=y) or a module
#    (=m). Check both: a /sys node, lsmod, or the in-kernel modules list.
# ---------------------------------------------------------------------------
if lsmod 2>/dev/null | grep -q '^vboxvideo'; then
	log_ok "vboxvideo is loaded as a module"
elif [ -d /sys/module/vboxvideo ]; then
	log_ok "vboxvideo is present (built-in or already loaded: /sys/module/vboxvideo exists)"
else
	# Try to load it; if it is a module this succeeds, if built-in modprobe is a
	# harmless no-op, if absent it fails and we warn.
	if modprobe vboxvideo 2>/dev/null; then
		log_ok "vboxvideo loaded on demand via modprobe"
	else
		log_warn "vboxvideo not loaded and modprobe failed."
		log_warn "  -> The kernel must be built with CONFIG_DRM_VBOXVIDEO (=y or =m)."
		log_warn "  -> See bonus/KERNEL-REQUIREMENTS.md (handed to the kernel agent, A4)."
		_warn=1
	fi
fi

# ---------------------------------------------------------------------------
# 2) Did the driver create a DRM/KMS device node? modesetting needs /dev/dri/card*.
# ---------------------------------------------------------------------------
if ls /dev/dri/card* >/dev/null 2>&1; then
	log_ok "DRM device node present: $(ls /dev/dri/card* 2>/dev/null | tr '\n' ' ')"
else
	log_warn "no /dev/dri/card* node — the modesetting driver has nothing to drive."
	log_warn "  -> Needs CONFIG_DRM + CONFIG_DRM_VBOXVIDEO and udev populating /dev/dri."
	log_warn "  -> Confirm the VM Graphics Controller is VBoxVGA or VMSVGA (see step 4)."
	_warn=1
fi

# ---------------------------------------------------------------------------
# 3) Are the input event devices present? evdev (via libinput/the server's
#    built-in input) needs /dev/input/event*; without them keyboard+mouse die.
# ---------------------------------------------------------------------------
if ls /dev/input/event* >/dev/null 2>&1; then
	log_ok "input event devices present: $(ls /dev/input/event* 2>/dev/null | wc -l | tr -d ' ') node(s)"
else
	log_warn "no /dev/input/event* nodes — keyboard/mouse will not work in X."
	log_warn "  -> Needs CONFIG_INPUT_EVDEV (+ CONFIG_INPUT_MOUSEDEV). See KERNEL-REQUIREMENTS.md."
	_warn=1
fi

# ---------------------------------------------------------------------------
# 4) The host-side setting we cannot read from inside the guest: document it.
# ---------------------------------------------------------------------------
cat <<'EOF' >&2

  --- HOST-SIDE setting (NOT controllable from inside the guest) ---
  In the VirtualBox HOST UI:  Settings -> Display -> Screen -> Graphics Controller.
    * VBoxVGA  : works with the in-kernel vboxvideo DRM driver (recommended for
                 this Guest-Additions-free setup).
    * VMSVGA   : also exposes a KMS device the modesetting driver can use; if you
                 pick this, ensure the kernel has the vmwgfx/vboxvideo support.
    * VBoxSVGA : the modern default; KMS-capable as well.
  If X shows only a black screen or "no screens found", switch the controller
  and/or raise the Video Memory to >= 32 MB on the host, then reboot the guest.

  --- OPTIONAL / heavier: VirtualBox Guest Additions ---
  Guest Additions add seamless resize, shared clipboard and an accelerated 3D
  driver, but they are NOT required for this bonus (the in-kernel vboxvideo +
  Xorg modesetting path gives a working desktop). They are also heavier to
  build (kernel modules against the running kernel) and can break on a custom
  LFS kernel. If you still want them: mount the Guest Additions ISO and run its
  installer, ensuring kernel headers for the running ft_linux kernel are present.
  This is intentionally left as an optional, manual step.

EOF

if [ "$_warn" -eq 0 ]; then
	log_ok "VirtualBox graphics path looks good: vboxvideo DRM + /dev/dri + input devices present."
else
	log_warn "One or more checks failed — review the messages above before running startx."
	log_warn "These are kernel/host-config issues, not bonus build failures."
fi

# Always exit 0: this is a diagnostic, not a gate. run-bonus.sh continues.
exit 0
