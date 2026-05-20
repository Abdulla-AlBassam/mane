import Foundation
import SwiftUI

enum TrackerCategory: String, CaseIterable, Hashable {
    case ads = "Ads"
    case analytics = "Analytics"
    case social = "Social"
    case fingerprint = "Fingerprint"
    case cdn = "CDN"
    case search = "Search"
    case other = "Other"

    var tint: Color {
        switch self {
        case .ads: return Color(red: 0.95, green: 0.45, blue: 0.35)
        case .analytics: return Color(red: 0.45, green: 0.70, blue: 0.95)
        case .social: return Color(red: 0.80, green: 0.45, blue: 0.95)
        case .fingerprint: return Color(red: 0.95, green: 0.75, blue: 0.30)
        case .cdn: return Color(red: 0.55, green: 0.85, blue: 0.55)
        case .search: return Color(red: 0.55, green: 0.65, blue: 0.95)
        case .other: return Color(white: 0.65)
        }
    }
}

struct TrackerInfo {
    let parent: String
    let category: TrackerCategory
}

enum TrackerTaxonomy {
    private struct Entry { let suffix: String; let info: TrackerInfo }

    private static let entries: [Entry] = [
        // Google
        .init(suffix: "doubleclick.net", info: .init(parent: "Google", category: .ads)),
        .init(suffix: "googletagmanager.com", info: .init(parent: "Google", category: .analytics)),
        .init(suffix: "google-analytics.com", info: .init(parent: "Google", category: .analytics)),
        .init(suffix: "googleadservices.com", info: .init(parent: "Google", category: .ads)),
        .init(suffix: "googlesyndication.com", info: .init(parent: "Google", category: .ads)),
        .init(suffix: "googletagservices.com", info: .init(parent: "Google", category: .ads)),
        .init(suffix: "adservice.google.com", info: .init(parent: "Google", category: .ads)),
        .init(suffix: "adservice.google.co.uk", info: .init(parent: "Google", category: .ads)),
        .init(suffix: "google.com", info: .init(parent: "Google", category: .search)),
        .init(suffix: "google.co.uk", info: .init(parent: "Google", category: .search)),
        .init(suffix: "gstatic.com", info: .init(parent: "Google", category: .cdn)),
        .init(suffix: "googleusercontent.com", info: .init(parent: "Google", category: .cdn)),
        .init(suffix: "youtube.com", info: .init(parent: "Google", category: .social)),
        .init(suffix: "ytimg.com", info: .init(parent: "Google", category: .cdn)),

        // Meta
        .init(suffix: "facebook.com", info: .init(parent: "Meta", category: .social)),
        .init(suffix: "facebook.net", info: .init(parent: "Meta", category: .social)),
        .init(suffix: "fbcdn.net", info: .init(parent: "Meta", category: .social)),
        .init(suffix: "instagram.com", info: .init(parent: "Meta", category: .social)),
        .init(suffix: "cdninstagram.com", info: .init(parent: "Meta", category: .cdn)),
        .init(suffix: "whatsapp.net", info: .init(parent: "Meta", category: .social)),

        // X / Twitter
        .init(suffix: "twitter.com", info: .init(parent: "X (Twitter)", category: .social)),
        .init(suffix: "x.com", info: .init(parent: "X (Twitter)", category: .social)),
        .init(suffix: "twimg.com", info: .init(parent: "X (Twitter)", category: .cdn)),
        .init(suffix: "t.co", info: .init(parent: "X (Twitter)", category: .social)),

        // LinkedIn
        .init(suffix: "linkedin.com", info: .init(parent: "LinkedIn", category: .social)),
        .init(suffix: "licdn.com", info: .init(parent: "LinkedIn", category: .cdn)),

        // TikTok
        .init(suffix: "tiktok.com", info: .init(parent: "TikTok", category: .social)),
        .init(suffix: "tiktokcdn.com", info: .init(parent: "TikTok", category: .cdn)),

        // Amazon
        .init(suffix: "amazon-adsystem.com", info: .init(parent: "Amazon", category: .ads)),
        .init(suffix: "aps.amazon.com", info: .init(parent: "Amazon", category: .ads)),
        .init(suffix: "assoc-amazon.com", info: .init(parent: "Amazon", category: .ads)),

        // Microsoft
        .init(suffix: "bing.com", info: .init(parent: "Microsoft", category: .search)),
        .init(suffix: "clarity.ms", info: .init(parent: "Microsoft", category: .analytics)),
        .init(suffix: "msn.com", info: .init(parent: "Microsoft", category: .other)),
        .init(suffix: "live.com", info: .init(parent: "Microsoft", category: .other)),

        // Apple
        .init(suffix: "icloud.com", info: .init(parent: "Apple", category: .other)),
        .init(suffix: "apple.com", info: .init(parent: "Apple", category: .other)),

        // Adobe
        .init(suffix: "adobedtm.com", info: .init(parent: "Adobe", category: .analytics)),
        .init(suffix: "demdex.net", info: .init(parent: "Adobe", category: .analytics)),
        .init(suffix: "adobedc.net", info: .init(parent: "Adobe", category: .analytics)),
        .init(suffix: "everesttech.net", info: .init(parent: "Adobe", category: .ads)),
        .init(suffix: "omtrdc.net", info: .init(parent: "Adobe", category: .analytics)),
        .init(suffix: "2o7.net", info: .init(parent: "Adobe", category: .analytics)),

        // Ad networks
        .init(suffix: "criteo.com", info: .init(parent: "Criteo", category: .ads)),
        .init(suffix: "criteo.net", info: .init(parent: "Criteo", category: .ads)),
        .init(suffix: "pubmatic.com", info: .init(parent: "PubMatic", category: .ads)),
        .init(suffix: "rubiconproject.com", info: .init(parent: "Magnite", category: .ads)),
        .init(suffix: "openx.net", info: .init(parent: "OpenX", category: .ads)),
        .init(suffix: "adsrvr.org", info: .init(parent: "The Trade Desk", category: .ads)),
        .init(suffix: "taboola.com", info: .init(parent: "Taboola", category: .ads)),
        .init(suffix: "outbrain.com", info: .init(parent: "Outbrain", category: .ads)),
        .init(suffix: "indexww.com", info: .init(parent: "Index Exchange", category: .ads)),
        .init(suffix: "casalemedia.com", info: .init(parent: "Index Exchange", category: .ads)),
        .init(suffix: "adnxs.com", info: .init(parent: "Xandr", category: .ads)),
        .init(suffix: "adsafeprotected.com", info: .init(parent: "IAS", category: .ads)),
        .init(suffix: "moatads.com", info: .init(parent: "Oracle Moat", category: .analytics)),
        .init(suffix: "smartadserver.com", info: .init(parent: "Smart Adserver", category: .ads)),
        .init(suffix: "spotxchange.com", info: .init(parent: "Magnite", category: .ads)),
        .init(suffix: "yieldmo.com", info: .init(parent: "Yieldmo", category: .ads)),
        .init(suffix: "yieldlab.net", info: .init(parent: "Yieldlab", category: .ads)),

        // Analytics
        .init(suffix: "scorecardresearch.com", info: .init(parent: "Comscore", category: .analytics)),
        .init(suffix: "newrelic.com", info: .init(parent: "New Relic", category: .analytics)),
        .init(suffix: "nr-data.net", info: .init(parent: "New Relic", category: .analytics)),
        .init(suffix: "segment.io", info: .init(parent: "Segment", category: .analytics)),
        .init(suffix: "segment.com", info: .init(parent: "Segment", category: .analytics)),
        .init(suffix: "mixpanel.com", info: .init(parent: "Mixpanel", category: .analytics)),
        .init(suffix: "hotjar.com", info: .init(parent: "Hotjar", category: .analytics)),
        .init(suffix: "fullstory.com", info: .init(parent: "FullStory", category: .analytics)),
        .init(suffix: "amplitude.com", info: .init(parent: "Amplitude", category: .analytics)),
        .init(suffix: "heap.io", info: .init(parent: "Heap", category: .analytics)),
        .init(suffix: "klaviyo.com", info: .init(parent: "Klaviyo", category: .analytics)),
        .init(suffix: "branch.io", info: .init(parent: "Branch", category: .analytics)),
        .init(suffix: "braze.com", info: .init(parent: "Braze", category: .analytics)),
        .init(suffix: "appsflyer.com", info: .init(parent: "AppsFlyer", category: .analytics)),
        .init(suffix: "kissmetrics.com", info: .init(parent: "Kissmetrics", category: .analytics)),
        .init(suffix: "chartbeat.com", info: .init(parent: "Chartbeat", category: .analytics)),
        .init(suffix: "chartbeat.net", info: .init(parent: "Chartbeat", category: .analytics)),
        .init(suffix: "quantserve.com", info: .init(parent: "Quantcast", category: .analytics)),
        .init(suffix: "optimizely.com", info: .init(parent: "Optimizely", category: .analytics)),

        // Video / streaming
        .init(suffix: "vipdine.space", info: .init(parent: "vipdine", category: .ads)),
        .init(suffix: "jwplatform.com", info: .init(parent: "JW Player", category: .ads)),
        .init(suffix: "jwpcdn.com", info: .init(parent: "JW Player", category: .cdn)),
    ]

    static func info(for domain: String) -> TrackerInfo {
        let host = domain.lowercased()
        for entry in entries where host == entry.suffix || host.hasSuffix("." + entry.suffix) {
            return entry.info
        }
        return TrackerInfo(parent: rootDomain(of: host), category: .other)
    }

    private static let multiPartTLDs: Set<String> = [
        "co.uk", "ac.uk", "gov.uk", "org.uk",
        "co.jp", "ne.jp",
        "com.au", "net.au", "org.au",
        "co.nz",
        "com.br",
        "co.za",
    ]

    static func rootDomain(of host: String) -> String {
        let parts = host.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return host }
        let lastTwo = parts.suffix(2).joined(separator: ".")
        if multiPartTLDs.contains(lastTwo), parts.count >= 3 {
            return parts.suffix(3).joined(separator: ".")
        }
        return lastTwo
    }
}
