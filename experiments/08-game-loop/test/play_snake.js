// For the Playwright MCP's browser_run_code (filename): the prototype page
// (serve.rb, port 18108) must be open. Runs examples/snake.rb in lesson 1's
// first cell - once with the per-tick time limit, once without - lets an
// autopilot steer Chunky to the bacon for a few seconds with real key
// presses, and reports the cost per Ruby call (game.js's stats), then
// checks that a re-run of the cell stops the old game. Screenshots go to
// globalThis.SCREENSHOT_DIR, else screenshots/ relative to the repo root
// (the MCP server's working directory).
async (page) => {
  const DIR = globalThis.SCREENSHOT_DIR || "experiments/08-game-loop/screenshots/";
  await page.waitForFunction(() => window.ChunkyBridge && window.ChunkyBridge.ready, null, { timeout: 120000 });
  const snake = await page.evaluate(async () => (await fetch("/examples/snake.rb")).text());
  const sel = "#cell-out-1 .game-widget";

  async function run(code) {
    await page.evaluate((c) => window.setCellCode(1, c), code);
    await page.click('.run-cell[data-idx="1"]');
    await page.waitForSelector(sel, { timeout: 30000 });
  }

  // where the fox and the bacon are, from the grid's cells
  const where = () => page.evaluate((s) => {
    const cells = [...document.querySelectorAll(s + " .game-grid > div")];
    const w = 20, find = (t) => cells.findIndex((c) => c.textContent === t);
    const f = find("🦊"), b = find("🥓");
    const over = document.querySelector(s).getAttribute("data-over");
    return { head: f < 0 ? null : [f % w, Math.floor(f / w)], bacon: b < 0 ? null : [b % w, Math.floor(b / w)], over };
  }, sel);

  async function autopilot(ms) {
    let dir = "right", restarts = 0, best = 0;
    const until = Date.now() + ms;
    while (Date.now() < until) {
      const s = await where();
      if (s.over !== null) {
        restarts++;
        await page.click("#cell-out-1 .game-overlay");
        dir = "right";
        continue;
      }
      if (s.head && s.bacon) {
        const [hx, hy] = s.head, [bx, by] = s.bacon;
        let want = bx > hx ? "right" : bx < hx ? "left" : by > hy ? "down" : "up";
        const back = { left: "right", right: "left", up: "down", down: "up" };
        if (want === back[dir]) want = by > hy ? "down" : by < hy ? "up" : (hy > 0 ? "up" : "down");
        if (want !== dir) {
          await page.keyboard.press("Arrow" + want[0].toUpperCase() + want.slice(1));
          dir = want;
        }
      }
      const status = await page.textContent("#cell-out-1 .game-status");
      best = Math.max(best, parseInt(status.replace(/\D/g, "") || "0", 10));
      await page.waitForTimeout(40);
    }
    return { restarts, best };
  }

  const stats = () => page.evaluate((s) => JSON.parse(document.querySelector(s).chunkyGame.stats()), sel);
  const result = {};

  for (const guard of [":focus", ":tick", "false"]) {
    await run("$game_guard = " + guard + "\n" + snake);
    await page.click("#cell-out-1 .game-overlay");      // focus: the game starts
    const play = await autopilot(8000);
    result["guard " + guard] = Object.assign(play, await stats());
  }
  await page.locator(sel).scrollIntoViewIfNeeded();
  await page.locator("#cell-out-1").screenshot({ path: DIR + "snake-playing.png" });

  // pausing: the focus goes elsewhere -> no more calls
  const before = (await stats()).calls;
  await page.evaluate(() => document.activeElement.blur());
  await page.waitForTimeout(600);
  result.callsWhilePaused = (await stats()).calls - before;
  await page.locator("#cell-out-1").screenshot({ path: DIR + "snake-paused.png" });

  // a re-run of the cell: the old game must stop calling Ruby
  await page.click("#cell-out-1 .game-overlay");
  const old = await page.evaluateHandle((s) => document.querySelector(s).chunkyGame, sel);
  const oldCalls = JSON.parse(await old.evaluate((g) => g.stats())).calls;
  await run("$game_guard = :focus\n" + snake);
  await page.waitForTimeout(800);
  result.oldGameCallsAfterRerun = JSON.parse(await old.evaluate((g) => g.stats())).calls - oldCalls;
  result.oldGameRunning = await old.evaluate((g) => g.running());

  // an error inside a tick, and an endless loop inside a tick
  await run("show_game { |g| g.every(0.1) { g.cell(1, 1, :bacon); nil + 1 } }");
  await page.click("#cell-out-1 .game-overlay");
  await page.waitForTimeout(400);
  result.tickError = await page.textContent("#cell-out-1 .game-error");
  await run("show_game { |g| g.every(0.1) { x = 0\n x += 1 while x >= 0 } }");
  await page.click("#cell-out-1 .game-overlay");
  const t = Date.now();
  await page.waitForFunction(() => {
    const e = document.querySelector("#cell-out-1 .game-error");
    return e && e.textContent;
  }, null, { timeout: 20000 });
  result.endlessLoop = { message: await page.textContent("#cell-out-1 .game-error"), afterMs: Date.now() - t };
  await page.locator("#cell-out-1").screenshot({ path: DIR + "endless-loop.png" });
  return result;
}
