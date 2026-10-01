// Headless test for live runs (html/autorun.rb, shell/app.rb): code runs by
// itself a moment after the last key - only code that parses, as a
// rehearsal that keeps no file, without downloads, cut off after a second -
// and the workshop's switch starts off. About a minute.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };

async function open(ctx, hash) {
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  page.on('console', m => { if (m.type() === 'error') console.log('  [console.error]', m.text().slice(0, 160)); });
  await page.goto(BASE + hash, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  return page;
}
const out = (page, idx) => page.evaluate(i => {
  const el = document.getElementById('cell-out-' + i);
  return el && el.style.display !== 'none' ? el.textContent : '';
}, idx);
// an edit as the learner makes it (not setValue, which is the page's own)
const edit = (page, idx, code) => page.evaluate(([i, text]) => {
  const cm = window.cellEditors[i];
  cm.replaceRange(text, { line: 0, ch: 0 }, { line: cm.lineCount(), ch: 0 }, '+input');
}, [idx, code]);
const runs = page => page.evaluate(() => window.__runs.length);
// what the shell asked the kernel for (shell/bridge.js)
const countRuns = page => page.evaluate(() => {
  window.__runs = [];
  window.addEventListener('chunky:run', e => window.__runs.push(e.detail.auto ? 'auto' : 'run'));
});
const responsive = async page => {
  const started = Date.now();
  await page.evaluate(() => 1 + 1);
  return Date.now() - started < 3000;
};

// ---------- a lesson: on by default ----------
{
  const ctx = await browser.newContext({ locale: 'de-DE' });
  const page = await open(ctx, '#hallo');
  await countRuns(page);
  check('the lesson has a Live switch, on', (await page.getAttribute('.cell:has(.run-cell[data-idx="1"]) .live-toggle', 'aria-pressed')) === 'true');

  // real keys into CodeMirror
  await page.click('.cell:has(.run-cell[data-idx="1"]) .CodeMirror');
  await page.keyboard.press('Control+A');
  await page.keyboard.type('6 * 7', { delay: 40 });
  await page.waitForTimeout(300);
  check('nothing runs while typing', (await runs(page)) === 0);
  await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('42'), null, { timeout: 5000 }).catch(() => {});
  check('the cell ran by itself a moment later', (await out(page, 1)).includes('=> 42'));
  check('once, as a live run', JSON.stringify(await page.evaluate(() => window.__runs)) === '["auto"]');
  check('its output is marked as a rehearsal', await page.evaluate(() => document.getElementById('cell-out-1').classList.contains('is-rehearsal')));

  await edit(page, 1, '6 * ');
  await page.waitForTimeout(1600);
  check('code that does not parse leaves the output as it was', (await out(page, 1)).includes('=> 42'));

  await edit(page, 1, 'while true\nend');
  await page.waitForTimeout(1600);
  check('an empty endless loop is not started', await responsive(page));
  check('... and the output stays', (await out(page, 1)).includes('=> 42'));

  await edit(page, 1, 'File.write("probe.txt", "Speck")\nFile.read("probe.txt")');
  await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('Speck'), null, { timeout: 5000 }).catch(() => {});
  check('a live run can write and read a file', (await out(page, 1)).includes('"Speck"'));
  await page.evaluate(() => window.cellEditors[3].setValue('File.exist?("probe.txt")'));
  await page.click('.run-cell[data-idx="3"]');
  await page.waitForFunction(() => (document.getElementById('cell-out-3').textContent || '').includes('=>'), null, { timeout: 10000 });
  check('... which it does not keep', (await out(page, 3)).includes('=> false'));
  check('a run with ▶ is no rehearsal', !(await page.evaluate(() => document.getElementById('cell-out-3').classList.contains('is-rehearsal'))));

  await edit(page, 1, 'install_gem "rainbow"');
  await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('▶'), null, { timeout: 5000 }).catch(() => {});
  check('a live run downloads no gem, it says ▶ will', (await out(page, 1)).includes('nur mit ▶'));
  check('... and installs nothing', !(await page.textContent('#gemsList')).includes('rainbow'));

  // the exercise passes by itself, and Chunky cheers
  const ex = await page.getAttribute('.cell.exercise .run-cell', 'data-idx');
  await edit(page, ex, 'puts "Hallo, Welt!"');
  await page.waitForFunction(() => document.getElementById('chunkyChat').className === 'pass', null, { timeout: 5000 }).catch(() => {});
  check('a live pass cheers', (await page.getAttribute('#chunkyChat', 'class')) === 'pass');
  check('... and marks the lesson done', (await page.getAttribute('#lessonNav a[data-id="hallo"]', 'class')).includes('done'));

  await edit(page, ex, 'puts "Hallo"');
  await page.evaluate(() => { document.getElementById('chunkyText').textContent = 'still'; });
  await page.waitForTimeout(1600);
  check('a live miss stays quiet', (await page.textContent('#chunkyText')) === 'still');
  check('... no shake', !(await page.evaluate(i => document.querySelector(`.run-cell[data-idx="${i}"]`).closest('.cell').classList.contains('shake'), ex)));

  // endless with a body: stopped after a second, the page lives on
  const before = Date.now();
  await edit(page, 1, 'n = 0\nloop do\n  n += 1\nend');
  await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('angehalten'), null, { timeout: 8000 }).catch(() => {});
  check('an endless loop is stopped after a second', (await out(page, 1)).includes('Nach einer Sekunde angehalten'));
  check('... the page lives on', await responsive(page));
  check('... within a few seconds', Date.now() - before < 6000);
  check('... and the cell waits for ▶ from now on',
    await page.evaluate(() => document.querySelector('.cell:has(.run-cell[data-idx="1"]) .live-toggle').classList.contains('is-paused')));
  const count = await runs(page);
  await edit(page, 1, 'n = 1');
  await page.waitForTimeout(1600);
  check('... no more live runs there', (await runs(page)) === count);

  // the switch
  await page.click('.cell:has(.run-cell[data-idx="3"]) .live-toggle');
  check('the switch turns live runs off', (await page.evaluate(() => localStorage.getItem('chunkyui_live'))) === 'off');
  check('... on every cell', await page.evaluate(() => [...document.querySelectorAll('.live-toggle')].every(b => b.getAttribute('aria-pressed') === 'false')));
  const off = await runs(page);
  await edit(page, 3, '1 + 2');
  await page.waitForTimeout(1600);
  check('... and nothing runs by itself', (await runs(page)) === off);
  await page.reload();
  await page.waitForSelector('#app', { state: 'visible' });
  check('the switch is remembered', (await page.getAttribute('.live-toggle', 'aria-pressed')) === 'false');
  await ctx.close();
}

// ---------- the workshop: off by default, a rehearsal keeps no file ----------
{
  const ctx = await browser.newContext({ locale: 'de-DE' });
  const page = await open(ctx, '#werkstatt');
  await countRuns(page);
  check('the workshop starts with Live off', (await page.getAttribute('.ws-editor .live-toggle', 'aria-pressed')) === 'false');
  await edit(page, 0, 'puts 1');
  await page.waitForTimeout(1600);
  check('... and nothing runs by itself', (await runs(page)) === 0);

  await page.click('.ws-editor .live-toggle');
  check('it can be turned on', (await page.getAttribute('.ws-editor .live-toggle', 'aria-pressed')) === 'true');
  check('... for the workshop only', (await page.evaluate(() => [localStorage.getItem('chunkyui_live_ws'), localStorage.getItem('chunkyui_live')])).join() === 'on,');
  await edit(page, 0, 'File.write("live.txt", "Speck")\nputs File.read("live.txt")');
  await page.waitForFunction(() => (document.getElementById('cell-out-0').textContent || '').includes('Speck'), null, { timeout: 5000 }).catch(() => {});
  check('a live program runs', (await out(page, 0)).includes('Speck'));
  check('... and writes nothing into the project', (await page.evaluate(() => window.ChunkyStorage.files.read('live.txt'))) === null);
  check('... nor into the file list', !(await page.textContent('#wsFiles')).includes('live.txt'));
  await page.click('.run-cell[data-idx="0"]');
  await page.waitForFunction(() => window.ChunkyStorage.files.read('live.txt') !== null, null, { timeout: 10000 }).catch(() => {});
  check('▶ keeps what the program writes', (await page.evaluate(() => window.ChunkyStorage.files.read('live.txt'))) === 'Speck');
  await ctx.close();
}

await browser.close();
console.log(failures ? `${failures} FAILURES` : 'ALL LIVE TESTS OK');
process.exit(failures === 0 ? 0 : 1);
