# 01 — VirtualBox setup for the ft_linux build

This is the detailed companion to **step 2** of the
[RUNBOOK](RUNBOOK.md#step-2--create-the-build-vm).
It explains *why* the VM is shaped the way it is and how to tune it. The
authoritative provisioning is [`vm/create-build-vm.sh`](../vm/create-build-vm.sh)
(and the Vagrant equivalent [`vm/Vagrantfile`](../vm/Vagrantfile)); this doc is
the rationale and the manual-GUI fallback.

---

## Why a VM at all (R1)

The spec mandates building inside a virtual machine. We use VirtualBox (the spec
names it explicitly). Two reasons it must be a VM and not bare metal:

- LFS repartitions a whole disk and installs a bootloader to it — destructive
  operations you do not want on your real machine.
- The submission artifact is a single **`disk.vdi`** file you can `shasum` and
  keep around for the peer-evaluation. A physical disk cannot be submitted.

---

## The two-disk layout (the key idea)

LFS is built *from* a working Linux (the "build host", which has gcc/make/bash)
*onto* a separate blank disk that becomes the new distribution. So the VM has
**two virtual disks**:

| Disk | File | In-VM device | Role |
|------|------|--------------|------|
| **A** | `build-host.vdi` (~25 GB) | `/dev/sda` | Throwaway Debian/Ubuntu build host OS. Provides the compiler. |
| **B** | `disk.vdi` (~20 GB, **dynamic**) | `/dev/sdb` | **The ft_linux target — the deliverable.** This is what you `shasum`. |

`$LFS_DISK` in [`../env/paths.sh`](../env/paths.sh) defaults to **`/dev/sdb`** —
Disk B. Everything destructive (`scripts/00-partition-disk.sh`) targets that.

> **Never install the build host onto `/dev/sdb`.** During the Ubuntu/Debian
> installer, choose `/dev/sda` only. If you wipe Disk B you lose nothing yet (it
> is blank pre-build), but it is the disk the whole pipeline expects to own.

`disk.vdi` is created **dynamic** so the file stays small until written; after a
full build it grows to a few GB. The ≥3-partition requirement (**R6**) is carved
*inside* Disk B: `/boot`, `swap`, `root` — see
[`../env/paths.sh`](../env/paths.sh) (`LFS_DISK_BOOT/SWAP/ROOT`).

---

## Firmware: BIOS vs EFI — use **BIOS** (recommended)

`vm/create-build-vm.sh` sets `--firmware bios`. **Recommended**, because:

- The GRUB install path is the simplest, most-documented LFS flow (`grub-install`
  to the MBR of the target disk, no EFI System Partition needed). This keeps the
  partition layout at exactly the three required (R6) without an extra ESP.
- It matches `scripts/boot/70-grub-install.sh` / `71-grub-cfg.sh` and the
  `grub.cfg.template`, which assume BIOS/MBR.

If you insist on **EFI** (`--firmware efi`), you must add an EFI System Partition
(FAT32, ~100 MB, `esp`/`boot` flags) and install GRUB with
`--target=x86_64-efi --efi-directory=/boot/efi`. That is a deviation from the
shipped boot scripts and is not covered here. Stick with BIOS unless you have a
reason.

---

## CPU / RAM / VRAM

Set by `vm/create-build-vm.sh` (override with flags):

| Setting | Default | Flag | Notes |
|---------|---------|------|-------|
| RAM | 4096 MB | `--ram` | Glibc/GCC test suites are memory-hungry; 4 GB is the floor. |
| vCPU | 2 | `--cpus` | `MAKEFLAGS=-j$(nproc)` in [`../env/lfs.env`](../env/lfs.env) uses them all. More cores ≈ proportionally faster build. |
| VRAM | 64 MB | (modifyvm) | Enough for the bonus X server framebuffer. |
| Disk A | 25 GB | `--disk-a-size` | Build host + extracted sources + object files. |
| Disk B | 20 GB | `--disk-b-size` | The ft_linux system; dynamic VDI. |

More cores is the single biggest lever on total build time (often the
difference between an afternoon and overnight).

---

## Networking: NAT (R12)

`create-build-vm.sh` attaches a single **NAT** NIC (`--nic1 nat`, Intel
`82540EM` emulation). NAT needs no host configuration and gives outbound
internet to:

- the **build host**, to clone this repo and download sources
  (`sources/download-sources.sh`, R13); and
- the **booted ft_linux**, where `verify.sh` pings/DNS-resolves to prove R12.

Inside ft_linux, networking is brought up by **systemd-networkd + resolved**,
configured by [`../scripts/system-config/50-network-systemd.sh`](../scripts/system-config/50-network-systemd.sh)
using the templates in `scripts/system-config/files/` (`20-wired.network`,
`resolv.conf`). The NAT NIC presents as a wired interface that DHCPs an address.
If `verify.sh`'s network check fails, see
[troubleshooting → no network](04-troubleshooting.md#2-no-network).

---

## Graphics controller (for the bonus, step 9)

The bonus X server (step 9 of the RUNBOOK) needs a framebuffer the in-kernel
`vboxvideo` DRM driver can drive. `create-build-vm.sh` defaults the controller
to **`vmsvga`** (`--graphics vmsvga`); **`vboxvga`** also works. Avoid the
`none`/serial-only setups.

- The kernel is built with `CONFIG_DRM_VBOXVIDEO` and `CONFIG_INPUT_EVDEV`
  (handed to the kernel config by the bonus author) so **no VirtualBox Guest
  Additions are needed**.
- Xorg uses the `modesetting` driver; resolution is pinned via
  `bonus/xorg.conf.d/10-monitor.conf` and/or `xrandr` in the bonus `xinitrc`.

If `startx` yields a black screen, the controller/VRAM is the first thing to
check — see
[troubleshooting → X black screen](04-troubleshooting.md#6-x-black-screen-or-startx-fails).

---

## Host vs guest: where each step runs

A recurring source of confusion. The boundary:

| Runs on the **macOS host** | Runs **inside the VM** |
|---|---|
| `vm/create-build-vm.sh` (create the VM) | Installing the build-host OS |
| `submit/checksum.sh` (hash the powered-off `disk.vdi`) | `vm/provision-build-host.sh`, `vm/version-check.sh` |
| `git push` of scripts/docs/`CHECKSUM.txt` | `scripts/00..02`, `sources/*`, `run-all.sh`/`make` |
| | `verify/verify.sh`, `bonus/run-bonus.sh`, `startx` |

Rule of thumb: anything that *compiles, partitions, or boots* runs in the VM;
only **creating the VM** and **hashing the final image** happen on the Mac.

---

## Tie-in: `vm/version-check.sh`

After installing the build host, `vm/provision-build-host.sh` runs
[`vm/version-check.sh`](../vm/version-check.sh) — the LFS "Host System
Requirements" gate. It verifies the build host ships new-enough bash, binutils,
bison, coreutils, diffutils, findutils, gawk, gcc/g++, grep, gzip, m4, make,
patch, perl, python, sed, tar, texinfo, xz, and that `/bin/sh` resolves to bash.
**Resolve every failure it reports before step 4** — a too-old host tool surfaces
much later as a confusing mid-build compile error.

---

Next: [`02-build-walkthrough.md`](02-build-walkthrough.md) walks the pipeline
phase by phase.
