# KFS_1 — Grub, boot and screen

A freestanding **i386** kernel written in **Rust**, GRUB-booted via Multiboot v1,
that displays `42` on the screen. First project of the 42 *Kernel From Scratch*
series. The full subject is broken down in [`.specs/`](.specs/README.md).

## Build & run

Everything runs inside an **amd64 Linux container** (the i386/GRUB toolchain is
not native to Apple-Silicon macOS). You only need Docker.

```sh
make image       # build the toolchain image (once)
make iso         # -> build/kfs1.iso  (asserts <= 10 MB)
make run         # boot headless in QEMU, serial -> stdout
make screenshot  # boot + capture build/screen.png (shows "42")
make smoke       # CI: boot and assert the kernel reaches Rust
make debug       # QEMU stopped on :1234 for gdb
make shell       # interactive shell in the toolchain container
make clean
```

## How it builds

1. `nasm` assembles `src/boot.s` (Multiboot v1 header, stack, zero `.bss`, `call kmain`).
2. `cargo` builds the Rust kernel as a **staticlib** for the custom bare-metal
   target `i386-kfs.json` (nightly + `-Zbuild-std`, soft-float, `panic=abort`).
3. **Our own** `linker.ld` links them with `ld -m elf_i386` → `build/kfs1.bin`
   (loaded at 1 MiB).
4. `grub-mkrescue` packages a bootable ISO.

## Layout

| Path | Role |
|---|---|
| `src/boot.s`, `linker.ld` | Multiboot boot stub + custom linker script |
| `src/lib.rs` | `#![no_std]` entry (`kmain`), panic handler, `print!` macros, main loop |
| `src/vga.rs` | VGA text driver (0xB8000): write, scroll, colours, hardware cursor, backspace |
| `src/console.rs` | `core::fmt::Write` backend for `print!`/`println!` |
| `src/keyboard.rs` | PS/2 keyboard polling (scancode set 1, US QWERTY, modifiers) |
| `src/screens.rs` | 4 virtual screens, switched with F1–F4 |
| `src/libk/` | kernel library: types, `strlen`/`strcmp`/`strncmp` |
| `Dockerfile`, `Makefile`, `scripts/` | toolchain + build/run automation |
| `CONTRACTS.md` | internal interface spec (entry ABI, memory layout, module surface) |

## Status

**Mandatory** ✓ — GRUB boot, ASM base, kernel lib, screen interface, displays
`42`, custom linker, Makefile, i386, freestanding, ISO 4.9 MB (≤ 10 MB).

**Bonus** ✓ — scroll, hardware cursor, colours, `printk`-style `print!`/`println!`,
PS/2 keyboard input, multiple virtual screens with F1–F4 switching.
