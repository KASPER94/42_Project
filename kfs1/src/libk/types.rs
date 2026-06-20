//! Kernel type aliases.
//!
//! Provides conveniently named integer / pointer types for use throughout
//! the kernel.  All aliases map directly to core primitives — zero runtime
//! cost.
//!
//! The lowercase names follow C kernel convention; silence the Rust style lint.
#![allow(non_camel_case_types)]

/// Unsigned pointer-sized integer (matches `usize` on i386: 32 bits).
pub type uptr = usize;

/// Signed pointer-sized integer.
pub type iptr = isize;

/// Byte (alias for `u8`).
pub type byte = u8;

/// Physical memory address (32-bit on i386).
pub type paddr = u32;

/// Virtual memory address (32-bit on i386, same as physical for now).
pub type vaddr = u32;
