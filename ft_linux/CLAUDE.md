# CLAUDE.md — ft_linux

ft_linux ("how_to_train_your_kernel", 42 spec v3.6) is a **Linux From Scratch**
distribution built entirely from source inside a VM: the **systemd** variant of
the LFS book, **64-bit**, booting via **GRUB**, running in **VirtualBox**, with
student login **`skapers`**. This repo is an **automation suite** — bash
scripts, configs, and docs — that the user runs *inside the build VM*. Agents
author files on macOS; **no agent ever compiles or boots LFS**.

## Critical invariants (compliance — never silently break these)

These map to the spec's hard rules. A future edit that violates one fails the
evaluation:

- **Hostname = `skapers`** (the student login).
- **Kernel localversion = `-skapers`** — `uname -r` MUST end in `-skapers`
  (`CONFIG_LOCALVERSION="-skapers"`, `CONFIG_LOCALVERSION_AUTO=n`).
- **Kernel binary = `/boot/vmlinuz-<KERNEL_VERSION>-skapers`**, and GRUB's
  `linux` line points at exactly that path.
- **Kernel sources in `/usr/src/kernel-<KERNEL_VERSION>`**.
- **`KERNEL_VERSION` is defined ONCE** in `env/versions.sh`; the binary name,
  source dir, and grub.cfg all derive from it. Kernel must be **>= 4.0** (we
  pin 6.x).
- **>= 3 partitions:** `root`, `/boot`, `swap` (we make exactly these three).
- **systemd is PID 1** (central management/config) — see the substitution note.
- **GRUB** is the bootloader.
- **FHS-compliant** filesystem layout.
- **Internet works** + `curl`/`wget` present (evaluation prerequisite).
- The single source of truth for login + versions + paths is `env/` — the
  literal `skapers` lives only in `env/lfs.env` (`LFS_USER_LOGIN`).
- **NEVER commit `*.vdi` / `*.vmdk` / `*.iso` or `sources/*.tar.*`** — only
  scripts/configs/docs + `shasum.txt`. (Enforced by `.gitignore`.)

## Directory map

```
ft_linux/
├── README.md  CLAUDE.md  Makefile  run-all.sh  .gitignore
├── env/            lfs.env · versions.sh · paths.sh     # single source of truth
├── lib/            common.sh · state.sh · chroot-helpers.sh · package.sh
├── vm/             create-build-vm.sh · Vagrantfile · provision · version-check
├── sources/        wget-list · md5sums · download-sources.sh · verify-sources.sh
├── scripts/                                              # the core mandatory pipeline
│   ├── 00-partition-disk.sh · 01-format-mount.sh · 02-setup-env.sh
│   ├── toolchain/   (Ch.5)   10-binutils-pass1 … 14-libstdcxx
│   ├── temp-tools/  (Ch.6)   m4 … gcc-pass2  + _order.txt
│   ├── chroot/      (Ch.7)   30-prepare-virtual-fs … 34-cleanup-temp
│   ├── final-system/(Ch.8)   one script per package, numbered  + _order.txt
│   ├── system-config/(Ch.9)  50-network-systemd … + files/ templates
│   ├── kernel/      (Ch.10)  60-prepare · 61-build · 62-install + kernel-config
│   ├── boot/        (Ch.10)  70-grub-install · 71-grub-cfg + grub.cfg.template
│   └── finalize/             80-cleanup · 81-release · 90-make-checksum
├── bonus/          BLFS Xorg chain + dwm/i3 + xinitrc (gated on verify.sh==0)
├── verify/         verify.sh · compliance-checklist.md
├── submit/         checksum.sh
├── docs/           RUNBOOK.md · walkthroughs · systemd-deviation · manifest · …
├── .claude/skills/lfs-package/SKILL.md
└── .specs/         (the 42 subject, parsed)
```

## How to run

The full procedure lives in **`docs/RUNBOOK.md`** (create VM → partition →
`./run-all.sh --yes` → reboot → `verify/verify.sh` → bonus → `submit/checksum.sh`).
**Scripts run inside the VM**, as root or the `lfs` build user as each step
requires. On macOS, agents/authors only edit files — they do not execute the
build.

## Conventions (every builder follows)

- `source "<repo>/env/lfs.env"` first (it pulls in `versions.sh` + `paths.sh`),
  then `lib/common.sh`, then `lib/package.sh` as needed.
- Use **`build_package`** (`lib/package.sh`) for package builds; use
  **`run_step`** (`lib/common.sh`) to wrap arbitrary steps (logging + timing +
  idempotency). Both are documented in `.claude/skills/lfs-package/SKILL.md`.
- `set -euo pipefail` at the top of every executable script.
- Builder scripts named **`NN-<pkg>.sh`** so sort order = build order; register
  them in the relevant `_order.txt`.
- Idempotency via `lib/state.sh` markers under `$FT_STATE_DIR`; re-running
  resumes past completed steps. `FORCE=1` re-runs one; STRICT=1 makes tests
  fatal.
- Install system packages to `/usr` (`--sysconfdir=/etc --localstatedir=/var`),
  **never `/usr/local`**. Temp tools (Ch.5/6) go to `$LFS/tools`.
- Logs: `$FT_LOG_DIR/<name>.log` — repo-local `./logs` on the host, or
  `/var/log/ft_linux` on the booted system.

## systemd substitution (do not reintroduce SysVinit)

The spec's package list (`/.specs/packages.md`) names **Eudev, Sysvinit,
Sysklogd, Udev-lfs Tarball** — the SysVinit path. We deliberately build the
**systemd** variant, which the spec explicitly permits: `mandatory.md` offers
"SysV **or** SystemD", and `packages.md` states *"Some packages below (vim,
bash, grub, udev) are examples. Feel free to change them for any equivalent you
like."*

| Spec entry | Replaced by | Role preserved |
|---|---|---|
| Eudev + Udev-lfs | `systemd-udevd` | kernel-module loader |
| Sysvinit | `systemd` (PID 1) | central management |
| Sysklogd | `systemd-journald` | system logging |

`zstd / openssl / elfutils / libffi / ninja / meson / dbus` are build
dependencies the systemd variant requires that are not in the spec's 68; they
are flagged as "build-dependency, added" in `docs/06-package-manifest.md`. The
documented deviation lives in `docs/03-systemd-deviation.md`. Do NOT add Eudev,
Sysvinit, Sysklogd, or Udev-lfs builders back into the pipeline.
