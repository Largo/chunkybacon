// Renders the social cards from docs/social/card.html, with the current
// lesson count from html/lessons.js:
//   docs/social/twitter-card.png  1600x900 (16:9)  X, Bluesky, Mastodon, the README
//   docs/social/github-social.png 1600x800 (2:1)   GitHub social preview, og:image
// The page is served from the repo through Playwright's request routing
// (file:// would block the fonts), so nothing listens on a port.
//
//   node tools/render_social_cards.mjs
//   (locally: PLAYWRIGHT_DIR=... node --import ./tmp/playwright_redirect.mjs tools/render_social_cards.mjs)
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';
import { existsSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ORIGIN = 'http://card.local';
const FORMATS = [
  { file: 'twitter-card.png', width: 1600, height: 900, query: '' },
  { file: 'github-social.png', width: 1600, height: 800, query: '&format=github' },
];

globalThis.window = {};
createRequire(import.meta.url)(path.join(ROOT, 'html/lessons.js'));
const lessons = JSON.parse(globalThis.window.LESSONS_JSON).lessons.length;

const browser = await chromium.launch();
for (const format of FORMATS) {
  const page = await browser.newPage({ viewport: { width: format.width, height: format.height }, deviceScaleFactor: 1 });
  await page.route(`${ORIGIN}/**`, (route) => {
    const file = path.join(ROOT, decodeURIComponent(new URL(route.request().url()).pathname));
    if (!file.startsWith(ROOT + path.sep) || !existsSync(file)) return route.fulfill({ status: 404 });
    return route.fulfill({ path: file });
  });
  await page.goto(`${ORIGIN}/docs/social/card.html?lessons=${lessons}${format.query}`);
  await page.evaluate(() => document.fonts.ready);
  const missing = await page.evaluate(() =>
    ['Shantell Sans', 'Atkinson Hyperlegible Next', 'Atkinson Hyperlegible Mono']
      .filter((f) => !document.fonts.check(`700 20px "${f}"`)));
  if (missing.length) throw new Error(`fonts not loaded: ${missing.join(', ')}`);
  const out = path.join(ROOT, 'docs/social', format.file);
  await page.screenshot({ path: out, type: 'png' });
  await page.close();
  console.log(`wrote docs/social/${format.file} (${format.width}x${format.height}, ${Math.round(statSync(out).size / 1024)} KB)`);
}
await browser.close();
console.log(`${lessons} lessons`);
