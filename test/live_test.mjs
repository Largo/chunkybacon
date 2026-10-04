// Headless test for live runs (html/autorun.rb, shell/app.rb): code runs by
// itself a moment after the last key - only code that parses, as a
// rehearsal that keeps no file, without downloads, cut off after a second -
// and the workshop's switch starts off. A SQLite database in a file
// (sqlite3_sqljs.rb): a live run reads it but changes only its own, and the
// workshop keeps it with the project. About two minutes.
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

// ---------- a check that reads the file a live run wrote ----------
{
  const ctx = await browser.newContext({ locale: 'de-DE' });
  const page = await open(ctx, '#jpeg');
  const ex = await page.getAttribute('.cell.exercise .run-cell', 'data-idx');
  await edit(page, ex, 'install_gem "pure_jpeg"\nrequire "pure_jpeg"\nkarte = PureJPEG::Source::RawSource.new(80, 60) { |x, y| y < 30 ? [100, 160, 230] : [60, 160, 60] }\nPureJPEG.encode(karte).write("postkarte.jpg")');
  await page.waitForFunction(() => document.getElementById('chunkyChat').className === 'pass', null, { timeout: 15000 }).catch(() => {});
  check('a live run installs a cached gem and passes a check that reads its file', (await page.getAttribute('#chunkyChat', 'class')) === 'pass');
  await page.evaluate(() => window.cellEditors[1].setValue('File.exist?("postkarte.jpg")'));
  await page.click('.run-cell[data-idx="1"]');
  await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('=>'), null, { timeout: 10000 });
  check('... and the file is gone afterwards', (await out(page, 1)).includes('=> false'));
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

// ▶ on a cell, until it has run
const run = async (page, idx, code) => {
  if (code !== undefined) await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [idx, code]);
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForTimeout(300);
  await page.waitForFunction(i => !document.querySelector(`.run-cell[data-idx="${i}"]`).disabled &&
    document.getElementById('cell-out-' + i).style.display !== 'none', idx, { timeout: 120000 }).catch(() => {});
  return out(page, idx);
};
const outIncludes = (page, idx, text) => page.waitForFunction(([i, t]) =>
  (document.getElementById('cell-out-' + i).textContent || '').includes(t), [idx, text], { timeout: 8000 }).catch(() => {});

// ---------- a database in a file: a live run reads it, changes only its own ----------
{
  const ctx = await browser.newContext({ locale: 'de-DE' });
  const page = await open(ctx, '#sequel');
  await run(page, 1);
  const fileCell = await page.evaluate(() => [...document.querySelectorAll('.run-cell')].map(b => b.dataset.idx)
    .find(i => window.cellEditors[i].getValue().includes('Sequel.sqlite("zeiterfassung.db")')));
  check('▶ fills the database file', /=> 1(?!\d)/.test(await run(page, fileCell)));
  await edit(page, 3, 'zeiterfassung[:eintraege].insert(projekt: "Live", stunden: 1)\nzeiterfassung[:eintraege].count');
  await outIncludes(page, 3, '▶');
  check('a live run changes no database opened before it, it says ▶ will', (await out(page, 3)).includes('eine Datenbank ändern geht nur mit ▶'));
  await edit(page, 5, 'zeiterfassung[:eintraege].where(projekt: "Chunky").count');
  await outIncludes(page, 5, '=>');
  check('... but may read it', (await out(page, 5)).includes('=> 1'));
  await edit(page, 7, 'probe = Sequel.sqlite("probe.db")\nprobe.create_table(:t) { Integer :x }\nprobe[:t].insert(x: 1)\nprobe[:t].count');
  await outIncludes(page, 7, '=>');
  check('a database the live run opens itself may be changed', (await out(page, 7)).includes('=> 1'));
  check('... and is thrown away with it',
    (await run(page, 9, '[zeiterfassung[:eintraege].count, File.exist?("probe.db")]')).includes('=> [1, false]'));
  await ctx.close();
}

// ---------- the workshop keeps a program's database ----------
{
  const ctx = await browser.newContext({ locale: 'de-DE' });
  const page = await open(ctx, '#werkstatt');
  const stored = () => page.evaluate(() => window.ChunkyStorage.files.read('zeit.db') || '');
  const program = 'install_gem "sequel"\nrequire "sequel"\nDB = Sequel.sqlite("zeit.db")\nDB.create_table?(:arbeit) do\n  primary_key :id\n  String :projekt\nend\nDB[:arbeit].insert(projekt: "Chunky")\nputs "Zeilen: #{DB[:arbeit].count}"';
  check('the first run waits for SQLite', (await run(page, 0, program)).includes('Zeilen: 1'));
  check('... and the database is kept as a SQLite file', (await stored()).startsWith('data:application/vnd.sqlite3;base64,U1FMaXRlIGZvcm1hdCAz'));
  check('... in the file list', (await page.textContent('#wsFiles')).includes('zeit.db'));
  check('the next run reads it', (await run(page, 0)).includes('Zeilen: 2'));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  check('a reload keeps it', (await run(page, 0)).includes('Zeilen: 3'));
  await page.click('#wsFiles >> text=zeit.db');
  check('selected, it is described instead of opened in the editor',
    ((await page.textContent('#wsPreview p.ws-database').catch(() => '')) || '').includes('SQLite-Datenbank'));
  await ctx.close();
}

await browser.close();
console.log(failures ? `${failures} FAILURES` : 'ALL LIVE TESTS OK');
process.exit(failures === 0 ? 0 : 1);
