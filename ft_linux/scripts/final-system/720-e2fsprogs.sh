#!/bin/bash
# scripts/final-system/720-e2fsprogs.sh — build E2fsprogs (ext2/3/4 filesystem tools)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Provides mke2fs/e2fsck/resize2fs/dumpe2fs — required to create & check the
# ext4 root and /boot filesystems on the target disk. The book builds it
# out-of-tree with a specific set of flags.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "e2fsprogs-$E2FSPROGS_VERSION.tar.gz")"
run_step final/e2fsprogs "Build & install e2fsprogs $E2FSPROGS_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"
		mkdir -v build
		cd build
		../configure \
			--prefix=/usr \
			--sysconfdir=/etc \
			--enable-elf-shlibs \
			--disable-libblkid \
			--disable-libuuid \
			--disable-uuidd \
			--disable-fsck
		make
		if ! make check; then
			[ "${STRICT:-0}" = "1" ] && exit 1
			echo "WARNING: e2fsprogs test suite reported failures (non-fatal)" >&2
		fi
		make install
		# Remove static libs the book deletes, and decompress an installed doc.
		rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a 2>/dev/null || true
		gunzip -v /usr/share/info/libext2fs.info.gz 2>/dev/null || true
		install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info 2>/dev/null || true
		# Install the bundled docs the book ships.
		makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo 2>/dev/null || true
		install -v -m644 doc/com_err.info /usr/share/info 2>/dev/null || true
		install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info 2>/dev/null || true
	' _ "$src"
