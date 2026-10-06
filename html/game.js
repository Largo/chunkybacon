// The grid for show_game (game.rb, main.rb's mount_game): the page runs the
// game loop, because CRuby runs on this thread and must never loop or sleep
// itself.
//
//   var game = chunkyGame(node, optsJson, function (now, events) { ... return frameJson; });
//   game.stop();          // a re-run of the cell, another lesson
//   game.stats();         // per-call cost, for the measurements
//
// Each animation frame, Ruby is called at most once, and only when there is
// something to do: a timer of the game is due (the frame says when: "next")
// or keys, clicks or a restart came in since the last frame. The answer is
// the cells that changed, as JSON; the grid is a CSS grid of <div>s, and only
// those cells are touched. The styles are app.css's (.game-*).
//
// The game runs only while it has the focus and is not paused: a click on
// it, or Space/Enter once Tab has reached it, starts it; Esc pauses it, and
// Tab (or a click elsewhere) leaves it, which pauses it too. So the arrow
// keys never scroll the page or reach the editor, a live run never starts a
// game nobody looks at, two games on one page do not both run, and nothing
// on the page moves until the learner asks for it. A screen reader hears
// the score when it changes (at most every 1.5 s), the end of a round and
// errors, from a polite live region inside the widget.
(function () {
  "use strict";

  var KEYS = {
    ArrowLeft: "left", ArrowRight: "right", ArrowUp: "up", ArrowDown: "down",
    " ": "space", Enter: "enter", Escape: "escape"
  };
  var SAY_EVERY = 1500;   // ms between two spoken score changes
  var count = 0;          // for the ids of the descriptions

  function el(tag, cls, parent) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (parent) parent.appendChild(e);
    return e;
  }

  window.chunkyGame = function (node, optsJson, step) {
    var opts = JSON.parse(String(optsJson));
    var w = opts.w, h = opts.h;
    var labels = opts.labels || {};
    // cells of 12..32 px, the board at most 480 px or the column's width
    var room = node.parentNode && node.parentNode.clientWidth ? node.parentNode.clientWidth - 12 : 480;
    var size = Math.max(12, Math.min(32, Math.floor(Math.min(opts.maxWidth || 480, room) / w)));

    node.className = "game-widget";
    node.tabIndex = 0;
    // the arrow keys belong to the game, not to a screen reader's browsing
    node.setAttribute("role", "application");
    node.setAttribute("aria-label", labels.title || "Game");
    var described = el("span", "sr-only", node);
    described.id = "game-keys-" + (++count);
    described.textContent = [labels.play, labels.keys].filter(Boolean).join(". ");
    node.setAttribute("aria-describedby", described.id);
    var board = el("div", "game-board", node);
    var grid = el("div", "game-grid", board);
    grid.setAttribute("aria-hidden", "true");   // emoji by the hundred: the live region speaks instead
    grid.style.gridTemplateColumns = "repeat(" + w + ", " + size + "px)";
    grid.style.gridTemplateRows = "repeat(" + h + ", " + size + "px)";
    grid.style.fontSize = Math.round(size * 0.78) + "px";
    var cells = new Array(w * h), looks = new Array(w * h);
    for (var i = 0; i < w * h; i++) {
      cells[i] = el("div", ((i % w) + Math.floor(i / w)) % 2 ? "alt" : null, grid);
      looks[i] = "";
    }
    var overlay = el("div", "game-overlay", board);
    overlay.setAttribute("aria-hidden", "true");   // the description and the live region say it
    var bar = el("div", "game-bar", node);
    var statusEl = el("span", "game-status", bar);
    var hintEl = el("span", "game-hint", bar);
    hintEl.textContent = labels.keys || "";
    var log = el("pre", "game-log", node);
    var errorEl = el("div", "game-error", node);
    errorEl.hidden = true;
    var say = el("p", "sr-only game-say", node);
    say.setAttribute("aria-live", "polite");
    say.setAttribute("aria-atomic", "true");

    var events = [];
    var next = null;          // when Ruby wants to be called again (ms)
    var focused = false, paused = true, started = false;
    var over = false, stopped = false, error = false;
    var raf = 0;
    var stats = { calls: 0, total: 0, max: 0, render: 0, recent: [] };

    // ---------- the live region: changes, never every tick ----------

    var spoken = "", saidAt = 0, pending = null, sayTimer = 0;

    function speak(text) {
      if (sayTimer) { clearTimeout(sayTimer); sayTimer = 0; }
      pending = null;
      say.textContent = "";
      // emptied first, the text a moment later: the same words twice are read twice
      setTimeout(function () { say.textContent = text; }, 50);
      saidAt = performance.now();
    }

    function sayStatus(text) {
      if (!text || text === spoken) return;
      spoken = text;
      pending = text;
      if (sayTimer) return;
      sayTimer = setTimeout(function () {
        sayTimer = 0;
        if (pending !== null && !over && !error) speak(pending);
      }, Math.max(0, saidAt + SAY_EVERY - performance.now()));
    }

    // ---------- drawing ----------

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

    function apply(json, quiet) {
      var t = performance.now();
      var f = JSON.parse(json);
      for (var k = 0; k < f.d.length; k++) paint(f.d[k][0], f.d[k][1]);
      next = typeof f.next === "number" ? f.next : null;
      if (typeof f.status === "string") {
        statusEl.textContent = f.status;
        if (quiet) spoken = f.status; else sayStatus(f.status);
      }
      if (typeof f.log === "string") {
        log.textContent = (log.textContent + f.log).split("\n").slice(-50).join("\n");
        log.scrollTop = log.scrollHeight;
      }
      if (f.error) {
        error = true;
        guard(false);
        errorEl.hidden = false;
        errorEl.textContent = f.error;
        speak(f.error);
      }
      if (typeof f.over === "string") {
        over = true;
        node.setAttribute("data-over", f.over);
        if (!f.error && !quiet) speak([statusEl.textContent, f.over || labels.over, labels.again].filter(Boolean).join(". "));
      }
      stats.render += performance.now() - t;
      update();
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

    // ---------- the loop ----------

    // the game's own clock: it stands still while the game is paused (no
    // focus, Esc, a hidden tab), so timers never have to catch up
    var clock = 0, last = null;

    function frame(now) {
      raf = 0;
      if (stopped) return;
      if (!node.isConnected) { stop(); return; }   // the cell's output was replaced
      if (last !== null && !over) clock += Math.min(now - last, 100);
      last = now;
      if (events.length || (!over && next !== null && clock >= next)) call(clock);
      if (!active()) last = null;
      else if (!raf) raf = requestAnimationFrame(frame);   // apply's update may have asked already
    }

    function active() { return !stopped && focused && !paused && !error; }

    function wake() {
      if (!raf && active()) raf = requestAnimationFrame(frame);
    }

    function update() {
      guard(active());
      showOverlay();
      wake();
    }

    function showOverlay() {
      var playing = active() && !over;
      node.classList.toggle("is-running", playing);
      node.setAttribute("data-state", error ? "error" : over ? "over" : playing ? "playing" : "paused");
      if (error) { overlay.hidden = true; return; }
      var text = null, small = null;
      if (over) { text = node.getAttribute("data-over") || labels.over || ""; small = labels.again; }
      else if (!playing) { text = started ? labels.paused : labels.play; small = started ? labels.play : labels.keys; }
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
      if (sayTimer) clearTimeout(sayTimer);
      node.classList.remove("is-running");
    }

    function push(event) {
      if (stopped || error) return;
      events.push(event);
      wake();
    }

    // play (again): a click, Space or Enter
    function play() {
      if (stopped || error) return;
      if (over) {
        over = false;
        node.removeAttribute("data-over");
        push("r");
      }
      paused = false;
      started = true;
      update();
    }

    // the kernel's time limit for the steps is on while the game runs
    // (main.rb, GameGuard): told at once, not with the next frame
    var guarded = false;
    function guard(on) {
      if (on === guarded || stopped) return;
      guarded = on;
      try { step(clock, on ? "f:1" : "f:0"); } catch (e) { /* the game goes on unguarded */ }
    }

    node.addEventListener("focus", function () { focused = true; update(); });
    node.addEventListener("blur", function () { focused = false; paused = true; update(); });
    overlay.addEventListener("click", function () {
      node.focus({ preventScroll: true });
      play();
    });
    node.addEventListener("keydown", function (e) {
      if (e.ctrlKey || e.metaKey || e.altKey || e.target !== node) return;
      var key = KEYS[e.key] || (/^[a-zA-Z0-9]$/.test(e.key) ? e.key.toLowerCase() : null);
      if (!key) return;           // Tab and the rest do what they always do
      var playing = active() && !over;
      if (key === "escape") {
        if (!playing) return;
        e.preventDefault();
        paused = true;
        update();
        speak(labels.paused || "");
        return;
      }
      if (!playing) {
        if (key === "space" || key === "enter") { e.preventDefault(); play(); }
        return;
      }
      e.preventDefault();         // no scrolling with the arrows and space
      push("k:" + key);
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
      if (!active() || over) return;
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
      // for the tests: a key as if pressed while the game runs
      press: function (key) { push("k:" + key); },
      running: function () { return active() && !over; }
    };
    node.chunkyGame = controller;

    if (opts.first) apply(opts.first, true);
    showOverlay();
    return controller;
  };
})();
