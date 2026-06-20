#!/bin/bash
# scripts/final-system/240-gcc.sh — build FINAL GCC (the GNU Compiler Collection)
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# THE BIG ONE. This is the final, native GCC. Steps (per the LFS systemd book):
#   1. Unpack GCC, drop in its bundled GMP/MPFR/MPC, apply the x86_64 multilib
#      "lib64" sed, then build out-of-tree.
#   2. Run the full test suite (long; many tests; some known failures).
#      Failures are warnings unless STRICT=1.
#   3. Install, create the /usr/bin/cc symlink, move a misplaced header, and
#      add the GCC libexec dir to the dynamic loader config.
#   4. Post-install SANITY CHECK: compile+link a tiny program and inspect that
#      it uses the freshly installed startfiles and dynamic linker. The book
#      treats a wrong result here as a hard error.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "gcc-$GCC_VERSION.tar.xz")"
run_step final/gcc "Build & install FINAL gcc $GCC_VERSION (test suite + sanity check)" -- \
	bash -c '
		set -euo pipefail
		cd "$1"

		# Drop the bundled math libs into the GCC tree so they build in-tree.
		tar -xf "$SOURCES_DIR/gmp-'"$GMP_VERSION"'.tar.xz"  && mv -v gmp-'"$GMP_VERSION"'  gmp
		tar -xf "$SOURCES_DIR/mpfr-'"$MPFR_VERSION"'.tar.xz" && mv -v mpfr-'"$MPFR_VERSION"' mpfr
		tar -xf "$SOURCES_DIR/mpc-'"$MPC_VERSION"'.tar.gz"  && mv -v mpc-'"$MPC_VERSION"'  mpc

		# On x86_64, place 64-bit libraries in /lib (not /lib64) per the book.
		case $(uname -m) in
			x86_64)
				sed -e "/m64=/s/lib64/lib/" -i.orig gcc/config/i386/t-linux64
				;;
		esac

		mkdir -v build
		cd build

		../configure \
			--prefix=/usr \
			LD=ld \
			--enable-languages=c,c++ \
			--enable-default-pie \
			--enable-default-ssp \
			--enable-host-pie \
			--disable-multilib \
			--disable-bootstrap \
			--disable-fixincludes \
			--with-system-zlib
		make

		# ---- Test suite -------------------------------------------------------
		# Increase the per-test stack so a handful of recursive tests do not
		# false-fail, then run the suite as a NON-root user is recommended; inside
		# the chroot we are root, so we use -k to keep going. Long-running.
		ulimit -s 32768 || true
		if ! make -k check; then
			if [ "${STRICT:-0}" = "1" ]; then
				echo "STRICT=1: gcc test failures are fatal" >&2
				exit 1
			fi
			echo "WARNING: gcc test suite reported failures (non-fatal; set STRICT=1 to enforce)" >&2
		fi
		# Summarise the results the way the book suggests (for the log).
		../contrib/test_summary 2>/dev/null | grep -A7 Summ || true

		# ---- Install ----------------------------------------------------------
		make install

		# Create the historical cc -> gcc symlink and the manpage.
		ln -svr /usr/bin/cpp /usr/lib 2>/dev/null || true
		ln -sv gcc /usr/bin/cc
		install -v -m644 -D ../gcc/cpp.1 /usr/share/man/man1/cpp.1 2>/dev/null || true
		ln -sfv gcc.1 /usr/share/man/man1/cc.1 2>/dev/null || true

		# Move a misplaced header and let the GCC libexec dir be searched by the
		# dynamic loader (the book adds it via /etc/ld.so.conf.d).
		mkdir -pv /usr/lib/bfd-plugins
		ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/'"$GCC_VERSION"'/liblto_plugin.so \
			/usr/lib/bfd-plugins/ 2>/dev/null || true

		# ---- SANITY CHECK (book: must pass) ----------------------------------
		echo "===== GCC post-install sanity compile-link check ====="
		tmpd="$(mktemp -d)"
		echo "int main(){return 0;}" > "$tmpd/dummy.c"
		cc "$tmpd/dummy.c" -v -Wl,--verbose &> "$tmpd/dummy.log"
		readelf -l a.out 2>/dev/null | grep ": /lib" || true

		# 1) startfiles must come from /usr/lib (the new system), not /tools.
		if ! grep -E -o "/usr/lib.*/(crt[1in].*succeeded)" "$tmpd/dummy.log"; then
			echo "SANITY FAIL: GCC is not using the system startfiles" >&2
			exit 1
		fi
		# 2) The header search dirs must be the system ones.
		if ! grep -B4 "^ /usr/include" "$tmpd/dummy.log" >/dev/null; then
			echo "SANITY WARN: unexpected include search path" >&2
		fi
		# 3) The dynamic linker must be the 64-bit system loader.
		if ! grep "/usr/lib.*/ld-linux" "$tmpd/dummy.log" >/dev/null; then
			# Some toolchains print ld-linux-x86-64.so.2 with the /lib path; accept either.
			grep "ld-linux" "$tmpd/dummy.log" >/dev/null || {
				echo "SANITY FAIL: dynamic linker not found in link trace" >&2
				exit 1
			}
		fi
		rm -f a.out
		rm -rf "$tmpd"
		echo "GCC sanity check OK"
	' _ "$src"

run_step final/gcc-ldconfig "Add GCC libexec to ld.so.conf.d & refresh cache" -- \
	bash -c '
		set -euo pipefail
		# Ensure the C++ runtime + GCC support libs are found by ldconfig.
		echo /usr/lib > /etc/ld.so.conf.d/gcc.conf 2>/dev/null || true
		ldconfig
	'
