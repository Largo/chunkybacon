// Headless test for the expert lessons mikro-* (docs/HANDOVER.md §6x): every
// code cell runs on ruby.wasm without an error; show_yarv's views (drawn by
// the shell, PicoRuby: shell/microscope.rb) step to the end and say that the
// simulator and Ruby itself agree; the lookup and GC views step through
// their pictures; the pictures are there; every exercise's solution passes.
// German and English by default (LANGS=de,en,ja). A few minutes.
//
//   BASE=http://127.0.0.1:8011/ node test/microscope_test.mjs
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const LESSONS = ['mikro-parser', 'mikro-yarv', 'mikro-stack', 'mikro-closures', 'mikro-values', 'mikro-lookup', 'mikro-zjit', 'mikro-gc'];
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond, extra) => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${cond || extra === undefined ? '' : ' -- ' + String(extra).slice(0, 300)}`);
  if (!cond) failures++;
};

for (const lang of (process.env.LANGS || 'de,en').split(',')) {
  const ctx = await browser.newContext({ locale: lang === 'de' ? 'de-DE' : 'en-US' });
  const page = await ctx.newPage();
  const shellErrors = [];
  page.on('pageerror', e => shellErrors.push(e.message));
  page.on('console', m => { if (m.type() === 'error' && /shell|microscope|msc/i.test(m.text())) shellErrors.push(m.text()); });
  for (const id of LESSONS) {
    await page.goto(BASE + `?lang=${lang}#${id}`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
    await page.waitForSelector('.run-cell', { timeout: 60000 });
    const idxs = await page.$$eval('.cell .run-cell', bs => bs.map(b => Number(b.getAttribute('data-idx'))));
    for (const idx of idxs) {
      const isTask = await page.evaluate(i => !!document.querySelector(`.run-cell[data-idx="${i}"]`).closest('.exercise'), idx);
      if (isTask) {
        const solution = await page.evaluate(([l, lid]) => window.LESSONS.lessons.find(x => x.id === lid)[l].cells.find(c => c.t === 'x').solution, [lang, id]);
        await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, solution]);
      }
      await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
      await page.click(`.run-cell[data-idx="${idx}"]`);
      await page.waitForFunction(() => window.__ran, null, { timeout: 180000 });
      const detail = await page.evaluate(() => JSON.stringify(window.__ran));
      const out = await page.evaluate(i => document.getElementById('cell-out-' + i).innerText, idx);
      const err = await page.$(`#cell-out-${idx} .cell-error, #cell-out-${idx} .friendly`);
      check(`${lang} ${id} cell ${idx} runs`, !err, out);
      if (isTask) check(`${lang} ${id}: the solution passes`, /pass/.test(detail), detail);
      // the step-through views, stepped to their last step
      const views = await page.$$(`#cell-out-${idx} .msc-box`);
      for (const view of views) {
        const kind = await view.evaluate(n => n.className);
        const buttons = await view.$$('.msc-controls .msc-btn');
        await buttons[3].click();   // ⏭
        const note = await view.$eval('.msc-note', n => n.textContent);
        if (/msc-yarv/.test(kind)) {
          const done = await view.$eval('.msc-note', n => n.classList.contains('is-done'));
          check(`${lang} ${id} cell ${idx}: YARV agrees with Ruby`, done && /✓/.test(note), note);
          await buttons[0].click(); // ⏮
          await buttons[2].click(); // ▶
          const frames = await view.$$eval('.msc-frame', f => f.length);
          const insn = await view.$eval('.msc-insn.is-now', n => n.textContent).catch(() => '');
          check(`${lang} ${id} cell ${idx}: step 2 shows a frame and the instruction`, frames >= 1 && insn.length > 0, `${frames} ${insn}`);
        } else {
          const svg = await view.$('.msc-pic svg');
          check(`${lang} ${id} cell ${idx}: picture stepped to the end`, !!svg && note.length > 5, note);
        }
      }
    }
    if (['mikro-parser', 'mikro-values'].includes(id)) {
      const pics = await page.$$eval('.cell-output img, [id^="cell-out-"] img', imgs => imgs.length);
      check(`${lang} ${id}: pictures shown`, pics >= 2, pics);
    }
  }
  check(`${lang}: no shell errors`, shellErrors.length === 0, shellErrors.join(' | '));
  await ctx.close();
}
await browser.close();
console.log(failures ? `${failures} FAILED` : 'all passed');
process.exit(failures ? 1 : 0);
