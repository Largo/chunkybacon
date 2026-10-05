// The grid for show_game (game.rb, main.rb): the page runs the game loop,
// because CRuby runs on this thread and must never loop or sleep itself.
//
//   var game = chunkyGame(node, optsJson, function (now, events) { ... return frameJson; });
//   game.stop();          // a re-run of the cell, another lesson
//   game.stats();         // per-call cost, for the measurements
//
// Each animation frame, Ruby is called at most once, and only when there is
// something to do: a timer of the game is due (the frame says when: "next")
// or keys, clicks or a restart came in since the last frame. The answer is
// the cells that changed, as JSON; the grid is a CSS grid of <div>s, and only
// those cells are touched.
//
// The game runs only while it has the focus: a click (or Tab) starts it, and
// it pauses when the focus goes elsewhere - so the arrow keys never scroll
// the page or reach the editor, a live run never starts a game nobody looks
// at, and two games on one page do not both run.
(function () {
  "use strict";

  var KEYS = {
    ArrowLeft: "left", ArrowRight: "right", ArrowUp: "up", ArrowDown: "down",
    " ": "space", Enter: "enter", Escape: "escape"
  };
  var CSS = [
    ".game-widget { margin: 0.7rem 0; display: inline-block; outline: none; user-select: none; -webkit-user-select: none; }",
    ".game-board { position: relative; border-radius: 10px; padding: 6px; background: #2a2119; box-shadow: 0 2px 0 rgba(0,0,0,.15); }",
    ".game-widget:focus-visible .game-board, .game-widget.is-running .game-board { box-shadow: 0 0 0 3px #f2a65a; }",
    ".game-grid { display: grid; background: #fbf7ee; border-radius: 6px; overflow: hidden; touch-action: none; }",
    ".game-grid > div { display: flex; align-items: center; justify-content: center; line-height: 1; background-size: 90% 90%; background-position: center; background-repeat: no-repeat; }",
    ".game-grid > div.alt { box-shadow: inset 0 0 0 100px rgba(80, 60, 30, .045); }",
    ".game-overlay { position: absolute; inset: 6px; display: flex; flex-direction: column; gap: .4rem; align-items: center; justify-content: center; text-align: center; border-radius: 6px; background: rgba(42, 33, 25, .55); color: #fff; font: 600 1.05rem 'Shantell Sans', 'Segoe Print', sans-serif; cursor: pointer; padding: 1rem; }",
    ".game-overlay[hidden] { display: none; }",
    ".game-overlay small { font-weight: 400; font-size: .85rem; opacity: .85; }",
    ".game-bar { display: flex; justify-content: space-between; gap: 1rem; font-size: .9rem; color: #5f5247; padding: .3rem .2rem 0; min-height: 1.4em; }",
    ".game-log { margin: .3rem 0 0; max-height: 6.5em; overflow: auto; font-size: .8rem; background: #f4efe4; border-radius: 6px; padding: .3rem .5rem; }",
    ".game-log:empty { display: none; }",
    ".game-error { color: #b3261e; font-size: .9rem; padding-top: .3rem; }"
  ].join("\n");

  function addStyle() {
    if (document.getElementById("chunky-game-style")) return;
    var style = document.createElement("style");
    style.id = "chunky-game-style";
    style.textContent = CSS;
    document.head.appendChild(style);
  }

  function el(tag, cls, parent) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (parent) parent.appendChild(e);
    return e;
  }

  window.chunkyGame = function (node, optsJson, step) {
    addStyle();
    var opts = JSON.parse(String(optsJson));
    var w = opts.w, h = opts.h;
    var labels = opts.labels || {};
    var size = Math.max(12, Math.min(32, Math.floor((opts.maxWidth || 480) / w)));

    node.className = "game-widget";
    node.tabIndex = 0;
    node.setAttribute("role", "application");
    node.setAttribute("aria-label", labels.title || "Game");
    var board = el("div", "game-board", node);
    var grid = el("div", "game-grid", board);
    grid.style.gridTemplateColumns = "repeat(" + w + ", " + size + "px)";
    grid.style.gridTemplateRows = "repeat(" + h + ", " + size + "px)";
    grid.style.fontSize = Math.round(size * 0.78) + "px";
    var cells = new Array(w * h), looks = new Array(w * h);
    for (var i = 0; i < w * h; i++) {
      cells[i] = el("div", ((i % w) + Math.floor(i / w)) % 2 ? "alt" : null, grid);
      looks[i] = "";
    }
    var overlay = el("div", "game-overlay", board);
    var bar = el("div", "game-bar", node);
    var statusEl = el("span", "game-status", bar);
    var hintEl = el("span", "game-hint", bar);
    hintEl.textContent = labels.hint || "";
    var log = el("pre", "game-log", node);
    var errorEl = el("div", "game-error", node);
    errorEl.hidden = true;

    var events = [];
    var next = null;          // when Ruby wants to be called again (ms)
    var focused = false, over = false, stopped = false, error = false;
    var raf = 0;
    var stats = { calls: 0, total: 0, max: 0, render: 0, recent: [] };

    function paint(i, look) {
      if (looks[i] === look) return;
      looks[i] = look;
      var c = cells[i];
      c.textContent = "";
      c.style.backgroundColor = "";
      c.style.backgroundImage = "";
      if (look.lastIndexOf("bg:", 0) === 0) c.style.backgroundColor = look.slice(3);
      else if (look.lastIndexOf("img:", 0) === 0) c.style.backgroundImage = "url(\"" + look.slice(4) + "\")";
      else c.textContent = look;
    }

    function apply(json) {
      var t = performance.now();
      var f = JSON.parse(json);
      for (var k = 0; k < f.d.length; k++) paint(f.d[k][0], f.d[k][1]);
      next = typeof f.next === "number" ? f.next : null;
      if (typeof f.status === "string") statusEl.textContent = f.status;
      if (typeof f.log === "string") {
        log.textContent = (log.textContent + f.log).split("\n").slice(-50).join("\n");
        log.scrollTop = log.scrollHeight;
      }
      if (f.error) {
        error = true;
        guard(false);
        errorEl.hidden = false;
        errorEl.textContent = f.error;
      }
      if (typeof f.over === "string") {
        over = true;
        node.setAttribute("data-over", f.over);
      }
      stats.render += performance.now() - t;
      showOverlay();
    }

    function call(now) {
      var batch = events.join("|");
      events.length = 0;
      var t = performance.now();
      var answer;
      try {
        answer = step(now, batch);
      } catch (e) {
        error = true;
        errorEl.hidden = false;
        errorEl.textContent = String(e);
        stop();
        return;
      }
      var spent = performance.now() - t;
      stats.calls++;
      stats.total += spent;
      if (spent > stats.max) stats.max = spent;
      stats.recent.push(spent);
      if (stats.recent.length > 200) stats.recent.shift();
      if (answer != null) apply(String(answer));
    }

    // the game's own clock: it stands still while the game is paused (no
    // focus, a hidden tab), so timers never have to catch up
    var clock = 0, last = null;

    function frame(now) {
      raf = 0;
      if (stopped) return;
      if (!node.isConnected) { stop(); return; }   // the cell's output was replaced
      if (last !== null && !over) clock += Math.min(now - last, 100);
      last = now;
      if (events.length || (!over && next !== null && clock >= next)) call(clock);
      if (running()) raf = requestAnimationFrame(frame);
      else last = null;
    }

    function running() { return !stopped && focused && !error; }

    function wake() {
      if (!raf && running()) raf = requestAnimationFrame(frame);
    }

    function showOverlay() {
      node.classList.toggle("is-running", running() && !over);
      if (error) { overlay.hidden = true; return; }
      var text = null, small = null;
      if (over) { text = node.getAttribute("data-over") || labels.over || ""; small = labels.again; }
      else if (!focused) { text = labels.play; small = labels.keys; }
      overlay.hidden = text === null;
      if (text !== null) {
        overlay.textContent = "";
        if (text) el("div", null, overlay).textContent = text;
        if (small) el("small", null, overlay).textContent = small;
      }
    }

    function stop() {
      guard(false);
      stopped = true;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
      node.classList.remove("is-running");
    }

    function push(event) {
      if (stopped || error) return;
      events.push(event);
      wake();
    }

    // the kernel's time limit for the steps is on while the game has the
    // focus (main.rb, GameGuard): told at once, not with the next frame
    var guarded = false;
    function guard(on) {
      if (on === guarded || stopped) return;
      guarded = on;
      try { step(clock, on ? "f:1" : "f:0"); } catch (e) { /* the game goes on unguarded */ }
    }

    node.addEventListener("focus", function () {
      focused = true;
      if (!error) guard(true);
      showOverlay();
      wake();
    });
    node.addEventListener("blur", function () { focused = false; guard(false); showOverlay(); });
    overlay.addEventListener("click", function () {
      node.focus();
      if (over && !error) {
        over = false;
        node.removeAttribute("data-over");
        push("r");
      }
      showOverlay();
    });
    node.addEventListener("keydown", function (e) {
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      var key = KEYS[e.key] || (/^[a-zA-Z0-9]$/.test(e.key) ? e.key.toLowerCase() : null);
      if (!key) return;
      e.preventDefault();       // no scrolling with the arrows and space
      if (key === "escape") { node.blur(); return; }
      if (!over) push("k:" + key);
    });

    // a tap is a click on a cell, a swipe an arrow key (phones)
    var down = null;
    grid.addEventListener("pointerdown", function (e) {
      down = [e.clientX, e.clientY];
    });
    grid.addEventListener("pointerup", function (e) {
      if (!down) return;
      var dx = e.clientX - down[0], dy = e.clientY - down[1];
      down = null;
      if (!focused || over) return;
      if (Math.max(Math.abs(dx), Math.abs(dy)) > 24) {
        push("k:" + (Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "down" : "up")));
        return;
      }
      var r = grid.getBoundingClientRect();
      var x = Math.floor((e.clientX - r.left) / (r.width / w));
      var y = Math.floor((e.clientY - r.top) / (r.height / h));
      if (x >= 0 && y >= 0 && x < w && y < h) push("c:" + x + "," + y);
    });

    var controller = {
      stop: stop,
      stats: function () {
        var sorted = stats.recent.slice().sort(function (a, b) { return a - b; });
        return JSON.stringify({
          calls: stats.calls,
          avgMs: stats.calls ? stats.total / stats.calls : 0,
          medianMs: sorted.length ? sorted[sorted.length >> 1] : 0,
          maxMs: stats.max,
          renderMs: stats.calls ? stats.render / stats.calls : 0
        });
      },
      // for the tests: a key as if pressed while the game has the focus
      press: function (key) { push("k:" + key); },
      running: function () { return running() && !over; }
    };
    node.chunkyGame = controller;

    if (opts.first) apply(opts.first);
    showOverlay();
    return controller;
  };
})();
