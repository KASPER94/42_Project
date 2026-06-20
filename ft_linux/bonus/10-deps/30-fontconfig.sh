#!/bin/bash
# bonus/10-deps/30-fontconfig.sh — build Fontconfig (BLFS, Xorg dependency)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# Fontconfig provides system-wide font discovery (fc-cache, fc-list). libXft,
# the terminal (st) and the WM use it to find DejaVu et al. Depends on freetype
# + expat (expat is in the mandatory final system). Recent fontconfig uses
# meson; the official release tarball ships the meson build files.
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

# -Ddoc=disabled avoids needing docbook/sphinx tooling. The test suite is
# network/timezone sensitive; keep it non-fatal (build_package default).
build_package bonus/fontconfig "fontconfig-$FONTCONFIG_VERSION.tar.xz" \
	--type=meson \
	--configure-args="-Ddoc=disabled -Dtests=disabled"
