//! PS/2 keyboard driver (polling, scancode set 1).
//!
//! Reads raw scancodes from the PS/2 data port (0x60) and status port (0x64).
//! Scancode set 1 is the default on QEMU and real PC hardware.
//! Polling-based — no IRQ/IDT required (that is KFS_2 territory).
//!
//! Modifier state (Shift, Ctrl) is tracked across calls in module-level statics.

// ── Key / KeyEvent types ──────────────────────────────────────────────────────

/// A decoded key.
#[allow(dead_code)]
#[derive(Copy, Clone, PartialEq, Eq)]
pub enum Key {
    /// A printable ASCII byte, already shift-adjusted.
    Char(u8),
    Enter,
    Backspace,
    Tab,
    Esc,
    /// Function key F1..=F12.
    Function(u8),
    /// A key we don't translate to a character (modifiers, arrows, …).
    Other,
}

/// A key-press event plus modifier state at the time of the press.
#[derive(Copy, Clone)]
pub struct KeyEvent {
    pub key: Key,
    pub shift: bool,
    pub ctrl: bool,
}

impl KeyEvent {
    /// The printable byte for this event, if any (`Enter` maps to `\n`).
    pub fn as_char(&self) -> Option<u8> {
        match self.key {
            Key::Char(c) => Some(c),
            Key::Enter => Some(b'\n'),
            _ => None,
        }
    }
}

// ── I/O port constants ────────────────────────────────────────────────────────

/// PS/2 data port: read scancode / write commands.
const PS2_DATA: u16 = 0x60;

/// PS/2 status register: bit 0 = output-buffer-full (data ready to read).
const PS2_STATUS: u16 = 0x64;

/// Status bit: output buffer has a byte ready.
const STATUS_OBF: u8 = 0x01;

// ── Modifier state ────────────────────────────────────────────────────────────

/// Tracks whether any Shift key is currently held.
/// Single-threaded kernel; raw pointer via `addr_of_mut!` avoids the
/// `static_mut_refs` lint.
static mut SHIFT: bool = false;

/// Tracks whether any Ctrl key is currently held.
static mut CTRL: bool = false;

// ── Scancode → ASCII lookup tables ───────────────────────────────────────────
//
// Index = scancode set-1 make code (0x01 … 0x58).
// 0x00 = "no mapping" (modifier, control key, or unmapped).
//
// Two parallel tables: unshifted and shifted (US QWERTY layout).
//
// Row layout (visible comment guides):
//   ESC  1  2  3  4  5  6  7  8  9  0  -  =  BS   (0x01–0x0E)
//   TAB  Q  W  E  R  T  Y  U  I  O  P  [  ]  \    (0x0F–0x1B)
//        A  S  D  F  G  H  J  K  L  ;  '  `       (0x1C–0x29)  [0x1C = Enter]
//   LS   Z  X  C  V  B  N  M  ,  .  /  RS          (0x2A–0x36) [shift keys]
//   CTRL  ALT  SPACE                               (0x38–0x39)

#[rustfmt::skip]
static UNSHIFTED: [u8; 89] = [
//  0x00  0x01  0x02  0x03  0x04  0x05  0x06  0x07  0x08  0x09  0x0A  0x0B  0x0C  0x0D  0x0E  0x0F
       0,    0,  b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9', b'0', b'-', b'=',    0,    0,
//  0x10  0x11  0x12  0x13  0x14  0x15  0x16  0x17  0x18  0x19  0x1A  0x1B  0x1C  0x1D  0x1E  0x1F
      b'q',b'w', b'e', b'r', b't', b'y', b'u', b'i', b'o', b'p', b'[', b']',    0,    0, b'a', b's',
//  0x20  0x21  0x22  0x23  0x24  0x25  0x26  0x27  0x28  0x29  0x2A  0x2B  0x2C  0x2D  0x2E  0x2F
      b'd',b'f', b'g', b'h', b'j', b'k', b'l', b';', b'\'',b'`',   0, b'\\',b'z', b'x', b'c', b'v',
//  0x30  0x31  0x32  0x33  0x34  0x35  0x36  0x37  0x38  0x39  0x3A  0x3B  0x3C  0x3D  0x3E  0x3F
      b'b',b'n', b'm', b',', b'.', b'/',    0,    0,    0, b' ',    0,    0,    0,    0,    0,    0,
//  0x40  0x41  0x42  0x43  0x44  0x45  0x46  0x47  0x48  0x49  0x4A  0x4B  0x4C  0x4D  0x4E  0x4F
         0,   0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
//  0x50  0x51  0x52  0x53  0x54  0x55  0x56  0x57  0x58
         0,   0,    0,    0,    0,    0,    0,    0,    0,
];

#[rustfmt::skip]
static SHIFTED: [u8; 89] = [
//  0x00  0x01  0x02  0x03  0x04  0x05  0x06  0x07  0x08  0x09  0x0A  0x0B  0x0C  0x0D  0x0E  0x0F
       0,    0,  b'!', b'@', b'#', b'$', b'%', b'^', b'&', b'*', b'(', b')', b'_', b'+',    0,    0,
//  0x10  0x11  0x12  0x13  0x14  0x15  0x16  0x17  0x18  0x19  0x1A  0x1B  0x1C  0x1D  0x1E  0x1F
      b'Q',b'W', b'E', b'R', b'T', b'Y', b'U', b'I', b'O', b'P', b'{', b'}',    0,    0, b'A', b'S',
//  0x20  0x21  0x22  0x23  0x24  0x25  0x26  0x27  0x28  0x29  0x2A  0x2B  0x2C  0x2D  0x2E  0x2F
      b'D',b'F', b'G', b'H', b'J', b'K', b'L', b':', b'"', b'~',    0, b'|', b'Z', b'X', b'C', b'V',
//  0x30  0x31  0x32  0x33  0x34  0x35  0x36  0x37  0x38  0x39  0x3A  0x3B  0x3C  0x3D  0x3E  0x3F
      b'B',b'N', b'M', b'<', b'>', b'?',    0,    0,    0, b' ',    0,    0,    0,    0,    0,    0,
//  0x40  0x41  0x42  0x43  0x44  0x45  0x46  0x47  0x48  0x49  0x4A  0x4B  0x4C  0x4D  0x4E  0x4F
         0,   0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
//  0x50  0x51  0x52  0x53  0x54  0x55  0x56  0x57  0x58
         0,   0,    0,    0,    0,    0,    0,    0,    0,
];

// ── Public API ────────────────────────────────────────────────────────────────

/// Initialise the keyboard: drain any byte already sitting in the PS/2 buffer.
///
/// On some firmware paths GRUB leaves a stale byte in the output buffer;
/// reading it here prevents a spurious keystroke on the first `poll()`.
pub fn init() {
    // Safety: 0x64 is the PS/2 status register; 0x60 is the data register.
    // Both are always readable at ring 0 on PC-compatible hardware.
    unsafe {
        if crate::inb(PS2_STATUS) & STATUS_OBF != 0 {
            let _ = crate::inb(PS2_DATA);
        }
    }
}

/// Poll for a key-press event.
///
/// Reads the PS/2 status register (0x64); if the output-buffer-full bit is
/// set a scancode is waiting in the data register (0x60). The scancode is
/// decoded according to scancode set 1:
///   - Break codes (`make | 0x80`) update modifier state only (no event).
///   - Make codes for pure modifiers (Shift, Ctrl) update state; no event.
///   - All other make codes are translated and returned as a `KeyEvent`.
///
/// Returns `None` when no scancode is available or when a modifier key is
/// pressed/released (modifier-only state change).
pub fn poll() -> Option<KeyEvent> {
    // Safety: 0x64 is the PS/2 status register; readable at ring 0.
    let status = unsafe { crate::inb(PS2_STATUS) };
    if status & STATUS_OBF == 0 {
        return None; // No data waiting.
    }

    // Safety: 0x60 is the PS/2 data register; readable at ring 0.
    // We only read after confirming the output-buffer-full bit above.
    let sc = unsafe { crate::inb(PS2_DATA) };

    // Scancodes ≥ 0x80 are break (key-release) codes in set 1.
    let is_break = sc & 0x80 != 0;
    let make = sc & 0x7F; // strip the break bit to get the make code

    // Update modifier state from break codes and return early.
    if is_break {
        match make {
            0x2A | 0x36 => {
                // Safety: SHIFT is only accessed in this single-threaded path.
                unsafe { *core::ptr::addr_of_mut!(SHIFT) = false };
            }
            0x1D => {
                // Safety: CTRL is only accessed in this single-threaded path.
                unsafe { *core::ptr::addr_of_mut!(CTRL) = false };
            }
            _ => {}
        }
        return None; // Break codes never produce a KeyEvent.
    }

    // ── Make code: update modifiers first ────────────────────────────────────
    match make {
        0x2A | 0x36 => {
            // Left Shift (0x2A) or Right Shift (0x36) pressed.
            // Safety: single-threaded access.
            unsafe { *core::ptr::addr_of_mut!(SHIFT) = true };
            return None; // Pure modifier: no KeyEvent.
        }
        0x1D => {
            // Left Ctrl pressed.
            // Safety: single-threaded access.
            unsafe { *core::ptr::addr_of_mut!(CTRL) = true };
            return None; // Pure modifier: no KeyEvent.
        }
        _ => {}
    }

    // Snapshot modifier state for the event we are about to emit.
    // Safety: single-threaded; reading atomically.
    let shift = unsafe { *core::ptr::addr_of_mut!(SHIFT) };
    let ctrl = unsafe { *core::ptr::addr_of_mut!(CTRL) };

    // ── Decode make code into a Key ───────────────────────────────────────────
    let key = match make {
        0x01 => Key::Esc,
        0x0E => Key::Backspace,
        0x0F => Key::Tab,
        0x1C => Key::Enter,

        // Function keys F1..F10 = 0x3B..0x44, F11 = 0x57, F12 = 0x58
        0x3B => Key::Function(1),
        0x3C => Key::Function(2),
        0x3D => Key::Function(3),
        0x3E => Key::Function(4),
        0x3F => Key::Function(5),
        0x40 => Key::Function(6),
        0x41 => Key::Function(7),
        0x42 => Key::Function(8),
        0x43 => Key::Function(9),
        0x44 => Key::Function(10),
        0x57 => Key::Function(11),
        0x58 => Key::Function(12),

        // Anything in the ASCII table range: look up the character.
        sc if (sc as usize) < UNSHIFTED.len() => {
            let ascii = if shift {
                SHIFTED[sc as usize]
            } else {
                UNSHIFTED[sc as usize]
            };
            if ascii != 0 {
                Key::Char(ascii)
            } else {
                Key::Other
            }
        }

        // Unknown scancode.
        _ => Key::Other,
    };

    Some(KeyEvent { key, shift, ctrl })
}
