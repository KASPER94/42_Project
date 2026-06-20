# vm/ — the build VM, the two disks, and the ISO

This directory holds everything needed to stand up the VirtualBox VM in which
the entire LFS (systemd) build runs. **You author nothing here — you run it.**
All scripts in this directory run on your **macOS/Linux host** except
`provision-build-host.sh` and `version-check.sh`, which run **inside** the VM.

## The mental model: two disks + one ISO

LFS is built on one machine that has a working compiler, onto a *separate*
blank disk that becomes the new distro. We model that with two virtual disks:

| Virtual disk | File | In-VM device | Role | Committed to git? |
|---|---|---|---|---|
| **Disk A** | `build-host.vdi` (~25 GB) | `/dev/sda` | The Debian/Ubuntu **build host** OS. Has gcc/make/bash. Throwaway. | No (`*.vdi` is gitignored) |
| **Disk B** | `disk.vdi` (~20 GB, dynamic) | `/dev/sdb` = `$LFS_DISK` | The **ft_linux TARGET**: `/boot`, swap, root. Gets the cross-toolchain, 68 packages, kernel, GRUB built onto it. | No — but **this is the deliverable** |
| **ISO** | e.g. `ubuntu-24.04-live-server-amd64.iso` | optical drive | Installer for Disk A only. | No |

The submission artifact is `shasum < disk.vdi` (see `submit/checksum.sh`), **not**
the whole VM. `.gitignore` keeps `*.vdi`/`*.iso` out of git on purpose.

> Why a second disk and not just partitions on Disk A? Because LFS partitions
> and reformats the target from scratch (`scripts/00-partition-disk.sh` runs
> GPT + mkfs on `$LFS_DISK`). Keeping the target on its own disk means we never
> risk the build host's own root filesystem, and the resulting `disk.vdi` is a
> clean, self-contained, bootable ft_linux system.

## Networking & firmware

- **NAT** networking: both the build host (to download sources) and the final
  ft_linux system (to satisfy the spec's "connect to the internet") reach the
  net through the host. No port-forwarding needed for the build.
- **BIOS** firmware (not UEFI): the simplest, most reliable target for the
  GRUB configuration in `scripts/boot/`.
- **Graphics**: VMSVGA (set by both `create-build-vm.sh` and the `Vagrantfile`)
  so the bonus Xorg + window-manager demo can render later.

## Two ways to create the VM

### Option 1 — `create-build-vm.sh` (manual ISO install, full control)

```sh
# On the host (macOS/Linux), with VirtualBox installed:
bash vm/create-build-vm.sh --iso ~/Downloads/ubuntu-24.04-live-server-amd64.iso
```

It creates the VM `ft_linux-build`, both disks, attaches the ISO, and prints
next steps. It **refuses to overwrite an existing `disk.vdi`** (your
deliverable) unless you pass `--force`. Then:

1. `VBoxManage startvm ft_linux-build` and install Ubuntu/Debian onto **`/dev/sda` only**.
2. Detach the ISO (command printed by the script).
3. Inside the VM: `sudo bash vm/provision-build-host.sh`.

Useful flags: `--ram`, `--cpus`, `--disk-a-size`, `--disk-b-size`,
`--graphics vmsvga|vboxvga`, `--vm-dir`, `--force`. Run `--help` for all.

### Option 2 — `Vagrantfile` (declarative, no ISO step)

```sh
cd vm
vagrant up        # downloads a prebuilt Ubuntu box, attaches lfs-target.vdi (/dev/sdb),
                  # and runs provision-build-host.sh automatically
vagrant ssh
```

With Vagrant the build host comes pre-installed (so there is no `/dev/sda`
install step), and the ft_linux target is `vm/lfs-target.vdi` (instead of
`disk.vdi`). The repo is synced to `/home/vagrant/ft_linux`.

## Provisioning the build host (inside the VM)

`provision-build-host.sh` (run as root inside the VM):

- `apt-get install`s the LFS host requirements **plus** `curl`, `wget`, `git`
  (the spec mandates a downloader), plus `parted`/`gdisk` for partitioning the
  target disk.
- Re-points **`/bin/sh` to bash** (LFS requires `sh=bash`, not dash).
- Ends by running **`version-check.sh`** and **aborts** if anything fails.

`version-check.sh` is the faithful LFS Chapter-2 host checker (Bash, Binutils,
Bison + yacc→bison, Bzip2, Coreutils, Diffutils, Findutils, Gawk + awk→gawk,
GCC/G++ ≥ 5.2, Glibc, Grep, Gzip, M4, Make ≥ 4.0, Patch, Perl, Python3, Sed,
Tar, Texinfo, Xz, host kernel ≥ 4.19) **plus** a G++ compile-and-link smoke
test **plus** the ft_linux extras (curl/wget/git). It prints `PASS`/`FAIL` per
item and exits non-zero on any failure.

## Where this fits in the whole flow

```
HOST (macOS/Linux):  vm/create-build-vm.sh   (or  cd vm && vagrant up)
        │
        ▼
VM build host:       vm/provision-build-host.sh  ->  vm/version-check.sh
        │
        ▼
VM build host:       scripts/00-partition-disk.sh  (partitions /dev/sdb)
                     scripts/01-format-mount.sh
                     scripts/02-setup-env.sh
                     ./run-all.sh --yes            (toolchain → … → GRUB)
        │
        ▼ reboot into ft_linux (standalone, off Disk B)
ft_linux:            bash verify/verify.sh         (must be 0 failures)
        │
        ▼ power off
HOST:                submit/checksum.sh            (shasum < disk.vdi)
```

See `docs/RUNBOOK.md` for the full end-to-end procedure.
