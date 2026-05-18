// Mane background service worker.
//
// Phase 3 scaffold: filter lists load, the request listener is registered,
// blocked counts are tracked. The matching engine is a stub that returns
// false for every request. Phase 3b will replace the stub with a WASM build
// of Brave's adblock-rust crate.

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
  return sources;
}

function buildStubEngine(rawLists) {
  const ruleCount = rawLists.reduce(
    (sum, text) => sum + text.split("\n").filter((l) => l && !l.startsWith("!")).length,
    0,
  );
  return {
    ruleCount,
    matches(_url, _sourceUrl, _type) {
      return false;
    },
  };
}

async function bootEngine() {
  try {
    const rawLists = await loadFilterLists();
    // TODO(phase-3b): replace stub with adblock-rust compiled to WASM.
    // Build the engine off the loaded list text, then call engine.matches
    // from the webRequest listener below.
    engine = buildStubEngine(rawLists);
    console.log(`[Mane] engine ready: ${engine.ruleCount} rules`);
  } catch (err) {
    console.error("[Mane] engine boot failed:", err);
  }
}

ext.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (!engine) return {};
    const source = details.initiator ?? details.documentUrl ?? "";
    if (engine.matches(details.url, source, details.type)) {
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
