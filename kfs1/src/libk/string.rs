//! Kernel string utilities.
//!
//! C-compatible helpers that operate on null-terminated byte strings
//! (`*const u8`).  These do NOT overlap with the symbols provided by
//! `compiler-builtins-mem` (`memcpy`, `memset`, `memmove`, `memcmp`) — those
//! are block-memory operations; these are string-semantic operations.
//!
//! Safety invariant: every `*const u8` argument must point to a
//! null-terminated sequence that is valid for reads for at least `strlen + 1`
//! bytes.

use core::ffi::c_int;

/// Return the number of bytes in `s` before the terminating NUL.
///
/// # Safety
/// `s` must be a valid pointer to a NUL-terminated byte string.
pub unsafe fn strlen(s: *const u8) -> usize {
    // Walk the pointer until we hit the NUL byte.
    let mut len = 0usize;
    while unsafe { *s.add(len) } != 0 {
        len += 1;
    }
    len
}

/// Compare two NUL-terminated byte strings lexicographically.
///
/// Returns `< 0`, `0`, or `> 0` following the POSIX `strcmp` convention.
///
/// # Safety
/// Both `a` and `b` must be valid, NUL-terminated byte strings.
pub unsafe fn strcmp(a: *const u8, b: *const u8) -> c_int {
    let mut i = 0usize;
    loop {
        // Safety: caller guarantees NUL-terminated strings.
        let ca = unsafe { *a.add(i) };
        let cb = unsafe { *b.add(i) };
        if ca != cb {
            return (ca as c_int) - (cb as c_int);
        }
        if ca == 0 {
            return 0;
        }
        i += 1;
    }
}

/// Like `strcmp` but compare at most `n` bytes.
///
/// # Safety
/// `a` and `b` must be valid for reads of at least `n` bytes, or be
/// NUL-terminated before that limit.
pub unsafe fn strncmp(a: *const u8, b: *const u8, n: usize) -> c_int {
    for i in 0..n {
        // Safety: caller guarantees validity for `n` bytes.
        let ca = unsafe { *a.add(i) };
        let cb = unsafe { *b.add(i) };
        if ca != cb {
            return (ca as c_int) - (cb as c_int);
        }
        if ca == 0 {
            return 0;
        }
    }
    0
}

/// Return a `&str` slice for a NUL-terminated byte string, without copying.
///
/// Returns `None` if the bytes are not valid UTF-8.
///
/// # Safety
/// `s` must be a valid, NUL-terminated byte string with lifetime at least `'a`.
pub unsafe fn str_from_cstr<'a>(s: *const u8) -> Option<&'a str> {
    // Safety: `strlen` requires NUL-termination, guaranteed by caller.
    let len = unsafe { strlen(s) };
    let bytes = unsafe { core::slice::from_raw_parts(s, len) };
    core::str::from_utf8(bytes).ok()
}
