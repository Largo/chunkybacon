// Measures the music lesson in the real page (ruby.wasm in Chromium) without
// touching shared files: it pastes show_audio.rb into a cell (the widget as
// a run-time patch of the kernel), then runs every demo cell of lesson.json
// with ▶ and as a live run, checks the exercise's check, and times raw
// rendering. Writes page_results.json and a screenshot next to this file.
//
//   PORT=18105 ruby tools/dev_server.rb        (background, from the repo root)
//   PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/<hash>/node_modules/playwright \
//     node experiments/05-ruby-music/measure_in_page.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(pathToFileURL(join(process.env.PLAYWRIGHT_DIR, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18105/';
const LANG = process.env.LESSON_LANG || 'de';
const lesson = JSON.parse(readFileSync(join(HERE, 'lesson.json'), 'utf8'))[LANG];
const showAudio = readFileSync(join(HERE, 'show_audio.rb'), 'utf8');

const browser = await chromium.launch();
const page = await browser.newPage({ locale: 'de-DE', viewport: { width: 1200, height: 1400 } });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('console', m => { if (m.type() === 'error') console.log('[console.error]', m.text()); });

await page.goto(`${BASE}?lang=${LANG}#hallo`, { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
await page.evaluate(() => {
  window.__ran = [];
  window.addEventListener('chunky:ran', e => window.__ran.push(e.detail));
});

const out = idx => page.evaluate(i => document.getElementById(`cell-out-${i}`).textContent || '', idx);
const outHtml = idx => page.evaluate(i => document.getElementById(`cell-out-${i}`).innerHTML || '', idx);
const IDX = 1;

// ▶: code put in by the page (origin setValue) starts no live run
async function run(code) {
  const before = await page.evaluate(() => window.__ran.length);
  await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [IDX, code]);
  const t0 = Date.now();
  await page.click(`.run-cell[data-idx="${IDX}"]`);
  await page.waitForFunction(n => window.__ran.length > n, before, { timeout: 60000 });
  const wall = Date.now() - t0;
  const detail = await page.evaluate(() => window.__ran[window.__ran.length - 1]);
  return { ...detail, wall };
}

// a live run: typed code (origin +input), the shell runs it a second later
async function live(code) {
  await run('nil');   // a quick ▶ run clears the cell's slow mark (shell/app.rb LIVE_SLOW)
  const before = await page.evaluate(() => window.__ran.length);
  await page.evaluate(([i, text]) => {
    const cm = window.cellEditors[i];
    cm.replaceRange(text, { line: 0, ch: 0 }, { line: cm.lineCount(), ch: 0 }, '+input');
  }, [IDX, code]);
  await page.waitForFunction(n => window.__ran.length > n, before, { timeout: 60000 });
  return page.evaluate(() => window.__ran[window.__ran.length - 1]);
}

const results = { lang: LANG, cells: [], live: [], notes: [] };

const patch = await run(showAudio);
console.log('show_audio patch:', patch.outcome, (await out(IDX)).slice(0, 120));

const demos = lesson.cells.filter(c => c.t === 'c').map(c => c.code);
for (const [n, code] of demos.entries()) {
  const r = await run(code);
  const html = await outHtml(IDX);
  const audios = (html.match(/<audio/g) || []).length;
  const text = (await out(IDX)).replace(/\s+/g, ' ').slice(0, 90);
  results.cells.push({ cell: n + 1, outcome: r.outcome, elapsed_ms: Math.round(r.elapsed * 1000), wall_ms: r.wall, audios, text });
  console.log(`cell ${n + 1}: ${r.outcome} ${Math.round(r.elapsed * 1000)} ms (wall ${r.wall} ms), ${audios} <audio>  ${text}`);
  if (n === 3) await page.screenshot({ path: join(HERE, 'screenshot_melody.png'), clip: await page.evaluate(i => {
    const r = document.getElementById(`cell-out-${i}`).getBoundingClientRect();
    return { x: r.x, y: r.y + window.scrollY, width: Math.min(r.width, 700), height: r.height };
  }, IDX), fullPage: true });
  if (n === 1) {
    // the browser decodes the WAV: metadata of the <audio> under the cell
    const meta = await page.evaluate(i => new Promise(resolve => {
      const a = document.querySelector(`#cell-out-${i} audio`);
      const done = () => resolve({ duration: a.duration, readyState: a.readyState, error: a.error && a.error.code });
      if (a.readyState >= 1) done(); else { a.addEventListener('loadedmetadata', done); a.addEventListener('error', done); setTimeout(done, 5000); }
    }), IDX);
    results.audio_metadata = meta;
    console.log('audio metadata:', JSON.stringify(meta));
  }
}
await page.screenshot({ path: join(HERE, 'screenshot_song.png'), clip: await page.evaluate(i => {
  const r = document.getElementById(`cell-out-${i}`).getBoundingClientRect();
  return { x: r.x, y: r.y + window.scrollY, width: Math.min(r.width, 700), height: r.height };
}, IDX), fullPage: true });

// the same cells as live runs (autorun.rb: TracePoint, 1 s limit)
for (const [n, code] of demos.entries()) {
  const r = await live(code + `\n# live ${n}`);
  results.live.push({ cell: n + 1, outcome: r.outcome, elapsed_ms: Math.round(r.elapsed * 1000), own_ms: Math.round(r.own * 1000) });
  console.log(`live cell ${n + 1}: ${r.outcome} ${Math.round(r.elapsed * 1000)} ms`);
}

// the exercise check against a solution (the hallo lesson has its own
// exercise, so the check runs as plain code here)
const x = lesson.cells.find(c => c.t === 'x');
const name = LANG === 'de' ? 'tusch.wav' : 'fanfare.wav';
const solution = LANG === 'de'
  ? 'akkord = zusammen(*%w[C4 E4 G4 C5].map { |name| huelle(ton(frequenz(name), 1.0, :sinus, 0.2)) })\nFile.binwrite("tusch.wav", wav(noten("C4 E4 G4 C5") + akkord))'
  : 'chord = mix(*%w[C4 E4 G4 C5].map { |name| envelope(tone(frequency(name), 1.0, :sine, 0.2)) })\nFile.binwrite("fanfare.wav", wav(notes("C4 E4 G4 C5") + chord))';
const sol = await run(solution);
const chk = await run(`downloads = [${JSON.stringify(name)}]\nt0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)\nok = (${x.check})\n[ok, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round]`);
results.exercise = { solution_ms: Math.round(sol.elapsed * 1000), check: (await out(IDX)).trim() };
console.log('solution:', sol.outcome, Math.round(sol.elapsed * 1000), 'ms; check [ok, ms]:', results.exercise.check);

// raw speed: seconds of 22,050 Hz audio per second of computing
const bench = await run(`
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
r = {}
[1, 5].each do |secs|
  t0 = clock.()
  s = Array.new(22_050 * secs) { |i| 0.3 * Math.sin(2 * Math::PI * 440 * i / 22_050.0) }
  t1 = clock.()
  w = wav(s)
  t2 = clock.()
  svg = ChunkyApp.instance.waveform_svg(w)
  t3 = clock.()
  b64 = [w].pack("m0")
  t4 = clock.()
  r[secs] = { samples: ((t1 - t0) * 1000).round, wav: ((t2 - t1) * 1000).round, svg: ((t3 - t2) * 1000).round, base64: ((t4 - t3) * 1000).round, bytes: w.bytesize }
end
t0 = clock.()
n = noten("C4 D4 E4 F4 E4 D4 C4 - E4 F4 G4 A4 G4 F4 E4 -", laenge: 0.3) rescue notes("C4 D4 E4 F4 E4 D4 C4 - E4 F4 G4 A4 G4 F4 E4 -", length: 0.3)
r[:melody_4_8s] = ((clock.() - t0) * 1000).round
if defined?(ton)
  t0 = clock.(); x = ton(440, 1.0); t1 = clock.(); huelle(x); t2 = clock.(); zusammen(x, x, x); t3 = clock.()
  r[:one_second] = { ton: ((t1 - t0) * 1000).round, huelle: ((t2 - t1) * 1000).round, zusammen_3: ((t3 - t2) * 1000).round }
end
events = 0
tp = TracePoint.new(:line, :b_call, :c_call) { |t| events += 1; (events & 127).zero? && t.path && clock.() }
t0 = clock.()
tp.enable { Array.new(22_050) { |i| 0.5 * Math.sin(2 * Math::PI * 440 * i.fdiv(22_050)) } }
r[:sine_1s_traced] = { ms: ((clock.() - t0) * 1000).round, events: events }
t0 = clock.()
Array.new(22_050) { |i| 0.5 * Math.sin(2 * Math::PI * 440 * i.fdiv(22_050)) }
r[:sine_1s_plain] = ((clock.() - t0) * 1000).round
puts r.inspect   # the result line is cut short; output is not
nil`);
results.bench = (await out(IDX)).trim();
console.log('bench:', results.bench);

writeFileSync(join(HERE, `page_results_${LANG}.json`), JSON.stringify(results, null, 2) + '\n');
await browser.close();
