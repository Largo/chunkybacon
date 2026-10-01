// Load-time measurement of the site (docs/PICORUBY_SHELL.md): how soon the
// lesson can be read, how soon its first cell has run, and how many bytes
// that took. Needs a server with gzip like nginx/default.conf (a dev copy of the site).
//
//   BASE=http://127.0.0.1:18011/ LABEL=prototype RUNS=3 node tools/measure_load.mjs
//   PROFILES=warm ...                     # a repeat visit instead
//   BASE="http://127.0.0.1:18011/?kernel=eager" ...   # CRuby beside the shell
//   SITES="baseline=http://127.0.0.1:18012/,prototype=http://127.0.0.1:18011/" ...
//       # several sites, their runs interleaved, so a busy machine slows all alike
//
// (Playwright is imported from the server path, like test/browser_test.mjs.)
// Every run uses a fresh browser context (cold cache). Metrics, all measured
// in the page from navigation start (performance.now()):
//   readable  - the lesson's <h2> is in the page and laid out (next frame)
//   ran       - #cell-out-1 of #hallo shows "=> 2" after clicking its Run
//               button as soon as the button exists (next frame)
//   bytes     - encodedDataLength of every response (CDP), up to readable,
//               up to ran, and in total once the network went quiet
// PROFILES: "fast" (no throttling), "20mbit" (20 Mbit/s down, 40 ms RTT),
// "warm" (a second visit in the same browser context). Results go to
// tmp/results/<LABEL>.json.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';
import { writeFileSync, mkdirSync } from 'node:fs';

const SITES = process.env.SITES
  ? process.env.SITES.split(',').map(s => { const i = s.indexOf('='); return { label: s.slice(0, i), base: s.slice(i + 1) }; })
  : [{ label: process.env.LABEL || 'site', base: process.env.BASE || 'http://127.0.0.1:18011/' }];
const RUNS = Number(process.env.RUNS || 3);
const PROFILES = (process.env.PROFILES || 'fast,20mbit').split(',');
const OUT = process.env.OUT || 'tmp/results';

const THROTTLE = {
  fast: null,
  warm: null,
  '20mbit': { offline: false, latency: 40, downloadThroughput: 20e6 / 8, uploadThroughput: 5e6 / 8 }
};

// installed before any page script: records when the metrics happen
const probe = () => {
  window.__m = {};
  const mark = k => { if (!(k in window.__m)) window.__m[k] = performance.now(); };
  let clicked = false;
  const look = () => {
    const h2 = document.querySelector('#lessonBody h2');
    if (h2 && !window.__m.readableSeen && h2.getClientRects().length > 0) {
      window.__m.readableSeen = performance.now();
      requestAnimationFrame(() => mark('readable'));
    }
    const btn = document.querySelector('.run-cell[data-idx="1"]');
    if (btn && !clicked && btn.getClientRects().length > 0) {
      clicked = true;
      window.__m.buttonSeen = performance.now();
      setTimeout(() => btn.click(), 0);
    }
    const out = document.getElementById('cell-out-1');
    if (out && !window.__m.ranSeen && out.textContent.includes('=> 2')) {
      window.__m.ranSeen = performance.now();
      requestAnimationFrame(() => mark('ran'));
    }
  };
  new MutationObserver(look).observe(document, { subtree: true, childList: true, characterData: true, attributes: true });
  window.addEventListener('chunky:kernel-ready', () => mark('kernelReady'));
  window.addEventListener('chunky:shell-ready', () => mark('shellReady'));
};

function category(url) {
  const path = new URL(url).pathname;
  if (path.includes('/assets/picoruby/')) return 'picoruby';
  if (path.includes('/shell/')) return 'shell';
  if (/ruby\+stdlib\.wasm|browser\.script\.iife\.js|\.rb$|\/gems\//.test(path)) return 'cruby';
  return 'common';
}

async function once(browser, profile, BASE) {
  const ctx = await browser.newContext();
  await ctx.addInitScript(probe);
  if (profile === 'warm') {
    // a returning learner: the same browser has loaded the site before
    const first = await ctx.newPage();
    await first.goto(BASE + '#hallo', { waitUntil: 'commit' });
    await first.waitForFunction(() => window.__m && window.__m.ran, null, { timeout: 300000, polling: 200 });
    await first.waitForTimeout(1500);
    await first.close();
  }
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Network.enable');
  if (profile !== 'warm') await cdp.send('Network.clearBrowserCache');
  if (THROTTLE[profile]) await cdp.send('Network.emulateNetworkConditions', THROTTLE[profile]);

  const urls = new Map();
  const done = [];   // { wall, bytes, cat }
  let clockOffset = null;   // wallTime - monotonic timestamp, seconds
  cdp.on('Network.requestWillBeSent', e => {
    urls.set(e.requestId, e.request.url);
    if (clockOffset === null && e.wallTime) clockOffset = e.wallTime - e.timestamp;
  });
  cdp.on('Network.loadingFinished', e => {
    const url = urls.get(e.requestId) || '';
    if (!url.startsWith('http')) return;
    done.push({ wall: (e.timestamp + clockOffset) * 1000, bytes: e.encodedDataLength, cat: category(url), url });
  });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));

  await page.goto(BASE + '#hallo', { waitUntil: 'commit' });
  await page.waitForFunction(() => window.__m && window.__m.ran, null, { timeout: 300000, polling: 200 });
  // let the network go quiet (late fetches: three.js preload, gem manifest ...)
  let last = -1;
  for (let i = 0; i < 20; i++) {
    await page.waitForTimeout(500);
    if (done.length === last) break;
    last = done.length;
  }
  const m = await page.evaluate(() => ({ ...window.__m, timeOrigin: performance.timeOrigin,
    fcp: (performance.getEntriesByName('first-contentful-paint')[0] || {}).startTime }));
  const upTo = t => done.filter(d => d.wall <= m.timeOrigin + t).reduce((s, d) => s + d.bytes, 0);
  const byCat = {};
  for (const d of done) byCat[d.cat] = (byCat[d.cat] || 0) + d.bytes;
  const result = {
    profile,
    fcp: m.fcp, readable: m.readable, shellReady: m.shellReady, kernelReady: m.kernelReady, ran: m.ran,
    bytesReadable: upTo(m.readable), bytesRan: upTo(m.ran),
    bytesTotal: done.reduce((s, d) => s + d.bytes, 0), requests: done.length, byCat, errors
  };
  await ctx.close();
  return result;
}

const median = xs => {
  const v = xs.filter(x => typeof x === 'number').sort((a, b) => a - b);
  return v.length ? v[Math.floor(v.length / 2)] : null;
};

const browser = await chromium.launch();
mkdirSync(OUT, { recursive: true });
const all = {};   // label -> profile -> runs
for (const site of SITES) all[site.label] = {};
for (const profile of PROFILES) {
  for (let i = 0; i < RUNS; i++) {
    for (const site of SITES) {
      const r = await once(browser, profile, site.base);
      console.log(`${site.label} ${profile} run ${i + 1}: readable ${Math.round(r.readable)} ms, ran ${Math.round(r.ran)} ms, ` +
        `bytes readable ${r.bytesReadable}, ran ${r.bytesRan}, total ${r.bytesTotal} (${r.requests} req)` +
        (r.errors.length ? ` ERRORS ${r.errors.join(' | ')}` : ''));
      (all[site.label][profile] = all[site.label][profile] || []).push(r);
    }
  }
}
await browser.close();

for (const site of SITES) {
  const summary = {};
  for (const [profile, runs] of Object.entries(all[site.label])) {
    summary[profile] = {};
    for (const k of ['fcp', 'readable', 'shellReady', 'kernelReady', 'ran', 'bytesReadable', 'bytesRan', 'bytesTotal', 'requests']) {
      summary[profile][k] = median(runs.map(r => r[k]));
    }
    summary[profile].byCat = runs[0].byCat;
  }
  writeFileSync(`${OUT}/${site.label}.json`, JSON.stringify({ label: site.label, base: site.base, runs: all[site.label], summary }, null, 1));
  console.log(site.label, JSON.stringify(summary, null, 1));
}
