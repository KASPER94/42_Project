; KFS_1 boot stub — Agent A final version
; Architecture: i386, 32-bit protected mode (NASM [bits 32])
;
; GRUB reads the Multiboot v1 header, enters 32-bit protected mode, loads
; the kernel ELF segments, then jumps to _start with:
;   EAX = 0x2BADB002  (multiboot magic — proof that a compliant loader ran)
;   EBX = physical address of the multiboot_info structure
;
; We set up our own stack and zero .bss ourselves before calling into Rust.

[bits 32]

; ---- Multiboot v1 header constants -----------------------------------------
MBALIGN  equ 1 << 0          ; bit 0: align loaded modules on page boundaries
MEMINFO  equ 1 << 1          ; bit 1: provide memory map via multiboot_info
MBFLAGS  equ MBALIGN | MEMINFO
MAGIC    equ 0x1BADB002      ; multiboot v1 magic that GRUB looks for
CHECKSUM equ -(MAGIC + MBFLAGS) ; must make magic+flags+checksum == 0 (mod 2^32)

; ---- Multiboot v1 header ----------------------------------------------------
; Must be 4-byte aligned and appear within the first 8 KiB of the kernel image.
; The linker script places .multiboot_header at the very start (1 MiB).
section .multiboot_header
align 4
    dd MAGIC
    dd MBFLAGS
    dd CHECKSUM

; ---- Stack ------------------------------------------------------------------
; 16 KiB stack in .bss (uninitialised).  stack_top is the *high* address
; because x86 stacks grow downward.
section .bss
align 16
stack_bottom:
    resb 16384          ; 16 KiB
stack_top:

; ---- Entry point ------------------------------------------------------------
section .text
global _start
extern kmain

; Linker-exported .bss boundary symbols (defined in linker.ld).
extern _bss_start
extern _bss_end

_start:
    ; 1. Set up the stack pointer.
    ;    We can write to the stack immediately — it lives in .bss, and the
    ;    writes ARE the zeroing for that range.  We zero all of .bss below
    ;    before any Rust static storage is accessed.
    mov esp, stack_top

    ; 2. Preserve the Multiboot registers (EAX, EBX) across the BSS-zero loop.
    ;    rep stosd clobbers EAX (fill value), ECX (count), and EDI (pointer),
    ;    but NOT EBX or EDX.  Move original EAX into EDX so it survives.
    mov edx, eax            ; EDX = multiboot magic (0x2BADB002)
    ;    EBX = multiboot info pointer (unchanged by the loop below)

    ; 3. Zero the entire .bss section.
    ;    Multiboot v1 does NOT guarantee that .bss is zeroed on entry.
    ;    We use rep stosd (4 bytes at a time) for speed.
    ;    _bss_start and _bss_end are provided by linker.ld and are 4-byte
    ;    aligned (both .bss and the symbols use ALIGN(4K) / ALIGN(4)).
    mov edi, _bss_start     ; destination
    mov ecx, _bss_end
    sub ecx, edi            ; byte count
    shr ecx, 2              ; -> dword count
    xor eax, eax            ; fill value = 0
    rep stosd               ; zero .bss

    ; 4. Call kmain using the cdecl calling convention.
    ;    Rust signature: pub extern "C" fn kmain(magic: u32, info: u32) -> !
    ;    First argument  (pushed last in cdecl) = multiboot_magic  <- EDX
    ;    Second argument (pushed first in cdecl, lower address)    <- EBX
    ;
    ;    cdecl: arguments are pushed right-to-left, so:
    ;      push info  (EBX — second arg, pushed first so it ends up at [esp+8])
    ;      push magic (EDX — first arg,  pushed last  so it ends up at [esp+4])
    push ebx                ; arg2: multiboot_info  pointer (u32)
    push edx                ; arg1: multiboot_magic (u32)   = 0x2BADB002
    call kmain              ; never returns (-> !)

    ; 5. Safety hang: kmain must not return, but be defensive.
.hang:
    cli
    hlt
    jmp .hang

; ---- GNU stack note ---------------------------------------------------------
; Silences the "missing .note.GNU-stack section implies executable stack"
; warning that ld emits when linking objects that do not declare stack
; permissions.  This section tells the linker our stack is non-executable.
section .note.GNU-stack noalloc noexec nowrite progbits
