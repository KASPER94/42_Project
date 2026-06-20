//! Multiple virtual text screens with a keyboard switch shortcut.
//!
//! Maintains `NUM_SCREENS` independent text screens. Only the active screen is
//! shown in the live VGA framebuffer; the others are kept in backing buffers.
//! Pressing **F1..F4** switches screens: the live framebuffer + cursor of the
//! outgoing screen are saved, and the incoming screen's buffer + cursor are
//! restored.
//!
//! Printable keystrokes are echoed to the active screen (and mirrored to serial
//! so headless tests can observe input). Backspace erases the previous cell.

use crate::keyboard::{Key, KeyEvent};
use crate::vga::{self, BUFFER_BYTES};

/// Number of virtual screens (switched with F1..F4).
pub const NUM_SCREENS: usize = 4;

/// Saved state of one virtual screen while it is not the active one.
#[derive(Copy, Clone)]
struct Screen {
    buffer: [u8; BUFFER_BYTES],
    col: usize,
    row: usize,
}

impl Screen {
    const fn new() -> Self {
        Screen { buffer: [0; BUFFER_BYTES], col: 0, row: 0 }
    }
}

/// Screen manager: the backing store for inactive screens + the active index.
struct Manager {
    screens: [Screen; NUM_SCREENS],
    active: usize,
}

/// Global screen manager. Single-threaded kernel; accessed via `addr_of_mut!`
/// to avoid the `static_mut_refs` lint (same pattern as `vga::WRITER`).
static mut MANAGER: Manager = Manager {
    screens: [Screen::new(); NUM_SCREENS],
    active: 0,
};

#[inline(always)]
fn manager() -> &'static mut Manager {
    // Safety: single-threaded; one &mut at a time.
    unsafe { &mut *core::ptr::addr_of_mut!(MANAGER) }
}

/// Initialise the screen manager and clear the (active) screen 0.
pub fn init() {
    vga::init();
    let m = manager();
    m.active = 0;
    // Backing buffers start zeroed (.bss); their cursors at (0, 0).
}

/// Switch the active screen to `target` (no-op if already active or invalid).
///
/// Saves the live framebuffer + cursor into the current screen's backing store,
/// then loads the target screen's backing store and cursor into the live VGA
/// framebuffer.
pub fn switch_to(target: usize) {
    if target >= NUM_SCREENS {
        return;
    }
    let m = manager();
    if target == m.active {
        return;
    }

    // Save the outgoing screen.
    let cur = m.active;
    let (col, row) = vga::cursor();
    m.screens[cur].col = col;
    m.screens[cur].row = row;
    vga::save_buffer(&mut m.screens[cur].buffer);

    // Restore the incoming screen.
    m.active = target;
    vga::load_buffer(&m.screens[target].buffer);
    vga::set_cursor(m.screens[target].col, m.screens[target].row);
}

/// The currently active virtual screen index.
pub fn active() -> usize {
    manager().active
}

/// Route a keyboard event: F1..F4 switch screens; Backspace erases; other
/// printable characters are echoed to the active screen and mirrored to serial.
pub fn handle_key(event: KeyEvent) {
    match event.key {
        Key::Function(n) if (1..=NUM_SCREENS as u8).contains(&n) => {
            switch_to((n - 1) as usize);
        }
        Key::Function(_) => { /* F5..F12: no screen assigned */ }
        Key::Backspace => vga::backspace(),
        _ => {
            if let Some(c) = event.as_char() {
                vga::print_char(c);
                // Mirror typed chars to serial so headless tests can assert input.
                unsafe { crate::outb(0x3F8, c) };
            }
        }
    }
}
