#!/bin/bash
# scripts/final-system/120-flex.sh — build Flex (fast lexical analyzer generator)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Autotools. The book disables the static lib and installs docs in a versioned
# dir, then creates the historical `lex` compatibility symlink.
build_package final/flex "flex-$FLEX_VERSION.tar.gz" \
	--configure-args="--disable-static --docdir=/usr/share/doc/flex-$FLEX_VERSION"

run_step final/flex-lex-symlink "Create lex compatibility symlink" -- \
	bash -c '
		set -euo pipefail
		ln -sfv flex /usr/bin/lex
		ln -sfv flex.1 /usr/share/man/man1/lex.1
	'
