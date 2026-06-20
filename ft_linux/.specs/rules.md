# Rules / Constraints

Hard requirements that the distribution MUST satisfy. (Sourced from the
General instructions and the Mandatory part of the subject.)

## System & environment

- You MUST use a virtual machine (for example, VirtualBox or VMware).
- You're free to choose between a 32-bit or 64-bit system.

## Kernel

- You MUST use a kernel version `>= 4.0` (stable or not, as long as it's a
  `>= 4.0` version).
- The kernel sources MUST live in `/usr/src/kernel-$(version)`.
- The kernel version string MUST contain your student login, e.g.
  `Linux kernel 4.1.2-<student_login>`.
- The kernel binary located in `/boot` MUST be named
  `vmlinuz-<linux_version>-<student_login>`. Adapt your bootloader
  configuration to that.

## Partitions

- You MUST use at least 3 different partitions: `root`, `/boot`, and a `swap`
  partition. You may make more partitions if you want.

## Identity

- The distribution hostname MUST be your student login.

## Core software

- Your distro MUST implement a kernel-module loader, like `udev`.
- You MUST use software for central management and configuration, like SysV or
  SystemD.
- Your distro MUST boot with a bootloader, like LILO or GRUB.

## Evaluation prerequisites (warnings)

> ⚠ For evaluation purposes, you MUST be able to download source code. It is
> strongly recommended to install `curl` or `wget` or any other equivalent
> tool.

> ⚠ For evaluation purposes, you also MUST be able to install packages, so make
> sure you have everything you need.

---

Related: [general instructions](general-instructions.md),
[mandatory part](mandatory.md), [packages](packages.md).
