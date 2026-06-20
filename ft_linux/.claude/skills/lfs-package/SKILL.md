---
name: lfs-package
description: Use when authoring or reviewing an LFS/BLFS package build script for the ft_linux suite. Encodes the canonical build_package contract (extract → configure → make → check → install → log → cleanup), the autotools/cmake/meson/suckless/perl variants, the install-prefix rules, and the pre-finalize checklist. Load this before writing any NN-<pkg>.sh builder.
---

# lfs-package — authoring an ft_linux package build script

Every package in ft_linux is built by a small, uniform script that delegates
the mechanics to `build_package` (defined in `lib/package.sh`). This keeps all
~100 builders consistent, idempotent, and logged. Read this before writing or
reviewing one.

## The `build_package` contract

```
build_package <name> <tarball> [OPTIONS...]
```

- `<name>` — log/idempotency slug. Use the phase-qualified form, e.g.
  `final/ncurses`, `temp/m4`. This is the `lib/state.sh` marker id AND the
  `$FT_LOG_DIR/<name>.log` filename.
- `<tarball>` — archive name relative to `$SOURCES_DIR` (or an absolute path).
  Derive the version from `env/versions.sh`, never hardcode it:
  `"ncurses-$NCURSES_VERSION.tar.gz"`.

Options (any order):

| Option | Meaning |
|---|---|
| `--type=autotools\|cmake\|meson\|make\|perl` | build system (default `autotools`) |
| `--prefix=<dir>` | install prefix (default `/usr`) |
| `--configure-args="…"` | extra args appended to configure/cmake/meson, verbatim |
| `--make-args="…"` | extra args for the build step (make/ninja) |
| `--install-args="…"` | extra args for the install step |
| `--check-target=<t>` | test target name (default `check`; `make` type has none unless set) |
| `--no-check` | skip the test phase |
| `--srcdir=<dir>` | force the extracted source dir if it differs from auto-detected |

Behavior: idempotent skip if already done (unless `FORCE=1`); extract → build
in a throwaway dir under `$SOURCES_DIR`; tee all output to the log; **test
failures are a warning by default** (set `STRICT=1` to enforce); on success
remove the source dir (unless `KEEP_BUILD=1`) and `mark_done`; on failure leave
the source dir for debugging and return non-zero.

Knobs: `FORCE=1` (rebuild), `STRICT=1` (tests fatal), `KEEP_BUILD=1` (keep src),
`MAKEFLAGS` (parallelism, from `env/lfs.env`).

## Copy-paste template for a new builder

```bash
#!/bin/bash
# scripts/final-system/NN-<pkg>.sh — build <Pkg> (LFS Ch.8)
# Run as part of the suite; chmod +x. Authored on macOS, RUN inside the VM.
set -euo pipefail

# Resolve repo root from this script's location, then load the contract.
HERE="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(CDPATH= cd -- "$HERE/../.." && pwd -P)"
# shellcheck source=/dev/null
source "$REPO_ROOT/env/lfs.env"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/package.sh"

build_package final/<pkg> "<pkg>-$<PKG>_VERSION.tar.xz"
```

## Variants

**autotools** (the default; most packages)
```bash
build_package final/grep "grep-$GREP_VERSION.tar.xz"
# build_package runs:
#   ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var <args>
#   make && make check && make install
```

**cmake** (out-of-tree)
```bash
build_package final/check "check-$CHECK_VERSION.tar.gz" --type=cmake \
  --configure-args="-DCMAKE_INSTALL_LIBDIR=lib"
# cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release <args> ..
```

**meson** (systemd, dbus, …)
```bash
build_package final/systemd "systemd-$SYSTEMD_VERSION.tar.gz" --type=meson \
  --configure-args="-Dmode=release -Ddefault-dnssec=no" --no-check
# meson setup build --prefix=/usr --buildtype=release <args>
#   && ninja -C build && ninja -C build install
```

**suckless / bare make** (dwm, st, dmenu — bonus)
```bash
build_package final/dwm "dwm-$DWM_VERSION.tar.gz" --type=make
# make PREFIX=/usr && make PREFIX=/usr install   (no configure, no check)
```

**perl** (XML::Parser, …)
```bash
build_package final/xml-parser "XML-Parser-$XML_PARSER_VERSION.tar.gz" --type=perl
# perl Makefile.PL && make && make test && make install
```

**Manual / multi-pass packages** (GCC bundled libs, Glibc, the kernel,
Binutils-pass1): `build_package` cannot express these. Use `extract_only`:
```bash
src="$(extract_only "binutils-$BINUTILS_VERSION.tar.xz")"
cd "$src" && mkdir -v build && cd build
../configure --prefix="$LFS/tools" --with-sysroot="$LFS" --target="$LFS_TGT" ...
make && make install
# wrap the whole thing in a run_step (lib/common.sh) for logging + idempotency.
```

## Install-prefix rules (do NOT get this wrong)

- System packages install to **`--prefix=/usr`**, with
  **`--sysconfdir=/etc`** and **`--localstatedir=/var`** (build_package's
  autotools path supplies all three automatically).
- **Never `/usr/local`** for system packages — that is for the local admin,
  and LFS puts the base system in `/usr`.
- Toolchain (Ch.5/6) temporary tools install to **`$LFS/tools`** — those use
  `extract_only` + manual configure, not the default prefix.
- Perl modules: prefer vendor dirs (`INSTALLDIRS=vendor`) so nothing lands in
  `/usr/local`.

## Pre-finalize checklist (before you call a builder "done")

- [ ] **Idempotent?** Uses `build_package`/`run_step` so re-running skips when
      marked done; no side effects outside extract/build/install.
- [ ] **Logged?** Output goes to `$FT_LOG_DIR/<name>.log` (automatic via
      `build_package`/`run_step`).
- [ ] **Versioned from `env/versions.sh`?** No hardcoded version or URL in the
      script body.
- [ ] **Correct prefix?** `/usr` (+ `/etc`, `/var`) for system packages;
      `$LFS/tools` for Ch.5/6 temp tools; never `/usr/local`.
- [ ] **In the order file?** Added to the relevant `_order.txt`
      (`scripts/temp-tools/_order.txt`, `scripts/final-system/_order.txt`) at
      the correct position.
- [ ] **Probe in `verify.sh`?** The package (or its systemd equivalent for the
      substituted ones) appears in `verify/verify.sh`'s package probe list.
- [ ] **systemd substitution respected?** Do not reintroduce Eudev / Sysvinit /
      Sysklogd / Udev-lfs builders — those roles are filled by systemd. See
      `CLAUDE.md`.
- [ ] **Header note:** `#!/bin/bash`, `set -euo pipefail`, "authored on macOS,
      run in the VM", `chmod +x` reminder.
