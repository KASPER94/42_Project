#!/bin/bash
# sources/verify-sources.sh — verify downloaded tarballs against sources/md5sums
# =============================================================================
# Purpose : Confirm every downloaded source matches its expected MD5, failing
#           LOUDLY on any mismatch or missing file so a corrupt/wrong-version
#           tarball is caught BEFORE a 12–24h build wastes time on it.
# LFS ref : Chapter 3 — md5sums verification.
# Context : RUNS INSIDE the build-host VM (after download-sources.sh). Authored
#           on macOS. Reads sources/md5sums (which the user must populate from
#           the LFS book — see that file's header).
# Make exe: chmod +x sources/verify-sources.sh
# =============================================================================
set -euo pipefail

# --- Resolve repo root & load the contract (robust regardless of depth). -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do
	REPO_ROOT="$(dirname "$REPO_ROOT")"
done
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"

MD5_FILE="$REPO_ROOT/sources/md5sums"

[ -d "$SOURCES_DIR" ] || die "sources dir not found: $SOURCES_DIR (run sources/download-sources.sh first)"
[ -f "$MD5_FILE" ]    || die "checksum list not found: $MD5_FILE"

# Strip comments / blank lines / TODO-placeholder lines (lines whose hash is
# literally TODO) so md5sum -c only sees real "<md5>  <file>" entries. We write
# the effective list to a temp file and check that.
TMP_LIST="$(mktemp 2>/dev/null || mktemp -t ftlinux_md5)"
trap 'rm -f "$TMP_LIST"' EXIT

# Keep only lines that look like a 32-hex-char md5 followed by whitespace+name.
grep -E '^[0-9a-fA-F]{32}[[:space:]]+' "$MD5_FILE" > "$TMP_LIST" || true

real_count="$(wc -l < "$TMP_LIST" | tr -d ' ')"
todo_count="$(grep -cE '^[[:space:]]*TODO[[:space:]]' "$MD5_FILE" 2>/dev/null || echo 0)"

if [ "$real_count" -eq 0 ]; then
	die "sources/md5sums has NO real checksums yet (only TODO placeholders). Populate it from the LFS book before verifying — see the file header."
fi
if [ "$todo_count" -gt 0 ]; then
	log_warn "$todo_count package(s) still carry a TODO placeholder in sources/md5sums and were NOT verified. Populate them from the LFS book for full coverage."
fi

log_info "Verifying $real_count checksum(s) in $SOURCES_DIR against sources/md5sums …"

do_verify() {
	# md5sum -c reads "<md5>  <file>" and checks each relative to CWD.
	cd "$SOURCES_DIR" || return 1
	md5sum -c "$TMP_LIST"
}

if run_step verify-sources "Verify source tarball md5sums" -- do_verify; then
	log_ok "All listed checksums verified."
	if [ "$todo_count" -gt 0 ]; then
		log_warn "NOTE: $todo_count package(s) remain unverified (TODO). Not a hard failure, but fill them in."
	fi
	exit 0
else
	die "md5sum verification FAILED — a tarball is corrupt or the wrong version. Re-download (sources/download-sources.sh) or fix sources/md5sums."
fi
