// Accessibility audit, part 1: axe-core on representative pages in de/en/ja.
//
//   PORT 18110 dev server running (tools/dev_server.rb), then from this folder:
//   node audit.mjs                      # all languages, all pages
//   node audit.mjs en hallo,irb         # one language, some pages
//
// Writes out/axe-<lang>-<page>.json (violations + incomplete), screenshots in
// shots/, and out/axe-summary.json (rule -> pages). Playwright comes from the
// npx cache (PLAYWRIGHT_DIR), axe-core from ./node_modules.
import { pathToFileURL, fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));
const PW = process.env.PLAYWRIGHT_DIR ||
  join(homedir(), 'AppData/Local/npm-cache/_npx/e41f203b7505f1fb/node_modules/playwright');
const { chromium } = await import(pathToFileURL(join(PW, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18110/';
const AXE = join(HERE, 'node_modules/axe-core/axe.min.js');
const OUT = join(HERE, 'out');
const SHOTS = join(HERE, 'shots');
mkdirSync(OUT, { recursive: true });
mkdirSync(SHOTS, { recursive: true });

const LANGS = (process.argv[2] || 'de,en,ja').split(',');
const ONLY = process.argv[3] ? process.argv[3].split(',') : null;

// lesson pages: id, and a regex for the cell(s) to run before the audit
// (every cell up to the last match runs, in order, so the binding is there)
const PAGES = [
  { name: 'hallo', hash: 'hallo', run: /./ },                 // basics: all cells
  { name: 'irb', hash: 'irb', run: /show_irb/ },              // IRB terminal
  { name: 'sinatra', hash: 'sinatra', run: /show_browser/ },  // mini browser
  { name: 'three', hash: 'three', run: /show_three/ },        // WebGL stage
  { name: 'rumale', hash: 'rumale', run: /show_letter/ },     // the letter
  { name: 'werkstatt', hash: 'werkstatt', run: /./ },         // workshop
];

const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);

async function axe(page, name, context = null) {
  await page.addScriptTag({ path: AXE });
  const result = await page.evaluate(async (ctx) => {
    const r = await window.axe.run(ctx ? document.querySelector(ctx) : document, {
      resultTypes: ['violations', 'incomplete'],
    });
    const slim = list => list.map(v => ({
      id: v.id, impact: v.impact, tags: v.tags, help: v.help, helpUrl: v.helpUrl,
      nodes: v.nodes.map(n => ({ target: n.target, html: n.html.slice(0, 300), summary: n.failureSummary })),
    }));
    return { url: location.href, lang: document.documentElement.lang, violations: slim(r.violations), incomplete: slim(r.incomplete) };
  }, context);
  writeFileSync(join(OUT, `axe-${name}.json`), JSON.stringify(result, null, 2));
  return result;
}

async function waitIdle(page, timeout = 180000) {
  // no run button disabled (= nothing running) and no cell with .running
  await page.waitForFunction(() => !document.querySelector('.run-cell[disabled], .cell.running'), null, { timeout });
}

async function runUpTo(page, regex) {
  const codes = await page.evaluate(() => Object.keys(window.cellEditors)
    .filter(k => document.getElementById('cell-code-' + k))
    .map(k => [Number(k), window.cellEditors[k].getValue()]));
  codes.sort((a, b) => a[0] - b[0]);
  let last = -1;
  codes.forEach(([i, c]) => { if (regex.test(c)) last = i; });
  for (const [i] of codes) {
    if (i > last) break;
    await page.click(`.run-cell[data-idx="${i}"]`);
    await page.waitForTimeout(300);
    await waitIdle(page);
  }
  return last;
}

async function goto(page, hash) {
  await page.evaluate(h => { location.hash = h; }, hash);
  await page.waitForFunction(h => h === 'werkstatt' ? document.body.classList.contains('in-workshop')
    : !!document.querySelector(`#lessonNav a.active[data-id="${h}"]`), hash, { timeout: 30000 });
  await page.waitForTimeout(500);
}

const summary = {};
const note = (key, res) => {
  for (const v of res.violations) {
    summary[v.id] ||= { impact: v.impact, help: v.help, pages: {} };
    summary[v.id].pages[key] = v.nodes.length;
  }
};

const browser = await chromium.launch();
for (const lang of LANGS) {
  const locale = { de: 'de-DE', en: 'en-US', ja: 'ja-JP' }[lang];
  const ctx = await browser.newContext({ locale, viewport: { width: 1280, height: 900 } });
  const page = await ctx.newPage();
  page.on('pageerror', e => log('[pageerror]', e.message));
  await page.goto(`${BASE}?lang=${lang}#hallo`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 180000 });
  log(lang, 'kernel ready');

  for (const p of PAGES) {
    if (ONLY && !ONLY.includes(p.name)) continue;
    try {
      await goto(page, p.hash);
      if (p.name === 'werkstatt') {
        await page.click('.run-cell[data-idx="0"]');
        await page.waitForTimeout(300);
        await waitIdle(page);
      } else {
        await runUpTo(page, p.run);
      }
      await page.waitForTimeout(800);
      const res = await axe(page, `${lang}-${p.name}`);
      note(`${lang}-${p.name}`, res);
      await page.screenshot({ path: join(SHOTS, `${lang}-${p.name}.png`), fullPage: false });
      log(lang, p.name, 'violations:', res.violations.map(v => `${v.id}(${v.nodes.length})`).join(' ') || 'none');
    } catch (e) {
      log(lang, p.name, 'FAILED', e.message.split('\n')[0]);
    }
  }

  // the progress dialog, open
  if (!ONLY || ONLY.includes('progress')) {
    await goto(page, 'hallo');
    await page.click('#progressBtn');
    await page.waitForSelector('#progressDialog[open]');
    await page.waitForTimeout(400);
    const res = await axe(page, `${lang}-progress`);
    note(`${lang}-progress`, res);
    await page.screenshot({ path: join(SHOTS, `${lang}-progress.png`) });
    log(lang, 'progress', 'violations:', res.violations.map(v => `${v.id}(${v.nodes.length})`).join(' ') || 'none');
    await page.keyboard.press('Escape');
  }
  await ctx.close();

  // the sidebar drawer on a phone
  if (!ONLY || ONLY.includes('drawer')) {
    const phone = await browser.newContext({ locale, viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    const pp = await phone.newPage();
    await pp.goto(`${BASE}?lang=${lang}#hallo`, { waitUntil: 'domcontentloaded' });
    await pp.waitForSelector('#app', { state: 'visible', timeout: 120000 });
    await pp.waitForTimeout(800);
    await pp.screenshot({ path: join(SHOTS, `${lang}-phone-lesson.png`) });
    await pp.click('#sidebarToggle');
    await pp.waitForTimeout(500);
    const res = await axe(pp, `${lang}-drawer`);
    note(`${lang}-drawer`, res);
    await pp.screenshot({ path: join(SHOTS, `${lang}-drawer.png`) });
    log(lang, 'drawer', 'violations:', res.violations.map(v => `${v.id}(${v.nodes.length})`).join(' ') || 'none');
    await phone.close();
  }
}
await browser.close();
writeFileSync(join(OUT, 'axe-summary.json'), JSON.stringify(summary, null, 2));
log('summary:');
for (const [id, s] of Object.entries(summary)) {
  log(`  ${s.impact.padEnd(9)} ${id.padEnd(28)} ${Object.entries(s.pages).map(([k, n]) => `${k}:${n}`).join(' ')}`);
}
