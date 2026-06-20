#!/usr/bin/env bash
# Compile the kernel inside the build container:
#   1. assemble the multiboot boot stub (boot.s -> ELF32 object)
#   2. build the Rust kernel as a staticlib for the custom i386 target
#   3. link everything with our own linker.ld via `ld`
set -euo pipefail

mkdir -p build

echo ">> [1/3] assembling src/boot.s"
nasm -f elf32 src/boot.s -o build/boot.o

echo ">> [2/3] building Rust staticlib (i386-kfs, build-std)"
cargo build --release

echo ">> [3/3] linking build/kfs1.bin"
ld -m elf_i386 -n -T linker.ld -o build/kfs1.bin \
    build/boot.o \
    target/i386-kfs/release/libkfs1.a

echo ">> verifying multiboot header"
if grub-file --is-x86-multiboot build/kfs1.bin; then
    echo "   multiboot: OK"
else
    echo "   multiboot: FAILED" >&2
    exit 1
fi
