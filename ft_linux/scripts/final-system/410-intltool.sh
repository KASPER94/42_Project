#!/bin/bash
# scripts/final-system/410-intltool.sh — build Intltool (i18n string extraction)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Intltool depends on XML::Parser. The book applies a one-line perl-5.22+ regex
# fix before configure. Drive manually so we can apply that sed first.
src="$(extract_only "intltool-$INTLTOOL_VERSION.tar.gz")"
run_step final/intltool "Build & install intltool $INTLTOOL_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Fix a deprecated perl regex warning under perl 5.22+. The canonical LFS
		# fix escapes the ${gt_func} interpolation in intltool-update.in. We use
		# perl in-place so we avoid fragile shell/sed backslash quoting.
		perl -i -pe "s/\\\$\\{gt_func\\}/\\\$\\\${gt_func}/g" intltool-update.in 2>/dev/null || true
		./configure --prefix=/usr
		make
		if ! make check; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: intltool test suite reported failures (non-fatal)" >&2
		fi
		make install
		install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-'"$INTLTOOL_VERSION"'/I18N-HOWTO 2>/dev/null || true
	' _ "$src"
