// Mane background service worker.
//
// Network blocking is performed by the bundled declarativeNetRequest ruleset
// (manifest.json declares it, rules.json contains it). The browser blocks
// ad requests itself in its network stack using rules compiled from EasyList
// + EasyPrivacy at build time by the engine-rs compile_rules example.
//
// This service worker only:
//   - tracks how many rules have matched in this session (best-effort)
//   - answers the popup's stats query

const ext = globalThis.browser ?? globalThis.chrome;

let blockedCount = 0;

if (ext.declarativeNetRequest?.onRuleMatchedDebug) {
  ext.declarativeNetRequest.onRuleMatchedDebug.addListener(() => {
    blockedCount += 1;
  });
}

ext.runtime.onMessage.addListener((msg, _sender, send) => {
  if (msg?.type === "stats") {
    send({ blocked: blockedCount, ready: true });
    return true;
  }
  return false;
});
