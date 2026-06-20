# 04 — Troubleshooting

Common failures and their fixes, in roughly the order you hit them. Each entry
notes the requirement (R-ID) at stake. See the [RUNBOOK](RUNBOOK.md) for the
overall flow and [`02-build-walkthrough.md`](02-build-walkthrough.md) for the
resume mechanics referenced below.

---

## 1. Kernel won't boot (GRUB)

*Relates to R2, R5, R10.*

**Symptoms:** GRUB error like `file '/boot/vmlinuz-...' not found`, a kernel
panic `unable to mount root fs`, or GRUB drops to a `grub>` prompt.

**Cause #1 — name mismatch.** The spec requires the kernel binary to be named
exactly **`/boot/vmlinuz-<version>-skapers`** (R5) and GRUB's `linux` line to
point at *that exact path*. If `scripts/kernel/62-install.sh` and
`scripts/boot/71-grub-cfg.sh` disagree on the version or the `-skapers` suffix,
GRUB can't find the image.

```sh
ls -1 /boot/vmlinuz-*                 # what is actually installed?
grep -n vmlinuz /boot/grub/grub.cfg   # what does GRUB point at?
uname -r 2>/dev/null                  # (if booted) must end in -skapers
```
Both must read `vmlinuz-<KERNEL_VERSION>-skapers` with the *same* version. The
version is defined once in [`../env/versions.sh`](../env/versions.sh)
(`KERNEL_VERSION`); the binary name, the source dir, and `grub.cfg` all derive
from it. Re-run the kernel install and GRUB config:
```sh
FORCE=1 bash scripts/kernel/62-install.sh
FORCE=1 bash scripts/boot/71-grub-cfg.sh
```

**Cause #2 — wrong `root=`.** `grub.cfg`'s `root=UUID=...` must match the root
partition's UUID. Check with `blkid` and compare to `/etc/fstab` and
`grub.cfg`; if they disagree, re-run the GRUB config step (it reads UUIDs from
`blkid`).

**Cause #3 — missing kernel features.** Panic on mount usually means ext4 or the
VirtualBox SATA driver was built as a module instead of built-in. The shipped
`scripts/kernel/kernel-config` builds these in; if you customized it, ensure
ext4 and AHCI/SATA are `=y`, not `=m`.

---

## 2. No network

*Relates to R12.*

**Symptoms:** `ping` fails, `verify.sh`'s DNS/ping check fails, package
downloads time out.

**On the booted ft_linux system** (systemd-networkd + resolved):
```sh
systemctl status systemd-networkd systemd-resolved
networkctl status                      # is the wired link 'routable'?
ip addr                                # did the NAT NIC get a DHCP address?
cat /etc/resolv.conf                   # should symlink to systemd-resolved's stub
```
Fixes:
- Ensure the `.network` unit matches the interface. The template
  [`../scripts/system-config/files/20-wired.network`](../scripts/system-config/files/20-wired.network)
  matches the NAT NIC; re-apply with
  `FORCE=1 bash scripts/system-config/50-network-systemd.sh`.
- `/etc/resolv.conf` must point at systemd-resolved
  (`ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf`).
- Enable the services: `systemctl enable --now systemd-networkd
  systemd-resolved`.

**On the build host** (before reboot): NAT is configured by
[`../vm/create-build-vm.sh`](../vm/create-build-vm.sh) (`--nic1 nat`). If the
host itself has no internet, check the VirtualBox NIC is *cable connected* and
that `82540EM` emulation is selected. See
[`01-vm-setup.md`](01-vm-setup.md#networking-nat-r12).

---

## 3. A package fails to build

*Relates to R14, R15.*

**Symptoms:** a `scripts/final-system/NN-<pkg>.sh` (or toolchain/temp-tools)
step exits non-zero; the orchestrator stops and prints the failing log path.

**First:** read the log under `$FT_LOG_DIR` (`./logs/` on the host,
`/var/log/ft_linux/` once booted — see
[`02-build-walkthrough.md`](02-build-walkthrough.md#where-logs-go)).

**Resume surgically — do not start over.** The build is idempotent via
`$FT_STATE_DIR` markers. After fixing the cause, re-run just that one step,
which clears and re-creates its marker:
```sh
FORCE=1 bash scripts/final-system/NN-<pkg>.sh
./run-all.sh --yes                # then resume; completed steps fast-forward
```
Or `./run-all.sh --only <step>` to run a single step, `--from <step>` to restart
from one.

**Common causes:**
- A failing `make check`. By default tests are non-fatal (LFS treats some test
  failures as expected). Only `STRICT=1` makes them fatal — so a *real* stop
  here is a genuine build error, not a flaky test.
- A missing build dependency. Confirm the prior package in
  `scripts/final-system/_order.txt` actually completed (check its `.done`
  marker / log).
- Out of disk or RAM. Disk B fills, or GCC/Glibc tests OOM at <4 GB. Grow the
  disk / RAM ([`01-vm-setup.md`](01-vm-setup.md#cpu--ram--vram)).

---

## 4. Wrong or unset `$LFS_DISK` (the destructive guard)

*Relates to R6.*

**Symptoms:** `scripts/00-partition-disk.sh` refuses to run, or you fear it
targeted the wrong disk.

`$LFS_DISK` defaults to **`/dev/sdb`** ([`../env/paths.sh`](../env/paths.sh)) —
the ft_linux target (Disk B). The build host OS is on `/dev/sda` (Disk A).
`run-all.sh` guards partitioning behind `--yes` *and* a confirmed `$LFS_DISK`.

```sh
lsblk                                  # confirm sdb is the ~20 GB blank target
echo "$LFS_DISK"                       # should be /dev/sdb
```
If your disk uses an NVMe/loop `pN` partition suffix instead of the `sdX`N
convention, override the partition vars (see the note in
[`../env/paths.sh`](../env/paths.sh)):
```sh
LFS_DISK=/dev/sdb \
LFS_DISK_BOOT=/dev/sdb1 LFS_DISK_SWAP=/dev/sdb2 LFS_DISK_ROOT=/dev/sdb3 \
  ./run-all.sh --yes
```
> **Never** point `$LFS_DISK` at `/dev/sda` — that wipes your build host.

---

## 5. Source checksum (md5) mismatch

*Relates to R13, R15.*

**Symptoms:** `sources/verify-sources.sh` reports `FAILED` for one or more
tarballs.

**Causes & fixes:**
- **Truncated/partial download.** Re-run the resumable downloader; it continues
  partial files (`wget --continue`):
  ```sh
  bash sources/download-sources.sh
  bash sources/verify-sources.sh
  ```
  If a file is corrupt rather than partial, delete it from `$LFS/sources` and
  re-download.
- **Pinned version drifted.** Versions in
  [`../env/versions.sh`](../env/versions.sh) are pinned to a coherent
  LFS-systemd set, but a few carry "verify against LFS book" notes. If a mirror
  now serves a different patch level, update both the version *and* the matching
  line in `sources/md5sums`. The checksum failing loudly is the system working
  as intended — it caught a mismatch before you wasted hours compiling the wrong
  source.

---

## 6. X black screen or `startx` fails

*Relates to the bonus (RUNBOOK step 9).*

**Symptoms:** `startx` returns to a black screen, exits immediately, or logs
`no screens found`.

**Checks, in order:**
1. **Mandatory must be perfect first.** The bonus is only graded if
   `verify/verify.sh` reports **0 failures** — and the build path is only stable
   then. Don't debug X over a broken base. See
   [item 7](#7-bonus-started-before-mandatory-is-perfect).
2. **Graphics controller.** The VM must use `vmsvga` or `vboxvga` with enough
   VRAM (≥16 MB; we set 64). Set at creation
   ([`../vm/create-build-vm.sh`](../vm/create-build-vm.sh) `--graphics`) or via
   `VBoxManage modifyvm ft_linux-build --graphicscontroller vmsvga --vram 64`.
   See [`01-vm-setup.md`](01-vm-setup.md#graphics-controller-for-the-bonus-step-9).
3. **DRM driver present.** The kernel needs `CONFIG_DRM_VBOXVIDEO` and
   `CONFIG_INPUT_EVDEV` (baked into `scripts/kernel/kernel-config`). Confirm:
   ```sh
   dmesg | grep -i vboxvideo
   ls /dev/dri/                         # expect card0 / renderD128
   ```
   If absent, the kernel config was changed — rebuild the kernel with those
   options.
4. **Xorg modeline / resolution.** Xorg uses `modesetting`; resolution is pinned
   by `bonus/xorg.conf.d/10-monitor.conf` and `xrandr` in the bonus
   `xinitrc.skel`. Read `~/.local/share/xorg/Xorg.0.log` (or `/var/log/Xorg.0.log`)
   for the actual EE error.
5. **Run as a non-root user.** `startx` must be launched by a normal user, not
   root.

---

## 7. Bonus started before mandatory is perfect

**Symptom:** you ran `bonus/run-bonus.sh` but the mandatory part still has
`verify.sh` failures.

The spec ([`../.specs/bonus.md`](../.specs/bonus.md)) is explicit: *"The bonus
part will only be assessed if the mandatory part is PERFECT."* Building Xorg on
top of an incomplete base also tends to surface confusing errors (missing libs,
broken toolchain) that are really mandatory-side problems in disguise.

**Fix the order:** stop, run `bash verify/verify.sh`, drive it to **0 failures**
(RUNBOOK step 8), *then* run the bonus (step 9). The bonus lives entirely under
`bonus/` so it cannot have broken the mandatory boot path — your base is intact.

---

## Still stuck?

- Re-read the relevant phase in
  [`02-build-walkthrough.md`](02-build-walkthrough.md) and check the step's log
  in `$FT_LOG_DIR`.
- Confirm no invariant drifted: [`../CLAUDE.md`](../CLAUDE.md) lists the
  compliance invariants; [`../verify/compliance-checklist.md`](../verify/compliance-checklist.md)
  maps each R-ID to its artifact and check.
- Verify your pinned versions against the current LFS-systemd book if a download
  URL 404s.
