// Playwright checks and measurements for the embed prototype.
//
//   PORT=18109 ruby experiments/09-embed-cell/serve_embed.rb      (background)
//   PLAYWRIGHT_DIR=.../node_modules/playwright node experiments/09-embed-cell/test_embed.mjs [check|measure|all]
//
// Two made-up sites on the one local server (host-resolver rules):
// blog.test (the page that embeds) and embed.test (the course).
import { pathToFileURL } from "node:url";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { writeFileSync, rmSync } from "node:fs";

const here = dirname(fileURLToPath(import.meta.url));
const PW = process.env.PLAYWRIGHT_DIR ||
  join(process.env.USERPROFILE || "", "AppData/Local/npm-cache/_npx/e41f203b7505f1fb/node_modules/playwright");
const { chromium } = await import(pathToFileURL(join(PW, "index.mjs")).href);

const PORT = process.env.PORT || "18109";
const EMBED = `http://embed.test:${PORT}/`;
const BLOG = `http://blog.test:${PORT}/`;
const mode = process.argv[2] || "all";
const RUNS = Number(process.env.RUNS || 3);

const browser = await chromium.launch({
  args: [`--host-resolver-rules=MAP embed.test 127.0.0.1, MAP blog.test 127.0.0.1`]
});

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "ok  " : "FAIL"} ${name}${detail ? " - " + detail : ""}`);
  if (!ok) failures += 1;
}

// the address for some code, as embed.js / make_embed_url.rb make it
async function embedUrl(page, code, options = {}, query = "") {
  return page.evaluate(async ([code, options, base, query]) => {
    const stream = new Blob([new TextEncoder().encode(code)]).stream().pipeThrough(new CompressionStream("deflate-raw"));
    const bytes = new Uint8Array(await new Response(stream).arrayBuffer());
    let bin = ""; bytes.forEach((b) => { bin += String.fromCharCode(b); });
    const frag = new URLSearchParams({ code: btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""), ...options });
    return `${base}embed.html${query}#${frag}`;
  }, [code, options, EMBED, query]);
}

async function frameOf(page, selector) {
  const handle = await page.waitForSelector(selector, { timeout: 30000 });
  for (let i = 0; i < 100; i++) {
    const frame = await handle.contentFrame();
    if (frame && frame.url().includes("embed.html")) return { handle, frame };
    await page.waitForTimeout(100);
  }
  throw new Error(`no frame for ${selector}`);
}

async function runAndWait(frame) {
  await frame.waitForSelector("#runBtn:not([disabled])");
  await frame.click("#runBtn");
  await frame.waitForFunction(() => {
    const out = document.getElementById("cell-out-0");
    return out && out.style.display !== "none" && !document.getElementById("cell").classList.contains("running");
  }, null, { timeout: 120000 });
  return frame.$eval("#cell-out-0", (el) => el.innerText);
}

async function checks() {
  const context = await browser.newContext({ viewport: { width: 900, height: 900 } });
  const page = await context.newPage();
  const logs = [];
  page.on("console", (m) => { if (m.type() === "error") logs.push(m.text()); });
  const wasmRequests = [];
  page.on("request", (r) => { if (r.url().includes("ruby+stdlib.wasm")) wasmRequests.push(r.frame().url()); });

  await page.goto(BLOG + "demo/host.html");
  check("embed.js upgraded the <pre data-chunky> blocks", (await page.$$("pre[data-chunky]")).length === 0);

  const first = await frameOf(page, "iframe[data-chunky-id='chunky-1']");
  await first.frame.waitForSelector(".CodeMirror");
  const shown = await first.frame.$eval(".CodeMirror", (el) => el.innerText);
  check("the first cell shows its code in the editor", shown.includes("words.tally"), shown.split("\n").slice(0, 2).join(" | "));
  check("the code's indentation was taken off", !shown.includes("    words"));
  const origin = await first.frame.evaluate(() => origin);
  check("the embed runs in an opaque origin (CSP sandbox header)", origin === "null", origin);

  const out1 = await runAndWait(first.frame);
  check("Run gives the result", out1.includes('"chunky" => 2'), out1.trim());
  await page.waitForTimeout(300);
  const [frameH, docH] = await Promise.all([
    first.handle.evaluate((f) => f.getBoundingClientRect().height),
    first.frame.evaluate(() => Math.ceil(document.documentElement.getBoundingClientRect().height))
  ]);
  check("the iframe followed the cell's height (postMessage)", Math.abs(frameH - docH) <= 1, `${frameH} vs ${docH}`);
  await first.handle.screenshot({ path: join(here, "screenshots/cell-result.png") });

  const png = await frameOf(page, "iframe[data-chunky-id='chunky-2']");
  await png.handle.scrollIntoViewIfNeeded();
  const out2 = await runAndWait(png.frame);
  const img = await png.frame.$("#cell-out-0 img.cell-image");
  check("data-gems=chunky_png: show_image draws a picture", Boolean(img), out2.trim().slice(0, 80));
  await png.handle.screenshot({ path: join(here, "screenshots/cell-chunky-png.png") });

  const hand = await frameOf(page, "#handwritten");
  await hand.handle.scrollIntoViewIfNeeded();
  await hand.frame.waitForSelector(".CodeMirror");
  await page.waitForTimeout(1500);
  const loadedBefore = wasmRequests.filter((u) => u.includes("load=click")).length;
  check("load=click: no ruby.wasm before Run", loadedBefore === 0, `${loadedBefore} requests`);
  await hand.handle.screenshot({ path: join(here, "screenshots/cell-before-run.png") });
  const out3 = await runAndWait(hand.frame);
  check("load=click: Run loads Ruby and runs", out3.includes('"FizzBuzz"'), out3.trim().slice(0, 60));

  const probe = await frameOf(page, "iframe[data-chunky-id='chunky-3']");
  const before = wasmRequests.length;
  await page.waitForTimeout(1500);
  check("load=visible: a cell out of view loads no Ruby", wasmRequests.length === before);
  await probe.handle.scrollIntoViewIfNeeded();
  const out4 = await runAndWait(probe.frame);
  check("embedded code sees no localStorage", /local_storage: "blocked \(JS::Error: SecurityError/.test(out4.replace(/\n/g, " ")) ||
    out4.includes('local_storage: "blocked'), out4.replace(/\s+/g, " ").slice(0, 300));
  await probe.handle.screenshot({ path: join(here, "screenshots/cell-probe-sandboxed.png") });
  await page.evaluate(() => scrollTo(0, 0));
  await page.waitForTimeout(600);
  await page.screenshot({ path: join(here, "screenshots/host-page.png") });

  // the same probe without the sandbox header: what an embed on the
  // course's own origin could read - progress, and with it any key
  const course = await context.newPage();
  await course.goto(EMBED + "embed-ui.js");
  await course.evaluate(() => localStorage.setItem("chunky_done", '["hallo","methoden","klassen"]'));
  const probeCode = await probe.frame.evaluate(() => window.getCellCode());
  await course.goto(await embedUrl(course, probeCode, { run: "1" }, "?nosandbox"));
  await course.waitForFunction(() => document.getElementById("cell-out-0").style.display !== "none", null, { timeout: 120000 });
  const open = await course.$eval("#cell-out-0", (el) => el.innerText);
  check("without the sandbox, embedded code reads the course's progress", open.includes("methoden"), open.replace(/\s+/g, " ").slice(0, 300));
  await course.screenshot({ path: join(here, "screenshots/cell-probe-unsandboxed.png") });

  // strict CSP on top of the sandbox: does the kernel still run?
  const cspLogs = [];
  course.on("console", (m) => { if (m.type() === "error") cspLogs.push(m.text()); });
  await course.goto(await embedUrl(course, '"strict #{1 + 1}"', { run: "1" }, "?csp=strict"));
  const strict = await course.waitForFunction(() => {
    const out = document.getElementById("cell-out-0");
    const status = document.getElementById("embedStatus").textContent;
    return (out.style.display !== "none" && out.innerText) || (/could not|konnte/.test(status) && status);
  }, null, { timeout: 120000 }).then((h) => h.jsonValue()).catch((e) => "timeout " + e.message);
  check("sandbox + strict CSP (connect-src 'self', unsafe-eval needed by the js gem): the kernel runs", String(strict).includes("strict 2"),
    String(strict).slice(0, 120) + (cspLogs.length ? " | console: " + cspLogs.slice(0, 3).join(" | ").slice(0, 400) : ""));

  check("no console errors on the host page", logs.length === 0, logs.slice(0, 3).join(" | "));
  await context.close();
}

// ---------- measurements ----------
// Throttled like docs/PICORUBY_SHELL.md's slow profile (20 Mbit/s, 40 ms)
async function throttle(page, on) {
  if (!on) return;
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.emulateNetworkConditions", {
    offline: false, latency: 40, downloadThroughput: 20e6 / 8, uploadThroughput: 5e6 / 8
  });
}

async function marks(page) {
  return page.evaluate(() => Object.fromEntries(performance.getEntriesByType("mark")
    .filter((m) => m.name.startsWith("embed:")).map((m) => [m.name.slice(6), Math.round(m.startTime)])));
}

// one load, cold or warm (a first visit in the same context before): when
// the code is visible, the editor up, Ruby up and the first result there.
// where: "frame" = embed.html as a page of its own (its own clock), "host" =
// demo/one.html on blog.test with one <pre data-chunky> (the host's clock,
// from the host page's navigation).
let profileCount = 0;
async function measureOnce({ slow, warm, query = "", where = "frame" }) {
  // warm: a real on-disk profile - an incognito context's memory cache does
  // not keep a 10 MB response, so it would download ruby.wasm every time
  const profile = join(here, ".profile-" + (++profileCount));
  const context = warm
    ? await chromium.launchPersistentContext(profile, { args: [`--host-resolver-rules=MAP embed.test 127.0.0.1, MAP blog.test 127.0.0.1`] })
    : await browser.newContext();
  const page = await context.newPage();
  await throttle(page, slow);
  const code = "words = %w[chunky bacon is chunky]\nwords.tally";
  await page.goto(EMBED + "embed-ui.js");
  const target = where === "host" ? BLOG + "demo/one.html" : await embedUrl(page, code, { run: "1" }, query);
  if (where === "host") {
    await page.addInitScript(() => {
      window.__timings = {};
      window.addEventListener("message", (e) => {
        if (e.data && e.data.chunkyEmbed === "timing") window.__timings[e.data.name] = Math.round(performance.now());
      });
    });
  }
  const done = where === "host"
    ? () => page.waitForFunction(() => window.__timings && window.__timings["first-result"], null, { timeout: 300000 })
    : () => page.waitForFunction(() => performance.getEntriesByName("embed:first-result").length > 0, null, { timeout: 300000 });
  if (warm) {
    await page.goto(target);
    await done();
    await page.goto(EMBED + "embed-ui.js");
  }
  await page.goto(target);
  await done();
  const m = where === "host" ? await page.evaluate(() => window.__timings) : await marks(page);
  if (where === "frame") {
    // a second run, Ruby already up: the run itself
    await page.click("#runBtn");
    const t0 = Date.now();
    await page.waitForFunction(() => !document.getElementById("cell").classList.contains("running") &&
      document.getElementById("runBtn").disabled === false);
    m["rerun"] = Date.now() - t0;
    const entries = await page.evaluate(() => {
      const start = performance.getEntriesByName("embed:kernel-start")[0].startTime;
      return performance.getEntriesByType("resource").map((r) => ({ name: r.name, size: r.transferSize, start: r.startTime }))
        .concat([{ name: "__start", start }]);
    });
    const start = entries.find((e) => e.name === "__start").start;
    const kb = (list) => Math.round(list.reduce((s, e) => s + (e.size || 0), 0) / 1024);
    m["KB before Ruby"] = kb(entries.filter((e) => e.name !== "__start" && e.start < start));
    m["wasm KB"] = kb(entries.filter((e) => e.name.includes("ruby+stdlib.wasm")));
    m["transfer KB"] = kb(entries.filter((e) => e.name !== "__start"));
  }
  await context.close();
  if (warm) rmSync(profile, { recursive: true, force: true });
  return m;
}

async function measure() {
  const rows = [];
  const profiles = [
    ["fast, cold", { slow: false, warm: false }],
    ["fast, warm", { slow: false, warm: true }],
    ["fast, warm, no sandbox", { slow: false, warm: true, query: "?nosandbox" }],
    ["20 Mbit/s, cold", { slow: true, warm: false }],
    ["20 Mbit/s, warm", { slow: true, warm: true }],
    ["20 Mbit/s, warm, no sandbox", { slow: true, warm: true, query: "?nosandbox" }],
    ["host page, fast, cold", { slow: false, warm: false, where: "host" }],
    ["host page, fast, warm", { slow: false, warm: true, where: "host" }],
    ["host page, 20 Mbit/s, cold", { slow: true, warm: false, where: "host" }]
  ];
  for (const [label, options] of profiles) {
    const runs = [];
    for (let i = 0; i < RUNS; i++) runs.push(await measureOnce(options));
    const median = (key) => {
      const v = runs.map((r) => r[key]).filter((x) => x !== undefined).sort((a, b) => a - b);
      return v.length ? v[Math.floor(v.length / 2)] : undefined;
    };
    const row = { profile: label };
    for (const key of ["code-visible", "editor", "kernel-start", "kernel-ready", "first-result", "rerun", "KB before Ruby", "wasm KB", "transfer KB"]) {
      const value = median(key);
      if (value !== undefined) row[key] = value;
    }
    rows.push(row);
    console.log(JSON.stringify(row));
  }
  writeFileSync(join(here, "measurements.json"), JSON.stringify({ runs: RUNS, date: new Date().toISOString(), rows }, null, 2));
}

if (mode === "check" || mode === "all") await checks();
if (mode === "measure" || mode === "all") await measure();
await browser.close();
console.log(failures ? `${failures} check(s) failed` : "done");
process.exit(failures ? 1 : 0);
