# KFS_1 — Spec Index

Semantic breakdown of the KFS_1 subject ("Grub, boot and screen", version 1).
Each file below covers one aspect of the subject. The source of truth is the
verbatim parse at [`raw/subject.md`](raw/subject.md).

## Files

- [00-overview.md](00-overview.md) — What the project is: title, version,
  summary, introduction, and high-level purpose.
- [goals.md](goals.md) — The concrete objectives (boot via GRUB, ASM base,
  kernel lib, screen output, "Hello world" / display `42`).
- [general-instructions.md](general-instructions.md) — Process guidance:
  emulation (KVM), language choice, compilation, documentation (OSDev).
- [rules.md](rules.md) — The hard constraints: i386 (x86), freestanding compile
  flags, custom linker file, the 10 MB limit, mandatory Makefile.
- [mandatory.md](mandatory.md) — The mandatory part: bootable kernel base +
  Makefile requirements.
- [bonus.md](bonus.md) — The bonus part (only graded if the mandatory part is
  perfect).
- [resources.md](resources.md) — Reference material: OSDev wiki, GNU `ld` docs,
  and common starting points.
- [submission-evaluation.md](submission-evaluation.md) — Git submission rules
  and the virtual-image / 10 MB requirement.

## Source

- [raw/subject.md](raw/subject.md) — Verbatim PDF parse; the source of truth for
  everything above.
