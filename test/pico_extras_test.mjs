// The Pico lessons' extras (docs/HANDOVER.md §6r) in a browser, against a
// dev server:
//
//   BASE=http://127.0.0.1:18111/ node test/pico_extras_test.mjs
//   SHOTS=dir ...   also saves screenshots (previews, webcam, deploy table)
//
// - pico-deploy's tables: the R2P2 file names never break, no word in the
//   boards table breaks inside, the page fits 360 px (de en ja, phone and
//   desktop).
// - The static previews: every board cell shows its bench before any run
//   (its parts, idle pins, "idle" badge, Stop disabled), the run makes that
//   cell's bench the live one and the cell before goes back to idle; an
//   input set on a preview goes with the next run and shows on the other
//   benches; the e-paper's picture shows on every e-paper preview; a
//   language switch and a lesson change rebuild them for the new page; the
//   robot waits at its start; a narrow slot gets a narrow bench.
// - The webcam (Chromium's fake camera): "Use my webcam" sends 160 x 120
//   grey frames as the camera input, the camera cell captures one, a
//   second click / a drawn picture / another lesson stop the stream; no
//   permission and no getUserMedia fall back to the drawn pictures.
import fs from "fs";
import path from "path";
import { chromium } from "/usr/local/lib/node_modules/playwright/index.mjs";

const BASE = process.env.BASE || "http://127.0.0.1:8011/";
const SHOTS = process.env.SHOTS || "";
if (SHOTS) fs.mkdirSync(SHOTS, { recursive: true });

let failures = 0, passes = 0;
const check = (name, cond, extra = "") => {
  console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra ? ` - ${String(extra).slice(0, 300)}` : ""}`);
  if (cond) passes++; else failures++;
};
const errors = [];
browser.it = await chromium.launch();
const until = (page, fn, arg, timeout = 5000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
const shot = async (target, name) => { if (SHOTS) await target.screenshot({ path: path.join(SHOTS, name) }).catch(() => {}); };

async function open(ctx, lang, hash, { width = 1280, board = true } = {}) {
  const page = await ctx.newPage();
  await page.setViewportSize({ width, height: 900 });
  page.on("pageerror", e => errors.push(`${hash}/${lang}: ${e.message}`));
  page.on("console", m => {
    if (m.type() === "error" && !/Failed to load resource/.test(m.text())) errors.push(`${hash}/${lang}: ${m.text().slice(0, 200)}`);
  });
  await page.goto(`${BASE}?lang=${lang}${hash}`, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  if (board) await page.waitForFunction(() => window.chunkyPicoRuby && window.chunkyPicoRuby.ready && window.chunkyPicoBoard, null, { timeout: 60000 });
  await page.evaluate(() => {
    window.__rans = [];
    window.addEventListener("chunky:ran", e => window.__rans.push(Number(e.detail.idx)));
  });
  return page;
}
async function run(page, idx, timeout = 70000) {
  const n = await page.evaluate(i => window.__rans.filter(x => x === i).length, idx);
  await page.click(`.run-cell[data-idx="${idx}"]`);
  await page.waitForFunction(([i, k]) => window.__rans.filter(x => x === i).length > k, [idx, n], { timeout });
}
const benches = page => page.evaluate(() => window.chunkyPicoBoard.benches());
// all board slots of the page have their bench (built one per frame)
const previewsDone = page => until(page, () => {
  const slots = [...document.querySelectorAll(".pico-slot")];
  return slots.length && slots.every(s => !s.hidden && s.querySelector(".pico-bench"));
}, null, 10000);
async function go(page, id) {
  await page.click(`#lessonNav a[data-id="${id}"]`);
  await until(page, x => location.hash === "#" + x && document.querySelector('.run-cell[data-idx="1"]'), id, 20000);
}

// ---------- pico-deploy: the boards table and the R2P2 files ----------
{
  for (const width of [360, 1280]) {
    const ctx = await browser().newContext({ viewport: { width, height: 800 }, isMobile: width < 400 });
    for (const lang of ["de", "en", "ja"]) {
      const page = await open(ctx, lang, "#pico-deploy", { width, board: false });
      await until(page, () => document.querySelector("dl.files"), null, 10000);
      const r = await page.evaluate(() => {
        const names = [...document.querySelectorAll(".lessonText dl.files dt code")];
        const lineH = c => parseFloat(getComputedStyle(c).lineHeight) || 20;
        // a word broken inside: a text node of one word on more than one line
        const broken = [];
        document.querySelectorAll(".lessonText table.boards th, .lessonText table.boards td").forEach(cell => {
          const walker = document.createTreeWalker(cell, NodeFilter.SHOW_TEXT);
          for (let n = walker.nextNode(); n; n = walker.nextNode()) {
            const re = /[A-Za-zÄÖÜäöü0-9]{3,}/g;
            let m;
            while ((m = re.exec(n.data))) {
              const range = document.createRange();
              range.setStart(n, m.index);
              range.setEnd(n, m.index + m[0].length);
              const tops = new Set([...range.getClientRects()].map(x => Math.round(x.top)));
              if (tops.size > 1) broken.push(m[0]);
            }
          }
        });
        return {
          names: names.map(c => c.textContent),
          oneLine: names.every(c => c.getClientRects().length === 1 && c.getBoundingClientRect().height < lineH(c) * 1.6),
          cols: [...document.querySelectorAll(".lessonText table.boards tr:first-child th")].length,
          old: !!document.querySelector(".lessonText table.boards code"),
          broken, scroll: document.documentElement.scrollWidth,
          // the boards' names ("Pico 2 W", ボード) on one line each, in every language
          firstCol: [...document.querySelectorAll(".lessonText table.boards tr > :first-child")]
            .filter(c => { const r = document.createRange(); r.selectNodeContents(c); return new Set([...r.getClientRects()].map(x => Math.round(x.top))).size > 1; })
            .map(c => c.textContent)
        };
      });
      const L = `pico-deploy/${lang} at ${width} px`;
      check(`${L}: two R2P2 files in a list`, r.names.length === 2 && r.names.every(n => /^R2P2-/.test(n)), r.names.join(" "));
      check(`${L}: each file name on one line`, r.oneLine);
      check(`${L}: the boards table has four columns, no file names in it`, r.cols === 4 && !r.old, r.cols);
      check(`${L}: no word breaks inside`, r.broken.length === 0, r.broken.join(" "));
      check(`${L}: each board's name on one line`, r.firstCol.length === 0, r.firstCol.join(" | "));
      check(`${L}: the page fits`, r.scroll <= width + 2, r.scroll);
      await shot(page.locator(".lessonText").first(), `deploy-${lang}-${width}.png`);
      await page.close();
    }
    await ctx.close();
  }
}

// ---------- the previews stay when Ruby boots ----------
// (the first sync_state of main.rb used to unmount and rebuild every bench
// about 2 s after load: an open USB panel closed, a started webcam stopped)
{
  const ctx = await browser().newContext({ locale: "en-US" });
  await ctx.addInitScript(() => {
    window.__benchGone = 0;
    window.__benchMade = 0;
    new MutationObserver(ms => ms.forEach(m => {
      m.addedNodes.forEach(n => { if (n.nodeType === 1 && n.matches(".pico-bench")) window.__benchMade++; });
      m.removedNodes.forEach(n => { if (n.nodeType === 1 && n.matches(".pico-bench")) window.__benchGone++; });
    })).observe(document, { childList: true, subtree: true });
  });
  const page = await open(ctx, "en", "#pico-blink");
  await previewsDone(page);
  await page.waitForTimeout(1500);
  const r = await page.evaluate(() => ({ made: window.__benchMade, gone: window.__benchGone, slots: document.querySelectorAll(".pico-slot").length }));
  check("previews: built once, not torn down when Ruby boots", r.gone === 0 && r.made === r.slots, JSON.stringify(r));
  await ctx.close();
}

// ---------- the static previews ----------
{
  const ctx = await browser().newContext({ locale: "en-US" });
  const page = await open(ctx, "en", "#pico-blink");
  check("previews: every board cell of pico-blink has its bench before any run", await previewsDone(page));
  let list = await benches(page);
  const slots = await page.evaluate(() => [...document.querySelectorAll(".pico-slot")].map(s => s.id.replace("pico-slot-", "")));
  check("previews: one bench per slot, all idle, none live", list.length === slots.length && list.every(b => !b.live && /idle/.test(b.badge)),
    JSON.stringify(list));
  check("previews: debug() has no live bench yet", await page.evaluate(() => window.chunkyPicoBoard.debug() === null));
  check("previews: the LED cell's preview draws the LED and its wires", await page.evaluate(() =>
    !!document.querySelector("#pico-slot-1 .pb-led15") && document.querySelectorAll("#pico-slot-1 .pb-wires path").length >= 2));
  check("previews: the pins are idle (no pin drawn high)", await page.evaluate(() => !document.querySelector(".pico-slot .pb-pinstate.is-high")));
  check("previews: Stop is disabled where nothing runs", await page.evaluate(() =>
    [...document.querySelectorAll(".pico-slot .pico-stop")].every(b => b.disabled)));
  check("previews: the SVG's text alternative names the parts", await page.evaluate(() =>
    /LED on GP15/.test(document.querySelector("#pico-slot-1 .pico-svg desc").textContent)));
  await shot(page.locator("#pico-slot-1"), "preview-blink-1.png");

  await run(page, 1);
  list = await benches(page);
  check("previews: ▶ makes that cell's bench the live one", list.filter(b => b.live).map(b => b.idx).join() === "1", JSON.stringify(list));
  check("previews: ...in place: no extra bench, the same slot", list.length === slots.length && await page.evaluate(() =>
    document.querySelectorAll("#pico-slot-1 .pico-bench").length === 1 && !document.querySelector("#pico-slot-1 .pico-stop").disabled));
  check("previews: ...and it drew the run's state", await page.evaluate(() => /"15":"o1"/.test(window.chunkyPicoBoard.debug().state) || /"15"/.test(window.chunkyPicoBoard.debug().state)));
  await run(page, 3);
  list = await benches(page);
  check("previews: the next cell's run moves the live bench, the cell before is idle again",
    list.find(b => b.idx === "3").live && /idle/.test(list.find(b => b.idx === "1").badge) && list.length === slots.length, JSON.stringify(list));
  check("previews: ...its pins drawn idle again", await page.evaluate(() => !document.querySelector("#pico-slot-1 .pb-pinstate.is-high")));
  await shot(page.locator("#pico-slot-3"), "live-blink-3.png");

  // a language switch: the benches again, in German
  await page.selectOption("#langSelect", "de");
  await until(page, () => document.documentElement.lang === "de" && /wartet/.test((document.querySelector("#pico-slot-1 .pico-badge") || {}).textContent || ""), null, 15000);
  await previewsDone(page);
  list = await benches(page);
  check("previews: a language switch rebuilds them, in the new language", list.length === slots.length && list.every(b => b.inPage && !b.live && /wartet/.test(b.badge)),
    JSON.stringify(list));
  check("previews: ...and no live bench is left over", await page.evaluate(() => window.chunkyPicoBoard.debug() === null));

  // inputs before ▶: pico-sensors' light slider
  await go(page, "pico-sensors");
  await previewsDone(page);
  list = await benches(page);
  check("previews: a lesson change drops the old benches", list.every(b => b.inPage) && list.some(b => b.parts.includes("light26")), JSON.stringify(list));
  const light = list.filter(b => b.parts.includes("light26")).map(b => b.idx);
  await page.evaluate(i => {
    const input = document.querySelector(`#pico-slot-${i} .pico-slider input`);
    input.value = "20";
    input.dispatchEvent(new Event("input", { bubbles: true }));
  }, light[0]);
  check("previews: an input set before ▶ is in the next run's inputs", await page.evaluate(() => JSON.parse(window.chunkyPicoBoard.inputs()).adc26 === "0.2"));
  check("previews: ...and the other light sliders follow it", light.length < 2 || await page.evaluate(i => document.querySelector(`#pico-slot-${i} .pico-slider input`).value === "20", light[1]));
  await run(page, Number(light[0]));
  const out = await page.evaluate(i => document.getElementById("cell-out-" + i).textContent, light[0]);
  check("previews: ...and the run reads it (0.66 V)", /0[.,]6[0-9]/.test(out), out.slice(0, 200));

  // the robot at its start; the e-paper's picture on every e-paper preview
  await go(page, "pico-robot");
  await previewsDone(page);
  check("previews: the robot waits at its start in every arena", await page.evaluate(() => {
    const robots = [...document.querySelectorAll(".pico-slot .pb-robot")];
    return robots.length >= 2 && robots.every(r => /rotate\((-)?0(\.0)?\)/.test(r.getAttribute("transform")));
  }));
  await shot(page.locator("#pico-slot-5"), "preview-robot-5.png");
  await go(page, "pico-epaper");
  await previewsDone(page);
  const epd = (await benches(page)).filter(b => b.parts.includes("epd213")).map(b => b.idx);
  check("previews: the e-paper starts blank", await page.evaluate(() => [...document.querySelectorAll(".pico-slot .pb-epd-image")].every(i => !i.getAttribute("href"))));
  await run(page, Number(epd[0]));
  await until(page, () => (window.chunkyPicoBoard.debug() || {}).frames >= 1, null, 30000);
  check("previews: the panel's picture shows on every e-paper bench", await page.evaluate(ids => ids.every(i =>
    /^data:image\/png/.test(document.querySelector(`#pico-slot-${i} .pb-epd-image`).getAttribute("href") || "")), epd));
  await shot(page.locator(`#pico-slot-${epd[1]}`), "preview-epaper-kept.png");
  await page.close();

  // a phone: narrow benches, the page fits
  const phone = await browser().newContext({ locale: "en-US", viewport: { width: 360, height: 740 }, isMobile: true, hasTouch: true });
  const small = await phone.newPage();
  small.on("pageerror", e => errors.push(`phone: ${e.message}`));
  await small.goto(`${BASE}?lang=en#pico-ble`, { waitUntil: "domcontentloaded" });
  await small.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready && window.chunkyPicoBoard, null, { timeout: 120000 });
  await previewsDone(small);
  check("previews: a 360 px phone gets narrow benches and fits", await small.evaluate(() =>
    document.documentElement.scrollWidth <= 362 && [...document.querySelectorAll(".pico-slot .pico-svg")].every(s => s.getBoundingClientRect().width <= 360)));
  await shot(small.locator("#pico-slot-5"), "preview-ble-5-phone.png");
  await phone.close();
  await ctx.close();
}

// ---------- the webcam ----------
{
  const cam = await chromium.launch({ args: ["--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream"] });
  const ctx = await cam.newContext({ locale: "en-US", permissions: ["camera"] });
  // the streams the page got, to see that they stop
  await ctx.addInitScript(() => {
    window.__streams = [];
    const md = navigator.mediaDevices;
    if (md && md.getUserMedia) {
      const real = md.getUserMedia.bind(md);
      md.getUserMedia = c => real(c).then(s => { window.__streams.push(s); return s; });
    }
  });
  const page = await open(ctx, "en", "#pico-epaper");
  await previewsDone(page);
  const camIdx = (await benches(page)).find(b => b.parts.includes("camera")).idx;
  const btn = page.locator(`#pico-slot-${camIdx} .pico-webcam`);
  check("webcam: the camera card has the opt-in button, off", await btn.count() === 1 && await btn.getAttribute("aria-pressed") === "false");
  check("webcam: off by default, no stream asked for", await page.evaluate(() => window.__streams.length === 0 && !window.chunkyPicoBoard.webcam().on));
  await btn.click();
  const on = await until(page, () => window.chunkyPicoBoard.webcam().on && window.chunkyPicoBoard.webcam().frame > 0, null, 10000);
  const w = await page.evaluate(() => window.chunkyPicoBoard.webcam());
  check("webcam: a click turns it on (button pressed, camera = webcam)", on && w.camera === "webcam" && await btn.getAttribute("aria-pressed") === "true", JSON.stringify(w));
  check("webcam: the frame is a 160 x 120 PGM in hex", w.frame === ("P5\n160 120\n255\n".length + 160 * 120) * 2 &&
    await page.evaluate(() => JSON.parse(window.chunkyPicoBoard.inputs())["camera.frame"].startsWith("50350a")), w.frame);
  check("webcam: the note says the pictures stay in the browser", /stay in this browser/.test(w.note));
  const idle = await page.evaluate(async () => {
    const pr = window.chunkyPicoRuby, real = pr.input;
    let frames = 0;
    pr.input = function (k, v) { if (k === "camera.frame") frames++; return real.apply(this, arguments); };
    await new Promise(r => setTimeout(r, 1000));
    pr.input = real;
    return { frames, busy: pr.busy() };
  });
  check("webcam: no frames to the worker while nothing runs (each run takes the newest with its inputs)", idle.frames === 0 && !idle.busy, JSON.stringify(idle));
  check("webcam: the card shows the webcam's view", await page.evaluate(i => {
    const img = document.querySelector(`#pico-slot-${i} .pb-photo`);
    return /^data:image\/png/.test(img.getAttribute("href") || "") && img.classList.contains("is-live");
  }, camIdx));
  await page.waitForTimeout(600);
  await shot(page.locator(`#pico-slot-${camIdx}`), "webcam-on.png");
  await run(page, Number(camIdx));
  const d = await page.evaluate(() => window.chunkyPicoBoard.debug());
  check("webcam: the camera cell captures a webcam frame", d.log.some(l => l[0] === "log" && l[1] === "camera webcam"), JSON.stringify(d.log.slice(-5)));
  check("webcam: ...and the e-paper shows it", d.frames >= 1 && d.black > 0 && d.black < 250 * 122, d.black);
  await shot(page.locator(`#pico-slot-${camIdx}`), "webcam-captured.png");
  await btn.click();
  check("webcam: a second click stops the stream, the drawn picture is back", await until(page, () =>
    !window.chunkyPicoBoard.webcam().on && window.__streams.every(s => s.getTracks().every(t => t.readyState === "ended")) &&
    JSON.parse(window.chunkyPicoBoard.inputs()).camera !== "webcam" && !JSON.parse(window.chunkyPicoBoard.inputs())["camera.frame"]));
  await btn.click();
  await until(page, () => window.chunkyPicoBoard.webcam().on, null, 10000);
  await page.selectOption(`#pico-slot-${camIdx} select`, "bacon");
  check("webcam: choosing a drawn picture stops it", await until(page, () =>
    !window.chunkyPicoBoard.webcam().on && window.__streams.every(s => s.getTracks().every(t => t.readyState === "ended")) &&
    JSON.parse(window.chunkyPicoBoard.inputs()).camera === "bacon"));
  await btn.click();
  await until(page, () => window.chunkyPicoBoard.webcam().on, null, 10000);
  await go(page, "pico-wifi");
  check("webcam: another lesson stops the stream", await until(page, () =>
    window.__streams.length >= 3 && window.__streams.every(s => s.getTracks().every(t => t.readyState === "ended")) && !window.chunkyPicoBoard.webcam().on, null, 10000));
  await page.close();

  // a drawn picture chosen while the browser still asks for permission: the
  // late yes must not switch to the webcam
  {
    const c3 = await cam.newContext({ locale: "en-US", permissions: ["camera"] });
    await c3.addInitScript(() => {
      window.__streams = [];
      const md = navigator.mediaDevices, real = md.getUserMedia.bind(md);
      md.getUserMedia = c => new Promise(res => { window.__grant = () => res(real(c).then(s => { window.__streams.push(s); return s; })); });
    });
    const p3 = await open(c3, "en", "#pico-epaper");
    await previewsDone(p3);
    await p3.click(`#pico-slot-${camIdx} .pico-webcam`);
    await until(p3, () => typeof window.__grant === "function");
    await p3.selectOption(`#pico-slot-${camIdx} select`, "bacon");
    await p3.evaluate(() => window.__grant());
    await until(p3, () => window.__streams.length === 1, null, 5000);
    await p3.waitForTimeout(300);
    const r3 = await p3.evaluate(i => ({ on: window.chunkyPicoBoard.webcam().on, camera: JSON.parse(window.chunkyPicoBoard.inputs()).camera,
      ended: window.__streams.every(s => s.getTracks().every(t => t.readyState === "ended")),
      pressed: document.querySelector(`#pico-slot-${i} .pico-webcam`).getAttribute("aria-pressed"),
      disabled: document.querySelector(`#pico-slot-${i} .pico-webcam`).disabled }), camIdx);
    check("webcam: a drawn picture chosen during the permission prompt wins (stream stopped, button usable)",
      !r3.on && r3.camera === "bacon" && r3.ended && r3.pressed === "false" && !r3.disabled, JSON.stringify(r3));
    await c3.close();
  }

  // no permission, then no getUserMedia at all (an insecure page): the
  // drawn pictures stay, and the note says why
  for (const how of ["denied", "missing"]) {
    const c2 = await cam.newContext({ locale: "en-US" });
    await c2.addInitScript(h => {
      if (h === "missing") Object.defineProperty(navigator, "mediaDevices", { value: undefined });
      else navigator.mediaDevices.getUserMedia = () => Promise.reject(new DOMException("Permission denied", "NotAllowedError"));
    }, how);
    const p2 = await open(c2, "en", "#pico-epaper");
    await previewsDone(p2);
    await p2.click(`#pico-slot-${camIdx} .pico-webcam`);
    const ok = await until(p2, () => /No webcam here/.test(window.chunkyPicoBoard.webcam().note), null, 5000);
    const w2 = await p2.evaluate(() => window.chunkyPicoBoard.webcam());
    check(`webcam: ${how === "denied" ? "no permission" : "no getUserMedia"} - the note says so, the drawn pictures stay`,
      ok && !w2.on && w2.camera !== "webcam" && await p2.getAttribute(`#pico-slot-${camIdx} .pico-webcam`, "aria-pressed") === "false", JSON.stringify(w2));
    if (how === "denied") await shot(p2.locator(`#pico-slot-${camIdx} .pico-controls`), "webcam-denied.png");
    if (how === "denied") {
      await run(p2, Number(camIdx));
      const d2 = await p2.evaluate(() => window.chunkyPicoBoard.debug());
      check("webcam: ...and the camera cell takes the drawn picture", d2.log.some(l => l[1] === "camera chunky"), JSON.stringify(d2.log.slice(-4)));
    }
    await c2.close();
  }
  await cam.close();
}

check("no page errors", errors.length === 0, errors.join(" | "));
await browser().close();
console.log(`${passes} passed, ${failures} failed`);
console.log(failures ? `${failures} FAILED` : "ALL PICO EXTRAS CHECKS PASSED");
process.exit(failures ? 1 : 0);

function browser() { return browser.it; }
