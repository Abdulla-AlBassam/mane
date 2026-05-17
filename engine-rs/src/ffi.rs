//! C ABI for the Mane engine.
//!
//! Exposes a minimal surface for the Swift Mac app and the browser extensions
//! (via WASM, later) to load filter rules and check whether a request should
//! be blocked. All entry points catch panics so a misbehaving caller cannot
//! abort the host process via undefined behaviour at the FFI boundary.

use adblock::lists::{FilterSet, ParseOptions};
use adblock::request::Request;
use adblock::Engine as AdblockEngine;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

/// Opaque engine handle. Construct with [`mane_engine_new`], free with
/// [`mane_engine_free`].
pub struct Engine {
    inner: AdblockEngine,
}

/// Build an engine from a combined rules string (newline-separated, EasyList
/// syntax). The caller retains ownership of `rules`; the engine copies what
/// it needs.
///
/// Returns null on failure (null input, invalid UTF-8, or panic during build).
#[no_mangle]
pub extern "C" fn mane_engine_new(rules: *const c_char) -> *mut Engine {
    catch_unwind(AssertUnwindSafe(|| {
        if rules.is_null() {
            return std::ptr::null_mut();
        }
        let rules_str = match unsafe { CStr::from_ptr(rules) }.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };
        let mut filter_set = FilterSet::new(false);
        filter_set.add_filter_list(rules_str, ParseOptions::default());
        let engine = AdblockEngine::from_filter_set(filter_set, true);
        Box::into_raw(Box::new(Engine { inner: engine }))
    }))
    .unwrap_or(std::ptr::null_mut())
}

/// Free an engine handle. Safe to call with null.
#[no_mangle]
pub extern "C" fn mane_engine_free(engine: *mut Engine) {
    if engine.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        drop(Box::from_raw(engine));
    }));
}

/// Check whether a request should be blocked.
///
/// `request_type` follows EasyList vocabulary: `script`, `image`, `stylesheet`,
/// `subdocument`, `xhr`, `document`, etc.
///
/// Returns `false` on any error (null inputs, invalid UTF-8, invalid URL, panic).
#[no_mangle]
pub extern "C" fn mane_engine_check(
    engine: *const Engine,
    url: *const c_char,
    source_url: *const c_char,
    request_type: *const c_char,
) -> bool {
    catch_unwind(AssertUnwindSafe(|| {
        if engine.is_null() || url.is_null() || source_url.is_null() || request_type.is_null() {
            return false;
        }
        let engine = unsafe { &*engine };
        let url = match unsafe { CStr::from_ptr(url) }.to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        let source = match unsafe { CStr::from_ptr(source_url) }.to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        let req_type = match unsafe { CStr::from_ptr(request_type) }.to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        let req = match Request::new(url, source, req_type) {
            Ok(r) => r,
            Err(_) => return false,
        };
        engine.inner.check_network_request(&req).matched
    }))
    .unwrap_or(false)
}
