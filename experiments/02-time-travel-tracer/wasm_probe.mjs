// Runs html/step_recorder.rb inside a lesson cell on ruby.wasm (the real page,
// from the dev server) and prints what wasm_probe_tail.rb reports: does the
// targeted TracePoint work there, and what does recording cost.
//   PLAYWRIGHT_DIR=.../node_modules/playwright BASE=http://127.0.0.1:18102/ node wasm_probe.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(pathToFileURL(join(process.env.PLAYWRIGHT_DIR, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18102/';

const code = readFileSync(join(here, '..', '..', 'html', 'step_recorder.rb'), 'utf8') + readFileSync(join(here, 'wasm_probe_tail.rb'), 'utf8');
const browser = await chromium.launch();
const page = await (await browser.newContext({ locale: 'de-DE' })).newPage();
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.goto(BASE + '#schleifen', { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
// switch live runs off for this cell's edit: setValue is the page's own and does not trigger one
await page.evaluate(c => window.cellEditors[1].setValue(c), code);
await page.click('.run-cell[data-idx="1"]', { noWaitAfter: true });
await page.waitForFunction(() => /RUBY_PLATFORM|Error/.test(document.getElementById('cell-out-1').textContent || ''), null, { timeout: 120000 });
const text = await page.evaluate(() => document.getElementById('cell-out-1').textContent);
console.log(text);
writeFileSync(join(here, 'wasm_probe_result.txt'), text);
await browser.close();
