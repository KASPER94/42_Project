#!/bin/bash
# bonus/10-deps/80-xcb-proto.sh — build xcb-proto (BLFS, XCB protocol descs)
# =============================================================================
# BLFS bonus. RUNS ON THE BOOTED ft_linux system as root (NOT in chroot),
# AFTER the mandatory build passes `verify/verify.sh` with 0 failures.
# Authored on macOS; chmod +x. Idempotent via build_package.
#
# xcb-proto ships the XML protocol descriptions + the Python code generator
# (libxcb is built from these). Needs Python (in the mandatory final system).
# Autotools; no binaries beyond the generator data, so no test suite.
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

build_package bonus/xcb-proto "xcb-proto-$XCB_PROTO_VERSION.tar.xz" --no-check
