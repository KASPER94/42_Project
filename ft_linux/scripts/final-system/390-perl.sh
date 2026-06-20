#!/bin/bash
# scripts/final-system/390-perl.sh — build FINAL Perl
# LFS Ch.8 final system, runs as root inside chroot.
# Authored on macOS; the user RUNS this inside the build VM (in chroot). chmod +x.
#
# Perl uses its own Configure script (not autotools). The book points it at the
# already-installed system libraries (zlib, bzip2, gdbm) so the bundled copies
# are not used, and sets the install paths explicitly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -f "$REPO_ROOT/env/lfs.env" ]; do REPO_ROOT="$(dirname "$REPO_ROOT")"; done
source "$REPO_ROOT/env/lfs.env"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/package.sh"

src="$(extract_only "perl-$PERL_VERSION.tar.xz")"
run_step final/perl "Build & install FINAL perl $PERL_VERSION" -- \
	bash -c '
		set -euo pipefail
		cd "$1"

		# Tell Compress::Raw::Zlib / ::Bzip2 to use the system libraries.
		export BUILD_ZLIB=False
		export BUILD_BZIP2=0

		sh Configure -des \
			-Dprefix=/usr \
			-Dvendorprefix=/usr \
			-Dprivlib=/usr/lib/perl5/'"${PERL_VERSION%.*}"'/core_perl \
			-Darchlib=/usr/lib/perl5/'"${PERL_VERSION%.*}"'/core_perl \
			-Dsitelib=/usr/lib/perl5/'"${PERL_VERSION%.*}"'/site_perl \
			-Dsitearch=/usr/lib/perl5/'"${PERL_VERSION%.*}"'/site_perl \
			-Dvendorlib=/usr/lib/perl5/'"${PERL_VERSION%.*}"'/vendor_perl \
			-Dvendorarch=/usr/lib/perl5/'"${PERL_VERSION%.*}"'/vendor_perl \
			-Dman1dir=/usr/share/man/man1 \
			-Dman3dir=/usr/share/man/man3 \
			-Dpager="/usr/bin/less -isR" \
			-Duseshrplib \
			-Dusethreads
		make

		# The full Perl test suite is long; the book marks it optional.
		if [ "${STRICT:-0}" = "1" ]; then
			make test
		fi

		make install
	' _ "$src"
