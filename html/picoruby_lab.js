// PicoRuby for the PicoRuby lesson (docs/HANDOVER.md §6m): a lesson with
// "engine": "picoruby" runs its cells and its IRBs on PicoRuby.wasm instead
// of CRuby. PicoRuby runs in a Web Worker (picoruby_worker.js); this is the
// page's side of it.
//
//   ensurePicoRuby()                 the shell calls it when such a lesson opens
//   chunkyPicoRuby.run(idx, code, auto, seq, tabsJson, boardJson)
//                                    main.rb, for a cell; the last two are
//                                    optional: the cell's tabs
//                                    ([{name, code}]) and its board (§6r)
//   chunkyPicoRuby.irb(sid, code, seq, boardJson)   main.rb, a line in an IRB
//   chunkyPicoRuby.reset()           main.rb, a new lesson or a reset: no
//                                    variables left
//   chunkyPicoRuby.input(key, value) the bench (pico_board.js): a button, a
//                                    slider - reaches a run that goes on
//   chunkyPicoRuby.stop()            the bench's ■: the Pico's reset - the
//                                    run ends as on the time limit
//
// Answers come back as a "chunky:picoruby" event on window, {kind: "cell" |
// "irb", idx, sid, seq, auto, elapsed, status ("ok" | "error" | "syntax" |
// "stopped" | "reset" | "failed"), output, value (the result's inspect),
// errorClass, line, file (the tab the error is in, "" for the cell's own
// code), message, irbs (show_irb calls), board (the simulated board's
// summary JSON, "" without a board)}, which main.rb turns into the cell's
// output. What a run prints comes early too, as "chunky:picoruby-progress"
// events ({idx, kind, seq, output}), and the bench's messages go to
// chunkyPicoBoard.receive(kind, text). One request at a time, in order. A
// run that takes too long (a loop that never ends) cannot be interrupted
// inside PicoRuby: the worker is ended and a new one started, and the
// answer is status "stopped" - every variable is gone with it.
(function () {
  "use strict";

  // ms; a cell with a board (a Pico lesson) runs as long as a program on a
  // Pico might, an IRB line below it half that
  var LIMIT = { auto: 1000, run: 10000, irb: 10000, board: 60000, boardIrb: 30000 };
  var queue = [];
  var current = null;   // {id, item, started, timer}: the request out now
  var nextId = 1;
  var sessions = {};    // the IRB sessions the worker has variables for

  var pico = window.chunkyPicoRuby = {
    ready: false, loading: null, error: null, version: "", worker: null,

    run: function (idx, code, auto, seq, tabsJson, boardJson) {
      enqueue({ kind: "cell", idx: Number(idx), sid: "cells", code: String(code),
                auto: auto === true || auto === "true", seq: Number(seq),
                tabs: parseTabs(tabsJson), board: boardJson ? String(boardJson) : "" });
    },
    // an IRB below a board cell (a Pico lesson) shares the cells' session:
    // its lines see the cell's `led` and drive the same board
    irb: function (sid, code, seq, boardJson) {
      var worker = boardJson ? "cells" : "irb" + sid;
      if (!boardJson) sessions[worker] = true;
      enqueue({ kind: "irb", sid: worker, irbSid: Number(sid), code: String(code), seq: Number(seq),
                tabs: [], board: boardJson ? String(boardJson) : "" });
    },
    // a bench input (pico_board.js): at once, even while a run goes on
    input: function (key, value) {
      if (pico.worker) pico.worker.postMessage({ kind: "input", key: String(key), value: String(value) });
    },
    // the bench's ■ Stop, the Pico's reset: like the time limit, but the
    // answer says "reset"
    stop: function () {
      if (current) stop(current.id, "reset");
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
        } else if (data.progress !== undefined) {
          progress(data);
        } else if (data.board !== undefined && data.status === undefined) {
          if (window.chunkyPicoBoard && current && data.id === current.id) window.chunkyPicoBoard.receive(String(data.board), String(data.text));
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
    var board = !!item.board;
    var limit = item.kind === "drop" ? 2000 : item.auto ? LIMIT.auto
      : item.kind === "irb" ? (board ? LIMIT.boardIrb : LIMIT.irb) : (board ? LIMIT.board : LIMIT.run);
    current = { id: id, item: item, started: performance.now(),
                timer: setTimeout(function () { stop(id); }, limit) };
    var inputs = board && window.chunkyPicoBoard && window.chunkyPicoBoard.inputs ? parseInputs(window.chunkyPicoBoard.inputs()) : {};
    // the bench was moved under this cell when ▶ was pressed; it draws this
    // run's state from now on, not the one of the run it waited for
    if (board && item.kind === "cell" && window.chunkyPicoBoard && window.chunkyPicoBoard.started) window.chunkyPicoBoard.started(String(item.idx));
    pico.worker.postMessage({ id: id, kind: item.kind === "drop" ? "drop" : "run", sid: item.sid, code: item.code || "",
                              tabs: item.tabs || [], board: item.board || "", inputs: inputs });
  }

  function parseTabs(json) {
    if (!json) return [];
    try {
      var list = JSON.parse(String(json));
      return Array.isArray(list) ? list.map(function (t) { return { name: String(t.name), code: String(t.code || "") }; }) : [];
    } catch (e) { return []; }
  }

  function parseInputs(json) {
    try { var v = JSON.parse(String(json || "{}")); return v && typeof v === "object" ? v : {}; } catch (e) { return {}; }
  }

  // what a run printed so far: main.rb shows it below the cell while it runs
  function progress(data) {
    if (!current || data.id !== current.id || current.item.kind === "drop") return;
    var item = current.item;
    // kept for the answer of a run that is stopped: what it printed stays
    current.streamed = (current.streamed || "") + String(data.progress);
    window.dispatchEvent(new CustomEvent("chunky:picoruby-progress", {
      detail: { idx: item.idx || 0, kind: item.kind, sid: item.irbSid || 0, seq: item.seq || 0, output: String(data.progress) }
    }));
  }

  function answered(data) {
    if (!current || data.id !== current.id) return;
    clearTimeout(current.timer);
    var done = current;
    current = null;
    reply(done.item, data, performance.now() - done.started);
    pump();
  }

  // the time is up (or ■ was pressed: "reset"): PicoRuby cannot be
  // interrupted, the worker goes
  function stop(id, status) {
    if (!current || current.id !== id) return;
    var done = current;
    clearTimeout(done.timer);
    current = null;
    endWorker();
    if (done.item.board && window.chunkyPicoBoard && window.chunkyPicoBoard.reset) window.chunkyPicoBoard.reset(status || "stopped");
    reply(done.item, { status: status || "stopped", output: done.streamed || "" }, performance.now() - done.started);
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
      errorClass: String(data.errorClass || ""), line: Number(data.line) || 0, file: String(data.file || ""),
      message: String(data.message || ""), irbs: Number(data.irbs) || 0, board: String(data.board || "")
    };
    window.dispatchEvent(new CustomEvent("chunky:picoruby", { detail: detail }));
  }
})();
