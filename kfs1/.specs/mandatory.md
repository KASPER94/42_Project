# Mandatory Part

The mandatory part (chapter IV) is the core deliverable: a kernel, bootable with
GRUB, that can write characters on screen.

## Base (IV.0.1)

You must make a kernel, bootable with GRUB, that writes characters on screen. To
do that:

- **Install GRUB** on a virtual image.
- Write an **ASM boot code** that handles the **multiboot header**, and use GRUB
  to init and call the kernel's main function.
- Write the **basic kernel code** in your chosen language.
- **Compile** with the correct flags and **link** it to make it bootable
  (see [rules](rules.md)).
- Then write **helpers** — kernel types and basic functions (`strlen`,
  `strcmp`, ...).
- Your work **must not exceed 10 MB**.
- Code the **interface between your kernel and the screen**.
- **Display `"42"`** on the screen.

For the link part, you **must create a linker file** with the GNU linker (`ld`).
(The subject points to docs via a "here" link embedded in the PDF — see
[resources](resources.md).)

## Makefile (IV.0.2)

- The Makefile must compile **all** source files with the **right flags** and
  the **right compiler**.
- The kernel uses **at least two languages** (ASM + whatever-you-choose), so
  write your Makefile rules accordingly.
- After compilation, **all objects must be linked together** to create the final
  kernel binary (see the Linker part in [rules](rules.md)).

---

Related: [rules](rules.md), [goals](goals.md), [bonus](bonus.md),
[submission & evaluation](submission-evaluation.md).
