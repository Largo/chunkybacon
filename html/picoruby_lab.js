// PicoRuby for the PicoRuby lesson (docs/HANDOVER.md §6m): a lesson with
// "engine": "picoruby" runs its cells and its IRBs on PicoRuby.wasm instead
// of CRuby. PicoRuby runs in a Web Worker (picoruby_worker.js); this is the
// page's side of it.
//
//   ensurePicoRuby()                 the shell calls it when such a lesson opens
//   chunkyPicoRuby.run(idx, code, auto, seq)   main.rb, for a cell
//   chunkyPicoRuby.irb(sid, code, seq)         main.rb, for a line in an IRB
//   chunkyPicoRuby.reset()           main.rb, a new lesson or a reset: no
//                                    variables left
//
// Answers come back as a "chunky:picoruby" event on window, {kind: "cell" |
// "irb", idx, sid, seq, auto, elapsed, status ("ok" | "error" | "syntax" |
// "stopped" | "failed"), output, value (the result's inspect), errorClass,
// line, message, irbs (show_irb calls)}, which main.rb turns into the cell's
// output. One request at a time, in order. A run that takes too long (a
// loop that never ends) cannot be interrupted inside PicoRuby: the worker
// is ended and a new one started, and the answer is status "stopped" -
// every variable is gone with it.
(function () {
  "use strict";

  var LIMIT = { auto: 1000, run: 10000, irb: 10000 };   // ms
  var queue = [];
  var current = null;   // {id, item, started, timer}: the request out now
  var nextId = 1;
  var sessions = {};    // the IRB sessions the worker has variables for

  var pico = window.chunkyPicoRuby = {
    ready: false, loading: null, error: null, version: "", worker: null,

    run: function (idx, code, auto, seq) {
      enqueue({ kind: "cell", idx: Number(idx), sid: "cells", code: String(code),
                auto: auto === true || auto === "true", seq: Number(seq) });
    },
    irb: function (sid, code, seq) {
      sessions["irb" + sid] = true;
      enqueue({ kind: "irb", sid: "irb" + sid, irbSid: Number(sid), code: String(code), seq: Number(seq) });
    },
    // a new lesson or a reset: the cells' and the IRBs' variables go. A run
    // still going would hold up the new page's runs (up to its 10 s): the
    // worker goes with it - its answer was for the page that went away
    reset: function () {
      queue = queue.filter(function (item) { return item.kind === "drop"; });
      if (current) {
        clearTimeout(current.timer);
        current = null;
        endWorker();
        return;
      }
      if (!pico.worker) return;
      enqueue({ kind: "drop", sid: "cells" });
      Object.keys(sessions).forEach(function (sid) { enqueue({ kind: "drop", sid: sid }); });
      sessions = {};
    }
  };

  window.ensurePicoRuby = function () {
    if (pico.ready) return Promise.resolve(true);
    if (pico.loading) return pico.loading;
    pico.error = null;
    pico.loading = new Promise(function (resolve) {
      var worker;
      try {
        worker = new Worker(new URL("picoruby_worker.js", document.baseURI).href, { type: "module" });
      } catch (e) {
        // no module workers here (or blocked): the same answer as a failed start
        fail(null, (e && e.message) || e, resolve);
        return;
      }
      worker.onmessage = function (event) {
        var data = event.data;
        if (data.ready) {
          pico.worker = worker;
          pico.ready = true;
          pico.version = data.version;
          resolve(true);
        } else if (data.failed) {
          fail(worker, data.failed, resolve);
        } else {
          answered(data);
        }
      };
      worker.onerror = function (event) {
        if (!pico.ready) fail(worker, event.message || "picoruby_worker.js could not start", resolve);
      };
    }).then(function (ok) {
      pico.loading = null;
      pump();
      return ok;
    });
    return pico.loading;
  };

  function fail(worker, message, resolve) {
    if (worker) worker.terminate();
    pico.error = String(message);
    console.error("PicoRuby (lesson) failed to load:", message);
    // what was waiting gets an answer, so no cell stays "running"
    var waiting = queue;
    queue = [];
    waiting.forEach(function (item) {
      reply(item, { status: "failed", message: pico.error, output: "" }, 0);
    });
    resolve(false);
  }

  function enqueue(item) {
    queue.push(item);
    if (!pico.ready && !pico.loading) window.ensurePicoRuby();
    pump();
  }

  function pump() {
    if (current || !pico.ready || queue.length === 0) return;
    var item = queue.shift();
    var id = nextId++;
    var limit = item.kind === "drop" ? 2000 : item.auto ? LIMIT.auto : item.kind === "irb" ? LIMIT.irb : LIMIT.run;
    current = { id: id, item: item, started: performance.now(),
                timer: setTimeout(function () { stop(id); }, limit) };
    pico.worker.postMessage({ id: id, kind: item.kind === "drop" ? "drop" : "run", sid: item.sid, code: item.code || "" });
  }

  function answered(data) {
    if (!current || data.id !== current.id) return;
    clearTimeout(current.timer);
    var done = current;
    current = null;
    reply(done.item, data, performance.now() - done.started);
    pump();
  }

  // the time is up: PicoRuby cannot be interrupted, the worker goes
  function stop(id) {
    if (!current || current.id !== id) return;
    var done = current;
    current = null;
    endWorker();
    reply(done.item, { status: "stopped", output: "" }, performance.now() - done.started);
    if (queue.length) window.ensurePicoRuby();
  }

  // the worker and every variable in it go; the next request starts a new one
  function endWorker() {
    pico.worker.terminate();
    pico.worker = null;
    pico.ready = false;
    sessions = {};
    // drops for the old worker mean nothing to a new one
    queue = queue.filter(function (item) { return item.kind !== "drop"; });
  }

  // every field is there (main.rb reads them with dots, jsg raises on a
  // missing one); "value" is the worker's inspect - a Ruby name of its own
  function reply(item, data, elapsed) {
    if (item.kind === "drop") return;
    var detail = {
      kind: item.kind, idx: item.idx || 0, sid: item.irbSid || 0, seq: item.seq || 0,
      auto: !!item.auto, elapsed: elapsed / 1000,
      status: String(data.status), output: String(data.output || ""), value: String(data.inspect || ""),
      errorClass: String(data.errorClass || ""), line: Number(data.line) || 0,
      message: String(data.message || ""), irbs: Number(data.irbs) || 0
    };
    window.dispatchEvent(new CustomEvent("chunky:picoruby", { detail: detail }));
  }
})();
