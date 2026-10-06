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
//
// A ruby2d window (ruby2d.rb's Page::Runner, opts.canvas) runs the same way
// on a <canvas> instead of the grid: Ruby is called every frame (its "next"
// is always the next frame, at most 60 a second), answers with the whole
// scene as draw commands ({"bg": rgba, "c": [...]}), and gets keys by the
// names SDL gives them ("left", "space", "a" - down and up, the held ones
// Ruby repeats itself) and the mouse in the window's own coordinates. A
// closed window does not start again; running the cell does that.
(function () {
  "use strict";

  var KEYS = {
    ArrowLeft: "left", ArrowRight: "right", ArrowUp: "up", ArrowDown: "down",
    " ": "space", Enter: "enter", Escape: "escape"
  };
  var SAY_EVERY = 1500;   // ms between two spoken score changes
  var count = 0;          // for the ids of the descriptions

  // ---------- a ruby2d window's canvas ----------

  var DPR = Math.min(window.devicePixelRatio || 1, 2);
  // the gem draws text in Outfit; the page in its own sans serif
  var FAMILY = '"Atkinson Hyperlegible Next", system-ui, sans-serif';
  // keys by SDL's scancode names, lowercased, as ruby2d 1.0 gives them -
  // physical keys, so e.code (an "A" key is "a" in any layout)
  var SDL_CODES = {
    ArrowLeft: "left", ArrowRight: "right", ArrowUp: "up", ArrowDown: "down",
    Space: "space", Enter: "return", NumpadEnter: "keypad enter", Escape: "escape",
    Backspace: "backspace", Delete: "delete", Insert: "insert", Home: "home", End: "end",
    PageUp: "pageup", PageDown: "pagedown", CapsLock: "capslock",
    ShiftLeft: "left shift", ShiftRight: "right shift", ControlLeft: "left ctrl",
    ControlRight: "right ctrl", AltLeft: "left alt", AltRight: "right alt",
    MetaLeft: "left gui", MetaRight: "right gui",
    Minus: "-", Equal: "=", BracketLeft: "[", BracketRight: "]", Backslash: "\\",
    Semicolon: ";", Quote: "'", Backquote: "`", Comma: ",", Period: ".", Slash: "/"
  };

  function sdlKey(code) {
    if (SDL_CODES[code]) return SDL_CODES[code];
    var m = /^(?:Key|Digit)(\w)$/.exec(code);
    if (m) return m[1].toLowerCase();
    m = /^Numpad(\d)$/.exec(code);
    if (m) return "keypad " + m[1];
    if (/^F\d+$/.test(code)) return code.toLowerCase();
    return null;
  }

  function textFont(size, style) {
    return (style & 2 ? "italic " : "") + (style & 1 ? "bold " : "") + size + "px " + FAMILY;
  }

  // a Text's width as ruby2d.rb asks for it (Ruby2D.measure__)
  var measurer = null;
  window.chunkyCanvasTextWidth = function (text, size, style) {
    measurer = measurer || document.createElement("canvas").getContext("2d");
    measurer.font = textFont(size, style);
    return measurer.measureText(String(text)).width;
  };

  function rgba(r, g, b, a) {
    return "rgba(" + Math.round(r * 255) + "," + Math.round(g * 255) + "," + Math.round(b * 255) + "," + a + ")";
  }

  function path(ctx, pts, close) {
    ctx.beginPath();
    ctx.moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) ctx.lineTo(pts[i], pts[i + 1]);
    if (close) ctx.closePath();
  }

  function fillPoly(ctx, pts, css) {
    path(ctx, pts, true);
    ctx.fillStyle = css;
    ctx.fill();
    // a hairline of the same colour hides the seams between pieces
    ctx.strokeStyle = css;
    ctx.lineWidth = 0.6;
    ctx.stroke();
  }

  function mix(cs, ws) {   // colours (4 numbers each) weighted
    var o = [0, 0, 0, 0];
    for (var k = 0; k < ws.length; k++) for (var n = 0; n < 4; n++) o[n] += cs[k * 4 + n] * ws[k];
    return rgba(o[0], o[1], o[2], o[3]);
  }

  var SPLIT = 8;   // a colour per corner: so many pieces a side, each its own colour

  function gradientQuad(ctx, p, cs) {
    function at(u, v) {
      var tx = p[0] + (p[2] - p[0]) * u, ty = p[1] + (p[3] - p[1]) * u;
      var bx = p[6] + (p[4] - p[6]) * u, by = p[7] + (p[5] - p[7]) * u;
      return [tx + (bx - tx) * v, ty + (by - ty) * v];
    }
    for (var i = 0; i < SPLIT; i++) {
      for (var j = 0; j < SPLIT; j++) {
        var u0 = i / SPLIT, u1 = (i + 1) / SPLIT, v0 = j / SPLIT, v1 = (j + 1) / SPLIT;
        var a = at(u0, v0), b = at(u1, v0), c = at(u1, v1), d = at(u0, v1);
        var u = (u0 + u1) / 2, v = (v0 + v1) / 2;
        fillPoly(ctx, [a[0], a[1], b[0], b[1], c[0], c[1], d[0], d[1]],
          mix(cs, [(1 - u) * (1 - v), u * (1 - v), u * v, (1 - u) * v]));
      }
    }
  }

  function gradientTriangle(ctx, p, cs) {
    function at(a, b) {
      return [p[0] + (p[2] - p[0]) * a / SPLIT + (p[4] - p[0]) * b / SPLIT,
              p[1] + (p[3] - p[1]) * a / SPLIT + (p[5] - p[1]) * b / SPLIT];
    }
    function piece(q) {
      var a = (q[0][0] + q[1][0] + q[2][0]) / 3 / SPLIT, b = (q[0][1] + q[1][1] + q[2][1]) / 3 / SPLIT;
      var x = at(q[0][0], q[0][1]), y = at(q[1][0], q[1][1]), z = at(q[2][0], q[2][1]);
      fillPoly(ctx, [x[0], x[1], y[0], y[1], z[0], z[1]], mix(cs, [1 - a - b, a, b]));
    }
    for (var a = 0; a < SPLIT; a++) {
      for (var b = 0; a + b < SPLIT; b++) {
        piece([[a, b], [a + 1, b], [a, b + 1]]);
        if (a + b + 2 <= SPLIT) piece([[a + 1, b], [a + 1, b + 1], [a, b + 1]]);
      }
    }
  }

  function oval(cx, cy, rx, ry, angle, sectors) {
    var pts = [], n = Math.max(3, Math.round(sectors) || 30);
    var ca = Math.cos(angle || 0), sa = Math.sin(angle || 0);
    for (var k = 0; k < n; k++) {
      var t = 2 * Math.PI * k / n, x = rx * Math.cos(t), y = ry * Math.sin(t);
      pts.push(cx + x * ca - y * sa, cy + x * sa + y * ca);
    }
    return pts;
  }

  function strokePoly(ctx, pts, close, width, css) {
    path(ctx, pts, close);
    ctx.strokeStyle = css;
    ctx.lineWidth = width;
    ctx.lineJoin = "miter";
    ctx.stroke();
  }

  // one frame of a ruby2d window: the background, then the commands in order
  function drawScene(ctx, w, h, bg, cmds) {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.setLineDash([]);
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = rgba(bg[0], bg[1], bg[2], bg[3]);
    ctx.fillRect(0, 0, w, h);
    for (var i = 0; i < cmds.length; i++) {
      var c = cmds[i];
      switch (c[0]) {
        case "q": fillPoly(ctx, c.slice(1, 9), rgba(c[9], c[10], c[11], c[12])); break;
        case "Q": gradientQuad(ctx, c.slice(1, 9), c[9]); break;
        case "t": fillPoly(ctx, c.slice(1, 7), rgba(c[7], c[8], c[9], c[10])); break;
        case "T": gradientTriangle(ctx, c.slice(1, 7), c[7]); break;
        case "p": {
          var n = c[2].length / 4, ws = [];
          for (var k = 0; k < n; k++) ws.push(1 / n);
          fillPoly(ctx, c[1], mix(c[2], ws));
          break;
        }
        case "s": strokePoly(ctx, c[1], c[3], c[2], rgba(c[4][0], c[4][1], c[4][2], c[4][3])); break;
        case "c": fillPoly(ctx, oval(c[1], c[2], c[3], c[3], 0, c[4]), rgba(c[5], c[6], c[7], c[8])); break;
        case "C": strokePoly(ctx, oval(c[1], c[2], c[3], c[3], 0, c[4]), true, c[5], rgba(c[6], c[7], c[8], c[9])); break;
        case "e": fillPoly(ctx, oval(c[1], c[2], c[3], c[4], c[5], c[6]), rgba(c[7], c[8], c[9], c[10])); break;
        case "E": strokePoly(ctx, oval(c[1], c[2], c[3], c[4], c[5], c[6]), true, c[7], rgba(c[8], c[9], c[10], c[11])); break;
        case "l": {
          var s = c[8], e = c[9], style = rgba(s[0], s[1], s[2], s[3]);
          if (s.join() !== e.join()) {
            style = ctx.createLinearGradient(c[1], c[2], c[3], c[4]);
            style.addColorStop(0, rgba(s[0], s[1], s[2], s[3]));
            style.addColorStop(1, rgba(e[0], e[1], e[2], e[3]));
          }
          ctx.setLineDash(c[6] > 0 ? [c[6], c[7]] : []);
          ctx.lineCap = "butt";
          strokePoly(ctx, [c[1], c[2], c[3], c[4]], false, c[5], style);
          ctx.setLineDash([]);
          break;
        }
        case "x": {
          ctx.save();
          if (c[6]) {
            ctx.translate(c[7], c[8]);
            ctx.rotate(c[6] * Math.PI / 180);
            ctx.translate(-c[7], -c[8]);
          }
          ctx.font = textFont(c[4], c[5]);
          ctx.textBaseline = "top";
          ctx.fillStyle = rgba(c[9], c[10], c[11], c[12]);
          ctx.fillText(c[1], c[2], c[3]);
          if (c[5] & 12) {
            var tw = ctx.measureText(c[1]).width, lw = Math.max(1, c[4] / 14);
            if (c[5] & 4) ctx.fillRect(c[2], c[3] + c[4] * 1.1, tw, lw);
            if (c[5] & 8) ctx.fillRect(c[2], c[3] + c[4] * 0.6, tw, lw);
          }
          ctx.restore();
          break;
        }
      }
    }
  }

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
    var canvasMode = !!opts.canvas;
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
    var grid, cells, looks, canvas, ctx;
    if (canvasMode) {
      // the window at its size, smaller when the column is narrower
      canvas = el("canvas", "game-canvas", board);
      canvas.width = Math.round(w * DPR);
      canvas.height = Math.round(h * DPR);
      var shown = Math.min(w, Math.max(160, room));
      canvas.style.width = shown + "px";
      canvas.style.height = Math.round(shown * h / w) + "px";
      canvas.setAttribute("aria-hidden", "true");   // the name and the live region speak
      ctx = canvas.getContext("2d");
      grid = canvas;
    } else {
      grid = el("div", "game-grid", board);
      grid.setAttribute("aria-hidden", "true");   // emoji by the hundred: the live region speaks instead
      grid.style.gridTemplateColumns = "repeat(" + w + ", " + size + "px)";
      grid.style.gridTemplateRows = "repeat(" + h + ", " + size + "px)";
      grid.style.fontSize = Math.round(size * 0.78) + "px";
      cells = new Array(w * h);
      looks = new Array(w * h);
      for (var i = 0; i < w * h; i++) {
        cells[i] = el("div", ((i % w) + Math.floor(i / w)) % 2 ? "alt" : null, grid);
        looks[i] = "";
      }
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
      if (canvasMode) {
        if (f.c) drawScene(ctx, w, h, f.bg, f.c);
      } else if (f.d) {
        for (var k = 0; k < f.d.length; k++) paint(f.d[k][0], f.d[k][1]);
      }
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
      if (over && canvasMode) return;   // a closed window: ▶ runs the cell again
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
    node.addEventListener("blur", function () {
      focused = false;
      paused = true;
      if (canvasMode) releaseKeys();
      update();
    });
    node.addEventListener("keyup", function (e) {
      if (!canvasMode) return;
      var name = sdlKey(e.code);
      if (!name || !held[name]) return;
      delete held[name];
      push("u:" + name);
    });
    overlay.addEventListener("click", function () {
      node.focus({ preventScroll: true });
      play();
    });
    // the keys a ruby2d window holds down: up again when the window pauses
    var held = {};
    function releaseKeys() {
      for (var k in held) if (held.hasOwnProperty(k)) events.push("u:" + k);
      held = {};
    }

    node.addEventListener("keydown", function (e) {
      if (e.ctrlKey || e.metaKey || e.altKey || e.target !== node) return;
      if (canvasMode && e.key !== "Escape" && active() && !over) {
        var name = sdlKey(e.code);
        if (!name) return;          // Tab and the rest do what they always do
        e.preventDefault();
        if (e.repeat || held[name]) return;   // ruby2d repeats held keys itself
        held[name] = true;
        push("k:" + name);
        return;
      }
      var key = KEYS[e.key] || (/^[a-zA-Z0-9]$/.test(e.key) ? e.key.toLowerCase() : null);
      if (!key) return;           // Tab and the rest do what they always do
      var playing = active() && !over;
      if (key === "escape") {
        if (!playing) return;
        e.preventDefault();
        if (canvasMode) releaseKeys();
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

    // a ruby2d window gets the mouse in its own coordinates
    var BUTTONS = ["left", "middle", "right", "x1", "x2"];
    var lastX = null, lastY = null;
    function spot(e) {
      var r = canvas.getBoundingClientRect();
      return [Math.round((e.clientX - r.left) * w / r.width), Math.round((e.clientY - r.top) * h / r.height)];
    }
    if (canvasMode) {
      canvas.addEventListener("pointerdown", function (e) {
        if (!active() || over) return;
        var p = spot(e);
        lastX = p[0]; lastY = p[1];
        push("d:" + p[0] + "," + p[1] + "," + (BUTTONS[e.button] || "left"));
      });
      canvas.addEventListener("pointerup", function (e) {
        if (!active() || over) return;
        var p = spot(e);
        push("p:" + p[0] + "," + p[1] + "," + (BUTTONS[e.button] || "left"));
      });
      canvas.addEventListener("pointermove", function (e) {
        if (!active() || over) return;
        var p = spot(e);
        var dx = lastX === null ? 0 : p[0] - lastX, dy = lastY === null ? 0 : p[1] - lastY;
        lastX = p[0]; lastY = p[1];
        // one move a frame: the last place, the way summed up
        var prev = events.length ? events[events.length - 1] : "";
        if (prev.lastIndexOf("m:", 0) === 0) {
          var q = prev.slice(2).split(",");
          events[events.length - 1] = "m:" + p[0] + "," + p[1] + "," + (+q[2] + dx) + "," + (+q[3] + dy);
          return;
        }
        push("m:" + p[0] + "," + p[1] + "," + dx + "," + dy);
      });
      canvas.addEventListener("wheel", function (e) {
        if (!active() || over) return;
        e.preventDefault();
        push("w:" + Math.sign(e.deltaX) + "," + Math.sign(e.deltaY));
      }, { passive: false });
      canvas.addEventListener("contextmenu", function (e) { if (active()) e.preventDefault(); });
    }

    // a tap is a click on a cell, a swipe an arrow key (phones)
    var down = null;
    if (!canvasMode) grid.addEventListener("pointerdown", function (e) {
      down = [e.clientX, e.clientY];
    });
    if (!canvasMode) grid.addEventListener("pointerup", function (e) {
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
      // for the tests: a key as if pressed while the game runs (a ruby2d
      // window: down now, up a moment later)
      press: function (key) {
        push("k:" + key);
        if (canvasMode) setTimeout(function () { push("u:" + key); }, 120);
      },
      running: function () { return active() && !over; }
    };
    node.chunkyGame = controller;

    if (opts.first) apply(opts.first, true);
    showOverlay();
    return controller;
  };
})();
