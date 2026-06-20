#!/bin/bash
# =============================================================================
# scripts/temp-tools/23-coreutils.sh — LFS Ch.6 — Coreutils (temporary tool).
#
# PURPOSE   Cross-compile Coreutils for $LFS. Enables the build of `hostname`
#           (off by default) and forces the cross-build values that configure
#           cannot probe (fnmatch / getline working). After install, the book
#           moves a few programs into the FHS-correct locations:
#             /usr/bin/chroot -> /usr/sbin/chroot
#             and stages the head/nice/etc. that later phases expect.
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
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
source "$REPO_ROOT/lib/package.sh"

require_not_root

build_package temp/coreutils "coreutils-$COREUTILS_VERSION.tar.xz" --no-check \
	--configure-args="--host=$LFS_TGT --build=$(uname -m)-pc-linux-gnu --enable-install-program=hostname --enable-no-install-program=kill,uptime gl_cv_macro_MB_CUR_MAX_good=y"

# FHS relocation the LFS book performs after Coreutils install: chroot belongs
# in sbin. Guard each move so a re-run (idempotent) does not error.
run_step "23b-coreutils-fhs" "Coreutils FHS relocations (chroot -> sbin)" -- bash -c '
	set -euo pipefail
	if [ -e "$LFS/usr/bin/chroot" ]; then
		mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin"
	fi
	# Stage the chroot man page in the sbin section if it was installed.
	if [ -f "$LFS/usr/share/man/man1/chroot.1" ]; then
		mkdir -pv "$LFS/usr/share/man/man8"
		mv -v "$LFS/usr/share/man/man1/chroot.1" "$LFS/usr/share/man/man8/chroot.8"
		sed -i "s/\"1\"/\"8\"/" "$LFS/usr/share/man/man8/chroot.8"
	fi
'
