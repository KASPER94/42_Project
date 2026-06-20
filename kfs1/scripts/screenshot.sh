#!/usr/bin/env bash
# Boot the ISO headless, wait for the kernel to render, dump the VGA
# framebuffer via the QEMU monitor, and convert it to PNG (build/screen.png).
# The delay matters: dumping too early captures QEMU's "display not initialized"
# placeholder instead of our screen.
set -euo pipefail

DELAY="${1:-7}"

( sleep "$DELAY"; printf 'screendump build/screen.ppm\n'; sleep 1; printf 'quit\n' ) \
  | timeout "$(( DELAY + 18 ))" qemu-system-i386 -cdrom build/kfs1.iso \
        -display none -serial null -monitor stdio -no-reboot >/dev/null 2>&1 || true

if [ ! -s build/screen.ppm ]; then
    echo "screenshot: screendump produced no PPM" >&2
    exit 1
fi

pamscale 2 build/screen.ppm 2>/dev/null | pnmtopng 2>/dev/null > build/screen.png
echo ">> wrote build/screen.png ($(stat -c%s build/screen.png) bytes), mode $(head -c 15 build/screen.ppm | tr '\n' ' ')"
