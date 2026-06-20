#!/bin/bash
# bonus/10-deps/140-libepoxy.sh — build libepoxy (BLFS, GL dispatch)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# libepoxy is a GL/EGL function-pointer dispatch library. The Xorg server (and
# its optional glamor acceleration) links it, so it is required to build the
# server even when we run software rendering. meson build; depends on Mesa.
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

build_package bonus/libepoxy "libepoxy-$LIBEPOXY_VERSION.tar.xz" \
	--type=meson --no-check
