# KFS_1 — Inter-agent contracts

This is the **source of truth** for the seams between workstreams. The
foundation (toolchain + pipeline) is proven working: `make smoke` boots the ISO
in QEMU and confirms the kernel reaches Rust. Agents A/B/C replace the stub
implementations **without changing these interfaces**.

## Build pipeline (do not break)

Everything runs inside the `kfs1-toolchain` amd64 container via the `Makefile`.

```
make image   # build the toolchain image (once)
make build   # nasm boot.s -> boot.o ; cargo staticlib -> libkfs1.a ; ld -> build/kfs1.bin
make iso     # grub-mkrescue -> build/kfs1.iso  (asserts <= 10 MB)
make smoke   # headless QEMU boot, asserts serial marker (CI check)
make run     # headless QEMU, serial -> stdout
make screenshot  # dump VGA framebuffer to build/screen.ppm (verify "42")
make debug   # QEMU stopped on :1234 for gdb
make shell   # interactive shell in the container
make clean
```

Link step (`scripts/build.sh`):
`ld -m elf_i386 -n -T linker.ld -o build/kfs1.bin build/boot.o target/i386-kfs/release/libkfs1.a`

## Toolchain facts

- Host is arm64; the container is **`linux/amd64`** (so `grub-pc-bin` exists).
- Rust **nightly** + `rust-src`, custom target **`i386-kfs.json`** (i686,
  `os=none`, **soft-float**, `panic=abort`), built with
  `-Zbuild-std=core,compiler_builtins` + `compiler-builtins-mem` +
  `json-target-spec` (see `.cargo/config.toml`).
- `compiler-builtins-mem` provides `memcpy/memset/memmove/memcmp` — **do not
  hand-roll** these (duplicate symbols will fail the link).

## Entry contract (Agent A ↔ Agent B)

- Linker: `ENTRY(_start)`.
- `src/boot.s` (NASM, `[bits 32]`): `global _start`, `extern kmain`. Sets up a
  16 KiB stack (`.bss`), then (cdecl) `push ebx` (multiboot info ptr), `push eax`
  (multiboot magic `0x2BADB002`), `call kmain`, then `cli; hlt` loop.
- `src/lib.rs` (Agent B): the crate is `#![no_std]`, **staticlib**, and exports
  ```rust
  #[no_mangle]
  pub extern "C" fn kmain(multiboot_magic: u32, multiboot_info: u32) -> ! { ... }
  ```
  Plus the single `#[panic_handler]`. `kmain` must never return.
- NASM nit: add `section .note.GNU-stack noalloc noexec nowrite progbits` to
  `boot.s` to silence the exec-stack linker warning.

## Memory layout (Agent A)

- Load at **1 MiB** (`. = 1M;`).
- Sections in order: `.multiboot_header` (KEEP, first), `.text`, `.rodata`,
  `.data`, `.bss` (incl. `COMMON`); export `_kernel_end`.
- Multiboot **v1** header: magic `0x1BADB002`, flags `MBALIGN|MEMINFO`,
  `checksum = -(magic+flags)`.

## Module surface (Agent B ↔ Agent C)

- `src/lib.rs` declares `mod vga;` and `mod libk;` and owns the `kmain` body.
- Agent C provides:
  - `src/vga.rs` — VGA text driver at **`0xB8000`**, 80×25, 2 bytes/cell
    (byte 0 = ASCII, byte 1 = attribute `bg<<4 | fg`). Public API at least:
    `vga::init()` / `vga::clear()` and a way to write a string. Must **display
    `42`** (top-left is fine).
  - `src/libk/` — kernel helpers: basic types, `strlen`, `strcmp` (and friends).
    Do **not** redefine `memcpy/memset/...` (provided by compiler-builtins-mem).
- Integration: B's `kmain` calls `vga::init()` then prints `42`.

## Debugging aids

- **Serial (COM1):** `outb(0x3F8, byte)` is echoed by `make run`/`smoke` — the
  fastest headless signal. The stub already prints `KFS1_BOOT_OK`.
- **VGA screenshot:** `make screenshot` → `build/screen.ppm` to visually confirm
  `42`.
- **gdb:** `make debug`, then in the container/host `gdb build/kfs1.bin` →
  `target remote :1234` → `break kmain`.

## File ownership (keep merges additive)

| Owner | Files |
|---|---|
| Foundation (done) | `Dockerfile`, `Makefile`, `scripts/*`, `Cargo.toml`, `.cargo/config.toml`, `rust-toolchain.toml`, `i386-kfs.json`, `grub/grub.cfg`, `CONTRACTS.md` |
| Agent A | `src/boot.s`, `linker.ld` (own them fully) |
| Agent B | `src/lib.rs` (owns the `mod` lines + `kmain` + panic handler) |
| Agent C | `src/vga.rs`, `src/libk/**` (new files) |

Only shared edit point: the `mod`/call lines in `src/lib.rs` — Agent B owns them;
Agent C delivers the modules B calls.
