// Headless test for offline mode (html/sw.js, html/offline.js, the progress
// dialog's "Offline lernen"): off until asked for, a complete copy, the
// course from the copy when the server is gone (lessons, cells, cached gems,
// three.js, the right message for what needs the internet), a deploy seen at
// once online and in the copy after the next check, and turning it off.
//
// The page goes through a small proxy in front of BASE, which the test can
// take down (every connection dropped, as with no network) and use to
// "deploy" a changed index.html. With the optional server (BASE on port
// 8012) it also opens a permalink offline.
//
//   BASE=http://127.0.0.1:8011/ node offline_test.mjs     (BROWSER=firefox|webkit)
import * as playwright from '/usr/local/lib/node_modules/playwright/index.mjs';
import http from 'node:http';

const UPSTREAM = new URL(process.env.BASE || 'http://127.0.0.1:8011/');
const BROWSER = process.env.BROWSER || 'chromium';

let failures = 0;
const check = (name, cond) => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`);
  if (!cond) failures++;
};

// ---------- the proxy ----------
let down = false;
const overrides = new Map();   // path -> { body, etag }
const requests = [];           // "GET /main.rb", ...
const sockets = new Set();
const proxy = http.createServer((req, res) => {
  if (down) { req.socket.destroy(); return; }
  requests.push(`${req.method} ${req.url}`);
  const override = overrides.get(req.url.split('?')[0]);
  if (override && (req.method === 'GET' || req.method === 'HEAD')) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'ETag': override.etag, 'Cache-Control': 'no-cache' });
    res.end(req.method === 'HEAD' ? undefined : override.body);
    return;
  }
  const upstream = http.request({
    host: UPSTREAM.hostname, port: UPSTREAM.port, path: req.url, method: req.method,
    headers: { ...req.headers, host: UPSTREAM.host }
  }, (answer) => { res.writeHead(answer.statusCode, answer.headers); answer.pipe(res); });
  upstream.on('error', () => req.socket.destroy());
  req.pipe(upstream);
});
proxy.on('connection', (socket) => { sockets.add(socket); socket.on('close', () => sockets.delete(socket)); });
await new Promise((resolve) => proxy.listen(0, '127.0.0.1', resolve));
const SITE = `http://127.0.0.1:${proxy.address().port}/`;
const goDown = () => { down = true; for (const socket of sockets) socket.destroy(); };
const comeBack = () => { down = false; };

// ---------- the page ----------
const browser = await playwright[BROWSER].launch();
const ctx = await browser.newContext({ locale: 'de-DE' });

async function open(path = '') {
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('[pageerror]', e.message));
  page.on('dialog', (d) => d.accept());
  await page.goto(SITE + path, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  return page;
}
const offlineState = (page) => page.evaluate(() => window.ChunkyOffline.state());
const offlineText = (page) => page.textContent('#progressDialog .pd-offline');
const waitForState = (page, state, timeout = 180000) =>
  page.waitForFunction((s) => window.ChunkyOffline.state() === s && !window.ChunkyOffline.updating(), state, { timeout });
const registrations = (page) => page.evaluate(async () => (await navigator.serviceWorker.getRegistrations()).length);
// the copy's index (sw.js): which version of each file it holds
const copyIndex = (page) => page.evaluate(async () => {
  const response = await caches.match(new URL('__offline__/index.json', document.baseURI).href);
  return response ? response.json() : null;
});
// runs Ruby in the first demo cell, returns its output
async function run(page, code) {
  const idx = await page.getAttribute('.cell:not(.exercise) .run-cell', 'data-idx');
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [idx, code]);
  await page.click(`.run-cell[data-idx="${idx}"]`, { noWaitAfter: true });
  await page.waitForFunction((i) => {
    const out = document.querySelector(`#cell-out-${i}`);
    return out && out.textContent.trim() !== '' && !document.querySelector('.cell.running');
  }, idx, { timeout: 60000 });
  return page.textContent(`#cell-out-${idx}`);
}

// ---------- 1. off until asked for ----------
const a = await open();
check('no service worker for a visitor who did not ask', (await registrations(a)) === 0);
check('offline mode reports "off"', (await offlineState(a)) === 'off');
await a.click('#progressBtn');
check('the dialog offers it', (await offlineText(a)).includes('Auf diesem Gerät speichern'));

// ---------- 2. saving the copy ----------
const started = Date.now();
await a.click('#progressDialog >> text=Auf diesem Gerät speichern');
await a.waitForSelector('#progressDialog .pd-offline .pd-busy', { timeout: 10000 });
check('it says it is saving', (await offlineText(a)).includes('Wird gespeichert'));
await waitForState(a, 'ready');
console.log(`  (copy saved in ${((Date.now() - started) / 1000).toFixed(1)} s)`);
check('the dialog says it is saved', (await offlineText(a)).includes('✓ Auf diesem Gerät gespeichert'));
check('…with its size on the delete button', /Kopie löschen \(\d+ MB\)/.test(await offlineText(a)));
const list = (await (await fetch(SITE + 'offline-files.txt')).text()).split('\n').filter((l) => l.trim() && !l.startsWith('#'));
let index = await copyIndex(a);
check(`the copy holds every listed file and the page (${list.length + 1})`, index && index.count === list.length + 1);
check('…the 33 MB Ruby among them', index && index.files['ruby+stdlib.wasm'] && index.files['ruby+stdlib.wasm'].size > 30e6);
check('…and Python, ticked by default', index && Boolean(index.files['assets/pyodide/pyodide.asm.wasm']) &&
  (await a.isChecked('#progressDialog .pd-check input')));
await a.keyboard.press('Escape');
await a.close();

// ---------- 3. the server is gone ----------
goDown();
const b = await open('#variablen');
check('the course opens offline', (await b.textContent('#lessonBody')).includes('Variablen'));
check('…and knows it came from the copy', await b.evaluate(() => window.ChunkyOffline.fromCopy()));
check('a cell runs offline', (await run(b, '"Speck" * 2')).includes('"SpeckSpeck"'));
check('a cached gem installs offline',
  (await run(b, 'install_gem "chunky_png"\nrequire "chunky_png"\nChunkyPNG::Color::WHITE')).includes('4294967295'));
check('a gem that is not in the copy says why',
  (await run(b, 'install_gem "rainbow"')).includes('nicht in der Offline-Kopie'));
check('Net::HTTP says it is offline',
  (await run(b, 'require "net/http"\nNet::HTTP.get(URI("https://www.ruby-lang.org/"))')).includes('offline'));
// the module files themselves (ensureThree also needs the import map, which
// Firefox ignores after a modulepreload - a separate matter)
check('three.js loads from the copy', await b.evaluate(() => import('./assets/three/three.module.min.js').then((m) => Boolean(m.Scene), () => false)));
const sql = await open('#sequel');
check('Sequel runs offline (sql.js, the sqlite3 stand-in and the gem from the copy)',
  (await run(sql, 'install_gem "sequel"\nrequire "sequel"\nDB = Sequel.sqlite\nDB.get(Sequel.lit("6 * 7"))')).includes('=> 42'));
await sql.close();
await b.click('#lessonNav a[data-id="methoden"]');
await b.waitForFunction(() => document.querySelector('#lessonBody').textContent.includes('Methoden'));
check('another lesson opens offline', true);
// Rumale: its gems from the cache, Numo's stand-in and digits.csv read
// synchronously - from memory on a page from the copy (offline.js)
await b.click('#lessonNav a[data-id="rumale"]');
await b.waitForFunction(() => document.querySelector('#lessonBody').textContent.includes('Rumale'));
check('Rumale, Numo and digits.csv offline',
  (await run(b, 'install_gem "rumale-nearest_neighbors"\nrequire "rumale/nearest_neighbors"\n[File.read("digits.csv").lines.size, Numo::DFloat[[1, 2]].sum]')).includes('=> [1797, 3.0]'));
check('…and the letter', await b.evaluate(() => typeof window.chunkyLetter === 'function'));
await b.click('#progressBtn');
check('the dialog says the page is the saved copy', (await offlineText(b)).includes('Du bist gerade offline'));
await b.close();

// ---------- 4. a deploy ----------
comeBack();
const html = await (await fetch(SITE)).text();
const marked = html.replace('<meta charset="UTF-8">', '<meta charset="UTF-8">\n    <meta name="deploy" content="2">');
overrides.set('/', { body: marked, etag: '"deploy-2"' });
overrides.set('/index.html', { body: marked, etag: '"deploy-2"' });
const c = await open();
check('online, a deploy shows at once (not the copy)',
  (await c.evaluate(() => document.querySelector('meta[name=deploy]')?.content)) === '2' &&
  !(await c.evaluate(() => window.ChunkyOffline.fromCopy())));
requests.length = 0;
await c.evaluate(() => navigator.serviceWorker.controller.postMessage({ type: 'refresh', force: true }));
// done when the copy's index names the deployed version (polled from here:
// waitForFunction does not wait for an async predicate)
for (let tries = 0; tries < 240; tries++) {
  const now = await copyIndex(c);
  if (now && now.files['index.html'].v === 'e"deploy-2"') break;
  await c.waitForTimeout(250);
}
await waitForState(c, 'ready', 60000);
// (the browser itself may look for a new sw.js meanwhile)
const gets = requests.filter((r) => r.startsWith('GET ') && !r.includes('offline-files.txt') && r !== 'GET /sw.js');
check(`the check fetched only what changed (${gets.join(', ')})`, gets.length >= 1 && gets.length <= 2 && gets.every((r) => r === 'GET /' || r === 'GET /index.html'));
index = await copyIndex(c);
check('the copy has the new version', index.files['index.html'].v === 'e"deploy-2"' && index.files[''].v === 'e"deploy-2"');
await c.close();
goDown();
const d = await open();
check('offline, the copy now has the deploy',
  (await d.evaluate(() => document.querySelector('meta[name=deploy]')?.content)) === '2');
await d.close();
comeBack();
overrides.clear();

// ---------- 5. permalinks, when the server makes them ----------
const permalinks = (await (await fetch(SITE)).text()).includes('name="chunky-permalinks"');
if (permalinks) {
  const e = await open('de/hallo');
  await e.evaluate(() => navigator.serviceWorker.controller.postMessage({ type: 'refresh', force: true }));
  await waitForState(e, 'ready', 60000);
  await e.close();
  goDown();
  const f = await open('de/variablen');
  check('offline, a permalink opens its lesson', (await f.textContent('#lessonBody')).includes('Variablen'));
  await f.close();
  comeBack();
} else {
  console.log('  (no permalinks here: BASE is the static site)');
}

// ---------- 5b. Python left out (the checkbox) ----------
const py = await open();
await py.click('#progressBtn');
await py.uncheck('#progressDialog .pd-check input');
const pythonFiles = list.filter((path) => path.startsWith('assets/pyodide/'));
for (let tries = 0; tries < 240; tries++) {
  const now = await copyIndex(py);
  if (now && !now.files['assets/pyodide/pyodide.asm.wasm']) break;
  await py.waitForTimeout(250);
}
await waitForState(py, 'ready', 60000);
index = await copyIndex(py);
check(`unticked, the copy drops Python (${pythonFiles.length} files)`,
  index.count === list.length + 1 - pythonFiles.length && !Object.keys(index.files).some((path) => path.startsWith('assets/pyodide/')));
check('…and the files are gone from the cache', !(await py.evaluate(async () =>
  (await (await caches.open('chunky-offline-1')).keys()).some((r) => r.url.includes('pyodide')))));
check('…the box stays unticked', !(await py.isChecked('#progressDialog .pd-check input')));
await py.close();
goDown();
const pyOff = await open('#pycall');
check('offline without Python, a Python lesson says why',
  (await run(pyOff, 'require "pycall"\nPyCall.import_module("pandas")')).includes('Python ist nicht in deiner Offline-Kopie'));
await pyOff.close();
comeBack();

// ---------- 6. turning it off ----------
const g = await open();
await g.click('#progressBtn');
await g.click('#progressDialog >> text=Kopie löschen');
await g.waitForFunction(() => window.ChunkyOffline.state() === 'off');
await g.waitForTimeout(500);
check('turned off: no service worker left', (await registrations(g)) === 0);
check('…and no copy', !(await g.evaluate(async () => (await caches.keys()).some((k) => k.startsWith('chunky-offline-')))));
check('…the dialog offers it again', (await offlineText(g)).includes('Auf diesem Gerät speichern'));
await g.close();
goDown();
const h = await ctx.newPage();
const failed = await h.goto(SITE, { timeout: 15000 }).then(() => false, () => true);
check('turned off, offline is offline again', failed);
comeBack();

await browser.close();
proxy.close();
console.log(failures === 0 ? 'ALL OFFLINE TESTS OK' : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
