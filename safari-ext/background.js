// Mane background service worker.
//
// On boot: load EasyList + EasyPrivacy from the bundle, hand them to the
// WASM engine, then call engine.check() for every outgoing request. If the
// engine boot fails for any reason, the listener falls through and allows
// every request rather than breaking the page.

import init, { Engine } from "./engine/mane_engine_wasm.js";

const ext = globalThis.browser ?? globalThis.chrome;

const FILTER_LISTS = [
  "filters/easylist.txt",
  "filters/easyprivacy.txt",
];

let engine = null;
let blockedCount = 0;

async function loadFilterLists() {
  const sources = await Promise.all(
    FILTER_LISTS.map(async (path) => {
      const url = ext.runtime.getURL(path);
      const res = await fetch(url);
      if (!res.ok) {
        throw new Error(`failed to load ${path}: HTTP ${res.status}`);
      }
      return res.text();
    }),
  );
  return sources.join("\n");
}

async function bootEngine() {
  try {
    await init(ext.runtime.getURL("engine/mane_engine_wasm_bg.wasm"));
    const rules = await loadFilterLists();
    engine = new Engine(rules);
    console.log("[Mane] engine ready");
  } catch (err) {
    console.error("[Mane] engine boot failed:", err);
  }
}

ext.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (!engine) return {};
    const source = details.initiator ?? details.documentUrl ?? "";
    if (engine.check(details.url, source, details.type)) {
      blockedCount += 1;
      return { cancel: true };
    }
    return {};
  },
  { urls: ["<all_urls>"] },
  ["blocking"],
);

ext.runtime.onMessage.addListener((msg, _sender, send) => {
  if (msg?.type === "stats") {
    send({ blocked: blockedCount, ready: engine !== null });
    return true;
  }
  return false;
});

bootEngine();
