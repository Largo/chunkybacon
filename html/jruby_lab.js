// JRuby for the JRuby lesson (docs/HANDOVER.md §6r): a lesson with
// "engine": "jruby" runs its cells on JRuby 10.1 (TeaVM, compiled to
// JavaScript) instead of CRuby - except a cell with "on": "cruby", which
// the page's own ruby.wasm runs, for the side-by-side. JRuby runs in a Web
// Worker (jruby_worker.js); this is the page's side of it, modelled on
// picoruby_lab.js.
//
//   ensureJRuby()                       the shell calls it when the lesson opens
//                                       (about 7 MB, the first time only)
//   chunkyJRuby.run(idx, code, earlier, seq)
//                                       main.rb, for a cell: +earlier+ is a JSON
//                                       list of [idx, code] of the cells above
//                                       that have not run in this page yet; they
//                                       run first, quietly, as CRuby's do
//   chunkyJRuby.reset()                 main.rb, a new lesson or a reset
//
// Answers come back as a "chunky:jruby" event on window: {idx, seq, elapsed
// (the cell's own run, s), total (with the cells above and the wait for the
// boot), status ("ok" | "error" | "stopped" | "failed"), output, value
// (the inspect), errorClass, line, message, earlier (the indices that ran
// first), earlierFailed}. One request at a time, in order. A run past the
// time limit cannot be interrupted: the worker is ended and a new one
// started - every variable is gone with it.
//
// While it loads, every .jruby-status element on the page (the lesson's
// first text cell has one) says how far it is.
(function () {
  "use strict";

  var LIMIT = 60000;   // ms: the biggest cell (the 7.3 MB JSON on a slow phone) needs a few seconds
  var queue = [];
  var current = null;
  var nextId = 1;
  var state = "idle";   // idle | download | boot | ready | stopped | failed
  var bootStarted = 0;

  var TEXT = {
    de: { download: "JRuby wird geladen … (rund 7 MB, nur beim ersten Mal)",
          boot: "JRuby startet … (rund 3 s)",
          ready: "JRuby ist bereit: %v, gestartet in %s s.",
          stopped: "JRuby wurde beendet; es startet beim nächsten Lauf neu (rund 3 s).",
          failed: "JRuby konnte nicht geladen werden: %m" },
    en: { download: "Loading JRuby … (about 7 MB, the first time only)",
          boot: "JRuby is starting … (about 3 s)",
          ready: "JRuby is ready: %v, started in %s s.",
          stopped: "JRuby was stopped; it starts again with the next run (about 3 s).",
          failed: "JRuby could not be loaded: %m" },
    ja: { download: "JRuby を読み込んでいます … (約 7 MB、初回のみ)",
          boot: "JRuby を起動しています … (約 3 秒)",
          ready: "JRuby の準備ができました: %v (起動 %s 秒)",
          stopped: "JRuby は停止しました。次の実行で再起動します (約 3 秒)。",
          failed: "JRuby を読み込めませんでした: %m" }
  };

  var jr = window.chunkyJRuby = {
    ready: false, loading: null, error: null, version: "", bootMs: 0, worker: null,

    run: function (idx, code, earlier, seq) {
      var list = [];
      try { list = JSON.parse(String(earlier || "[]")); } catch (e) { list = []; }
      enqueue({ kind: "run", idx: Number(idx), code: String(code), earlier: list, seq: Number(seq),
                queued: performance.now() });
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
      if (jr.worker) jr.worker.postMessage({ id: nextId++, kind: "fresh" });
    },
    status: function () { return state; },
    // the earthquake data for CRuby (jruby_cells.rb): fetched while the
    // lesson opens, so a CRuby cell's run does not wait for it
    text: function (url) {
      if (texts[url] !== undefined) return texts[url];
      try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, false);
        xhr.send(null);
        texts[url] = xhr.status === 200 ? xhr.responseText : "ERROR " + xhr.status;
      } catch (e) {
        return "ERROR " + e;
      }
      return texts[url];
    }
  };
  var texts = {};
  var DATA = "assets/jruby/data/all_month.geojson";

  function lang() {
    var l = (document.documentElement.lang || "de").slice(0, 2);
    return TEXT[l] ? l : "de";
  }

  // the status line(s) of the lesson; also called by the shell after it drew
  // the lesson (a new page has a new, empty one)
  function show() {
    var t = TEXT[lang()];
    var text = state === "ready"
      ? t.ready.replace("%v", jr.version).replace("%s", seconds(jr.bootMs))
      : state === "failed" ? t.failed.replace("%m", jr.error || "")
      : t[state] || "";
    var els = document.querySelectorAll(".jruby-status");
    for (var i = 0; i < els.length; i++) {
      if (els[i].textContent !== text) els[i].textContent = text;
      els[i].setAttribute("data-state", state);
    }
  }
  jr.show = show;
  // 4.9 in English and Japanese, 4,9 in German (as the course's text)
  function seconds(ms) {
    var s = (ms / 1000).toFixed(1);
    return lang() === "de" ? s.replace(".", ",") : s;
  }
  // the lesson's HTML comes and goes with the page: keep the line current
  var body = document.getElementById("lessonBody");
  if (body && window.MutationObserver) {
    new MutationObserver(function () { if (state !== "idle") show(); }).observe(body, { childList: true });
  }

  function setState(s) { state = s; show(); }

  // The bonus card (docs/HANDOVER.md §6r): its button puts jruby_swing.html
  // - JRuby 9.4 on CheerpJ, about 40 MB - into an iframe in place of the
  // card's preview. Nothing of it loads before that click; a new lesson page
  // drops the iframe, and the JVM in it, with the rest of the lesson's HTML.
  document.addEventListener("click", function (event) {
    var button = event.target && event.target.closest && event.target.closest(".jruby-swing-start");
    if (!button) return;
    var card = button.closest(".jruby-swing");
    if (!card || card.querySelector("iframe")) return;
    var frame = document.createElement("iframe");
    frame.className = "jruby-swing-frame";
    frame.title = button.getAttribute("data-frame-title") || "JRuby + Swing";
    frame.src = new URL("jruby_swing.html?lang=" + lang(), document.baseURI).href;
    var preview = card.querySelector(".jruby-swing-preview");
    if (preview) preview.remove();
    button.remove();
    card.appendChild(frame);
  });
  // the iframe says how tall its page is: no scroll bar inside the lesson
  window.addEventListener("message", function (event) {
    var data = event.data;
    if (event.origin !== location.origin || !data || data.chunkySwing !== "height") return;
    var frames = document.querySelectorAll("iframe.jruby-swing-frame");
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].contentWindow === event.source) frames[i].style.height = Math.ceil(Number(data.height) + 4) + "px";
    }
  });

  window.ensureJRuby = function () {
    if (texts[DATA] === undefined) {
      fetch(DATA).then(function (r) { return r.ok ? r.text() : null; })
        .then(function (t) { if (t !== null && texts[DATA] === undefined) texts[DATA] = t; })
        .catch(function () {});
    }
    if (jr.ready) { show(); return Promise.resolve(true); }
    if (jr.loading) return jr.loading;
    jr.error = null;
    bootStarted = performance.now();
    setState("download");
    jr.loading = new Promise(function (resolve) {
      var worker;
      try {
        worker = new Worker(new URL("jruby_worker.js", document.baseURI).href, { type: "module" });
      } catch (e) {
        fail(null, (e && e.message) || e, resolve);
        return;
      }
      worker.onmessage = function (event) {
        var data = event.data;
        if (data.progress) {
          setState(data.progress);
        } else if (data.ready) {
          jr.worker = worker;
          jr.ready = true;
          jr.version = data.version;
          // what the learner waited: from the click to the ready worker
          jr.bootMs = performance.now() - bootStarted;
          jr.workerBootMs = data.ms;
          setState("ready");
          resolve(true);
        } else if (data.failed !== undefined && data.id === undefined) {
          fail(worker, data.failed, resolve);
        } else {
          answered(data);
        }
      };
      worker.onerror = function (event) {
        if (!jr.ready) fail(worker, event.message || "jruby_worker.js could not start", resolve);
      };
    }).then(function (ok) {
      jr.loading = null;
      pump();
      return ok;
    });
    return jr.loading;
  };

  function fail(worker, message, resolve) {
    if (worker) worker.terminate();
    jr.error = String(message);
    console.error("JRuby (lesson) failed to load:", message);
    setState("failed");
    var waiting = queue;
    queue = [];
    waiting.forEach(function (item) { reply(item, { status: "failed", message: jr.error, output: "" }, 0); });
    resolve(false);
  }

  function enqueue(item) {
    queue.push(item);
    if (!jr.ready && !jr.loading) window.ensureJRuby();
    pump();
  }

  function pump() {
    if (current || !jr.ready || queue.length === 0) return;
    var item = queue.shift();
    var id = nextId++;
    current = { id: id, item: item, started: performance.now(),
                timer: setTimeout(function () { stop(id); }, LIMIT) };
    jr.worker.postMessage({ id: id, kind: "run", code: item.code,
                            earlier: item.earlier.map(function (pair) { return String(pair[1]); }) });
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
    current = null;
    endWorker();
    reply(done.item, { status: "stopped", output: "" }, performance.now() - done.started);
    if (queue.length) window.ensureJRuby();
  }

  function endWorker() {
    if (jr.worker) jr.worker.terminate();
    jr.worker = null;
    jr.ready = false;
    // the line said "ready": say that the next run boots a new one
    setState("stopped");
  }

  function reply(item, data, elapsed) {
    var earlier = item.earlier || [];
    var detail = {
      idx: item.idx, seq: item.seq, elapsed: elapsed / 1000,
      total: (performance.now() - item.queued) / 1000,
      status: String(data.status), output: String(data.output || ""), value: String(data.inspect || ""),
      errorClass: String(data.errorClass || ""), line: Number(data.line) || 0,
      message: String(data.message || ""),
      earlier: earlier.map(function (pair) { return pair[0]; }).join(","),
      earlierFailed: (data.earlierFailed || []).map(function (i) { return earlier[i] && earlier[i][0]; }).join(",")
    };
    window.dispatchEvent(new CustomEvent("chunky:jruby", { detail: detail }));
  }
})();
