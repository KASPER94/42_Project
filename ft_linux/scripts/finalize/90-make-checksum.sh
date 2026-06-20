#!/bin/bash
# =============================================================================
# scripts/finalize/90-make-checksum.sh
#   Submission — produce the disk-image checksum (HOST-side wrapper).
#
# PURPOSE   Thin delegator to submit/checksum.sh (authored by the submission
#           agent). That script reproduces the spec's `shasum < disk.vdi`
#           (+ sha256), verifies the VM is powered off, and writes shasum.txt.
#           This wrapper exists so the finalize phase has a single, discoverable
#           entry point in the same numbering scheme as 80/81; it simply execs
#           the real implementation and forwards all arguments.
#
# RUN-CONTEXT
#   *** RUNS ON THE macOS HOST, NOT in the chroot / VM. ***
#   The VM MUST be POWERED OFF first — checksumming a live .vdi yields a value
#   that will not match the evaluator is. submit/checksum.sh enforces this.
#
# AUTHORED  on macOS — and ALSO RUN on the macOS host. chmod +x.
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

CHECKSUM="$REPO_ROOT/submit/checksum.sh"

if [ ! -f "$CHECKSUM" ]; then
	die "submit/checksum.sh not found at $CHECKSUM — it is authored by the submission agent; nothing to delegate to."
fi

log_info "Delegating to $CHECKSUM (HOST-side; VM must be powered off)"
# Hand off entirely. Prefer bash to avoid relying on the exec bit being set.
exec bash "$CHECKSUM" "$@"
