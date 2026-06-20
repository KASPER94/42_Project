#!/bin/bash
# =============================================================================
# scripts/finalize/80-final-cleanup.sh
#   LFS Ch.11 — Strip + clean the finished system to shrink the image.
#
# PURPOSE   Reduce the size of the ft_linux image before the checksum/submit by
#           removing build by-products that are not needed at runtime:
#             * strip debug symbols from binaries/libraries (GUARDED: only if
#               `strip` exists; never strips the running kernel image)
#             * remove libtool .la archives (LFS recommends deleting these)
#             * clear /tmp/*
#             * clear in-system build logs (/var/log/ft_linux)
#             * OPTIONALLY remove $LFS/sources to reclaim several GB
#               (only when KEEP_SOURCES=0; default KEEP_SOURCES=1 keeps them so
#               re-running a failed package is still possible — the spec also
#               requires being able to install packages at evaluation time).
#
#           All destructive actions are individually guarded; the script is
#           safe to run more than once.
#
# RUN AS    root, INSIDE the chroot (or on the booted system before checksum).
#
# AUTHORED  on macOS — RUN by the operator inside the build VM. chmod +x.
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

require_root

# Default to KEEPING sources (safer; satisfies "must be able to install pkgs").
KEEP_SOURCES="${KEEP_SOURCES:-1}"

run_step "80-final-cleanup" "Strip + clean (KEEP_SOURCES=$KEEP_SOURCES)" -- bash -c '
	set -euo pipefail
	keep_sources="$1"; sources_dir="$2"; log_dir="$3"

	# 1) Strip debug symbols (GUARDED). The LFS book strips with care; we only
	#    run if strip is present and we operate on the standard library/binary
	#    trees. We deliberately do NOT touch /boot (the kernel/initrd) or
	#    /lib/modules (stripping modules can break loading). Failures on
	#    individual files are ignored (some are scripts, not ELF).
	if command -v strip >/dev/null 2>&1; then
		echo "stripping unneeded symbols (guarded)..."
		# --strip-unneeded for libraries/objects; --strip-all only for binaries
		# under the standard bin/sbin dirs.
		find /usr/lib /lib -type f \( -name "*.so*" -o -name "*.a" \) \
			-exec strip --strip-unneeded {} ";" 2>/dev/null || true
		find /usr/bin /usr/sbin /bin /sbin -type f \
			-exec strip --strip-all {} ";" 2>/dev/null || true
	else
		echo "strip not found — skipping symbol stripping"
	fi

	# 2) Remove libtool .la archives (LFS: these can confuse later builds and
	#    are not needed at runtime).
	echo "removing *.la archives..."
	find /usr/lib /lib -name "*.la" -delete 2>/dev/null || true

	# 3) Clear /tmp.
	echo "clearing /tmp..."
	rm -rf /tmp/* 2>/dev/null || true

	# 4) Clear in-system build logs.
	if [ -n "$log_dir" ] && [ -d "$log_dir" ]; then
		echo "clearing build logs in $log_dir..."
		rm -rf "${log_dir:?}/"* 2>/dev/null || true
	fi
	rm -rf /var/log/ft_linux/* 2>/dev/null || true

	# 5) Optionally drop the sources tree to shrink the image (GUARDED).
	if [ "$keep_sources" = "0" ]; then
		if [ -n "$sources_dir" ] && [ -d "$sources_dir" ] && [ "$sources_dir" != "/" ]; then
			echo "KEEP_SOURCES=0 -> removing sources tree $sources_dir ..."
			rm -rf "${sources_dir:?}/"* 2>/dev/null || true
		fi
	else
		echo "KEEP_SOURCES=1 -> keeping $sources_dir (re-runs + evaluation installs stay possible)"
	fi

	echo "----- disk usage after cleanup -----"
	df -h / 2>/dev/null || true
' _ "$KEEP_SOURCES" "$SOURCES_DIR" "$FT_LOG_DIR"

log_ok "Final cleanup complete (KEEP_SOURCES=$KEEP_SOURCES)"
