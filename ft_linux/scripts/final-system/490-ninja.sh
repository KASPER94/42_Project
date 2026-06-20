#!/bin/bash
# scripts/final-system/490-ninja.sh — build Ninja (small build system; for Meson/systemd)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant (the meson backend).
# Not in the spec's 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Ninja bootstraps itself with Python (no autotools/meson). The book optionally
# honours NINJAJOBS; we just run the bootstrap, then install the single binary.
src="$(extract_only "ninja-$NINJA_VERSION.tar.gz")"
run_step final/ninja "Build & install ninja $NINJA_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		python3 configure.py --bootstrap
		install -vm755 ninja /usr/bin/
		# Install shell completions per the book (best-effort).
		install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja 2>/dev/null || true
		install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja      2>/dev/null || true
	' _ "$src"
