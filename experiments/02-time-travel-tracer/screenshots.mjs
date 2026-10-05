// Screenshots of scrubber.html (from file://) at interesting steps, into
// shots/. Also drives the controls once to check they move the step.
//   PLAYWRIGHT_DIR=.../node_modules/playwright node screenshots.mjs
import { mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(pathToFileURL(join(process.env.PLAYWRIGHT_DIR, 'index.mjs')).href);
mkdirSync(join(here, 'shots'), { recursive: true });
const url = pathToFileURL(join(here, 'scrubber.html')).href;

const shots = [
  ['schleifen-times', 2, 'de'],
  ['schleifen-while', 8, 'de'],
  ['arrays-each', 3, 'de'],
  ['methoden-map', 11, 'de'],
  ['rekursion', 12, 'de'],
  ['fehler', 6, 'de'],
  ['lang', 600, 'de'],
  ['methoden-map', 7, 'en'],
  ['schleifen-times', 3, 'ja']
];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1100, height: 760 }, deviceScaleFactor: 1 });
page.on('pageerror', e => console.log('[pageerror]', e.message));
for (const [id, step, lang] of shots) {
  await page.goto(`${url}?sample=${id}&step=${step}&lang=${lang}`);
  await page.waitForTimeout(150);
  const file = join(here, 'shots', `${id}-${step}-${lang}.png`);
  await page.locator('.cell').screenshot({ path: file });
  console.log('shot', file.replace(here, '.'), '-', await page.textContent('#say'));
}

// the controls: next, slider, keys
await page.goto(`${url}?sample=methoden-map&step=0`);
await page.click('#next');
await page.click('#next');
const afterClicks = await page.textContent('#count');
await page.keyboard.press('End');
const afterEnd = await page.textContent('#count');
await page.keyboard.press('ArrowLeft');
const afterLeft = await page.textContent('#count');
console.log('controls:', afterClicks, '|', afterEnd, '|', afterLeft);
await browser.close();
