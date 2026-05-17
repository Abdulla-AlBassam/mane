//! Validation harness for the adblock-rust engine.
//!
//! Loads EasyList + EasyPrivacy from `filterlists/`, builds the engine,
//! and runs a fixed set of requests through it. Each case has a known
//! expected outcome (block or allow); the harness prints PASS or FAIL
//! and exits non-zero if anything fails.

use adblock::lists::{FilterSet, ParseOptions};
use adblock::request::Request;
use adblock::Engine;
use std::fs;
use std::time::Instant;

fn main() {
    println!("=== Mane engine validation ===\n");

    let easylist = fs::read_to_string("filterlists/easylist.txt")
        .expect("filterlists/easylist.txt missing — run ./scripts/fetch-filterlists.sh");
    let easyprivacy = fs::read_to_string("filterlists/easyprivacy.txt")
        .expect("filterlists/easyprivacy.txt missing — run ./scripts/fetch-filterlists.sh");

    println!("EasyList     {} KB", easylist.len() / 1024);
    println!("EasyPrivacy  {} KB", easyprivacy.len() / 1024);

    let mut filter_set = FilterSet::new(false);
    filter_set.add_filter_list(&easylist, ParseOptions::default());
    filter_set.add_filter_list(&easyprivacy, ParseOptions::default());

    let started = Instant::now();
    let engine = Engine::from_filter_set(filter_set, true);
    println!("Engine built in {:?}\n", started.elapsed());

    let source = "https://www.bbc.co.uk/news";

    let cases: &[(&str, &str, bool, &str)] = &[
        ("https://www.googletagmanager.com/gtm.js?id=GTM-XXXX",     "script",      true,  "Google Tag Manager"),
        ("https://www.google-analytics.com/analytics.js",            "script",      true,  "Google Analytics"),
        ("https://securepubads.g.doubleclick.net/gampad/ads?abc=1",  "subdocument", true,  "DoubleClick ad slot"),
        ("https://static.scorecardresearch.com/beacon.js",           "script",      true,  "Scorecard tracker"),
        ("https://m.files.bbci.co.uk/main.css",                      "stylesheet",  false, "BBC stylesheet"),
        ("https://ichef.bbci.co.uk/news/640/cpsprodpb/example.jpg",  "image",       false, "BBC image"),
        ("https://github.com/brave/adblock-rust",                    "document",    false, "GitHub page"),
        ("https://en.wikipedia.org/wiki/Adblock_Plus",               "document",    false, "Wikipedia page"),
    ];

    println!("Source page: {source}");
    println!("Running {} test URLs:\n", cases.len());

    let mut pass = 0usize;
    let mut fail = 0usize;

    for (url, request_type, expected, label) in cases {
        let req = match Request::new(url, source, request_type) {
            Ok(r) => r,
            Err(e) => {
                println!("  [FAIL] could not build request for {url}: {e:?}");
                fail += 1;
                continue;
            }
        };
        let started = Instant::now();
        let result = engine.check_network_request(&req);
        let elapsed = started.elapsed();
        let actual = result.matched;
        let ok = actual == *expected;
        if ok {
            pass += 1;
        } else {
            fail += 1;
        }
        let tag = if ok { "PASS" } else { "FAIL" };
        println!(
            "  [{tag}] {elapsed:>9?}  expect={expected:5}  actual={actual:5}  {label}"
        );
        println!("           {url}");
    }

    println!("\n{pass} of {} passed", pass + fail);
    if fail > 0 {
        std::process::exit(1);
    }
}
