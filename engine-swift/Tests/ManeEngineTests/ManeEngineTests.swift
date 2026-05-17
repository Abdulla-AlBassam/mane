import XCTest
@testable import ManeEngine

final class ManeEngineTests: XCTestCase {
    static var engine: ManeEngine!

    override class func setUp() {
        super.setUp()

        // Resolve filter lists relative to this test file. Layout:
        //   Mane/engine-swift/Tests/ManeEngineTests/ManeEngineTests.swift
        //   Mane/filterlists/{easylist,easyprivacy}.txt
        let maneRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()    // ManeEngineTests/
            .deletingLastPathComponent()    // Tests/
            .deletingLastPathComponent()    // engine-swift/
            .deletingLastPathComponent()    // Mane/

        let easyList = maneRoot.appendingPathComponent("filterlists/easylist.txt")
        let easyPrivacy = maneRoot.appendingPathComponent("filterlists/easyprivacy.txt")

        guard let ads = try? String(contentsOf: easyList, encoding: .utf8),
              let trackers = try? String(contentsOf: easyPrivacy, encoding: .utf8) else {
            fatalError("Could not read filter lists from \(maneRoot.path)/filterlists/. Run ./scripts/fetch-filterlists.sh from the repo root.")
        }

        // Mirror the Rust harness: load EasyList + EasyPrivacy into one engine.
        let rules = ads + "\n" + trackers

        guard let e = ManeEngine(rules: rules) else {
            fatalError("ManeEngine init returned nil")
        }
        engine = e
    }

    private let source = "https://www.bbc.co.uk/news"

    func testBlocksGoogleTagManager() {
        XCTAssertTrue(Self.engine.shouldBlock(
            url: "https://www.googletagmanager.com/gtm.js?id=GTM-XXXX",
            sourceUrl: source,
            type: "script"
        ))
    }

    func testBlocksDoubleClick() {
        XCTAssertTrue(Self.engine.shouldBlock(
            url: "https://securepubads.g.doubleclick.net/gampad/ads?abc=1",
            sourceUrl: source,
            type: "subdocument"
        ))
    }

    func testBlocksGoogleAnalytics() {
        XCTAssertTrue(Self.engine.shouldBlock(
            url: "https://www.google-analytics.com/analytics.js",
            sourceUrl: source,
            type: "script"
        ))
    }

    func testAllowsBBCStylesheet() {
        XCTAssertFalse(Self.engine.shouldBlock(
            url: "https://m.files.bbci.co.uk/main.css",
            sourceUrl: source,
            type: "stylesheet"
        ))
    }

    func testAllowsBBCImage() {
        XCTAssertFalse(Self.engine.shouldBlock(
            url: "https://ichef.bbci.co.uk/news/640/cpsprodpb/example.jpg",
            sourceUrl: source,
            type: "image"
        ))
    }

    func testAllowsGitHub() {
        XCTAssertFalse(Self.engine.shouldBlock(
            url: "https://github.com/brave/adblock-rust",
            sourceUrl: source,
            type: "document"
        ))
    }
}
