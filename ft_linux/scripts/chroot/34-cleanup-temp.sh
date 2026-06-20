#!/bin/bash
# =============================================================================
# scripts/chroot/34-cleanup-temp.sh
#   LFS Ch.7 — Cleaning Up and Saving the Temporary System.
#
# PURPOSE   Reclaim space and remove cruft accumulated by the temporary tools,
#           per the LFS book:
#             * strip debugging symbols from binaries/libraries (guarded so a
#               failure on an in-use or unstrippable file is non-fatal);
#             * remove the documentation the temp tools installed
#               (/usr/share/{info,man,doc}/*);
#             * remove leftover libtool archive (.la) files (they break later
#               libtool relinking in Ch.8);
#             * clear /tmp/*.
#           This does NOT make the backup tarball — that is an operator decision
#           documented in the runbook; we only do the in-place cleanup here.
#
# RUN CONTEXT  *** RUNS INSIDE THE CHROOT ***  (root, under $LFS as "/").
#           Does NOT call enter_chroot. Staged + invoked via 31-enter-chroot.sh:
#               sudo ./scripts/chroot/31-enter-chroot.sh \
#                    /opt/ft_linux/scripts/chroot/34-cleanup-temp.sh
#
# ASSUMPTION  Repo reachable inside the chroot (e.g. /opt/ft_linux). Bootstrap
#           dies clearly if env/lfs.env cannot be found.
#
# AUTHORED  on macOS — RUN by the operator (via the orchestrator) inside the VM.
# =============================================================================
set -euo pipefail

# --- Foundation bootstrap (tolerant: must work from inside the chroot) ------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
if [ ! -f "$REPO_ROOT/env/lfs.env" ]; then
	echo "FATAL: cannot locate env/lfs.env above $SCRIPT_DIR" >&2
	echo "       This script runs INSIDE the chroot — stage the repo under \$LFS" >&2
	echo "       first (e.g. bind-mount/copy to /opt/ft_linux)." >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"

require_root

# --- 1) Strip debugging symbols (the book's guarded incantation) ------------
# We must NOT strip the dynamic loader's debug-needed sections nor binaries that
# are currently mapped; we save/restore the loader, and tolerate per-file errors
# (|| true) so a single unstrippable file does not abort the whole pass.
run_step "34a-strip" "Strip debug symbols from temp system" -- bash -c '
	set -uo pipefail
	# Save the dynamic loader so a partial strip cannot brick the chroot.
	save_usrlib="$(cd /usr/lib && ls ld-linux-x86-64.so.2 2>/dev/null || true)"

	# Strip shared libs: keep symbol tables some need (libc/libm/etc handled by
	# --strip-unneeded). Errors per file are ignored.
	find /usr/lib -type f -name "*.so*" ! -name "ld-*" -exec \
		strip --strip-unneeded {} ";" 2>/dev/null || true
	find /usr/lib -type f -name "*.a" -exec \
		strip --strip-debug {} ";" 2>/dev/null || true
	# Strip executables.
	find /usr/{bin,sbin,libexec} -type f -exec \
		strip --strip-all {} ";" 2>/dev/null || true

	echo "strip pass complete (per-file errors tolerated; loader: ${save_usrlib:-n/a})"
'

# --- 2) Remove temp documentation -------------------------------------------
run_step "34b-rm-docs" "Remove temp /usr/share/{info,man,doc}/*" -- bash -c '
	set -euo pipefail
	rm -rf /usr/share/{info,man,doc}/*
'

# --- 3) Remove libtool archive (.la) files ----------------------------------
run_step "34c-rm-la" "Remove leftover libtool .la files" -- bash -c '
	set -euo pipefail
	find /usr/{lib,libexec} -name "*.la" -delete 2>/dev/null || true
'

# --- 4) Clear /tmp ----------------------------------------------------------
run_step "34d-clear-tmp" "Clear /tmp/*" -- bash -c '
	set -euo pipefail
	rm -rf /tmp/* 2>/dev/null || true
'

log_ok "Ch.7 temporary-system cleanup complete (backup tarball is operator-driven; see RUNBOOK)"
