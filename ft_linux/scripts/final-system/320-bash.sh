#!/bin/bash
# scripts/final-system/320-bash.sh — build Bash (the Bourne-Again SHell)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# NOTE: the version variable is BASH_VERSION_LFS (BASH_VERSION is a reserved
# bash variable). Build against the system readline.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# The full bash test suite must run as a non-root user and is long; the book
# marks it optional. We build with the system readline and skip the suite.
build_package final/bash "bash-$BASH_VERSION_LFS.tar.gz" \
	--configure-args="--without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-$BASH_VERSION_LFS" \
	--no-check

# Make /bin/bash the canonical shell location (merged-/usr: /bin -> /usr/bin).
run_step final/bash-symlink "Ensure /bin/sh and exec the new bash" -- \
	bash -c '
		set -euo pipefail
		ln -sfv bash /usr/bin/sh 2>/dev/null || true
	'
