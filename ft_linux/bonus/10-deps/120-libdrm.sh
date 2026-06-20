#!/bin/bash
# bonus/10-deps/120-libdrm.sh — build libdrm (BLFS, Direct Rendering Manager)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# libdrm is the userspace interface to the kernel DRM subsystem. Mesa and the
# Xorg modesetting driver both need it; in a VirtualBox guest it talks to the
# in-kernel vboxvideo DRM driver (see bonus/30-driver/). meson build, depends
# on libpciaccess (built in 100-xorg-libs.sh).
#
# We disable the vendor-specific GPU backends we do not have (intel/radeon/
# amdgpu/nouveau/vmwgfx) to keep the build small and reliable — the VBox path
# uses the generic DRM ioctls, not a vendor libdrm helper.
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

build_package bonus/libdrm "libdrm-$LIBDRM_VERSION.tar.xz" --type=meson \
	--configure-args="-Dudev=true -Dvalgrind=disabled -Dtests=false" \
	--no-check
