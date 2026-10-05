// For the Playwright MCP's browser_run_code (filename): per-call cost of the
// game loop under each time-limit mode, each in a FRESH page (TracePoint's
// cost depends on what ran before), with examples/endless_snake.rb at 20
// steps a second for 5 s. Also: does a plain cell still run fine afterwards.
async (page) => {
  const out = {};
  const sel = "#cell-out-1 .game-widget";
  const modes = (globalThis.GUARD_MODES || [":tick", ":focus", ":lines", "false"]);
  for (const mode of modes) {
    await page.goto("http://127.0.0.1:18108/?kernel=eager");
    await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
    const code = await page.evaluate(async () => (await fetch("/examples/endless_snake.rb")).text());
    await page.evaluate((c) => window.setCellCode(1, c), "$game_guard = " + mode + "\n" + code);
    await page.click('.run-cell[data-idx="1"]');
    await page.waitForSelector(sel, { timeout: 30000 });
    await page.click("#cell-out-1 .game-overlay");
    await page.waitForTimeout(5000);
    const s = JSON.parse(await page.evaluate((q) => document.querySelector(q).chunkyGame.stats(), sel));
    const status = await page.textContent("#cell-out-1 .game-status");
    // afterwards: a plain cell, timed (the guard must be off again)
    await page.evaluate(() => window.setCellCode(1, "t = Time.now\n200_000.times.sum { |i| i * 2 }\n((Time.now - t) * 1000).round"));
    await page.click('.run-cell[data-idx="1"]');
    await page.waitForFunction(() => /=>/.test(document.getElementById("cell-out-1").textContent), null, { timeout: 30000 });
    const cell = (await page.textContent("#cell-out-1")).trim();
    out[mode + (out[mode] ? " again" : "")] = {
      calls: s.calls, avgMs: +s.avgMs.toFixed(2), medianMs: s.medianMs, maxMs: s.maxMs,
      renderMs: +s.renderMs.toFixed(3), status, cellAfterMs: cell
    };
  }
  return out;
}
