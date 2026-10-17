// Screenshots of the Pico bench (html/pico_board.js), one per part, with the
// throwaway lessons tmp/pico-lessons/_bench.json (a cell per part) and
// _demo.json put into the page's course, against a dev server. Also checks
// what each shot needs to show (the e-paper got a frame, the robot stopped
// at the wall, ...), so it doubles as the bench's browser test.
//
//   BASE=http://127.0.0.1:18111/ node test/pico_bench_shots.mjs [out-dir]
//
// The PNGs go to out-dir (default tmp/pico-research/shots/).
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { chromium } from "/usr/local/lib/node_modules/playwright/index.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASE = process.env.BASE || "http://127.0.0.1:8011/";
const OUT = process.argv[2] || path.join(ROOT, "tmp/pico-research/shots");
fs.mkdirSync(OUT, { recursive: true });
const lessons = ["_bench.json", "_demo.json"].map(f => {
  const l = JSON.parse(fs.readFileSync(path.join(ROOT, "tmp/pico-lessons", f), "utf8"));
  delete l.solutions;
  return l;
});

let failures = 0;
const check = (name, cond, extra = "") => { console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra ? ` - ${extra}` : ""}`); if (!cond) failures++; };
const errors = [];
const browser = await chromium.launch();

async function context(opts) {
  const ctx = await browser.newContext(Object.assign({ locale: "en-US" }, opts));
  await ctx.route("**/lessons.js", async route => {
    const response = await route.fetch();
    let text = await response.text();
    const start = text.indexOf("JSON.stringify(") + "JSON.stringify(".length;
    const end = text.lastIndexOf(");");
    const data = JSON.parse(text.slice(start, end));
    const at = data.lessons.findIndex(l => l.id === "picoruby");
    lessons.forEach((l, i) => { if (!data.lessons.some(x => x.id === l.id)) data.lessons.splice(at + 1 + i, 0, l); });
    text = text.slice(0, start) + JSON.stringify(data) + text.slice(end);
    await route.fulfill({ response, body: text, headers: Object.assign({}, response.headers(), { "content-length": String(Buffer.byteLength(text)) }) });
  });
  return ctx;
}

async function open(ctx, hash) {
  const page = await ctx.newPage();
  page.on("pageerror", e => { errors.push(e.message); console.log("[pageerror]", e.message); });
  page.on("console", m => {
    if (m.type() === "error" && !/Failed to load resource/.test(m.text())) { errors.push(m.text()); console.log("  [console.error]", m.text().slice(0, 200)); }
  });
  await page.goto(BASE + hash, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  await page.waitForFunction(() => window.chunkyPicoRuby && window.chunkyPicoRuby.ready && window.chunkyPicoBoard, null, { timeout: 60000 });
  return page;
}

async function run(page, idx, wait = false) {
  await page.evaluate(() => { window.__ran = null; window.addEventListener("chunky:ran", e => { window.__ran = e.detail; }, { once: true }); });
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(i => { const s = document.getElementById("pico-slot-" + i); return s && !s.hidden && s.querySelector(".pico-svg"); }, idx, { timeout: 20000 });
  if (wait) await page.waitForFunction(() => window.__ran, null, { timeout: 70000 });
}
const shot = async (page, idx, name) => {
  const slot = page.locator(`#pico-slot-${idx}`);
  await slot.scrollIntoViewIfNeeded();
  await slot.screenshot({ path: path.join(OUT, name + ".png") });
  console.log("  shot", name + ".png");
};
const dbg = page => page.evaluate(() => window.chunkyPicoBoard.debug());
const cellIdx = (lesson, pred) => lesson.en.cells.findIndex(pred);
const has = part => c => c.board && (c.board.parts || []).includes(part);

const bench = lessons[0];
for (const [label, opts] of [["", { viewport: { width: 1280, height: 1000 } }],
                             ["-narrow", { viewport: { width: 390, height: 900 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }],
                             ["-dark", { viewport: { width: 1280, height: 1000 }, colorScheme: "dark" }]]) {
  const ctx = await context(opts);
  const page = await open(ctx, "#" + bench.id);
  const only = label === "" ? null : ["desk", "robot", "epd", "lcd", "matrix"];
  const want = n => !only || only.includes(n);

  if (want("desk")) {
    const desk = cellIdx(bench, has("led15"));
    await run(page, desk);
    await page.waitForTimeout(700);
    // the light down: the night light goes on; then the button, held
    await page.evaluate(() => window.chunkyPicoBoard.input("adc26", "0.2"));
    const press = page.locator(`#pico-slot-${desk} .pico-press`);
    await press.dispatchEvent("pointerdown", { pointerId: 1 });
    await page.waitForFunction(() => /"16":"p50"/.test(window.chunkyPicoBoard.debug().state), null, { timeout: 3000 })
      .then(() => check(`desk${label}: the button reaches the loop (buzzer at 50 %)`, true), () => check(`desk${label}: the button reaches the loop (buzzer at 50 %)`, false));
    await page.waitForTimeout(150);
    check(`desk${label}: the LED glows`, await page.evaluate(i => Number(getComputedStyle(document.querySelector(`#pico-slot-${i} .pb-led-glow`)).opacity) > 0.5, desk));
    check(`desk${label}: GP15 is drawn high`, await page.locator(`#pico-slot-${desk} .pb-pinstate.is-high`).count() >= 1);
    await shot(page, desk, "desk" + label);
    await press.dispatchEvent("pointerup", { pointerId: 1 });
    if (!only) {
      // ▶ on another board cell while this one runs: its bench waits for
      // the worker to take its run and does not draw this one's pins
      const env = cellIdx(bench, has("envsensor"));
      await page.click(`.run-cell[data-idx="${env}"]`);
      await page.waitForTimeout(400);
      const st = (await dbg(page)).state;
      check("a queued run's bench does not draw the running cell's pins", !/"15":/.test(st), st.slice(0, 120));
      await page.waitForFunction(() => /"20":"i2c"/.test(window.chunkyPicoBoard.debug().state), null, { timeout: 20000 })
        .then(() => check("...and draws its own once it starts", true), () => check("...and draws its own once it starts", false));
      await page.evaluate(() => { window.__ran = null; window.addEventListener("chunky:ran", e => { window.__ran = e.detail; }, { once: true }); });
    }
    // one run at a time: the next cell's bench waits for this one
    await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
  }
  if (want("env") && !only) {
    const env = cellIdx(bench, has("envsensor"));
    await page.evaluate(() => window.chunkyPicoBoard.input("bme.t", "24.5"));
    await run(page, env);
    await page.waitForFunction(() => /"20":"i2c"/.test(window.chunkyPicoBoard.debug().state), null, { timeout: 10000 }).catch(() => {});
    await page.waitForTimeout(300);
    const text = await page.locator(`#pico-slot-${env} .pb-env-text`).first().textContent();
    check("env: the board shows the slider's temperature", /24\.5/.test(text), text);
    check("env: SDA/SCL are drawn as bus pins", await page.locator(`#pico-slot-${env} .pb-pinstate.is-bus`).count() >= 2);
    await shot(page, env, "envsensor");
    await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
  }
  if (want("epd")) {
    const epd = cellIdx(bench, has("epd213"));
    await run(page, epd);
    if (!only) {
      await page.waitForFunction(i => document.querySelector(`#pico-slot-${i} .pb-epd-flash.is-flashing`), epd, { timeout: 20000 })
        .then(() => check("epd: a full refresh flashes", true), () => check("epd: a full refresh flashes", false));
      await page.waitForTimeout(200);
      await shot(page, epd, "epaper-flash");
    }
    await page.waitForFunction(() => window.chunkyPicoBoard.debug().frames >= 1, null, { timeout: 30000 });
    await page.waitForTimeout(300);
    const d = await dbg(page);
    check(`epd${label}: the frame is drawn (black pixels)`, d.black > 500, String(d.black));
    check(`epd${label}: the image has the frame`, await page.evaluate(i => /^data:image\/png/.test(document.querySelector(`#pico-slot-${i} .pb-epd-image`).getAttribute("href") || ""), epd));
    await shot(page, epd, "epaper" + label);
    await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
  }
  if (want("robot")) {
    const robot = cellIdx(bench, has("picogo"));
    await run(page, robot);
    await page.waitForTimeout(900);
    if (!only) await shot(page, robot, "robot-driving");
    await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
    const st = JSON.parse((await dbg(page)).state || "{}");
    const g = (st.parts || {}).picogo || {};
    check(`robot${label}: it stopped in front of the wall`, g.x > 40 && !g.hit, JSON.stringify(g));
    await shot(page, robot, "robot" + label);
    if (!only) {
      // the box, put into the arena and moved with the keys
      await page.locator(`#pico-slot-${robot} .pico-arena-keys input[type=checkbox]`).check();
      for (let i = 0; i < 3; i++) await page.locator(`#pico-slot-${robot} .pico-move`).first().click();
      check("robot: the box is in the arena (input arena.box)", await page.evaluate(() => JSON.parse(window.chunkyPicoBoard.inputs())["arena.box"] === "135,60"));
      await shot(page, robot, "robot-box");
    }
  }
  if (want("lcd")) {
    const lcd = cellIdx(bench, has("lcd114"));
    await run(page, lcd);
    await page.waitForFunction(() => /"lit":true/.test(window.chunkyPicoBoard.debug().state), null, { timeout: 15000 }).catch(() => {});
    const key = page.locator(`#pico-slot-${lcd} .pico-lcd-keys button`).nth(3);
    await key.dispatchEvent("pointerdown", { pointerId: 1 });
    await page.waitForTimeout(600);
    const st = JSON.parse((await dbg(page)).state || "{}");
    const l = (st.parts || {}).lcd114 || {};
    check(`lcd${label}: the joystick's right reaches the loop`, (l.keys || []).includes("right"), JSON.stringify(l));
    check(`lcd${label}: the glass is lit, inverted as the init asks, backlight 90 %`, l.lit === true && l.inv === true && l.bl === 90, JSON.stringify(l));
    const glass = await page.evaluate(i => { const im = document.querySelector(`#pico-slot-${i} .pb-lcd-image`); return [im.getAttribute("href") || "", im.style.opacity]; }, lcd);
    check(`lcd${label}: the frames are drawn on the glass`, (await dbg(page)).lcd > 0 && /^data:image\/png/.test(glass[0]) && Number(glass[1]) > 0.8, glass[1]);
    check(`lcd${label}: the key shows pressed`, await page.locator(`#pico-slot-${lcd} .pb-key-cap.is-pressed`).count() === 1);
    await shot(page, lcd, "lcd" + label);
    await key.dispatchEvent("pointerup", { pointerId: 1 });
    await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
  }
  if (want("matrix")) {
    const mx = cellIdx(bench, has("rgbled"));
    await run(page, mx, true);
    await page.waitForTimeout(300);
    check(`matrix${label}: all 160 LEDs lit`, await page.locator(`#pico-slot-${mx} .pb-rgb-led.is-on`).count() === 160);
    check(`matrix${label}: LED 0 is red, LED 15 (top right) violet`, await page.evaluate(i => {
      const leds = document.querySelectorAll(`#pico-slot-${i} .pb-rgb-led`);
      const rgb = n => (leds[n].style.fill.match(/\d+/g) || []).map(Number);
      const a = rgb(0), b = rgb(15);
      return a[0] > 100 && a[1] < 30 && a[2] < 30 && b[0] > 100 && b[2] > 60 && b[1] < 30;
    }, mx));
    await shot(page, mx, "matrix" + label);
  }
  if (!only) {
    const leds = bench.en.cells.findIndex(c => c.board && c.board.parts.includes("picogo") && /ws2812/.test(c.code));
    await run(page, leds, true);
    await page.waitForTimeout(300);
    check("robot leds: the PicoGo's four WS2812 lit", await page.locator(`#pico-slot-${leds} .pb-robot-led.is-on`).count() === 4);
    await shot(page, leds, "robot-leds");
  }
  if (!only) {
    const cam = cellIdx(bench, has("camera"));
    // the chooser is there once the bench is: a first run, then the bacon
    await run(page, cam, true);
    await page.selectOption(`#pico-slot-${cam} select`, "bacon");
    await run(page, cam, true);
    await page.waitForTimeout(500);
    check("camera: the captured picture is shown", await page.evaluate(i => {
      const img = document.querySelector(`#pico-slot-${i} .pb-photo`);
      return /^data:image/.test(img.getAttribute("href") || "") && !img.classList.contains("is-preview");
    }, cam));
    check("camera: the chosen picture", await page.locator(`#pico-slot-${cam} .pb-photo ~ text`).last().textContent() === "bacon.pgm");
    await shot(page, cam, "camera");

    const wifi = cellIdx(bench, has("wifi"));
    await run(page, wifi, true);
    await page.waitForTimeout(300);
    const http = await page.locator(`#pico-slot-${wifi} .pb-http-line`).first().textContent();
    check("wifi: the HTTP log shows the request", /GET api\.open-meteo\.com/.test(http), http);
    await shot(page, wifi, "wifi");

    const lap = cellIdx(bench, has("laptop"));
    await run(page, lap);
    await page.waitForTimeout(1500);
    await page.fill(`#pico-slot-${lap} .pico-line input`, "chunky bacon");
    await page.click(`#pico-slot-${lap} .pico-send`);
    await page.waitForTimeout(600);
    const lines = await page.locator(`#pico-slot-${lap} .pb-term`).allTextContents();
    check("laptop: the bench's line and the Pico's answer", lines.some(l => /HELLO PICO/.test(l)), lines.join(" | "));
    check("laptop: a line typed in the panel comes back", lines.some(l => /CHUNKY BACON/.test(l)), lines.join(" | "));
    await shot(page, lap, "laptop");

    const said = await page.evaluate(() => window.chunkyPicoBoard.debug().said);
    check("the live region speaks", said.length > 0, said);
  }
  await ctx.close();
}

// the demo lesson: its exercise with the bench script's finger, and Stop
{
  const ctx = await context({ viewport: { width: 1280, height: 1000 }, locale: "de-DE" });
  const demo = lessons[1];
  const page = await open(ctx, "#" + demo.id);
  const ex = demo.de.cells.findIndex(c => c.t === "x");
  await page.evaluate(([i, t]) => window.setCellCode(i, t), [ex, demo.de.cells[ex].code.replace(/#.*\n/, "lampe.write(knopf.low? ? 1 : 0)\n")]);
  await run(page, ex);
  const finger = await page.waitForFunction(i => document.querySelector(`#pico-slot-${i} .pb-finger`).getAttribute("visibility") === "visible", ex, { timeout: 10000 }).then(() => true, () => false);
  check("demo: the bench script presses (finger shown)", finger);
  await shot(page, ex, "demo-exercise-de");
  await page.waitForFunction(() => window.__ran, null, { timeout: 30000 });
  const loop = demo.de.cells.findIndex(c => c.t === "c" && (c.board || {}).parts && c.board.parts.includes("button14"));
  await run(page, loop);
  await page.waitForTimeout(600);
  await page.click(`#pico-slot-${loop} .pico-stop`);
  await page.waitForTimeout(400);
  const d = await dbg(page);
  check("demo: ■ Stop resets the bench", d.reset === "reset" && /zurückgesetzt/.test(d.badge), JSON.stringify(d.badge));
  await shot(page, loop, "demo-reset-de");
  await ctx.close();
}

check("no page errors", errors.length === 0, errors.join(" | "));
await browser.close();
console.log(failures ? `${failures} FAILED` : "ALL BENCH CHECKS PASSED");
process.exit(failures ? 1 : 0);
