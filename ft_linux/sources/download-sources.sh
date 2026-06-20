#!/bin/bash
# sources/download-sources.sh — fetch every source tarball + LFS patches
# =============================================================================
# Purpose : Download all source tarballs (one per *_URL in env/versions.sh) into
#           $SOURCES_DIR, resumably, using wget --continue (falling back to
#           curl). Also fetch the LFS patches the build needs.
# LFS ref : Chapter 3 — "All Packages" / "Needed Patches" / wget-list.
# Context : RUNS INSIDE the build-host VM (or any machine with net access that
#           can write to $SOURCES_DIR). Authored on macOS. Idempotent/resumable:
#           --continue means an interrupted download picks up where it stopped,
#           and already-complete files are not re-fetched.
# Make exe: chmod +x sources/download-sources.sh
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

# -----------------------------------------------------------------------------
# Ensure $SOURCES_DIR exists and we have a downloader (spec REQUIRES one).
# -----------------------------------------------------------------------------
mkdir -p "$SOURCES_DIR"

HAVE_WGET=0; HAVE_CURL=0
command -v wget >/dev/null 2>&1 && HAVE_WGET=1
command -v curl >/dev/null 2>&1 && HAVE_CURL=1
if [ "$HAVE_WGET" -eq 0 ] && [ "$HAVE_CURL" -eq 0 ]; then
	die "neither wget nor curl found — install one (the spec REQUIRES a downloader). Run vm/provision-build-host.sh."
fi

# fetch_one <url> — download a single URL into $SOURCES_DIR, resumable,
# skipping if a complete copy already exists. Returns non-zero on failure.
fetch_one() {
	_url="$1"
	_fname="$(basename "$_url")"
	_dest="$SOURCES_DIR/$_fname"

	if [ "$HAVE_WGET" -eq 1 ]; then
		# --continue resumes partial files; --timestamping is avoided so a
		# fully-present file is simply confirmed. -nv keeps logs readable.
		wget --continue --no-verbose --tries=3 --timeout=60 \
			--directory-prefix="$SOURCES_DIR" "$_url"
	else
		# curl fallback. -C - resumes; -L follows redirects; -f fails on 404.
		curl -fL --retry 3 --connect-timeout 60 -C - -o "$_dest" "$_url"
	fi
}

# -----------------------------------------------------------------------------
# Collect every *_URL variable currently in scope (defined by env/versions.sh).
# We enumerate variable names ending in _URL, then dereference each. Mirror
# variables (GNU_MIRROR, …) do NOT end in _URL, so they are naturally excluded.
# -----------------------------------------------------------------------------
collect_urls() {
	# `compgen -v` lists all shell variable names; filter to *_URL.
	for _name in $(compgen -v | grep -E '_URL$' | sort); do
		_val="${!_name}"
		[ -n "$_val" ] && printf '%s\n' "$_val"
	done
}

# -----------------------------------------------------------------------------
# LFS patches. The systemd build needs a small set of patches from the LFS
# patches mirror. We keep this list explicit (and version-derived) so it stays
# auditable; verify-sources.sh / the LFS book are the source of truth for the
# exact filenames. Adjust to your LFS book revision if a patch name differs.
# -----------------------------------------------------------------------------
LFS_PATCH_BASE="https://www.linuxfromscratch.org/patches/lfs/12.3"
PATCH_URLS=(
	"${LFS_PATCH_BASE}/bzip2-${BZIP2_VERSION}-install_docs-1.patch"
	"${LFS_PATCH_BASE}/coreutils-${COREUTILS_VERSION}-i18n-1.patch"
	"${LFS_PATCH_BASE}/glibc-${GLIBC_VERSION}-fhs-1.patch"
	"${LFS_PATCH_BASE}/kbd-${KBD_VERSION}-backspace-1.patch"
)

# -----------------------------------------------------------------------------
# Do the work, wrapped in run_step for logging + idempotency.
# -----------------------------------------------------------------------------
do_downloads() {
	_failed=0
	_count=0

	log_info "Downloading source tarballs into $SOURCES_DIR …"
	while IFS= read -r _url; do
		_count=$((_count + 1))
		_fname="$(basename "$_url")"
		log_info "[$_count] $_fname"
		if ! fetch_one "$_url"; then
			log_warn "FAILED: $_url"
			_failed=$((_failed + 1))
		fi
	done < <(collect_urls)

	log_info "Downloading LFS patches …"
	for _url in "${PATCH_URLS[@]}"; do
		_fname="$(basename "$_url")"
		log_info "patch: $_fname"
		if ! fetch_one "$_url"; then
			log_warn "FAILED (patch): $_url"
			_failed=$((_failed + 1))
		fi
	done

	if [ "$_failed" -ne 0 ]; then
		log_error "$_failed download(s) failed — re-run to resume (wget --continue / curl -C -)."
		return 1
	fi
	log_ok "All sources + patches present in $SOURCES_DIR."
	return 0
}

# run_step executes its command via "$@" in THIS shell (no sub-shell), so the
# do_downloads function and the sourced env vars remain in scope.
run_step download-sources "Download all source tarballs + LFS patches" -- \
	do_downloads || die "download-sources failed; re-run to resume."

log_info "Next: sources/verify-sources.sh  (md5sum -c against sources/md5sums)"
