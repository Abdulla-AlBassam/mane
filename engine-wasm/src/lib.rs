//! Browser-facing WASM wrapper around Brave's adblock-rust engine.
//!
//! Mirrors the surface of `engine-rs`'s C ABI, but exposed to JavaScript via
//! wasm-bindgen. The Safari extension's `background.js` imports the generated
//! glue, builds an `Engine` from filter list text once at boot, then calls
//! `check` on every network request.

use adblock::lists::{FilterSet, ParseOptions};
use adblock::request::Request;
use adblock::Engine as AdblockEngine;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct Engine {
    inner: AdblockEngine,
}

#[wasm_bindgen]
impl Engine {
    /// Build an engine from a single string containing all filter rules
    /// (typically EasyList and EasyPrivacy concatenated with a newline).
    #[wasm_bindgen(constructor)]
    pub fn new(rules: &str) -> Engine {
        let mut filter_set = FilterSet::new(false);
        filter_set.add_filter_list(rules, ParseOptions::default());
        Engine {
            inner: AdblockEngine::from_filter_set(filter_set, true),
        }
    }

    /// Return true if the request should be blocked.
    ///
    /// `request_type` is EasyList vocabulary: `script`, `image`, `stylesheet`,
    /// `subdocument`, `xhr`, `document`, etc. Invalid URLs or types return
    /// false (do not block) rather than throwing.
    pub fn check(&self, url: &str, source_url: &str, request_type: &str) -> bool {
        match Request::new(url, source_url, request_type) {
            Ok(req) => self.inner.check_network_request(&req).matched,
            Err(_) => false,
        }
    }
}
