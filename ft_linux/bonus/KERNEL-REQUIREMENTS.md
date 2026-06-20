# Bonus kernel requirements (handoff to the kernel agent, A4)

The BLFS bonus (Xorg + window manager) needs a few kernel `.config` options so
that the **VirtualBox guest graphics + input** path works with the in-kernel
`vboxvideo` DRM driver and the Xorg `modesetting` DDX (no Guest Additions, no
separate video-driver package).

> **Status:** A4 has been told to fold these into
> `scripts/kernel/kernel-config`. This file records the dependency for
> traceability — the bonus does **not** build a kernel; it only validates these
> at runtime (see `bonus/30-driver/10-vbox-guest-notes.sh`).

## Required `.config` options

| Option | Value | Why the bonus needs it |
|---|---|---|
| `CONFIG_DRM` | `y` (or `m`) | Direct Rendering Manager core; everything KMS depends on it. |
| `CONFIG_DRM_VBOXVIDEO` | `y` or `m` | The VirtualBox in-tree DRM/KMS driver. Creates `/dev/dri/cardN` — what Xorg's `modesetting` driver binds. **The single most important option for this bonus.** |
| `CONFIG_DRM_FBDEV_EMULATION` | `y` | Gives a framebuffer console on the DRM device (text VT before X, sane handoff). |
| `CONFIG_FB` | `y` | Framebuffer core (prerequisite for fbdev emulation / console). |
| `CONFIG_INPUT_EVDEV` | `y` (or `m`) | Exposes `/dev/input/event*`; Xorg's input stack (libinput / built-in evdev) reads keyboard + mouse from these. |
| `CONFIG_INPUT_MOUSEDEV` | `y` (or `m`) | Legacy `/dev/input/mouse*` mouse interface; harmless to include and improves compatibility. |

## How the runtime check maps to these

`bonus/30-driver/10-vbox-guest-notes.sh` validates, on the booted system:

1. `vboxvideo` is loaded / present  → `CONFIG_DRM_VBOXVIDEO`
2. `/dev/dri/card*` exists           → `CONFIG_DRM` (+ udev populating the node)
3. `/dev/input/event*` exists        → `CONFIG_INPUT_EVDEV`

If any check fails, the script prints the exact `CONFIG_*` option to fix and
points back to this file. It is a **diagnostic, not a gate** — `run-bonus.sh`
continues so the rest of the stack still builds.

## Host-side note (not a kernel option)

The VirtualBox VM's **Graphics Controller** (VBoxVGA / VBoxSVGA / VMSVGA) is a
**host-side** setting in the VirtualBox UI, not a guest kernel option. VBoxVGA
or VBoxSVGA with the in-kernel `vboxvideo` driver is the recommended,
Guest-Additions-free combination. Raise Video Memory to ≥ 32 MB on the host if
X reports "no screens found".
