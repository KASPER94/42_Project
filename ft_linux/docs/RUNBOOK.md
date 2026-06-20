# ft_linux — RUNBOOK (end-to-end build guide)

This is **the** guide. Follow the ten numbered steps in order, top to bottom, to
go from a bare macOS host to a submitted ft_linux distribution. Each step lists
the requirement IDs (**R1–R15**) it discharges; the authoritative mapping of
those IDs to artifacts and `verify.sh` checks lives in
[`../verify/compliance-checklist.md`](../verify/compliance-checklist.md).

> **Mental model.** Everything in this repo is a *script or config you run
> inside the build VM* (or, for the checksum, on the macOS host). No part of the
> build runs on your Mac directly. The repo was authored on macOS; you execute
> it in the VM.

**Requirement IDs at a glance** (full text in the compliance checklist):

| ID | Requirement |
|----|-------------|
| R1  | Build inside a virtual machine |
| R2  | Kernel version string contains the login (`-skapers`) |
| R3  | Kernel version `>= 4.0` |
| R4  | Kernel sources in `/usr/src/kernel-<version>` |
| R5  | `/boot` kernel binary named `vmlinuz-<version>-skapers` |
| R6  | At least 3 partitions: `root`, `/boot`, `swap` |
| R7  | Hostname = the student login (`skapers`) |
| R8  | A kernel-module loader (`udev` / `systemd-udevd`) |
| R9  | Central management software (SysV / **systemd**) |
| R10 | A bootloader (LILO / **GRUB**) |
| R11 | FHS-compliant filesystem layout |
| R12 | Internet connectivity works |
| R13 | `curl` / `wget` present (download sources) |
| R14 | A working build toolchain (gcc/make), can install packages |
| R15 | All 68 spec packages (or documented equivalents) installed |

---

## Step 1 — Prerequisites on the macOS host

**Discharges:** prepares R1, R13.

On your Mac:

1. **Install VirtualBox** (the spec mandates a VM — R1). Either the GUI app from
   <https://www.virtualbox.org/> or:
   ```sh
   brew install --cask virtualbox
   ```
   Confirm the CLI is on `PATH`:
   ```sh
   VBoxManage --version
   ```
2. **Download a build-host ISO** — an Ubuntu Server or Debian netinst image.
   This is the *throwaway* OS that provides `gcc`/`make`/`bash` to compile LFS;
   it is **not** ft_linux. (R13/R14 are satisfied later *inside* ft_linux, but
   the build host is where the cross-toolchain is compiled.)
3. **Have this repo on disk.** You will copy it into the VM in step 3.

See [`01-vm-setup.md`](01-vm-setup.md) for the full VirtualBox rationale
(two-disk layout, BIOS vs EFI, RAM/CPU, graphics controller).

---

## Step 2 — Create the build VM

**Discharges:** R1; sets up the R6 disk; prepares the bonus.

From the repo root **on the host**:

```sh
bash vm/create-build-vm.sh --iso /path/to/ubuntu-server.iso
```

This creates the VirtualBox VM `ft_linux-build` with **two disks**:

- **Disk A** = `build-host.vdi` (`/dev/sda` in the VM) — the Debian/Ubuntu build
  host OS you install in step 3.
- **Disk B** = `disk.vdi` (`/dev/sdb` in the VM) — **the ft_linux target and the
  submission artifact.** This is the file you will `shasum` in step 10.

The script also sets a **graphics controller** (`vmsvga` by default) and 64 MB
VRAM so the later bonus GUI (step 9) has a framebuffer, and **NAT networking**
so both the build host and the finished ft_linux reach the internet (R12).

> Vagrant alternative: [`vm/Vagrantfile`](../vm/Vagrantfile) provisions the same
> two-disk layout if you prefer `vagrant up`.

Details and tunables (RAM/CPU/disk sizes, EFI vs BIOS): see
[`01-vm-setup.md`](01-vm-setup.md).

---

## Step 3 — Install + provision the build host, copy the repo

**Discharges:** R13, R14.

1. Start the VM and run the Ubuntu/Debian installer. **Install onto Disk A
   (`/dev/sda`) ONLY.** Do **not** touch `/dev/sdb` — that is the ft_linux
   target (`$LFS_DISK`).
2. After install, detach the ISO so the VM boots from disk (the create script
   prints the exact `VBoxManage storageattach ... --medium none` command).
3. Boot into the build host. Provision it (installs the LFS host dependencies,
   points `/bin/sh` at bash, and runs the version sanity check):
   ```sh
   sudo bash vm/provision-build-host.sh
   ```
   This invokes [`vm/version-check.sh`](../vm/version-check.sh) — the LFS
   "host system requirements" gate (bash, binutils, bison, gcc, make, etc. at
   minimum versions). Fix anything it flags before continuing.
4. **Get this repo into the VM.** Clone it (the build host has internet via NAT)
   or copy it in. Work from its root for all remaining in-VM steps.

---

## Step 4 — Partition + format the TARGET disk

**Discharges:** R6, R11.

Still in the build host, **as root**, operating on `$LFS_DISK` (`/dev/sdb`):

```sh
sudo LFS_DISK=/dev/sdb bash scripts/00-partition-disk.sh
sudo bash scripts/01-format-mount.sh
sudo bash scripts/02-setup-env.sh
```

- `00-partition-disk.sh` creates the **≥3 partitions** (R6): `/boot` (~512 MB
  ext4), `swap` (~2 GB), `root` (remainder, ext4) — matching `LFS_DISK_BOOT/SWAP/
  ROOT` in [`../env/paths.sh`](../env/paths.sh).
- `01-format-mount.sh` makes the filesystems and mounts root at `$LFS`
  (`/mnt/lfs`) with `/boot` under it — the start of the FHS layout (R11).
- `02-setup-env.sh` creates the `lfs` build user and the clean build environment
  (`$LFS`, `$LFS_TGT`, `MAKEFLAGS`) per [`../env/lfs.env`](../env/lfs.env).

> **DESTRUCTIVE.** `00-partition-disk.sh` wipes `$LFS_DISK`. Triple-check it
> points at the target disk (`/dev/sdb`), never the build host's `/dev/sda`.
> The orchestrator (step 6) additionally guards this behind `--yes`.

---

## Step 5 — Download + verify sources

**Discharges:** R13, R15.

```sh
bash sources/download-sources.sh        # uses curl/wget, resumable (--continue)
bash sources/verify-sources.sh          # md5sum -c against sources/md5sums
```

This fetches all 68 spec packages plus the systemd-variant build dependencies
into `$SOURCES_DIR` (`$LFS/sources`) and checksums them. A mismatch fails loudly
— see [troubleshooting](04-troubleshooting.md#5-source-checksum-md5-mismatch).
The package roster and the systemd substitutions are documented in
[`06-package-manifest.md`](06-package-manifest.md).

---

## Step 6 — Run the build

**Discharges:** R2, R3, R4, R5, R8, R9, R10, R11, R14, R15.

This is the long one — **hours** of compilation (cross-toolchain → 68 packages →
kernel → GRUB). It is **resumable**: if it crashes or you reboot, re-running
fast-forwards past completed steps via state markers under `$FT_STATE_DIR`
(`$LFS/.ft_state`).

```sh
sudo ./run-all.sh --yes
```

Or drive individual phases with the Makefile:

```sh
make toolchain      # Ch.5  cross-toolchain
make chroot         # Ch.6–7 temp tools + enter chroot
make final          # Ch.8  the 68 final packages
make kernel         # Ch.10 kernel build (asserts the -skapers name, R2/R5)
make grub           # Ch.10 GRUB install + grub.cfg (R10)
make all            # everything, end to end
```

What the phases produce, how resumability and `--from`/`--only`/`--status`
work, and where logs go (`/var/log/ft_linux`): see
[`02-build-walkthrough.md`](02-build-walkthrough.md). The systemd-for-SysVinit
substitution (R8/R9) is explained in
[`03-systemd-deviation.md`](03-systemd-deviation.md).

> The kernel step bakes `CONFIG_LOCALVERSION="-skapers"` so `uname -r` ends in
> `-skapers` (R2), installs sources to `/usr/src/kernel-<version>` (R4), and
> copies the image to `/boot/vmlinuz-<version>-skapers` (R5) — failing loudly if
> either name is wrong. GRUB's `linux` line points at exactly that file (R10).

---

## Step 7 — Reboot into ft_linux

**Discharges:** R1, R10.

1. Power the VM off.
2. Make sure the ISO is detached (step 3.2) and the VM boots **Disk B**
   (`/dev/sdb` / `disk.vdi`). In the GUI, set the boot order to that disk; or
   detach Disk A temporarily if your firmware insists on `/dev/sda`.
3. Boot. GRUB should present ft_linux; it boots the
   `vmlinuz-<version>-skapers` kernel.
4. Log in as **`skapers`** (or root, as the install created it).

If it does not boot, jump to
[troubleshooting → kernel won't boot](04-troubleshooting.md#1-kernel-wont-boot-grub).

---

## Step 8 — Verify

**Discharges:** R1–R15 (this is the gate for the bonus).

On the booted ft_linux system, **as root**:

```sh
bash verify/verify.sh
```

This self-check asserts every hard rule: `uname -r` ends in `-skapers`, hostname
is `skapers`, ≥3 partitions, `systemd-udevd` active, PID 1 is systemd, GRUB
points at the named kernel, FHS dirs exist, DNS + ping work, `curl`/`wget` and
`gcc`/`make` are present, and every package (or its systemd equivalent) probes
present. **The exit code is the failure count.** Iterate — fix issues (often a
re-run of one step with `FORCE=1`, see step 6) — until it prints:

```
MANDATORY PERFECT — bonus may be graded
```

**Do not start the bonus until this is 0 failures.** The spec only grades the
bonus if the mandatory part is *perfect*
([`.specs/bonus.md`](../.specs/bonus.md)).

---

## Step 9 — Bonus: Xorg + window manager

**Precondition:** only run this if step 8 reported 0 failures.

On the booted ft_linux system:

```sh
bash bonus/run-bonus.sh             # builds the Xorg chain + dwm (default WM)
```

Then, **as a non-root user** (`startx` refuses to run cleanly as root):

```sh
startx
```

This brings up Xorg with the in-kernel `vboxvideo` DRM driver and the `dwm`
window manager (override with `BONUS_WM=i3`). For the framebuffer to work, the
VM's **graphics controller** must be `vmsvga` (or `vboxvga`) with adequate VRAM
— set in step 2, or adjust per [`01-vm-setup.md`](01-vm-setup.md). A black
screen? See
[troubleshooting → X black screen](04-troubleshooting.md#6-x-black-screen-or-startx-fails).

---

## Step 10 — Submit

**Discharges:** the submission rules (see [`SUBMISSION.md`](SUBMISSION.md)).

1. Power the VM **off** (clean shutdown).
2. **On the macOS host**, checksum the disk image:
   ```sh
   bash submit/checksum.sh                       # auto-finds ~/VirtualBox VMs/ft_linux-build/disk.vdi
   # or: bash submit/checksum.sh /path/to/disk.vdi
   ```
   This reproduces the spec's `shasum < disk.vdi` (plus SHA-256), prints both,
   and writes a tracked `CHECKSUM.txt` at the repo root.
3. Commit and push **the scripts, configs, docs, and `CHECKSUM.txt`** — but
   **never** the `.vdi` (it is `.gitignore`d):
   ```sh
   git add -A && git status        # confirm no *.vdi / sources/*.tar.* are staged
   git commit -m "ft_linux: build suite + disk image checksum"
   git push
   ```
4. **Keep `disk.vdi` accessible** for the peer-evaluation — you boot it live
   during the defense.

The full rules, with the spec quoted verbatim, are in
[`SUBMISSION.md`](SUBMISSION.md).

---

## Troubleshooting

Stuck at any step? Start at [`04-troubleshooting.md`](04-troubleshooting.md):
kernel won't boot, no network, a package fails to compile, wrong `$LFS_DISK`,
md5 mismatch, X black screen, or the bonus started too early.
