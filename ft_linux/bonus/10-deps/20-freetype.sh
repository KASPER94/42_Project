#!/bin/bash
# bonus/10-deps/20-freetype.sh — build FreeType 2 (BLFS, Xorg dependency)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# FreeType renders TrueType/Type1 fonts; fontconfig, libXft, the terminal and
# the WM all link it. Built BEFORE fontconfig and harfbuzz are present, so we
# disable the optional harfbuzz auto-hinter loop (the BLFS first-pass pattern);
# a second freetype build with harfbuzz is unnecessary for a tiling WM demo.
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

# BLFS enables the subpixel rendering + infinality patches via macros; the
# minimal reliable path just enables the bundled zlib/png usage. freetype's
# autotools wrapper has no test suite (--no-check).
build_package bonus/freetype "freetype-$FREETYPE_VERSION.tar.xz" \
	--configure-args="--enable-freetype-config --disable-static --without-harfbuzz" \
	--no-check
