#!/bin/bash
# scripts/final-system/500-meson.sh — build Meson (the systemd/dbus build system)
# LFS Ch.8 final system, runs as root inside chroot.
# DEVIATION: build-dependency added for the systemd variant. Not in the spec's
# 68 — see docs manifest.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Meson is a pure-Python package; the book installs it with the PEP517 build
# backend then copies the bash/zsh completions. Drive manually.
src="$(extract_only "meson-$MESON_VERSION.tar.gz")"
run_step final/meson "Build & install meson $MESON_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
		pip3 install --no-index --find-links dist meson
		# Install shell completions (best-effort).
		install -vDm644 data/shell-completions/bash/meson \
			/usr/share/bash-completion/completions/meson 2>/dev/null || true
		install -vDm644 data/shell-completions/zsh/_meson \
			/usr/share/zsh/site-functions/_meson 2>/dev/null || true
	' _ "$src"
