//! `libk` — basic kernel library.
//!
//! Provides portable, heap-free utilities for use throughout the KFS kernel:
//!
//! - `types`  — kernel-wide type aliases (`paddr`, `vaddr`, `byte`, …).
//! - `string` — C-string helpers (`strlen`, `strcmp`, `strncmp`, `str_from_cstr`).
//!
//! Note: `memcpy`, `memset`, `memmove`, and `memcmp` are intentionally **not**
//! defined here; they are provided by `compiler-builtins-mem` and duplicate
//! symbols would break the link.

pub mod string;
pub mod types;
