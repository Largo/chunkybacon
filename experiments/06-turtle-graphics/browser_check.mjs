// The turtle in the real page, served by serve.rb (html/ + the turtle,
// changed in memory): the lesson's demo cells draw, the pictures animate,
// the exercise passes with a Koch snowflake and fails with the starter.
//   PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/<hash>/node_modules/playwright \
//     node experiments/06-turtle-graphics/browser_check.mjs
import { pathToFileURL, fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';

const { chromium } = await import(pathToFileURL(join(process.env.PLAYWRIGHT_DIR, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18106/';
const SHOTS = join(dirname(fileURLToPath(import.meta.url)), 'shots');

const browser = await chromium.launch();
const page = await browser.newPage({ locale: 'de-DE', viewport: { width: 1200, height: 900 } });
page.on('pageerror', e => console.log('[pageerror]', e.message));
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };

// 1. the examples, as <img>: halfway through the animation, and at the end
await page.goto(BASE + 'turtle/preview.html');
await page.waitForTimeout(700);
await page.screenshot({ path: join(SHOTS, 'preview-midway.png'), fullPage: true });
await page.waitForTimeout(4500);
await page.screenshot({ path: join(SHOTS, 'preview-end.png'), fullPage: true });

// 2. the lesson in the course
await page.goto(BASE + '#turtle', { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
check('lesson renders', (await page.textContent('#lessonBody h2')).includes('Malen mit Chunky'));
const run = async idx => {
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => window.ChunkyBridge && window.ChunkyBridge.ready &&
    document.getElementById(`cell-out-${i}`).textContent.includes('=>'), idx, { timeout: 120000 });
};
for (const idx of [1, 3, 5]) {
  await run(idx);
  const imgs = await page.$$eval(`#cell-out-${idx} img.cell-image`, els => els.map(e => [e.src.slice(0, 25), e.naturalWidth, e.getBoundingClientRect().width]));
  check(`cell ${idx} shows ${imgs.length} SVG picture(s) ${JSON.stringify(imgs.map(i => i.slice(1)))}`,
        imgs.length > 0 && imgs.every(([src, w]) => src === 'data:image/svg+xml;base64' && w > 0));
}
await page.waitForTimeout(400);
await page.locator('#cell-out-1').screenshot({ path: join(SHOTS, 'app-square-midway.png') });
await page.waitForTimeout(4000);
await page.locator('#cell-out-5').screenshot({ path: join(SHOTS, 'app-tree.png') });

const idx = await page.getAttribute('.cell.exercise .run-cell', 'data-idx');
await page.click(`.run-cell[data-idx="${idx}"]`);
await page.waitForFunction(i => document.getElementById(`cell-out-${i}`).textContent.includes('=>'), idx, { timeout: 30000 });
check('starter does not pass', !((await page.getAttribute('#chunkyChat', 'class')) || '').includes('pass'));

const solution = `def koch(laenge, tiefe)
  if tiefe == 0
    forward laenge
  else
    koch(laenge / 3.0, tiefe - 1)
    left 60
    koch(laenge / 3.0, tiefe - 1)
    right 120
    koch(laenge / 3.0, tiefe - 1)
    left 60
    koch(laenge / 3.0, tiefe - 1)
  end
end

turtle do
  color "#2a6fb0"
  3.times do
    koch(270, 3)
    right 120
  end
end
`;
await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [idx, solution]);
await page.click(`.run-cell[data-idx="${idx}"]`);
await page.waitForFunction(() => (document.getElementById('chunkyChat').className || '').includes('pass'), null, { timeout: 30000 })
  .catch(() => {});
check('Koch snowflake passes', ((await page.getAttribute('#chunkyChat', 'class')) || '').includes('pass'));
await page.waitForTimeout(4500);
await page.locator(`#cell-out-${idx}`).screenshot({ path: join(SHOTS, 'app-koch.png') });
await page.screenshot({ path: join(SHOTS, 'app-lesson.png') });

await browser.close();
console.log(failures ? `${failures} failed` : 'all passed');
process.exit(failures ? 1 : 0);
