// Mane background service worker (Chrome).
//
// Network blocking is performed by the bundled declarativeNetRequest ruleset.
// This worker aggregates per-day/per-domain stats and persists them, plus
// enabled/disabled state, via chrome.storage.local. The popup is the only UI
// surface on Chrome; there is no native messaging or external dashboard.

const ext = globalThis.browser ?? globalThis.chrome;

const STORAGE_KEY = "mane.stats.v1";
const TS_KEY = "mane.lastMatchTs.v1";
const ENGINE_KEY = "mane.engineEnabled.v1";
const STATS_VERSION = 1;

let stats = null;
let lastSeenMatchTimestamp = 0;
let initialised = false;
let persistTimer = null;
let currentlyEnabled = true;

function todayKey() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dy = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dy}`;
}

function currentHour() {
  return new Date().getHours();
}

function hostFromUrl(url) {
  try {
    return new URL(url).hostname || "unknown";
  } catch {
    return "unknown";
  }
}

function getDayBucket(day) {
  if (!stats.days[day]) {
    stats.days[day] = { total: 0, byDomain: {}, byHour: new Array(24).fill(0) };
  } else if (!stats.days[day].byHour) {
    stats.days[day].byHour = new Array(24).fill(0);
  }
  return stats.days[day];
}

function schedulePersist() {
  if (persistTimer) return;
  persistTimer = setTimeout(async () => {
    persistTimer = null;
    if (!stats) return;
    try {
      await ext.storage.local.set({
        [STORAGE_KEY]: stats,
        [TS_KEY]: lastSeenMatchTimestamp,
      });
    } catch (err) {
      console.error("[Mane] persist failed", err);
    }
  }, 250);
}

function recordOneMatch(url) {
  const day = todayKey();
  const bucket = getDayBucket(day);
  const host = hostFromUrl(url);
  const hour = currentHour();
  bucket.total += 1;
  bucket.byDomain[host] = (bucket.byDomain[host] ?? 0) + 1;
  bucket.byHour[hour] = (bucket.byHour[hour] ?? 0) + 1;
}

function ingestMatches(matches) {
  if (!Array.isArray(matches)) return 0;
  let added = 0;
  for (const m of matches) {
    const ts = m.timeStamp ?? 0;
    if (ts > 0 && ts <= lastSeenMatchTimestamp) continue;
    if (ts > lastSeenMatchTimestamp) lastSeenMatchTimestamp = ts;
    recordOneMatch(m.request?.url ?? "");
    added += 1;
  }
  if (added > 0) schedulePersist();
  return added;
}

async function applyEngineState(enabled, force = false) {
  if (!force && enabled === currentlyEnabled) return;
  if (!ext.declarativeNetRequest?.updateEnabledRulesets) return;
  try {
    await ext.declarativeNetRequest.updateEnabledRulesets({
      enableRulesetIds: enabled ? ["mane-main"] : [],
      disableRulesetIds: enabled ? [] : ["mane-main"],
    });
    currentlyEnabled = enabled;
    console.log("[Mane] ruleset", enabled ? "enabled" : "disabled");
  } catch (err) {
    console.error("[Mane] applyEngineState failed:", err);
  }
}

async function setEngineEnabled(enabled) {
  await applyEngineState(enabled);
  try {
    await ext.storage.local.set({ [ENGINE_KEY]: enabled });
  } catch (err) {
    console.error("[Mane] persist engine state failed:", err);
  }
}

async function loadInitialState() {
  try {
    const result = await ext.storage.local.get([STORAGE_KEY, TS_KEY, ENGINE_KEY]);
    const stored = result[STORAGE_KEY];
    stats = stored && stored.version === STATS_VERSION
      ? stored
      : { version: STATS_VERSION, days: {} };
    lastSeenMatchTimestamp = result[TS_KEY] ?? 0;
    const storedEnabled = result[ENGINE_KEY];
    if (typeof storedEnabled === "boolean") {
      currentlyEnabled = storedEnabled;
    }
  } catch (err) {
    console.error("[Mane] load failed", err);
    stats = { version: STATS_VERSION, days: {} };
  }
  initialised = true;
  await applyEngineState(currentlyEnabled, true);
  console.log(
    "[Mane] init complete; engine =",
    currentlyEnabled,
    "today =",
    stats.days[todayKey()]?.total ?? 0
  );
}

if (ext.declarativeNetRequest?.onRuleMatchedDebug) {
  ext.declarativeNetRequest.onRuleMatchedDebug.addListener((info) => {
    if (!initialised) return;
    recordOneMatch(info.request?.url ?? "");
    schedulePersist();
  });
}

async function pollMatchedRules() {
  if (!initialised) return;
  const api = ext.declarativeNetRequest?.getMatchedRules;
  if (!api) return;
  try {
    const result = await ext.declarativeNetRequest.getMatchedRules({});
    ingestMatches(result?.rulesMatchedInfo ?? []);
  } catch {}
}

if (ext.webNavigation?.onCompleted) {
  ext.webNavigation.onCompleted.addListener((details) => {
    if (details.frameId === 0) pollMatchedRules();
  });
}

ext.runtime.onMessage.addListener((msg, _sender, send) => {
  if (!initialised || !stats) {
    send({ ready: false, blocked: 0, enabled: currentlyEnabled });
    return true;
  }
  if (msg?.type === "stats") {
    const today = stats.days[todayKey()] ?? { total: 0 };
    send({ blocked: today.total, ready: true, enabled: currentlyEnabled });
    return true;
  }
  if (msg?.type === "getStats") {
    send({ ready: true, stats, enabled: currentlyEnabled });
    return true;
  }
  if (msg?.type === "setEnabled") {
    (async () => {
      await setEngineEnabled(!!msg.enabled);
      const today = stats.days[todayKey()] ?? { total: 0 };
      send({ blocked: today.total, ready: true, enabled: currentlyEnabled });
    })();
    return true;
  }
  return false;
});

loadInitialState();
