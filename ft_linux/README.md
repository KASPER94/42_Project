# ft_linux

Build a basic-but-functional **Linux From Scratch (LFS)** distribution entirely
from source, inside a virtual machine — the foundation for later kernel
projects. (42 project *how_to_train_your_kernel*, spec v3.6.)

**Profile:** LFS **systemd** variant · **64-bit** · **GRUB** bootloader ·
**VirtualBox** · student login **`skapers`** · kernel **6.x** (>= 4.0 required).

## What this repository is

This repo is **not** the operating system — it is the **automation suite that
builds it**. It is a collection of bash scripts, configs, and docs that *you
run inside a VM* to produce the ft_linux disk image (`disk.vdi`). The disk image
itself, and the downloaded source tarballs, are **never committed** (see
`.gitignore`) — only the scripts/configs/docs and the final `shasum.txt`.

The build (cross-toolchain → 68 packages → kernel → GRUB → reboot) takes many
hours and involves `chroot`, `menuconfig`, and reboots, so it cannot run on a
plain macOS host. The suite is authored to be **run by you in the build VM**.

## Quickstart

The full, ordered procedure is in **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)**. In
brief, inside the VM:

```sh
# 1. Create the build VM + attach the empty target disk   (see vm/)
# 2. Edit env/ if needed (confirm $LFS_DISK points at the TARGET disk!)
# 3. Download sources
bash sources/download-sources.sh && bash sources/verify-sources.sh
# 4. Run the whole pipeline (idempotent / resumable)
./run-all.sh --yes
# 5. Reboot into ft_linux, then self-check
sudo bash verify/verify.sh        # must report 0 failures
# 6. (bonus) Xorg + window manager
bash bonus/run-bonus.sh
# 7. Produce the submission checksum (host-side, VM powered off)
bash submit/checksum.sh
```

`run-all.sh` is idempotent and resumable: a crash mid-build resumes by
fast-forwarding past completed steps (markers under `$LFS/.ft_state`).

## Directory map

```
env/      single source of truth   — login, package versions/URLs, disk paths
lib/      shared bash               — logging, state markers, chroot, build_package
vm/       VirtualBox / Vagrant      — create + provision the build host
sources/  download + verify         — wget-list, md5sums
scripts/  the core pipeline         — partition → toolchain → chroot → final → kernel → grub
bonus/    BLFS                       — Xorg + dwm/i3 (gated on a clean verify)
verify/   self-check                — verify.sh + compliance checklist
submit/   checksum.sh               — host-side shasum of disk.vdi
docs/     RUNBOOK + walkthroughs    — start here
```

See **[`CLAUDE.md`](CLAUDE.md)** for the critical compliance invariants and the
project conventions every script follows.
