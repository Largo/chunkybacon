// Headless test for the JRuby lesson ("engine": "jruby"; docs/HANDOVER.md
// §6t): its cells run on JRuby 10.1 (TeaVM) in a Web Worker
// (jruby_worker.js), one cell on the page's CRuby ("on": "cruby"). Checks:
// no JRuby for other lessons, the status line, every demo's output (Java
// classes, the ZXing QR code, the USGS JSON, Jackson, Lesson::Quakes,
// threads, AtomicLong), the label naming the Ruby that ran a cell, the
// cells above running first in JRuby's binding, CRuby's explanation of a
// syntax error and the line mark of a JRuby error, the exercise (checked in
// CRuby, then the same code on CRuby agreeing), and a reset forgetting the
// variables; the Swing bonus on CheerpJ (only after its click; SKIP_SWING=1
// leaves it out - it needs cjrtnc.leaningtech.com and 30-60 s) and the German
// lesson. Needs html/assets/jruby/ and html/assets/jruby-swing/
// (tools/vendor_jruby.rb, tools/vendor_jruby_swing.rb). About two minutes.
//   BASE=http://127.0.0.1:18011/ node test/jruby_test.mjs
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
const codeCells = page => page.$$eval('.cell .run-cell', buttons => buttons.map(b => Number(b.getAttribute('data-idx'))));
const code = (page, idx) => page.evaluate(i => window.cellEditors[i].getValue(), idx);
async function run(page, idx, text) {
  if (text !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, text]);
  await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(() => window.__ran, null, { timeout: 90000 });
  return out(page, idx);
}

// ---------- another lesson: no JRuby ----------
{
  const ctx = await browser.newContext({ locale: 'de-DE' });
  const page = await open(ctx, '#hallo');
  const asked = [];
  page.on('request', r => { if (/assets\/jruby|jruby_worker/.test(r.url())) asked.push(r.url()); });
  await page.waitForTimeout(1500);
  check('a CRuby lesson starts no JRuby worker', await page.evaluate(() => window.chunkyJRuby.worker === null && !window.chunkyJRuby.loading));
  check('...and loads none of its files', asked.length === 0);
  await ctx.close();
}

const ctx = await browser.newContext({ locale: 'en-US' });
const page = await open(ctx, '#jruby');
check('the lesson shows a status line while JRuby loads', /JRuby/.test(await page.textContent('.jruby-status')));
await page.waitForFunction(() => window.chunkyJRuby.ready, null, { timeout: 90000 });
check('...and says when it is ready', /JRuby is ready: jruby 10\.1/.test(await page.textContent('.jruby-status')));
const cells = await codeCells(page);
const cellWith = async (text, not) => {
  for (const idx of cells) {
    const c = await code(page, idx);
    if (c.includes(text) && (!not || !c.includes(not))) return idx;
  }
  return null;
};

// ---------- the cells above run first, in JRuby's binding ----------
const top5 = await cellWith('max_by(5)');
const first = await run(page, top5);
check('a cell that needs the ones above runs them first (quakes from the parse cell)', first.includes('M 7.7'));
check('...JRuby ran it (the label)', first.includes('JRuby 10.1.2.0 in the browser (TeaVM)'));

// ---------- the demos ----------
const who = await run(page, cells[0]);
check('the cells run on JRuby 10.1, Ruby 4.0', who.includes('["jruby", "10.1.2.0", "4.0.0"]'));
const sort = await run(page, await cellWith('Collections.sort'));
check('a Ruby block as a Java Comparator', sort.includes('["apfel", "Bacon", "Speck"]'));
const qrIdx = await cellWith('QRCodeWriter');
const qr = await run(page, qrIdx);
check('ZXing prints a QR code in half blocks', (qr.match(/█/g) || []).length > 40 && qr.includes('▀') && qr.includes('▄'));
// drawn as an SVG of square modules (JRubyCells.blocks_svg), the text hidden
// next to it: as text, the font's block glyphs decide whether it scans
const qrShape = await page.evaluate(i => {
  const svg = document.querySelector(`#cell-out-${i} svg.cell-blocks`);
  const pre = document.querySelector(`#cell-out-${i} .cell-stdout.blocks.is-drawn`);
  if (!svg || !pre) return null;
  const [, , w, h] = svg.getAttribute('viewBox').split(' ').map(Number);
  const box = svg.getBoundingClientRect();
  const lines = pre.textContent.replace(/\n$/, '').split('\n');
  return { w, h, cols: Math.max(...lines.map(l => l.length)), rows: lines.length,
           pxW: box.width / w, pxH: box.height / h, preShown: pre.getBoundingClientRect().height > 2 };
}, qrIdx);
check('...drawn as square pixels, a character one module wide and two tall', !!qrShape &&
  qrShape.w === qrShape.cols && qrShape.h === 2 * qrShape.rows && Math.abs(qrShape.pxW - qrShape.pxH) < 0.01 && qrShape.pxW >= 3);
check('...the text kept in the page, out of sight', !!qrShape && !qrShape.preShown);
{
  // and a QR reader reads it off the screen (qr_reader gem, when installed)
  const png = '/tmp/jruby_test_qr.png';
  await (await page.$(`#cell-out-${qrIdx} svg.cell-blocks`)).screenshot({ path: png });
  const { spawnSync } = await import('node:child_process');
  const read = spawnSync('ruby', ['-e', 'require "qr_reader"; puts QrReader.read(ARGV[0]).inspect', png], { encoding: 'utf8' });
  if (read.status === 0) check('...and the screenshot scans: https://chunkybacon.idogawa.com', read.stdout.includes('https://chunkybacon.idogawa.com'));
  else console.log('  (no qr_reader gem: the scan is not checked)', (read.stderr || '').split('\n')[0]);
}
check('...and no "=> nil" after it', !qr.includes('=> nil'));
const parse = await run(page, await cellWith('JSON.parse', 'def '));
check('JSON.parse of the 7.3 MB USGS file on JRuby', /10224 quakes in \d+ ms/.test(parse));
const where = await run(page, await cellWith('tally'));
check('tally of the places', where.includes('["Alaska",'));

const parseCells = [];
for (const idx of cells) if ((await code(page, idx)).includes('puts "#{quakes.size} quakes')) parseCells.push(idx);
const cruby = await run(page, parseCells[1]);
check('the "on": "cruby" cell runs on the page\'s CRuby', cruby.includes('CRuby 4.0') && cruby.includes('ruby.wasm'));
check('...on the same data', /10224 quakes in \d+ ms/.test(cruby));
const jrMs = Number(parse.match(/in (\d+) ms/)[1]), crMs = Number(cruby.match(/in (\d+) ms/)[1]);
console.log(`  (parse: JRuby ${jrMs} ms, CRuby ${crMs} ms)`);

const jackson = await run(page, await cellWith('next_token'));
check('Jackson streaming from Ruby counts 173 quakes from M5', jackson.includes('=> 173'));
const quakes = await run(page, await cellWith('count_at_least'));
check('the same loop in Java (Lesson::Quakes): 173', quakes.includes('=> 173'));
const race = await run(page, await cellWith('sleep 0.001', 'Mutex'));
check('the sleep race loses updates: 100', race.includes('=> 100'));
const mutex = await run(page, await cellWith('Mutex'));
check('a Mutex fixes it: 400', mutex.includes('=> 400'));
const atomic = await run(page, await cellWith('AtomicLong'));
check('AtomicLong from java.util.concurrent: 200000', atomic.includes('=> 200000'));

// ---------- errors ----------
const ex = Number(await page.getAttribute('.cell.exercise .run-cell', 'data-idx'));
const syntax = await run(page, ex, 'def strong_quakes(quakes, magnitude)\n  quakes.count {\nend');
check('a syntax error is explained by CRuby before JRuby sees it', /line 2|2 \|/i.test(syntax));
const runtime = await run(page, ex, 'x = 1\nnil.upcase');
check('a JRuby error: NoMethodError', runtime.includes('upcase'));
check('...and its line is marked', await page.evaluate(i => window.cellEditors[i].getAllMarks().some(m => m.find().from.line === 1), ex));
const java = await run(page, ex, 'java.lang.Integer.parse_int("bacon")');
check('a Java exception reaches the cell', java.includes('NumberFormatException'));

// ---------- the exercise ----------
const starter = 'require "json"\n\ndef strong_quakes(quakes, magnitude)\n  # count the quakes with mag >= magnitude\nend\n\nquakes = JSON.parse(File.read("data/all_month.geojson"))["features"]\nstrong_quakes(quakes, 5)';
await run(page, ex, starter);
check('the starter does not pass', !(await page.getAttribute('.cell.exercise', 'class')).includes('celebrate'));
const passes = async body => {
  await run(page, ex, starter.replace('  # count the quakes with mag >= magnitude', body));
  return (await page.getAttribute('.cell.exercise', 'class')).includes('celebrate');
};
check('a body that ignores the magnitude does not pass', !(await passes('  quakes.count { |q| q["properties"]["mag"].to_f >= 5 }')));
check('...nor a hard-coded 173', !(await passes('  173')));
check('...nor > instead of >=', !(await passes('  quakes.count { |q| q["properties"]["mag"].to_f > magnitude }')));
const javaBody = '  n = java.util.concurrent.atomic.AtomicLong.new\n  quakes.each { |q| n.increment_and_get if q["properties"]["mag"].to_f >= magnitude }\n  n.get';
const errorsBefore = errors.length;
check('a solution with Java (AtomicLong) passes', await passes(javaBody));
const javaOut = await out(page, ex);
check('...and CRuby says it has no Java, instead of nothing', /CRuby \(ruby\.wasm\) cannot run this code: it uses Java/.test(javaOut));
check('...with no console error', errors.length === errorsBefore);
const solved = await run(page, ex, starter.replace('  # count the quakes with mag >= magnitude', '  quakes.count { |q| q["properties"]["mag"].to_f >= magnitude }'));
check('a solution passes the check (CRuby, the same data)', (await page.getAttribute('.cell.exercise', 'class')).includes('celebrate'));
check('...and CRuby, running the same code, agrees', /CRuby \(ruby\.wasm\) with the same code: => 173 – the same answer/.test(solved));

// ---------- a reset during a run ends the worker: the status line says so ----------
// (the lesson's reset button, while the first cell sleeps; the time limit's
// stop takes the same path, endWorker, after 60 s)
page.once('dialog', d => d.accept());
await page.evaluate(i => { window.setCellCode(i, 'sleep 30'); document.querySelector(`.run-cell[data-idx="${i}"]`).click(); }, cells[0]);
await page.waitForTimeout(800);
await page.click('#reset-code');
await page.waitForFunction(() => !window.chunkyJRuby.worker, null, { timeout: 10000 }).catch(() => {});
check('after a reset during a run, the status line no longer says ready',
  /JRuby was stopped; it starts again with the next run/.test(await page.textContent('.jruby-status')));
const again = await run(page, ex, '1 + 1');
check('...and the next run boots a new one: ready again', again.includes('=> 2') &&
  /JRuby is ready: jruby 10\.1/.test(await page.textContent('.jruby-status')));

// ---------- a reset: JRuby's variables go too ----------
await page.evaluate(() => window.chunkyJRuby.reset());
const fresh = await run(page, ex, 'defined?(quakes).inspect');
check('after a reset the binding is new', fresh.includes('"nil"'));

// (a 404 is the dev checkout's missing Spinel toolchain, compile/toolchain/ready.json)
// ---------- the Swing bonus (CheerpJ): nothing before the click ----------
const swingAsked = [];
page.on('request', r => { if (/leaningtech|jruby-swing|jruby_swing/.test(r.url())) swingAsked.push(r.url()); });
check('the bonus shows a preview and a start button', await page.evaluate(() =>
  !!document.querySelector('.jruby-swing img.jruby-swing-preview') && /40 MB/.test(document.querySelector('.jruby-swing-start').textContent)));
check('...and loads nothing of CheerpJ before the click', swingAsked.length === 0 && !(await page.$('iframe.jruby-swing-frame')));
if (process.env.SKIP_SWING) {
  console.log('  (SKIP_SWING: the CheerpJ part is not run)');
} else {
  await page.click('.jruby-swing-start');
  const frameEl = await page.waitForSelector('iframe.jruby-swing-frame');
  check('a click puts the CheerpJ page into an iframe', !!frameEl && (await frameEl.getAttribute('src')).includes('jruby_swing.html?lang=en'));
  const frame = await frameEl.contentFrame();
  await frame.waitForFunction(() => window.swingLab && (window.swingLab.ready() || window.swingLab.failed()), null, { timeout: 240000, polling: 1000 });
  const status = await frame.textContent('#msg');
  console.log(`  (${status})`);
  check('JRuby 9.4 on CheerpJ is ready, with Glimmer', /Ready: JRuby 9\.4\.15\.0 \(Ruby 3\.1/.test(status));
  const fox = await frame.evaluate(() => window.swingLab.run('fox'));
  check('Glimmer opens the fox window', fox.ok && /#<Fox/.test(fox.result));
  const feed = await frame.evaluate(() => window.swingLab.run('feed'));
  const label = await frame.evaluate(() => window.swingLab.eval('@label.text'));
  check('...and data binding follows the fox: Bacon: 10', feed.ok && label.result === '=> "Bacon: 10"');
  const temp = await frame.evaluate(() => window.swingLab.run('temp'));
  check('the Celsius converter opens', temp.ok);
  const chart = await frame.evaluate(() => window.swingLab.run('chart'));
  check('JFreeChart draws a pie from a Ruby Hash', chart.ok && chart.result === '=> true');
  const dark = await frame.evaluate(() => window.swingLab.run('dark'));
  check('FlatLaf switches to dark mode', dark.ok && dark.result.includes('Dark mode on'));
  check('the iframe grows with its page (no scroll bar inside)', await page.evaluate(() => {
    const f = document.querySelector('iframe.jruby-swing-frame');
    return Math.abs(f.getBoundingClientRect().height - f.contentDocument.documentElement.scrollHeight) < 12;
  }));
}

// ---------- German: the lesson in de, its exercise ----------
{
  const ctxDe = await browser.newContext({ locale: 'de-DE' });
  const de = await open(ctxDe, '#jruby');
  await de.waitForFunction(() => window.chunkyJRuby.ready, null, { timeout: 90000 });
  check('de: the status line is German, with a decimal comma', /JRuby ist bereit: jruby 10\.1.*, gestartet in \d+,\d s\./.test(await de.textContent('.jruby-status')));
  const deCells = await codeCells(de);
  const deWho = await run(de, deCells[0]);
  check('de: the cells run on JRuby', deWho.includes('["jruby", "10.1.2.0", "4.0.0"]') && deWho.includes('JRuby 10.1.2.0 im Browser (TeaVM)'));
  let deParse = null;
  for (const idx of deCells) if ((await code(de, idx)).includes('Beben in')) { deParse = idx; break; }
  check('de: JSON.parse counts 10224 Beben', /10224 Beben in \d+ ms/.test(await run(de, deParse)));
  const deEx = Number(await de.getAttribute('.cell.exercise .run-cell', 'data-idx'));
  const deStarter = await code(de, deEx);
  check('de: the exercise asks for staerke_beben', deStarter.includes('def staerke_beben(beben, staerke)'));
  const deSolved = await run(de, deEx, deStarter.replace(/  # .*\n/, '  beben.count { |q| q["properties"]["mag"].to_f >= staerke }\n'));
  check('de: a solution passes, and CRuby agrees', (await de.getAttribute('.cell.exercise', 'class')).includes('celebrate') &&
    /CRuby \(ruby\.wasm\) mit demselben Code: => 173 – dieselbe Antwort/.test(deSolved));
  check('de: the bonus preview is the German one', (await de.getAttribute('.jruby-swing-preview', 'src')).endsWith('swing-de.png'));
  await ctxDe.close();
}

check('no page errors', errors.filter(e => !/favicon|Failed to load resource/.test(e)).length === 0);
await browser.close();
console.log(failures === 0 ? 'ALL JRUBY TESTS PASSED' : `${failures} FAILED`);
process.exit(failures ? 1 : 0);
