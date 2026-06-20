# 06 — Package Manifest (all 68 spec packages + added build-dependencies)

This manifest is the authoritative map from **every package the subject lists**
(`.specs/packages.md`, in document order) to:

- **Status** — `built` (compiled verbatim), `replaced-by-systemd` (the
  SysVinit-path entry is satisfied by a systemd component — see
  `docs/03-systemd-deviation.md`), or `via` (provided as part of another
  package, e.g. tzdata configured through glibc).
- **Final-system build script** — the per-package script under
  `scripts/final-system/` (naming: `NNN-<slug>.sh`, ordered by the canonical
  systemd-variant build order; agent **A3** authors these). Scripts are
  numbered in steps of 10 so packages can be inserted later without renumbering.
- **Build-log path** — where `run_step`/`build_package` tees that package's
  build output **on the booted/built system**: `/var/log/ft_linux/final/<pkg>.log`.

> The 68 spec entries below are listed in `.specs/packages.md` order (NOT build
> order) so a reviewer can tick straight down the subject's list. The
> "build script" column reflects the canonical build *order* (its `NNN`
> prefix), so the numbers are not monotonic when read top-to-bottom here.
>
> **Note on entry 50.** `.specs/packages.md` prints it verbatim as `Perl)` with
> a trailing parenthesis — a transcription artifact. It is simply **Perl**.

---

## The 68 spec packages (in `.specs/packages.md` order)

| #  | Spec package | Status | Final-system build script | Build log |
|----|--------------|--------|---------------------------|-----------|
| 1  | Acl | built | `scripts/final-system/210-acl.sh` | `/var/log/ft_linux/final/acl.log` |
| 2  | Attr | built | `scripts/final-system/200-attr.sh` | `/var/log/ft_linux/final/attr.log` |
| 3  | Autoconf | built | `scripts/final-system/420-autoconf.sh` | `/var/log/ft_linux/final/autoconf.log` |
| 4  | Automake | built | `scripts/final-system/430-automake.sh` | `/var/log/ft_linux/final/automake.log` |
| 5  | Bash | built | `scripts/final-system/320-bash.sh` | `/var/log/ft_linux/final/bash.log` |
| 6  | Bc | built | `scripts/final-system/110-bc.sh` | `/var/log/ft_linux/final/bc.log` |
| 7  | Binutils | built | `scripts/final-system/160-binutils.sh` | `/var/log/ft_linux/final/binutils.log` |
| 8  | Bison | built | `scripts/final-system/300-bison.sh` | `/var/log/ft_linux/final/bison.log` |
| 9  | Bzip2 | built | `scripts/final-system/050-bzip2.sh` | `/var/log/ft_linux/final/bzip2.log` |
| 10 | Check | built | `scripts/final-system/520-check.sh` | `/var/log/ft_linux/final/check.log` |
| 11 | Coreutils | built | `scripts/final-system/510-coreutils.sh` | `/var/log/ft_linux/final/coreutils.log` |
| 12 | DejaGNU | built | `scripts/final-system/150-dejagnu.sh` | `/var/log/ft_linux/final/dejagnu.log` |
| 13 | Diffutils | built | `scripts/final-system/530-diffutils.sh` | `/var/log/ft_linux/final/diffutils.log` |
| 14 | Eudev | **replaced-by-systemd** → `systemd-udevd` | `scripts/final-system/680-systemd.sh` | `/var/log/ft_linux/final/systemd.log` |
| 15 | E2fsprogs | built | `scripts/final-system/720-e2fsprogs.sh` | `/var/log/ft_linux/final/e2fsprogs.log` |
| 16 | Expat | built | `scripts/final-system/360-expat.sh` | `/var/log/ft_linux/final/expat.log` |
| 17 | Expect | built | `scripts/final-system/140-expect.sh` | `/var/log/ft_linux/final/expect.log` |
| 18 | File | built | `scripts/final-system/080-file.sh` | `/var/log/ft_linux/final/file.log` |
| 19 | Findutils | built | `scripts/final-system/550-findutils.sh` | `/var/log/ft_linux/final/findutils.log` |
| 20 | Flex | built | `scripts/final-system/120-flex.sh` | `/var/log/ft_linux/final/flex.log` |
| 21 | Gawk | built | `scripts/final-system/540-gawk.sh` | `/var/log/ft_linux/final/gawk.log` |
| 22 | GCC | built | `scripts/final-system/240-gcc.sh` | `/var/log/ft_linux/final/gcc.log` |
| 23 | GDBM | built | `scripts/final-system/340-gdbm.sh` | `/var/log/ft_linux/final/gdbm.log` |
| 24 | Gettext | built | `scripts/final-system/290-gettext.sh` | `/var/log/ft_linux/final/gettext.log` |
| 25 | Glibc | built | `scripts/final-system/030-glibc.sh` | `/var/log/ft_linux/final/glibc.log` |
| 26 | GMP | built | `scripts/final-system/170-gmp.sh` | `/var/log/ft_linux/final/gmp.log` |
| 27 | Gperf | built | `scripts/final-system/350-gperf.sh` | `/var/log/ft_linux/final/gperf.log` |
| 28 | Grep | built | `scripts/final-system/310-grep.sh` | `/var/log/ft_linux/final/grep.log` |
| 29 | Groff | built | `scripts/final-system/560-groff.sh` | `/var/log/ft_linux/final/groff.log` |
| 30 | GRUB | built | `scripts/final-system/570-grub.sh` | `/var/log/ft_linux/final/grub.log` |
| 31 | Gzip | built | `scripts/final-system/580-gzip.sh` | `/var/log/ft_linux/final/gzip.log` |
| 32 | Iana-Etc | built | `scripts/final-system/020-iana-etc.sh` | `/var/log/ft_linux/final/iana-etc.log` |
| 33 | Inetutils | built | `scripts/final-system/370-inetutils.sh` | `/var/log/ft_linux/final/inetutils.log` |
| 34 | Intltool | built | `scripts/final-system/410-intltool.sh` | `/var/log/ft_linux/final/intltool.log` |
| 35 | IPRoute2 | built | `scripts/final-system/590-iproute2.sh` | `/var/log/ft_linux/final/iproute2.log` |
| 36 | Kbd | built | `scripts/final-system/600-kbd.sh` | `/var/log/ft_linux/final/kbd.log` |
| 37 | Kmod | built | `scripts/final-system/450-kmod.sh` | `/var/log/ft_linux/final/kmod.log` |
| 38 | Less | built | `scripts/final-system/380-less.sh` | `/var/log/ft_linux/final/less.log` |
| 39 | Libcap | built | `scripts/final-system/220-libcap.sh` | `/var/log/ft_linux/final/libcap.log` |
| 40 | Libpipeline | built | `scripts/final-system/610-libpipeline.sh` | `/var/log/ft_linux/final/libpipeline.log` |
| 41 | Libtool | built | `scripts/final-system/330-libtool.sh` | `/var/log/ft_linux/final/libtool.log` |
| 42 | M4 | built | `scripts/final-system/100-m4.sh` | `/var/log/ft_linux/final/m4.log` |
| 43 | Make | built | `scripts/final-system/620-make.sh` | `/var/log/ft_linux/final/make.log` |
| 44 | Man-DB | built | `scripts/final-system/700-man-db.sh` | `/var/log/ft_linux/final/man-db.log` |
| 45 | Man-pages | built | `scripts/final-system/010-man-pages.sh` | `/var/log/ft_linux/final/man-pages.log` |
| 46 | MPC | built | `scripts/final-system/190-mpc.sh` | `/var/log/ft_linux/final/mpc.log` |
| 47 | MPFR | built | `scripts/final-system/180-mpfr.sh` | `/var/log/ft_linux/final/mpfr.log` |
| 48 | Ncurses | built | `scripts/final-system/260-ncurses.sh` | `/var/log/ft_linux/final/ncurses.log` |
| 49 | Patch | built | `scripts/final-system/630-patch.sh` | `/var/log/ft_linux/final/patch.log` |
| 50 | Perl *(printed `Perl)` — transcription artifact)* | built | `scripts/final-system/390-perl.sh` | `/var/log/ft_linux/final/perl.log` |
| 51 | Pkg-config | built | `scripts/final-system/250-pkgconf.sh` | `/var/log/ft_linux/final/pkg-config.log` |
| 52 | Procps | built (Procps-ng) | `scripts/final-system/710-procps-ng.sh` | `/var/log/ft_linux/final/procps-ng.log` |
| 53 | Psmisc | built | `scripts/final-system/280-psmisc.sh` | `/var/log/ft_linux/final/psmisc.log` |
| 54 | Readline | built | `scripts/final-system/090-readline.sh` | `/var/log/ft_linux/final/readline.log` |
| 55 | Sed | built | `scripts/final-system/270-sed.sh` | `/var/log/ft_linux/final/sed.log` |
| 56 | Shadow | built | `scripts/final-system/230-shadow.sh` | `/var/log/ft_linux/final/shadow.log` |
| 57 | Sysklogd | **replaced-by-systemd** → `systemd-journald` | `scripts/final-system/680-systemd.sh` | `/var/log/ft_linux/final/systemd.log` |
| 58 | Sysvinit | **replaced-by-systemd** → `systemd` (PID 1) | `scripts/final-system/680-systemd.sh` | `/var/log/ft_linux/final/systemd.log` |
| 59 | Tar | built | `scripts/final-system/640-tar.sh` | `/var/log/ft_linux/final/tar.log` |
| 60 | Tcl | built | `scripts/final-system/130-tcl.sh` | `/var/log/ft_linux/final/tcl.log` |
| 61 | Texinfo | built | `scripts/final-system/650-texinfo.sh` | `/var/log/ft_linux/final/texinfo.log` |
| 62 | Time Zone Data | **via** Glibc (tzdata configured during glibc/locale setup) | `scripts/final-system/030-glibc.sh` + `scripts/system-config/*` (timezone) | `/var/log/ft_linux/final/glibc.log` |
| 63 | Udev-lfs Tarball | **replaced-by-systemd** → udev rules ship with systemd | `scripts/final-system/680-systemd.sh` | `/var/log/ft_linux/final/systemd.log` |
| 64 | Util-linux | built | `scripts/final-system/660-util-linux.sh` | `/var/log/ft_linux/final/util-linux.log` |
| 65 | Vim | built | `scripts/final-system/730-vim.sh` | `/var/log/ft_linux/final/vim.log` |
| 66 | XML::Parser | built (Perl module) | `scripts/final-system/400-xml-parser.sh` | `/var/log/ft_linux/final/xml-parser.log` |
| 67 | Xz Utils | built | `scripts/final-system/060-xz.sh` | `/var/log/ft_linux/final/xz.log` |
| 68 | Zlib | built | `scripts/final-system/040-zlib.sh` | `/var/log/ft_linux/final/zlib.log` |

**Coverage:** 68/68 spec entries. 64 built verbatim, 1 provided via glibc
(Time Zone Data), 3 SysVinit-path entries replaced by systemd components
(Eudev, Sysklogd, Sysvinit), and Udev-lfs Tarball replaced by systemd's udev
rules — 4 substitutions total, all documented in `docs/03-systemd-deviation.md`.

---

## Added build-dependencies (NOT in the spec's 68 — required by the systemd variant)

The systemd variant of LFS requires several packages the subject does not list.
They are **build-dependencies, added** so that systemd, D-Bus, the kernel and
the build system can be built. They are not part of the graded package list but
are present on the final system.

| Added package | Why it is needed | Final-system build script | Build log |
|---|---|---|---|
| Zstd | Compression for kernel/initramfs and systemd | `scripts/final-system/070-zstd.sh` | `/var/log/ft_linux/final/zstd.log` |
| OpenSSL | TLS for systemd, D-Bus and HTTPS source fetches | `scripts/final-system/440-openssl.sh` | `/var/log/ft_linux/final/openssl.log` |
| Elfutils | `libelf` for systemd and the kernel | `scripts/final-system/460-elfutils.sh` | `/var/log/ft_linux/final/elfutils.log` |
| Libffi | Foreign-function interface for Python / gobject | `scripts/final-system/470-libffi.sh` | `/var/log/ft_linux/final/libffi.log` |
| Ninja | Build backend for Meson/systemd | `scripts/final-system/490-ninja.sh` | `/var/log/ft_linux/final/ninja.log` |
| Meson | Build system used by systemd | `scripts/final-system/500-meson.sh` | `/var/log/ft_linux/final/meson.log` |
| D-Bus | System message bus required by systemd | `scripts/final-system/670-dbus.sh` | `/var/log/ft_linux/final/dbus.log` |
| systemd | The init system / udev / journald (replaces 4 spec entries) | `scripts/final-system/680-systemd.sh` | `/var/log/ft_linux/final/systemd.log` |
| systemd-man-pages | Man pages for systemd (LFS companion tarball) | `scripts/final-system/690-systemd-man-pages.sh` | `/var/log/ft_linux/final/systemd-man-pages.log` |

> **Python** is also built (`scripts/final-system/480-python.sh`) as a runtime
> dependency of Meson; it is required by the systemd build chain. It is listed
> here for completeness as part of the added systemd-variant toolchain.

---

## Cross-references

- Per-package build order is also enumerated in
  `scripts/final-system/_order.txt` (authored by **A3**); this manifest and that
  file must agree on the `NNN-<slug>.sh` names.
- Each package's presence on the booted system is independently re-checked by
  `verify/verify.sh` `chk_packages` (requirement **R15**).
- Substitution rationale: `docs/03-systemd-deviation.md`.
- Toolchain/temp-tools passes (Ch.5–7) reuse several of these tarballs before
  the final system; see `scripts/toolchain/*` and `scripts/temp-tools/*`.

---

Related: `verify/compliance-checklist.md`, `verify/verify.sh`,
`docs/03-systemd-deviation.md`, `.specs/packages.md`.
