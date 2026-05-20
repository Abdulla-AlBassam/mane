// Better test: query getMatchedRules per-site before closing the tab, and run
// a baseline pass without the extension for diffing. Distinguishes
// extension-initiated blocks from generic network failures by inspecting
// the failure error text.

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
    { name: 'bbc-sport',    url: 'https://www.bbc.co.uk/sport' },
    { name: 'aliexpress',   url: 'https://www.aliexpress.com' },
];

const NAV_TIMEOUT = 30000;
const SETTLE_MS = 6000;

function hostOf(u) {
    try { return new URL(u).hostname; } catch { return null; }
}

async function loadSite(page, url) {
    const requests = [];
    const failed = [];
    const popups = [];

    page.on('request', (req) => {
        requests.push({ url: req.url(), type: req.resourceType() });
    });
    page.on('requestfailed', (req) => {
        const f = req.failure();
        failed.push({
            url: req.url(),
            type: req.resourceType(),
            error: f?.errorText ?? 'unknown',
        });
    });
    page.on('popup', (popup) => {
        popups.push(popup.url());
        popup.close().catch(() => {});
    });

    let navError = null;
    try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: NAV_TIMEOUT });
        await page.waitForTimeout(SETTLE_MS);
    } catch (err) {
        navError = err.message;
    }

    return { requests, failed, popups, navError };
}

async function runPass(passName, withExtension) {
    const userDir = `/tmp/mane-${passName}-${Date.now()}`;
    const launchArgs = [
        '--no-first-run',
        '--no-default-browser-check',
    ];
    if (withExtension) {
        launchArgs.push(`--disable-extensions-except=${extensionPath}`);
        launchArgs.push(`--load-extension=${extensionPath}`);
    }

    const context = await chromium.launchPersistentContext(userDir, {
        headless: false,
        args: launchArgs,
        viewport: { width: 1280, height: 800 },
        ignoreHTTPSErrors: true,
    });

    let worker = null;
    if (withExtension) {
        worker = context.serviceWorkers()[0];
        if (!worker) {
            try { worker = await context.waitForEvent('serviceworker', { timeout: 15000 }); } catch {}
        }
    }

    const results = [];
    for (const site of TEST_SITES) {
        const t0 = Date.now();
        process.stdout.write(`  ${site.name}... `);
        const page = await context.newPage();
        const { requests, failed, popups, navError } = await loadSite(page, site.url);

        let matchedHere = null;
        if (worker) {
            try {
                matchedHere = await worker.evaluate(async () => {
                    try {
                        const r = await chrome.declarativeNetRequest.getMatchedRules({});
                        return (r.rulesMatchedInfo || []).map(m => ({
                            url: m.request?.url,
                            ruleId: m.rule?.ruleId,
                            tabId: m.tabId,
                        }));
                    } catch (e) { return { error: e.message }; }
                });
            } catch {}
        }

        // Take screenshot
        try {
            await page.screenshot({
                path: path.join(outDir, `${passName}-${site.name}.png`),
                fullPage: false,
            });
        } catch {}

        // Domain stats
        const requestDomains = {};
        for (const r of requests) {
            const h = hostOf(r.url);
            if (h) requestDomains[h] = (requestDomains[h] ?? 0) + 1;
        }
        const failedDomains = {};
        const extBlockedDomains = {};
        for (const f of failed) {
            const h = hostOf(f.url);
            if (!h) continue;
            failedDomains[h] = (failedDomains[h] ?? 0) + 1;
            if (f.error.includes('BLOCKED_BY_CLIENT') || f.error.includes('blocked')) {
                extBlockedDomains[h] = (extBlockedDomains[h] ?? 0) + 1;
            }
        }
        const matchedByDomain = {};
        if (Array.isArray(matchedHere)) {
            for (const m of matchedHere) {
                const h = hostOf(m.url);
                if (h) matchedByDomain[h] = (matchedByDomain[h] ?? 0) + 1;
            }
        }

        results.push({
            site: site.name,
            url: site.url,
            elapsedMs: Date.now() - t0,
            navError,
            totalRequests: requests.length,
            uniqueRequestDomains: Object.keys(requestDomains).length,
            failedCount: failed.length,
            extensionBlockedCount: Array.isArray(matchedHere) ? matchedHere.length : 0,
            popups,
            sampleFailureErrors: [...new Set(failed.map(f => f.error))].slice(0, 10),
            topRequestDomains: Object.entries(requestDomains).sort((a,b) => b[1]-a[1]).slice(0, 25)
                .map(([h,n]) => ({ host: h, count: n })),
            extensionBlockedTopDomains: Object.entries(matchedByDomain).sort((a,b)=>b[1]-a[1]).slice(0,25)
                .map(([h,n]) => ({ host: h, count: n })),
        });

        console.log(`req=${requests.length} extBlocked=${results[results.length-1].extensionBlockedCount} fail=${failed.length} popups=${popups.length}`);

        await page.close();
    }

    await context.close();
    return results;
}

(async () => {
    console.log('== Pass 1: baseline (no extension) ==');
    const baseline = await runPass('baseline', false);
    console.log('\n== Pass 2: with Mane extension ==');
    const extn = await runPass('extension', true);

    // Diff: which domains are present in baseline but not in extension's requests
    const diff = {};
    for (let i = 0; i < TEST_SITES.length; i++) {
        const site = TEST_SITES[i];
        const b = baseline[i];
        const e = extn[i];
        const baselineSet = new Map(b.topRequestDomains.map(d => [d.host, d.count]));
        const extnSet = new Map(e.topRequestDomains.map(d => [d.host, d.count]));
        const reducedDomains = [];
        const escapedDomains = [];
        for (const [host, baseN] of baselineSet) {
            const extN = extnSet.get(host) || 0;
            if (extN === 0) {
                reducedDomains.push({ host, before: baseN, after: 0 });
            } else if (extN < baseN) {
                reducedDomains.push({ host, before: baseN, after: extN });
            }
        }
        // Identify potential trackers/ads still appearing in extension run
        const adKeywords = ['ads', 'doubleclick', 'analytics', 'tracker', 'pixel', 'tag', 'criteo', 'taboola', 'outbrain', 'amazon-ad', 'facebook', 'permutive', 'pubmatic', 'rubicon', 'adnxs', 'openx', 'adsrvr'];
        for (const [host, n] of extnSet) {
            if (adKeywords.some(k => host.toLowerCase().includes(k))) {
                escapedDomains.push({ host, count: n });
            }
        }
        diff[site.name] = {
            baselineRequests: b.totalRequests,
            extensionRequests: e.totalRequests,
            extensionBlockedReported: e.extensionBlockedCount,
            reducedDomainsCount: reducedDomains.length,
            topReducedDomains: reducedDomains.sort((a,b) => (b.before-b.after) - (a.before-a.after)).slice(0, 15),
            possiblyEscapedAdDomains: escapedDomains,
            popupDifference: { baseline: b.popups, extension: e.popups },
        };
    }

    const report = {
        timestamp: new Date().toISOString(),
        baseline,
        extension: extn,
        diff,
    };

    fs.writeFileSync(path.join(outDir, 'report-v2.json'), JSON.stringify(report, null, 2));
    console.log('\nReport written to test-output/report-v2.json');
})().catch(err => {
    console.error('Fatal:', err);
    process.exit(1);
});
