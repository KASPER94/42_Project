//! Backend for the `print!` / `println!` macros.
//!
//! Bridges `core::fmt` formatting to the VGA driver. Agent X owns this file
//! (and may route it through the active virtual screen / cursor).

use core::fmt::{self, Write};

/// A `core::fmt::Write` sink that forwards to the VGA text driver.
struct VgaSink;

impl Write for VgaSink {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        crate::vga::print(s);
        Ok(())
    }
}

/// Backend used by `print!` / `println!` — formats `args` to the screen.
pub fn _print(args: fmt::Arguments) {
    // Formatting to the VGA buffer cannot fail; ignore the Result.
    let _ = VgaSink.write_fmt(args);
}

/// Erase the character before the cursor on the active screen.
///
/// Delegates to `vga::backspace()`. Exposed here so higher-level modules
/// (e.g. `screens`) can call it without importing `vga` directly.
pub fn backspace() {
    crate::vga::backspace();
}
