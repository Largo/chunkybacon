// The eight Pico lessons of html/lessons.js in a browser (docs/HANDOVER.md
// §6r), against a dev server, in each language asked for (default de en):
//
//   BASE=http://127.0.0.1:18111/ node test/pico_lessons_test.mjs [de] [en] [ja]
//   SHOTS=dir ...   also saves a screenshot of each lesson and its bench
//
// Per lesson: it opens in the section "Ruby on a Pico"; every demo cell runs
// on its board without an error, and the bench is moved under the cell that
// runs and redrawn from that run's state (an e-paper cell's frame reaches
// the bench's image); the exercise's starter fails and the solution
// (check_harness.rb's SOLUTIONS) passes on the page. And: the bench's
// button, pressed with the mouse, reaches a running loop; the IRB below a
// board cell drives the LED; tabs - the tab list, the arrow keys, a
// read-only tab ignores typing, an edited editable tab survives a reload
// and the lesson's reset brings its starter back; the BLE echo answers the
// bench's laptop panel; ■ Stop resets the Pico within a second, keeps what
// the run printed, and the next run works; the CRuby laptop cell
// (pico_laptop.rb) finds the advertising Pico and prints its echo; no page
// errors. The LCD: its frames reach the bench's glass, the joystick
// pressed with the mouse reaches the running loop and B ends it; the WS2812
// cells light the PicoGo's and the matrix's LEDs. (■ Stop is the live bench's: the other cells show idle previews
// with Stop disabled, so the tests click ".pico-stop:enabled".)
// pico_board_test.mjs covers the same machinery on the demo lesson
// file (tmp/), pico_bench_shots.mjs the drawing.
import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { fileURLToPath } from "url";
import { chromium } from "/usr/local/lib/node_modules/playwright/index.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASE = process.env.BASE || "http://127.0.0.1:8011/";
const SHOTS = process.env.SHOTS || "";
const langs = process.argv.slice(2).length ? process.argv.slice(2) : ["de", "en"];
const IDS = ["pico-blink", "pico-sensors", "pico-robot", "pico-epaper", "pico-lcd", "pico-wifi", "pico-ble", "pico-deploy"];

const text = fs.readFileSync(path.join(ROOT, "html/lessons.js"), "utf8");
const data = JSON.parse(text.slice(text.indexOf("JSON.stringify(") + 15, text.lastIndexOf(");")));
// ONLY=pico-ble,pico-wifi: just these (ONLY=review: only the review regressions)
const lessons = IDS.filter(id => !process.env.ONLY || process.env.ONLY.split(",").includes(id)).map(id => data.lessons.find(l => l.id === id));
const SOLUTIONS = JSON.parse(execFileSync("ruby", [path.join(ROOT, "test/check_harness.rb"), "--dump-solutions", IDS.join(",")], { encoding: "utf8" }));
if (SHOTS) fs.mkdirSync(SHOTS, { recursive: true });

let failures = 0, passes = 0;
const check = (name, cond, extra = "") => {
  console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra ? ` - ${String(extra).slice(0, 300)}` : ""}`);
  if (cond) passes++; else failures++;
};
const errors = [];
const browser = await chromium.launch();

async function open(ctx, lang, hash) {
  const page = await ctx.newPage();
  await page.setViewportSize({ width: 1280, height: 900 });
  page.on("pageerror", e => errors.push(`${hash}/${lang}: ${e.message}`));
  page.on("console", m => {
    if (m.type() === "error" && !/Failed to load resource/.test(m.text())) errors.push(`${hash}/${lang}: ${m.text().slice(0, 200)}`);
  });
  page.on("dialog", d => d.accept());
  await page.goto(`${BASE}?lang=${lang}${hash}`, { waitUntil: "domcontentloaded" });
  await ready(page);
  return page;
}
async function ready(page) {
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  // (a lesson without board cells loads no bench)
  await page.waitForFunction(() => window.chunkyPicoRuby && window.chunkyPicoRuby.ready &&
    (window.chunkyPicoBoard || !document.querySelector(".pico-slot")), null, { timeout: 60000 });
  await page.evaluate(() => {
    window.__rans = [];
    // the bench's debug(), safe before it is mounted
    window.__bench = () => (window.chunkyPicoBoard && window.chunkyPicoBoard.debug()) || { log: [], state: "", frames: 0 };
    window.addEventListener("chunky:ran", e => window.__rans.push(Number(e.detail.idx)));
  });
}
const out = (page, idx) => page.evaluate(i => (document.getElementById("cell-out-" + i) || {}).textContent || "", idx);
const debug = page => page.evaluate(() => window.__bench());
const until = (page, fn, arg, timeout = 5000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
async function run(page, idx, { code, wait = true, timeout = 70000 } = {}) {
  if (code !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, code]);
  const n = await page.evaluate(i => window.__rans.filter(x => x === i).length, idx);
  await page.click(`.run-cell[data-idx="${idx}"]`);
  if (wait) await page.waitForFunction(([i, k]) => window.__rans.filter(x => x === i).length > k, [idx, n], { timeout });
  return out(page, idx);
}
const ranCount = (page, idx) => page.evaluate(i => window.__rans.filter(x => x === i).length, idx);
const celebrates = async page => (await page.getAttribute(".cell.exercise", "class")).includes("celebrate");
const failed = t => /\b\w*(Error|Exception)\b|Fehler|エラー|zurückgesetzt|was reset|リセット/.test(t) && !/ConnectTimeout/.test(t);
const said = {
  reset: { de: "zurückgesetzt", en: "was reset", ja: "リセット" },
  connected: { de: "ein Laptop ist verbunden", en: "a laptop connected", ja: "a laptop connected" },
  hello: { de: "Hallo von CRuby", en: "hello from CRuby", ja: "hello from CRuby" },
  led: { de: "lampe", en: "led", ja: "led" }
};

for (const lang of langs) {
  const ctx = await browser.newContext({ locale: lang === "ja" ? "ja-JP" : lang === "en" ? "en-US" : "de-DE" });
  for (const lesson of lessons) {
    const id = lesson.id;
    const cells = lesson[lang].cells;
    const page = await open(ctx, lang, "#" + id);
    const L = `${id}/${lang}`;
    check(`${L} opens (${lesson[lang].title})`, await page.evaluate(t => document.title.includes(t), lesson[lang].title));
    if (id === "pico-blink") {
      const sec = await page.evaluate(() => [...document.querySelectorAll("#lessonNav .nav-group-name")].map(n => n.textContent));
      check(`${L} the sidebar has the section "${lesson.section[lang]}" before the timelog course`,
        sec.indexOf(lesson.section[lang]) >= 0 && sec.indexOf(lesson.section[lang]) === sec.length - 2, sec.join(" | "));
    }

    for (let i = 0; i < cells.length; i++) {
      const c = cells[i];
      if (c.t !== "c") continue;
      const parts = (c.board && c.board.parts) || [];
      const before = await debug(page);

      // ---------- pico-ble: the 30 s radio cells, the laptop ----------
      if (id === "pico-ble" && c.engine !== "cruby") {
        await run(page, i, { wait: false });
        if (parts.includes("epd213")) {
          check(`${L} cell ${i}: the bench's SHOW reaches the e-paper`, await until(page, f => window.__bench().frames > f, before.frames || 0, 20000));
          check(`${L} cell ${i}: the Pico reports T <celsius>`, await until(page, () => /tx\|T \d/.test(JSON.stringify(window.__bench().log)), null, 12000));
        } else {
          check(`${L} cell ${i}: the echo answers the bench script`, await until(page, () => /echo: Hello, Pico!/.test(JSON.stringify(window.__bench().log)), null, 10000), JSON.stringify((await debug(page)).log));
          // the laptop panel: a typed line
          await page.fill(`#pico-slot-${i} .pico-line input`, "Grüezi");
          await page.press(`#pico-slot-${i} .pico-line input`, "Enter");
          check(`${L} cell ${i}: a line typed into the laptop panel comes back`, await until(page, () => /echo: Grüezi/.test(JSON.stringify(window.__bench().log))));
          // ■ Stop: within a second, the streamed output stays
          const k = await ranCount(page, i);
          const t0 = Date.now();
          await page.click(".pico-stop:enabled");
          await page.waitForFunction(([x, n]) => window.__rans.filter(y => y === x).length > n, [i, k], { timeout: 5000 });
          const o = await out(page, i);
          check(`${L} cell ${i}: ■ Stop resets the Pico within a second (${Date.now() - t0} ms)`, Date.now() - t0 < 1500 && o.includes(said.reset[lang]), o);
          if (said.connected[lang]) check(`${L} cell ${i}: ...and what the run printed stays above the message`, o.includes(said.connected[lang]), o);
          check(`${L} cell ${i}: ...the bench shows the reset`, /reset/.test((await debug(page)).reset));
          continue;
        }
        const k = await ranCount(page, i);
        await page.click(".pico-stop:enabled");
        await page.waitForFunction(([x, n]) => window.__rans.filter(y => y === x).length > n, [i, k], { timeout: 5000 });
        continue;
      }
      if (c.engine === "cruby") {
        // the echo cell above advertises "PicoRuby"; the laptop finds it
        const echo = cells.findIndex(x => x.t === "c" && x.engine !== "cruby");
        await run(page, echo, { wait: false });
        await page.waitForTimeout(800);
        const o = await run(page, i);
        check(`${L} cell ${i}: the CRuby laptop cell runs (pico_laptop.rb)`, !failed(o) && !/LoadError|ble/.test(o.split("\n")[0] || "") , o);
        if (said.hello[lang]) {
          check(`${L} cell ${i}: ...finds the Pico and prints its echo`,
            await until(page, ([x, s]) => (document.getElementById("cell-out-" + x).textContent || "").includes("echo: " + s), [i, said.hello[lang]], 8000), await out(page, i));
        }
        const k = await ranCount(page, echo);
        await page.click(".pico-stop:enabled");
        await page.waitForFunction(([x, n]) => window.__rans.filter(y => y === x).length > n, [echo, k], { timeout: 5000 });
        const again = await run(page, i);
        check(`${L} cell ${i}: without a running Pico it says it found nothing`, !failed(again) && !again.includes("echo"), again);
        continue;
      }

      // ---------- every other demo cell ----------
      let o;
      if (parts.includes("lcd114") && /GPIO::PULL_UP/.test(c.code)) {
        // the joystick cell: steer with the mouse, B ends the loop
        await run(page, i, { wait: false });
        await until(page, x => document.querySelector(`#pico-slot-${x} .pico-lcd-keys`) && /"lit":true/.test(window.__bench().state), i, 10000);
        const f0 = (await debug(page)).lcd;
        const right = page.locator(`#pico-slot-${i} .pico-lcd-keys button`).nth(3);
        await right.hover();
        await page.mouse.down();
        check(`${L} cell ${i}: the joystick, pushed right with the mouse, reaches the loop`, await until(page, () => /"keys":\["right"\]/.test(window.__bench().state), null, 3000));
        check(`${L} cell ${i}: ...and the square moves on the glass`, await until(page, f => window.__bench().lcd > f + 2, f0, 3000));
        await page.mouse.up();
        const t0 = Date.now();
        const b = page.locator(`#pico-slot-${i} .pico-lcd-keys button`).nth(6);
        await b.hover();
        await page.mouse.down();
        await page.waitForFunction(x => window.__rans.includes(x), i, { timeout: 20000 });
        await page.mouse.up();
        check(`${L} cell ${i}: key B ends the program (${Date.now() - t0} ms)`, Date.now() - t0 < 4000);
        o = await out(page, i);
      } else if (parts.includes("button14")) {
        await run(page, i, { wait: false });
        await until(page, x => document.querySelector(`#pico-slot-${x} .pico-press`) && window.__bench().state, i);
        await page.waitForTimeout(500);
        const press = page.locator(`#pico-slot-${i} .pico-press`);
        await press.hover();
        await page.mouse.down();
        check(`${L} cell ${i}: the bench's button, pressed with the mouse, lights the LED`, await until(page, () => /"15":"o1"/.test(window.__bench().state), null, 2000));
        await page.mouse.up();
        check(`${L} cell ${i}: ...and released, the LED goes out`, await until(page, () => /"15":"o0"/.test(window.__bench().state), null, 2000));
        await page.waitForFunction(x => window.__rans.includes(x), i, { timeout: 20000 });
        o = await out(page, i);
      } else {
        o = await run(page, i);
      }
      check(`${L} cell ${i} runs without an error`, !failed(o), o);
      if (c.board) {
        const d = await debug(page);
        const mounted = await page.evaluate(x => !!document.querySelector(`#pico-slot-${x} .pico-bench`) && !document.getElementById(`pico-slot-${x}`).hidden, i);
        check(`${L} cell ${i}: the bench is under the cell and drew this run's state`, mounted && d.idx === String(i) && d.state && d.state !== before.state, JSON.stringify({ mounted, idx: d.idx }));
      }
      if (parts.includes("lcd114")) {
        const d = await debug(page);
        const lit = await page.evaluate(x => { const im = document.querySelector(`#pico-slot-${x} .pb-lcd-image`); return im ? [im.getAttribute("href") || "", im.style.opacity] : ["", ""]; }, i);
        check(`${L} cell ${i}: the LCD's frames reached the bench and the glass is lit`, d.lcd > (before.lcd || 0) && lit[0].length > 100 && Number(lit[1]) > 0, JSON.stringify({ lcd: d.lcd, img: lit[0].length, opacity: lit[1] }));
      }
      if (parts.includes("rgbled") || (parts.includes("picogo") && /ws2812|pio/.test(c.code))) {
        const lit = await page.evaluate(x => [...document.querySelectorAll(`#pico-slot-${x} .pb-rgb-led.is-on, #pico-slot-${x} .pb-robot-led.is-on`)].length, i);
        check(`${L} cell ${i}: the WS2812 LEDs light up on the bench`, lit >= (parts.includes("rgbled") ? 160 : 1), lit);
      }
      if (parts.includes("epd213")) {
        const d = await debug(page);
        const img = await page.evaluate(x => { const im = document.querySelector(`#pico-slot-${x} .pico-bench image`); return im ? im.getAttribute("href") || "" : ""; }, i);
        check(`${L} cell ${i}: the e-paper frame reached the bench and is drawn`, d.frames > (before.frames || 0) && d.black > 0 && img.length > 100, JSON.stringify({ frames: d.frames, black: d.black, img: img.length }));
      }
      if (c.code.includes("show_irb")) {
        await page.fill(`#cell-out-${i} .irb-input`, `${said.led[lang]}.write(1)`);
        await page.press(`#cell-out-${i} .irb-input`, "Enter");
        check(`${L} cell ${i}: the IRB drives the cell's LED`, await until(page, () => /"15":"o1"/.test(window.__bench().state)));
      }
      // tabs: switching, read-only
      if (c.tabs && c.tabs.some(t => t.src) && lang !== "ja") {
        const k = c.tabs.findIndex(t => t.src) + 1;
        check(`${L} cell ${i}: one tab per file`, await page.locator(`.cell-tab[data-idx="${i}"]`).count() === c.tabs.length + 1);
        await until(page, key => window.cellEditors[key] && window.cellEditors[key].getValue().length > 100, `${i}-${k}`);
        await page.click(`#cell-tab-${i}-${k - 1}`);
        await page.keyboard.press("ArrowRight");
        check(`${L} cell ${i}: the arrow key selects the next tab`, await page.evaluate(([x, n]) => document.getElementById(`cell-tab-${x}-${n}`).getAttribute("aria-selected") === "true" && !document.getElementById(`cell-panel-${x}-${n}`).hidden, [i, k]));
        const was = await page.evaluate(key => window.cellEditors[key].getValue(), `${i}-${k}`);
        await page.click(`#cell-panel-${i}-${k} .CodeMirror`);
        await page.keyboard.type("zzz");
        check(`${L} cell ${i}: the read-only tab ${c.tabs[k - 1].name} ignores typing`, await page.evaluate(([key, w]) => window.cellEditors[key].getValue() === w, [`${i}-${k}`, was]));
        await page.click(`#cell-tab-${i}-0`);
      }
      // an editable tab: saved with the run, kept over a reload, reset restores it
      const ed = (c.tabs || []).findIndex(t => t.readonly === false);
      if (ed >= 0 && (c.tabs || []).length === 1 && lang !== "ja") {
        const key = `${i}-${ed + 1}`;
        const starter = c.tabs[ed].code;
        await page.evaluate(k => { const e = window.cellEditors[k]; e.setValue(e.getValue() + "\n# mine\n"); }, key);
        await run(page, i);
        await page.reload({ waitUntil: "domcontentloaded" });
        await ready(page);
        await until(page, k => window.cellEditors[k], key, 20000);
        check(`${L} cell ${i}: the edited tab ${c.tabs[ed].name} survives a reload`, (await page.evaluate(k => window.cellEditors[k].getValue(), key)).includes("# mine"));
        await page.click("#reset-code");
        await page.waitForTimeout(500);
        check(`${L} cell ${i}: the lesson's reset brings the tab's starter back`, await page.evaluate(([k, s]) => window.cellEditors[k].getValue() === s, [key, starter]));
      }
    }

    // ---------- the exercise ----------
    const ex = cells.findIndex(c => c.t === "x");
    const so = await run(page, ex);
    check(`${L} the starter does not pass`, !(await celebrates(page)), so);
    const sol = SOLUTIONS[id][lang === "de" ? "de" : "en"][0];
    const sp = await run(page, ex, { code: sol });
    check(`${L} the solution passes on the page`, await celebrates(page), sp);
    if (id === "pico-ble") check(`${L} a line the laptop sent to an earlier run is not sent again`, !/CRuby/.test(JSON.stringify((await debug(page)).log)), JSON.stringify((await debug(page)).log));
    if (SHOTS) {
      await page.screenshot({ path: path.join(SHOTS, `${id}-${lang}.png`), fullPage: true });
      const slot = page.locator(`#pico-slot-${ex}`);
      if (cells[ex].board && await slot.count()) await slot.screenshot({ path: path.join(SHOTS, `${id}-${lang}-bench.png`) }).catch(() => {});
    }
    await page.close();
  }
  await ctx.close();
}

// regressions from the review (en): stale inputs (the lesson-change case
// does not show here: the worker restarts on the way), ■ Stop in a board IRB,
// a loop without sleep, a driver fetch of another lesson, phone width
if (!process.env.ONLY || process.env.ONLY === "review") {
  const ctx = await browser.newContext({ locale: "en-US" });
  const go = async (page, id) => {
    await page.click(`#lessonNav a[data-id="${id}"]`);
    await until(page, x => location.hash === "#" + x && document.querySelector('.run-cell[data-idx="1"]'), id, 20000);
    await page.waitForTimeout(500);
  };
  {
    const page = await open(ctx, "en", "#pico-wifi");
    await run(page, 1);
    await page.check("#pico-slot-1 .pico-check input");
    let o = await run(page, 1);
    check("review: pico-wifi with the access point off does not connect", /ConnectTimeout|connected: false/.test(o), o);
    await go(page, "pico-blink");
    await go(page, "pico-wifi");
    o = await run(page, 1);
    check("review: back in pico-wifi, the access point is on again (no stale input in the worker)", /connected: true/.test(o), o);
    await page.close();
  }
  {
    // a BLE line of a run that ended by itself is not sent to the next run
    // (the worker kept every input it was ever given)
    const page = await open(ctx, "en", "#pico-ble");
    const code = await page.evaluate(() => window.cellEditors["1"].getValue().replace("30_000", "3_000"));
    await run(page, 1, { code, wait: false });
    await until(page, () => /echo: Hello, Pico!/.test(JSON.stringify(window.__bench().log)), null, 20000);
    await page.fill("#pico-slot-1 .pico-line input", "hi-from-first-run");
    await page.press("#pico-slot-1 .pico-line input", "Enter");
    await page.waitForFunction(() => window.__rans.includes(1), null, { timeout: 20000 });
    await run(page, 1, { timeout: 20000 });
    const log = JSON.stringify((await debug(page)).log);
    check("review: a BLE line of an earlier run (ended by itself) is not sent again", /Hello, Pico!/.test(log) && !/hi-from-first-run/.test(log), log);
    await page.close();
  }
  {
    const page = await open(ctx, "en", "#pico-blink");
    await run(page, 9);
    await page.fill("#cell-out-9 .irb-input", "10.times { led.write(1); sleep 1 }");
    await page.press("#cell-out-9 .irb-input", "Enter");
    await page.waitForTimeout(1500);
    await page.click(".pico-stop:enabled");
    await until(page, () => /reset/.test((document.querySelector("#cell-out-9 .irb-history") || {}).textContent || ""), null, 5000);
    const h = await page.evaluate(() => document.querySelector("#cell-out-9 .irb-history").textContent);
    check("review: ■ Stop during a board IRB line says the Pico was reset", h.includes("The Pico was reset.") && !h.includes("could not be loaded"), h.slice(-300));
    const t0 = Date.now();
    const o = await run(page, 1, { code: "while true\n  puts \"busy\"\nend\n", timeout: 30000 });
    const took = Date.now() - t0;
    check("review: a loop without sleep ends after the quiet limit, not a minute", took < 20000, `${took} ms: ${o.slice(-200)}`);
    await page.close();
  }
  {
    const page = await open(ctx, "en", "#pico-robot");
    await page.route("**/pico/lib/en/picogo.rb", r => r.abort());
    await page.reload({ waitUntil: "domcontentloaded" });
    await ready(page);
    await go(page, "pico-wifi");
    await page.unroute("**/pico/lib/en/picogo.rb");
    await until(page, () => window.cellEditors["9-1"], null, 10000);
    const tabs = await page.evaluate(() => JSON.parse(window.getCellTabs("9")));
    const dechunk = tabs.find(t => t.name === "dechunk.rb");
    check("review: an inline tab never gets the driver of the lesson before", dechunk && dechunk.code.includes("def dechunk") && !/PicoGo/.test(dechunk.code), dechunk && dechunk.code.slice(0, 200));
    await page.close();
  }
  await ctx.close();
  const phone = await browser.newContext({ locale: "en-US", viewport: { width: 360, height: 740 }, isMobile: true, hasTouch: true });
  for (const id of ["pico-deploy", "pico-ble", "pico-wifi", "pico-robot"]) {
    const page = await phone.newPage();
    page.on("pageerror", e => errors.push(`phone ${id}: ${e.message}`));
    await page.goto(`${BASE}?lang=en#${id}`, { waitUntil: "domcontentloaded" });
    await ready(page);
    const w = await page.evaluate(() => document.documentElement.scrollWidth);
    check(`review: ${id} fits a 360 px phone`, w <= 362, `${w} px`);
    await page.close();
  }
  await phone.close();
}

// the closing cell of lesson picoruby points to the new section
{
  const ctx = await browser.newContext({ locale: "en-US" });
  const page = await ctx.newPage();
  await page.goto(`${BASE}?lang=en#picoruby`, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  const r = await page.evaluate(() => {
    const num = (document.querySelector('#lessonNav a[data-id="pico-blink"] .num') || {}).textContent || "?";
    const body = document.getElementById("lessonBody").innerText;
    return { num, tail: body.slice(-400) };
  });
  check(`picoruby's closing text names lesson ${r.num} (pico-blink)`, r.tail.includes(`Lesson ${r.num} puts`), r.tail);
  await ctx.close();
}

check("no page errors", errors.length === 0, errors.join(" | "));
await browser.close();
console.log(`${passes} passed, ${failures} failed`);
console.log(failures ? `${failures} FAILED` : "ALL PICO LESSON CHECKS PASSED");
process.exit(failures ? 1 : 0);
