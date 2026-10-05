// Screenshots of what keyboard focus looks like: an editor reached by Tab,
// a run button, and a cell while it runs. node focus_shots.mjs
import { pathToFileURL, fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));
const PW = process.env.PLAYWRIGHT_DIR ||
  join(homedir(), 'AppData/Local/npm-cache/_npx/e41f203b7505f1fb/node_modules/playwright');
const { chromium } = await import(pathToFileURL(join(PW, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18110/';

const browser = await chromium.launch();
const page = await browser.newPage({ locale: 'en-US', viewport: { width: 1280, height: 900 } });
await page.goto(`${BASE}?lang=en#hallo`, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 180000 });
// Tab from the language select into the first editor, as a keyboard user would
await page.focus('#langSelect');
await page.keyboard.press('Tab');
const cell = await page.$('.cell');
await cell.screenshot({ path: join(HERE, 'shots/en-editor-keyboard-focus.png') });
const ring = await page.evaluate(() => {
  const cm = document.querySelector('.CodeMirror-focused');
  const ta = document.activeElement;
  return { cmOutline: cm && getComputedStyle(cm).outlineStyle, textareaOutline: getComputedStyle(ta).outlineStyle, textareaBox: ta.getBoundingClientRect().width + 'x' + ta.getBoundingClientRect().height };
});
console.log('editor focus:', JSON.stringify(ring));
await page.keyboard.press('Shift+Tab');
await page.keyboard.press('Shift+Tab');
await page.focus('.run-cell[data-idx="1"]');
await (await page.$('.cell')).screenshot({ path: join(HERE, 'shots/en-run-button-focus.png') });
await browser.close();
