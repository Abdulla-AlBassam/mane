// Cleaner functional test: drives the toggle through the actual popup
// (which is how a real user would), and measures blocking effectiveness
// by counting ad-domain requests with engine on vs off.

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const extensionPath = path.resolve(__dirname, 'chrome-ext');
const outDir = path.resolve(__dirname, 'test-output');
fs.mkdirSync(outDir, { recursive: true });

const TEST_URL = 'https://www.theguardian.com';
const AD_KEYWORDS = ['doubleclick', 'amazon-adsystem', 'adsrvr', 'adnxs',
    'openx', 'gumgum', 'adsafeprotected', 'smartadserver', 'pubmatic',
    'criteo', 'taboola', 'outbrain', 'rubicon', 'permutive', 'id5-sync',
    'bidswitch', 'presage'];

function tally(requests) {
    const ads = requests.filter(u => AD_KEYWORDS.some(k => u.includes(k)));
    return { total: requests.length, ads: ads.length, sampleAds: ads.slice(0, 4) };
}

async function getSwState(worker) {
    return worker.evaluate(async () => {
        const enabled = await chrome.declarativeNetRequest.getEnabledRulesets();
        const stored = await chrome.storage.local.get(['mane.engineEnabled.v1']);
        return { enabledRulesets: enabled, storedEnabled: stored['mane.engineEnabled.v1'] };
    });
}

async function visitAndCount(context, url) {
    const page = await context.newPage();
    const requests = [];
    page.on('request', (req) => requests.push(req.url()));
    try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(5000);
    } catch {}
    await page.close();
    return tally(requests);
}

async function clickPopupToggle(context, extId) {
    const popup = await context.newPage();
    await popup.goto(`chrome-extension://${extId}/popup/popup.html`);
    await popup.waitForTimeout(500);
    const before = await popup.evaluate(() => ({
        status: document.getElementById('status').textContent,
        on: document.getElementById('toggle').classList.contains('on'),
    }));
    await popup.click('#toggle');
    await popup.waitForTimeout(800);
    const after = await popup.evaluate(() => ({
        status: document.getElementById('status').textContent,
        on: document.getElementById('toggle').classList.contains('on'),
    }));
    await popup.close();
    return { before, after };
}

(async () => {
    const userDir = `/tmp/mane-chrome-v2-${Date.now()}`;
    const context = await chromium.launchPersistentContext(userDir, {
        headless: false,
        args: [
            `--disable-extensions-except=${extensionPath}`,
            `--load-extension=${extensionPath}`,
            '--no-first-run',
            '--no-default-browser-check',
        ],
        viewport: { width: 1280, height: 800 },
        ignoreHTTPSErrors: true,
    });

    let worker = context.serviceWorkers()[0];
    if (!worker) worker = await context.waitForEvent('serviceworker', { timeout: 15000 });
    const extId = worker.url().match(/chrome-extension:\/\/([a-z]+)\//)[1];
    await new Promise(r => setTimeout(r, 1500));

    const findings = [];
    const bugs = [];

    // === Step 1: Verify initial state ===
    const s1 = await getSwState(worker);
    console.log('1. Initial:', JSON.stringify(s1));
    findings.push({ step: 'initial-sw', ...s1 });
    if (!s1.enabledRulesets.includes('mane-main')) bugs.push('init: ruleset not enabled');

    // === Step 2: Engine ON visit ===
    console.log('2. Visit with engine ON...');
    const v1 = await visitAndCount(context, TEST_URL);
    console.log('   total=' + v1.total + ' ads=' + v1.ads + ' sample=' + JSON.stringify(v1.sampleAds));
    findings.push({ step: 'visit-on', ...v1 });

    // === Step 3: Click popup toggle to OFF ===
    console.log('3. Popup click to OFF...');
    const c1 = await clickPopupToggle(context, extId);
    console.log('   ', JSON.stringify(c1));
    findings.push({ step: 'popup-click-1', ...c1 });
    if (c1.after.on !== false) bugs.push('popup: toggle did not flip to off');
    const s2 = await getSwState(worker);
    console.log('   sw:', JSON.stringify(s2));
    findings.push({ step: 'after-off-sw', ...s2 });
    if (s2.enabledRulesets.length !== 0) bugs.push('popup off: ruleset not disabled');
    if (s2.storedEnabled !== false) bugs.push('popup off: storage not persisted');

    // === Step 4: Engine OFF visit ===
    console.log('4. Visit with engine OFF...');
    const v2 = await visitAndCount(context, TEST_URL);
    console.log('   total=' + v2.total + ' ads=' + v2.ads + ' sample=' + JSON.stringify(v2.sampleAds));
    findings.push({ step: 'visit-off', ...v2 });
    if (v2.ads <= v1.ads) {
        bugs.push(`blocking ineffective: with-off ads (${v2.ads}) not greater than with-on ads (${v1.ads})`);
    }

    // === Step 5: Click popup toggle to ON ===
    console.log('5. Popup click back to ON...');
    const c2 = await clickPopupToggle(context, extId);
    console.log('   ', JSON.stringify(c2));
    findings.push({ step: 'popup-click-2', ...c2 });
    if (c2.after.on !== true) bugs.push('popup: toggle did not flip back to on');
    const s3 = await getSwState(worker);
    console.log('   sw:', JSON.stringify(s3));
    findings.push({ step: 'after-on-sw', ...s3 });
    if (!s3.enabledRulesets.includes('mane-main')) bugs.push('popup on: ruleset not re-enabled');

    // === Step 6: Engine ON visit again ===
    console.log('6. Visit again with engine ON...');
    const v3 = await visitAndCount(context, TEST_URL);
    console.log('   total=' + v3.total + ' ads=' + v3.ads);
    findings.push({ step: 'visit-on-again', ...v3 });

    // Sanity: v3.ads should be close to v1.ads (both engine on)
    // and both should be lower than v2.ads (engine off)

    const summary = {
        engineOn1: { ads: v1.ads, total: v1.total },
        engineOff:  { ads: v2.ads, total: v2.total },
        engineOn2: { ads: v3.ads, total: v3.total },
        blockingEffectiveness: v2.ads > 0 ? ((v2.ads - v1.ads) / v2.ads * 100).toFixed(1) + '%' : 'n/a',
    };
    findings.push({ step: 'summary', ...summary });
    console.log('\nSummary:', JSON.stringify(summary, null, 2));

    fs.writeFileSync(path.join(outDir, 'chrome-functional-v2.json'), JSON.stringify(findings, null, 2));

    if (bugs.length === 0) {
        console.log('\n=== ALL CHECKS PASSED ===');
    } else {
        console.log('\n=== ' + bugs.length + ' BUG(S) FOUND ===');
        for (const b of bugs) console.log('  -', b);
    }

    await context.close();
    process.exit(bugs.length === 0 ? 0 : 1);
})().catch(err => { console.error('Fatal:', err); process.exit(1); });
