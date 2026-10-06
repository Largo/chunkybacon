// Lesson 39 in a browser: Spinel compiling in the page. The widgets are the
// shell's (html/shell/spinel.rb), the compiler and the runs are Ruby on
// PicoRuby.wasm in workers (html/spinel/), Spinel and clang the build in
// html/assets/spinel/ (node tools/build_spinel.mjs first).
//
//   BASE=http://127.0.0.1:8011/ node spinel_test.mjs     (~2 min)
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const manifest = await fetch(new URL('assets/spinel/manifest.json', BASE)).catch(() => null);
if (!manifest || !manifest.ok) {
  console.log('SKIP html/assets/spinel/ is not built there: node tools/build_spinel.mjs');
  process.exit(0);
}

const browser = await chromium.launch();
const page = await browser.newPage({ locale: 'en-US' });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') { errors.push(m.text()); console.log('[console.error]', m.text()); } });
page.on('pageerror', (e) => { errors.push(e.message); console.log('[pageerror]', e.message); });

let failures = 0;
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${detail && !cond ? ' - ' + detail : ''}`);
  if (!cond) failures++;
};

const out = (idx) => page.evaluate((i) => document.getElementById(`cell-out-${i}`).innerText, idx);
const until = (fn, arg, timeout = 90000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
const codeCells = () => page.$$eval('.run-cell', (buttons) => buttons.map((b) => b.getAttribute('data-idx')));

await page.goto(`${BASE}?lang=en#spinel`, { waitUntil: 'domcontentloaded' });
await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
check('the lesson opens', (await page.textContent('#lessonBody h2')).includes('Spinel'));
const [fib, cat, refusal, irbCell] = await codeCells();

// 1. a program: the steps, its output, the C, the module, CRuby beside it
await page.click(`.run-cell[data-idx="${fib}"]`);
check('fib: compiled and run',
      await until((i) => /CRuby prints exactly the same/.test(document.getElementById(`cell-out-${i}`).innerText), fib, 240000),
      await out(fib));
let text = await out(fib);
check('fib: the output', text.includes('832040'), text);
check('fib: three steps with times', /spinel: Ruby → C\s+\d+ ms/.test(text) && /clang: C → WebAssembly\s+[\d.]+ s/.test(text), text);
check('fib: the C to read', (await page.$eval(`#cell-out-${fib} .spinel-c pre`, (pre) => pre.textContent)).includes('sp_fib'));
const download = await page.$eval(`#cell-out-${fib} .spinel-download`, (a) => [a.getAttribute('download'), a.href]);
check('fib: main.wasm to download', download[0] === 'main.wasm' && download[1].startsWith('blob:'));
check('fib: no => line for the Program', !text.includes('#<Spinel::Program'));

// 2. a class: Spinel's types, the same output as CRuby
await page.click(`.run-cell[data-idx="${cat}"]`);
check('cat: same as CRuby',
      await until((i) => /CRuby prints exactly the same/.test(document.getElementById(`cell-out-${i}`).innerText), cat),
      await out(cat));
check('cat: the output', (await out(cat)).includes("I'm Mimi and 3 years old."));

// 3. what an AOT compiler cannot do: refused with the line, CRuby's answer beside it
await page.click(`.run-cell[data-idx="${refusal}"]`);
check('eval: refused', await until((i) => /CRuby runs it and prints/.test(document.getElementById(`cell-out-${i}`).innerText), refusal), await out(refusal));
text = await out(refusal);
check('eval: the line and the reason', /main\.rb:2: unsupported eval/.test(text), text);
check('eval: CRuby\'s 42', /CRuby runs it and prints:\s*42/.test(text), text);

// 4. IRB on Spinel
await page.click(`.run-cell[data-idx="${irbCell}"]`);
check('irb: ready', await until((i) => /Spinel .* is ready/.test(document.getElementById(`cell-out-${i}`).innerText), irbCell));
const history = () => page.$eval(`#cell-out-${irbCell} .spinel-term-history`, (h) => h.innerText);
const enter = async (line, expect, timeout = 90000) => {
  await page.fill(`#cell-out-${irbCell} .spinel-term-input`, line);
  await page.press(`#cell-out-${irbCell} .spinel-term-input`, 'Enter');
  return until(([i, re]) => new RegExp(re).test(document.querySelector(`#cell-out-${i} .spinel-term-history`).innerText), [irbCell, expect], timeout);
};
check('irb: a value', await enter('x = 6 * 7', '=> 42'), await history());
const prompt = () => page.$eval(`#cell-out-${irbCell} .spinel-term-prompt`, (p) => p.textContent);
await enter('def double(n)', 'def double\\(n\\)');
check('irb: an open def waits', await until((i) => document.querySelector(`#cell-out-${i} .spinel-term-prompt`).textContent === 'spinel(main):002:1*' &&
                                            !document.querySelector(`#cell-out-${i} .spinel-term-input`).disabled, irbCell, 10000), await prompt());
await enter('  n * 2', 'spinel\\(main\\):002:2\\*');
check('irb: the def answers its name', await enter('end', '=> :double'), await history());
check('irb: what a line prints, once', await enter('puts "twice: #{double(x)}"', 'twice: 84\\n=> nil'), await history());
check('irb: a syntax error without compiling', await enter('1 +* 2', '\\(irb\\):1:6: unexpected integer'), await history());
check('irb: a refusal', await enter('eval("x")', 'cannot compile this:\\n\\(irb\\):1: unsupported eval'), await history());
check('irb: an exception', await enter('raise "no"', 'no \\(RuntimeError\\)'), await history());
check('irb: the failed lines are not kept', await enter('[x, double(x)].sum', '=> 126'), await history());
check('irb: an endless loop is stopped', await enter('x = (x + 1) % 7 while true', 'Stopped after 10 s', 60000), await history());
check('irb: and the session goes on', await enter('x', '=> 42'), await history());

// 5. the exercise: CRuby's run is what the check reads
const exercise = await page.getAttribute('.cell.exercise .run-cell', 'data-idx');
await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [exercise,
  "spinel <<~'RUBY'\n  def collatz(n)\n    steps = 0\n    until n == 1\n      n = n.even? ? n / 2 : 3 * n + 1\n      steps += 1\n    end\n    steps\n  end\n\n  puts collatz(27)\nRUBY"]);
await page.click(`.run-cell[data-idx="${exercise}"]`);
check('exercise: passes', await until(() => document.querySelector('#chunkyChat').className.includes('celebrate') ||
                                       /Lesson 39 of 55/.test(document.getElementById('chunkyChat').innerText), null, 60000));
check('exercise: and Spinel agrees',
      await until((i) => /111/.test(document.getElementById(`cell-out-${i}`).innerText) &&
                         /CRuby prints exactly the same/.test(document.getElementById(`cell-out-${i}`).innerText), exercise),
      await out(exercise));

check('no console errors', errors.length === 0, errors.join(' | '));
await browser.close();
console.log(failures ? `${failures} FAILED` : 'all passed');
process.exit(failures ? 1 : 0);
