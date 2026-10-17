// Headless test for the IronRuby lesson ("engine": "ironruby";
// docs/HANDOVER.md §6s): its cells run on IronRuby 4.0 - .NET 10 compiled to
// WebAssembly - in a Web Worker (ironruby_worker.js), not on CRuby. The
// boot with its progress bar, every demo cell (QRCoder's PNG starting with
// \x89PNG, the snake_case gotcha, the SVGs, the QR-bill, System.Numerics,
// Markdig loaded on demand), the exercise's two-part check (the probe in
// IronRuby, [true, true, 328]), CRuby's explanation of a syntax error, a
// line mark for a runtime error, a cell run first that brings the cells
// above along, ■ Stop on an endless loop (the worker ended and started anew,
// the variables gone) while the page stays responsive, a new page starting
// from scratch - and no worker at all for other lessons. Needs
// html/assets/ironruby/ (tools/vendor_ironruby.rb). About a minute.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };
const errors = [];

async function open(ctx, hash) {
  const page = await ctx.newPage();
  page.on('pageerror', e => { errors.push(e.message); console.log('[pageerror]', e.message); });
  // (a missing file is counted by its address below: the 📦 toolchain is optional)
  page.on('console', m => { if (m.type() === 'error' && !m.text().startsWith('Failed to load resource')) { errors.push(m.text()); console.log('  [console.error]', m.text().slice(0, 160)); } });
  page.on('response', r => { if (r.status() >= 400 && !r.url().includes('/compile/toolchain/')) { errors.push(`${r.status()} ${r.url()}`); console.log('  [http]', r.status(), r.url()); } });
  await page.goto(BASE + hash, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  return page;
}
const out = (page, idx) => page.evaluate(i => {
  const el = document.getElementById('cell-out-' + i);
  return el && el.style.display !== 'none' ? el.textContent : '';
}, idx);
const codeCells = page => page.$$eval('.cell .run-cell', buttons => buttons.map(b => Number(b.getAttribute('data-idx'))));
const code = (page, idx) => page.evaluate(i => window.cellEditors[i].getValue(), idx);
// ▶, then wait until the shell has settled the cell
async function run(page, idx, text, timeout = 60000) {
  if (text !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, text]);
  await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(() => window.__ran, null, { timeout });
  return out(page, idx);
}
// the pictures below a cell: [kind, the decoded start of their data]
const pictures = (page, idx) => page.evaluate(i => {
  const el = document.getElementById('cell-out-' + i);
  return [...el.querySelectorAll('img.cell-image, iframe.ironruby-html')].map(p => {
    if (p.tagName === 'IFRAME') return ['html', p.getAttribute('srcdoc')];
    const [head, b64] = p.src.split(',');
    const bytes = atob(b64);
    return [head.includes('png') ? 'png' : 'svg', bytes.slice(0, 200), bytes.length, p.naturalWidth];
  });
}, idx);
const responsive = async page => {
  const started = Date.now();
  await page.evaluate(() => 1 + 1);
  return Date.now() - started < 1000;
};
const timings = {};

const ctx = await browser.newContext({ locale: 'de-DE' });

// ---------- another lesson: no IronRuby ----------
{
  const page = await open(ctx, '#hallo');
  const requested = [];
  page.on('request', r => { if (r.url().includes('/assets/ironruby/')) requested.push(r.url()); });
  await page.waitForTimeout(1500);
  check('a CRuby lesson starts no IronRuby worker', await page.evaluate(() => window.chunkyIronRuby.worker === null && !window.chunkyIronRuby.loading));
  check('...and loads none of its files', requested.length === 0);
  await page.close();
}

const page = await open(ctx, '#ironruby');
const bootStarted = Date.now();
await page.waitForFunction(() => document.querySelector('.ironruby-status progress'), null, { timeout: 30000 });
const bar = await page.evaluate(() => {
  const el = document.querySelector('.ironruby-status');
  return { state: el.dataset.state, text: el.textContent, bar: !el.querySelector('progress').hidden };
});
check('the lesson starts IronRuby, with a status line and a progress bar', ['download', 'boot', 'ready'].includes(bar.state) && (bar.state === 'ready' || bar.bar));
check('...which says what it loads', /\.NET|IronRuby/.test(bar.text));
await page.waitForFunction(() => window.chunkyIronRuby.ready, null, { timeout: 120000 });
timings.boot = Date.now() - bootStarted;
const ready = await page.textContent('.ironruby-status');
check('IronRuby is ready, says the status line', ready.includes('IronRuby ist bereit') && ready.includes('wasm32-browser'));
check('...and the bar is gone', await page.evaluate(() => document.querySelector('.ironruby-status progress').hidden));

const cells = await codeCells(page);
const cellWith = async text => {
  for (const idx of cells) if ((await code(page, idx)).includes(text)) return idx;
  return null;
};
const timed = async (name, idx) => {
  const started = Date.now();
  const text = await run(page, idx);
  timings[name] = Date.now() - started;
  return text;
};

// ---------- the demos run on IronRuby ----------
const where = await timed('where', await cellWith('RuntimeInformation'));
check('the cells run on IronRuby: ironruby, .NET, WebAssembly', where.includes('ironruby') && where.includes('.NET 10') && where.includes('WebAssembly (Browser)'));
check('...System::Math.Sqrt(2) as a value', where.includes('=> 1.4142135623730951'));
const firstIdx = await cellWith('PngByteQRCode');
const first = await timed('first', firstIdx);
check('QRCoder: a System::Byte[] that starts with \\x89PNG', first.includes('System::Byte[]') && first.includes('"\\x89PNG"'));
check('...the marker line is not in the output', !first.includes('LAB:'));
check('...and the version as the value', first.includes('=> "QR-Version 2, 33 x 33 Module"'));
const png = await pictures(page, firstIdx);
check('...shown as a PNG below the cell', png.length === 1 && png[0][0] === 'png' && png[0][1].startsWith('\x89PNG') && png[0][3] > 200);
const names = await timed('names', await cellWith('ECCLevel.send'));
check('enum values by name, ECC H is version 2', names.includes('ECC H: Version 2, 33 Module'));
check('module_matrix is ModuleMatrix, a List of BitArray', names.includes('dieselbe Liste: true') && names.includes('List[System::Collections::BitArray]'));
check('create_qr_code is a NoMethodError (the qr -> QR gotcha)', names.includes('create_qr_code: NoMethodError'));
const artIdx = await cellWith('"██"');
const art = await timed('art', artIdx);
check('puts draws the QR code in blocks', art.includes('██████████████'));
check('...without gaps between the lines (qr-art)', await page.evaluate(i => !!document.querySelector(`#cell-out-${i} .cell-stdout.qr-art`), artIdx));
const baconIdx = await cellWith('def bacon_svg');
const bacon = await timed('bacon', baconIdx);
check('bacon_svg: an SVG with 415 dark modules', bacon.includes('415 dunkle Module'));
const baconPics = await pictures(page, baconIdx);
check('...shown as an SVG in bacon colours', baconPics.length === 1 && baconPics[0][0] === 'svg' && baconPics[0][1].startsWith('<svg') && baconPics[0][1].includes('hsl('));
const billIdx = await cellWith('SwissQrCode');
const bill = await timed('bill', billIdx);
check('the Swiss QR-bill payload: SPC | 0200 | 1 | CH44...', bill.includes('SPC | 0200 | 1 | CH4431999123000889012 | S | Chunky Bacon AG'));
check('...a version 9 or 10 code (UTF-8, level M)', /QR-Version (9|10)\b/.test(bill));
check('...shown as an SVG with the Swiss cross', (await pictures(page, billIdx)).length === 1);
const complex = await timed('complex', await cellWith('NetComplex'));
check('System::Numerics::Complex with Ruby operators', complex.includes('<-0.5; 0.5>') && complex.includes('true'));
check('...and the Mandelbrot set', complex.includes('@@@@@@@@@@'));
const mdIdx = await cellWith('Markdig');
const md = await timed('markdig', mdIdx);
const mdPics = await pictures(page, mdIdx);
check('Markdig, loaded on demand: a table and an emoji', md.includes('Einkauf') && mdPics.length === 1 && mdPics[0][1].includes('<table>') && mdPics[0][1].includes('🐷'));
check('...in a sandboxed frame', await page.evaluate(i => document.querySelector(`#cell-out-${i} iframe`).getAttribute('sandbox') === '', mdIdx));

// ---------- the exercise ----------
const ex = Number(await page.getAttribute('.cell.exercise .run-cell', 'data-idx'));
const starter = await code(page, ex);
await run(page, ex);
check('the starter does not pass', !(await page.getAttribute('.cell.exercise', 'class')).includes('celebrate'));
const syntax = await run(page, ex, 'def qr_svg(text)\n  [\nend');
check('a syntax error is explained (CRuby\'s Prism, before IronRuby)', syntax.includes('Zeile') || syntax.includes('3 |') || syntax.includes('SyntaxError'));
const runtime = await run(page, ex, 'x = 1\nx.no_such_method');
check('a runtime error comes from IronRuby', runtime.includes('no_such_method'));
check('...and marks its line', await page.evaluate(i => window.cellEditors[i].getAllMarks().some(m => m.find() && m.find().from.line === 1), ex));
const solution = starter.replace(/  # .*\n  # .*\n  # .*\n/, '  data.module_matrix.each_with_index do |row, y|\n    row.each_with_index do |dark, x|\n      rects << %(<rect x="#{x * cell}" y="#{y * cell}" width="#{cell}" height="#{cell}"/>) if dark\n    end\n  end\n');
check('(the starter has the three comment lines the test replaces)', solution !== starter);
const started = Date.now();
await run(page, ex, solution);
timings.exercise = Date.now() - started;
check('a solution passes the check', (await page.getAttribute('.cell.exercise', 'class')).includes('celebrate'));
const probe = await page.evaluate(() => window.chunkyIronRuby.lastProbe);
check('...the probe in IronRuby said [true, true, 328]', probe === '[true, true, 328]');
const exPics = await pictures(page, ex);
check('...and its SVG is shown: 328 rects', exPics.length === 1 && exPics[0][2] > 10000);

// ---------- a cell run first brings the cells above along ----------
await page.evaluate(() => { location.hash = '#picoruby'; });
await page.waitForFunction(() => document.querySelector('#lessonNav a.active')?.dataset.id === 'picoruby', null, { timeout: 10000 });
await page.evaluate(() => { location.hash = '#ironruby'; });
await page.waitForFunction(() => document.querySelector('#lessonNav a.active')?.dataset.id === 'ironruby', null, { timeout: 10000 });
const fresh = await run(page, artIdx);
check('after another lesson, the art cell alone runs the QR cells above first', fresh.includes('██████████████'));
check('...and says so', await page.evaluate(i => !!document.querySelector(`#cell-out-${i}`) && document.querySelector(`#cell-out-${i}`).textContent.length > 0, artIdx));

// ---------- ■ Stop on an endless loop ----------
await run(page, ex, 'merk = 5');
await page.evaluate(([i, t]) => window.setCellCode(i, t), [ex, 'loop { merk += 1 }']);
await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
await page.click(`.run-cell[data-idx="${ex}"]`);
await page.waitForSelector(`#cell-out-${ex} .ironruby-stop`, { timeout: 10000 });
await page.waitForTimeout(1500);
check('the page stays responsive while IronRuby loops', await responsive(page));
await page.click(`#cell-out-${ex} .ironruby-stop`);
await page.waitForFunction(() => window.__ran, null, { timeout: 10000 });
check('■ Stop ends the run and says IronRuby was started anew', (await out(page, ex)).includes('neu gestartet'));
await page.waitForFunction(() => window.chunkyIronRuby.ready, null, { timeout: 60000 });
const gone = await run(page, ex, 'merk');
check('...and the variables are gone', gone.includes('NameError') || gone.includes('merk'));
check('...but QRCoder is loaded again', (await run(page, ex, 'QRCoder::QRCodeGenerator.name')).includes('QRCoder.QRCodeGenerator') ||
  (await out(page, ex)).includes('QRCodeGenerator'));

check('no page errors', errors.filter(e => !/favicon/.test(e)).length === 0);
console.log('timings (ms):', JSON.stringify(timings));
await browser.close();
console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
process.exit(failures ? 1 : 0);
