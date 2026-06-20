#!/bin/bash
# scripts/final-system/730-vim.sh — build Vim (the text editor)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

# Vim: the book points vimrc at /etc, builds with the system ncurses, then
# creates the vi compatibility symlink and a minimal /etc/vimrc. Drive manually
# so we can do the pre-configure sed + post-install steps.
src="$(extract_only "vim-$VIM_VERSION.tar.gz")"
run_step final/vim "Build & install vim $VIM_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		# Place the system vimrc in /etc rather than /usr/share/vim.
		echo "#define SYS_VIMRC_FILE \"/etc/vimrc\"" >> src/feature.h

		./configure --prefix=/usr \
			--with-features=huge \
			--enable-gui=no \
			--without-x \
			--disable-gtktest
		make

		# The Vim test suite is long and needs a tty; the book marks it optional.
		if [ "${STRICT:-0}" = "1" ]; then
			LANG=en_US.UTF-8 make -j1 test || echo "WARNING: vim tests reported failures" >&2
		fi

		make install

		# Create the customary symlinks for vi and friends.
		ln -sfv vim /usr/bin/vi
		for L in /usr/share/man/{,*/}man1/vim.1; do
			ln -sfv vim.1 "$(dirname "$L")/vi.1" 2>/dev/null || true
		done
		ln -sfv ../vim/vim'"$(echo "$VIM_VERSION" | tr -d ".")"'/doc /usr/share/doc/vim-'"$VIM_VERSION"' 2>/dev/null || true

		# Minimal, sane default /etc/vimrc.
		cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc — default ft_linux vim configuration

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
	' _ "$src"
