/* KFS_1 linker script — Agent A final version
 *
 * Loads the kernel at 1 MiB (physical).  The Multiboot v1 header is placed
 * first so GRUB can find it within the required 8 KiB window.
 *
 * Exported symbols used by src/boot.s:
 *   _bss_start  — first byte of the .bss section (for BSS zeroing loop)
 *   _bss_end    — one-past-last byte of .bss    (for BSS zeroing loop)
 *   _kernel_end — one-past-last byte of the whole kernel image
 */

ENTRY(_start)

SECTIONS
{
    /* Load address: 1 MiB (0x00100000).  Chosen because the first MiB of
     * physical memory is reserved (real-mode IVT, BIOS data, VGA, etc.) and
     * GRUB itself lives below 1 MiB.  Loading above keeps us out of that mess.
     */
    . = 1M;

    /* .multiboot_header must be within the first 8 KiB of the image so GRUB
     * can find the magic dword.  Placed first with KEEP so the linker never
     * discards it as "unreferenced".
     */
    .multiboot_header :
    {
        KEEP(*(.multiboot_header))
    }

    /* Executable code. */
    .text ALIGN(4K) :
    {
        *(.text .text.*)
    }

    /* Read-only data (string literals, const statics, etc.). */
    .rodata ALIGN(4K) :
    {
        *(.rodata .rodata.*)
    }

    /* Initialised read-write data. */
    .data ALIGN(4K) :
    {
        *(.data .data.*)
    }

    /* Uninitialised data.  boot.s zeros this region before calling kmain.
     * _bss_start / _bss_end are consumed by the rep stosd loop in boot.s.
     * Both are aligned to 4 bytes so that the dword-count (shr ecx, 2) is exact.
     */
    .bss ALIGN(4K) :
    {
        _bss_start = .;         /* exported: start of BSS (4K-aligned) */
        *(COMMON)               /* tentative (common) symbols from C/Rust */
        *(.bss .bss.*)
        . = ALIGN(4);           /* ensure _bss_end is 4-byte aligned */
        _bss_end = .;           /* exported: one-past-end of BSS */
    }

    /* Marks the end of the kernel image — useful for the memory allocator
     * (Agent B/C) to know where free physical memory begins.
     */
    _kernel_end = .;
}
