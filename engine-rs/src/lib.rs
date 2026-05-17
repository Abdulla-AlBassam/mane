//! Mane engine wrapper.
//!
//! Native consumers (CLI examples, tests) use this crate as a regular Rust
//! library. The Swift Mac app consumes the same engine through the C ABI
//! defined in [`ffi`], built into a static library by `cargo build`.

pub mod ffi;
