#!/bin/bash
# bonus/10-deps/90-libxcb.sh — build libxcb (BLFS, X C Binding)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# libxcb is the modern low-level X11 C binding; libX11 layers on top of it and
# Mesa/the WM link it directly. Depends on xcb-proto, libXau, libXdmcp.
# Autotools. Its test suite needs check (libcheck), already in the mandatory
# final system; failures are non-fatal by default.
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

# --without-doxygen: skip API docs. Python (for the protocol codegen) must be
# on PATH (it is, from the mandatory final system).
build_package bonus/libxcb "libxcb-$LIBXCB_VERSION.tar.xz" \
	--configure-args="--without-doxygen"
