// IronRuby for the IronRuby lesson (docs/HANDOVER.md §6s): a lesson with
// "engine": "ironruby" runs its cells on IronRuby 4.0 - Ruby written in C#,
// on .NET 10 compiled to WebAssembly - instead of CRuby. IronRuby runs in a
// Web Worker (ironruby_worker.js); this is the page's side of it, modelled
// on picoruby_lab.js.
//
//   ensureIronRuby()                    the shell calls it when the lesson opens
//                                       (about 20 MB the first time, then cached)
//   chunkyIronRuby.run(idx, code, earlier, seq, probe)
//                                       main.rb, for a cell: +earlier+ is a JSON
//                                       list of [idx, code] of the cells above
//                                       that have not run in this page yet; they
//                                       run first, quietly, as CRuby's do.
//                                       +probe+: the exercise's IronRuby check
//   chunkyIronRuby.reset()              main.rb, a new lesson or a reset
//
// Answers come back as a "chunky:ironruby" event on window: {idx, seq,
// elapsed (the cell's own run, s), status ("ok" | "error" | "stopped" |
// "failed"), output, value (the inspect), errorClass, line, message, probe,
// earlier (the indices that ran first), earlierFailed}. One request at a
// time, in order. A run cannot be interrupted inside .NET: past the time
// limit, or on ■ Stop, the worker is ended and a new one started - every
// variable is gone with it.
//
// While it loads, every .ironruby-status element on the page (the lesson's
// first text cell has one) shows how far it is, with a progress bar.
(function () {
  "use strict";

  var LIMIT = 30000;   // ms: the slowest cell takes about half a second on a laptop
  var queue = [];
  var current = null;
  var nextId = 1;
  var state = "idle";   // idle | download | boot | ready | failed
  var progress = 0;     // 0..1 while downloading
  var bootStarted = 0;

  var TEXT = {
    de: { download: ".NET startet in deinem Browser … (rund 20 MB beim ersten Mal, danach aus dem Cache)",
          boot: "IronRuby startet …",
          ready: "IronRuby ist bereit: %v, gestartet in %s s.",
          failed: "IronRuby konnte nicht geladen werden: %m",
          stop: "■ Stopp" },
    en: { download: "Starting .NET in your browser … (about 20 MB the first time, then cached)",
          boot: "IronRuby is starting …",
          ready: "IronRuby is ready: %v, started in %s s.",
          failed: "IronRuby could not be loaded: %m",
          stop: "■ Stop" },
    ja: { download: "ブラウザーで .NET を起動しています … (初回は約 20 MB、次からはキャッシュ)",
          boot: "IronRuby を起動しています …",
          ready: "IronRuby の準備ができました: %v (起動 %s 秒)",
          failed: "IronRuby を読み込めませんでした: %m",
          stop: "■ 停止" }
  };

  var ir = window.chunkyIronRuby = {
    ready: false, loading: null, error: null, version: "", bootMs: 0, worker: null,

    run: function (idx, code, earlier, seq, probe) {
      var list = [];
      try { list = JSON.parse(String(earlier || "[]")); } catch (e) { list = []; }
      enqueue({ idx: Number(idx), code: String(code), earlier: list, seq: Number(seq),
                probe: probe ? String(probe) : "" });
    },
    reset: function () {
      queue = [];
      if (current) {
        // its answer was for the page that went away
        clearTimeout(current.timer);
        current = null;
        endWorker();
        return;
      }
      if (ir.worker) ir.worker.postMessage({ id: nextId++, kind: "fresh" });
    },
    status: function () { return state; }
  };

  function lang() {
    var l = (document.documentElement.lang || "de").slice(0, 2);
    return TEXT[l] ? l : "de";
  }

  // the status line(s) of the lesson; also called after the shell drew the
  // lesson (a new page has a new, empty one)
  function show() {
    var t = TEXT[lang()];
    var text = state === "ready"
      ? t.ready.replace("%v", ir.version).replace("%s", (ir.bootMs / 1000).toFixed(1))
      : state === "failed" ? t.failed.replace("%m", ir.error || "")
      : t[state] || "";
    var els = document.querySelectorAll(".ironruby-status");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var label = el.querySelector(".ironruby-status-text");
      var bar = el.querySelector("progress");
      if (!label) {
        el.textContent = "";
        label = document.createElement("span");
        label.className = "ironruby-status-text";
        el.appendChild(label);
        bar = document.createElement("progress");
        bar.max = 1;
        el.appendChild(bar);
      }
      if (label.textContent !== text) label.textContent = text;
      bar.hidden = !(state === "download" || state === "boot");
      // booting: an indeterminate bar (no value), downloading: how far
      if (state === "download") bar.value = progress; else bar.removeAttribute("value");
      el.setAttribute("data-state", state);
    }
  }
  ir.show = show;
  var body = document.getElementById("lessonBody");
  if (body && window.MutationObserver) {
    new MutationObserver(function () { if (state !== "idle") show(); }).observe(body, { childList: true });
  }

  function setState(s) { state = s; show(); }

  window.ensureIronRuby = function () {
    if (ir.ready) { show(); return Promise.resolve(true); }
    if (ir.loading) return ir.loading;
    ir.error = null;
    bootStarted = performance.now();
    progress = 0;
    setState("download");
    ir.loading = new Promise(function (resolve) {
      var worker;
      try {
        worker = new Worker(new URL("ironruby_worker.js", document.baseURI).href, { type: "module" });
      } catch (e) {
        fail(null, (e && e.message) || e, resolve);
        return;
      }
      worker.onmessage = function (event) {
        var data = event.data;
        if (data.progress) {
          if (data.progress === "download") progress = Math.min(1, (data.done || 0) / (data.total || 1));
          // all of it is here: what is left is .NET and IronRuby starting
          // (about 2 s, the bar without a value)
          setState(data.progress === "download" && progress >= 0.99 ? "boot" : data.progress);
        } else if (data.ready) {
          ir.worker = worker;
          ir.ready = true;
          ir.version = data.version;
          // what the learner waited: from the lesson's opening to the ready worker
          ir.bootMs = performance.now() - bootStarted;
          setState("ready");
          resolve(true);
        } else if (data.failed !== undefined && data.id === undefined) {
          fail(worker, data.failed, resolve);
        } else {
          answered(data);
        }
      };
      worker.onerror = function (event) {
        if (!ir.ready) fail(worker, event.message || "ironruby_worker.js could not start", resolve);
      };
    }).then(function (ok) {
      ir.loading = null;
      pump();
      return ok;
    });
    return ir.loading;
  };

  function fail(worker, message, resolve) {
    if (worker) worker.terminate();
    ir.error = String(message);
    console.error("IronRuby (lesson) failed to load:", message);
    setState("failed");
    var waiting = queue;
    queue = [];
    waiting.forEach(function (item) { reply(item, { status: "failed", message: ir.error, output: "" }, 0); });
    resolve(false);
  }

  function enqueue(item) {
    queue.push(item);
    if (!ir.ready && !ir.loading) window.ensureIronRuby();
    pump();
  }

  function pump() {
    if (current || !ir.ready || queue.length === 0) return;
    var item = queue.shift();
    var id = nextId++;
    current = { id: id, item: item, started: performance.now(),
                timer: setTimeout(function () { stop(id); }, LIMIT) };
    stopButton(item.idx, id);
    ir.worker.postMessage({ id: id, kind: "run", code: item.code, probe: item.probe,
                            earlier: item.earlier.map(function (pair) { return String(pair[1]); }) });
  }

  // ■ Stop in the cell's output while it runs (main.rb writes over it with the answer)
  function stopButton(idx, id) {
    var out = document.getElementById("cell-out-" + idx);
    if (!out) return;
    var button = document.createElement("button");
    button.type = "button";
    button.className = "ironruby-stop";
    button.textContent = TEXT[lang()].stop;
    button.addEventListener("click", function () { stop(id); });
    out.innerHTML = "";
    out.appendChild(button);
    out.style.display = "block";
  }

  function answered(data) {
    if (!current || data.id !== current.id) return;
    clearTimeout(current.timer);
    var done = current;
    current = null;
    reply(done.item, data, data.cellMs || 0);
    pump();
  }

  function stop(id) {
    if (!current || current.id !== id) return;
    var done = current;
    clearTimeout(done.timer);
    current = null;
    endWorker();
    reply(done.item, { status: "stopped", output: "" }, performance.now() - done.started);
    // a new worker right away: the next run should not wait for its boot
    window.ensureIronRuby();
  }

  function endWorker() {
    if (ir.worker) ir.worker.terminate();
    ir.worker = null;
    ir.ready = false;
    state = "idle";
  }

  function reply(item, data, elapsed) {
    var earlier = item.earlier || [];
    var detail = {
      idx: item.idx, seq: item.seq, elapsed: elapsed / 1000,
      status: String(data.status), output: String(data.output || ""), value: String(data.inspect || ""),
      errorClass: String(data.errorClass || ""), line: Number(data.line) || 0,
      message: String(data.message || ""),
      probe: data.probe === null || data.probe === undefined ? "" : String(data.probe),
      earlier: earlier.map(function (pair) { return pair[0]; }).join(","),
      earlierFailed: (data.earlierFailed || []).map(function (i) { return earlier[i] && earlier[i][0]; }).join(",")
    };
    // (for test/ironruby_test.mjs: what the exercise's probe said last)
    if (item.probe) ir.lastProbe = detail.probe;
    window.dispatchEvent(new CustomEvent("chunky:ironruby", { detail: detail }));
  }
})();
