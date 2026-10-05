// Small companion to browser_probe.mjs: where the first matplotlib import
// spends its time, and one cell's full output (CODE env or the default).
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const { chromium } = await import(pathToFileURL(path.join(process.env.PLAYWRIGHT_DIR, 'index.mjs')).href);
const BASE = process.env.BASE || 'http://127.0.0.1:18101/';
const browser = await chromium.launch();
const page = await browser.newPage({ locale: 'de-DE' });
page.on('pageerror', e => console.log('[pageerror]', e.message));

const t0 = Date.now();
await page.goto(BASE + '#matplotlib', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.chunkyPython?.ready && window.ChunkyBridge?.ready, null, { timeout: 180000 });
console.log(`navigation -> Python + packages + kernel ready: ${((Date.now() - t0) / 1000).toFixed(1)} s`);

// the import, step by step, straight in Pyodide (no bridge)
const timing = await page.evaluate(() => window.chunkyPython.pyodide.runPython(`
import time, os, json
steps = []
t = time.perf_counter()
def step(name):
    global t
    now = time.perf_counter(); steps.append([name, round((now - t) * 1000)]); t = now
import numpy; step("numpy")
import PIL.Image; step("PIL")
import matplotlib; step("matplotlib")
import matplotlib.font_manager as fm; step("font_manager (font cache)")
import matplotlib.pyplot as plt; step("pyplot")
fig = plt.figure(); plt.plot([1, 2, 3]); step("first figure")
import io; b = io.BytesIO(); fig.savefig(b, format="svg"); step("first savefig svg")
b = io.BytesIO(); fig.savefig(b, format="png"); step("first savefig png")
plt.close("all")
cache = matplotlib.get_cachedir()
json.dumps({"steps": steps, "cachedir": cache, "files": os.listdir(cache), "backend": matplotlib.get_backend(), "fonts": len(fm.fontManager.ttflist)})
`));
console.log(timing);

const code = process.env.CODE || 'require "pycall"\nplt = PyCall.import_module("matplotlib.pyplot")\nplt.plot([1, 2])\nplt.savefig("ohne_endung")\nplt.close()\nFile.read("ohne_endung.png")[1, 3]';
const idx = await page.getAttribute('.cell.exercise .run-cell', 'data-idx');
await page.evaluate(([i, c]) => window.cellEditors[i].setValue(c), [idx, code]);
await page.click(`.run-cell[data-idx="${idx}"]`);
await page.waitForTimeout(3000);
console.log('--- cell output ---\n' + await page.textContent(`#cell-out-${idx}`));
await browser.close();
