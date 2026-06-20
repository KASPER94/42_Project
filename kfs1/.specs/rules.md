# Rules / Constraints

Hard requirements the kernel MUST satisfy. (Sourced from chapter III — General
instructions, and chapter IV — Mandatory part.)

## Architecture (III.4)

- The **i386 (x86)** architecture is **mandatory**.

## Compilation flags (III.2.2)

To boot without any dependencies, you MUST compile with freestanding flags.
The subject lists a C++ example — adapt them to your language:

- `-fno-builtin`
- `-fno-exception`
- `-fno-stack-protector`
- `-fno-rtti`
- `-nostdlib`
- `-nodefaultlibs`

> Pay special attention to `-nodefaultlibs` and `-nostdlib`. The kernel is
> compiled on a host system, but it **cannot be linked to any host library**,
> otherwise it will not execute.

## Linking (III.3)

- You **cannot** use an existing/host linker script to link your kernel — it
  won't boot. You **must create your own linker file**.
- You **CAN** use the `ld` binary available on your host.
- You **CANNOT** use the host's `.ld` file.

## Size

- Your work / virtual image **must not exceed 10 MB**. (Repeated in
  [submission & evaluation](submission-evaluation.md).)

## Tooling note

- A **Makefile must be turned in** (III.2.1). See [mandatory](mandatory.md).

---

Related: [general instructions](general-instructions.md),
[mandatory part](mandatory.md), [submission & evaluation](submission-evaluation.md).
