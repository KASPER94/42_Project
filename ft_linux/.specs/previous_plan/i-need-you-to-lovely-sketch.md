# ft_linux — LFS (systemd) Build Automation Suite + Multi-Agent Build Plan

## Context

`ft_linux` (42 project "how_to_train_your_kernel", spec v3.6) is **Linux From Scratch (LFS)**: build a basic-but-functional Linux distribution entirely from source, inside a VM, that becomes the base for all later kernel projects. The repo is currently empty except `.specs/` and the PDF.

The user asked me to **set up agents that realize the project, splitting the tasks according to the spec**, using the right skills. This plan defines the deliverable, the repo architecture, and the multi-agent decomposition that will produce it.

### Decisions (confirmed with the user)
- **Init system:** systemd (the *systemd variant* of the LFS book)
- **Arch / bootloader / VM:** 64-bit · GRUB · VirtualBox
- **Scope:** mandatory **+ bonus** (Xorg + window manager)
- **Student login:** `skapers` — must appear in the hostname, the kernel version string, and the kernel binary name
- **Kernel:** current LFS-systemd book kernel (6.x) — satisfies the spec's `>= 4.0` and ships the `vboxvideo` DRM driver the bonus needs

### Critical constraint shaping the deliverable
The agents run on a **macOS host with no Linux VM**. They **cannot compile or boot LFS** (a 12–24h build with chroot, reboots, `menuconfig`). They **author files only** — bash scripts, configs, docs — that the **user runs inside the build VM**. Every artifact below is a script/config/doc the user executes or reads; no agent ever runs a build step. `verify.sh`, `run-bonus.sh`, and `checksum.sh` are explicitly designed to be run by the user and say so in their headers.

### How LFS actually runs (so the VM layer makes sense)
1. A VirtualBox VM with a Debian/Ubuntu **build host** (has gcc/make/bash) — `Disk A`.
2. A **second virtual disk** `disk.vdi` = the ft_linux target system (root, `/boot`, swap) — this is the file whose `shasum` is submitted.
3. Cross-toolchain + 68 packages + kernel + GRUB are built onto `disk.vdi`, then the VM reboots into the new system standalone.

---

## Repository layout (target)

```
ft_linux/
├── README.md  CLAUDE.md  Makefile  run-all.sh  .gitignore
├── env/            lfs.env · versions.sh · paths.sh        # single source of truth (login, versions, paths, $LFS_DISK)
├── lib/            common.sh · state.sh · chroot-helpers.sh · package.sh
├── vm/             create-build-vm.sh · Vagrantfile · provision-build-host.sh · version-check.sh · README.md
├── sources/        wget-list · wget-list-sysv (ref) · md5sums · download-sources.sh · verify-sources.sh
├── scripts/                                                 # the CORE mandatory pipeline
│   ├── 00-partition-disk.sh · 01-format-mount.sh · 02-setup-env.sh
│   ├── toolchain/   (LFS Ch.5)   10-binutils-pass1 … 14-libstdcxx
│   ├── temp-tools/  (LFS Ch.6)   m4…gcc-pass2  + _order.txt
│   ├── chroot/      (LFS Ch.7)   30-prepare-virtual-fs … 34-cleanup-temp
│   ├── final-system/(LFS Ch.8)   one script per package, numbered  + _order.txt
│   ├── system-config/(LFS Ch.9)  50-network-systemd … 54-* + files/ (templates)
│   ├── kernel/      (LFS Ch.10)  60-prepare · 61-build · 62-install + kernel-config
│   ├── boot/        (LFS Ch.10)  70-grub-install · 71-grub-cfg + grub.cfg.template
│   └── finalize/                 80-cleanup · 81-release · 90-make-checksum
├── bonus/          00-blfs-env · run-bonus.sh · 10-deps/ · 20-xorg/ · 30-driver/ · 40-wm/ · xorg.conf.d/ · xinitrc.skel
├── verify/         verify.sh · compliance-checklist.md
├── submit/         checksum.sh
├── docs/           RUNBOOK.md · 01-vm-setup · 02-build-walkthrough · 03-systemd-deviation · 04-troubleshooting · 05-evaluation-checklist · 06-package-manifest · SUBMISSION.md
├── .claude/skills/lfs-package/SKILL.md
└── .specs/  (existing)
```

**Conventions** (every builder follows): `source` the `env/` contract; use `lib/package.sh`'s `build_package` helper; `set -euo pipefail`; log to `logs/` (host) / `/var/log/ft_linux/` (in-VM); idempotent via `lib/state.sh` markers; files named `NN-<pkg>.sh` so order is sortable. The login `skapers` and the kernel version live in exactly one variable each (`env/versions.sh`).

---

## Build pipeline (what the scripts do)

- **Disk + env (Ch.2–4):** partition the target disk into `/boot` (~512MB ext4), swap (~2GB), root (rest, ext4) → satisfies the ≥3-partition rule; create the `lfs` user + clean build env (`$LFS`, `$LFS_TGT`, `MAKEFLAGS=-j$(nproc)`).
- **Sources (Ch.3):** `download-sources.sh` (curl/wget present per spec, resumable `wget --continue`) + `verify-sources.sh` (`md5sum -c`). Covers all 68 spec packages + systemd-variant deps.
- **Cross-toolchain (Ch.5):** Binutils pass1 → GCC pass1 → Linux API headers → Glibc → libstdc++ (with the book's sanity compile-link test).
- **Temp tools + chroot (Ch.6–7):** cross-compiled temp tools → enter chroot → additional temp tools → cleanup.
- **Final system (Ch.8):** all final packages **one script per package**, ordered by `final-system/_order.txt` (chosen over grouping for surgical resume-after-failure + parallel authoring). Canonical systemd-variant order, with the substitution folded in:
  `Man-pages → Iana-Etc → Glibc → Zlib → Bzip2 → Xz → Zstd → File → Readline → M4 → Bc → Flex → Tcl → Expect → DejaGNU → Binutils → GMP → MPFR → MPC → Attr → Acl → Libcap → Shadow → GCC(final) → Pkg-config → Ncurses → Sed → Psmisc → Gettext → Bison → Grep → Bash → Libtool → GDBM → Gperf → Expat → Inetutils → Less → Perl → XML::Parser → Intltool → Autoconf → Automake → OpenSSL → Kmod → Elfutils → Libffi → Python → Ninja → Meson → Coreutils → Check → Diffutils → Gawk → Findutils → Groff → GRUB(build) → Gzip → IPRoute2 → Kbd → Libpipeline → Make → Patch → Tar → Texinfo → Util-linux → D-Bus → systemd → systemd-man-pages → Man-DB → Procps-ng → E2fsprogs → Vim`
  (Zstd/OpenSSL/Elfutils/Libffi/Ninja/Meson/D-Bus are book-required systemd deps not in the spec's 68; flagged as "build-dependency, added" in `docs/06-package-manifest.md`.)
- **System config (Ch.9):** `hostname=skapers` + `/etc/hosts`; systemd-networkd + resolved (`/etc/resolv.conf`) over VirtualBox NAT → satisfies "Connect to the Internet"; `/etc/fstab` (UUIDs via `blkid`); locale/console/clock; FHS layout.
- **Kernel (Ch.10) — most-scrutinized:** extract to **`/usr/src/kernel-<version>`**; pre-baked `kernel-config` with `CONFIG_LOCALVERSION="-skapers"` + `CONFIG_LOCALVERSION_AUTO=n` (modern, robust way to put the login in `uname -r`) plus systemd + ext4 + VirtualBox storage/net + `CONFIG_DRM_VBOXVIDEO`/`CONFIG_INPUT_EVDEV` (for the bonus). Build, `modules_install`, then copy `bzImage` → **`/boot/vmlinuz-<version>-skapers`**; `62-kernel-install.sh` asserts both the binary name and that `make kernelrelease` ends in `-skapers`, failing loudly otherwise.
- **GRUB (Ch.10):** `grub-install` to the **target disk**; `grub.cfg` `linux` line points at the exact `vmlinuz-<version>-skapers` with `root=` by UUID.
- **Finalize + submission:** strip/clean; write an `ft_linux` `/etc/os-release`; host-side `90-make-checksum.sh` powers off the VM and runs `shasum < disk.vdi > shasum.txt`.

### systemd vs. the spec package list (must be documented)
`packages.md` lists **Eudev, Sysvinit, Sysklogd, Udev-lfs Tarball** — the SysVinit path. We chose systemd, which the spec explicitly permits: `mandatory.md` offers "SysV **or** SystemD", and `packages.md` says *"Some packages below (vim, bash, grub, udev) are examples. Feel free to change them for any equivalent you like."* Substitution (documented in `docs/03-systemd-deviation.md` + `06-package-manifest.md`, with `wget-list-sysv` kept as an auditable reference):

| Spec entry | Replaced by | Role preserved |
|---|---|---|
| Eudev + Udev-lfs | `systemd-udevd` | kernel-module loader |
| Sysvinit | `systemd` (PID 1) | central management |
| Sysklogd | `systemd-journald` | system logging |

The other ~64 packages are built verbatim (the list's `Perl)` trailing-paren is a transcription artifact = Perl).

---

## Master orchestrator
`run-all.sh` (thin `Makefile` wrapper on top): ordered phase registry; **resumable/idempotent** via `$LFS/.ft_state/<step>.done` markers (a crash resumes by fast-forwarding past completed steps); per-step `tee` logging; auto-wraps in-chroot steps via `chroot/31-enter-chroot.sh`; targeted runs (`--from`, `--only`, `--status`, `--dry-run`); a destructive-partition guard requiring `--yes` + a confirmed `$LFS_DISK`. `make` targets: `vm · download · toolchain · chroot · final · kernel · grub · checksum · all`.

## Bonus (BLFS, only graded if mandatory is perfect — gate on `verify.sh` == 0 fails)
Lives entirely under `bonus/` so it can never break the mandatory boot path. `run-bonus.sh` builds, on the booted system: the Xorg dependency chain (libpng → freetype → fontconfig → util-macros → xorgproto → libXau/libXdmcp → xcb → Xorg libs → pixman → libdrm → **Mesa softpipe, no LLVM by default** to save ~1h build → libepoxy → **xorg-server** with modesetting → xkeyboard-config → xinit) + base fonts (DejaVu + `fc-cache`). **Default WM = `dwm`** (single tiny binary, near-zero deps → lowest "won't compile" risk; `i3` available behind `BONUS_WM=i3`), default terminal `st`, launcher `dmenu`. Graphics: in-kernel `vboxvideo` + Xorg `modesetting` (no Guest Additions needed); fixed resolution via `xorg.conf.d/10-monitor.conf` / `xrandr` in `xinitrc.skel`. Needs a non-root user for `startx`.

## Compliance + verification
- `verify/compliance-checklist.md`: maps every requirement (R1–R15: VM, kernel≥4.0, sources in `/usr/src/kernel-<ver>`, version string has `skapers`, `/boot/vmlinuz-<ver>-skapers`, ≥3 partitions, hostname=`skapers`, module loader, systemd init, GRUB, FHS, internet, curl/wget, build toolchain, all 68 packages) → the artifact that satisfies it → the `verify.sh` check ID, quoting `rules.md`/`goals.md`.
- `verify/verify.sh`: a self-check the **user** runs as root on the booted system — asserts `uname -r` contains `-skapers`, hostname, ≥3 partitions, `systemd-udevd` active, init is systemd, GRUB cfg points at the named kernel, FHS dirs, DNS+ping, curl/wget, gcc/make, and a data-driven probe per package (substituted entries probe their systemd equivalent). Exit code = failure count; prints "MANDATORY PERFECT — bonus may be graded" only at 0.

## Ops / docs / submission
- `docs/RUNBOOK.md`: the 10-step end-to-end order (create VM → partition → run core → reboot → `verify.sh` → bonus → re-verify/snapshot → checksum → push), each step citing the requirement IDs it discharges.
- `submit/checksum.sh` (host-side): reproduces the spec's `shasum < disk.vdi` (+ sha256), verifies the VM is powered off, writes `shasum.txt`. `.gitignore` keeps `*.vdi/*.iso/sources/*.tar.*/logs` out of git — only scripts/configs/docs + `shasum.txt` are committed (spec: "do **not** push your entire VM").
- `CLAUDE.md`: project summary + the **critical invariants** (hostname/localversion/binary-name/source-dir/≥3 partitions/systemd/GRUB/never-commit-vdi) so no future edit silently breaks compliance.

## The `lfs-package` skill (the "right skill" leverage)
There is no off-the-shelf LFS skill in this environment — the real leverage is bash + the LFS methodology, encoded once. Agent 0 creates `.claude/skills/lfs-package/SKILL.md` describing the canonical `build_package` pattern (extract → configure (`--prefix=/usr --sysconfdir=/etc --localstatedir=/var`) → make → `make check` → install → log → cleanup), with autotools/cmake/meson/suckless/perl variants and a pre-finalize checklist (idempotent? logged? in `_order.txt`? probe added to `verify.sh`?). **Every builder agent uses this skill** so all ~100 build scripts stay consistent. (The `init` skill concept informs `CLAUDE.md`.)

---

## Multi-agent implementation decomposition

Work parallelizes cleanly because each agent authors **non-overlapping files**; the only serialization is the shared contract (first) and the orchestrator/integration (last). On approval I spawn these via the Agent tool.

**Phase 1 — Foundation (1 agent, runs FIRST, blocks all others)**
- **A0 — Contracts & Skill:** `env/*`, `lib/*` (incl. the `build_package`/state/chroot helpers), `.claude/skills/lfs-package/SKILL.md`, `CLAUDE.md`, `.gitignore`, `README.md`. Freezes the variable names + helper API everyone depends on.

**Phase 2 — Authors (parallel, after A0)** — one message, multiple Agent calls:
- **A1 — VM & Sources:** `vm/*`, `sources/*`, `scripts/00–02` (disk/format/env).
- **A2 — Toolchain/Temp/Chroot:** `scripts/toolchain/*`, `scripts/temp-tools/*`, `scripts/chroot/*` (LFS Ch.5–7).
- **A3 — Final system:** `scripts/final-system/*` + `_order.txt` (LFS Ch.8, ~45 scripts; **may split into A3a/A3b** by build-order halves if throughput matters).
- **A4 — Config/Kernel/Boot:** `scripts/system-config/*`+`files/*`, `scripts/kernel/*` (owns the 3 spec-critical naming guarantees), `scripts/boot/*`, `scripts/finalize/*`.
- **A5 — Bonus (BLFS):** `bonus/*` (Xorg chain + dwm/i3 + xinitrc). Hands a kernel-config requirement (vboxvideo/DRM/evdev) to A4.
- **A6 — Verify & Compliance:** `verify/verify.sh`, `verify/compliance-checklist.md`, `docs/03-systemd-deviation.md`, `docs/06-package-manifest.md`, `docs/05-evaluation-checklist.md`.
- **A7 — Docs & Submission:** `docs/RUNBOOK.md` + walkthrough/troubleshooting/vm-setup, `docs/SUBMISSION.md`, `submit/checksum.sh` (finalizes last among authors since it references A1–A6 paths).

**Phase 3 — Integrator (1 agent, runs LAST)**
- **A8 — Orchestrator & Reconcile:** `run-all.sh`, `Makefile`; validates every script path referenced in the phase registry / `_order.txt` actually exists, that every R1–R15 appears in both checklist and runbook, that `.gitignore` covers every artifact the runbook tells the user to create, and that no file contradicts the systemd substitution.

Ordering: **A0 → {A1…A7 in parallel} → A8.** All builder agents are instructed to load and follow the `lfs-package` skill and the `env/`+`lib/` contracts from A0.

---

## Verification (how we confirm the deliverable is correct)

Because the actual build runs in the user's VM, verification is layered:
1. **Static (we can do, post-authoring):** A8 reconciles cross-references; optionally run `bash -n` syntax checks and (if available) `shellcheck` on all scripts; confirm `_order.txt` covers all 68 spec packages via `docs/06-package-manifest.md`.
2. **In-VM (the user runs, per `docs/RUNBOOK.md`):** create the VM (`vm/create-build-vm.sh`) → `./run-all.sh --yes` end-to-end → reboot into ft_linux → `bash verify/verify.sh` must report **0 failures** (this is the gate for bonus) → `bash bonus/run-bonus.sh` + `startx` for the GUI demo → `submit/checksum.sh` → commit `shasum.txt` + scripts/docs (not the VDI).

Success = `verify.sh` green (all of R1–R15), the system boots standalone via GRUB into `uname -r` ending `-skapers` with hostname `skapers` and working networking, and (bonus) `startx` brings up dwm/i3.
