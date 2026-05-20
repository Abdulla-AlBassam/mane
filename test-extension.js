// Autonomous live test of the Mane ad-blocker in Chromium with the extension
// loaded. Drives ad-heavy sites, captures network requests, popups, console
// errors, and queries the extension's matched-rules count. Output goes to
// test-output/report.json.

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const extensionPath = path.resolve(__dirname, 'chrome-ext');
const outDir = path.resolve(__dirname, 'test-output');
fs.mkdirSync(outDir, { recursive: true });

const TEST_SITES = [
    { name: 'theguardian',  url: 'https://www.theguardian.com' },
    { name: 'dailymail',    url: 'https://www.dailymail.co.uk' },
    { name: 'forbes',       url: 'https://www.forbes.com' },
    { name: 'aliexpress',   url: 'https://www.aliexpress.com' },
    { name: 'bbc-sport',    url: 'https://www.bbc.co.uk/sport' },
    { name: 'strikeout',    url: 'https://strikeout.im' },
];

const NAV_TIMEOUT = 30000;
const SETTLE_MS = 6000;

async function testSite(context, { name, url }) {
    const page = await context.newPage();

    const requests = [];
    const blocked = [];
    const consoleMessages = [];
    const popups = [];
    const pageErrors = [];

    page.on('request', (req) => {
        requests.push({ url: req.url(), type: req.resourceType(), method: req.method() });
    });
    page.on('requestfailed', (req) => {
        const f = req.failure();
        blocked.push({
            url: req.url(),
            type: req.resourceType(),
            error: f?.errorText ?? 'unknown',
        });
    });
    page.on('console', (msg) => {
        if (msg.type() === 'error') {
            consoleMessages.push({ type: msg.type(), text: msg.text() });
        }
    });
    page.on('popup', (popup) => {
        popups.push({ url: popup.url() });
        popup.close().catch(() => {});
    });
    page.on('pageerror', (err) => {
        pageErrors.push(String(err));
    });

    let navError = null;
    try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: NAV_TIMEOUT });
        await page.waitForTimeout(SETTLE_MS);
    } catch (err) {
        navError = err.message;
    }

    let title = null;
    try { title = await page.title(); } catch {}

    // Take a screenshot for visual inspection
    try {
        await page.screenshot({
            path: path.join(outDir, `${name}.png`),
            fullPage: false,
        });
    } catch {}

    const blockedDomains = {};
    for (const b of blocked) {
        try {
            const host = new URL(b.url).hostname;
            blockedDomains[host] = (blockedDomains[host] ?? 0) + 1;
        } catch {}
    }

    const result = {
        site: name,
        url,
        title,
        navError,
        totalRequests: requests.length,
        blockedRequestCount: blocked.length,
        blockedDomainsTop: Object.entries(blockedDomains)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 20)
            .map(([host, n]) => ({ host, count: n })),
        popups: popups,
        pageErrors: pageErrors.slice(0, 10),
        consoleErrorSamples: consoleMessages.slice(0, 8).map(m => m.text),
    };

    await page.close();
    return result;
}

(async () => {
    const userDataDir = `/tmp/mane-test-profile-${Date.now()}`;
    console.log(`Launching Chromium with extension from ${extensionPath}`);

    const context = await chromium.launchPersistentContext(userDataDir, {
        headless: false,
        args: [
            `--disable-extensions-except=${extensionPath}`,
            `--load-extension=${extensionPath}`,
            '--no-first-run',
            '--no-default-browser-check',
            '--disable-blink-features=AutomationControlled',
        ],
        viewport: { width: 1280, height: 800 },
        ignoreHTTPSErrors: true,
    });

    // Wait for service worker to come up
    let worker = context.serviceWorkers()[0];
    if (!worker) {
        try {
            worker = await context.waitForEvent('serviceworker', { timeout: 15000 });
        } catch {}
    }
    console.log(`Service worker: ${worker ? worker.url() : 'NOT FOUND'}`);

    // Capture any console output from the service worker
    const swErrors = [];
    if (worker) {
        // Service worker console isn't directly capturable, but we can evaluate state
        try {
            const initialState = await worker.evaluate(async () => {
                const result = { hasNetRequest: !!chrome.declarativeNetRequest };
                if (chrome.declarativeNetRequest) {
                    try {
                        const enabled = await chrome.declarativeNetRequest.getEnabledRulesets();
                        result.enabledRulesets = enabled;
                    } catch (e) { result.enabledError = e.message; }
                    try {
                        const avail = await chrome.declarativeNetRequest.getAvailableStaticRuleCount();
                        result.availableRules = avail;
                    } catch (e) { result.availError = e.message; }
                }
                return result;
            });
            console.log('Initial extension state:', JSON.stringify(initialState));
        } catch (err) {
            console.log('Service worker evaluate failed:', err.message);
        }
    }

    const results = [];
    for (const site of TEST_SITES) {
        const t0 = Date.now();
        process.stdout.write(`Testing ${site.name}... `);
        try {
            const r = await testSite(context, site);
            const elapsed = Date.now() - t0;
            results.push({ ...r, elapsedMs: elapsed });
            console.log(`requests=${r.totalRequests} blocked=${r.blockedRequestCount} popups=${r.popups.length} (${elapsed}ms)`);
        } catch (err) {
            results.push({ site: site.name, error: err.message });
            console.log(`ERROR ${err.message}`);
        }
    }

    // Get matched rules from extension
    let matched = null;
    if (worker) {
        try {
            matched = await worker.evaluate(async () => {
                try {
                    const r = await chrome.declarativeNetRequest.getMatchedRules({});
                    const matches = r.rulesMatchedInfo || [];
                    const byDomain = {};
                    for (const m of matches) {
                        try {
                            const host = new URL(m.request?.url || '').hostname;
                            byDomain[host] = (byDomain[host] || 0) + 1;
                        } catch {}
                    }
                    return {
                        total: matches.length,
                        topDomains: Object.entries(byDomain)
                            .sort((a,b) => b[1] - a[1])
                            .slice(0, 30)
                            .map(([h,n]) => ({ host: h, count: n })),
                    };
                } catch (e) {
                    return { error: e.message };
                }
            });
        } catch (e) {
            matched = { evalError: e.message };
        }
    }

    const report = {
        timestamp: new Date().toISOString(),
        extensionPath,
        sites: results,
        extensionMatchedRules: matched,
    };

    const out = path.join(outDir, 'report.json');
    fs.writeFileSync(out, JSON.stringify(report, null, 2));
    console.log(`\nReport: ${out}`);

    await context.close();
})().catch(err => {
    console.error('Fatal:', err);
    process.exit(1);
});
