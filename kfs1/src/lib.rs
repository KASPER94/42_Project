//! KFS_1 kernel — `#![no_std]` staticlib crate root.
//!
//! Provides the Rust kernel entry point (`kmain`) called by the NASM boot stub
//! (`_start` in `src/boot.s`) after GRUB hands control over in 32-bit
//! protected mode.
//!
//! Module layout
//! ─────────────
//!   lib.rs      — entry point, panic handler, print! macros, main loop
//!   vga.rs      — VGA text-mode driver (0xB8000, 80×25, scroll, colours, cursor)
//!   console.rs  — `core::fmt::Write` glue behind print!/println!
//!   keyboard.rs — PS/2 keyboard polling (port 0x60, scancode set 1)
//!   screens.rs  — multiple virtual screens + switch shortcut
//!   libk/       — kernel library (types, C-string helpers)
#![no_std]

pub mod console;
pub mod keyboard;
pub mod libk;
pub mod screens;
pub mod vga;

use core::panic::PanicInfo;

// ── print!/println! ────────────────────────────────────────────────────────────

/// Print formatted text to the active screen (no newline).
#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => ($crate::console::_print(format_args!($($arg)*)));
}

/// Print formatted text to the active screen, followed by a newline.
#[macro_export]
macro_rules! println {
    ()              => ($crate::print!("\n"));
    ($($arg:tt)*)   => ($crate::print!("{}\n", format_args!($($arg)*)));
}

// ── I/O helpers ──────────────────────────────────────────────────────────────

/// Write a byte to an x86 I/O port.
///
/// # Safety
/// `port` must be a valid, writable I/O port for the current privilege level.
#[inline(always)]
pub unsafe fn outb(port: u16, value: u8) {
    // Safety: `out dx, al` is privileged (ring 0); valid in the kernel.
    unsafe {
        core::arch::asm!(
            "out dx, al",
            in("dx") port,
            in("al") value,
            options(nomem, nostack, preserves_flags),
        );
    }
}

/// Read a byte from an x86 I/O port.
///
/// # Safety
/// `port` must be a valid, readable I/O port for the current privilege level.
#[inline(always)]
pub unsafe fn inb(port: u16) -> u8 {
    let value: u8;
    // Safety: `in al, dx` is privileged (ring 0); valid in the kernel.
    unsafe {
        core::arch::asm!(
            "in al, dx",
            out("al") value,
            in("dx") port,
            options(nomem, nostack, preserves_flags),
        );
    }
    value
}

/// Emit every byte of a string slice to serial COM1 (port 0x3F8).
pub fn serial_print(s: &str) {
    for &b in s.as_bytes() {
        // Safety: 0x3F8 is COM1 data register; always writable at ring 0.
        unsafe { outb(0x3F8, b) };
    }
}

/// Halt the CPU forever.
fn halt() -> ! {
    loop {
        // Safety: `hlt` is privileged (ring 0); the loop never returns.
        unsafe { core::arch::asm!("hlt", options(nomem, nostack)) };
    }
}

// ── Entry point ──────────────────────────────────────────────────────────────

/// Kernel entry point — called by `boot.s` via cdecl after GRUB boots.
///
/// Must never return (GRUB has no place to return to).
#[no_mangle]
pub extern "C" fn kmain(_multiboot_magic: u32, _multiboot_info: u32) -> ! {
    screens::init(); // sets up the virtual screens and clears screen 0

    // Mandatory output.
    println!("42");
    serial_print("42\nKFS1_BOOT_OK\n");

    keyboard::init();

    // Main loop: poll the keyboard, route key events to the screen manager
    // (printable chars are echoed; Fn keys switch virtual screens).
    loop {
        if let Some(event) = keyboard::poll() {
            screens::handle_key(event);
        }
        core::hint::spin_loop();
    }
}

// ── Panic handler ────────────────────────────────────────────────────────────

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    serial_print("KERNEL PANIC\n");
    halt();
}
