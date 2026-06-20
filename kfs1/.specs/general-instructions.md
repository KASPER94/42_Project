# General Instructions

Process guidance from chapter III. The softer "how to work" notes are here; the
hard constraints are collected in [rules](rules.md).

## Emulation (III.1.1)

- Not mandatory: you are free to use any virtual manager.
- Recommended: **KVM** (Kernel Virtual Manager) — it has advanced execution and
  debug functions. All examples in the subject use KVM.

## Language (III.1.2)

- No constraint on the language. C is **not** mandatory.
- But not all languages are kernel-friendly. You *could* write a kernel in
  JavaScript — but should you?
- Most documentation examples are in C, so a different language means constant
  "code translation".
- Not all language features work in a basic kernel. Example: C++ `new`, classes
  and structure declarations need a memory interface you don't have yet, so they
  can't be used at the beginning.
- Viable alternatives to C include **C++, Rust, Go**, etc. You could even write
  the whole kernel in **ASM**.
- *Choose a language, but choose wisely.*

## Compilation (III.2)

- **Compilers (III.2.1):** any compiler you want. The author uses **gcc** and
  **nasm**. A **Makefile must be turned in**.
- **Flags (III.2.2):** see [rules](rules.md) — the freestanding flags are a hard
  requirement, not a suggestion.

## Linking (III.3) & Architecture (III.4)

Both are hard constraints — see [rules](rules.md).

## Documentation (III.5)

There is a lot of documentation, good and bad. The recommended reference is the
**OSDev wiki**. See [resources](resources.md).

---

Related: [rules](rules.md), [resources](resources.md),
[mandatory part](mandatory.md).
