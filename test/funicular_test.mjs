// Headless test for lesson `funicular` ("funicular": true; docs/HANDOVER.md
// §6w): each cell runs on CRuby headless (funicular_cells.rb), then for real
// in a preview below it - a PicoRuby.wasm of its own in an iframe
// (funicular_frame.js). Checks: every demo starts in its preview, clicks and
// typing re-render it, the log counts what the patcher changed (a click on
// +1 touches texts only; deleting a keyed item removes one element), a
// mistake is explained by CRuby and starts no preview, the exercise's
// starter fails and its solution passes - in German, English and Japanese
// (which runs the English code).
// About a minute.
//
//   BASE=http://127.0.0.1:8011/ node test/funicular_test.mjs
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond, extra) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${cond || extra === undefined ? '' : ' -- ' + extra}`); if (!cond) failures++; };
const errors = [];

async function open(lang) {
  const ctx = await browser.newContext({ locale: lang === 'de' ? 'de-DE' : 'en-US' });
  const page = await ctx.newPage();
  page.on('pageerror', e => { errors.push(e.message); console.log('[pageerror]', e.message); });
  await page.goto(BASE + `?lang=${lang}#funicular`, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  await page.waitForSelector('.run-cell', { timeout: 60000 });
  return page;
}
const codeCells = page => page.$$eval('.cell .run-cell', bs => bs.map(b => Number(b.getAttribute('data-idx'))));
const code = (page, idx) => page.evaluate(i => window.cellEditors[i].getValue(), idx);
async function run(page, idx, text) {
  if (text !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, text]);
  await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(() => window.__ran, null, { timeout: 90000 });
  return page.evaluate(i => document.getElementById('cell-out-' + i).textContent, idx);
}
// the preview's iframe below cell idx, once its app is up
async function preview(page, idx) {
  const handle = await page.waitForSelector(`#cell-out-${idx} iframe.funicular-frame`, { timeout: 30000 });
  await page.waitForFunction(i => {
    const s = document.querySelector(`#cell-out-${i} .funicular-status`);
    return s && /\d/.test(s.textContent);
  }, idx, { timeout: 30000 });
  return handle.contentFrame();
}
const log = (page, idx) => page.$$eval(`#cell-out-${idx} .funicular-log li`, lis => lis.map(li => li.textContent));
const appOut = (page, idx) => page.$eval(`#cell-out-${idx} .funicular-out`, el => el.textContent);
const waitLog = (page, idx, n) => page.waitForFunction(([i, k]) => document.querySelectorAll(`#cell-out-${i} .funicular-log li`).length >= k, [idx, n], { timeout: 10000 });

for (const lang of ['de', 'en', 'ja']) {
  const page = await open(lang);
  const cells = await codeCells(page);
  const cellWith = async text => { for (const i of cells) if ((await code(page, i)).includes(text)) return i; return null; };
  const T = lang === 'de'
    ? { hello: 'HalloFunicular', counter: 'SpeckZaehler', h2: 'Speckscheiben: 2', greet: 'FuchsGruss', hallo: 'Hallo, Chunky!', todo: 'FuchsListe', add: 'Dazu', open: 'Noch offen', rating: 'SpeckBewertung', task: 'class Ampel', next: 'Weiter', light: 'Ampel: grün', done: 'Speck braten' }
    : { hello: 'HelloFunicular', counter: 'BaconCounter', h2: 'Bacon slices: 2', greet: 'FoxGreeter', hallo: 'Hello, Chunky!', todo: 'FoxTodo', add: 'Add', open: 'Still to do', rating: 'BaconRating', task: 'class TrafficLight', next: 'Next', light: 'Light: green', done: 'Fry bacon' };

  // ---------- hello ----------
  const hello = await cellWith(T.hello);
  const helloOut = await run(page, hello);
  check(`${lang}: hello shows no => value`, !helloOut.includes('=>'), helloOut);
  let frame = await preview(page, hello);
  check(`${lang}: hello renders on PicoRuby`, (await frame.textContent('#app')).includes('Chunky bacon!'));
  check(`${lang}: ...RUBY_ENGINE in the preview is mruby`, (await frame.textContent('#app')).includes('mruby'));

  // ---------- counter: clicks, and the log counts texts only ----------
  const counter = await cellWith(T.counter);
  await run(page, counter);
  frame = await preview(page, counter);
  await frame.click('button:has-text("+1")');
  await waitLog(page, counter, 1);
  await frame.click('button:has-text("+1")');
  await waitLog(page, counter, 2);
  check(`${lang}: two clicks re-render`, (await frame.textContent('#app')).includes(T.h2));
  check(`${lang}: ...🥓🥓`, (await frame.textContent('#app')).includes('🥓🥓'));
  const entries = await log(page, counter);
  console.log('   log:', JSON.stringify(entries));
  check(`${lang}: the log's last update changed texts and left nodes alone`, /×/.test(entries[0]) && /\d+/.test(entries[0]) && !/(neu|added|weg|removed|追加|削除)/.test(entries[0]), entries[0]);
  check(`${lang}: ...red frames flashed in the preview`, await frame.evaluate(() => document.querySelectorAll('#fn-layer .fn-flash').length > 0));

  // ---------- greeter: typing ----------
  const greet = await cellWith(T.greet);
  await run(page, greet);
  frame = await preview(page, greet);
  await frame.click('input');
  await frame.type('input', 'Chunky', { delay: 40 });
  await page.waitForTimeout(300);
  const greetText = await frame.textContent('#app');
  check(`${lang}: typing re-renders`, greetText.includes(T.hallo), greetText);
  check(`${lang}: ...the box keeps what was typed`, (await frame.inputValue('input')) === 'Chunky');

  // ---------- todo: add, toggle, keyed delete ----------
  const todo = await cellWith(T.todo);
  await run(page, todo);
  frame = await preview(page, todo);
  await frame.fill('input', 'Bacon');
  await frame.click(`button:has-text("${T.add}")`);
  await page.waitForTimeout(300);
  check(`${lang}: todo: an item added`, (await frame.$$('li')).length === 3, String((await frame.$$('li')).length));
  check(`${lang}: ...and the box emptied`, (await frame.inputValue('input')) === '');
  const before = (await log(page, todo)).length;
  await frame.click('li:first-child button:has-text("✕")');
  await waitLog(page, todo, before + 1);
  const del = (await log(page, todo))[0];
  console.log('   delete:', del);
  check(`${lang}: todo: the keyed delete removed one element`, /×1/.test(del) && /(weg|removed|削除)/.test(del), del);
  check(`${lang}: ...the first item is gone`, !(await frame.textContent('#app')).includes(T.done));
  const todoOut = await appOut(page, todo).catch(() => '');
  check(`${lang}: ...no error from the app`, !/Error|Exception/.test(todoOut), todoOut);

  // ---------- rating: child components with props and a lambda ----------
  const rating = await cellWith(T.rating);
  await run(page, rating);
  frame = await preview(page, rating);
  const stars = await frame.$$('button');
  await stars[3].click();
  await page.waitForTimeout(300);
  const ratingText = await frame.textContent('#app');
  check(`${lang}: rating: the fourth star lights four`, ratingText.includes('★★★★☆'), ratingText);

  // ---------- a mistake: CRuby explains it, no preview ----------
  const bad = await run(page, hello, (await code(page, hello)).replace('h1 {', 'h1 {{'));
  check(`${lang}: a syntax error is explained`, bad.length > 0 && !(await page.$(`#cell-out-${hello} iframe.funicular-frame`)), bad.slice(0, 120));
  const nameErr = await run(page, hello, (await code(page, hello)).replace('h1 {{', 'h1 {').replace('div do', 'dvi do'));
  check(`${lang}: a typo in render is explained before the preview`, /dvi/.test(nameErr) && !(await page.$(`#cell-out-${hello} iframe.funicular-frame`)), nameErr.slice(0, 160));

  // ---------- the exercise ----------
  const task = await cellWith(T.task);
  await run(page, task);
  check(`${lang}: the starter does not pass`, !(await page.evaluate(i => document.querySelector(`.cell[data-cell="${i}"]`)?.classList.contains('passed'), task)));
  frame = await preview(page, task);
  const solution = await page.evaluate(([i, l]) => {
    const lesson = window.LESSONS.lessons.find(x => x.id === 'funicular');
    return lesson[l].cells.find(c => c.t === 'x').solution;
  }, [task, lang]);
  await run(page, task, solution);
  const detail = await page.evaluate(() => JSON.stringify(window.__ran));
  check(`${lang}: the solution passes`, /pass/.test(detail), detail);
  frame = await preview(page, task);
  await frame.click(`button:has-text("${T.next}")`);
  await page.waitForTimeout(300);
  check(`${lang}: ...and its light switches in the preview`, (await frame.textContent('#app')).includes(T.light));

  await page.context().close();
}

await browser.close();
console.log(failures ? `${failures} FAILED` : 'all passed');
process.exit(failures ? 1 : 0);
