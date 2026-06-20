#!/bin/bash
# bonus/10-deps/130-mesa.sh — build Mesa (BLFS, OpenGL implementation)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# Mesa provides libGL + the Gallium software rasterizers. For a VirtualBox
# guest running a tiling WM we do NOT need hardware 3D — software rendering is
# plenty and avoids the heavy LLVM dependency.
#
# DEFAULT (BONUS_MESA_LLVM=0): build ONLY the 'softpipe' Gallium driver, no
#   Vulkan, X11 platform only, NO LLVM. This saves the ~1h LLVM build and has
#   essentially zero "won't compile" risk. glamor accel in the Xorg server is
#   left OFF by default so the modesetting driver uses plain shadow fb / softpipe.
#
# OPT-IN (BONUS_MESA_LLVM=1): add 'llvmpipe' (faster software GL) — REQUIRES a
#   prebuilt LLVM on the system. Building LLVM from source first roughly
#   DOUBLES the bonus build time; only enable if you have already installed
#   LLVM and want the speed.
#
# meson build; deps: libdrm, libxcb/Xlib set, zlib, expat, the Python+mako
# codegen (mako must be pip-installed — see the note below if meson complains).
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

# Mesa's build needs the Python 'mako' template module. If it is missing the
# meson setup fails with a clear message; install it once with pip.
if command -v python3 >/dev/null 2>&1; then
	if ! python3 -c 'import mako' >/dev/null 2>&1; then
		log_warn "python 'mako' module not found — Mesa needs it; attempting 'pip install mako'"
		python3 -m pip install --no-index mako >/dev/null 2>&1 \
			|| python3 -m pip install mako \
			|| log_warn "could not auto-install mako; if Mesa's meson step fails, run: python3 -m pip install mako"
	fi
fi

if [ "$BONUS_MESA_LLVM" = "1" ]; then
	log_info "Mesa: LLVM path enabled (llvmpipe). This needs a prebuilt LLVM and is much slower."
	_mesa_args="-Dgallium-drivers=softpipe,llvmpipe -Dvulkan-drivers= -Dplatforms=x11 -Dllvm=enabled -Dglx=dri -Dgbm=enabled -Degl=enabled -Dgles1=disabled -Dgles2=enabled -Dvalgrind=disabled -Dlibunwind=disabled"
else
	log_info "Mesa: no-LLVM software path (softpipe only) — saves ~1h, ideal for a VBox WM demo."
	_mesa_args="-Dgallium-drivers=softpipe -Dvulkan-drivers= -Dplatforms=x11 -Dllvm=disabled -Dglx=dri -Dgbm=enabled -Degl=enabled -Dgles1=disabled -Dgles2=enabled -Dvalgrind=disabled -Dlibunwind=disabled"
fi

# Mesa has no useful 'meson test' for an end user; skip it.
build_package bonus/mesa "mesa-$MESA_VERSION.tar.xz" --type=meson \
	--configure-args="$_mesa_args" --no-check
