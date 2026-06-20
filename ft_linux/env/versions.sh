# shellcheck shell=bash
#
# env/versions.sh — pinned package versions and download URLs
# =============================================================================
# Single source of truth for EVERY version number and source URL in ft_linux.
# Sourced (indirectly) by every build script via env/lfs.env.
#
# CONVENTION
#   <PKG>_VERSION   the exact version string (e.g. 6.13.4)
#   <PKG>_URL       the full download URL for the source tarball
#   (some packages also expose <PKG>_TARBALL when the filename is irregular)
#
# IMPORTANT
#   * KERNEL_VERSION is defined EXACTLY ONCE. The kernel binary name
#     (/boot/vmlinuz-${KERNEL_VERSION}-${LFS_USER_LOGIN}), the source dir
#     (/usr/src/kernel-${KERNEL_VERSION}) and grub.cfg all derive from it.
#   * Versions are pinned to a coherent, mutually-compatible set matching a
#     recent LFS 12.x *systemd* book. Where an exact patch level could not be
#     confirmed offline it carries a "# verify against LFS book" note; the
#     downloader (sources/) checks md5sums so a wrong patch fails loudly.
#   * Do NOT hardcode versions anywhere else — derive from these variables.
# =============================================================================

# Convenience mirrors (kept as variables so a mirror swap is one-line).
GNU_MIRROR="https://ftp.gnu.org/gnu"
SOURCEFORGE="https://downloads.sourceforge.net"
KERNEL_MIRROR="https://www.kernel.org/pub/linux"

# -----------------------------------------------------------------------------
# Kernel  (LFS Ch.10) — defined ONCE, drives the spec-critical naming rules
# -----------------------------------------------------------------------------
KERNEL_VERSION=6.13.4                                  # verify against LFS book; >= 4.0 required by spec
KERNEL_URL="${KERNEL_MIRROR}/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"

# -----------------------------------------------------------------------------
# Cross-toolchain  (LFS Ch.5) — Binutils, GCC + its math libs, kernel headers,
# Glibc. These are the SAME tarballs reused for the final-system passes.
# -----------------------------------------------------------------------------
BINUTILS_VERSION=2.44
BINUTILS_URL="${GNU_MIRROR}/binutils/binutils-${BINUTILS_VERSION}.tar.xz"

GCC_VERSION=14.2.0
GCC_URL="${GNU_MIRROR}/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"

# GCC bundled math libraries (extracted into the GCC tree before pass1).
GMP_VERSION=6.3.0
GMP_URL="${GNU_MIRROR}/gmp/gmp-${GMP_VERSION}.tar.xz"

MPFR_VERSION=4.2.1
MPFR_URL="${GNU_MIRROR}/mpfr/mpfr-${MPFR_VERSION}.tar.xz"

MPC_VERSION=1.3.1
MPC_URL="${GNU_MIRROR}/mpc/mpc-${MPC_VERSION}.tar.gz"

GLIBC_VERSION=2.41
GLIBC_URL="${GNU_MIRROR}/glibc/glibc-${GLIBC_VERSION}.tar.xz"

# -----------------------------------------------------------------------------
# Temporary tools  (LFS Ch.6) — reuse many tarballs above plus the below.
# -----------------------------------------------------------------------------
M4_VERSION=1.4.19
M4_URL="${GNU_MIRROR}/m4/m4-${M4_VERSION}.tar.xz"

NCURSES_VERSION=6.5
NCURSES_URL="${GNU_MIRROR}/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"

BASH_VERSION_LFS=5.2.37                                 # NB: not BASH_VERSION (a reserved bash var)
BASH_URL="${GNU_MIRROR}/bash/bash-${BASH_VERSION_LFS}.tar.gz"

COREUTILS_VERSION=9.6
COREUTILS_URL="${GNU_MIRROR}/coreutils/coreutils-${COREUTILS_VERSION}.tar.xz"

DIFFUTILS_VERSION=3.11
DIFFUTILS_URL="${GNU_MIRROR}/diffutils/diffutils-${DIFFUTILS_VERSION}.tar.xz"

FILE_VERSION=5.46
FILE_URL="https://astron.com/pub/file/file-${FILE_VERSION}.tar.gz"

FINDUTILS_VERSION=4.10.0
FINDUTILS_URL="${GNU_MIRROR}/findutils/findutils-${FINDUTILS_VERSION}.tar.xz"

GAWK_VERSION=5.3.1
GAWK_URL="${GNU_MIRROR}/gawk/gawk-${GAWK_VERSION}.tar.xz"

GREP_VERSION=3.11
GREP_URL="${GNU_MIRROR}/grep/grep-${GREP_VERSION}.tar.xz"

GZIP_VERSION=1.13
GZIP_URL="${GNU_MIRROR}/gzip/gzip-${GZIP_VERSION}.tar.xz"

MAKE_VERSION=4.4.1
MAKE_URL="${GNU_MIRROR}/make/make-${MAKE_VERSION}.tar.gz"

PATCH_VERSION=2.7.6
PATCH_URL="${GNU_MIRROR}/patch/patch-${PATCH_VERSION}.tar.xz"

SED_VERSION=4.9
SED_URL="${GNU_MIRROR}/sed/sed-${SED_VERSION}.tar.xz"

TAR_VERSION=1.35
TAR_URL="${GNU_MIRROR}/tar/tar-${TAR_VERSION}.tar.xz"

XZ_VERSION=5.6.4
XZ_URL="${SOURCEFORGE}/lzmautils/xz-${XZ_VERSION}.tar.xz"

# -----------------------------------------------------------------------------
# Final system  (LFS Ch.8) — packages not already declared above.
# Spec packages + systemd-variant build deps. Grouped roughly by build order.
# -----------------------------------------------------------------------------
MAN_PAGES_VERSION=6.9.1
MAN_PAGES_URL="${KERNEL_MIRROR}/docs/man-pages/man-pages-${MAN_PAGES_VERSION}.tar.xz"

IANA_ETC_VERSION=20250123                               # date-based; verify against LFS book
IANA_ETC_URL="https://github.com/Mic92/iana-etc/releases/download/${IANA_ETC_VERSION}/iana-etc-${IANA_ETC_VERSION}.tar.gz"

ZLIB_VERSION=1.3.1
ZLIB_URL="https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"

BZIP2_VERSION=1.0.8
BZIP2_URL="https://www.sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz"

# zstd: build-dependency added for the systemd variant (kernel/initramfs + systemd).
ZSTD_VERSION=1.5.6
ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz"

READLINE_VERSION=8.2.13
READLINE_URL="${GNU_MIRROR}/readline/readline-${READLINE_VERSION}.tar.gz"

BC_VERSION=7.0.3
BC_URL="https://github.com/gavinhoward/bc/releases/download/${BC_VERSION}/bc-${BC_VERSION}.tar.xz"

FLEX_VERSION=2.6.4
FLEX_URL="https://github.com/westes/flex/releases/download/v${FLEX_VERSION}/flex-${FLEX_VERSION}.tar.gz"

TCL_VERSION=8.6.16
TCL_URL="${SOURCEFORGE}/tcl/tcl${TCL_VERSION}-src.tar.gz"

EXPECT_VERSION=5.45.4
EXPECT_URL="${SOURCEFORGE}/expect/expect${EXPECT_VERSION}.tar.gz"

DEJAGNU_VERSION=1.6.3
DEJAGNU_URL="${GNU_MIRROR}/dejagnu/dejagnu-${DEJAGNU_VERSION}.tar.gz"

ATTR_VERSION=2.5.2
ATTR_URL="${GNU_MIRROR}/../nongnu/attr/attr-${ATTR_VERSION}.tar.gz"   # nongnu mirror; verify against LFS book

ACL_VERSION=2.3.2
ACL_URL="${GNU_MIRROR}/../nongnu/acl/acl-${ACL_VERSION}.tar.xz"       # nongnu mirror; verify against LFS book

LIBCAP_VERSION=2.73
LIBCAP_URL="${KERNEL_MIRROR}/libs/security/linux-privs/libcap2/libcap-${LIBCAP_VERSION}.tar.xz"

SHADOW_VERSION=4.17.3
SHADOW_URL="https://github.com/shadow-maint/shadow/releases/download/${SHADOW_VERSION}/shadow-${SHADOW_VERSION}.tar.xz"

PKGCONFIG_VERSION=0.29.2
PKGCONFIG_URL="https://pkgconfig.freedesktop.org/releases/pkg-config-${PKGCONFIG_VERSION}.tar.gz"

PSMISC_VERSION=23.7
PSMISC_URL="${SOURCEFORGE}/psmisc/psmisc-${PSMISC_VERSION}.tar.xz"

GETTEXT_VERSION=0.24
GETTEXT_URL="${GNU_MIRROR}/gettext/gettext-${GETTEXT_VERSION}.tar.xz"

BISON_VERSION=3.8.2
BISON_URL="${GNU_MIRROR}/bison/bison-${BISON_VERSION}.tar.xz"

LIBTOOL_VERSION=2.5.4
LIBTOOL_URL="${GNU_MIRROR}/libtool/libtool-${LIBTOOL_VERSION}.tar.xz"

GDBM_VERSION=1.24
GDBM_URL="${GNU_MIRROR}/gdbm/gdbm-${GDBM_VERSION}.tar.gz"

GPERF_VERSION=3.1
GPERF_URL="${GNU_MIRROR}/gperf/gperf-${GPERF_VERSION}.tar.gz"

EXPAT_VERSION=2.6.4
EXPAT_URL="https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-${EXPAT_VERSION}.tar.xz"

INETUTILS_VERSION=2.6
INETUTILS_URL="${GNU_MIRROR}/inetutils/inetutils-${INETUTILS_VERSION}.tar.xz"

LESS_VERSION=668
LESS_URL="${GNU_MIRROR}/less/less-${LESS_VERSION}.tar.gz"

PERL_VERSION=5.40.1
PERL_URL="https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.xz"

XML_PARSER_VERSION=2.47
XML_PARSER_URL="https://cpan.metacpan.org/authors/id/T/TO/TODDR/XML-Parser-${XML_PARSER_VERSION}.tar.gz"

INTLTOOL_VERSION=0.51.0
INTLTOOL_URL="${SOURCEFORGE}/intltool/intltool-${INTLTOOL_VERSION}.tar.gz"

AUTOCONF_VERSION=2.72
AUTOCONF_URL="${GNU_MIRROR}/autoconf/autoconf-${AUTOCONF_VERSION}.tar.xz"

AUTOMAKE_VERSION=1.17
AUTOMAKE_URL="${GNU_MIRROR}/automake/automake-${AUTOMAKE_VERSION}.tar.xz"

# openssl: build-dependency added for the systemd variant (systemd, dbus, https fetch).
OPENSSL_VERSION=3.4.1
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"

# NB: pinned to 33 (the LAST autotools release). kmod >= 34 ships a meson-only
# build, but in the Ch.8 order kmod (450) is built BEFORE ninja(490)/meson(500),
# so meson is not yet available. 33 still provides ./configure, taking the
# autotools path in scripts/final-system/450-kmod.sh. See A8 reconcile note.
KMOD_VERSION=33
KMOD_URL="${KERNEL_MIRROR}/utils/kernel/kmod/kmod-${KMOD_VERSION}.tar.xz"

# elfutils: build-dependency added for the systemd variant (libelf for systemd & kernel).
ELFUTILS_VERSION=0.192
ELFUTILS_URL="https://sourceware.org/elfutils/ftp/${ELFUTILS_VERSION}/elfutils-${ELFUTILS_VERSION}.tar.bz2"

# libffi: build-dependency added for the systemd variant (Python, gobject).
LIBFFI_VERSION=3.4.7
LIBFFI_URL="https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz"

PYTHON_VERSION=3.13.2
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"

# ninja + meson: build-dependency added for the systemd variant (systemd build system).
NINJA_VERSION=1.12.1
NINJA_URL="https://github.com/ninja-build/ninja/archive/v${NINJA_VERSION}/ninja-${NINJA_VERSION}.tar.gz"

MESON_VERSION=1.7.0
MESON_URL="https://github.com/mesonbuild/meson/releases/download/${MESON_VERSION}/meson-${MESON_VERSION}.tar.gz"

CHECK_VERSION=0.15.2
CHECK_URL="https://github.com/libcheck/check/releases/download/${CHECK_VERSION}/check-${CHECK_VERSION}.tar.gz"

GROFF_VERSION=1.23.0
GROFF_URL="${GNU_MIRROR}/groff/groff-${GROFF_VERSION}.tar.gz"

GRUB_VERSION=2.12
GRUB_URL="${GNU_MIRROR}/grub/grub-${GRUB_VERSION}.tar.xz"

IPROUTE2_VERSION=6.13.0
IPROUTE2_URL="${KERNEL_MIRROR}/utils/net/iproute2/iproute2-${IPROUTE2_VERSION}.tar.xz"

KBD_VERSION=2.7.1
KBD_URL="${KERNEL_MIRROR}/utils/kbd/kbd-${KBD_VERSION}.tar.xz"

LIBPIPELINE_VERSION=1.5.8
LIBPIPELINE_URL="https://download.savannah.gnu.org/releases/libpipeline/libpipeline-${LIBPIPELINE_VERSION}.tar.gz"

TEXINFO_VERSION=7.2
TEXINFO_URL="${GNU_MIRROR}/texinfo/texinfo-${TEXINFO_VERSION}.tar.xz"

UTIL_LINUX_VERSION=2.40.4
UTIL_LINUX_URL="${KERNEL_MIRROR}/utils/util-linux/v2.40/util-linux-${UTIL_LINUX_VERSION}.tar.xz"

# dbus: build-dependency added for the systemd variant (system message bus).
DBUS_VERSION=1.16.0
DBUS_URL="https://dbus.freedesktop.org/releases/dbus/dbus-${DBUS_VERSION}.tar.xz"

# systemd: replaces Eudev + Sysvinit + Sysklogd (the spec permits SysV *or* SystemD).
SYSTEMD_VERSION=257.3
SYSTEMD_URL="https://github.com/systemd/systemd/archive/v${SYSTEMD_VERSION}/systemd-${SYSTEMD_VERSION}.tar.gz"

# systemd-man-pages: the man-pages tarball companion shipped by the LFS book.
SYSTEMD_MAN_PAGES_VERSION=${SYSTEMD_VERSION}
SYSTEMD_MAN_PAGES_URL="https://anduin.linuxfromscratch.org/LFS/systemd-man-pages-${SYSTEMD_MAN_PAGES_VERSION}.tar.xz"   # verify against LFS book

MAN_DB_VERSION=2.13.0
MAN_DB_URL="https://download.savannah.gnu.org/releases/man-db/man-db-${MAN_DB_VERSION}.tar.xz"

PROCPS_VERSION=4.0.5
PROCPS_URL="${SOURCEFORGE}/procps-ng/procps-ng-${PROCPS_VERSION}.tar.xz"

E2FSPROGS_VERSION=1.47.2
E2FSPROGS_URL="${SOURCEFORGE}/e2fsprogs/e2fsprogs-${E2FSPROGS_VERSION}.tar.gz"

VIM_VERSION=9.1.1080
VIM_URL="https://github.com/vim/vim/archive/v${VIM_VERSION}/vim-${VIM_VERSION}.tar.gz"

# Time Zone Data (spec #62) — tzdata, consumed by glibc localtime config.
TZDATA_VERSION=2025a
TZDATA_URL="https://www.iana.org/time-zones/repository/releases/tzdata${TZDATA_VERSION}.tar.gz"

# -----------------------------------------------------------------------------
# Export everything declared above so child processes (and `set -a` callers)
# inherit it. We re-export by name to keep the list auditable.
# -----------------------------------------------------------------------------
export GNU_MIRROR SOURCEFORGE KERNEL_MIRROR
export KERNEL_VERSION KERNEL_URL
export BINUTILS_VERSION BINUTILS_URL GCC_VERSION GCC_URL
export GMP_VERSION GMP_URL MPFR_VERSION MPFR_URL MPC_VERSION MPC_URL
export GLIBC_VERSION GLIBC_URL
export M4_VERSION M4_URL NCURSES_VERSION NCURSES_URL
export BASH_VERSION_LFS BASH_URL COREUTILS_VERSION COREUTILS_URL
export DIFFUTILS_VERSION DIFFUTILS_URL FILE_VERSION FILE_URL
export FINDUTILS_VERSION FINDUTILS_URL GAWK_VERSION GAWK_URL
export GREP_VERSION GREP_URL GZIP_VERSION GZIP_URL
export MAKE_VERSION MAKE_URL PATCH_VERSION PATCH_URL
export SED_VERSION SED_URL TAR_VERSION TAR_URL XZ_VERSION XZ_URL
export MAN_PAGES_VERSION MAN_PAGES_URL IANA_ETC_VERSION IANA_ETC_URL
export ZLIB_VERSION ZLIB_URL BZIP2_VERSION BZIP2_URL ZSTD_VERSION ZSTD_URL
export READLINE_VERSION READLINE_URL BC_VERSION BC_URL FLEX_VERSION FLEX_URL
export TCL_VERSION TCL_URL EXPECT_VERSION EXPECT_URL DEJAGNU_VERSION DEJAGNU_URL
export ATTR_VERSION ATTR_URL ACL_VERSION ACL_URL LIBCAP_VERSION LIBCAP_URL
export SHADOW_VERSION SHADOW_URL PKGCONFIG_VERSION PKGCONFIG_URL
export PSMISC_VERSION PSMISC_URL GETTEXT_VERSION GETTEXT_URL
export BISON_VERSION BISON_URL LIBTOOL_VERSION LIBTOOL_URL
export GDBM_VERSION GDBM_URL GPERF_VERSION GPERF_URL EXPAT_VERSION EXPAT_URL
export INETUTILS_VERSION INETUTILS_URL LESS_VERSION LESS_URL
export PERL_VERSION PERL_URL XML_PARSER_VERSION XML_PARSER_URL
export INTLTOOL_VERSION INTLTOOL_URL AUTOCONF_VERSION AUTOCONF_URL
export AUTOMAKE_VERSION AUTOMAKE_URL OPENSSL_VERSION OPENSSL_URL
export KMOD_VERSION KMOD_URL ELFUTILS_VERSION ELFUTILS_URL
export LIBFFI_VERSION LIBFFI_URL PYTHON_VERSION PYTHON_URL
export NINJA_VERSION NINJA_URL MESON_VERSION MESON_URL
export CHECK_VERSION CHECK_URL GROFF_VERSION GROFF_URL GRUB_VERSION GRUB_URL
export IPROUTE2_VERSION IPROUTE2_URL KBD_VERSION KBD_URL
export LIBPIPELINE_VERSION LIBPIPELINE_URL TEXINFO_VERSION TEXINFO_URL
export UTIL_LINUX_VERSION UTIL_LINUX_URL DBUS_VERSION DBUS_URL
export SYSTEMD_VERSION SYSTEMD_URL SYSTEMD_MAN_PAGES_VERSION SYSTEMD_MAN_PAGES_URL
export MAN_DB_VERSION MAN_DB_URL PROCPS_VERSION PROCPS_URL
export E2FSPROGS_VERSION E2FSPROGS_URL VIM_VERSION VIM_URL
export TZDATA_VERSION TZDATA_URL
