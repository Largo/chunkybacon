// Playwright for the audit scripts: the copy in PLAYWRIGHT_DIR if set (e.g. an
// npx cache folder .../node_modules/playwright), else import('playwright').
// It is not in package.json, so npm ci here only brings axe-core.
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';

const PW = process.env.PLAYWRIGHT_DIR;
let pw;
try {
  pw = await import(PW ? pathToFileURL(join(PW, 'index.mjs')).href : 'playwright');
} catch (e) {
  console.error(`Playwright not found (${PW ? `PLAYWRIGHT_DIR=${PW}` : "import('playwright')"}): ${e.message.split('\n')[0]}\n` +
    'Set PLAYWRIGHT_DIR to a playwright package folder, or install playwright where Node resolves it ' +
    '(then: npx playwright install chromium).');
  process.exit(1);
}
export const { chromium } = pw;
