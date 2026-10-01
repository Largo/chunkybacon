// Headless test for permalinks: the page served by the optional server
// (server/app.rb) at /de/methoden, /en/werkstatt ... - navigating, back,
// language, reload, old /#hash links, and Ruby running under a permalink.
//   cd server && bundle exec puma -b tcp://127.0.0.1:8012 config.ru
//   BASE=http://127.0.0.1:8012/ node permalink_test.mjs
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = (process.env.BASE || 'http://127.0.0.1:8012/').replace(/\/$/, '');
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };

const ctx = await browser.newContext({ locale: 'de-DE' });
const page = await ctx.newPage();
page.on('pageerror', e => console.log('[pageerror]', e.message));
const path = () => page.evaluate(() => location.pathname + location.hash);
const active = () => page.getAttribute('#lessonNav a.active', 'data-id');
const shown = async id => page.waitForFunction(i => {
  const a = document.querySelector('#lessonNav a.active');
  return a && a.getAttribute('data-id') === i;
}, id, { timeout: 15000 }).then(() => true, () => false);

const response = await page.goto(BASE + '/de/methoden');
check('a permalink is served', response.status() === 200);
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
check('it opens its lesson', await shown('methoden'));
check('in its language', (await page.getAttribute('html', 'lang')) === 'de' && (await page.textContent('#lessonBody h2')).includes('Methoden'));
check('the address stays', (await path()) === '/de/methoden');
check('the tab is titled for the lesson', (await page.title()).startsWith('9. Methoden'));
check('index links are permalinks', (await page.getAttribute('#lessonNav a[data-id="klassen"]', 'href')) === '/de/klassen');

// navigating within the page: no reload, a history entry
await page.evaluate(() => { window.__samePage = true; });
await page.click('#lessonNav a[data-id="klassen"]');
check('a click goes to the next permalink', await shown('klassen') && (await path()) === '/de/klassen');
check('... without loading the page again', await page.evaluate(() => window.__samePage === true));
await page.goBack();
check('back returns to the lesson before', await shown('methoden') && (await path()) === '/de/methoden');
await page.goForward();
check('forward too', await shown('klassen'));

// Ruby runs under a permalink: every relative URL resolves against <base>
await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
await page.evaluate(() => window.cellEditors[1].setValue('[RUBY_VERSION.split(".").first.to_i >= 3, 6 * 7]'));
await page.click('.run-cell[data-idx="1"]');
await page.waitForFunction(() => (document.getElementById('cell-out-1').textContent || '').includes('=>'), null, { timeout: 30000 }).catch(() => {});
check('the kernel loads and runs code', (await page.textContent('#cell-out-1')).includes('=> [true, 42]'));

// the language
await page.selectOption('#langSelect', 'en');
check('switching the language changes the permalink', (await path()) === '/en/klassen');
await page.reload();
await page.waitForSelector('#app', { state: 'visible' });
check('a reload keeps lesson and language', await shown('klassen') && (await page.getAttribute('html', 'lang')) === 'en');

// the workshop
await page.click('#workshopLink');
await page.waitForFunction(() => document.body.classList.contains('in-workshop'), null, { timeout: 10000 }).catch(() => {});
check('the workshop has a permalink', (await path()) === '/en/werkstatt');
await page.reload();
await page.waitForSelector('#app', { state: 'visible' });
check('... that reloads into the workshop', await page.evaluate(() => document.body.classList.contains('in-workshop')));

// old links and the bare address
await page.goto(BASE + '/#hashes');
await page.waitForSelector('#app', { state: 'visible' });
check('an old /#hash link becomes a permalink', await shown('hashes') && (await path()) === '/en/hashes');
await page.goto(BASE + '/');
await page.waitForSelector('#app', { state: 'visible' });
check('the bare address names the lesson left off at', (await path()) === '/en/hashes');

// what the server says about pages that do not exist
check('an unknown lesson is a 404', (await page.goto(BASE + '/de/gibts-nicht')).status() === 404);
check('an unknown language too', (await page.goto(BASE + '/xx/methoden')).status() === 404);
const meta = await (await page.request.get(BASE + '/ja/methoden')).text();
check('a permalink carries its own title for link previews', meta.includes('<meta property="og:title" content="9. メソッド'));

await browser.close();
console.log(failures ? `${failures} FAILURES` : 'ALL PERMALINK TESTS OK');
process.exit(failures === 0 ? 0 : 1);
