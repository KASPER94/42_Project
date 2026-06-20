# Mandatory Part

The mandatory part (chapter IV) is the core deliverable: a basic but functional
Linux distribution that satisfies every hard requirement.

## What's required

- Build the Linux kernel and install the required binaries.
- Install the full set of packages — see [packages](packages.md) for the
  complete list (versions are your choice; some entries are examples that may
  be swapped for equivalents).
- Satisfy all the hard constraints collected in [rules](rules.md): VM, kernel
  `>= 4.0`, sources in `/usr/src/kernel-$(version)`, at least 3 partitions
  (root, /boot, swap), a kernel-module loader (e.g. udev), central management
  software (SysV/SystemD), a bootloader (LILO/GRUB), the kernel version string
  and hostname containing your student login, and the `/boot` kernel binary
  named `vmlinuz-<linux_version>-<student_login>`.

## Evaluation prerequisites

> ⚠ For evaluation purposes, you must be able to download source code. It is
> strongly recommended to install `curl`, `wget`, or any equivalent tool.

> ⚠ For evaluation purposes, you must also be able to install packages, so make
> sure you have everything you need.

---

Related: [packages](packages.md), [rules](rules.md), [goals](goals.md),
[bonus](bonus.md), [submission & evaluation](submission-evaluation.md).
