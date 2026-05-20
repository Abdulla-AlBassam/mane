# Chrome MV3 handoff

Phase 4 deliverable: a Chrome (and Edge / Brave / Arc) ad blocker that reuses Mane's compiled `rules.json` and gives a parity user experience with the Safari extension. Mac dashboard integration is optional in v1.

---

## What you're inheriting

The Safari Web Extension at `safari-ext/` is already MV3, and Chrome MV3 shares almost the entire surface. What's portable as-is:

- `manifest.json` (manifest_version 3, declarativeNetRequest static ruleset declaration)
- `rules.json` (the 116,944-rule compiled output of `engine-rs/examples/compile_rules.rs`, ~15 MB)
- `background.js` (service worker, MV3 patterns, `chrome.storage.local`, `webNavigation`, `runtime.onMessage`)
- `popup/popup.html`, `popup/popup.js` (queries the SW via `runtime.sendMessage({type:"stats"})`)
- `scripts/` (any sync / build helpers)

What's Safari-only in the current code:

- `background.js` calls `runtime.sendNativeMessage("com.albassam.mane.Extension", ...)` to ship stats to the Mac container app. Chrome's native messaging is a different model (host JSON manifest under `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/` plus a standalone host executable). For Chrome v1, drop this path entirely; the Chrome extension is standalone.
- `nativeMessaging` permission in the manifest can be removed for Chrome.
- The popup will keep working unchanged; no Mac bridge needed.

What's stale or worth a second pass:

- The `nativeMessaging` permission was added recently for the Safari bridge. Conditionally include it (Safari) or drop it (Chrome).
- Chrome's `declarativeNetRequest` static ruleset cap is 300,000 rules per ruleset (was 30k pre-Chrome 117, now much higher) and you can have up to 100 enabled rulesets. Our 116,944 is fine. Verify on the latest Chrome.

---

## Recommended layout

```
mane/
├── shared-ext/         # canonical extension source, used by both browsers
│   ├── manifest.template.json
│   ├── background.js
│   ├── popup/
│   ├── filters/
│   └── ...
├── safari-ext/         # generated: shared + Safari-specific manifest
└── chrome-ext/         # generated: shared + Chrome-specific manifest
```

Or, less ceremoniously, copy `safari-ext/` to `chrome-ext/` and prune the Safari-only bits. Either works; pick what fits the next session.

If you go with shared source:

- `manifest.template.json` has placeholders for `${nativeMessaging}` etc.
- A build script writes `safari-ext/manifest.json` and `chrome-ext/manifest.json` from the template, then symlinks (or copies) the shared assets.
- `rules.json` is shared via symlink so a single `./scripts/build-rules.sh` updates both.

The Safari extension currently uses an Xcode-managed bundle (`Mane Extension.appex`). The Chrome extension is a plain directory you load via `chrome://extensions/` → "Load unpacked". Different package shapes, same source.

---

## Step-by-step

### 1. Bootstrap `chrome-ext/`

```
chrome-ext/
├── manifest.json
├── background.js
├── popup/
│   ├── popup.html
│   └── popup.js
├── rules.json           # symlink to ../safari-ext/rules.json
├── images/              # icons
└── README.md            # install + dev instructions
```

### 2. Manifest

Start from `safari-ext/manifest.json`. Diff:

- Remove `"nativeMessaging"` from `permissions`.
- Add `"minimum_chrome_version"` (e.g. `"117"` for the bumped dNR limits).
- Add icon paths (Chrome wants 16/48/128 at minimum). Reuse the AppIcon PNGs we generated, or pull from `Assets.xcassets/AppIcon.appiconset/`.
- Keep `declarativeNetRequest`, `declarativeNetRequestFeedback`, `storage`, `webNavigation`, host_permissions `<all_urls>`, action.default_popup.

### 3. Background.js

The Safari-specific bits to strip or guard:

```js
// REMOVE: schedulePushToNative(), pushToNative(), pollControl(), applyEngineState()
// callers — these depend on the native bridge.
// REMOVE: nativeMessaging permission usage.
```

Or wrap the native-messaging block in a feature detect:

```js
const hasNativeBridge = typeof browser !== "undefined" && false; // Chrome: no native side
// ... only run pushToNative / pollControl when hasNativeBridge.
```

The `onRuleMatchedDebug` path is the one that *works on Chrome and not Safari*, so the live counter actually lights up natively in Chrome.

### 4. Popup

The popup queries `runtime.sendMessage({type:"stats"})`; the SW returns `{ready, blocked}`. Works as-is.

Consider adding an engine on/off toggle to the popup since the Chrome extension has no companion Mac app. A simple checkbox in the popup writes `chrome.storage.local` and `background.js` reads it on each `webNavigation.onCompleted` to apply via `updateEnabledRulesets`.

### 5. Icons

Drop the Mane logo into `chrome-ext/images/` as `icon-16.png`, `icon-48.png`, `icon-128.png`. Source: `mac-app/Mane/Mane/Assets.xcassets/AppIcon.appiconset/icon-{16,128}.png` (resize 128 → 48 with `sips -z 48 48`).

### 6. Test loop

```
1. Open chrome://extensions/, enable Developer mode, "Load unpacked" → chrome-ext/.
2. Visit theguardian.com or similar ad-heavy site. Ads should be blocked.
3. DevTools → service worker logs for `[Mane] getMatchedRules ->` lines. On Chrome
   the `onRuleMatchedDebug` listener also fires per match.
4. Open the popup. The blocked counter increments in real time on Chrome (unlike
   Safari, which only ticks on each navigation).
```

### 7. Distribution

For development, "Load unpacked" is enough. For shipping:

- Chrome Web Store: zip `chrome-ext/`, upload, pay the $5 developer fee, wait for review. Manifest needs `description`, `version`, and ideally a privacy policy URL.
- Edge / Brave / Arc: same package usually works. Edge has its own store and similar process.

Mane's positioning is "native ad blocker, no telemetry, no upsell". Match the listing copy.

---

## Out of scope for v1 Chrome

- **Cross-browser stats sync to the Mac dashboard.** Would need an HTTP server inside the Mac app on `localhost:N` that the Chrome extension POSTs stats to. Doable, ~half a day, but adds attack surface and isn't worth it until the Chrome extension actually ships. Park.
- **Cosmetic filtering / element picker.** Separate phase 4 deliverable; same scope on both browsers, do once.
- **Engine on/off from the Mac dashboard for Chrome.** Same blocker as stats sync; no IPC.

---

## Things the next agent should not re-derive

- The compiled rules at `safari-ext/rules.json` are produced by `cargo run --example compile_rules --release`. Both Safari and Chrome read the same file; do not re-implement rule compilation.
- The filter list metadata at `safari-ext/filterlists-meta.json` is also a build artefact of the same script. Nothing in the extension needs it (only the Mac app reads it).
- The Safari `Mane Extension` target's `SafariWebExtensionHandler.swift` is irrelevant to Chrome. Don't try to port it; Chrome's native bridge is a completely different (and out-of-scope) mechanism.
- macOS-only assumptions in `engine-rs` and `engine-swift` don't apply to the browser extension at all. The browser extension is pure JS plus the bundled `rules.json`.

---

## Acceptance criteria for the Chrome build

- [ ] `chrome-ext/` directory loads via "Load unpacked" with no manifest errors.
- [ ] Ads are blocked on theguardian.com after the extension is enabled (visual inspection: ad slots are empty / pages load measurably faster).
- [ ] Popup shows a non-zero `blocked` count after a couple of page loads.
- [ ] `chrome.storage.local` persists the count across SW restarts.
- [ ] Per-domain breakdown is recorded (verify by reading `chrome.storage.local.get("mane.stats.v1")` from the DevTools console on the extension's background page).
- [ ] Engine on/off toggle in the popup actually disables blocking (verify by toggling off, reloading an ad-heavy page, observing ads come back; toggle on, reload, ads gone).

When those tick, the Chrome side of phase 4 is shippable.

---

## What to ask Abdulla before starting

- Should the Chrome extension be its own published listing or a developer-mode-only artefact for now? Affects how much polish (privacy policy, store screenshots, listing copy) belongs in this phase.
- Logo identical to Safari (the chroma-keyed transparent PNG) or a slight variation for Chrome? Probably identical.
- One toggle in the popup (master), or split by content type (ads vs trackers vs social)? The Mac app went master; consistency suggests popup goes master too.

Nothing else should require Abdulla input; the rest is straightforward execution.
