# 05 — Evaluation Checklist (peer-evaluation walkthrough)

## Purpose

This is the **live-defense companion** for the evaluator. For each mandatory
requirement (`R1`–`R15`) it gives the single command to run **on the booted
ft_linux system**, what a passing result looks like, and the underlying spec
rule. Most commands mirror exactly what `verify/verify.sh` automates, so you can
spot-check any line by hand.

> **Fast path:** run `bash verify/verify.sh` (as root). It executes all the
> checks below and prints `X passed, Y warnings, Z failed`. **Z must be 0** for
> the mandatory part to be complete (and for the bonus to be eligible for
> grading). The per-requirement commands below let you confirm any individual
> claim live during the defense.

Fixed facts for this build: login `skapers`, kernel `6.13.4`, systemd init,
64-bit, GRUB, VirtualBox.

---

## Per-requirement live checks

### R1 — Runs in a virtual machine
> Rule: *"You MUST use a virtual machine (for example, VirtualBox or VMware)."* (`.specs/rules.md`)
```sh
systemd-detect-virt          # expect: oracle  (VirtualBox)
```
Pass: prints a hypervisor name (e.g. `oracle`), not `none`.

### R2 — Kernel version string contains the login
> Rule: *"The kernel version string MUST contain your student login..."* (`.specs/rules.md`)
```sh
uname -r                     # expect: 6.13.4-skapers  (ends with -skapers)
```
Pass: the string contains `-skapers`.

### R3 — Kernel version >= 4.0
> Rule: *"You MUST use a kernel version `>= 4.0`..."* (`.specs/rules.md`)
```sh
uname -r | cut -d. -f1       # expect: 6  (>= 4)
```
Pass: the major number is 4 or greater.

### R4 — Kernel sources in /usr/src/kernel-<version>
> Rule: *"The kernel sources MUST live in `/usr/src/kernel-$(version)`."* (`.specs/rules.md`)
```sh
ls -d /usr/src/kernel-*      # expect: /usr/src/kernel-6.13.4
```
Pass: a `/usr/src/kernel-<version>` directory (or symlink) exists.

### R5 — /boot kernel binary named vmlinuz-<version>-<login>
> Rule: *"The kernel binary located in `/boot` MUST be named `vmlinuz-<linux_version>-<student_login>`..."* (`.specs/rules.md`)
```sh
ls /boot/vmlinuz-*-skapers   # expect: /boot/vmlinuz-6.13.4-skapers
```
Pass: a file matching `vmlinuz-*-skapers` exists in `/boot`.

### R6 — At least 3 partitions (root, /boot, swap)
> Rule: *"You MUST use at least 3 different partitions: `root`, `/boot`, and a `swap` partition..."* (`.specs/rules.md`)
```sh
lsblk -o NAME,MOUNTPOINT,FSTYPE,SIZE   # see /, /boot, and [SWAP]
findmnt /        # root partition
findmnt /boot    # separate /boot partition
swapon --show    # active swap
```
Pass: `/` and `/boot` are on separate partitions and swap is active (3+ partitions).

### R7 — Hostname is the login
> Rule: *"The distribution hostname MUST be your student login."* (`.specs/rules.md`)
```sh
hostname                     # expect: skapers
cat /etc/hostname            # expect: skapers
```
Pass: both report `skapers`.

### R8 — Kernel-module loader (udev)
> Rule: *"Your distro MUST implement a kernel-module loader, like `udev`."* (`.specs/rules.md`)
> systemd variant: the loader is `systemd-udevd` (see `docs/03-systemd-deviation.md`).
```sh
systemctl is-active systemd-udevd    # expect: active
lsmod | head                          # expect: a list of loaded modules
modprobe --version                    # module-loading tool present
```
Pass: `systemd-udevd` is active, `modprobe` exists, modules are loaded.

### R9 — Central management software (SysV or SystemD)
> Rule: *"You MUST use software for central management and configuration, like SysV or SystemD."* (`.specs/rules.md`)
```sh
readlink -f /sbin/init       # expect: a path containing 'systemd'
systemctl is-system-running  # expect: running  (degraded is a warning, not a fail)
```
Pass: `/sbin/init` resolves to systemd and systemctl reports the system state.

### R10 — Bootloader (GRUB)
> Rule: *"Your distro MUST boot with a bootloader, like LILO or GRUB."* (`.specs/rules.md`)
```sh
ls /boot/grub/grub.cfg                        # the GRUB config exists
grep 'vmlinuz-.*-skapers' /boot/grub/grub.cfg  # menuentry points at the named kernel
```
Pass: the system booted via GRUB and its config references `vmlinuz-*-skapers`.
(Live proof: the machine reached a login prompt — it booted through GRUB.)

### R11 — FHS-compliant filesystem hierarchy
> Goal: *"Implement a filesystem hierarchy compliant with the standards"* (FHS). (`.specs/goals.md`)
```sh
for d in /bin /sbin /etc /lib /usr/bin /usr/lib /var /boot /root /home /tmp /proc /sys /dev; do
    [ -e "$d" ] && echo "ok   $d" || echo "MISS $d"
done
```
Pass: every directory prints `ok`.

### R12 — Connect to the Internet
> Goal: *"Connect to the Internet."* (`.specs/goals.md`)
```sh
getent hosts gnu.org         # DNS resolution works
ping -c1 -W3 gnu.org         # reachability (ICMP may be blocked → still OK if DNS works)
```
Pass: DNS resolves; ping replies (or DNS alone is acceptable if ICMP is filtered).

### R13 — Can download source code (curl/wget)
> Rule: *"⚠ For evaluation purposes, you MUST be able to download source code. It is strongly recommended to install `curl` or `wget`..."* (`.specs/rules.md`)
```sh
command -v curl || command -v wget
```
Pass: at least one of `curl` / `wget` is on PATH. (Live: try `curl -I https://gnu.org`.)

### R14 — Can install/build packages (toolchain present)
> Rule: *"⚠ For evaluation purposes, you also MUST be able to install packages, so make sure you have everything you need."* (`.specs/rules.md`)
```sh
for c in gcc make tar xz patch; do command -v "$c" || echo "MISSING $c"; done
echo 'int main(){return 0;}' | gcc -xc - -o /tmp/t && echo "gcc builds OK"; rm -f /tmp/t
```
Pass: all five tools resolve and a trivial program compiles.

### R15 — All 68 spec packages installed
> Requirement: *"Install the full set of packages — see [packages](packages.md) for the complete list"* (`.specs/mandatory.md`); the 68 entries of `.specs/packages.md`.
```sh
bash verify/verify.sh                         # see the per-package R15 PASS/FAIL lines
bash verify/verify.sh | grep 'R15'            # focus on the package punch-list
```
Pass: every package prints `[PASS] R15: package present: ...`. The four
SysVinit-path entries (Eudev, Sysklogd, Sysvinit, Udev-lfs Tarball) are probed
via their systemd equivalents (`systemd-udevd`, `journalctl`,
`/sbin/init`→systemd) — see `docs/03-systemd-deviation.md`. Spot-check examples:
```sh
gcc --version; bash --version; vim --version | head -1
ip --version; ps --version; mke2fs -V 2>&1 | head -1
perl -MXML::Parser -e 'print "XML::Parser OK\n"'
journalctl --version; udevadm --version
```

---

## Bonus (only if mandatory is perfect)
> Bonus is graded **only** when `verify.sh` reports `0 failed`.
```sh
bash verify/verify.sh        # must end with: MANDATORY PERFECT — bonus may be graded
# then, as a non-root user:
startx                       # brings up the Xorg + dwm/i3 session (see bonus/)
```

---

Related: `verify/verify.sh`, `verify/compliance-checklist.md`,
`docs/03-systemd-deviation.md`, `docs/06-package-manifest.md`,
`.specs/rules.md`, `.specs/goals.md`, `.specs/mandatory.md`, `.specs/packages.md`.
