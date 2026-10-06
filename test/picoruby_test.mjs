// Headless test for the PicoRuby lesson (lesson 41, "engine": "picoruby";
// docs/HANDOVER.md §6m): its cells and its IRB run on PicoRuby.wasm in a
// Web Worker (picoruby_worker.js), not on CRuby - the demos' output, the
// IRB with _ and a def over several lines, the exercise's check on what
// PicoRuby answered, CRuby's explanation of a syntax error, a line mark for
// a runtime error, live runs, an endless loop stopped (the worker ended and
// started anew, the variables gone) while the page stays responsive, a new
// page starting from scratch - and no worker at all for other lessons.
// About half a minute.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };
const errors = [];

async function open(ctx, hash) {
  const page = await ctx.newPage();
  page.on('pageerror', e => { errors.push(e.message); console.log('[pageerror]', e.message); });
  page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); console.log('  [console.error]', m.text().slice(0, 160)); } });
  await page.goto(BASE + hash, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  return page;
}
const out = (page, idx) => page.evaluate(i => {
  const el = document.getElementById('cell-out-' + i);
  return el && el.style.display !== 'none' ? el.textContent : '';
}, idx);
// the code cells in order: their data-idx
const codeCells = page => page.$$eval('.cell .run-cell', buttons => buttons.map(b => Number(b.getAttribute('data-idx'))));
const code = (page, idx) => page.evaluate(i => window.cellEditors[i].getValue(), idx);
// ▶, then wait until the shell has settled the cell
async function run(page, idx, text) {
  if (text !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, text]);
  await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
  return out(page, idx);
}
// an edit as the learner makes it (setValue is the page's own)
const edit = (page, idx, text) => page.evaluate(([i, t]) => {
  const cm = window.cellEditors[i];
  cm.replaceRange(t, { line: 0, ch: 0 }, { line: cm.lineCount(), ch: 0 }, '+input');
}, [idx, text]);
const responsive = async page => {
  const started = Date.now();
  await page.evaluate(() => 1 + 1);
  return Date.now() - started < 1000;
};

const ctx = await browser.newContext({ locale: 'de-DE' });

// ---------- another lesson: no second PicoRuby ----------
{
  const page = await open(ctx, '#hallo');
  check('a CRuby lesson starts no PicoRuby worker', await page.evaluate(() => window.chunkyPicoRuby.worker === null && !window.chunkyPicoRuby.loading));
  await page.close();
}

const page = await open(ctx, '#picoruby');
await page.waitForFunction(() => window.chunkyPicoRuby.ready, null, { timeout: 60000 });
const cells = await codeCells(page);
const cellWith = async text => {
  for (const idx of cells) if ((await code(page, idx)).includes(text)) return idx;
  return null;
};

// ---------- the demos run on PicoRuby ----------
const who = await run(page, await cellWith('PICORUBY_VERSION'));
check('the cells run on PicoRuby: mruby, wasm32-Emscripten', who.includes('"mruby"') && who.includes('wasm32-Emscripten'));
check('...a version from the vendored runtime', who.includes(await page.evaluate(() => window.chunkyPicoRuby.version.split('PicoRuby ')[1])));
const missing = await run(page, await cellWith('respond_to?'));
check('PicoRuby has no Array#sum, but inject', missing.includes('[:sum, false]') && missing.includes('[:inject, true]'));
const tasks = await run(page, await cellWith('Task.new'));
check('two Tasks take turns', /Sensor: 20 °C\s*LED an\s*Sensor: 21 °C\s*LED aus/.test(tasks));
check('...and a nil after output is not shown', !tasks.includes('=> nil'));
const overflow = await run(page, await cellWith('2 ** 62'));
check('64-bit integers: RangeError', overflow.includes('RangeError: integer overflow'));
const sqlite = await run(page, await cellWith('SQLite3'));
check('JSON and SQLite3 in PicoRuby', sqlite.includes('{"name":"Chunky"') && sqlite.includes('=> [["Speck"]]'));

// ---------- its IRB ----------
const irbCell = await cellWith('show_irb');
await run(page, irbCell);
check('the IRB has a prompt of its own', (await page.textContent('.irb-term .irb-prompt')) === 'irb>');
const type = async line => {
  await page.fill('.irb-term .irb-input', line);
  await page.press('.irb-term .irb-input', 'Enter');
  await page.waitForTimeout(250);
};
await type('x = 6 * 7');
await type('_ + 1');
await type('def doppelt(n)');
check('an unfinished def waits for more', (await page.textContent('.irb-term .irb-prompt')) === 'irb*');
await type('  n * 2');
await type('end');
await type('doppelt(x)');
await type('[1, 2].sum');
await type('1 +* 2');
const history = await page.textContent('.irb-term .irb-history');
check('IRB: _ is the last answer', history.includes('=> 43'));
check('IRB: a def over three lines', history.includes('=> :doppelt') && history.includes('=> 84'));
check('IRB: PicoRuby\'s own error', history.includes("NoMethodError: undefined method 'sum' for Array"));
check('IRB: a syntax error from Prism', history.includes('SyntaxError'));

// ---------- the exercise ----------
const ex = Number(await page.getAttribute('.cell.exercise .run-cell', 'data-idx'));
const starter = await code(page, ex);
await run(page, ex);
check('the starter does not pass', !(await page.getAttribute('.cell.exercise', 'class')).includes('celebrate'));
const syntax = await run(page, ex, 'def woerter_zaehlen(woerter)\n  anzahl = {\nend');
check('a syntax error is explained (CRuby\'s Prism, before PicoRuby)', syntax.includes('Zeile 2') || syntax.includes('2 |'));
const runtime = await run(page, ex, 'woerter = %w[a b]\nwoerter.tally');
check('a runtime error comes from PicoRuby', runtime.includes("undefined method 'tally' for Array"));
check('...and marks its line', await page.evaluate(i => window.cellEditors[i].getAllMarks().some(m => m.find().from.line === 1), ex));
await run(page, ex, 'def woerter_zaehlen(woerter)\n  anzahl = Hash.new(0)\n  woerter.each { |w| anzahl[w] += 1 }\n  anzahl\nend\n\nwoerter_zaehlen(%w[chunky bacon chunky fuchs chunky])');
check('a solution passes the check', (await page.getAttribute('.cell.exercise', 'class')).includes('celebrate'));
check('...and the lesson is done', (await page.textContent('#chunkyChat')).includes('Lektion 41 von'));

// ---------- live runs ----------
await edit(page, ex, 'y = 20\ny * 2 + 2');
await page.waitForFunction(i => (document.getElementById('cell-out-' + i).textContent || '').includes('=> 42'), ex, { timeout: 10000 });
check('a live run on PicoRuby', await page.evaluate(i => document.getElementById('cell-out-' + i).classList.contains('is-rehearsal'), ex));
await edit(page, ex, 'z = 0\nwhile 1 > 0\n  z += 1\nend');
await page.waitForFunction(i => (document.getElementById('cell-out-' + i).textContent || '').includes('neu gestartet'), ex, { timeout: 10000 });
check('an endless live run is stopped after a second, PicoRuby started anew', true);
check('...while the page stayed responsive', await responsive(page));

// ---------- ▶ on an endless loop: ten seconds ----------
await run(page, ex, 'x = 1');
const started = Date.now();
const stopped = await run(page, ex, 'loop { x += 1 }');
check('▶ on an endless loop stops after 10 s', stopped.includes('Nach 10 Sekunden') && Date.now() - started < 14000);
const gone = await run(page, ex, 'x');
check('...and the variables are gone', gone.includes('NoMethodError') || gone.includes('undefined'));

// ---------- a new page starts from scratch ----------
await run(page, ex, 'merk = 5');
await page.evaluate(() => { location.hash = '#rubies'; });
await page.waitForFunction(() => document.title.startsWith('40.'), null, { timeout: 10000 });
await page.evaluate(() => { location.hash = '#picoruby'; });
await page.waitForFunction(() => document.title.startsWith('41.'), null, { timeout: 10000 });
const fresh = await run(page, ex, 'merk');
check('after another lesson the variables are gone', !fresh.includes('=> 5'));
await page.evaluate(([i, t]) => window.setCellCode(i, t), [ex, starter]);

check('no page errors', errors.length === 0);
await browser.close();
console.log(failures ? `${failures} FAILED` : 'ALL PICORUBY CHECKS PASSED');
process.exit(failures ? 1 : 0);
