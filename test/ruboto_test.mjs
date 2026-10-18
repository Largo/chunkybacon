// Headless test for the Ruboto lesson ("engine": "jruby", "android": true;
// docs/HANDOVER.md §6u): its cells run on JRuby (TeaVM) in the JRuby lesson's
// worker, with the simulated phone (ruboto_sim/) loaded into it, and
// ruboto_phone.js draws the phone below a cell that starts an app. Checks: no
// phone for other lessons, every demo app (taps, a toast, a rotation that
// recreates the activity, logcat, Home and the launcher, a list with a
// dialog and a menu, the photo frame's timer and its second activity, Back),
// an older phone going stale, a crash and its dialog, an onCreate without
// super, the exercise (starter fails, a solution passes), and the German
// lesson. Needs html/assets/jruby/ (tools/vendor_jruby.rb). About a minute.
//   BASE=http://127.0.0.1:18011/ node test/ruboto_test.mjs
import { chromium } from '/usr/local/lib/node_modules/playwright/index.mjs';

const BASE = process.env.BASE || 'http://127.0.0.1:8011/';
const browser = await chromium.launch();
let failures = 0;
const check = (name, cond) => { console.log(`${cond ? 'PASS' : 'FAIL'} ${name}`); if (!cond) failures++; };
const errors = [];

async function open(ctx, hash) {
  const page = await ctx.newPage();
  page.on('pageerror', e => { errors.push(e.message); console.log('[pageerror]', e.message); });
  page.on('console', m => {
    // the course's known 404 (/compile/toolchain/ready.json) is a resource error without a URL here
    if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) { errors.push(m.text()); console.log('  [console.error]', m.text().slice(0, 200)); }
  });
  await page.goto(BASE + hash, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('#app', { state: 'visible', timeout: 120000 });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  return page;
}
async function run(page, idx, text) {
  if (text !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, text]);
  await page.evaluate(() => { window.__ran = null; window.addEventListener('chunky:ran', e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(() => window.__ran, null, { timeout: 90000 });
  return page.evaluate(i => document.getElementById('cell-out-' + i).innerText, idx);
}
// the worker has answered every tap so far
const settle = page => page.waitForFunction(() => !window.chunkyJRuby.busy(), null, { timeout: 30000 });
const tap = async (page, selector) => { await page.click(selector); await settle(page); };
const screen = (page, idx) => page.evaluate(i => {
  const s = document.querySelector('#ruboto-slot-' + i + ' .rp-body');
  return s ? s.innerText : '';
}, idx);
const logcat = (page, idx) => page.evaluate(i => document.querySelector('#ruboto-slot-' + i + ' .rp-logcat-lines').innerText, idx);
const cellIndex = (page, pattern) => page.evaluate(src => {
  const re = new RegExp(src);
  return Object.keys(window.cellEditors).map(Number).find(i => re.test(window.cellEditors[i].getValue()));
}, pattern.source);

// ---------- another lesson: no phone ----------
{
  const ctx = await browser.newContext({ locale: 'en-US' });
  const page = await open(ctx, '#jruby');
  await page.waitForTimeout(1000);
  check('the JRuby lesson loads no phone', await page.evaluate(() => !document.getElementById('rubotoPhoneScript')));
  await ctx.close();
}

const ctx = await browser.newContext({ locale: 'en-US', viewport: { width: 1280, height: 1000 } });
const page = await open(ctx, '#ruboto');
check('the lesson loads the phone script', await page.evaluate(() => !!document.getElementById('rubotoPhoneScript')));

const build = await run(page, 1);
check('android.os.Build answers from the simulated phone', /Chunky Phone \(simulated\)", "14", 34/.test(build));
check('the status line says JRuby is ready', /JRuby/.test(await page.textContent('.jruby-status')));

// Hello
const hello = await cellIndex(page, /class HelloActivity/);
await run(page, hello);
check('a cell with an activity gets a phone', await page.$('#ruboto-slot-' + hello) !== null);
check('...showing its title and text', /Hello[\s\S]*Chunky bacon!/.test(await screen(page, hello)));
check('...without the class body\'s => value', !/=>/.test(await page.evaluate(i => document.getElementById('cell-out-' + i).innerText, hello)));
await tap(page, `#ruboto-slot-${hello} .rp-nav-home`);
check('Home shows the launcher with the app', await page.$(`#ruboto-slot-${hello} .rp-app-icon`) !== null);
await tap(page, `#ruboto-slot-${hello} .rp-app-icon`);
check('the launcher starts the app again', /Chunky bacon!/.test(await screen(page, hello)));

// Ruboto's sample
const sample = await cellIndex(page, /class SampleActivity/);
await run(page, sample);
check('the older phone goes stale', await page.evaluate(i => document.getElementById('ruboto-slot-' + i).classList.contains('is-stale'), hello));
await tap(page, `#ruboto-slot-${sample} .rp-button`);
check('a tap runs the proc: the text changes', /What hath Matz wrought!/.test(await screen(page, sample)));
check('...and a toast comes up', /Flipped a bit via butterfly/.test(await page.textContent(`#ruboto-slot-${sample} .rp-toasts`)));
await tap(page, `#ruboto-slot-${sample} .rp-rotate`);
check('a rotation makes a new activity: the text is back', /What hath Matz wrought\?/.test(await screen(page, sample)));
check('...in landscape', await page.$(`#ruboto-slot-${sample} .rp-device.is-landscape`) !== null);

// the lifecycle
const life = await cellIndex(page, /class LifeActivity/);
await run(page, life);
check('a new app starts upright', await page.$(`#ruboto-slot-${life} .rp-device.is-portrait`) !== null);
check('...with a log of its own', !/Matz/.test(await logcat(page, life)) && /onCreate, bundle: nil/.test(await logcat(page, life)));
await tap(page, `#ruboto-slot-${life} .rp-button`);
await tap(page, `#ruboto-slot-${life} .rp-button`);
await tap(page, `#ruboto-slot-${life} .rp-rotate`);
const lifelog = await logcat(page, life);
check('logcat shows the rotation in order',
      /onPause[\s\S]*onSaveInstanceState: 2 taps[\s\S]*onStop[\s\S]*onDestroy[\s\S]*onCreate, bundle: Bundle\[\{taps=2\}\]/.test(lifelog));
check('...and the taps survive it', /2 taps/.test(await screen(page, life)));
await tap(page, `#ruboto-slot-${life} .rp-nav-back`);
check('Back ends the activity: onDestroy, the home screen', /onDestroy\s*$/.test(await logcat(page, life)) && await page.$(`#ruboto-slot-${life} .rp-app-icon`) !== null);
await tap(page, `#ruboto-slot-${life} .rp-app-icon`);
check('...and the next start has no bundle', /0 taps/.test(await screen(page, life)));

// the shopping list
const shop = await cellIndex(page, /class ShoppingActivity/);
await run(page, shop);
await page.fill(`#ruboto-slot-${shop} .rp-edit`, 'Toast');
await page.waitForTimeout(350);
await settle(page);
await tap(page, `#ruboto-slot-${shop} .rp-button`);
check('typing and Add put an item into the list', /Toast/.test(await page.textContent(`#ruboto-slot-${shop} .rp-list`)));
check('...and the field is empty again', await page.inputValue(`#ruboto-slot-${shop} .rp-edit`) === '');
await tap(page, `#ruboto-slot-${shop} .rp-row >> nth=1`);
check('a tap on an item opens the AlertDialog', /eggs[\s\S]*Got it\?/.test(await page.textContent(`#ruboto-slot-${shop} .rp-dialog`)));
await tap(page, `#ruboto-slot-${shop} .rp-dialog-button >> text=Remove`);
check('...whose Remove takes it off', !/eggs/.test(await page.textContent(`#ruboto-slot-${shop} .rp-list`)) && await page.$(`#ruboto-slot-${shop} .rp-dialog`) === null);
await page.click(`#ruboto-slot-${shop} .rp-more`);
await tap(page, `#ruboto-slot-${shop} .rp-menu-item >> text=Sort`);
check('the menu sorts the list', (await page.$$eval(`#ruboto-slot-${shop} .rp-row`, rows => rows.map(r => r.textContent))).join(' ') === 'Bacon Coffee Toast');

// the photo frame
const frame = await cellIndex(page, /class PhotoFrameActivity/);
await run(page, frame);
const caption = () => page.textContent(`#ruboto-slot-${frame} .rp-text`);
const photo = () => page.getAttribute(`#ruboto-slot-${frame} .rp-image img`, 'alt');
check('the photo frame shows the first photo', await photo() === 'earthrise' && /Earthrise/.test(await caption()));
await page.waitForTimeout(4600);
await settle(page);
check('the Handler moves on after 4 seconds', await photo() === 'blue_marble');
await tap(page, `#ruboto-slot-${frame} .rp-button >> text=Next`);
check('Next moves on at once', await photo() === 'moonwalk');
await tap(page, `#ruboto-slot-${frame} .rp-image`);
check('a tap on the photo starts the second activity', /Photo 3 of 6/.test(await screen(page, frame)));
await tap(page, `#ruboto-slot-${frame} .rp-nav-back`);
check('Back returns to the frame, on the same photo', /Photo frame/.test(await screen(page, frame)) && await photo() === 'moonwalk');
await tap(page, `#ruboto-slot-${frame} .rp-rotate`);
check('the photo survives a rotation (onSaveInstanceState)', await photo() === 'moonwalk');
check('...and its timer is due in about 4 s', await page.evaluate(() => window.chunkyRubotoPhone.debug().state.device.nextTimer) > 3000);

// a crash, and onCreate without super
const boom = 'require "ruboto/widget"\nruboto_import_widgets :Button\n\nclass BoomActivity\n  def onCreate(bundle)\n    super\n' +
             '    self.content_view = button text: "Boom", on_click_listener: proc { 1 / 0 }\n  end\nend\n';
await run(page, frame, boom);
await tap(page, `#ruboto-slot-${frame} .rp-button`);
check('an exception in a click shows "has stopped"', /Boom has stopped/.test(await screen(page, frame)));
check('...and logcat FATAL EXCEPTION', /FATAL EXCEPTION[\s\S]*ZeroDivisionError/.test(await logcat(page, frame)));
await tap(page, `#ruboto-slot-${frame} .rp-dialog-item >> nth=0`);
check('"Open app again" starts it again', /Boom/.test(await screen(page, frame)) && !/has stopped/.test(await screen(page, frame)));
const lazy = await run(page, frame, 'class LazyActivity\n  def onCreate(bundle)\n    set_title "no super"\n  end\nend\n');
check('onCreate without super: SuperNotCalledException in the cell', /SuperNotCalledException[\s\S]*super\.onCreate/.test(lazy));
check('...with the line of the def marked', await page.evaluate(i => {
  const ed = window.cellEditors[i];
  return ed.getAllMarks().some(m => m.className === 'marker' && m.find().from.line === 1);
}, frame));

// the exercise
const x = await cellIndex(page, /class CounterActivity/);
const starter = await page.evaluate(i => window.cellEditors[i].getValue(), x);
await run(page, x);
const outcome = () => page.evaluate(() => window.__ran.outcome);
check('the starter does not pass', await outcome() === 'fail');
const solution = starter.replace("@count = 0", "@count = bundle ? bundle.getInt('count') : 0")
  .replace(/\nend\n?$/, "\n\n  def onSaveInstanceState(out_state)\n    super\n    out_state.putInt('count', @count)\n  end\nend\n");
await run(page, x, solution);
check('a solution passes', await outcome() === 'pass');
check('...and its phone shows 4 after the check\'s taps and rotation', /\b4\b/.test(await screen(page, x)));
await ctx.close();

// German
{
  const de = await browser.newContext({ locale: 'de-DE' });
  const p = await open(de, '?lang=de#ruboto');
  const idx = await cellIndex(p, /class HalloActivity/);
  await run(p, idx);
  check('the German lesson starts its app', /Hallo[\s\S]*Chunky bacon!/.test(await screen(p, idx)));
  check('...with German phone controls', /Drehen/.test(await p.textContent(`#ruboto-slot-${idx} .rp-rotate`)));
  await de.close();
}

check('no page errors', errors.length === 0);
await browser.close();
console.log(failures ? `${failures} FAILED` : 'ALL PASS');
process.exit(failures ? 1 : 0);
