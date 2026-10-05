// Playwright probe for the matplotlib experiment, against serve.rb:
//
//   PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/<hash>/node_modules/playwright \
//     BASE=http://127.0.0.1:18101/ node experiments/01-matplotlib-charts/browser_probe.mjs
//
// Opens the sketched lesson, runs every cell, times Python's load and the
// first matplotlib import, sums what /assets/pyodide/ transferred, checks
// the exercise (starter fails, solution passes), plt.savefig's download, a
// Japanese title, and takes screenshots into shots/.
import path from 'node:path';
import fs from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(pathToFileURL(path.join(process.env.PLAYWRIGHT_DIR, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18101/';
const shots = path.join(here, 'shots');
fs.mkdirSync(shots, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ locale: 'de-DE', viewport: { width: 1280, height: 900 } });
page.on('console', m => { if (m.type() === 'error') console.log('[console.error]', m.text()); });
page.on('pageerror', e => console.log('[pageerror]', e.message));

// what Python's files cost on the wire
const pyodideBytes = {};
page.on('response', async r => {
  const url = r.url();
  if (!url.includes('/assets/pyodide/')) return;
  try {
    const len = Number(r.headers()['content-length'] || (await r.body()).length);
    pyodideBytes[url.split('/').pop()] = len;
  } catch { /* redirected or aborted */ }
});

let failures = 0;
const check = (name, cond, extra = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${extra ? ' - ' + extra : ''}`);
  if (!cond) failures++;
};
const t0 = Date.now();
const secs = since => ((Date.now() - since) / 1000).toFixed(1) + ' s';

const runCell = async (idx, timeout = 60000) => {
  const start = Date.now();
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    document.getElementById('cell-out-' + i).style.display !== 'none', idx, { timeout }).catch(() => {});
  return { text: (await page.textContent(`#cell-out-${idx}`)) || '', ms: Date.now() - start };
};
const svgsIn = idx => page.$$eval(`#cell-out-${idx} img.cell-image`, imgs => imgs.map(i => ({
  svg: i.src.startsWith('data:image/svg+xml'), bytes: Math.round(i.src.length * 3 / 4), w: i.naturalWidth, h: i.naturalHeight, shown: i.getBoundingClientRect().width
})));

await page.goto(BASE + '#matplotlib', { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
await page.waitForFunction(() => document.querySelector('#lessonBody h2')?.textContent.includes('Zahlen als Bild'), null, { timeout: 60000 });
check('the sketched lesson opens', true, (await page.textContent('#lessonTitle').catch(() => '')) || '');
check('opening it starts loading Python', await page.evaluate(() => !!(window.chunkyPython.loading || window.chunkyPython.ready)));
await page.waitForFunction(() => window.chunkyPython.ready && window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 180000 });
const pythonReady = secs(t0);
check('Python + matplotlib loaded', await page.evaluate(() => !!window.chunkyPython.packages.matplotlib), `navigation -> Python, its packages and the kernel ready: ${pythonReady}`);

// cell 1: line chart; the first import of matplotlib.pyplot (font cache)
const line = await runCell(1, 120000);
let imgs = await svgsIn(1);
check('plt.show() puts an SVG under the cell', imgs.length === 1 && imgs[0].svg, `${line.ms} ms (first import), ${JSON.stringify(imgs)}`);
check('no "=> nil" and no error', !line.text.includes('=>') && !line.text.includes('Error'), JSON.stringify(line.text.slice(0, 200)));
await page.locator('#cell-out-1').screenshot({ path: path.join(shots, '1-line.png') });

const again = await runCell(1);
check('a second run draws again, once', (await svgsIn(1)).length === 1, `${again.ms} ms warm`);

const bar = await runCell(3);
imgs = await svgsIn(3);
check('bar chart', imgs.length === 1, `${bar.ms} ms, ${imgs[0]?.bytes} bytes as data URL`);
await page.locator('#cell-out-3').screenshot({ path: path.join(shots, '2-bar.png') });

const curves = await runCell(5);
check('numpy curves + legend', (await svgsIn(5)).length === 1, `${curves.ms} ms`);
await page.locator('#cell-out-5').screenshot({ path: path.join(shots, '3-curves.png') });

const figure = await runCell(7);
imgs = await svgsIn(7);
const links = await page.$$eval('#cell-out-7 a.cell-download', as => as.map(a => a.textContent));
check('subplots side by side', imgs.length === 1 && imgs[0].w > imgs[0].h * 2, JSON.stringify(imgs));
check('plt.savefig("wetter.png") is offered as a download', links.some(t => t.includes('wetter.png')), JSON.stringify(links));
check('no warnings in the cell (PNG through Agg)', !figure.text.includes('Warning'), JSON.stringify(figure.text.slice(0, 200)));
const png = await page.$eval('#cell-out-7 a.cell-download', a => fetch(a.href).then(r => r.arrayBuffer()).then(b => {
  const u = new Uint8Array(b); return { size: u.length, magic: String.fromCharCode(u[1], u[2], u[3]) };
})).catch(e => ({ error: String(e) }));
check('... and the file is a PNG', png.magic === 'PNG', JSON.stringify(png));
await page.locator('#cell-out-7').screenshot({ path: path.join(shots, '4-subplots-savefig.png') });

// the exercise: the starter fails, a solution passes
const exIdx = await page.getAttribute('.cell.exercise .run-cell', 'data-idx');
await runCell(exIdx);
check('starter fails', (await page.getAttribute('#chunkyChat', 'class')).includes('fail'));
await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exIdx,
  'require "pycall"\nplt = PyCall.import_module("matplotlib.pyplot")\n\ntage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]\nmaeuse = [3, 5, 2, 6, 4, 7, 1]\nplt.bar(tage, maeuse, color: "sienna")\nplt.title("Fuchs-Jagd")\nplt.show()\n']);
await runCell(exIdx);
await page.waitForTimeout(500);
check('solution passes', (await page.getAttribute('#chunkyChat', 'class')).includes('pass'));
await page.locator(`.cell.exercise`).screenshot({ path: path.join(shots, '5-exercise.png') });

// more of the bridge, in the exercise cell
const probe = async (code, name) => {
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exIdx, code]);
  const out = await runCell(exIdx);
  return { ...out, imgs: await svgsIn(exIdx) };
};
let p = await probe('plt.plot([1, 2, 3], [3, 1, 2])\nplt.title("キツネの狩り – 日本語")\nplt.xlabel("曜日")\nplt.show()');
check('a Japanese title (text stays text in the SVG, the browser\'s fonts draw it)', p.imgs.length === 1 && !p.text.includes('Warning'), JSON.stringify(p.text.slice(0, 120)));
await page.locator(`#cell-out-${exIdx}`).screenshot({ path: path.join(shots, '6-japanese.png') });

p = await probe('fig = plt.figure(figsize: [4, 2])\nfig.add_subplot(1, 1, 1).plot([1, 2, 3])\nshow_plot fig\nplt.get_fignums.to_a');
check('show_plot(fig) shows one figure and closes it', p.imgs.length === 1 && p.text.includes('=> []'), p.text.slice(0, 120));

p = await probe('plt.plot([1, 2])\nplt.plot([2, 1])\nplt.figure()\nplt.plot([5, 5])\nplt.show()');
check('two open figures: plt.show() draws both', p.imgs.length === 2);

p = await probe('plt.plot([1, 2])\nplt.savefig("ohne_endung")\nplt.close()\nFile.read("ohne_endung.png")[1, 3]');
check('savefig without an extension: .png, and Ruby can read the file', p.text.includes('"PNG"'), p.text.slice(0, 160));

p = await probe('plt.plot([1, 2])\nplt.savefig("kurve.svg")\nplt.close()\nFile.read("kurve.svg").include?("<svg")');
check('savefig as SVG', p.text.includes('=> true'), p.text.slice(0, 160));

p = await probe('plt.plot(nil, [1])');
check('a matplotlib error is a PyCall::PyError', p.text.includes('PyCall::PyError'), p.text.slice(0, 160));

// timing of a bigger chart: 10 000 points
p = await probe('np = PyCall.import_module("numpy")\nrng = np.random.default_rng(1)\nplt.hist(rng.normal(size: 10000), bins: 40)\nplt.show()');
check('a histogram of 10 000 values', p.imgs.length === 1, `${p.ms} ms, ${p.imgs[0]?.bytes} bytes`);
p = await probe('np = PyCall.import_module("numpy")\nrng = np.random.default_rng(1)\nplt.scatter(rng.normal(size: 2000), rng.normal(size: 2000), s: 4)\nplt.show()');
check('a scatter of 2000 points (SVG grows with the marks)', p.imgs.length === 1, `${p.ms} ms, ${p.imgs[0]?.bytes} bytes`);

// whole lesson as a picture, English and Japanese
await page.screenshot({ path: path.join(shots, '7-page-de.png'), fullPage: false });
for (const lang of ['en', 'ja']) {
  await page.goto(BASE + `?lang=${lang}#matplotlib`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#lessonBody h2', { timeout: 60000 });
  await page.waitForFunction(() => window.chunkyPython?.ready && window.ChunkyBridge?.ready, null, { timeout: 180000 });
  const out = await runCell(1, 120000);
  check(`${lang}: the first cell draws`, (await svgsIn(1)).length === 1, `${out.ms} ms`);
  await page.screenshot({ path: path.join(shots, `8-page-${lang}.png`) });
}

const total = Object.values(pyodideBytes).reduce((a, b) => a + b, 0);
const mpl = ['matplotlib', 'contourpy', 'cycler', 'fonttools', 'kiwisolver', 'packaging', 'pillow', 'pyparsing'];
const mplBytes = Object.entries(pyodideBytes).filter(([f]) => mpl.some(m => f.startsWith(m + '-'))).reduce((a, [, b]) => a + b, 0);
console.log('pyodide transfer (first visit):');
for (const [f, b] of Object.entries(pyodideBytes)) console.log(`  ${f.padEnd(70)} ${(b / 1024).toFixed(0).padStart(7)} KB`);
console.log(`  total ${(total / 1048576).toFixed(2)} MB, of which the matplotlib wheels ${(mplBytes / 1048576).toFixed(2)} MB`);
console.log(`whole probe ${secs(t0)}; ${failures} failure(s)`);
await browser.close();
process.exit(failures ? 1 : 0);
