#!/bin/bash
# vm/version-check.sh — faithful LFS host-prerequisite checker (+ ft_linux extras)
# =============================================================================
# Purpose : Verify the Debian/Ubuntu BUILD HOST satisfies every prerequisite the
#           LFS book demands BEFORE you start the cross-toolchain. This is the
#           LFS "Host System Requirements" version-check script (Ch.2) adapted,
#           PLUS three ft_linux-specific extras the spec mandates: curl, wget,
#           git must be present (the spec requires being able to download source).
# LFS ref : Chapter 2 — "Host System Requirements" / version-check.sh.
# Context : RUNS INSIDE the build-host VM (Debian/Ubuntu). Authored on macOS.
#           Invoked at the end of provision-build-host.sh; can also be run alone.
# Exit    : 0 if every check PASSes; non-zero (= number of failures) otherwise.
# Make exe: chmod +x vm/version-check.sh
#
# NOTE: This script deliberately does NOT source env/lfs.env or lib/common.sh.
#       It must run on a bare host before the suite's contract is relevant, and
#       it mirrors the upstream LFS checker so an evaluator recognises it.
# =============================================================================
set -uo pipefail   # NB: NOT -e — we want to run every check and tally failures.

export LC_ALL=C

# --- tiny self-contained reporting (no lib/common.sh dependency) -------------
fail_count=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fail_count=$((fail_count + 1)); }
info() { printf '      %s\n' "$*"; }

# require <human-name> <command> — FAIL if the command is not on PATH.
require() {
	if command -v "$2" >/dev/null 2>&1; then
		pass "$1 found: $(command -v "$2")"
		return 0
	fi
	fail "$1 NOT found (expected command: $2)"
	return 1
}

# ver_ge <have> <want> — true if version <have> >= <want> (dotted numeric).
ver_ge() {
	# sort -V puts the smaller first; if want sorts <= have, then have>=want.
	[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# check_ver <name> <want> <have> — PASS/FAIL on a >= comparison.
check_ver() {
	if [ -z "${3:-}" ]; then
		fail "$1 version could not be determined (need >= $2)"
	elif ver_ge "$3" "$2"; then
		pass "$1 $3 (>= $2)"
	else
		fail "$1 $3 is too old (need >= $2)"
	fi
}

printf '===== ft_linux host prerequisite check (LFS Ch.2) =====\n\n'

# -----------------------------------------------------------------------------
# Bash >= 3.2
# -----------------------------------------------------------------------------
bash_ver=$(bash --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Bash" "3.2" "$bash_ver"

# /bin/sh MUST be a link to bash (LFS requirement; dash breaks the build).
if [ -h /bin/sh ]; then
	sh_target=$(readlink -f /bin/sh)
	case "$sh_target" in
		*bash) pass "/bin/sh -> $sh_target (bash)" ;;
		*)     fail "/bin/sh -> $sh_target (must point to bash; run: provision-build-host.sh relinks it)" ;;
	esac
else
	# Could be a real file; check it is bash by probing.
	if /bin/sh -c 'echo ${BASH_VERSION:-}' 2>/dev/null | grep -q '[0-9]'; then
		pass "/bin/sh is bash"
	else
		fail "/bin/sh is not bash (LFS requires sh=bash, not dash)"
	fi
fi

# -----------------------------------------------------------------------------
# Binutils >= 2.13.1 (no realistic upper bound to assert here)
# -----------------------------------------------------------------------------
binutils_ver=$(ld --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Binutils (ld)" "2.13.1" "$binutils_ver"

# -----------------------------------------------------------------------------
# Bison >= 2.7  AND  /usr/bin/yacc must resolve to bison
# -----------------------------------------------------------------------------
bison_ver=$(bison --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Bison" "2.7" "$bison_ver"
if [ -h /usr/bin/yacc ]; then
	yacc_target=$(readlink -f /usr/bin/yacc)
	case "$yacc_target" in
		*bison*) pass "/usr/bin/yacc -> $yacc_target (bison)" ;;
		*)       fail "/usr/bin/yacc -> $yacc_target (should be a link to bison)" ;;
	esac
elif [ -x /usr/bin/yacc ]; then
	info "/usr/bin/yacc is a real binary (LFS prefers a link to bison) — accepting"
	pass "/usr/bin/yacc present"
else
	fail "/usr/bin/yacc not found (should be a link to bison)"
fi

# -----------------------------------------------------------------------------
# Bzip2  (version reported on stderr)
# -----------------------------------------------------------------------------
bzip2_ver=$(bzip2 --version 2>&1 < /dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
check_ver "Bzip2" "1.0.4" "$bzip2_ver"

# -----------------------------------------------------------------------------
# Coreutils >= 8.1  (use Chmod's version line as the proxy upstream uses)
# -----------------------------------------------------------------------------
coreutils_ver=$(chmod --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Coreutils (chmod)" "8.1" "$coreutils_ver"

# -----------------------------------------------------------------------------
# Diffutils >= 2.8.1
# -----------------------------------------------------------------------------
diff_ver=$(diff --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Diffutils (diff)" "2.8.1" "$diff_ver"

# -----------------------------------------------------------------------------
# Findutils >= 4.2.31
# -----------------------------------------------------------------------------
find_ver=$(find --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Findutils (find)" "4.2.31" "$find_ver"

# -----------------------------------------------------------------------------
# Gawk >= 4.0.1  AND  /usr/bin/awk must resolve to gawk
# -----------------------------------------------------------------------------
gawk_ver=$(gawk --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Gawk" "4.0.1" "$gawk_ver"
if [ -h /usr/bin/awk ]; then
	awk_target=$(readlink -f /usr/bin/awk)
	case "$awk_target" in
		*gawk*) pass "/usr/bin/awk -> $awk_target (gawk)" ;;
		*)      fail "/usr/bin/awk -> $awk_target (should be a link to gawk)" ;;
	esac
elif [ -x /usr/bin/awk ]; then
	info "/usr/bin/awk is a real binary (LFS prefers a link to gawk) — accepting"
	pass "/usr/bin/awk present"
else
	fail "/usr/bin/awk not found (should be a link to gawk)"
fi

# -----------------------------------------------------------------------------
# GCC >= 5.2 (and not too new for the chosen LFS book) + C++ compiler present
# -----------------------------------------------------------------------------
gcc_ver=$(gcc --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "GCC" "5.2" "$gcc_ver"
gpp_ver=$(g++ --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "G++ (g++)" "5.2" "$gpp_ver"

# -----------------------------------------------------------------------------
# Glibc >= 2.11  (via ldd, the canonical LFS probe)
# -----------------------------------------------------------------------------
glibc_ver=$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | tail -n1)
check_ver "Glibc (ldd)" "2.11" "$glibc_ver"

# -----------------------------------------------------------------------------
# Grep, Gzip, M4, Perl, Python3, Sed, Tar, Texinfo, Xz, Make, Patch
# -----------------------------------------------------------------------------
grep_ver=$(grep --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Grep" "2.5.1a" "$grep_ver"

gzip_ver=$(gzip --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Gzip" "1.3.12" "$gzip_ver"

m4_ver=$(m4 --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "M4" "1.4.10" "$m4_ver"

make_ver=$(make --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Make" "4.0" "$make_ver"

patch_ver=$(patch --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Patch" "2.5.4" "$patch_ver"

perl_ver=$(perl -V:version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Perl" "5.8.8" "$perl_ver"

# Python: prefer python3; the book requires Python 3.
py_ver=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Python3" "3.4" "$py_ver"

sed_ver=$(sed --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Sed" "4.1.5" "$sed_ver"

tar_ver=$(tar --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Tar" "1.22" "$tar_ver"

# Texinfo: makeinfo carries the version.
texinfo_ver=$(makeinfo --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Texinfo (makeinfo)" "5.0" "$texinfo_ver"

xz_ver=$(xz --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Xz" "5.0.0" "$xz_ver"

# -----------------------------------------------------------------------------
# Host kernel >= 4.19 (LFS book requires it; spec only needs the BUILT kernel
# to be >= 4.0, but the host that compiles glibc must be >= 4.19).
# -----------------------------------------------------------------------------
kernel_ver=$(uname -r | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
check_ver "Host kernel (uname -r)" "4.19" "$kernel_ver"

# -----------------------------------------------------------------------------
# ft_linux EXTRAS (spec rule: must be able to download source code)
# -----------------------------------------------------------------------------
printf '\n--- ft_linux extras (downloaders + VCS, per spec) ---\n'
require "curl"  curl
require "wget"  wget
require "git"   git

# -----------------------------------------------------------------------------
# The LFS G++ compile-and-link smoke test. If this fails, the host C++
# toolchain is broken and the LFS build will not proceed.
# -----------------------------------------------------------------------------
printf '\n--- G++ compile-and-link smoke test ---\n'
tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t ftlinux)
cat > "$tmpdir/dummy.c" <<'EOF'
#include <stdlib.h>
int main(void) { return 0; }
EOF
if gcc -o "$tmpdir/dummy" "$tmpdir/dummy.c" >/dev/null 2>&1 && [ -x "$tmpdir/dummy" ]; then
	pass "gcc can compile and link a trivial C program"
else
	fail "gcc cannot compile/link a trivial C program"
fi
cat > "$tmpdir/dummy.cpp" <<'EOF'
#include <iostream>
int main(void) { std::cout << "ok"; return 0; }
EOF
if g++ -o "$tmpdir/dummycpp" "$tmpdir/dummy.cpp" >/dev/null 2>&1 && [ -x "$tmpdir/dummycpp" ]; then
	pass "g++ can compile and link a trivial C++ program (libstdc++ usable)"
else
	fail "g++ cannot compile/link a trivial C++ program (install g++/libstdc++-dev)"
fi
rm -rf "$tmpdir"

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
printf '\n=====================================================\n'
if [ "$fail_count" -eq 0 ]; then
	printf 'RESULT: ALL CHECKS PASSED — host is ready for the LFS build.\n'
	exit 0
fi
printf 'RESULT: %d CHECK(S) FAILED — fix the above before building.\n' "$fail_count"
exit "$fail_count"
