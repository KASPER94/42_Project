#!/usr/bin/env bash
# Assemble a GRUB-bootable ISO from build/kfs1.bin and enforce the 10 MB cap.
set -euo pipefail

ISODIR=build/isodir
mkdir -p "$ISODIR/boot/grub"
cp build/kfs1.bin "$ISODIR/boot/kfs1.bin"
cp grub/grub.cfg  "$ISODIR/boot/grub/grub.cfg"

grub-mkrescue -o build/kfs1.iso "$ISODIR" 2>/dev/null

size=$(stat -c%s build/kfs1.iso)
printf ">> ISO: build/kfs1.iso (%s bytes, %s)\n" "$size" "$(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")"
if [ "$size" -le 10485760 ]; then
    echo "   size <= 10 MB: OK"
else
    echo "   ERROR: ISO exceeds 10 MB" >&2
    exit 1
fi
