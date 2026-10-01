// Headless test for the language the page opens in (shell/bridge.js):
// ?lang= in the address, then the last choice, then the browser's preferred
// languages, then English.
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };

// a fresh browser with these preferred languages, at this address
async function visit(languages, path = '#hallo') {
  const ctx = await browser.newContext({ locale: languages[0] });
  await ctx.addInitScript(list => {
    Object.defineProperty(navigator, 'languages', { get: () => list });
  }, languages);
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.goto(BASE + path, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  return page;
}
const lang = page => page.getAttribute('html', 'lang');
const reload = async page => {
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
};

let page = await visit(['en-US', 'en']);
check('an English browser gets English', (await lang(page)) === 'en' &&
  (await page.textContent('#siteTitle')).includes('Learn Ruby'));
await page.context().close();

page = await visit(['ja-JP']);
check('a Japanese browser gets Japanese', (await lang(page)) === 'ja');
await page.context().close();

page = await visit(['de-CH', 'en']);
check('a Swiss German browser gets German', (await lang(page)) === 'de' &&
  (await page.textContent('#siteTitle')).includes('Ruby lernen'));
await page.context().close();

page = await visit(['fr-FR', 'de-DE', 'en']);
check('the first preferred language the course has wins', (await lang(page)) === 'de');
await page.context().close();

page = await visit(['fr-FR', 'it']);
check('a language the course lacks falls back to English', (await lang(page)) === 'en');
await page.context().close();

page = await visit(['en-US'], '?v=1&lang=ja#irb');
check('?lang= picks the language', (await lang(page)) === 'ja');
check('?lang= leaves the address, the rest stays', page.url().endsWith('/?v=1#irb'));
check('?lang= is kept as the choice', (await page.evaluate(() => localStorage.getItem('chunky_lang'))) === 'ja');
await page.goto(BASE + '#hallo', { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
check('the next visit without ?lang= stays Japanese', (await lang(page)) === 'ja');
await page.context().close();

page = await visit(['en-US'], '?lang=xx#hallo');
check('an unknown ?lang= is ignored', (await lang(page)) === 'en' && !page.url().includes('lang='));
await page.context().close();

page = await visit(['en-US']);
await page.selectOption('#langSelect', 'de');
await page.waitForTimeout(300);
await reload(page);
check('the last choice beats the browser', (await lang(page)) === 'de');
await page.context().close();

await browser.close();
console.log(failures === 0 ? 'ALL LANGUAGE TESTS OK' : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
