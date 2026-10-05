// Tries the JS/CSS parts of the proposed fixes on the live page, without
// changing html/: node verify_fixes.mjs (dev server on 18110)
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
await page.addScriptTag({ path: join(HERE, 'cm_escape_tab.js') });
await page.addStyleTag({ content: '.cell .CodeMirror-focused { outline: 3px solid var(--focus); outline-offset: -3px; }' });
await page.evaluate(() => Object.entries(window.cellEditors).forEach(([i, cm]) =>
  window.chunkyEditorKeys(cm, `Code, cell ${Number(i) + 1}`, 'Shift+Enter runs. Escape, then Tab, leaves the editor.')));

const focus = () => page.evaluate(() => {
  const a = document.activeElement;
  return a.closest('.CodeMirror') ? 'editor' : `${a.tagName.toLowerCase()}.${a.className.split(' ')[0]} "${a.textContent.trim()}"`;
});
await page.focus('#langSelect');
await page.keyboard.press('Tab');
const start = await focus();
const code0 = await page.evaluate(() => window.cellEditors[1].getValue());
await page.keyboard.press('Tab');
const afterTab = await focus();
const indented = await page.evaluate(() => window.cellEditors[1].getValue());
await page.keyboard.press('Control+z');
await page.keyboard.press('Escape');
await page.keyboard.press('Tab');
const afterEscTab = await focus();
await page.keyboard.press('Shift+Tab');   // back to Live? (the toolbar's first button is Live)
await page.keyboard.press('Shift+Tab');
const back = await focus();
await page.keyboard.press('Escape');
await page.keyboard.press('Shift+Tab');
const afterEscShiftTab = await focus();
const name = await page.evaluate(() => {
  const ta = window.cellEditors[1].getInputField();
  return { label: ta.getAttribute('aria-label'), described: document.getElementById(ta.getAttribute('aria-describedby')).textContent };
});
await page.focus('#langSelect');
await page.keyboard.press('Tab');
await (await page.$('.cell')).screenshot({ path: join(HERE, 'shots/fix-editor-focus-ring.png') });
console.log(JSON.stringify({ start, afterTab, indentedStill: indented !== code0, afterEscTab, back, afterEscShiftTab, name }, null, 1));
await browser.close();
