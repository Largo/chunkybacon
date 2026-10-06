// The stepper (experiments/02-time-travel-tracer): ⏯ beside ▶, in a lesson
// with "stepper": true, runs the cell recorded line by line (main.rb's
// run_cell(idx, step: true), step_recorder.rb), and this walks the learner
// through that run: the line about to run marked in the cell's own editor,
// Chunky's sentence about the step, the variables of each frame (the cell,
// a method, a block with its pass), the output so far - in
// #cell-out-<idx>, above the run's own output.
//
//   ChunkyStepper.show(idx, trace)  the recording (bridge.js parsed the JSON)
//   ChunkyStepper.clear(idx)        an edit or a new run of the cell (the
//                                   line numbers would no longer match)
//   ChunkyStepper.clearAll()        a lesson reset
//   ChunkyStepper.page(lang, lesson, workshop)   the shell drew a page
//       (bridge.js, after its paint): another lesson drops every recording;
//       the same lesson again - another language - shows each one again,
//       at its step, where the cell's code is the same apart from comments
//       (en <-> ja, and cells whose German code is the English one)
//
// Keyboard and screen readers: the slider is a native range input (arrow
// keys, Home, End, Page Up/Down), named, its value "Schritt 3 von 12". The
// buttons are aria-disabled at the ends, never disabled, so the focus stays
// where it is. A polite live region says the step's sentence and what
// changed - after a move of the learner's, never on the ticks of ⏵, which
// steps more slowly under prefers-reduced-motion. Styles: app.css .step-*.
(function () {
  "use strict";

  var TICK = 700, TICK_CALM = 1500;   // ms per step while ⏵ plays
  var kept = {};                      // idx -> {trace, step, editor, node, line, timer}
  var shown = { lesson: null };

  function strings() {
    var all = window.LESSONS.ui;
    return all[lang()] || all.de;
  }
  function lang() { return window.ChunkyBridge ? window.ChunkyBridge.state.lang : "de"; }

  // the course's ui strings are Ruby format strings: %s and %d, in order
  function fmt(text, args) {
    var i = 0;
    return String(text || "").replace(/%[sd]/g, function () {
      var v = args[i++];
      return v === undefined || v === null ? "" : String(v);
    });
  }
  function ordinal(n) {
    var s = ["th", "st", "nd", "rd"], v = n % 100;
    return n + (s[(v - 20) % 10] || s[v] || s[0]);
  }
  function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  function el(tag, cls, parent) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (parent) parent.appendChild(e);
    return e;
  }
  function calm() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  // The code without its comments, line by line: what a language change
  // may change in a cell without changing what it does. ("#{" and "#@"
  // are interpolation, not a comment.)
  function codeOnly(code) {
    return String(code || "").split("\n").map(function (line) {
      return line.replace(/(^|\s)#(?![{$@]).*$/, "").replace(/\s+$/, "");
    }).join("\n").replace(/\n+$/, "");
  }

  // output offsets are bytes (Ruby's bytesize), JavaScript strings UTF-16;
  // terminal colours are left out (the run's own output below has them)
  var encoder = new TextEncoder(), decoder = new TextDecoder();
  function outputUpTo(trace, bytes) {
    if (!trace.bytes) trace.bytes = encoder.encode(trace.output || "");
    return decoder.decode(trace.bytes.slice(0, bytes || 0)).replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
  }

  function framesOf(trace, step) { return (step.f || []).map(function (i) { return trace.frames[i]; }); }
  function varMap(frame) {
    var m = {};
    (frame.vars || []).forEach(function (v) { m[v[0]] = v[1]; });
    return m;
  }

  // What Chunky says about a step
  function sentence(t, trace, s) {
    var frames = framesOf(trace, s), top = frames[frames.length - 1] || {};
    if (s.event === "line" || s.event === "recorder-error") {
      if (s.hit > 1) return fmt(t.stepLineAgain, [s.line, lang() === "en" ? ordinal(s.hit) : s.hit]);
      return fmt(t.stepLine, [s.line]);
    }
    if (s.event === "call") {
      return fmt(t.stepCall, [top.name, (top.vars || []).map(function (v) { return v[1]; }).join(", ")]);
    }
    if (s.event === "return") return fmt(t.stepReturn, [top.name, s.value]);
    if (s.event === "error") return fmt(t.stepError, [s.line || "?", s.value]);
    return fmt(t.stepEnd, [s.value]);
  }

  // the frames, outermost first; a value that differs from the step before
  // is "changed" (in a block's new pass, all of them). Returns the HTML and
  // the changes in words, for the live region.
  function framesHtml(t, trace, step) {
    var s = trace.steps[step], prev = step > 0 ? trace.steps[step - 1] : null;
    var frames = framesOf(trace, s), before = prev ? framesOf(trace, prev) : [];
    var changes = [];
    var html = frames.map(function (f, k) {
      if (f.kind === "more") {
        return '<div class="step-frame"><p class="step-empty">' + esc(fmt(t.stepMore, [String(f.name).replace("… ", "")])) + "</p></div>";
      }
      var old = before[k] && before[k].name === f.name && before[k].iter === f.iter ? varMap(before[k]) : null;
      var head = f.kind === "main" ? t.stepMain : fmt(f.kind === "method" ? t.stepMethod : t.stepBlock, [f.name]);
      var rows = (f.vars || []).map(function (v) {
        var changed = prev && (old ? old[v[0]] !== v[1] : f.kind !== "main");
        if (changed) changes.push(v[0] + " = " + v[1]);
        return '<tr class="' + (changed ? "changed" : "") + (v[2] ? " earlier" : "") + '"><th scope="row">' + esc(v[0]) +
          '</th><td>' + esc(v[1]) + (changed ? ' <span class="sr-only">(' + esc(t.stepChanged) + ")</span>" : "") + "</td></tr>";
      }).join("");
      return '<div class="step-frame' + (k === frames.length - 1 ? " is-top" : "") + '"><p class="step-frame-head"><span>' + esc(head) + "</span>" +
        (f.iter ? '<span class="step-pass">' + esc(fmt(t.stepPass, [f.iter])) + "</span>" : "") + "</p>" +
        (rows ? '<table class="step-vars">' + rows + "</table>" : '<p class="step-empty">' + esc(t.stepNoVars) + "</p>") + "</div>";
    }).join("");
    return { html: html, changes: changes };
  }

  // ---- the widget ----

  function build(idx) {
    var k = kept[idx], t = strings(), n = k.trace.steps.length;
    var out = document.getElementById("cell-out-" + idx);
    if (!out) return false;
    var node = el("div", "stepper");
    node.setAttribute("role", "group");
    var button = document.querySelector('.step-cell[data-idx="' + idx + '"]');
    node.setAttribute("aria-label", button ? button.getAttribute("aria-label") : t.stepSlider);
    k.node = node;
    if (!n) {
      el("p", "step-note", node).textContent = t.stepNone;
    } else {
      k.say = el("p", "step-say", node);
      var body = el("div", "step-body", node);
      k.frames = el("div", "step-frames", body);
      var side = el("div", "step-output", body);
      el("p", "step-out-label", side).textContent = t.stepOutput;
      k.out = el("pre", "step-out", side);
      var bar = el("div", "step-controls", node);
      var buttons = {};
      var add = function (name, text, parent) {
        var b = el("button", "step-" + name, parent);
        b.type = "button";
        b.textContent = text;
        b.addEventListener("click", function () { if (b.getAttribute("aria-disabled") !== "true") act(idx, name); });
        buttons[name] = b;
      };
      var back = el("span", "step-btns", bar);
      add("first", "⏮", back);
      add("prev", "◀", back);
      var slider = k.slider = el("input", "step-slider", bar);
      slider.type = "range";
      slider.min = "0";
      slider.max = String(n - 1);
      slider.step = "1";
      slider.addEventListener("input", function () { go(idx, Number(slider.value), true); });
      var ahead = el("span", "step-btns", bar);
      add("next", "▶", ahead);
      add("last", "⏭", ahead);
      add("play", "", bar);   // with its word: ⏵ alone looks like ▶
      k.count = el("span", "step-count", bar);
      k.count.setAttribute("aria-hidden", "true");   // the slider's value says it
      k.buttons = buttons;
      if (k.trace.truncated) el("p", "step-note is-warn", node).textContent = fmt(t.stepTruncated, [n - 1]);
      el("p", "step-legend", node).textContent = t.stepLegend;
      k.live = el("p", "sr-only step-live", node);
      k.live.setAttribute("aria-live", "polite");
      k.live.setAttribute("aria-atomic", "true");
      label(idx);
    }
    out.insertBefore(node, out.firstChild);
    out.style.display = "block";
    watch(idx);
    if (n) render(idx, false);
    return true;
  }

  // the buttons' and the slider's names, in the page's language; ⏵ says
  // its word on the button itself (and turns into ⏸ while it plays)
  function label(idx) {
    var k = kept[idx], t = strings(), b = k.buttons;
    var names = { first: t.stepFirst, prev: t.stepPrev, next: t.stepNext, last: t.stepLast };
    Object.keys(names).forEach(function (name) {
      b[name].setAttribute("aria-label", names[name]);
      b[name].title = names[name];
    });
    b.play.textContent = k.timer ? "⏸ " + t.stepPause : "⏵ " + t.stepPlay;
    k.slider.setAttribute("aria-label", t.stepSlider);
  }

  // Draws step k.step; +say+: the learner moved, so the live region speaks
  function render(idx, say) {
    var k = kept[idx], t = strings(), trace = k.trace, n = trace.steps.length, s = trace.steps[k.step];
    var words = sentence(t, trace, s);
    k.say.textContent = words;
    k.say.className = "step-say" + (s.event === "error" ? " is-error" : "");
    var frames = framesHtml(t, trace, k.step);
    k.frames.innerHTML = frames.html;
    k.out.textContent = outputUpTo(trace, s.out);
    k.slider.value = String(k.step);
    var count = fmt(t.stepCount, [k.step + 1, n]);
    k.slider.setAttribute("aria-valuetext", count);
    k.count.textContent = count;
    ["first", "prev"].forEach(function (b) { k.buttons[b].setAttribute("aria-disabled", k.step === 0 ? "true" : "false"); });
    ["next", "last"].forEach(function (b) { k.buttons[b].setAttribute("aria-disabled", k.step === n - 1 ? "true" : "false"); });
    mark(idx, s);
    if (say) speak(k, words + (frames.changes.length ? " " + frames.changes.join(", ") : ""));
  }

  // emptied first, the text a moment later: the same sentence twice (a
  // loop's line) is read twice
  function speak(k, text) {
    k.live.textContent = "";
    clearTimeout(k.speaking);
    k.speaking = setTimeout(function () { k.live.textContent = text; }, 50);
  }

  // the line about to run, in the cell's editor (CodeMirror's line class,
  // like the error line's marker); none after the end
  function mark(idx, s) {
    var k = kept[idx], ed = k.editor;
    if (!ed) return;
    if (k.line) ed.removeLineClass(k.line.n, "background", k.line.cls);
    k.line = null;
    if (!s.line || s.event === "end" || s.line > ed.lineCount()) return;
    var cls = "step-now" + (s.event === "line" || s.event === "recorder-error" ? "" : " step-" + s.event);
    k.line = { n: s.line - 1, cls: cls };
    ed.addLineClass(k.line.n, "background", cls);
  }

  function go(idx, step, byLearner) {
    var k = kept[idx];
    if (!k) return;
    if (byLearner) stop(idx);
    k.step = Math.max(0, Math.min(step, k.trace.steps.length - 1));
    render(idx, byLearner);
  }

  function act(idx, name) {
    var k = kept[idx], last = k.trace.steps.length - 1;
    if (name === "play") return play(idx);
    go(idx, { first: 0, prev: k.step - 1, next: k.step + 1, last: last }[name], true);
  }

  // ⏵: a step every TICK ms to the end; quiet, the learner watches
  function play(idx) {
    var k = kept[idx];
    if (k.timer) {
      stop(idx);
      render(idx, true);   // where it stopped, said once
      return;
    }
    if (k.step >= k.trace.steps.length - 1) go(idx, 0, false);
    k.timer = setInterval(function () {
      if (!kept[idx] || kept[idx] !== k) return clearInterval(k.timer);
      if (k.step >= k.trace.steps.length - 1) { stop(idx); return; }
      go(idx, k.step + 1, false);
    }, calm() ? TICK_CALM : TICK);
    label(idx);
  }

  function stop(idx) {
    var k = kept[idx];
    if (!k || !k.timer) return;
    clearInterval(k.timer);
    k.timer = null;
    if (k.buttons) label(idx);
  }

  // any change to the cell's code ends its recording (setValue too: a reset)
  function watch(idx) {
    var ed = kept[idx].editor;
    if (!ed || ed.chunkyStepperWatch) return;
    ed.chunkyStepperWatch = true;
    ed.on("change", function (cm) {
      var k = kept[idx];
      if (k && k.editor === cm) clear(idx);
    });
  }

  function clear(idx) {
    var k = kept[idx];
    if (!k) return;
    stop(idx);
    delete kept[idx];
    if (k.editor && k.line) k.editor.removeLineClass(k.line.n, "background", k.line.cls);
    var node = k.node;
    if (!node || !node.parentNode) return;
    // the keyboard was in the stepper (Alt+R on the exercise): to the code
    var inside = node.contains(document.activeElement);
    var out = node.parentNode;
    node.remove();
    if (!out.textContent.trim() && !out.querySelector("img, audio, iframe, canvas")) out.style.display = "none";
    if (inside && k.editor) k.editor.focus();
  }

  window.ChunkyStepper = {
    show: function (idx, trace) {
      clear(idx);
      shown.lesson = window.ChunkyBridge ? window.ChunkyBridge.state.lesson : shown.lesson;
      kept[idx] = { trace: trace, step: 0, editor: window.cellEditors[idx] || null };
      if (!build(idx)) delete kept[idx];
    },
    clear: clear,
    clearAll: function () { Object.keys(kept).forEach(clear); },
    page: function (lang, lesson, workshop) {
      var same = !workshop && lesson === shown.lesson;
      shown.lesson = workshop ? null : lesson;
      Object.keys(kept).forEach(function (idx) {
        var k = kept[idx];
        stop(idx);
        if (k.node && k.node.isConnected) return;   // still on the page
        var ed = window.cellEditors[idx];
        delete kept[idx];
        if (!same || !ed || codeOnly(ed.getValue()) !== codeOnly(k.trace.code)) return;
        kept[idx] = { trace: k.trace, step: k.step, editor: ed };
        if (!build(idx)) delete kept[idx];
      });
    },
    // for the tests
    state: function (idx) { var k = kept[idx]; return k ? { step: k.step, steps: k.trace.steps.length, playing: !!k.timer } : null; }
  };
})();
