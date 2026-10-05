// Accessibility audit, part 2: scripted "manual" checks - keyboard, focus,
// live regions, lang attributes, contrast, reduced motion.
//
//   node keyboard.mjs            (dev server on 18110)
//
// Writes out/keyboard.json and prints PASS/FAIL/INFO lines.
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { mkdirSync, writeFileSync } from 'node:fs';
import { chromium } from './load_playwright.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASE = process.env.BASE || 'http://127.0.0.1:18110/';
const OUT = join(HERE, 'out');
const SHOTS = join(HERE, 'shots');
mkdirSync(OUT, { recursive: true });
mkdirSync(SHOTS, { recursive: true });

const report = {};
const say = (status, key, msg, data) => {
  console.log(`${status.padEnd(4)} ${key}: ${msg}`);
  report[key] = { status, msg, data };
};

// what has the focus, as a short readable string
const FOCUS = () => {
  const a = document.activeElement;
  if (!a || a === document.body) return 'BODY';
  const cm = a.closest('.CodeMirror');
  if (cm) {
    const cell = cm.closest('.cell');
    const ta = cell && cell.querySelector('textarea[id^="cell-code-"]');
    return `CODEMIRROR(${ta ? ta.id : '?'})`;
  }
  const where = a.closest('#sidebar') ? 'sidebar' : a.closest('header') ? 'header' : a.closest('main') ? 'main'
    : a.closest('dialog') ? 'dialog' : a.closest('footer') ? 'footer' : 'other';
  const txt = (a.getAttribute('aria-label') || a.textContent || a.value || '').trim().replace(/\s+/g, ' ').slice(0, 30);
  return `${where}:${a.tagName.toLowerCase()}${a.id ? '#' + a.id : ''}${a.className && typeof a.className === 'string' ? '.' + a.className.split(' ')[0] : ''}${a.dataset.idx ? '[' + a.dataset.idx + ']' : ''} "${txt}"`;
};
const focus = p => p.evaluate(FOCUS);

async function boot(browser, opts = {}, hash = 'hallo', lang = 'en') {
  const ctx = await browser.newContext({ locale: 'en-US', viewport: { width: 1280, height: 900 }, ...opts });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.goto(`${BASE}?lang=${lang}#${hash}`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  return { ctx, page };
}
const kernel = p => p.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 180000 });
const idle = p => p.waitForFunction(() => !document.querySelector('.run-cell[disabled], .cell.running'), null, { timeout: 180000 });

const browser = await chromium.launch();

// ---------------------------------------------------------------- 1. Tab walk
{
  const { ctx, page } = await boot(browser);
  await kernel(page);
  await page.evaluate(() => { document.activeElement && document.activeElement.blur(); window.scrollTo(0, 0); });
  const runButtons = await page.$$eval('.run-cell', bs => bs.map(b => b.dataset.idx));
  const stops = [];
  const traps = [];
  let firstMain = -1;
  for (let i = 0; i < 160; i++) {
    await page.keyboard.press('Tab');
    let f = await focus(page);
    if (f.startsWith('CODEMIRROR')) {
      // inside an editor: does Tab leave it?
      const before = await page.evaluate(() => Object.values(window.cellEditors).map(e => e.getValue()).join('\u0000'));
      await page.keyboard.press('Tab');
      const after = await focus(page);
      const changed = before !== await page.evaluate(() => Object.values(window.cellEditors).map(e => e.getValue()).join('\u0000'));
      // Escape, then Tab
      await page.keyboard.press('Escape');
      await page.keyboard.press('Tab');
      const afterEsc = await focus(page);
      // Shift+Tab
      await page.keyboard.press('Shift+Tab');
      const afterShift = await focus(page);
      traps.push({ editor: f, tabStaysIn: after === f, tabEditedCode: changed, escThenTab: afterEsc, shiftTab: afterShift });
      // undo the inserted tabs so later checks see the starter code
      await page.keyboard.press('Control+z'); await page.keyboard.press('Control+z'); await page.keyboard.press('Control+z');
      // a learner cannot get out here; the walk goes on from the cell's toolbar
      await page.evaluate(() => {
        const cell = document.activeElement.closest('.cell');
        const b = cell.querySelector('.cell-toolbar button');
        b.focus();
      });
      f = await focus(page);
      stops.push('(escaped by script) ' + f);
    } else {
      stops.push(f);
    }
    if (firstMain < 0 && (f.startsWith('main') || f.startsWith('CODEMIRROR'))) firstMain = i + 1;
    if (f.startsWith('footer') || (i > 5 && f === stops[0])) break;
  }
  const reached = runButtons.filter(idx => stops.some(s => s.includes(`.run-cell[${idx}]`)));
  // no editor reached = nothing tested, not a PASS
  if (!traps.length) say('FAIL', 'codemirror-trap', 'the Tab walk never reached a CodeMirror cell', traps);
  else say(traps.every(t => t.tabStaysIn) ? 'FAIL' : 'PASS', 'codemirror-trap',
    `Tab inside a CodeMirror cell ${traps[0].tabStaysIn ? 'stays in the editor and inserts indentation' : 'leaves the editor'}; Escape then Tab -> ${traps[0].escThenTab}; Shift+Tab -> ${traps[0].shiftTab}`, traps);
  say(reached.length === runButtons.length ? 'INFO' : 'FAIL', 'run-buttons-reachable',
    `${reached.length}/${runButtons.length} run buttons reached by Tab - but only because the script pulled focus out of each editor`, { runButtons, reached });
  say(firstMain > 15 ? 'FAIL' : 'PASS', 'bypass-blocks', `${firstMain} Tab presses from the top of the page to the first lesson control (no skip link)`, { firstMain });
  writeFileSync(join(OUT, 'tab-walk-en-hallo.txt'), stops.map((s, i) => `${String(i + 1).padStart(3)} ${s}`).join('\n'));

  // ------------------------------------------------ 2. running from the keyboard
  await page.focus('.run-cell[data-idx="1"]');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(60);
  const during = await focus(page);
  await idle(page);
  const afterRun = await focus(page);
  say(afterRun.includes('run-cell') ? 'PASS' : 'FAIL', 'focus-after-run',
    `Enter on Run: focus during the run = ${during}, after = ${afterRun}`, { during, afterRun });

  // live regions: is anything that changes after a run announced?
  const live = await page.evaluate(() => {
    const liveOf = el => {
      for (let n = el; n; n = n.parentElement) {
        const role = n.getAttribute && n.getAttribute('role');
        const l = n.getAttribute && n.getAttribute('aria-live');
        if (l || ['status', 'alert', 'log'].includes(role)) return `${n.tagName.toLowerCase()}${n.id ? '#' + n.id : ''} aria-live=${l} role=${role}`;
      }
      return null;
    };
    const ids = ['cell-out-1', 'chunkyChat', 'chunkyText', 'kernelStatus'];
    const r = {};
    ids.forEach(id => { const e = document.getElementById(id); r[id] = e ? liveOf(e) : 'missing'; });
    r.anyLiveRegions = [...document.querySelectorAll('[aria-live],[role=status],[role=alert],[role=log]')].map(e => e.id || e.className);
    r.runTime = document.querySelector('.run-time') ? liveOf(document.querySelector('.run-time')) : 'missing';
    return r;
  });
  say(live['cell-out-1'] ? 'PASS' : 'FAIL', 'output-announced', `cell output live region: ${live['cell-out-1']}; Chunky's bubble: ${live.chunkyChat}; run time: ${live.runTime}; kernel status: ${live.kernelStatus}`, live);

  // the run buttons all have the same name
  const names = await page.$$eval('.run-cell', bs => bs.map(b => b.getAttribute('aria-label') || b.textContent.trim()));
  say(new Set(names).size < names.length ? 'WARN' : 'PASS', 'run-button-names', `run button names: ${JSON.stringify(names)}`, names);

  // the exercise: solve it, then follow "next lesson" with the keyboard
  await page.evaluate(() => {
    const b = document.querySelector('.cell.exercise .run-cell');
    window.cellEditors[b.dataset.idx].setValue('"Hello, World!"');
  });
  await page.focus('.cell.exercise .run-cell');
  await page.keyboard.press('Enter');
  await idle(page);
  await page.waitForSelector('#nextLessonLink', { timeout: 10000 }).catch(() => null);
  const bubble = await page.evaluate(() => document.getElementById('chunkyChat').className + ' | ' + document.getElementById('chunkyText').textContent.slice(0, 80));
  await page.focus('#nextLessonLink').catch(() => null);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(600);
  const afterNext = await focus(page);
  const scroll = await page.evaluate(() => window.scrollY);
  say(afterNext === 'BODY' ? 'FAIL' : 'PASS', 'focus-after-next-lesson',
    `bubble after pass: "${bubble}"; Enter on the next-lesson link -> focus ${afterNext}, scrollY ${scroll}`, { afterNext });

  // a lesson link in the sidebar, by keyboard (wide screen)
  await page.focus('#lessonNav a[data-id="strings"]');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(600);
  const afterNav = await focus(page);
  say(afterNav === 'BODY' ? 'FAIL' : 'PASS', 'focus-after-nav-link',
    `Enter on a lesson link in the index -> focus ${afterNav} (the index is re-rendered with innerHTML)`, { afterNav });

  // Shift+Enter in an editor
  await page.click('.cell .CodeMirror');
  await page.keyboard.press('Shift+Enter');
  await page.waitForTimeout(100);
  await idle(page);
  say('INFO', 'shift-enter', `Shift+Enter in an editor runs it; focus afterwards ${await focus(page)}`);

  // Alt+R
  await page.evaluate(() => document.activeElement.blur());
  await page.keyboard.press('Alt+r');
  await page.waitForTimeout(100);
  await idle(page);
  say('INFO', 'alt-r', `Alt+R runs the exercise; focus afterwards ${await focus(page)} (shortcut documented only in lesson text?)`);

  // ---------------------------------------------- 3. progress dialog
  await page.focus('#progressBtn');
  await page.keyboard.press('Enter');
  await page.waitForSelector('#progressDialog[open]');
  const inDialog = await focus(page);
  const dlgStops = [];
  for (let i = 0; i < 25; i++) { await page.keyboard.press('Tab'); dlgStops.push(await focus(page)); }
  await page.keyboard.press('Escape');
  await page.waitForTimeout(200);
  const afterDlg = await focus(page);
  const escaped = dlgStops.filter(s => !s.startsWith('dialog') && s !== 'BODY');
  say(inDialog.startsWith('dialog') && afterDlg.includes('progressBtn') && !escaped.length ? 'PASS' : 'FAIL', 'progress-dialog',
    `opens with focus on ${inDialog}; Tab stays inside: ${!escaped.length}; Escape returns focus to ${afterDlg}`, { inDialog, dlgStops, afterDlg });

  // --------------------------------------------- 4. lang attributes
  await ctx.close();
}

// lang: Japanese text inside elements whose language is not ja, per UI language
for (const lang of ['de', 'en', 'ja']) {
  const { ctx, page } = await boot(browser, {}, 'hallo', lang);
  const early = await page.evaluate(() => document.documentElement.lang);
  const res = await page.evaluate(() => {
    const JA = /[぀-ヿ㐀-鿿＀-￯]/;
    const out = [];
    const walk = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const seen = new Set();
    let n;
    while ((n = walk.nextNode())) {
      if (!JA.test(n.data)) continue;
      const el = n.parentElement;
      const l = (el.closest('[lang]') || document.documentElement).getAttribute('lang');
      if (l !== 'ja' && !seen.has(el)) { seen.add(el); out.push({ el: el.tagName.toLowerCase() + (el.id ? '#' + el.id : ''), lang: l, text: n.data.trim().slice(0, 40) }); }
    }
    // attributes, too
    document.querySelectorAll('[title],[aria-label],[placeholder]').forEach(el => {
      ['title', 'aria-label', 'placeholder'].forEach(a => {
        const v = el.getAttribute(a);
        const l = (el.closest('[lang]') || document.documentElement).getAttribute('lang');
        if (v && JA.test(v) && l !== 'ja') out.push({ el: el.tagName.toLowerCase() + (el.id ? '#' + el.id : ''), attr: a, lang: l, text: v });
      });
    });
    const options = [...document.querySelectorAll('#langSelect option')].map(o => `${o.value}:${o.getAttribute('lang')}`);
    return { html: document.documentElement.lang, out, options };
  });
  say(res.out.length ? 'FAIL' : 'PASS', `lang-${lang}`,
    `<html lang> at domcontentloaded=${early}, after the shell=${res.html}; Japanese text in a non-ja element: ${res.out.length} (${res.out.slice(0, 4).map(o => `${o.el}${o.attr ? '@' + o.attr : ''} "${o.text}"`).join('; ')}); option langs: ${res.options.join(' ')}`, res);
  await ctx.close();
}

// spinner phase with ?lang=ja: what language does the loading screen claim?
{
  const ctx = await browser.newContext({ locale: 'ja-JP' });
  const page = await ctx.newPage();
  await page.route('**/picoruby.wasm', r => new Promise(res => setTimeout(() => res(r.continue()), 1500)));
  await page.goto(`${BASE}?lang=ja#hallo`, { waitUntil: 'domcontentloaded' });
  const s = await page.evaluate(() => ({ lang: document.documentElement.lang, text: document.getElementById('spinnerText').textContent, title: document.title }));
  await page.screenshot({ path: join(SHOTS, 'ja-spinner.png') });
  say('WARN', 'spinner-lang', `loading screen with ?lang=ja: <html lang="${s.lang}">, title "${s.title}", text "${s.text}" - the three languages are not marked up`, s);
  await ctx.close();
}

// ------------------------------------------------- 5. the drawer on a phone
{
  const { ctx, page } = await boot(browser, { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  await page.evaluate(() => document.activeElement && document.activeElement.blur());
  await page.keyboard.press('Tab');
  const first = await focus(page);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(400);
  const open = await page.evaluate(() => ({ cls: document.body.className, exp: document.getElementById('sidebarToggle').getAttribute('aria-expanded'), modal: document.getElementById('sidebar').getAttribute('aria-modal'), role: document.getElementById('sidebar').getAttribute('role'), inertMain: document.querySelector('.column').inert }));
  const afterOpen = await focus(page);
  const stops = [];
  for (let i = 0; i < 80; i++) {
    await page.keyboard.press('Tab');
    const f = await focus(page);
    stops.push(f);
    if (!f.startsWith('sidebar') && f !== 'BODY' && !f.includes('sidebarToggle')) break;
  }
  const leaked = stops[stops.length - 1];
  const leakedVisible = await page.evaluate(() => {
    const a = document.activeElement; const r = a.getBoundingClientRect();
    const top = document.elementFromPoint(Math.max(1, r.left + 2), Math.max(1, r.top + 2));
    return { coveredByScrim: top === document.body || (top && !a.contains(top)), inView: r.top >= 0 && r.bottom <= innerHeight };
  });
  await page.screenshot({ path: join(SHOTS, 'en-drawer-focus-leak.png') });
  say(leaked.startsWith('sidebar') ? 'PASS' : 'FAIL', 'drawer-focus',
    `first Tab -> ${first}; Enter opens the drawer (aria-expanded=${open.exp}, role=${open.role}, aria-modal=${open.modal}, page behind inert=${open.inertMain}); focus stays on ${afterOpen}; after ${stops.length} Tabs focus leaves the drawer to ${leaked} (behind the scrim: ${JSON.stringify(leakedVisible)})`, { first, open, stops });
  // Escape from inside the drawer
  await page.evaluate(() => document.body.classList.contains('sidebar-open') || document.getElementById('sidebarToggle').click());
  await page.focus('#lessonNav a[data-id="arrays"]');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  const afterEsc = await focus(page);
  say(afterEsc.includes('sidebarToggle') ? 'PASS' : 'FAIL', 'drawer-escape', `Escape inside the drawer closes it, focus -> ${afterEsc}`);
  // choosing a lesson from the drawer with the keyboard
  await page.click('#sidebarToggle');
  await page.waitForTimeout(300);
  await page.focus('#lessonNav a[data-id="arrays"]');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(600);
  const afterPick = await focus(page);
  say(afterPick === 'BODY' ? 'FAIL' : 'PASS', 'drawer-pick-lesson', `Enter on a lesson in the drawer: the drawer closes, focus -> ${afterPick}`);
  // reflow at 320 px
  await page.setViewportSize({ width: 320, height: 640 });
  await page.waitForTimeout(300);
  const overflow = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
  await page.screenshot({ path: join(SHOTS, 'en-320px.png') });
  say(overflow.sw > overflow.cw ? 'WARN' : 'PASS', 'reflow-320', `at 320 CSS px: scrollWidth ${overflow.sw} vs ${overflow.cw}`);
  await ctx.close();
}

// ------------------------------------------- 6. contrast (own computation)
// axe marks most text "incomplete" because the page has a background image
// (the exercise-book grid). This walks every visible text node and uses the
// nearest opaque background colour instead, i.e. the paper under the grid.
for (const where of ['hallo', 'werkstatt']) {
  const { ctx, page } = await boot(browser, {}, where);
  await kernel(page);
  await page.click('.run-cell[data-idx="' + (where === 'hallo' ? 1 : 0) + '"]');
  await idle(page);
  await page.focus('#navSearch'); // the placeholder stays
  // let the reveal animations (opacity 0 -> 1) end, or they read as 1:1
  await page.waitForTimeout(1200);
  await page.evaluate(() => document.getAnimations().forEach(a => { try { if (a.effect.getTiming().iterations !== Infinity) a.finish(); } catch (e) {} }));
  const low = await page.evaluate(() => {
    const parse = c => { const m = c.match(/rgba?\(([^)]+)\)/); if (!m) return null; const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number); return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 }; };
    const lum = c => { const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
    const blend = (fg, bg) => ({ r: fg.r * fg.a + bg.r * (1 - fg.a), g: fg.g * fg.a + bg.g * (1 - fg.a), b: fg.b * fg.a + bg.b * (1 - fg.a), a: 1 });
    const bgOf = el => {
      const stack = [];
      for (let n = el; n; n = n.parentElement) {
        const c = parse(getComputedStyle(n).backgroundColor);
        if (c && c.a > 0) { stack.push(c); if (c.a >= 1) break; }
      }
      let bg = { r: 255, g: 255, b: 255, a: 1 };
      for (let i = stack.length - 1; i >= 0; i--) bg = blend(stack[i], bg);
      return bg;
    };
    const opacityOf = el => { let o = 1; for (let n = el; n; n = n.parentElement) o *= Number(getComputedStyle(n).opacity); return o; };
    const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
    const hex = c => '#' + [c.r, c.g, c.b].map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
    const seen = new Map();
    const walk = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walk.nextNode())) {
      if (!n.data.trim()) continue;
      const el = n.parentElement;
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || el.closest('[hidden],dialog:not([open]),.CodeMirror-measure,.CodeMirror-cursors')) continue;
      const bg = bgOf(el);
      let fg = parse(cs.color);
      const op = opacityOf(el);
      fg = blend({ ...fg, a: fg.a * op }, bg);
      const size = parseFloat(cs.fontSize), bold = Number(cs.fontWeight) >= 700;
      const large = size >= 24 || (bold && size >= 18.66);
      const cr = ratio(fg, bg);
      const need = large ? 3 : 4.5;
      if (cr < need) {
        const key = `${hex(fg)} on ${hex(bg)}`;
        const sel = el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (typeof el.className === 'string' && el.className ? '.' + el.className.trim().split(/\s+/).join('.') : '');
        if (!seen.has(key + sel)) seen.set(key + sel, { pair: key, ratio: Math.round(cr * 100) / 100, need, sel, text: n.data.trim().slice(0, 30) });
      }
    }
    // the search field's placeholder
    const s = document.getElementById('navSearch');
    const ph = parse(getComputedStyle(s, '::placeholder').color);
    const placeholder = ph ? { pair: `${hex(blend(ph, bgOf(s)))} on ${hex(bgOf(s))}`, ratio: Math.round(ratio(blend(ph, bgOf(s)), bgOf(s)) * 100) / 100 } : null;
    // focus ring against paper (non-text contrast, 3:1)
    const ring = parse(getComputedStyle(document.documentElement).getPropertyValue('--focus').trim().replace(/^#(..)(..)(..)$/, (m, a, b, c) => `rgb(${parseInt(a, 16)},${parseInt(b, 16)},${parseInt(c, 16)})`));
    const fox = parse(getComputedStyle(document.documentElement).getPropertyValue('--fox').trim().replace(/^#(..)(..)(..)$/, (m, a, b, c) => `rgb(${parseInt(a, 16)},${parseInt(b, 16)},${parseInt(c, 16)})`));
    return { low: [...seen.values()], placeholder, focusRingOnPaper: ring && Math.round(ratio(ring, { r: 255, g: 255, b: 255 }) * 100) / 100, focusRingOnFox: ring && fox && Math.round(ratio(ring, fox) * 100) / 100, foxOnPaper: fox && Math.round(ratio(fox, { r: 255, g: 255, b: 255 }) * 100) / 100 };
  });
  say(low.low.length ? 'FAIL' : 'PASS', `contrast-${where}`,
    `${low.low.length} text/background pairs under the AA ratio: ${low.low.slice(0, 12).map(l => `${l.sel} "${l.text}" ${l.pair} ${l.ratio}:1`).join(' | ')}; placeholder ${JSON.stringify(low.placeholder)}; focus ring on paper ${low.focusRingOnPaper}:1, on fox ${low.focusRingOnFox}:1; fox orange on paper ${low.foxOnPaper}:1`, low);
  await ctx.close();
}

// --------------------------------------------- 7. reduced motion
for (const motion of ['reduce', 'no-preference']) {
  const ctx = await browser.newContext({ locale: 'en-US', reducedMotion: motion, viewport: { width: 1280, height: 900 } });
  const page = await ctx.newPage();
  await page.route('**/picoruby.wasm', r => new Promise(res => setTimeout(() => res(r.continue()), 1500)));
  await page.goto(`${BASE}?lang=en#hallo`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(300);
  const anims = () => page.evaluate(() => document.getAnimations().map(a => {
    const t = a.effect && a.effect.target;
    const name = a.animationName || a.transitionProperty || 'js';
    return `${name}@${t ? (t.className && typeof t.className === 'string' ? t.className.split(' ')[0] : t.tagName) : '?'}${a.effect.getTiming().iterations === Infinity ? '(infinite)' : ''}`;
  }));
  const spinner = await anims();
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await kernel(page);
  // a run: what moves while it runs
  await page.evaluate(() => { window.__seen = new Set(); const tick = () => { document.getAnimations().forEach(a => window.__seen.add((a.animationName || a.transitionProperty) + '@' + ((a.effect.target && a.effect.target.className) || '').toString().split(' ')[0])); if (window.__go) requestAnimationFrame(tick); }; window.__go = true; tick(); });
  await page.evaluate(() => window.cellEditors[2] && window.cellEditors[2].setValue('sleep 0.5\n"Hello, World!"'));
  await page.click('.cell.exercise .run-cell');
  await idle(page);
  await page.waitForTimeout(400);
  const during = await page.evaluate(() => { window.__go = false; return [...window.__seen]; });
  say(motion === 'reduce' && (spinner.length || during.length) ? 'WARN' : 'INFO', `motion-${motion}`,
    `loading screen: [${spinner.join(', ')}]; a run + pass: [${during.join(', ')}]`, { spinner, during });
  // three: does the animated scene keep going?
  if (motion === 'reduce') {
    await page.evaluate(() => { location.hash = 'three'; });
    await page.waitForTimeout(1500);
    const codes = await page.evaluate(() => Object.keys(window.cellEditors).filter(k => document.getElementById('cell-code-' + k)).map(k => [k, /show_three/.test(window.cellEditors[k].getValue()) && /do \|/.test(window.cellEditors[k].getValue())]));
    const animated = codes.find(c => c[1]);
    let moving = null;
    if (animated) {
      for (const [k] of codes) {
        await page.click(`.run-cell[data-idx="${k}"]`);
        await page.waitForTimeout(200);
        await idle(page);
        if (k === animated[0]) break;
      }
      await page.waitForTimeout(1500);
      moving = await page.evaluate(async (k) => {
        const c = document.querySelector(`#cell-out-${k} canvas`);
        if (!c) return 'no canvas';
        const a = c.toDataURL(); await new Promise(r => setTimeout(r, 700)); return a !== c.toDataURL();
      }, animated[0]);
      await page.screenshot({ path: join(SHOTS, 'en-three-reduced-motion.png') });
    }
    say(moving === true ? 'WARN' : 'INFO', 'three-reduced-motion', `animated show_three cell ${animated ? animated[0] : '-'}: canvas still changing under prefers-reduced-motion: ${moving}; pause control present: ${await page.evaluate(() => !!document.querySelector('.three-stage button'))}`);
    const threeA11y = await page.evaluate(() => [...document.querySelectorAll('.three-stage canvas')].map(c => ({ role: c.getAttribute('role'), label: c.getAttribute('aria-label'), tabindex: c.getAttribute('tabindex') })));
    say(threeA11y.some(c => !c.label) ? 'FAIL' : 'PASS', 'three-canvas-name', `3D canvases: ${JSON.stringify(threeA11y.slice(0, 3))}`);
  }
  await ctx.close();
}

// ------------------------------------------- 8. widgets by keyboard
{
  const { ctx, page } = await boot(browser, {}, 'irb');
  await kernel(page);
  const i = await page.evaluate(() => Object.keys(window.cellEditors).find(k => document.getElementById('cell-code-' + k) && /show_irb/.test(window.cellEditors[k].getValue())));
  await page.click(`.run-cell[data-idx="${i}"]`);
  await idle(page);
  await page.focus(`.run-cell[data-idx="${i}"]`);
  const order = [];
  for (let k = 0; k < 3; k++) { await page.keyboard.press('Tab'); order.push(await focus(page)); }
  const irbInput = await page.$('.irb-input');
  let irbLive = null;
  if (irbInput) {
    await irbInput.focus();
    await page.keyboard.type('1 + 2');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(500);
    irbLive = await page.evaluate(() => {
      const h = document.querySelector('.irb-history');
      let live = null; for (let n = h; n; n = n.parentElement) if (n.getAttribute('aria-live') || ['log', 'status'].includes(n.getAttribute('role'))) { live = n.className; break; }
      return { text: h.textContent.slice(-40), live, inputLabel: document.querySelector('.irb-input').getAttribute('aria-label') || document.querySelector('.irb-input').title, focus: document.activeElement.className };
    });
  }
  say(irbLive && irbLive.live ? 'PASS' : 'FAIL', 'irb-widget', `Tab after Run -> ${order.join(' -> ')}; IRB result "${irbLive && irbLive.text}" announced by: ${irbLive && irbLive.live}; input named by: ${irbLive && irbLive.inputLabel}; focus stays: ${irbLive && irbLive.focus}`, { order, irbLive });
  await ctx.close();
}

await browser.close();
writeFileSync(join(OUT, 'keyboard.json'), JSON.stringify(report, null, 2));
