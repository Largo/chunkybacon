// The real-Pico panels under the benches (html/pico_real.js, docs/HANDOVER.md
// §6r) in a browser, against a dev server:
//
//   BASE=http://127.0.0.1:18111/ node test/pico_real_ui_test.mjs
//   SHOTS=dir ...   also saves screenshots
//
// The browser's Web Serial and Web Bluetooth are replaced by the fakes of
// test/pico_real_fakes.js (a fake R2P2 behind a fake port, a fake Pico 2 W
// running BLE::UART) - no hardware is involved anywhere.
//
// - every board cell's bench has a folded "A real Pico (USB)" panel; only
//   benches with the laptop have the Bluetooth one;
// - no Web Serial / Web Bluetooth: a note says which browsers have it, no
//   button; not a secure context: a note says https or localhost (de en ja);
// - connect: the terminal shows R2P2's prompt; "Send" writes the cell's
//   code (and its tabs, the e-paper driver as the page shows it) and runs
//   it, the output shows; Ctrl-C; the cable out; disconnect;
// - Bluetooth in pico-ble: the laptop's line goes to the real Pico 2 W,
//   its answer shows on the laptop's screen and reaches the CRuby cell,
//   which finds and writes to the real Pico; disconnect gives the
//   simulated radio back.
import fs from "fs";
import path from "path";
import { chromium } from "/usr/local/lib/node_modules/playwright/index.mjs";

const BASE = process.env.BASE || "http://127.0.0.1:8011/";
const SHOTS = process.env.SHOTS || "";
if (SHOTS) fs.mkdirSync(SHOTS, { recursive: true });
const here = path.dirname(new URL(import.meta.url).pathname);
const FAKES = path.join(here, "pico_real_fakes.js");

let failures = 0, passes = 0;
const check = (name, cond, extra = "") => {
  console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra !== "" ? ` - ${String(extra).slice(0, 300)}` : ""}`);
  if (cond) passes++; else failures++;
};
const errors = [];
const browser = await chromium.launch();
const until = (page, fn, arg, timeout = 8000) => page.waitForFunction(fn, arg, { timeout }).then(() => true, () => false);
const shot = async (target, name) => { if (SHOTS) await target.screenshot({ path: path.join(SHOTS, name) }).catch(() => {}); };

// +mode+: "fake" (fake serial + bluetooth), "noapi", "insecure"
async function open(lang, hash, mode, { width = 1280, dark = false } = {}) {
  const ctx = await browser.newContext({ locale: lang === "de" ? "de-DE" : "en-US", viewport: { width, height: 900 }, colorScheme: dark ? "dark" : "light" });
  await ctx.addInitScript({ path: FAKES });
  await ctx.addInitScript(m => {
    if (m === "noapi") {
      delete Navigator.prototype.serial;
      delete Navigator.prototype.bluetooth;
    } else if (m === "insecure") {
      Object.defineProperty(window, "isSecureContext", { get: () => false });
    } else {
      // one fake R2P2 for the page, one fake Pico 2 W
      window.__dev = new window.PicoRealFakes.FakeR2P2();
      window.__port = new window.PicoRealFakes.FakeSerialPort(window.__dev);
      window.__asked = [];
      const listeners = {};
      const serial = {
        requestPort(opts) { window.__asked.push(opts); return window.__cancel ? Promise.reject(Object.assign(new Error("No port selected by the user."), { name: "NotFoundError" })) : Promise.resolve(window.__port); },
        getPorts() { return Promise.resolve([]); },
        addEventListener(t, f) { (listeners[t] = listeners[t] || []).push(f); },
        fire(t, e) { (listeners[t] || []).forEach(f => f(e)); }
      };
      Object.defineProperty(Navigator.prototype, "serial", { get: () => serial, configurable: true });
      window.__bt = new window.PicoRealFakes.FakeBluetooth("PicoRuby");
      Object.defineProperty(Navigator.prototype, "bluetooth", { get: () => window.__bt, configurable: true });
    }
  }, mode);
  const page = await ctx.newPage();
  page.on("pageerror", e => errors.push(`${hash}/${lang}/${mode}: ${e.message}`));
  page.on("console", m => {
    if (m.type() === "error" && !/Failed to load resource/.test(m.text())) errors.push(`${hash}/${lang}/${mode}: ${m.text().slice(0, 200)}`);
  });
  await page.goto(`${BASE}?lang=${lang}${hash}`, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  await page.waitForFunction(() => window.chunkyPicoRuby && window.chunkyPicoRuby.ready && window.chunkyPicoBoard && window.chunkyPicoReal, null, { timeout: 60000 });
  await until(page, () => document.querySelectorAll(".pico-slot").length > 0 &&
    window.chunkyPicoBoard.benches().length === document.querySelectorAll(".pico-slot").length, null, 20000);
  return { ctx, page };
}
const lessonBoards = (page, id) => page.evaluate(id => {
  const l = window.LESSONS.lessons.find(x => x.id === id).en;
  return l.cells.map((c, i) => c.board ? { idx: i, parts: c.board.parts || [] } : null).filter(Boolean);
}, id);

// ---------- capabilities ----------
for (const lang of ["de", "en", "ja"]) {
  const { ctx, page } = await open(lang, "#pico-blink", "noapi");
  const r = await page.evaluate(() => ({
    panels: document.querySelectorAll(".pico-bench .pico-real-usb").length,
    benches: document.querySelectorAll(".pico-bench").length,
    notes: [...document.querySelectorAll(".pico-real-usb .pico-real-note")].map(n => n.dataset.why),
    buttons: document.querySelectorAll(".pico-real-connect").length,
    ble: document.querySelectorAll(".pico-real-ble").length,
    open: document.querySelectorAll(".pico-real[open]").length,
    text: document.querySelector(".pico-real-note") && document.querySelector(".pico-real-note").textContent,
    sup: window.chunkyPicoReal.serialSupport()
  }));
  check(`${lang} no Web Serial: a folded USB panel on every bench`, r.panels === r.benches && r.benches > 3 && r.open === 0, JSON.stringify(r));
  check(`${lang} no Web Serial: the note, no button`, r.notes.every(w => w === "api") && r.buttons === 0 && r.sup.why === "api", JSON.stringify(r));
  check(`${lang} no Web Serial: names the browsers that have it`, /Chrome/.test(r.text || ""), r.text);
  check(`${lang} pico-blink has no laptop: no Bluetooth panel`, r.ble === 0);
  await ctx.close();
}
for (const lang of ["de", "en", "ja"]) {
  const { ctx, page } = await open(lang, "#pico-ble", "insecure");
  await page.evaluate(() => document.querySelectorAll(".pico-real").forEach(d => { d.open = true; }));
  const r = await page.evaluate(() => ({
    usb: [...document.querySelectorAll(".pico-real-usb .pico-real-note")].map(n => n.dataset.why),
    ble: [...document.querySelectorAll(".pico-real-ble .pico-real-note")].map(n => n.dataset.why),
    text: document.querySelector(".pico-real-ble .pico-real-note").textContent,
    buttons: document.querySelectorAll(".pico-real-connect").length
  }));
  const boards = await lessonBoards(page, "pico-ble");
  const laptops = boards.filter(b => b.parts.includes("laptop")).length;
  check(`${lang} plain http: the USB and Bluetooth notes say why`, r.usb.length === boards.length && r.usb.every(w => w === "insecure") && r.ble.length === laptops && r.ble.every(w => w === "insecure"), JSON.stringify(r));
  check(`${lang} plain http: the note names https and localhost`, /https:\/\/chunkybacon\.idogawa\.com/.test(r.text) && /localhost/.test(r.text) && r.buttons === 0, r.text);
  if (lang === "en") {
    const fig = await page.$(`#pico-slot-${boards[0].idx} .pico-bench`);
    if (fig) await shot(fig, "insecure-ble-en.png");
  }
  await ctx.close();
}

// ---------- USB with the fake R2P2 ----------
{
  const { ctx, page } = await open("en", "#pico-blink", "fake");
  const boards = await lessonBoards(page, "pico-blink");
  const idx = boards[1].idx;      // the 10x blink
  const sel = `#pico-slot-${idx} .pico-real-usb`;
  await page.click(`${sel} > summary`);
  check("USB: opens, the connect button, the port list filtered to R2P2", await page.isVisible(`${sel} .pico-real-connect`));
  await page.evaluate(() => { window.__cancel = true; });
  await page.click(`${sel} .pico-real-connect`);
  check("USB: no device chosen says so", await until(page, s => document.querySelector(s + " .pico-real-status").textContent === "No device chosen.", sel));
  await page.evaluate(() => { window.__cancel = false; });
  await page.click(`${sel} .pico-real-connect`);
  check("USB: asked for R2P2's vendor id 0x16C0", await page.evaluate(() => JSON.stringify(window.__asked[1]) === JSON.stringify({ filters: [{ usbVendorId: 0x16C0 }] })), await page.evaluate(() => JSON.stringify(window.__asked)));
  check("USB: opened at 115200", await page.evaluate(() => window.__port.opened && window.__port.opened.baudRate === 115200));
  check("USB: connected, the terminal shows R2P2's prompt", await until(page, s => /\$>/.test(document.querySelector(s + " .pico-real-term").textContent), sel),
        await page.evaluate(s => document.querySelector(s).textContent, sel));
  check("USB: the other benches' panels say connected too", await page.evaluate(() => [...document.querySelectorAll(".pico-real-usb .pico-real-status")].every(p => /^Connected/.test(p.textContent))));
  const code = await page.evaluate(i => window.getCellCode(i), idx);
  await page.click(`${sel} .pico-real-send`);
  check("USB: Send writes /home/chunky.rb and runs it", await until(page, () => window.__dev.runs.includes("/home/chunky.rb"), null, 15000), await page.evaluate(() => JSON.stringify(window.__dev.runs)));
  check("USB: the file is the cell's code", await page.evaluate(c => window.__dev.text("/home/chunky.rb") === c, code));
  check("USB: status says it runs", await until(page, s => /runs on the Pico/.test(document.querySelector(s + " .pico-real-status").textContent), sel));
  await shot(await page.$(`#pico-slot-${idx} .pico-bench`), "usb-connected-en.png");
  // type a line, Ctrl-C
  await page.fill(`${sel} .pico-real-type input`, "irb");
  await page.press(`${sel} .pico-real-type input`, "Enter");
  check("USB: a typed line reaches the shell", await until(page, () => window.__dev.mode === "irb"));
  check("USB: irb's prompt in the terminal", await until(page, s => /irb>/.test(document.querySelector(s + " .pico-real-term").textContent), sel));
  // send from irb: Ctrl-D first
  await page.click(`${sel} .pico-real-send`);
  check("USB: Send from irb gets back to the shell first", await until(page, () => window.__dev.runs.filter(r => r === "/home/chunky.rb").length === 2, null, 15000));
  // as app.rb
  await page.check(`${sel} .pico-real-buttons input[type=checkbox] >> nth=-1`);
  // while a cell goes over, no Ctrl-C or typed byte may land inside a PicoModem frame
  const during = await page.evaluate(async s => {
    document.querySelector(s + " .pico-real-send").click();
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    const q = c => document.querySelector(s + " " + c);
    return { busy: window.chunkyPicoReal.state().serial.busy, send: q(".pico-real-send").disabled, ctrlc: q(".pico-real-ctrlc").disabled,
             line: q(".pico-real-type input").disabled, go: q(".pico-real-type button").disabled };
  }, sel);
  check("USB: while sending, Send, Ctrl-C and the Type form are disabled", during.busy && during.send && during.ctrlc && during.line && during.go, JSON.stringify(during));
  check("USB: as /home/app.rb", await until(page, () => window.__dev.text("/home/app.rb") !== null && window.__dev.runs.includes("/home/app.rb"), null, 15000));
  // the cable out
  await page.evaluate(() => { window.__port.unplug(); });
  check("USB: unplugged says so, the connect button is back", await until(page, s => /gone/.test(document.querySelector(s + " .pico-real-status").textContent) && !document.querySelector(s + " .pico-real-connect").hidden, sel));
  await ctx.close();
}
{
  // a cell with a tab: the driver goes to /lib as the page shows it
  const { ctx, page } = await open("de", "#pico-epaper", "fake", { width: 360 });
  const boards = await lessonBoards(page, "pico-epaper");
  const idx = boards[0].idx;
  const sel = `#pico-slot-${idx} .pico-real-usb`;
  await page.click(`${sel} > summary`);
  await page.click(`${sel} .pico-real-connect`);
  await until(page, s => /\$>/.test(document.querySelector(s + " .pico-real-term").textContent), sel);
  await page.click(`${sel} .pico-real-send`);
  check("USB de: a cell with tabs: /lib/epd2in13.rb then the code", await until(page, () => window.__dev.runs.includes("/home/chunky.rb"), null, 20000));
  const tabs = await page.evaluate(i => JSON.parse(window.getCellTabs(i)), idx);
  const sent = await page.evaluate(() => ({ lib: window.__dev.text("/lib/epd2in13.rb"), main: window.__dev.text("/home/chunky.rb") }));
  check("USB de: the driver tab arrived unchanged", tabs.length >= 1 && sent.lib === tabs.find(t => t.name === "epd2in13.rb").code && sent.lib.length > 500, (sent.lib || "").length);
  check("USB de: the code forgets the driver's earlier require first", /^\[.*"\/lib\/epd2in13\.rb".*\]\.each \{ \|f\| \$LOADED_FEATURES\.delete\(f\) \}/.test(sent.main), (sent.main || "").slice(0, 120));
  check("USB de: German status", await page.evaluate(s => /läuft auf dem Pico/.test(document.querySelector(s + " .pico-real-status").textContent), sel));
  const fit = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
  check("USB de 360 px: the page still fits", fit);
  await shot(await page.$(`#pico-slot-${idx} .pico-real-usb`), "usb-de-360.png");
  await page.click(`${sel} .pico-real-close`);
  check("USB de: Trennen", await until(page, s => /Nicht verbunden/.test(document.querySelector(s + " .pico-real-status").textContent), sel));
  await ctx.close();
}
{
  // dark, ja
  const { ctx, page } = await open("ja", "#pico-sensors", "fake", { dark: true });
  const boards = await lessonBoards(page, "pico-sensors");
  const sel = `#pico-slot-${boards[0].idx} .pico-real-usb`;
  await page.click(`${sel} > summary`);
  await page.click(`${sel} .pico-real-connect`);
  check("USB ja: connected in Japanese", await until(page, s => /接続しました/.test(document.querySelector(s + " .pico-real-status").textContent), sel));
  await shot(await page.$(`#pico-slot-${boards[0].idx} .pico-bench`), "usb-ja-dark.png");
  await ctx.close();
}

// ---------- Bluetooth with the fake Pico 2 W ----------
{
  const { ctx, page } = await open("en", "#pico-ble", "fake");
  const boards = await lessonBoards(page, "pico-ble");
  const laptops = boards.filter(b => b.parts.includes("laptop"));
  const n = await page.evaluate(() => document.querySelectorAll(".pico-real-ble").length);
  check("BLE: a Bluetooth panel on each bench with the laptop", n === laptops.length && n > 0, `${n} vs ${laptops.length}`);
  const idx = laptops[0].idx;
  const sel = `#pico-slot-${idx} .pico-real-ble`;
  await page.click(`${sel} > summary`);
  await page.click(`${sel} .pico-real-connect`);
  check("BLE: asked for the Nordic UART Service", await until(page, () => window.__bt.asked && window.__bt.asked.filters[0].services[0] === "6e400001-b5a3-f393-e0a9-e50e24dcca9e"));
  check("BLE: connected, named", await until(page, s => /Connected to PicoRuby/.test(document.querySelector(s + " .pico-real-status").textContent), sel));
  check("BLE: chunkyPicoBoard.ble() reports the real one", await page.evaluate(() => { const b = JSON.parse(window.chunkyPicoBoard.ble()); return b.real && b.adv === "PicoRuby" && b.connected && b.running; }));
  check("BLE: the laptop's screen names it as real", await until(page, i => /PicoRuby \(real\)/.test(document.querySelector(`#pico-slot-${i} .pb-term-head`).textContent), idx));
  await page.evaluate(() => { window.__events = []; window.addEventListener("chunky:pico-ble", e => window.__events.push(e.detail.text)); });
  await page.fill(`#pico-slot-${idx} .pico-laptop-form input[type=text]`, "PING");
  await page.click(`#pico-slot-${idx} .pico-laptop-form .pico-send`);
  check("BLE: the laptop's line went to the real Pico", await until(page, () => (window.__bt.got || []).includes("PING")));
  check("BLE: its answer on the laptop's screen", await until(page, i => [...document.querySelectorAll(`#pico-slot-${i} .pb-term`)].some(t => t.textContent === "← PONG"), idx));
  check("BLE: and once as chunky:pico-ble", await page.evaluate(() => window.__events.length === 1 && window.__events[0] === "PONG\n"), await page.evaluate(() => JSON.stringify(window.__events)));
  await shot(await page.$(`#pico-slot-${idx} .pico-bench`), "ble-connected-en.png");
  // the CRuby cell finds the real Pico and writes to it; a notification reaches its block
  const cruby = await page.evaluate(() => window.LESSONS.lessons.find(x => x.id === "pico-ble").en.cells.findIndex(c => c.engine === "cruby"));
  await page.click(`.run-cell[data-idx="${cruby}"]`);
  check("BLE: the CRuby cell wrote to the real Pico", await until(page, () => (window.__bt.got || []).some(l => /^hello from CRuby/.test(l)), null, 60000), await page.evaluate(() => JSON.stringify(window.__bt.got)));
  await page.evaluate(() => window.__bt.notify("T 21.5\n"));
  check("BLE: the real Pico's line reaches the CRuby cell's block", await until(page, i => /T 21\.5/.test((document.querySelector(`.run-cell[data-idx="${i}"]`).closest(".cell") || document.body).textContent), cruby, 10000));
  await page.click(`${sel} .pico-real-close`);
  check("BLE: disconnected, the simulated radio is back", await until(page, () => !JSON.parse(window.chunkyPicoBoard.ble()).real));
  check("BLE: Disconnect says not connected (not \"went away\")", await until(page, s => /^Not connected/.test(document.querySelector(s + " .pico-real-status").textContent), sel),
        await page.evaluate(s => document.querySelector(s + " .pico-real-status").textContent, sel));
  await ctx.close();
}

await browser.close();
check("no page errors", errors.length === 0, errors.join(" | "));
console.log(`\n${passes} passed, ${failures} failed`);
process.exit(failures ? 1 : 0);
