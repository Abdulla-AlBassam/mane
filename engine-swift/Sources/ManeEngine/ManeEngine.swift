import CManeEngine
import Foundation

/// Swift wrapper around the Mane engine's C ABI.
///
/// Loads filter rules at init, checks requests via ``shouldBlock(url:sourceUrl:type:)``,
/// and frees the underlying engine on deinit. The wrapper is a reference type so
/// ownership of the C handle is unambiguous and lifetime tracks the Swift object.
public final class ManeEngine {
    private let handle: OpaquePointer

    /// Build an engine from a combined rules string (newline-separated, EasyList syntax).
    /// Returns nil if the underlying C call fails (null pointer back from Rust).
    public init?(rules: String) {
        guard let raw = mane_engine_new(rules) else {
            return nil
        }
        self.handle = raw
    }

    deinit {
        mane_engine_free(handle)
    }

    /// Returns true if the request should be blocked.
    ///
    /// - Parameters:
    ///   - url: the URL being requested (e.g. an ad script)
    ///   - sourceUrl: the URL of the page making the request
    ///   - type: EasyList request type, e.g. `script`, `image`, `stylesheet`, `subdocument`
    public func shouldBlock(url: String, sourceUrl: String, type: String) -> Bool {
        return mane_engine_check(handle, url, sourceUrl, type)
    }
}
