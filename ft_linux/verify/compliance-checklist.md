# ft_linux — Compliance Checklist (R1–R15)

## How to read this

This table is the **single audit map** for the mandatory part. Every hard
requirement of the subject is assigned a stable ID (`R1`–`R15`) and one row
below. Each row gives, left to right:

| Column | Meaning |
|---|---|
| **ID** | The requirement ID, reused everywhere (this file, `verify/verify.sh`, `docs/05-evaluation-checklist.md`, the runbook). |
| **Requirement (verbatim spec quote + source)** | The exact sentence from the subject `.specs/*`, quoted word-for-word, with the file it came from. No paraphrasing of the binding text. |
| **Artifact / script that satisfies it** | The file(s) in this repo that *make* the requirement true on the built system. |
| **verify.sh check** | The function ID inside `verify/verify.sh` that *proves* it on the booted system, and the printed `[PASS]/[FAIL]` tag (`R1`…`R15`). |

The quotes come from `.specs/rules.md`, `.specs/goals.md`, `.specs/mandatory.md`
and `.specs/packages.md`. The decision to ship **systemd** in place of the
SysVinit-path packages (Eudev, Sysvinit, Sysklogd, Udev-lfs Tarball) is
permitted by the subject and documented in `docs/03-systemd-deviation.md`.

> **Build vs. proof.** The authoring agents worked on a macOS host with no
> Linux VM, so they could not run `verify.sh`. The "artifact" column is what we
> *authored*; the "verify.sh check" column is what **you** run as root on the
> booted ft_linux to confirm it. A clean run (`0 failed`) is the gate that lets
> the bonus be graded.

---

## Requirement map

| ID | Requirement (verbatim spec quote + source) | Artifact / script that satisfies it | verify.sh check |
|----|--------------------------------------------|-------------------------------------|-----------------|
| **R1** | "You MUST use a virtual machine (for example, VirtualBox or VMware)." — `.specs/rules.md` (System & environment) | `vm/create-build-vm.sh`, `vm/Vagrantfile`, `vm/provision-build-host.sh` — provision the VirtualBox build VM + target disk. | `chk_vm` → `[PASS] R1` (warn-only: `systemd-detect-virt`). |
| **R2** | "The kernel version string MUST contain your student login, e.g. `Linux kernel 4.1.2-<student_login>`." — `.specs/rules.md` (Kernel) | `scripts/kernel/kernel-config` sets `CONFIG_LOCALVERSION="-skapers"` + `CONFIG_LOCALVERSION_AUTO=n`; `scripts/kernel/62-kernel-install.sh` asserts `make kernelrelease` ends in `-skapers`. Login pinned once in `env/lfs.env` (`LFS_USER_LOGIN=skapers`). | `chk_uname_has_skapers` → `[PASS] R2` (`uname -r` contains `-skapers`). |
| **R3** | "You MUST use a kernel version `>= 4.0` (stable or not, as long as it's a `>= 4.0` version)." — `.specs/rules.md` (Kernel) | `env/versions.sh` `KERNEL_VERSION=6.13.4`; `scripts/kernel/60-prepare.sh` / `61-build.sh`. | `chk_kver_ge_4` → `[PASS] R3` (major version of `uname -r` ≥ 4). |
| **R4** | "The kernel sources MUST live in `/usr/src/kernel-$(version)`." — `.specs/rules.md` (Kernel) | `scripts/kernel/60-prepare.sh` extracts the kernel tarball to `/usr/src/kernel-${KERNEL_VERSION}`. | `chk_kernel_src_path` → `[PASS] R4` (`/usr/src/kernel-<version>` dir or symlink exists). |
| **R5** | "The kernel binary located in `/boot` MUST be named `vmlinuz-<linux_version>-<student_login>`. Adapt your bootloader configuration to that." — `.specs/rules.md` (Kernel) | `scripts/kernel/62-kernel-install.sh` copies `bzImage` → `/boot/vmlinuz-${KERNEL_VERSION}-skapers`; `scripts/boot/71-grub-cfg.sh` points the `linux` line at that exact name. | `chk_boot_binary_name` → `[PASS] R5` (a `/boot/vmlinuz-*-skapers` file exists). |
| **R6** | "You MUST use at least 3 different partitions: `root`, `/boot`, and a `swap` partition. You may make more partitions if you want." — `.specs/rules.md` (Partitions) | `scripts/00-partition-disk.sh` creates p1 `/boot` (ext4), p2 swap, p3 root (ext4); `scripts/01-format-mount.sh` formats/mounts; `env/paths.sh` defines `LFS_DISK_BOOT/SWAP/ROOT`; `/etc/fstab` from `scripts/system-config`. | `chk_three_partitions` → `[PASS] R6` (root, `/boot`, swap each present via `findmnt`/`lsblk` + `swapon`). |
| **R7** | "The distribution hostname MUST be your student login." — `.specs/rules.md` (Identity) | `scripts/system-config/files/hostname` = `skapers`, installed to `/etc/hostname`; `scripts/system-config/files/hosts`. | `chk_hostname_skapers` → `[PASS] R7` (`hostname` == `skapers` AND `/etc/hostname` == `skapers`). |
| **R8** | "Your distro MUST implement a kernel-module loader, like `udev`." — `.specs/rules.md` (Core software) | systemd variant: `systemd-udevd` (replaces Eudev + Udev-lfs Tarball — see `docs/03-systemd-deviation.md`); `Kmod` provides `modprobe`. Built by `scripts/final-system/*systemd*.sh` + `*kmod*.sh`. | `chk_module_loader` → `[PASS] R8` (`systemctl is-active systemd-udevd` + `modprobe` present + non-empty `lsmod`). |
| **R9** | "You MUST use software for central management and configuration, like SysV or SystemD." — `.specs/rules.md` (Core software) | systemd is PID 1 (replaces Sysvinit). Built by `scripts/final-system/*systemd*.sh`; `/sbin/init` → systemd. | `chk_init_is_systemd` → `[PASS] R9` (`readlink -f /sbin/init` contains `systemd`; `systemctl is-system-running`). |
| **R10** | "Your distro MUST boot with a bootloader, like LILO or GRUB." — `.specs/rules.md` (Core software) | `scripts/final-system/*grub*.sh` (build), `scripts/boot/70-grub-install.sh` (`grub-install` to target disk), `scripts/boot/71-grub-cfg.sh` (`grub.cfg` with the named kernel). | `chk_grub` → `[PASS] R10` (`/boot/grub/grub.cfg` exists + menuentry for `vmlinuz-*-skapers` + `grub-mkconfig` present). |
| **R11** | "Implement a filesystem hierarchy compliant with the standards" (FHS). — `.specs/goals.md` (Goals) | FHS layout established across the toolchain/temp-tools/chroot phases (`scripts/toolchain/*`, `scripts/chroot/*`) and the final system; standard dirs created during partition/mount + chroot prep. | `chk_fhs_dirs` → `[PASS] R11` (loop asserts `/bin /sbin /etc /lib /usr/bin /usr/lib /var /boot /root /home /tmp /proc /sys /dev`). |
| **R12** | "Connect to the Internet." — `.specs/goals.md` (Goals) | `scripts/system-config/files/20-wired.network` (systemd-networkd) + `resolv.conf` (systemd-resolved) over VirtualBox NAT; built by `scripts/system-config/*`. | `chk_network` → `[PASS] R12` (`getent hosts gnu.org` for DNS, then `ping -c1 -W3`; ping warn-only if blocked). |
| **R13** | "⚠ For evaluation purposes, you MUST be able to download source code. It is strongly recommended to install `curl` or `wget` or any other equivalent tool." — `.specs/rules.md` (Evaluation prerequisites) | `curl`/`wget` available on the system; `sources/download-sources.sh` uses them; toolchain ships them. | `chk_download_tool` → `[PASS] R13` (`command -v curl || command -v wget`). |
| **R14** | "⚠ For evaluation purposes, you also MUST be able to install packages, so make sure you have everything you need." — `.specs/rules.md` (Evaluation prerequisites) | Full build toolchain in the final system (`GCC`, `Make`, `Tar`, `Xz Utils`, `Patch`, Binutils, etc.) via `scripts/final-system/*`. | `chk_build_toolchain` → `[PASS] R14` (`gcc make tar xz patch` on PATH + a tiny gcc smoke compile, warn-only). |
| **R15** | "Install the full set of packages — see [packages](packages.md) for the complete list" (the 68 entries of `.specs/packages.md`). — `.specs/mandatory.md` (What's required) | All 68 spec packages built one-script-per-package under `scripts/final-system/NNN-*.sh` (see `docs/06-package-manifest.md`); the 4 SysVinit-path entries are satisfied by their systemd equivalents (`docs/03-systemd-deviation.md`). | `chk_packages` → `[PASS]/[FAIL] R15` (data-driven `PKG_PROBE` loop over all 68; each miss names the package). |

---

## Notes on the substituted requirements

Four of the 68 listed packages are on the **SysVinit** code path. ft_linux is
the **systemd** variant of LFS, which the subject explicitly allows ("SysV **or**
SystemD" in `.specs/rules.md`, and packages.md: *"Some packages below (vim, bash,
grub, udev) are examples. Feel free to change them for any equivalent you
like."*). The original *role* behind each requirement is preserved:

| Listed package(s) | Replaced by | Requirement still satisfied |
|---|---|---|
| Eudev + Udev-lfs Tarball | `systemd-udevd` | **R8** kernel-module loader |
| Sysvinit | `systemd` (PID 1) | **R9** central management/configuration |
| Sysklogd | `systemd-journald` | (logging role; central management — **R9**) |

`verify.sh`'s `chk_packages` probes these entries by their systemd equivalents
(`systemd-udevd`, `/sbin/init`→systemd, `journalctl`), so R15 stays green on a
systemd build. Full rationale: `docs/03-systemd-deviation.md`.

---

Related: `verify/verify.sh`, `docs/03-systemd-deviation.md`,
`docs/05-evaluation-checklist.md`, `docs/06-package-manifest.md`,
`.specs/rules.md`, `.specs/goals.md`, `.specs/mandatory.md`, `.specs/packages.md`.
