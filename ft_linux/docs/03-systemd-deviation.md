# 03 — systemd Deviation (why ft_linux ships systemd, not the SysVinit packages)

## Summary

`ft_linux` is built from the **systemd variant** of the Linux From Scratch book.
The package list in the subject (`.specs/packages.md`) names four packages that
belong to the **SysVinit** code path:

- **Eudev** (#14)
- **Sysklogd** (#57)
- **Sysvinit** (#58)
- **Udev-lfs Tarball** (#63)

We deliberately do **not** build those four. Instead we build **systemd**,
which absorbs all of their roles. This document records that decision, quotes
the exact subject text that permits it, and shows how every *original*
requirement is still satisfied.

---

## What the subject actually permits (verbatim)

### 1. The package list is explicitly mutable

From `.specs/packages.md` (the `ℹ Info` callout directly above the table):

> **Some packages below (vim, bash, grub, udev) are examples. Feel free to
> change them for any equivalent you like.** You are free to use the versions
> you want — the subject prints no explicit version numbers next to any
> package.

`udev` is named as one of those swappable examples, and the line authorizes
swapping *any* listed package "for any equivalent you like." systemd's
`systemd-udevd` is the canonical equivalent of the standalone udev/Eudev.

### 2. Central management may be SysV **or** SystemD

From `.specs/rules.md` (Core software):

> - You MUST use software for central management and configuration, like SysV
>   or SystemD.

And the same allowance is restated in `.specs/mandatory.md` (What's required):

> ... a kernel-module loader (e.g. udev), central management software
> (SysV/SystemD) ...

The subject lists **SysV or SystemD** as equally acceptable. Choosing systemd
is squarely inside the rules — it is one of the two named options.

---

## Substitution table

| Spec list entry (`.specs/packages.md`) | Replaced by | Original role | Where it is satisfied |
|---|---|---|---|
| **Eudev** (#14) | `systemd-udevd` (shipped inside the systemd package) | Kernel-module loader / device manager (`udev`) | systemd's udev daemon auto-loads modules and manages `/dev`. |
| **Udev-lfs Tarball** (#63) | `systemd-udevd` + the udev rules shipped with systemd | The LFS-specific udev rule/config tarball that accompanies a standalone udev | systemd installs its own complete `udev` rules under `/usr/lib/udev/rules.d`, replacing the LFS udev-config tarball. |
| **Sysvinit** (#58) | `systemd` as PID 1 | The init system / central management (`/sbin/init`) | `/sbin/init` is a symlink into systemd; systemd is process 1. |
| **Sysklogd** (#57) | `systemd-journald` | System logging daemon | `systemd-journald` captures kernel + service logs; queried with `journalctl`. |

The other **64** packages are built verbatim from the spec list (one of which,
entry #50, is transcribed in the subject as `Perl)` with a stray trailing
parenthesis — a transcription artifact; it is simply **Perl**).

---

## How each ORIGINAL requirement is still satisfied

The four removed packages each existed to discharge a specific subject
requirement. None of those requirements is dropped — they are re-satisfied by
systemd components.

### Module loader (was: Eudev / Udev-lfs) — requirement R8

`.specs/rules.md`: *"Your distro MUST implement a kernel-module loader, like
`udev`."*

- **systemd-udevd** is the device manager that watches `uevent`s from the
  kernel and **auto-loads matching kernel modules** — exactly udev's job (it
  *is* udev, merged into the systemd source tree upstream).
- The **Kmod** package (still built, spec #37) provides `modprobe`/`lsmod`, the
  module-loading machinery udevd drives.
- `verify.sh` `chk_module_loader` proves it: `systemctl is-active
  systemd-udevd` is `active`, `modprobe` is on PATH, and `lsmod` lists loaded
  modules.

### Central management / configuration (was: Sysvinit) — requirement R9

`.specs/rules.md`: *"You MUST use software for central management and
configuration, like SysV or SystemD."*

- **systemd** is PID 1 and the unit-based service manager — the literal
  "SystemD" option offered by the rule. It manages boot, services, mounts,
  sockets, timers, and targets from one configuration model (`/etc/systemd`,
  `/usr/lib/systemd`).
- `/sbin/init` resolves to systemd.
- `verify.sh` `chk_init_is_systemd` proves it: `readlink -f /sbin/init`
  contains `systemd`, and `systemctl is-system-running` reports the system
  state (a `degraded` state is a warning, not a failure).

### Logging (was: Sysklogd)

Sysklogd's only job is the classic syslog daemon. Under systemd this role is
taken by **systemd-journald**, which collects all kernel and service log
streams into the journal (`journalctl`). This is structured, indexed logging
that fully supersedes the flat `/var/log/messages` model. (There is no separate
"logging" hard-requirement ID in the subject; logging supports the central-
management requirement **R9** and general operability.)

`verify.sh` probes the Sysklogd slot via `journalctl` / the
`systemd-journald` unit, so requirement R15 (all 68 packages) stays green for
this substituted entry.

---

## Auditability

- The SysVinit-path download list is preserved (unbuilt) as a reference
  `sources/wget-list-sysv` so a reviewer can see exactly what was swapped out.
- `docs/06-package-manifest.md` marks each of the four entries as
  `replaced-by-systemd` and points at the systemd build script.
- `verify/compliance-checklist.md` carries the same substitution table in its
  "Notes on the substituted requirements" section.

---

Related: `verify/compliance-checklist.md`, `docs/06-package-manifest.md`,
`verify/verify.sh`, `.specs/packages.md`, `.specs/rules.md`,
`.specs/mandatory.md`.
