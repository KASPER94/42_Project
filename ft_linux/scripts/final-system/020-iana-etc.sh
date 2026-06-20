#!/bin/bash
# scripts/final-system/020-iana-etc.sh — install Iana-Etc (/etc/protocols, /etc/services)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Iana-Etc provides the data for /etc/protocols and /etc/services. There is no
# build step — the book simply copies the prebuilt files into /etc.
src="$(extract_only "iana-etc-$IANA_ETC_VERSION.tar.gz")"
run_step final/iana-etc "Install iana-etc $IANA_ETC_VERSION (/etc/services, /etc/protocols)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		cp -v services protocols /etc
	' _ "$src"
