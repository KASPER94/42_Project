#!/bin/bash
# =============================================================================
# scripts/toolchain/13-glibc.sh
#   LFS Ch.5 — Glibc (the C library, cross-compiled into $LFS/usr).
#
# PURPOSE   Build Glibc against the just-installed Linux API headers and the
#           GCC-pass1 cross compiler, installing into $LFS (prefix /usr). Steps,
#           per the LFS systemd book:
#             1. Create the loader symlinks the dynamic linker expects:
#                  $LFS/lib64 -> ld-linux-x86-64.so.2
#                  $LFS/lib64 -> ld-lsb-x86-64.so.3   (LSB compatibility name)
#             2. Drop a tiny `configparms` so `rootsbindir` = /usr/sbin.
#             3. Configure cross (--host=$LFS_TGT, headers in $LFS/usr/include).
#             4. make && make DESTDIR=$LFS install.
#             5. Fix the `ldd` hard-coded interpreter path.
#             6. SANITY CHECK: compile+link a tiny program with the cross gcc and
#                confirm the produced binary's program interpreter is the
#                /tools-aware ld-linux. A wrong toolchain fails here, loudly.
#
# RUN AS    the unprivileged `lfs` build user (NOT root), on the build HOST.
#
# DEPENDS   10/11/12 complete (binutils-pass1, gcc-pass1, linux api headers).
#
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

# --- Step 1: create the loader symlinks the x86_64 ABI expects ---------------
# These must exist before glibc is configured/installed. Idempotent: ln -sfv.
run_step "13a-glibc-symlinks" "Glibc loader symlinks (lib64 + ld-lsb)" -- bash -c '
	set -euo pipefail
	case "$(uname -m)" in
		x86_64)
			mkdir -p "$LFS/lib64"
			ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
			ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"
			;;
		i?86)
			ln -sfv ld-linux.so.2     "$LFS/lib/ld-lsb.so.3"
			;;
	esac
'

# --- Steps 2-6: configure / build / install / sanity-check -------------------
# Script-local function handed to run_step (runs IN-PROCESS so extract_only and
# the sourced helpers stay in scope — a `bash -c` child would not see them).
_do_glibc() {
	set -euo pipefail
	local src
	src="$(extract_only "glibc-$GLIBC_VERSION.tar.xz")"
	cd "$src"

	# Out-of-tree build dir.
	rm -rf build
	mkdir -v build
	cd build

	# configparms: install programs into /usr/sbin (not /usr/bin) per the book.
	echo "rootsbindir=/usr/sbin" > configparms

	../configure \
		--prefix=/usr \
		--host="$LFS_TGT" \
		--build="$(../scripts/config.guess)" \
		--enable-kernel=5.4 \
		--with-headers="$LFS/usr/include" \
		--disable-nscd \
		libc_cv_slibdir=/usr/lib

	make
	# DESTDIR redirects the install into the target root.
	make DESTDIR="$LFS" install

	# Fix the hard-coded loader path inside the installed `ldd` script.
	sed "/RTLDLIST=/s@/usr@@g" -i "$LFS/usr/bin/ldd"

	# --- SANITY CHECK (LFS book) -------------------------------------------
	# Build a trivial program with the cross gcc and confirm the resulting
	# binary uses the /lib-rooted dynamic linker we just installed.
	echo "int main(){}" | "$LFS_TGT-gcc" -xc - -o "$LFS/sources/glibc-dummy.out"
	if readelf -l "$LFS/sources/glibc-dummy.out" | grep -q "/lib64/ld-linux-x86-64.so.2"; then
		echo "GLIBC SANITY OK: dynamic linker = /lib64/ld-linux-x86-64.so.2"
	else
		echo "GLIBC SANITY FAILED: unexpected program interpreter:" >&2
		readelf -l "$LFS/sources/glibc-dummy.out" | grep "program interpreter" >&2 || true
		rm -f "$LFS/sources/glibc-dummy.out"
		return 1
	fi
	rm -f "$LFS/sources/glibc-dummy.out"

	cd "$SOURCES_DIR"
	rm -rf "$src"
}

run_step "13-glibc" "Glibc cross-build + sanity check -> $LFS/usr" -- _do_glibc

log_ok "Glibc installed and sanity-checked"
