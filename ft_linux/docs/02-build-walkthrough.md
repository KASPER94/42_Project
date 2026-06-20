# 02 — Build walkthrough (the pipeline, phase by phase)

This expands **step 6** of the [RUNBOOK](RUNBOOK.md#step-6--run-the-build). It
maps each pipeline phase to its LFS-book chapter, says what the phase produces,
and explains resumability and logging. The orchestrator that runs these in
order is `run-all.sh` (with the `Makefile` as a thin wrapper).

---

## The phases at a glance

| Phase | Dir | LFS Ch. | Produces |
|-------|-----|---------|----------|
| Disk + env | [`scripts/00..02`](../scripts/) | 2–4 | Partitioned/mounted target disk, `lfs` user, clean build env |
| Sources | [`sources/`](../sources/) | 3 | Verified tarballs under `$LFS/sources` |
| Cross-toolchain | [`scripts/toolchain/`](../scripts/toolchain/) | 5 | A `$LFS_TGT` cross-compiler in `$LFS/tools` |
| Temp tools | [`scripts/temp-tools/`](../scripts/temp-tools/) | 6 | Minimal native tools in `$LFS/tools` |
| Chroot | [`scripts/chroot/`](../scripts/chroot/) | 7 | Entered chroot + remaining temp tools, cleaned |
| Final system | [`scripts/final-system/`](../scripts/final-system/) | 8 | All 68 packages installed to `/usr` |
| System config | [`scripts/system-config/`](../scripts/system-config/) | 9 | hostname, network, fstab, locale, FHS |
| Kernel | [`scripts/kernel/`](../scripts/kernel/) | 10 | `/boot/vmlinuz-<ver>-skapers`, modules, sources in `/usr/src/kernel-<ver>` |
| GRUB | [`scripts/boot/`](../scripts/boot/) | 10 | Bootloader on the target disk, `grub.cfg` |
| Finalize | [`scripts/finalize/`](../scripts/finalize/) | end | Strip/clean, `/etc/os-release`, checksum hook |

---

## Phase by phase

### Disk + environment (Ch.2–4) — `scripts/00-partition-disk.sh`, `01-format-mount.sh`, `02-setup-env.sh`
Wipes and partitions `$LFS_DISK` into `/boot` + `swap` + `root` (R6), formats
them ext4/swap, mounts root at `$LFS` (`/mnt/lfs`), creates the unprivileged
`lfs` build user, and exports the clean environment (`$LFS`, `$LFS_TGT`,
`MAKEFLAGS`, sanitized `PATH`) from [`../env/lfs.env`](../env/lfs.env).

### Cross-toolchain (Ch.5) — `scripts/toolchain/10..14`
Binutils pass 1 → GCC pass 1 → Linux API headers → Glibc → libstdc++. The output
is a self-contained cross-compiler under `$LFS/tools` that targets `$LFS_TGT`,
isolated from the host toolchain. Ends with the book's sanity *compile-and-link*
test; if that prints the wrong dynamic-linker path the toolchain is broken and
the rest is futile, so the step fails there.

### Temp tools + chroot (Ch.6–7) — `scripts/temp-tools/20..`, `scripts/chroot/30..34`
Cross-compiles a minimal set of native tools (m4, ncurses, bash, coreutils,
diffutils, file, …) into `$LFS/tools`, then **enters chroot** so the build is
sealed off from the host. Inside chroot it finishes the temporary toolset and
cleans up. `run-all.sh` auto-wraps the in-chroot steps via
`scripts/chroot/31-enter-chroot.sh` — you do not chroot by hand.

### Final system (Ch.8) — `scripts/final-system/NN-<pkg>.sh` + `_order.txt`
The bulk of the build: **one script per package**, numbered so sort order is
build order, driven by `scripts/final-system/_order.txt`. One-script-per-package
is deliberate — it lets a failure be re-run surgically (see resumability). This
rebuilds Glibc/GCC/Binutils as the *final* native toolchain, then the rest of
the 68 packages. The roster (and which entries are systemd build-deps not in the
spec's list) is in [`06-package-manifest.md`](06-package-manifest.md).

### System config (Ch.9) — `scripts/system-config/50..` + `files/`
Writes `/etc/hostname` = **`skapers`** (R7) and `/etc/hosts`; sets up
**systemd-networkd + resolved** over the VirtualBox NAT NIC for internet (R12);
generates `/etc/fstab` with partition **UUIDs** (via `blkid`); configures
locale/console/clock; finalizes the **FHS** layout (R11). Templates live in
`scripts/system-config/files/` (`hostname`, `hosts`, `20-wired.network`,
`resolv.conf`, `fstab.template`, `locale.conf`, `vconsole.conf`).

### Kernel (Ch.10) — `scripts/kernel/60-prepare`, `61-build`, `62-install` + `kernel-config`
The most-scrutinized phase. It:
- extracts the kernel to **`/usr/src/kernel-<KERNEL_VERSION>`** (R4);
- applies the pre-baked `kernel-config` with `CONFIG_LOCALVERSION="-skapers"`
  and `CONFIG_LOCALVERSION_AUTO=n`, so `uname -r` ends in **`-skapers`** (R2),
  plus the systemd, ext4, VirtualBox storage/net, and
  `CONFIG_DRM_VBOXVIDEO`/`CONFIG_INPUT_EVDEV` (bonus) options;
- builds, runs `make modules_install`, then copies the image to
  **`/boot/vmlinuz-<KERNEL_VERSION>-skapers`** (R5).

`62-install` **asserts** both the binary name and that `make kernelrelease` ends
in `-skapers`, failing loudly otherwise — these are the spec's named-kernel
rules and must not silently drift. `KERNEL_VERSION` is defined exactly once in
[`../env/versions.sh`](../env/versions.sh) (6.13.4, satisfying R3's `>= 4.0`).

### GRUB (Ch.10) — `scripts/boot/70-grub-install`, `71-grub-cfg` + `grub.cfg.template`
`grub-install` to the **target disk** (MBR, BIOS), then renders `grub.cfg` whose
`linux` line points at the exact `/boot/vmlinuz-<KERNEL_VERSION>-skapers` with
`root=` by UUID (R10). A name mismatch here is the #1 boot failure — see
[troubleshooting → kernel won't boot](04-troubleshooting.md#1-kernel-wont-boot-grub).

### Finalize — `scripts/finalize/80-cleanup`, `81-release`, `90-make-checksum`
Strips debug symbols, removes build cruft, writes an ft_linux `/etc/os-release`.
`90-make-checksum.sh` is the in-VM hook that pairs with the host-side
[`../submit/checksum.sh`](../submit/checksum.sh) used in RUNBOOK step 10.

---

## systemd substitution (high level)

The spec's package list names the **SysVinit** stack (Eudev, Sysvinit, Sysklogd,
Udev-lfs). We build the **systemd** variant instead, which the spec explicitly
permits ("SysV **or** SystemD"; "feel free to change [examples] for any
equivalent"). The roles are preserved one-for-one:

| Spec entry | We build | Role (requirement) |
|---|---|---|
| Eudev + Udev-lfs | `systemd-udevd` | kernel-module loader (R8) |
| Sysvinit | `systemd` (PID 1) | central management (R9) |
| Sysklogd | `systemd-journald` | system logging |

The full rationale, the verbatim spec quotes, and the auditable
`wget-list-sysv` reference are in
[`03-systemd-deviation.md`](03-systemd-deviation.md). `verify.sh` probes the
systemd equivalents for these entries.

---

## Resumability and targeted runs

The build is **idempotent**. Every step records a marker
`$FT_STATE_DIR/<step>.done` (`$FT_STATE_DIR` = `$LFS/.ft_state`, see
[`../env/paths.sh`](../env/paths.sh)), written via `lib/state.sh`. Because the
markers live on the target filesystem, they survive the host → chroot → booted
transitions.

| You want to… | Do this |
|---|---|
| Resume after a crash/reboot | Re-run `./run-all.sh --yes` — it fast-forwards past `.done` steps |
| See what is left | `./run-all.sh --status` |
| Re-run **one** step that failed | `FORCE=1 bash scripts/final-system/NN-<pkg>.sh` (clears that step's marker) — or `./run-all.sh --only <step>` |
| Restart from a given phase | `./run-all.sh --from <step>` |
| Preview without running | `./run-all.sh --dry-run` |
| Make package tests fatal | `STRICT=1 ...` (otherwise `make check` failures warn, per LFS guidance) |

> If a single package fails, the surgical fix is almost always to re-run *that
> one script* with `FORCE=1` after addressing the cause, then resume the whole
> pipeline — not to start over. See
> [troubleshooting → package build failure](04-troubleshooting.md#3-a-package-fails-to-build).

---

## Where logs go

Each step `tee`s its output to a per-step log via `lib/common.sh`'s `run_step`
and `lib/package.sh`'s `build_package`. The directory is `$FT_LOG_DIR`
([`../env/paths.sh`](../env/paths.sh)):

- **on the build host / in chroot:** repo-local `./logs/` (because `/var/log`
  may not be the target's);
- **on the booted ft_linux system** (`FT_IN_SYSTEM=1`): **`/var/log/ft_linux/`**.

Override anytime with `FT_LOG_DIR=/some/path`. When a step fails, its log is the
first place to look — the orchestrator prints the failing log's path.

---

Next: [`04-troubleshooting.md`](04-troubleshooting.md) for concrete failure
fixes.
