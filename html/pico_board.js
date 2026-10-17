// The bench of the Pico lessons (docs/HANDOVER.md §6r): what the simulated
// Pico and its parts look like while a cell runs, and the inputs a learner
// gives them. PLACEHOLDER: the API the page and the worker use is final,
// the drawing is not - this shows the parts, the state as text, and a ■
// Stop button; the SVG of the Pico 2 W, its pins, wires and parts (design
// §1.6) replaces the body of render().
//
//   chunkyPicoBoard.mount(idx, configJson)  build for these parts, move into #pico-slot-<idx>, show
//   chunkyPicoBoard.receive(kind, text)     "state" | "epd_frame" | "ble" | "log" from the worker
//   chunkyPicoBoard.inputs()                JSON of the current inputs, sent with each run
//   chunkyPicoBoard.input(key, value)       set one (and tell a running cell: chunkyPicoRuby.input)
//   chunkyPicoBoard.reset(reason)           the worker ended: "reset" badge; the e-paper keeps its picture
//   chunkyPicoBoard.unmount()               another lesson
//
// Input keys: pin14 ("1" pressed), adc26 (0..1), tempC, bme.t, bme.rh,
// bme.p, arena.box / arena.bacon ("x,y" cm), wifi.off ("1"), camera
// (a picture's name), ble.line ("<n>|<text>", a new n sends the text once),
// ble.connected ("1"/"0").
(function () {
  "use strict";

  var values = {};
  var bench = null;   // {el, idx, config, state, frames, log}
  var lineNo = 0;

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function build(config) {
    var figure = el("figure", "pico-bench");
    figure.setAttribute("role", "group");
    figure.setAttribute("aria-label", "Pico " + (config.board || "pico2w"));
    var caption = el("figcaption", "pico-parts", (config.board || "pico2w") + ": " + (config.parts || []).join(", "));
    var state = el("pre", "pico-state");
    var status = el("p", "pico-status");
    status.setAttribute("role", "status");
    status.setAttribute("aria-live", "polite");
    var stop = el("button", "pico-stop", "■");
    stop.type = "button";
    stop.title = "Stop (reset the Pico)";
    stop.addEventListener("click", function () {
      if (window.chunkyPicoRuby && window.chunkyPicoRuby.stop) window.chunkyPicoRuby.stop();
    });
    figure.appendChild(caption);
    figure.appendChild(stop);
    figure.appendChild(state);
    figure.appendChild(status);
    return { el: figure, state: state, status: status, config: config, frames: 0, log: [] };
  }

  function render() {
    if (!bench) return;
    bench.state.textContent = bench.lastState || "";
  }

  var api = window.chunkyPicoBoard = {
    mount: function (idx, configJson) {
      var config = {};
      try { config = JSON.parse(String(configJson || "{}")); } catch (e) { config = {}; }
      var key = JSON.stringify([config.board, config.parts]);
      if (!bench || bench.key !== key) {
        if (bench && bench.el.parentNode) bench.el.parentNode.removeChild(bench.el);
        bench = build(config);
        bench.key = key;
      }
      bench.idx = String(idx);
      var slot = document.getElementById("pico-slot-" + idx);
      if (slot) {
        document.querySelectorAll(".pico-slot").forEach(function (s) { if (s !== slot) s.hidden = true; });
        slot.appendChild(bench.el);
        slot.hidden = false;
      }
      bench.status.textContent = "";
    },
    receive: function (kind, text) {
      if (!bench) return;
      if (kind === "state") {
        bench.lastState = String(text);
        render();
      } else if (kind === "epd_frame") {
        bench.frames++;
        bench.lastFrame = String(text);
        bench.status.textContent = "E-paper: " + bench.frames;
      } else {
        bench.log.push([kind, String(text)]);
        if (bench.log.length > 50) bench.log.shift();
        if (kind === "ble" && String(text).indexOf("tx|") === 0) {
          window.dispatchEvent(new CustomEvent("chunky:pico-ble", { detail: { text: String(text).slice(3) } }));
        }
      }
    },
    inputs: function () { return JSON.stringify(values); },
    input: function (key, value) {
      values[String(key)] = String(value);
      if (window.chunkyPicoRuby && window.chunkyPicoRuby.input) window.chunkyPicoRuby.input(String(key), String(value));
    },
    // a line from the laptop's side (the bench's laptop panel, the CRuby cell)
    sendLine: function (text) {
      lineNo++;
      api.input("ble.line", lineNo + "|" + String(text));
    },
    reset: function (reason) {
      if (!bench) return;
      bench.status.textContent = "reset";
      bench.lastReset = String(reason || "");
    },
    unmount: function () {
      if (bench && bench.el.parentNode) bench.el.parentNode.removeChild(bench.el);
      bench = null;
    },
    // for tests: what the bench holds now
    debug: function () {
      return bench ? { idx: bench.idx, frames: bench.frames, state: bench.lastState || "", frame: bench.lastFrame || "",
                       log: bench.log.slice(), reset: bench.lastReset || "" } : null;
    }
  };
})();
