// Headless test for the embedded cell (html/embed.html, embed.js,
// embed-frame.js): one runnable cell on a page of another site.
//
//   FRAME_ANCESTORS="http://blog.test:*" PORT=8011 ruby tools/dev_server.rb   (background)
//   BASE=http://127.0.0.1:8011/ node embed_test.mjs
//
// Three made-up sites, all 127.0.0.1 (host-resolver rules): course.test is
// the course (the dev server at BASE's port), blog.test a blog post that
// embeds cells (a small server in this test), evil.test a site that may not
// frame them. The dev server must let blog.test frame embed.html
// (FRAME_ANCESTORS; its default is nginx's https://idogawa.com).
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';
import http from 'node:http';
import zlib from 'node:zlib';
import { readFileSync } from 'node:fs';

const BASE = new URL(process.env.BASE || 'http://127.0.0.1:8011/');
const COURSE = `http://course.test:${BASE.port || 80}/`;

let failures = 0;
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${detail ? ' - ' + detail : ''}`);
  if (!cond) failures++;
};

// the address of a cell, as embed.js and tools/make_embed_url.rb make it
// (deflate-raw, base64url without padding)
const embedUrl = (code, params = {}) => {
  const fragment = new URLSearchParams({ code: zlib.deflateRawSync(Buffer.from(code, 'utf8')).toString('base64url'), ...params });
  return `${COURSE}embed.html#${fragment}`;
};

const FIZZBUZZ = '(1..15).map do |n|\n  if n % 15 == 0 then "FizzBuzz"\n  elsif n % 3 == 0 then "Fizz"\n  elsif n % 5 == 0 then "Buzz"\n  else n\n  end\nend';
const PROBE = `require "js"
def peek
  yield
rescue Exception => e
  "blocked (#{e.message[0, 24]})"
end
{
  origin: JS.global[:origin].to_s,
  local_storage: peek { JS.global[:localStorage].getItem("chunky_done").to_s },
  indexed_db: peek { JS.global[:indexedDB].open("probe"); "open" }
}`;

// ---------- the other sites ----------
const pages = {
  // a blog post: <pre data-chunky> blocks and a hand-written iframe
  '/post.html': () => `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>A blog post with runnable Ruby</title>
<style>body { font: 17px/1.6 Georgia, serif; max-width: 42rem; margin: 2rem auto; } .spacer { height: 140vh; }</style>
</head><body>
  <h1>Ruby blocks, in five minutes</h1>
  <pre data-chunky>
    words = %w[chunky bacon is chunky]
    words.tally
  </pre>
  <pre data-chunky data-gems="chunky_png">
    require "chunky_png"

    image = ChunkyPNG::Image.new(16, 16, ChunkyPNG::Color::WHITE)
    16.times { |i| image[i, i] = image[15 - i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }
    show_image image
  </pre>
  <iframe id="handwritten" src="${embedUrl(FIZZBUZZ, { lang: 'en', load: 'click', id: 'handwritten' })}" title="Ruby code you can run"
    loading="lazy" sandbox="allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads"
    style="width:100%;border:0;height:246px"></iframe>
  <div class="spacer">(prose: the cell below is out of view)</div>
  <pre data-chunky id="probe">${PROBE.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</pre>
  <script src="${COURSE}embed.js"></script>
</body></html>`,
  // embed.js copied to the blog, pointed at the course by data-base
  '/based.html': () => `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Own copy</title></head>
<body><pre data-chunky data-load="click">1 + 1</pre><script src="/embed.js" data-base="${COURSE}"></script></body></html>`,
  '/embed.js': () => readFileSync(new URL('../html/embed.js', import.meta.url), 'utf8'),
  // a site the course does not allow to frame its cells
  '/frame.html': () => `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Not allowed</title></head>
<body><iframe id="cell" src="${embedUrl('1 + 1', { load: 'eager' })}" style="width:100%;height:200px"></iframe></body></html>`
};
const sites = http.createServer((req, res) => {
  const page = pages[req.url.split('?')[0]];
  const type = req.url.endsWith('.js') ? 'text/javascript' : 'text/html';
  res.writeHead(page ? 200 : 404, { 'Content-Type': `${type}; charset=utf-8` });
  res.end(page ? page() : 'not here');
});
await new Promise((resolve) => sites.listen(0, '127.0.0.1', resolve));
const SITES_PORT = sites.address().port;
const BLOG = `http://blog.test:${SITES_PORT}/`;
const EVIL = `http://evil.test:${SITES_PORT}/`;

const browser = await chromium.launch({
  args: ['--host-resolver-rules=MAP course.test 127.0.0.1, MAP blog.test 127.0.0.1, MAP evil.test 127.0.0.1']
});
const context = await browser.newContext({ viewport: { width: 900, height: 900 } });

// ---------- the course's headers (asked at BASE: Node resolves no .test) ----------
const head = await context.request.get(`${BASE}embed.html`);
const csp = head.headers()['content-security-policy'] || '';
check('embed.html comes sandboxed (CSP sandbox, no allow-same-origin)',
  csp.startsWith('sandbox allow-scripts ') && !csp.includes('allow-same-origin'), csp.slice(0, 90));
if (!/frame-ancestors [^;]*http:\/\/blog\.test/.test(csp)) {
  console.log(`FAIL the dev server must let blog.test frame embed.html: start it with FRAME_ANCESTORS="http://blog.test:*" (it sends: ${csp.match(/frame-ancestors [^;]*/)})`);
  process.exit(1);
}
const staticFile = await context.request.get(`${BASE}main.rb`);
check('static files may be read cross-origin (Access-Control-Allow-Origin: *)', staticFile.headers()['access-control-allow-origin'] === '*');

// the course's progress on course.test - what an embed on the same host
// must not be able to read
const course = await context.newPage();
await course.goto(`${COURSE}offline-files.txt`);
await course.evaluate(() => localStorage.setItem('chunky_done', '["hallo","methoden","klassen"]'));

// ---------- a blog post with cells ----------
const page = await context.newPage();
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
const wasm = [];
page.on('request', (r) => { if (r.url().includes('ruby+stdlib.wasm')) wasm.push(r.frame().url()); });
await page.goto(`${BLOG}post.html`);
await page.waitForFunction(() => document.querySelectorAll('pre[data-chunky]').length === 0, null, { timeout: 30000 });
check('embed.js turns the <pre data-chunky> blocks into iframes', (await page.$$('iframe[data-chunky-id^="chunky-"]')).length === 3);

async function frameOf(selector) {
  const handle = await page.waitForSelector(selector, { timeout: 30000 });
  for (let i = 0; i < 100; i++) {
    const frame = await handle.contentFrame();
    if (frame && frame.url().includes('embed.html')) return { handle, frame };
    await page.waitForTimeout(100);
  }
  throw new Error(`no frame for ${selector}`);
}
async function waitForResult(frame) {
  await frame.waitForFunction(() => {
    const out = document.getElementById('cell-out-0');
    return out && out.style.display !== 'none' && !document.getElementById('cell').classList.contains('running');
  }, null, { timeout: 180000 });
  return frame.$eval('#cell-out-0', (el) => el.innerText);
}
async function runAndWait(frame) {
  await frame.waitForSelector('#runBtn:not([disabled])');
  await frame.click('#runBtn');
  return waitForResult(frame);
}

const first = await frameOf("iframe[data-chunky-id='chunky-1']");
await first.frame.waitForSelector('.CodeMirror');
const shown = await first.frame.$eval('.CodeMirror', (el) => el.innerText);
check('the cell shows its code in the editor, its shared indentation gone',
  shown.includes('words.tally') && !shown.includes('    words'), shown.split('\n').slice(0, 2).join(' | '));
check('the embed runs in an opaque origin, though on the course\'s host', (await first.frame.evaluate(() => origin)) === 'null');
const input = await first.frame.$eval('.CodeMirror textarea', (el) => ({
  label: el.getAttribute('aria-label'),
  hint: (document.getElementById(el.getAttribute('aria-describedby') || '') || {}).textContent || ''
}));
check('the editor is named for screen readers, its hint says Shift+Enter and how to leave',
  input.label === 'Ruby code you can run' && input.hint.includes('Shift+Enter') && input.hint.includes('Escape'), JSON.stringify(input));

// ▶ by keyboard: the result, read out, and the focus back on ▶
await first.frame.waitForSelector('#runBtn:not([disabled])');
await first.frame.focus('#runBtn');
await first.frame.press('#runBtn', 'Enter');
const out1 = await waitForResult(first.frame);
check('Run gives the result', out1.includes('"chunky" => 2'), out1.trim());
await page.waitForTimeout(400);
const after = await first.frame.evaluate(() => ({
  focus: document.activeElement && document.activeElement.id,
  said: document.getElementById('runStatus').textContent,
  time: document.getElementById('runTime').textContent
}));
check('the focus stays on Run, and the result is read out', after.focus === 'runBtn' && after.said.startsWith('Ran: ') && after.said.includes('chunky'), JSON.stringify(after));
check('the run time is shown', /^(< )?\d+\.\d s$/.test(after.time), after.time);
const [frameH, docH] = await Promise.all([
  first.handle.evaluate((f) => f.getBoundingClientRect().height),
  first.frame.evaluate(() => Math.ceil(document.documentElement.getBoundingClientRect().height))
]);
check('the iframe follows the cell\'s height (postMessage)', Math.abs(frameH - docH) <= 1, `${frameH} vs ${docH}`);
check('the widgets\' scripts are there for the kernel (show_game, show_letter, processing)',
  await first.frame.evaluate(() => typeof window.chunkyGame === 'function' && typeof window.chunkyLetter === 'function'));

const png = await frameOf("iframe[data-chunky-id='chunky-2']");
await png.handle.scrollIntoViewIfNeeded();
const out2 = await runAndWait(png.frame);
check('data-gems="chunky_png" installs from the course\'s gem cache, show_image draws',
  Boolean(await png.frame.$('#cell-out-0 img.cell-image')), out2.trim().slice(0, 80));

const hand = await frameOf('#handwritten');
await hand.handle.scrollIntoViewIfNeeded();
await hand.frame.waitForSelector('.CodeMirror');
await page.waitForTimeout(1500);
check('load=click: no ruby.wasm before Run', wasm.filter((u) => u.includes('load=click')).length === 0);
const out3 = await runAndWait(hand.frame);
check('load=click: Run loads Ruby and runs', out3.includes('"FizzBuzz"'), out3.trim().slice(0, 60));

const probe = await frameOf("iframe[data-chunky-id='chunky-3']");
const before = wasm.length;
await page.waitForTimeout(1500);
check('load=visible: a cell out of view loads no Ruby', wasm.length === before);
await probe.handle.scrollIntoViewIfNeeded();
const out4 = (await runAndWait(probe.frame)).replace(/\s+/g, ' ');
check('embedded code cannot read the course\'s storage on the same host',
  out4.includes('local_storage: "blocked') && out4.includes('indexed_db: "blocked') && !out4.includes('methoden'), out4.slice(0, 240));
check('no console errors on the blog post', errors.length === 0, errors.slice(0, 3).join(' | '));

// ---------- the other ways in ----------
// a plain link (a README's "▶ Run"): the cell as a page of its own
const alone = await context.newPage();
// A sandboxed page sends no Referer, so the bridges refuse it like any other
// site's page (403 without CORS: status 0 here); gems come from the cache.
const ALONE = 'require "js"\nbridge = JSON.parse(JS.global.fetchHttpSync("/rubygems/api/v1/gems/rake.json").to_s)["status"]\n"alone #{1 + 1}, bridge #{bridge}"';
await alone.goto(embedUrl(ALONE, { run: '1', lang: 'de' }));
const out5 = await waitForResult(alone);
check('a link opens the cell as a page of its own, sandboxed, and runs it',
  out5.includes('alone 2') && (await alone.evaluate(() => origin)) === 'null' && (await alone.getAttribute('html', 'lang')) === 'de', out5.trim());
check('the bridges do not serve the embed (a sandboxed page sends no Referer)', out5.includes('bridge 0'), out5.trim());

// embed.js from the blog's own copy, with data-base: the cells still come
// from the course
const based = await context.newPage();
await based.goto(`${BLOG}based.html`);
const basedSrc = await (await based.waitForSelector('iframe[data-chunky-id]', { timeout: 30000 })).getAttribute('src');
check('data-base on the script tag points the cells at the course', basedSrc.startsWith(`${COURSE}embed.html#code=`), basedSrc.slice(0, 50));

// a site the course does not allow to frame it
const evil = await context.newPage();
await evil.goto(`${EVIL}frame.html`);
await evil.waitForTimeout(2000);
const evilFrame = await (await evil.$('#cell')).contentFrame();
const evilCell = evilFrame ? await evilFrame.$('#runBtn').catch(() => null) : null;
check('another site cannot frame the cell (frame-ancestors)', !evilCell, evilFrame ? evilFrame.url().slice(0, 60) : 'no frame');

// the page without its sandbox header (a misconfigured server): it runs
// nothing. Every course.test file comes through the route (fetched at BASE:
// Node resolves no .test), as Chrome would block a fulfilled page's
// requests to loopback (Private Network Access).
const bare = await context.newPage();
await bare.route(`${COURSE}**`, async (route) => {
  const response = await route.fetch({ url: route.request().url().replace(COURSE, BASE.href) });
  const headers = { ...response.headers() };
  delete headers['content-security-policy'];
  delete headers['content-encoding'];   // route.fetch hands over the body unpacked
  delete headers['content-length'];
  await route.fulfill({ response, headers });
});
const bareWasm = [];
bare.on('request', (r) => { if (r.url().includes('ruby+stdlib.wasm') || r.url().includes('browser.script')) bareWasm.push(r.url()); });
await bare.goto(embedUrl('1 + 1', { run: '1', lang: 'en' }));
await bare.waitForTimeout(2000);
const bareState = await bare.evaluate(() => ({ origin, status: document.getElementById('embedStatus').textContent }));
check('without its sandbox header the cell runs nothing, and says so',
  bareState.origin !== 'null' && bareState.status.includes('sandboxed') && bareWasm.length === 0, JSON.stringify(bareState));

await browser.close();
sites.close();
console.log(failures === 0 ? 'ALL EMBED TESTS OK' : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
