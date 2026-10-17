// The Pico lessons in a browser (docs/HANDOVER.md §6r), against a dev
// server. Until the lessons are in html/lessons.js it runs on a lesson
// file put into the page's course (default tmp/pico-lessons/_demo.json):
//
//   BASE=http://127.0.0.1:18111/ node test/pico_board_test.mjs [lesson.json]
//
// So far (the bench's drawing is still a placeholder, pico_board.js): no
// bench script for a CRuby lesson; a lesson's cells with tabs - the tab
// list, switching with the keyboard, a read-only tab that ignores typing;
// a board cell runs in the worker and the bench gets its state; a button
// pressed from the page reaches a running loop; output streams while the
// cell runs; ■ Stop resets the Pico and the next run works; an error in a
// tab marks its line there; the exercise's check sees `board` (starter
// fails, the solution passes); an IRB below a board cell drives the board;
// no page errors.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { chromium } from "/usr/local/lib/node_modules/playwright/index.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASE = process.env.BASE || "http://127.0.0.1:8011/";
const file = process.argv[2] || path.join(ROOT, "tmp/pico-lessons/_demo.json");
const lesson = JSON.parse(fs.readFileSync(file, "utf8"));
const solution = ((lesson.solutions || {}).de || [])[0];
delete lesson.solutions;

let failures = 0;
const check = (name, cond, extra = "") => { console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra ? ` - ${extra}` : ""}`); if (!cond) failures++; };
const errors = [];
const browser = await chromium.launch();
const ctx = await browser.newContext({ locale: "de-DE" });
// the course with the lesson file in it, after picoruby
await ctx.route("**/lessons.js", async route => {
  const response = await route.fetch();
  let text = await response.text();
  const start = text.indexOf("JSON.stringify(") + "JSON.stringify(".length;
  const end = text.lastIndexOf(");");
  const data = JSON.parse(text.slice(start, end));
  if (!data.lessons.some(l => l.id === lesson.id)) {
    const at = data.lessons.findIndex(l => l.id === "picoruby");
    data.lessons.splice(at + 1, 0, lesson);
  }
  text = text.slice(0, start) + JSON.stringify(data) + text.slice(end);
  await route.fulfill({ response, body: text, headers: Object.assign({}, response.headers(), { "content-length": String(Buffer.byteLength(text)) }) });
});

async function open(hash) {
  const page = await ctx.newPage();
  page.on("pageerror", e => { errors.push(e.message); console.log("[pageerror]", e.message); });
  page.on("console", m => {
    if (m.type() === "error" && !/Failed to load resource/.test(m.text())) { errors.push(m.text()); console.log("  [console.error]", m.text().slice(0, 200)); }
  });
  await page.goto(BASE + hash, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  return page;
}
const out = (page, idx) => page.evaluate(i => (document.getElementById("cell-out-" + i) || {}).textContent || "", idx);
async function run(page, idx, { code, wait = true } = {}) {
  if (code !== undefined) await page.evaluate(([i, t]) => window.setCellCode(i, t), [idx, code]);
  await page.evaluate(() => { window.__ran = null; window.addEventListener("chunky:ran", e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  if (wait) await page.waitForFunction(() => window.__ran, null, { timeout: 70000 });
  return out(page, idx);
}

// ---------- a CRuby lesson loads no bench ----------
{
  const page = await open("#hallo");
  await page.waitForTimeout(500);
  check("a CRuby lesson loads no pico_board.js", await page.evaluate(() => !window.chunkyPicoBoard && !document.getElementById("picoBoardScript")));
  await page.close();
}

const page = await open("#" + lesson.id);
await page.waitForFunction(() => window.chunkyPicoRuby.ready && window.chunkyPicoBoard, null, { timeout: 60000 });
const cells = lesson.de.cells;
const idxOf = pred => cells.findIndex(pred);
const blink = idxOf(c => c.t === "c" && c.board && !c.tabs && !c.code.includes("show_irb") && c.code.includes("write(1)"));
const loop = idxOf(c => c.t === "c" && c.board && (c.board.parts || []).includes("button14"));
const epd = idxOf(c => c.t === "c" && c.tabs);
const irb = idxOf(c => c.t === "c" && c.code.includes("show_irb"));
const ex = idxOf(c => c.t === "x");

// ---------- tabs ----------
check("the cell with tabs has a tab list", await page.locator(`.cell-tab[data-idx="${epd}"]`).count() === cells[epd].tabs.length + 1);
await page.waitForFunction(i => window.cellEditors[`${i}-1`] && window.cellEditors[`${i}-1`].getValue().includes("class EPD2in13"), epd, { timeout: 10000 });
check("a src tab shows its file", true);
await page.click(`#cell-tab-${epd}-0`);
await page.keyboard.press("ArrowRight");
check("the arrow keys move to the next tab", await page.evaluate(i => document.getElementById(`cell-tab-${i}-1`).getAttribute("aria-selected") === "true"
  && !document.getElementById(`cell-panel-${i}-1`).hidden && document.getElementById(`cell-panel-${i}-0`).hidden, epd));
const before = await page.evaluate(i => window.cellEditors[`${i}-1`].getValue(), epd);
await page.click(`#cell-panel-${epd}-1 .CodeMirror`);
await page.keyboard.type("zzz");
check("a read-only tab ignores typing", await page.evaluate(([i, b]) => window.cellEditors[`${i}-1`].getValue() === b, [epd, before]));
await page.click(`#cell-tab-${epd}-0`);

// ---------- a board cell ----------
const t0 = Date.now();
await run(page, blink);
check("a board cell runs and the bench is mounted under it", await page.evaluate(i => !!document.querySelector(`#pico-slot-${i} .pico-bench`) && !document.getElementById(`pico-slot-${i}`).hidden, blink));
check("...the bench got the LED's state", await page.evaluate(() => /"15":"o1"/.test(window.chunkyPicoBoard.debug().state)), await page.evaluate(() => window.chunkyPicoBoard.debug().state));
console.log(`  (blink cell: ${Date.now() - t0} ms)`);

// a button pressed on the page reaches the running loop, output streams
await run(page, loop, { wait: false });
await page.waitForTimeout(800);
await page.evaluate(() => window.chunkyPicoBoard.input("pin14", "1"));
await page.waitForFunction(() => /"15":"o1"/.test(window.chunkyPicoBoard.debug().state), null, { timeout: 2000 }).then(() => check("a page input reaches a running loop (LED follows the button)", true), () => check("a page input reaches a running loop (LED follows the button)", false));
await page.evaluate(() => window.chunkyPicoBoard.input("pin14", "0"));
// ■ Stop: the Pico's reset
const stopped = Date.now();
await page.evaluate(() => window.chunkyPicoRuby.stop());
await page.waitForFunction(() => window.__ran, null, { timeout: 5000 });
check("■ Stop ends the run at once with the reset message", Date.now() - stopped < 1500 && (await out(page, loop)).includes("zurückgesetzt"), await out(page, loop));
const again = await run(page, blink);
check("...and the next run works", !again.includes("Error"), again);

// streaming: a cell that prints for a while
await page.evaluate(() => { window.__progress = []; window.addEventListener("chunky:picoruby-progress", e => window.__progress.push(e.detail.output)); });
await run(page, blink, { code: 'require "gpio"\n3.times { |i| puts "tick #{i}"; sleep_ms 300 }\n' });
check("what a run prints streams before the run ends", await page.evaluate(() => window.__progress.length >= 2));
await page.evaluate(([i, t]) => window.setCellCode(i, t), [blink, cells[blink].code]);

// ---------- e-paper with tabs; an error in a tab ----------
const shown = await run(page, epd);
check("the e-paper cell refreshes (a frame reached the bench)", await page.evaluate(() => window.chunkyPicoBoard.debug().frames >= 1), shown);
await run(page, epd, { code: 'require "epd2in13"\nEPD2in13.new(spi: nil, cs_pin: 9, dc_pin: 8, rst_pin: 12, busy_pin: 13).refresh' });
check("an error in a tab marks its line in that tab", await page.evaluate(i => {
  const ed = window.cellEditors[`${i}-1`];
  return document.getElementById(`cell-tab-${i}-1`).getAttribute("aria-selected") === "true" && ed.getAllMarks().length > 0;
}, epd), await out(page, epd));
await page.evaluate(([i, t]) => window.setCellCode(i, t), [epd, cells[epd].code]);

// ---------- an IRB below a board cell ----------
await run(page, irb);
await page.fill(".irb-term .irb-input", "led.write(1)");
await page.press(".irb-term .irb-input", "Enter");
await page.waitForFunction(() => /"15":"o1"/.test(window.chunkyPicoBoard.debug().state), null, { timeout: 5000 })
  .then(() => check("an IRB line drives the cell's board", true), () => check("an IRB line drives the cell's board", false));

// ---------- the exercise ----------
await run(page, ex);
check("the starter does not pass (bench script, board in the check)", !(await page.getAttribute(".cell.exercise", "class")).includes("celebrate"));
if (solution) {
  await run(page, ex, { code: solution });
  check("the solution passes its check on the page", (await page.getAttribute(".cell.exercise", "class")).includes("celebrate"), await out(page, ex));
}

check("no page errors", errors.length === 0, errors.join(" | "));
await browser.close();
console.log(failures ? `${failures} FAILED` : "ALL PICO BOARD CHECKS PASSED");
process.exit(failures ? 1 : 0);
