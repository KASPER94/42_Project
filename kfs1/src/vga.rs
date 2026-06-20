//! VGA text-mode driver.
//!
//! Drives the VGA text buffer at physical address `0xB8000`.
//! Mode: 80 columns × 25 rows, 2 bytes per cell:
//!   byte 0 — ASCII character code
//!   byte 1 — colour attribute: `(background << 4) | foreground`
//!
//! All reads/writes to the hardware buffer use `core::ptr::write_volatile` so
//! the compiler cannot cache or elide them.

use core::ptr::write_volatile;

// ── Constants ────────────────────────────────────────────────────────────────

/// Physical address of the VGA text framebuffer.
const VGA_BUFFER: usize = 0xB8000;

pub const COLS: usize = 80;
pub const ROWS: usize = 25;

/// Size in bytes of one full text screen (`COLS * ROWS` cells × 2 bytes/cell).
pub const BUFFER_BYTES: usize = COLS * ROWS * 2;

/// VGA CRTC index and data ports (I/O-mapped registers).
const CRTC_INDEX: u16 = 0x3D4;
const CRTC_DATA: u16 = 0x3D5;

/// CRTC register indices for the cursor position.
const CRTC_CURSOR_HI: u8 = 0x0E;
const CRTC_CURSOR_LO: u8 = 0x0F;

// ── Colour definitions ───────────────────────────────────────────────────────

/// Standard 4-bit VGA palette index.
#[allow(dead_code)]
#[repr(u8)]
#[derive(Copy, Clone)]
pub enum Color {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    Pink = 13,
    Yellow = 14,
    White = 15,
}

/// Pack a foreground/background pair into a VGA attribute byte.
#[inline(always)]
pub const fn make_attr(fg: Color, bg: Color) -> u8 {
    ((bg as u8) << 4) | (fg as u8)
}

// ── Writer ───────────────────────────────────────────────────────────────────

/// Global VGA writer; initialised by `init()`.
///
/// Using a plain global (no mutex) is safe here because the kernel is
/// single-threaded at this stage.
static mut WRITER: Writer = Writer {
    col: 0,
    row: 0,
    attr: make_attr(Color::White, Color::Black),
};

/// Stateful writer that tracks the current cursor position and colour.
pub struct Writer {
    col: usize,
    row: usize,
    attr: u8,
}

impl Writer {
    /// Overwrite every cell with a space in the current attribute, reset cursor.
    pub fn clear(&mut self) {
        for row in 0..ROWS {
            for col in 0..COLS {
                // Safety: index is always within the 80×25 VGA buffer.
                unsafe { self.write_cell(col, row, b' ') };
            }
        }
        self.col = 0;
        self.row = 0;
        self.update_cursor();
    }

    /// Set the foreground/background colour for subsequent writes.
    #[inline(always)]
    pub fn set_color(&mut self, fg: Color, bg: Color) {
        self.attr = make_attr(fg, bg);
    }

    /// Write a single byte at (col, row) using `write_volatile`.
    ///
    /// # Safety
    /// `col` and `row` must be within [0, COLS) and [0, ROWS) respectively.
    unsafe fn write_cell(&self, col: usize, row: usize, byte: u8) {
        let offset = (row * COLS + col) * 2;
        let ptr = (VGA_BUFFER + offset) as *mut u8;
        // Safety: `ptr` is within the 80×25 VGA text buffer; volatile write
        // ensures the store reaches hardware and is not optimised away.
        unsafe {
            write_volatile(ptr, byte);
            write_volatile(ptr.add(1), self.attr);
        }
    }

    /// Write a single ASCII byte and advance the cursor.
    ///
    /// `\n` moves to the next row (with scroll if needed).  All other bytes
    /// are written as-is.
    pub fn write_byte(&mut self, byte: u8) {
        match byte {
            b'\n' => {
                self.col = 0;
                self.advance_row();
            }
            _ => {
                if self.col >= COLS {
                    self.col = 0;
                    self.advance_row();
                }
                // Safety: col < COLS and row < ROWS after the checks above.
                unsafe { self.write_cell(self.col, self.row, byte) };
                self.col += 1;
            }
        }
        self.update_cursor();
    }

    /// Write every byte of a UTF-8 string slice (non-ASCII bytes printed as-is).
    pub fn write_str(&mut self, s: &str) {
        for byte in s.bytes() {
            self.write_byte(byte);
        }
    }

    /// Erase the previous character (move back one cell, write a space, leave
    /// cursor on the blank cell).
    ///
    /// Behaviour at column 0: wrap to the last column of the previous row.
    /// Never moves above row 0.
    pub fn backspace(&mut self) {
        if self.col > 0 {
            self.col -= 1;
        } else if self.row > 0 {
            self.row -= 1;
            self.col = COLS - 1;
        }
        // Overwrite the cell with a space using the current attribute.
        // Safety: col < COLS and row < ROWS after the adjustments above.
        unsafe { self.write_cell(self.col, self.row, b' ') };
        self.update_cursor();
    }

    /// Move to the next row, scrolling the screen up by one line if necessary.
    fn advance_row(&mut self) {
        if self.row + 1 < ROWS {
            self.row += 1;
        } else {
            self.scroll_up();
            // row stays at ROWS-1 (last line, now blank)
        }
    }

    /// Scroll every row one line upwards and blank the last row.
    fn scroll_up(&mut self) {
        for row in 1..ROWS {
            for col in 0..COLS {
                let src_offset = (row * COLS + col) * 2;
                let dst_offset = ((row - 1) * COLS + col) * 2;
                let src = (VGA_BUFFER + src_offset) as *const u8;
                let dst = (VGA_BUFFER + dst_offset) as *mut u8;
                // Safety: both offsets are within the 80×25 VGA buffer.
                unsafe {
                    let ch = core::ptr::read_volatile(src);
                    let at = core::ptr::read_volatile(src.add(1));
                    write_volatile(dst, ch);
                    write_volatile(dst.add(1), at);
                }
            }
        }
        // Blank the last row.
        for col in 0..COLS {
            // Safety: col < COLS, row = ROWS-1 < ROWS.
            unsafe { self.write_cell(col, ROWS - 1, b' ') };
        }
    }

    /// Current cursor position as `(col, row)`.
    #[inline(always)]
    pub fn cursor(&self) -> (usize, usize) {
        (self.col, self.row)
    }

    /// Move the cursor to `(col, row)` (clamped to the screen) and sync the
    /// hardware cursor. Used when switching virtual screens.
    pub fn set_cursor(&mut self, col: usize, row: usize) {
        self.col = if col < COLS { col } else { COLS - 1 };
        self.row = if row < ROWS { row } else { ROWS - 1 };
        self.update_cursor();
    }

    /// Sync the VGA CRTC hardware cursor to the current (col, row) position.
    ///
    /// The CRTC cursor position is a linear index `row * COLS + col`. It is
    /// programmed as two 8-bit halves via the indexed register pair at I/O
    /// ports 0x3D4 (index) and 0x3D5 (data).
    fn update_cursor(&self) {
        let pos: u16 = (self.row * COLS + self.col) as u16;
        // Safety: 0x3D4/0x3D5 are the VGA CRTC address/data ports; writing
        // registers 0x0E/0x0F updates only the cursor position — no side
        // effects on display mode. Ring 0 I/O is permitted here.
        unsafe {
            crate::outb(CRTC_INDEX, CRTC_CURSOR_HI);
            crate::outb(CRTC_DATA, (pos >> 8) as u8);
            crate::outb(CRTC_INDEX, CRTC_CURSOR_LO);
            crate::outb(CRTC_DATA, (pos & 0xFF) as u8);
        }
    }
}

// ── Public API ───────────────────────────────────────────────────────────────

/// Obtain a `&mut Writer` from the global singleton.
///
/// # Safety
/// The kernel is single-threaded; the caller must not create a second
/// mutable reference to `WRITER` concurrently.
#[inline(always)]
unsafe fn writer() -> &'static mut Writer {
    // Safety: raw pointer cast avoids the `static_mut_refs` lint while
    // preserving the same semantics: one &mut at a time, single-threaded.
    unsafe { &mut *core::ptr::addr_of_mut!(WRITER) }
}

/// Initialise the VGA driver: set default colour and clear the screen.
///
/// Must be called once before any other VGA function.
pub fn init() {
    // Safety: single-threaded; this is the first (and only) call.
    let w = unsafe { writer() };
    w.set_color(Color::White, Color::Black);
    w.clear();
}

/// Clear the entire screen and reset the cursor to (0, 0).
pub fn clear() {
    // Safety: single-threaded.
    unsafe { writer() }.clear();
}

/// Set the foreground / background colour for subsequent output.
pub fn set_color(fg: Color, bg: Color) {
    // Safety: single-threaded.
    unsafe { writer() }.set_color(fg, bg);
}

/// Print a string slice to the VGA buffer.
pub fn print(s: &str) {
    // Safety: single-threaded.
    unsafe { writer() }.write_str(s);
}

/// Print a single ASCII byte to the VGA buffer.
pub fn print_char(c: u8) {
    // Safety: single-threaded.
    unsafe { writer() }.write_byte(c);
}

/// Erase the character before the cursor (move back, blank cell, leave cursor).
pub fn backspace() {
    // Safety: single-threaded.
    unsafe { writer() }.backspace();
}

/// Current cursor position as `(col, row)`.
pub fn cursor() -> (usize, usize) {
    // Safety: single-threaded.
    unsafe { writer() }.cursor()
}

/// Set the cursor position to `(col, row)`.
pub fn set_cursor(col: usize, row: usize) {
    // Safety: single-threaded.
    unsafe { writer() }.set_cursor(col, row);
}

/// Copy the live VGA framebuffer into `dst` (used to save a virtual screen).
pub fn save_buffer(dst: &mut [u8; BUFFER_BYTES]) {
    for (i, byte) in dst.iter_mut().enumerate() {
        let ptr = (VGA_BUFFER + i) as *const u8;
        // Safety: `i < BUFFER_BYTES`, so `ptr` is within the VGA text buffer.
        *byte = unsafe { core::ptr::read_volatile(ptr) };
    }
}

/// Copy `src` into the live VGA framebuffer (used to restore a virtual screen).
pub fn load_buffer(src: &[u8; BUFFER_BYTES]) {
    for (i, &byte) in src.iter().enumerate() {
        let ptr = (VGA_BUFFER + i) as *mut u8;
        // Safety: `i < BUFFER_BYTES`, so `ptr` is within the VGA text buffer.
        unsafe { write_volatile(ptr, byte) };
    }
}
