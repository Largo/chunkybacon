// Headless test for the two ways the page can fail to come up
// (docs/PICORUBY_SHELL.md): CRuby's wasm cannot be fetched - the header
// says so and a waiting run is freed -, PicoRuby's wasm cannot be fetched -
// the spinner says so after 20 s. About 30 s.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };

{
  const ctx = await browser.newContext();
  await ctx.route('**/ruby+stdlib.wasm', route => route.abort());
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error') console.log('  [console.error]', m.text().slice(0, 160)); });
  await page.goto(BASE + '#hallo');
  await page.waitForSelector('#app', { state: 'visible' });
  await page.click('.run-cell[data-idx="1"]');
  await page.waitForFunction(() => window.ChunkyBridge.failed, null, { timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(300);
  check('kernel failure is noticed', await page.evaluate(() => window.ChunkyBridge.failed));
  check('the header says Ruby could not be loaded', (await page.textContent('#kernelStatus')).includes('nicht geladen'));
  check('the waiting cell is free again', !(await page.evaluate(() => document.querySelector('.run-cell[data-idx="1"]').disabled)));
  check('the lesson stays readable', (await page.textContent('#lessonBody h2')).includes('Hallo'));
  await ctx.close();
}
{
  const ctx = await browser.newContext();
  await ctx.route('**/picoruby.wasm', route => route.abort());
  const page = await ctx.newPage();
  await page.goto(BASE + '#hallo');
  await page.waitForTimeout(21000);
  check('the spinner says the page could not start', (await page.textContent('#spinnerText')).includes('could not start'));
  await ctx.close();
}
await browser.close();
console.log(failures ? `${failures} FAILURES` : 'ALL BOOT FAILURE TESTS OK');
process.exit(failures === 0 ? 0 : 1);
