#!/bin/bash
# =============================================================================
# scripts/temp-tools/22-bash.sh — LFS Ch.6 — Bash (temporary tool).
#
# PURPOSE   Cross-compile Bash for $LFS and create the customary `sh -> bash`
#           symlink so scripts invoked as /bin/sh work inside the coming chroot.
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

# Cross-compile; --without-bash-malloc avoids the bundled allocator (segfaults
# under cross builds). build_package handles extract/build/install/cleanup.
build_package temp/bash "bash-$BASH_VERSION_LFS.tar.gz" --no-check \
	--configure-args="--host=$LFS_TGT --build=$(uname -m)-pc-linux-gnu --without-bash-malloc"

# Provide /bin/sh -> bash inside the target so the chroot's #!/bin/sh works.
run_step "22b-bash-sh-symlink" "Create sh -> bash symlink in \$LFS" -- bash -c '
	set -euo pipefail
	ln -sfv bash "$LFS/usr/bin/sh"
'
