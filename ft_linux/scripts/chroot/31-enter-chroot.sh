#!/bin/bash
# =============================================================================
# scripts/chroot/31-enter-chroot.sh
#   LFS Ch.7 — Entering the Chroot environment.
#
# PURPOSE   Thin wrapper around enter_chroot (lib/chroot-helpers.sh). It either
#           drops the operator into an interactive chroot login shell, or runs a
#           single in-chroot script and returns its exit status.
#
# USAGE
#     # interactive login shell inside $LFS:
#     sudo ./scripts/chroot/31-enter-chroot.sh
#
#     # run a staged in-chroot script (NON-interactive):
#     sudo ./scripts/chroot/31-enter-chroot.sh /sources/32-create-dirs-files.sh
#
#   !!! IMPORTANT — THE $LFS-RELATIVE PATH RULE !!!
#   The script argument is interpreted RELATIVE TO THE CHROOT ROOT ($LFS), NOT
#   relative to the host filesystem. So you must STAGE the inner script (and any
#   libs/env it sources) somewhere under $LFS *first*, then pass the in-chroot
#   path. For this suite the orchestrator (A8) makes the repo reachable inside
#   the chroot at $LFS/opt/ft_linux (bind mount or copy); a script staged there
#   would be invoked as e.g. /opt/ft_linux/scripts/chroot/32-create-dirs-files.sh.
#
# RUN AS    ROOT, on the build HOST. Requires 30-prepare-virtual-fs.sh first.
#
# AUTHORED  on macOS — RUN by the operator inside the Linux build VM.
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
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/chroot-helpers.sh"

require_root

# Pass through an optional in-chroot script path (else interactive). The helper
# enforces the $LFS-relative semantics documented above.
enter_chroot "$@"
