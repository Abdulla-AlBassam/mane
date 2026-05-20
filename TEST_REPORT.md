# Mane autonomous test report — 2026-05-20

Test rig: Playwright + Chromium 148, with `chrome-ext/` (a quick MV3 port of `safari-ext/`) loaded as unpacked. Two passes over five ad-heavy sites: a baseline with no extension, then the same five with Mane active. Diffed request lists, captured screenshots, queried the extension's `getMatchedRules` per site.

Test data: `test-output/report-v2.json`, baseline + extension screenshots in `test-output/`.

## Headline numbers

| Site | Baseline reqs | Extension reqs | Reduction | Notes |
|---|---:|---:|---:|---|
| theguardian.com | 409 | 190 | **53%** | Major trackers killed cleanly |
| dailymail.co.uk | 494 | 187 | **62%** | Biggest win; Permutive removed |
| forbes.com | 184 | 294 | **-60%** (worse) | See bug 4 |
| bbc.co.uk/sport | 206 | 205 | **0%** | Extension does almost nothing |
| aliexpress.com | 384 | 396 | **-3%** (worse) | See bug 3 |

Average across news sites that actually have third-party ads: very good. Average across non-news commercial sites: poor to non-existent.

## Bugs and gaps, ranked by severity

### Bug 1: AliExpress effectively unprotected

Major trackers reach the page with the extension on. None of these are blocked:

| Domain | Requests on aliexpress |
|---|---:|
| cdn.taboola.com | 6 |
| gum.criteo.com | 4 |
| trc.taboola.com | 3 |
| connect.facebook.net | 3 |
| googletagmanager.com | 3 |
| ib.adnxs.com | 3 |
| cm.g.doubleclick.net | 3 |

Rules for taboola (20 entries), criteo (20), googletagmanager (14), doubleclick (many) **do exist** in `rules.json`. So the rules are present but failing to match these specific URLs.

Most likely cause: the EasyList rules target third-party ad contexts identified by domain anchors (e.g. `||taboola.com^$third-party`). AliExpress may be loading these via a context Chrome's dNR doesn't classify as "third-party" (some kind of edge-cached or proxied load), or the resource-type filter on the rule doesn't match the actual request type. Need to step through one specific request to know for sure.

### Bug 2: Forbes ads partially escape, plus extension increases request count

Forbes goes **up** from 184 to 294 requests with the extension on. Investigation needed: it's possible Forbes detects ad-blocking and triggers a retry / fallback path that ends up firing more analytics. The escapees are heavy:

`s.amazon-adsystem.com` (12), `match.adsrvr.org` (5), `cm.g.doubleclick.net` (5), `ups.analytics.yahoo.com` (5), `quantserve` (4), `openx` (4), `adnxs` (4), `yieldmo` (4), `pubmatic`, `facebook`.

Inconsistency: `s.amazon-adsystem.com` is blocked on theguardian but reaches forbes. Same domain, different behaviour. The rules must be domain-specific in a way that doesn't generalise, or there's a resource-type asymmetry.

### Bug 3: Permutive on theguardian

Permutive (an audience-data platform) leaks 14+ requests through. EasyPrivacy has 3 references to "permutive" but our compiled rules only show 4 entries. The escaping subdomains:

- `api.permutive.com` (14 requests)
- `secure-signals.permutive.app` (4)
- `cdn.permutive.com` (2)

The `.app` and `cdn.` variants likely aren't covered by the existing rule, which probably targets only `permutive.com` directly.

### Bug 4: Google's first-party tracking properties slip through everywhere

`analytics.google.com`, `www.googletagmanager.com`, `stats.g.doubleclick.net` reach almost every page. We have 14 rule entries mentioning googletagmanager but none of them seem to actually block the standard `https://www.googletagmanager.com/gtm.js?id=...` URL pattern. This is a common gap in EasyList because it's controversial (lots of sites won't function fully without GTM), but for an aggressive ad-blocker this is something to fix.

### Bug 5: Engine state visibility via `getMatchedRules` is broken or undercounting

`chrome.declarativeNetRequest.getMatchedRules({})` returns 4-11 matches per site even when the request-diff shows 200+ requests were actually prevented. This API is supposed to be the ground truth for what the extension blocked. Possible causes: a per-call result limit we're not aware of, or the API only reports matches initiated by `onRuleMatchedDebug` events. Whatever the cause, **the dashboard's reliance on this API to populate the "Today blocked" count is suspect**. The Safari version may show artificially low numbers for the same reason. Worth verifying.

### Bug 6 (cosmetic): Forbes anti-adblock cookie banner

Visible in the screenshot: Forbes shows a "We've detected you have an ad blocker" overlay. We compiled out the cosmetic rules (BlockCookies, CssDisplayNone) which means we can't hide it. Expected limitation until phase 4 adds cosmetic filtering, but worth noting.

### Bug 7 (methodology, not the extension): No popups fired

I tried to catch popups (window.open, target=_blank ads, full-page redirects) but none triggered on any of the 5 sites in either pass. Likely Chromium's built-in popup blocker plus the fact that these are landing pages rather than streaming/interactive flows. The redirect ad you reported on strikeout.im wouldn't show up here without clicking into an actual stream. Real popup testing needs interaction, which the autonomous run isn't doing.

## What works

- Ruleset compiles, loads, and stays loaded across 122,026 rules. Chrome's dNR slot quota is 329,000, so we have headroom.
- Service worker initialises cleanly: `enabledRulesets: ["mane-main"]`. No console errors.
- News sites get major blocks: doubleclick, adsrvr, adnxs, smartadserver, openx, gumgum, adsafeprotected, id5-sync, bidswitch, presage, amazon-adsystem all killed on theguardian and dailymail.
- Visual quick-check (screenshots): theguardian + dailymail load with no visible display ads.

## What I couldn't test autonomously

- **Toggle bridge** (dashboard ↔ extension via `mane-control.json`): no Safari from Playwright. Need you to test by hand or I can do it via direct file writes if you keep the dashboard open.
- **Stats accuracy** (whether the count on the dashboard matches reality): related to bug 5.
- **Real redirect/popup ads** on streaming sites: would need scripted interaction with the page (clicking "watch stream" then checking what windows open). Doable as a phase 2 of testing if you want.
- **Cosmetic ads** (the empty rectangles you'd see if a site lays out around a removed banner): visual inspection of screenshots is what I have; nothing automated.

## Quick recommendations

1. **Investigate Forbes**: open in Safari with Mane, open Web Inspector, see if there's an anti-adblock retry loop. Possibly worth a per-site allow-list of analytics if their content gates on it.
2. **Patch obvious gaps with a custom rule list**: `||permutive.app^`, `||permutive.com^`, and the specific `cm.g.doubleclick.net` / `stats.g.doubleclick.net` patterns. A small `filterlists/mane-custom.txt` would slot into the compile pipeline cleanly.
3. **Confirm Bug 5** on real Safari: if `getMatchedRules` undercounts on Safari too, the dashboard "Today blocked" number is lying. We may need to track blocks differently (e.g. a domain-by-domain estimate from `webNavigation` callbacks, since `onRuleMatchedDebug` is unreliable).
4. **AliExpress and BBC need their own analysis**: they're shaped differently from western news sites. Worth a dedicated pass.
