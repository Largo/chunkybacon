// Headless test for the embedded cell (html/embed.html, embed.js,
// embed-frame.js): one runnable cell on a page of another site.
//
//   FRAME_ANCESTORS="http://blog.test:*" PORT=8011 ruby tools/dev_server.rb   (background)
//   BASE=http://127.0.0.1:8011/ node embed_test.mjs
//
// The IronRuby cell (engine=ironruby) needs html/assets/ironruby/
// (tools/vendor_ironruby.rb).
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

// an IronRuby cell: .NET's DateTime, QRCoder's PNG (show_png), the engine
const IRONRUBY = `now = System::DateTime.now
puts "year ok: #{now.Year >= 2025}"
gen = QRCoder::QRCodeGenerator.new
data = gen.CreateQrCode("https://idogawa.com", QRCoder::QRCodeGenerator::ECCLevel.M)
show_png QRCoder::PngByteQRCode.new(data).get_graphic(8)
"#{RUBY_ENGINE} on .NET #{System::Environment.Version}"`;

// long lines: at a phone's width the editor wraps them (with a hanging
// indent), and the plain text before it must wrap the same way
const NARROW = `# 日本語のコメント: 長い行は折り返されます。エディターが読み込まれる前も同じように。
words = %w[chunky bacon is chunky and the foxes love chunky bacon more than anything else]
counts = words.tally.sort_by { |word, count| [-count, word] }.map { |word, count| "#{word}: #{count}" }
counts.first(3).join(", ")`;

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
  // a phone's narrow column, long lines that wrap (and Japanese text)
  '/narrow.html': () => `<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width">
<title>Narrow</title><style>body { margin: 0 16px; }</style></head>
<body><pre data-chunky data-load="click">${NARROW.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</pre>
<script src="${COURSE}embed.js"></script></body></html>`,
  '/based.html': () => `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>Own copy</title></head>
<body><pre data-chunky data-load="click">1 + 1</pre><script src="/embed.js" data-base="${COURSE}"></script></body></html>`,
  '/embed.js': () => readFileSync(new URL('../html/embed.js', import.meta.url), 'utf8'),
  // a post with an IronRuby cell (data-engine="ironruby"): .NET from the
  // course, in a worker the opaque-origin frame starts from a blob: URL
  '/dotnet.html': () => `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>IronRuby on .NET</title></head>
<body><pre data-chunky data-engine="ironruby">${IRONRUBY.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</pre>
<script src="${COURSE}embed.js"></script></body></html>`,
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
// (the hand-written iframe gets a chunky-N id too once it talks: not counted)
check('embed.js turns the <pre data-chunky> blocks into iframes', (await page.$$('iframe[data-chunky-id^="chunky-"]:not(#handwritten)')).length === 3);

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
// another child frame on the blog (an ad, a video) that sends embed.js the
// embed's messages: ignored - no size, no id of its choosing, and a timing
// keyed "__proto__" does not reach the blog's Object.prototype. Sandboxed,
// so it has an opaque origin like a real cell: only the source window tells
// them apart. Its last message is a marker; messages arrive in order, so
// when the marker is here embed.js has seen (and ignored) the two before it
const stranger = await page.evaluate(() => new Promise((done) => {
  const frame = document.createElement('iframe');
  frame.id = 'stranger';
  frame.setAttribute('sandbox', 'allow-scripts');
  frame.style.height = '150px';
  const result = (sent) => ({ sent, polluted: ({}).polluted, height: frame.style.height, id: frame.dataset.chunkyId || null });
  const timeout = setTimeout(() => done(result(false)), 10000);
  window.addEventListener('message', function marker(event) {
    if (event.source !== frame.contentWindow || !event.data || !event.data.strangerDone) return;
    window.removeEventListener('message', marker);
    clearTimeout(timeout);
    setTimeout(() => done(result(true)), 0);
  });
  frame.srcdoc = '<script>parent.postMessage({ chunkyEmbed: "timing", id: "__proto__", name: "polluted", ms: 1 }, "*");' +
    'parent.postMessage({ chunkyEmbed: "size", height: 5 }, "*");' +
    'parent.postMessage({ strangerDone: true }, "*");</' + 'script>';
  document.body.appendChild(frame);
}));
check('a child frame that is not a cell is ignored (no size, no id, no prototype pollution)',
  stranger.sent && stranger.polluted === undefined && stranger.height === '150px' && stranger.id === null, JSON.stringify(stranger));
check('no console errors on the blog post', errors.length === 0, errors.slice(0, 3).join(' | '));

// ---------- an IronRuby cell (engine=ironruby; HANDOVER §6s, §6k) ----------
// Needs html/assets/ironruby/ (tools/vendor_ironruby.rb); about 20 MB.
const dotnet = await context.newPage();
const dotnetErrors = [];
dotnet.on('console', (m) => { if (m.type() === 'error') dotnetErrors.push(m.text()); });
const dotnetFiles = [];
dotnet.on('request', (r) => { if (/ironruby_worker\.js|assets\/ironruby\//.test(r.url())) dotnetFiles.push(r.url()); });
// ironruby_lab.js arrives well after CRuby is up (about 2 s): the run
// clicked meanwhile must wait for its controller, not fail without one
await dotnet.route('**/ironruby_lab.js', async (route) => {
  await new Promise((resolve) => setTimeout(resolve, 6000));
  await route.continue();
});
await dotnet.goto(`${BLOG}dotnet.html`);
const irHandle = await dotnet.waitForSelector('iframe[data-chunky-id]', { timeout: 30000 });
check('data-engine="ironruby" goes into the address', (await irHandle.getAttribute('src')).includes('engine=ironruby'));
let irFrame = null;
for (let i = 0; i < 100 && !(irFrame && irFrame.url().includes('embed.html')); i++) {
  irFrame = await irHandle.contentFrame();
  await dotnet.waitForTimeout(100);
}
await irFrame.waitForSelector('.CodeMirror');
await dotnet.waitForTimeout(1500);
check('an IronRuby cell loads no .NET before Run (load=click is its default)', dotnetFiles.length === 0, dotnetFiles.slice(0, 2).join(' '));
await irFrame.waitForSelector('#runBtn:not([disabled])');
await irFrame.click('#runBtn');
const irOut = await waitForResult(irFrame);
const irState = await irFrame.evaluate(() => {
  const img = document.querySelector('#cell-out-0 img.ironruby-png');
  return { origin, png: img ? atob(img.src.split(',')[1]).slice(1, 4) : '', width: img ? img.naturalWidth : 0,
           status: (document.querySelector('.ironruby-status') || {}).textContent || '',
           state: (document.querySelector('.ironruby-status') || { getAttribute: () => '' }).getAttribute('data-state') };
});
check('an IronRuby cell runs on .NET in the embed (its controller late): DateTime, a QRCoder PNG, RUBY_ENGINE',
  irOut.includes('year ok: true') && irOut.includes('ironruby on .NET 10') && irState.png === 'PNG' && irState.width > 100,
  `${irOut.replace(/\s+/g, ' ').trim().slice(0, 120)} ${JSON.stringify(irState)}`);
check('the IronRuby cell is still sandboxed (opaque origin), its worker from the course\'s host',
  irState.origin === 'null' && dotnetFiles.some((u) => u.startsWith(`${COURSE}ironruby_worker.js`)) &&
  dotnetFiles.some((u) => u.startsWith(`${COURSE}assets/ironruby/`)));
check('IronRuby says it is ready below the cell', irState.state === 'ready' && irState.status.startsWith('IronRuby is ready'), irState.status);
// a second run uses the same worker: the variables of the first are there
await irFrame.evaluate(() => window.setCellCode(0, 'gen.class.name'));
const irOut2 = await runAndWait(irFrame);
check('a second run keeps the first one\'s variables (one IronRuby worker)', irOut2.includes('QRCoder.QRCodeGenerator') || irOut2.includes('QRCoder::QRCodeGenerator'), irOut2.trim());
check('no console errors around the IronRuby cell', dotnetErrors.length === 0, dotnetErrors.slice(0, 3).join(' | '));

// ---------- a phone: the cell keeps its height when the editor arrives ----------
// The plain text before CodeMirror wraps as the editor does (embed.css,
// embed-frame.js showPlain), so ▶ does not move under a finger: a tap
// before the editor has loaded runs the cell. At 375px the frame used to
// grow by half its height when the editor took over, and a click at that
// moment hit nothing. embed.js's first guess at the height counts the
// wrapped rows too.
{
  const phone = await browser.newContext({ viewport: { width: 375, height: 800 } });
  const narrow = await phone.newPage();
  const narrowErrors = [];
  narrow.on('console', (m) => { if (m.type() === 'error') narrowErrors.push(m.text()); });
  let releaseEditor;
  const editorHeld = new Promise((resolve) => { releaseEditor = resolve; });
  await narrow.route('**/assets/codemirror.js', async (route) => { await editorHeld; await route.continue(); });
  await narrow.goto(`${BLOG}narrow.html`);
  const handle = await narrow.waitForSelector('iframe[data-chunky-id]', { timeout: 30000 });
  let cell = null;
  for (let i = 0; i < 100 && !(cell && cell.url().includes('embed.html')); i++) {
    cell = await handle.contentFrame();
    await narrow.waitForTimeout(100);
  }
  await cell.waitForSelector('.embed-plain-line');
  await narrow.waitForTimeout(500);   // the size message, the fonts
  // the frame's height, and the toolbar's place (▶ is in it; after the
  // click it also says "Loading Ruby", so the frame may grow below it)
  const size = () => Promise.all([
    handle.evaluate((f) => Math.round(f.getBoundingClientRect().height)),
    cell.evaluate(() => Math.round(document.querySelector('.cell-toolbar').getBoundingClientRect().top))
  ]);
  const [plainHeight, plainRun] = await size();
  const guess = await narrow.evaluate(([code, frame]) => window.ChunkyEmbed.estimateHeight(code, frame),
    [NARROW, await handle.evaluate((f) => f.getBoundingClientRect().width)]);
  check('embed.js guesses the wrapped cell\'s height at a phone\'s width (within a row)',
    Math.abs(guess - plainHeight) <= 25, `${guess} vs ${plainHeight}`);
  // ▶ while the code is still plain text: it must run
  await cell.click('#runBtn');
  const ranEarly = await cell.evaluate(() => document.getElementById('cell').classList.contains('running') ||
    document.getElementById('cell-out-0').style.display !== 'none');
  releaseEditor();
  await cell.waitForSelector('.CodeMirror');
  await narrow.waitForTimeout(500);
  const [, editorRun] = await size();
  check('at a phone\'s width ▶ keeps its place when the editor takes over (the code wraps alike)',
    Math.abs(editorRun - plainRun) <= 2, `toolbar at ${plainRun} -> ${editorRun}`);
  const outNarrow = await waitForResult(cell);
  check('▶ tapped before the editor has loaded runs the cell', ranEarly && outNarrow.includes('"chunky: 3, bacon: 2, and: 1"'), outNarrow.trim());
  check('no console errors on the narrow page', narrowErrors.length === 0, narrowErrors.slice(0, 3).join(' | '));
  await phone.close();
}

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
