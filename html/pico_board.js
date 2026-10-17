// The bench of the Pico lessons (docs/HANDOVER.md §6r): an SVG of the
// simulated Raspberry Pi Pico 2 W, the parts a cell names (board.parts), the
// jumper wires between them, and real HTML controls for what a learner does
// to the parts. The simulator (html/pico_sim/) runs in the lesson's worker;
// this file only draws what it reports and sends inputs back.
//
//   chunkyPicoBoard.mount(idx, configJson, uiJson)  build for these parts, move into #pico-slot-<idx>, show
//   chunkyPicoBoard.receive(kind, text)     "state" | "epd_frame" | "ble" | "log" from the worker
//   chunkyPicoBoard.inputs()                JSON of the current inputs, sent with each run
//   chunkyPicoBoard.input(key, value)       set one (and tell a running cell: chunkyPicoRuby.input)
//   chunkyPicoBoard.sendLine(text)          a line from the laptop's side to the Pico (BLE RX)
//   chunkyPicoBoard.ble()                   JSON {adv, connected, running}: for html/pico_laptop.rb
//   chunkyPicoBoard.started(idx)            the worker took that cell's run (picoruby_lab.js)
//   chunkyPicoBoard.reset(reason)           the worker ended: "reset" badge; the e-paper keeps its picture
//   chunkyPicoBoard.unmount()               another lesson
//   chunkyPicoBoard.debug()                 what the bench holds (the browser tests)
//
// Input keys: pin14 ("1" pressed), adc26 (0..1), tempC, bme.t, bme.rh,
// bme.p, arena.box / arena.bacon ("x,y" cm), wifi.off ("1"), camera
// (a picture's name), ble.line ("<n>|<text>", a new n sends the text once),
// ble.connected ("1"/"0").
//
// Drawing: 1 mm = 5 px, so the Pico is 255 x 105, landscape with the USB
// on the left; the bottom row is pins 1..20 from left to right, the top row
// pins 40..21 (the datasheet's portrait layout turned a quarter to the
// left). Parts wired to the top row sit above the board, the bottom row's
// below it, each jumper wire plugs into the breadboard column of its pin,
// past the pin's label. Parts without pins (the robot's arena, the camera,
// Wi-Fi, the laptop) go to the right of the breadboard, or below it when
// the slot is narrower than 600 px. The e-paper's 250 x 122 pixels are drawn
// 1:1 from the panel's RAM.
//
// Accessibility, as game.js: the bench is a <figure role=group> with a
// caption naming the parts, the SVG is one image with a text alternative
// that follows the state, a polite live region says what changed (at most
// every 1.5 s), every input is a real control with a label, and nothing
// flashes under prefers-reduced-motion.
(function () {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";
  var MM = 5;
  var PICO_W = 51 * MM, PICO_H = 21 * MM;
  var PITCH = 2.54 * MM;
  var PIN0 = 1.37 * MM;          // the first pin's centre from the board's short edge
  var ROW_IN = 1.61 * MM;        // a pin row's centre from the long edge
  var LABEL = 32;                // a pin label's length (outside the board)
  var COL = 330;                 // a column of the bench
  var GAP = 24;
  var WIDE = 600;                // slot px from which the columns sit side by side
  var SAY_EVERY = 1500;
  var AROUND = 10;               // x of a wire that goes round the Pico's USB end
  var REDUCED = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // the Pico (2) W's 40 pins: [name, GP number or null, kind]
  var PINS = [null,
    ["GP0", 0], ["GP1", 1], ["GND"], ["GP2", 2], ["GP3", 3], ["GP4", 4], ["GP5", 5], ["GND"],
    ["GP6", 6], ["GP7", 7], ["GP8", 8], ["GP9", 9], ["GND"], ["GP10", 10], ["GP11", 11],
    ["GP12", 12], ["GP13", 13], ["GND"], ["GP14", 14], ["GP15", 15],
    ["GP16", 16], ["GP17", 17], ["GND"], ["GP18", 18], ["GP19", 19], ["GP20", 20], ["GP21", 21],
    ["GND"], ["GP22", 22], ["RUN"], ["GP26", 26], ["GP27", 27], ["AGND"], ["GP28", 28],
    ["ADC_VREF"], ["3V3"], ["3V3_EN"], ["GND"], ["VSYS"], ["VBUS"]];
  var GP_PIN = {};
  PINS.forEach(function (p, i) { if (p && p[1] !== undefined) GP_PIN[p[1]] = i; });

  // English, for a mount without the course's strings
  var UI = {
    boardStop: "■ Stop (reset the Pico)", boardReset: "The Pico was reset.",
    boardTitle: "Pico 2 W bench", boardParts: "On the bench", boardAlone: "only the Pico, with its onboard LED",
    boardEnded: "The program has ended.",
    boardRunning: "running", boardMotorsOn: "motors on", boardCanned: "canned",
    boardSound: "Sound", boardOn: "on", boardOff: "off", boardScripted: "set by the exercise",
    boardLed: "LED on GP15", boardOnboard: "Onboard LED", boardButton: "Button on GP14",
    boardPressed: "pressed", boardReleased: "released", boardLight: "Light",
    boardRoom: "Room temperature", boardTempC: "Temperature", boardHumidity: "Humidity",
    boardPressure: "Air pressure", boardBuzzer: "Buzzer", boardSilent: "silent",
    boardEnv: "Environment sensor", boardEpd: "E-paper 2.13\"",
    boardEpdRefreshed: "E-paper refreshed", boardEpdAlt: "E-paper, refreshed %1 times, %2 black pixels",
    boardRobot: "PicoGo robot", boardRobotStopped: "Robot stopped, %1 cm from the obstacle ahead",
    boardRobotHit: "The robot bumped into something", boardRobotMoving: "Robot driving",
    boardBox: "Box", boardBacon: "Bacon", boardBoxIn: "Box in the arena",
    boardLeft: "left", boardRight: "right", boardUp: "up", boardDown: "down",
    boardCamera: "Camera (simulated)", boardPicture: "Picture", boardCaptured: "The camera took a picture",
    boardWifi: "Wi-Fi", boardWifiOff: "Access point off", boardWifiUp: "Wi-Fi connected to chunkynet",
    boardLaptop: "Laptop (Bluetooth LE)", boardSend: "Send", boardLine: "Line to the Pico",
    boardBleOn: "Bluetooth connected", boardBleOff: "Bluetooth disconnected", boardBleGot: "The laptop got",
    boardBleLink: "Laptop connected", boardAdvertising: "advertising", boardChipTemp: "chip sensor"
  };

  var values = {};          // the page's inputs, sent with each run
  var bench = null;         // the mounted bench (build)
  var epd = { frames: 0, hex: "", url: "", black: 0 };   // the panel keeps its picture across runs
  var lineNo = 0;
  var audio = null;

  // ---------- small helpers ----------

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function sv(tag, attrs, parent) {
    var node = document.createElementNS(NS, tag);
    if (attrs) for (var k in attrs) if (attrs[k] !== undefined && attrs[k] !== null) node.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(node);
    return node;
  }

  function txt(parent, x, y, text, cls, attrs) {
    var node = sv("text", Object.assign({ x: x, y: y, "class": cls }, attrs || {}), parent);
    node.textContent = text;
    return node;
  }

  function title(node, text) {
    sv("title", null, node).textContent = text;
    return node;
  }

  function lang() { return (document.documentElement.lang || "en").slice(0, 2); }

  function num(n, digits) {
    try { return Number(n).toLocaleString(lang(), { maximumFractionDigits: digits || 0, minimumFractionDigits: digits || 0, useGrouping: false }); }
    catch (e) { return Number(n).toFixed(digits || 0); }
  }

  function t(key) { return (bench && bench.ui[key]) || UI[key] || key; }

  function fill(text, a, b) { return String(text).replace("%1", a).replace("%2", b === undefined ? "" : b); }

  // a polyline with round corners (the jumper wires)
  function roundPath(pts, r) {
    var d = "M" + pts[0][0] + " " + pts[0][1];
    for (var i = 1; i < pts.length; i++) {
      var p = pts[i];
      if (i === pts.length - 1) { d += " L" + p[0] + " " + p[1]; break; }
      var a = pts[i - 1], b = pts[i + 1];
      var l1 = Math.hypot(p[0] - a[0], p[1] - a[1]), l2 = Math.hypot(b[0] - p[0], b[1] - p[1]);
      var rr = Math.min(r, l1 / 2, l2 / 2);
      if (rr < 0.5) { d += " L" + p[0] + " " + p[1]; continue; }
      var p1 = [p[0] - (p[0] - a[0]) / l1 * rr, p[1] - (p[1] - a[1]) / l1 * rr];
      var p2 = [p[0] + (b[0] - p[0]) / l2 * rr, p[1] + (b[1] - p[1]) / l2 * rr];
      d += " L" + p1[0].toFixed(1) + " " + p1[1].toFixed(1) + " Q" + p[0] + " " + p[1] + " " + p2[0].toFixed(1) + " " + p2[1].toFixed(1);
    }
    return d;
  }

  // what a GPIO can be, for the pin's tooltip (RP2350 datasheet §9.4)
  function functions(gp) {
    var list = [];
    list.push("SPI" + ((gp >> 3) & 1) + " " + ["RX", "CSn", "SCK", "TX"][gp % 4]);
    list.push("UART" + (((gp + 4) >> 3) & 1) + " " + ["TX", "RX", "CTS", "RTS"][gp % 4]);
    list.push("I2C" + ((gp >> 1) & 1) + " " + (gp % 2 ? "SCL" : "SDA"));
    list.push("PWM" + ((gp >> 1) & 7) + " " + (gp % 2 ? "B" : "A"));
    if (gp >= 26) list.push("ADC" + (gp - 26));
    return list.join(" · ");
  }

  function pinKind(name) {
    if (/GND/.test(name)) return "gnd";
    if (/^(VBUS|VSYS|3V3|3V3_EN|ADC_VREF)$/.test(name)) return "pwr";
    if (name === "RUN") return "ctl";
    return "gp";
  }

  // a pin's centre on the Pico (its own coordinates)
  function pinXY(pin) {
    if (pin <= 20) return [PIN0 + (pin - 1) * PITCH, PICO_H - ROW_IN];
    return [PIN0 + (40 - pin) * PITCH, ROW_IN];
  }

  // ---------- the parts: size, leads (wires to pins), drawing ----------
  //
  // A part on the breadboard has leads: [x, pin, role] with x in its own
  // coordinates; its wires plug in at its bottom edge (top row parts) or top
  // edge (bottom row parts). role: "pwr", "gnd" or a signal colour.

  var WIRE = { pwr: "#d23a2c", gnd: "#23262b", vsys: "#e0702a", orange: "#ef8a1a", blue: "#2a6fdb",
               green: "#2e9e4f", purple: "#8e44ad", yellow: "#e8c51b", white: "#f2f2ee", gray: "#9aa0a8" };

  var PARTS = {
    // (the leads in the order of their pins on the Pico, so no two wires cross)
    light26: { row: "top", w: 72, h: 76, leads: [[10, 36, "pwr"], [36, 33, "gnd"], [62, 31, "green"]], draw: drawLight },
    buzzer16: { row: "top", w: 56, h: 76, leads: [[20, 23, "gnd"], [36, 21, "purple"]], draw: drawBuzzer },
    envsensor: { row: "top", w: 170, h: 84, leads: [[109, 36, "pwr"], [125, 28, "gnd"], [141, 27, "yellow"], [157, 26, "blue"]], draw: drawEnv },
    button14: { row: "bottom", w: 54, h: 60, leads: [[14, 18, "gnd"], [40, 19, "blue"]], draw: drawButton },
    led15: { row: "bottom", w: 74, h: 74, leads: [[12, 18, "gnd"], [62, 20, "orange"]], draw: drawLed },
    // Waveshare's 8-pin cable, in the connector's order
    epd213: { row: "epd", w: 300, h: 176,
              leads: [[30, 39, "vsys"], [50, 13, "gnd"], [70, 15, "blue"], [90, 14, "yellow"], [110, 12, "orange"],
                      [130, 11, "green"], [150, 16, "white"], [170, 17, "purple"]], draw: drawEpd }
  };
  var SIDE = {
    picogo: { h: 236, draw: drawArena },
    camera: { h: 168, draw: drawCamera },
    wifi: { h: 128, draw: drawWifi },
    laptop: { h: 196, draw: drawLaptop }
  };

  // ---------- building a bench ----------

  function build(config, ui, width) {
    var parts = (config.parts || []).map(String);
    var w = width >= WIDE;
    var b = { config: config, parts: parts, ui: ui || {}, board: String(config.board || "pico2w"),
              wide: w, refs: {}, controls: {}, state: null, log: [], http: [], ble: [], said: "",
              lastSay: 0, sayTimer: null, status: "", spoken: {} };
    bench = b;   // t() reads the strings from here while it builds
    var wireless = b.board !== "pico" && b.board !== "pico2";

    var figure = el("figure", "pico-bench");
    figure.setAttribute("role", "group");
    figure.setAttribute("aria-label", t("boardTitle"));
    b.el = figure;

    var bar = el("div", "pico-bar");
    var stop = el("button", "pico-stop", t("boardStop"));
    stop.type = "button";
    stop.addEventListener("click", function () {
      if (window.chunkyPicoRuby && window.chunkyPicoRuby.stop) window.chunkyPicoRuby.stop();
    });
    bar.appendChild(stop);
    if (parts.indexOf("buzzer16") >= 0 || parts.indexOf("picogo") >= 0) {
      var sound = el("button", "pico-sound", "🔇 " + t("boardSound"));
      sound.type = "button";
      sound.setAttribute("aria-pressed", "false");
      sound.addEventListener("click", function () {
        var on = sound.getAttribute("aria-pressed") !== "true";
        sound.setAttribute("aria-pressed", on ? "true" : "false");
        sound.textContent = (on ? "🔊 " : "🔇 ") + t("boardSound");
        b.sound = on;
        tone();
      });
      bar.appendChild(sound);
    }
    var badge = el("span", "pico-badge");
    b.badge = badge;
    bar.appendChild(badge);
    figure.appendChild(bar);

    // the drawing
    var svg = sv("svg", { "class": "pico-svg", role: "img", focusable: "false" });
    var descId = "pico-desc-" + Math.random().toString(36).slice(2, 8);
    var desc = sv("desc", { id: descId }, svg);
    svg.setAttribute("aria-labelledby", descId);
    b.desc = desc;
    b.svg = svg;
    defs(svg);

    var top = parts.filter(function (p) { return PARTS[p] && PARTS[p].row === "top"; });
    var bottom = parts.filter(function (p) { return PARTS[p] && PARTS[p].row === "bottom"; });
    var hasEpd = parts.indexOf("epd213") >= 0;
    var side = parts.filter(function (p) { return SIDE[p]; });

    // column A: the breadboard
    var y = 10;
    var topH = top.reduce(function (m, p) { return Math.max(m, PARTS[p].h); }, 0);
    var placed = [];
    var colA = sv("g", { "class": "pb-col" }, svg);
    var boardBg = sv("rect", { "class": "pb-breadboard", x: 0, y: 0, width: COL, rx: 8 }, colA);
    var holes = sv("rect", { "class": "pb-holes", x: 6, y: 6, width: COL - 12, fill: "url(#pb-holes)" }, colA);
    // the Pico and its labels, the wires, the parts over the wires' ends
    var picoLayer = sv("g", null, colA);
    var wireLayer = sv("g", { "class": "pb-wires" }, colA);
    var partLayer = sv("g", null, colA);

    var px = Math.round((COL - PICO_W) / 2);
    var topLanes = 0, bottomLanes = 0;
    if (top.length) {
      y += topH;
      placed = placed.concat(place(top, px, y, "top"));
      topLanes = lanes(placed.filter(function (p) { return p.row === "top"; }), px);
      y += 10 + topLanes * 6;
    }
    var py = y + LABEL + 6;
    var pico = drawPico(picoLayer, px, py, wireless, b);
    y = py + PICO_H + LABEL + 6;
    if (bottom.length || hasEpd) {
      var row = place(bottom, px, 0, "bottom");
      var rowLanes = lanes(row, px);
      if (row.length) {
        y += 10 + rowLanes * 6;
        var bh = 0;
        row.forEach(function (p) { p.y = y; bh = Math.max(bh, p.spec.h); });
        y += bh;
      }
      if (hasEpd) {
        var ep = { id: "epd213", spec: PARTS.epd213, x: Math.round((COL - PARTS.epd213.w) / 2), row: "bottom" };
        y += 10 + lanes([ep], px) * 6 + (row.length ? 8 : 0);
        ep.y = y;
        y += ep.spec.h;
        row.push(ep);
      }
      placed = placed.concat(row);
    }
    var heightA = y + 10;
    boardBg.setAttribute("height", heightA);
    holes.setAttribute("height", heightA - 12);

    placed.forEach(function (p) {
      var g = sv("g", { "class": "pb-part pb-" + p.id, transform: "translate(" + p.x + " " + p.y + ")" }, partLayer);
      if (p.row === "top") g.setAttribute("transform", "translate(" + p.x + " " + (p.y - p.spec.h) + ")");
      b.refs[p.id] = p.spec.draw(g, p.spec, b) || {};
      wires(wireLayer, p, px, py, b);
    });

    // column B: the parts without pins; the arena of a wide bench goes
    // under both columns
    arenaLayout(w);
    var heightB = 0;
    var bx = w ? COL + GAP : 0;
    var by = w ? 0 : heightA + GAP;
    var cards = side.filter(function (id) { return !(w && id === "picogo"); });
    cards.forEach(function (id) {
      var g = sv("g", { "class": "pb-side pb-" + id, transform: "translate(" + bx + " " + (by + heightB) + ")" }, svg);
      b.refs[id] = SIDE[id].draw(g, b) || {};
      b.refs[id].g = g;
      heightB += SIDE[id].h + 14;
    });
    if (heightB) heightB -= 14;
    var under = 0;
    if (w && side.indexOf("picogo") >= 0) {
      var top0 = Math.max(heightA, heightB) + 14;
      var ga = sv("g", { "class": "pb-side pb-picogo", transform: "translate(0 " + top0 + ")" }, svg);
      b.refs.picogo = drawArena(ga, b);
      b.refs.picogo.g = ga;
      under = 14 + SIDE.picogo.h;
      // nothing beside the breadboard: it goes over the arena's middle
      if (!cards.length) colA.setAttribute("transform", "translate(" + Math.round((COL + GAP) / 2) + " 0)");
    }
    // the radio's link: a dashed line from the Pico's antenna to the cards
    if (wireless && side.some(function (id) { return id === "wifi" || id === "laptop"; })) {
      var target = side.indexOf("wifi") >= 0 ? "wifi" : "laptop";
      var off = 0;
      for (var i = 0; i < cards.indexOf(target); i++) off += SIDE[cards[i]].h + 14;
      var ax = px + PICO_W - 8, ay = py + PICO_H / 2;
      var tx = bx + 34, ty = by + off + 52;
      var d = w ? "M" + ax + " " + ay + " C" + (ax + 50) + " " + ay + " " + (tx - 70) + " " + ty + " " + (tx - 18) + " " + ty
                : "M" + ax + " " + ay + " C" + (ax + 30) + " " + (ay + 80) + " " + tx + " " + (ty - 90) + " " + tx + " " + (ty - 30);
      b.refs.link = sv("path", { "class": "pb-radio", d: d }, svg);
    }

    var totalW = w && side.length ? COL + GAP + COL : COL;
    var totalH = w ? Math.max(heightA, heightB) + under : heightA + (side.length ? GAP + heightB : 0);
    svg.setAttribute("viewBox", "0 0 " + totalW + " " + totalH);
    svg.style.maxWidth = Math.round(totalW * 1.35) + "px";
    b.pico = pico;
    figure.appendChild(svg);

    var caption = el("figcaption", "pico-parts");
    var names = partNames(b);
    caption.textContent = t("boardParts") + ": " + (names.length ? names.join(", ") : t("boardAlone"));
    figure.appendChild(caption);

    var controls = el("div", "pico-controls");
    buildControls(controls, b);
    figure.appendChild(controls);

    var say = el("p", "pico-say");
    say.setAttribute("role", "status");
    say.setAttribute("aria-live", "polite");
    b.say = say;
    figure.appendChild(say);

    if (epd.url && b.refs.epd213) b.refs.epd213.image.setAttribute("href", epd.url);
    describe(b);
    return b;
  }

  function partNames(b) {
    var names = { led15: t("boardLed"), button14: t("boardButton"), light26: t("boardLight") + " (GP26)",
                  temp: t("boardRoom"), buzzer16: t("boardBuzzer") + " (GP16)", envsensor: t("boardEnv"),
                  epd213: t("boardEpd"), picogo: t("boardRobot"), camera: t("boardCamera"),
                  wifi: t("boardWifi"), laptop: t("boardLaptop") };
    return b.parts.map(function (p) { return names[p] || p; });
  }

  // parts of one row over (or under) their pins, left to right, no overlaps
  function place(ids, px, y, row) {
    var list = ids.map(function (id) {
      var spec = PARTS[id];
      // over its signal pins (the ground and power wires can go further)
      var signal = spec.leads.filter(function (l) { return l[2] !== "gnd" && l[2] !== "pwr"; });
      var use = signal.length ? signal : spec.leads;
      var mean = function (f) { return use.reduce(function (a, l) { return a + f(l); }, 0) / use.length; };
      return { id: id, spec: spec, want: mean(function (l) { return px + pinXY(l[1])[0] - l[0]; }),
               pin: mean(function (l) { return pinXY(l[1])[0]; }), x: 0, y: y, row: row };
    }).sort(function (a, c) { return a.pin - c.pin; });
    var x = 6;
    list.forEach(function (p) {
      p.x = Math.round(Math.max(x, Math.min(p.want, COL - 6 - p.spec.w)));
      x = p.x + p.spec.w + 8;
    });
    // pushed past the right edge: pack from the right instead
    var right = COL - 6;
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].x + list[i].spec.w > right) list[i].x = right - list[i].spec.w;
      right = list[i].x - 8;
    }
    return list;
  }

  // a lane (a horizontal run) for every wire that has to move sideways.
  // Lane 0 is the one nearest the part, higher ones nearer the Pico. Of two
  // wires that both run left, the one from the pin further left goes nearer
  // the Pico (and mirrored for wires that run right), so wires that keep
  // their order never cross; a wire takes the lane just past every wire
  // whose run overlaps its own, and runs that do not overlap share a lane.
  function lanes(parts, px) {
    var runs = [];
    parts.forEach(function (p) {
      p.lanes = [];
      p.spec.leads.forEach(function (l, i) {
        var a = px + pinXY(l[1])[0], c = p.x + l[0];
        p.lanes[i] = -1;
        // a top-row pin for a part below runs round the USB end (wires)
        if (l[1] > 20 && p.row === "bottom") a = AROUND;
        if (Math.abs(a - c) < 1) return;
        runs.push({ p: p, i: i, a: a, lo: Math.min(a, c) - 4, hi: Math.max(a, c) + 4, left: c < a });
      });
    });
    var order = runs.filter(function (r) { return r.left; }).sort(function (x, y) { return y.a - x.a; })
      .concat(runs.filter(function (r) { return !r.left; }).sort(function (x, y) { return x.a - y.a; }));
    var count = 0;
    order.forEach(function (r, n) {
      var k = 0;
      for (var j = 0; j < n; j++) {
        var u = order[j];
        if (u.lo < r.hi && r.lo < u.hi) k = Math.max(k, u.k + 1);
      }
      r.k = k;
      r.p.lanes[r.i] = k;
      count = Math.max(count, k + 1);
    });
    return count;
  }

  function wires(layer, p, px, py, b) {
    var top = p.row === "top";
    var partY = top ? p.y : p.y;
    p.spec.leads.forEach(function (l, i) {
      var pin = l[1];
      var xy = pinXY(pin);
      var x0 = px + xy[0];
      var end = pin <= 20 ? py + PICO_H + LABEL + 4 : py - LABEL - 4;   // the column's hole past the label
      var x1 = p.x + l[0];
      var pts;
      var k = p.lanes ? p.lanes[i] : -1;
      if (pin > 20 && !top) {
        // a top-row pin for a part below (the e-paper's VSYS): round the USB end
        var ly = py - LABEL - 10;
        var lane = partY - 8 - (k < 0 ? 0 : k * 6);
        pts = [[x0, end], [x0, ly], [AROUND, ly], [AROUND, lane], [x1, lane], [x1, partY]];
      } else if (top) {
        var laneY = partY + 8 + (k < 0 ? 0 : k * 6);
        pts = k < 0 ? [[x0, end], [x1, partY]] : [[x0, end], [x0, laneY], [x1, laneY], [x1, partY]];
      } else {
        var laneB = partY - 8 - (k < 0 ? 0 : k * 6);
        pts = k < 0 ? [[x0, end], [x1, partY]] : [[x0, end], [x0, laneB], [x1, laneB], [x1, partY]];
      }
      var d = roundPath(pts, 4);
      var colour = WIRE[l[2]] || l[2];
      var g = sv("g", { "class": "pb-wire" }, layer);
      title(g, PINS[pin][0] + " (pin " + pin + ")");
      sv("path", { d: d, "class": "pb-wire-edge" }, g);
      sv("path", { d: d, "class": "pb-wire-core", stroke: colour }, g);
      sv("path", { d: d, "class": "pb-wire-shine" }, g);
      [pts[0], pts[pts.length - 1]].forEach(function (q, j) {
        var vertical = j === 0 ? true : Math.abs(pts[pts.length - 2][0] - q[0]) < 0.5;
        sv("rect", vertical ? { x: q[0] - 2.4, y: q[1] - 3.5, width: 4.8, height: 7, rx: 1, "class": "pb-wire-tip" }
                           : { x: q[0] - 3.5, y: q[1] - 2.4, width: 7, height: 4.8, rx: 1, "class": "pb-wire-tip" }, g);
      });
    });
  }

  function defs(svg) {
    var d = sv("defs", null, svg);
    var hp = sv("pattern", { id: "pb-holes", width: PITCH, height: PITCH, patternUnits: "userSpaceOnUse" }, d);
    sv("rect", { x: PITCH / 2 - 1.6, y: PITCH / 2 - 1.6, width: 3.2, height: 3.2, rx: 0.6, "class": "pb-hole" }, hp);
    var glow = sv("radialGradient", { id: "pb-glow-red" }, d);
    sv("stop", { offset: "0", "stop-color": "#ff5a3c", "stop-opacity": "0.95" }, glow);
    sv("stop", { offset: "0.45", "stop-color": "#ff3b1f", "stop-opacity": "0.45" }, glow);
    sv("stop", { offset: "1", "stop-color": "#ff3b1f", "stop-opacity": "0" }, glow);
    var green = sv("radialGradient", { id: "pb-glow-green" }, d);
    sv("stop", { offset: "0", "stop-color": "#b6ff8a", "stop-opacity": "1" }, green);
    sv("stop", { offset: "0.4", "stop-color": "#5ee05a", "stop-opacity": "0.55" }, green);
    sv("stop", { offset: "1", "stop-color": "#5ee05a", "stop-opacity": "0" }, green);
    var metal = sv("linearGradient", { id: "pb-metal", x1: "0", y1: "0", x2: "1", y2: "1" }, d);
    sv("stop", { offset: "0", "stop-color": "#eef0f2" }, metal);
    sv("stop", { offset: "0.55", "stop-color": "#b9bfc6" }, metal);
    sv("stop", { offset: "1", "stop-color": "#8f969e" }, metal);
    var pcb = sv("linearGradient", { id: "pb-pcb", x1: "0", y1: "0", x2: "0", y2: "1" }, d);
    sv("stop", { offset: "0", "stop-color": "#23824b" }, pcb);
    sv("stop", { offset: "1", "stop-color": "#196b3b" }, pcb);
    var chip = sv("linearGradient", { id: "pb-chip", x1: "0", y1: "0", x2: "1", y2: "1" }, d);
    sv("stop", { offset: "0", "stop-color": "#3a3d42" }, chip);
    sv("stop", { offset: "1", "stop-color": "#1b1d20" }, chip);
    var lens = sv("radialGradient", { id: "pb-lens", cx: "0.35", cy: "0.35" }, d);
    sv("stop", { offset: "0", "stop-color": "#6d7fa8" }, lens);
    sv("stop", { offset: "0.35", "stop-color": "#1d2333" }, lens);
    sv("stop", { offset: "1", "stop-color": "#07090d" }, lens);
  }

  // ---------- the Pico 2 W ----------

  function drawPico(layer, px, py, wireless, b) {
    var g = sv("g", { "class": "pb-pico", transform: "translate(" + px + " " + py + ")" }, layer);
    var refs = { pins: {}, labels: {} };
    // the labels outside the board, read from below
    for (var pin = 1; pin <= 40; pin++) {
      var p = PINS[pin], xy = pinXY(pin), kind = pinKind(p[0]);
      var bottom = pin <= 20;
      var ly = bottom ? PICO_H + 3 : -3 - LABEL + 4;
      var lg = sv("g", { "class": "pb-label pb-label-" + kind }, g);
      sv("rect", { x: xy[0] - 5, y: ly, width: 10, height: LABEL - 4, rx: 2 }, lg);
      var tx = xy[0] + 2.6, ty = bottom ? ly + 2.5 : ly + LABEL - 6.5;
      var label = txt(lg, tx, ty, p[0], "pb-label-text" + (p[0].length > 6 ? " pb-label-long" : ""), { transform: "rotate(-90 " + tx + " " + ty + ")",
        "text-anchor": bottom ? "end" : "start" });
      if (p[1] >= 26) {
        var sp = sv("tspan", { "class": "pb-label-adc" }, label);
        sp.textContent = " A" + (p[1] - 26);
        if (bottom) label.setAttribute("text-anchor", "end");
      }
      title(lg, "pin " + pin + ": " + p[0] + (p[1] !== undefined ? " · " + functions(p[1]) : ""));
      refs.labels[pin] = lg;
    }
    // the board
    sv("rect", { x: 0, y: 0, width: PICO_W, height: PICO_H, rx: 4, "class": "pb-pcb" }, g);
    sv("rect", { x: 1.5, y: 1.5, width: PICO_W - 3, height: PICO_H - 3, rx: 3, "class": "pb-pcb-edge" }, g);
    // the castellated pads and their through holes
    for (pin = 1; pin <= 40; pin++) {
      xy = pinXY(pin);
      var edge = pin <= 20 ? PICO_H : 0;
      var pg = sv("g", { "class": "pb-pin" }, g);
      sv("rect", { x: xy[0] - 3.4, y: pin <= 20 ? PICO_H - 10.5 : 0, width: 6.8, height: 10.5, rx: 1.5, "class": "pb-pad" }, pg);
      sv("circle", { cx: xy[0], cy: edge, r: 2.2, "class": "pb-castle" }, pg);
      sv("circle", { cx: xy[0], cy: xy[1], r: 3.3, "class": "pb-ring" }, pg);
      sv("circle", { cx: xy[0], cy: xy[1], r: 1.6, "class": "pb-drill" }, pg);
      refs.pins[pin] = sv("circle", { cx: xy[0], cy: xy[1], r: 4.6, "class": "pb-pinstate" }, g);
      title(pg, "pin " + pin + ": " + PINS[pin][0]);
    }
    // pin 1's square pad, the corner numbers
    sv("rect", { x: pinXY(1)[0] - 3.3, y: pinXY(1)[1] - 3.3, width: 6.6, height: 6.6, "class": "pb-ring" }, g);
    sv("circle", { cx: pinXY(1)[0], cy: pinXY(1)[1], r: 1.6, "class": "pb-drill" }, g);
    [[1, "1"], [2, "2"], [39, "39"], [40, "40"], [20, "20"], [21, "21"]].forEach(function (n) {
      var q = pinXY(n[0]);
      txt(g, q[0], n[0] <= 20 ? q[1] - 6.5 : q[1] + 9.5, n[1], "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    });
    // mounting holes
    [[2, 4.8], [2, 16.2], [49, 4.8], [49, 16.2]].forEach(function (m) {
      sv("circle", { cx: m[0] * MM, cy: m[1] * MM, r: 5.2, "class": "pb-mount" }, g);
      sv("circle", { cx: m[0] * MM, cy: m[1] * MM, r: 3.3, "class": "pb-mount-hole" }, g);
    });
    // micro USB, over the left edge
    var usb = sv("g", { "class": "pb-usb" }, g);
    title(usb, "micro USB");
    sv("rect", { x: -6, y: PICO_H / 2 - 19, width: 29, height: 38, rx: 2.5, fill: "url(#pb-metal)", stroke: "#6d747c", "stroke-width": 0.8 }, usb);
    sv("rect", { x: -6, y: PICO_H / 2 - 13, width: 5, height: 26, rx: 1, fill: "#2a2d31" }, usb);
    sv("line", { x1: 6, y1: PICO_H / 2 - 16, x2: 20, y2: PICO_H / 2 - 16, stroke: "#8a9199", "stroke-width": 0.8 }, usb);
    sv("line", { x1: 6, y1: PICO_H / 2 + 16, x2: 20, y2: PICO_H / 2 + 16, stroke: "#8a9199", "stroke-width": 0.8 }, usb);
    // the onboard LED next to the USB socket
    var ledX = 31, ledY = PICO_H - 26;
    refs.ledGlow = sv("circle", { cx: ledX + 3, cy: ledY + 2, r: 13, fill: "url(#pb-glow-green)", "class": "pb-onboard-glow" }, g);
    sv("rect", { x: ledX, y: ledY, width: 6, height: 4, rx: 0.8, "class": "pb-onboard" }, g);
    txt(g, ledX + 3, ledY + 11, "LED", "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    // BOOTSEL
    var boot = sv("g", { "class": "pb-bootsel" }, g);
    title(boot, "BOOTSEL");
    sv("rect", { x: 32, y: 15, width: 22, height: 17, rx: 1.5, fill: "#cfd3d6", stroke: "#7e858c", "stroke-width": 0.6 }, boot);
    sv("circle", { cx: 43, cy: 23.5, r: 5.6, fill: "#f7f7f2", stroke: "#a9aeb3", "stroke-width": 0.8 }, boot);
    txt(g, 43, 41, "BOOTSEL", "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    // flash, crystal, the regulator's inductor and a few small parts
    sv("rect", { x: 60, y: 54, width: 22, height: 17, rx: 1, fill: "url(#pb-chip)" }, g);
    for (var k = 0; k < 4; k++) {
      sv("rect", { x: 62 + k * 5, y: 51, width: 2.4, height: 3, fill: "#c9ccd0" }, g);
      sv("rect", { x: 62 + k * 5, y: 71, width: 2.4, height: 3, fill: "#c9ccd0" }, g);
    }
    sv("rect", { x: 64, y: 30, width: 15, height: 9, rx: 1.5, fill: "url(#pb-metal)", stroke: "#7e858c", "stroke-width": 0.5 }, g);
    sv("rect", { x: 86, y: 74, width: 13, height: 13, rx: 2, fill: "#3c3f44" }, g);
    [[103, 28], [103, 36], [110, 76], [117, 76], [94, 22], [57, 80], [52, 46]].forEach(function (c) {
      sv("rect", { x: c[0], y: c[1], width: 5, height: 2.6, fill: "#c7a26b", stroke: "#8c7448", "stroke-width": 0.4 }, g);
    });
    // the RP2350 (7 x 7 mm QFN-60)
    var cx0 = 22.5 * MM, cy0 = PICO_H / 2;
    var chip = sv("g", { "class": "pb-chip" }, g);
    title(chip, "RP2350 · Arm Cortex-M33 / Hazard3 RISC-V");
    for (k = 0; k < 13; k++) {
      var o = -15 + k * 2.5;
      sv("rect", { x: cx0 + o - 0.6, y: cy0 - 19, width: 1.2, height: 2.5, fill: "#c9ccd0" }, chip);
      sv("rect", { x: cx0 + o - 0.6, y: cy0 + 16.5, width: 1.2, height: 2.5, fill: "#c9ccd0" }, chip);
      sv("rect", { x: cx0 - 19, y: cy0 + o - 0.6, width: 2.5, height: 1.2, fill: "#c9ccd0" }, chip);
      sv("rect", { x: cx0 + 16.5, y: cy0 + o - 0.6, width: 2.5, height: 1.2, fill: "#c9ccd0" }, chip);
    }
    sv("rect", { x: cx0 - 17.5, y: cy0 - 17.5, width: 35, height: 35, rx: 1.5, fill: "url(#pb-chip)" }, chip);
    sv("circle", { cx: cx0 - 13, cy: cy0 - 13, r: 1.4, fill: "#55595f" }, chip);
    txt(chip, cx0, cy0 - 1, "RP2350", "pb-chip-text", { "text-anchor": "middle" });
    txt(chip, cx0, cy0 + 7, "A2", "pb-chip-text pb-chip-small", { "text-anchor": "middle" });
    refs.chipTemp = txt(g, cx0, cy0 + 28, "", "pb-silk pb-chip-temp", { "text-anchor": "middle" });
    // the name, on the silkscreen
    txt(g, 136, 25, wireless ? "Raspberry Pi Pico 2 W" : (b.board === "pico" ? "Raspberry Pi Pico" : "Raspberry Pi Pico 2"),
        "pb-silk pb-silk-name");
    txt(g, 136, 33, "© 2024", "pb-silk pb-silk-tiny");
    if (wireless) {
      // the CYW43439 under its shield can, and the PCB antenna at the end
      var can = sv("g", { "class": "pb-can" }, g);
      title(can, "Infineon CYW43439 · Wi-Fi 4 + Bluetooth 5.2");
      sv("rect", { x: 168, y: 40, width: 52, height: 50, rx: 2.5, fill: "url(#pb-metal)", stroke: "#7c838b", "stroke-width": 0.8 }, can);
      sv("rect", { x: 172, y: 44, width: 44, height: 42, rx: 1.5, fill: "none", stroke: "#d5d9dd", "stroke-width": 0.7 }, can);
      txt(can, 194, 67, "CYW43439", "pb-can-text", { "text-anchor": "middle" });
      sv("rect", { x: 226, y: 14, width: 25, height: 77, rx: 2, "class": "pb-antenna-zone" }, g);
      sv("path", { d: "M232 84 V22 H238 V78 H244 V22", "class": "pb-antenna" }, g);
      var debug = sv("g", null, g);
      title(debug, "DEBUG (SWD)");
      [0, 1, 2].forEach(function (i) {
        sv("rect", { x: 150 + i * 6, y: 74, width: 4, height: 8, rx: 0.8, "class": "pb-pad" }, debug);
      });
      txt(g, 156, 89, "DEBUG", "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    } else {
      sv("rect", { x: 220, y: 36, width: 30, height: 34, rx: 2, "class": "pb-antenna-zone" }, g);
      [0, 1, 2].forEach(function (i) {
        sv("rect", { x: 232, y: 40 + i * 10, width: 8, height: 4, rx: 0.8, "class": "pb-pad" }, g);
      });
      txt(g, 236, 80, "DEBUG", "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    }
    refs.ledLabel = wireless ? "WL_GPIO0" : "GP25";
    return refs;
  }

  // ---------- the parts on the breadboard ----------

  function leg(g, x1, y1, x2, y2) {
    sv("line", { x1: x1, y1: y1, x2: x2, y2: y2, "class": "pb-leg" }, g);
  }

  function resistor(g, x, y, len, vertical, bands, name) {
    var r = sv("g", { "class": "pb-resistor" }, g);
    title(r, name);
    var w = vertical ? 8 : len, h = vertical ? len : 8;
    sv("rect", { x: x - (vertical ? 4 : 0), y: y - (vertical ? 0 : 4), width: w, height: h, rx: 3.5, "class": "pb-resistor-body" }, r);
    bands.forEach(function (c, i) {
      var at = 4 + i * (len - 10) / (bands.length - 1) - (i === bands.length - 1 ? -1 : 0);
      if (vertical) sv("rect", { x: x - 4, y: y + at, width: 8, height: 2.2, fill: c }, r);
      else sv("rect", { x: x + at, y: y - 4, width: 2.2, height: 8, fill: c }, r);
    });
    return r;
  }

  // GND <- red LED <- 330 ohm <- GP15 (the resistor on the right)
  function drawLed(g, spec) {
    var refs = {};
    leg(g, 62, 0, 62, 10);
    resistor(g, 62, 10, 28, true, ["#e8761c", "#e8761c", "#7b4a1e", "#c9a23c"], "330 Ω");
    leg(g, 62, 38, 62, 52);
    leg(g, 62, 52, 46, 52);
    leg(g, 30, 52, 12, 52);
    leg(g, 12, 52, 12, 0);
    refs.glow = sv("circle", { cx: 38, cy: 50, r: 30, fill: "url(#pb-glow-red)", "class": "pb-led-glow" }, g);
    var led = sv("g", { "class": "pb-led-body" }, g);
    title(led, "LED (GP15)");
    // the rim's flat side marks the cathode (towards GND)
    sv("path", { d: "M30 43.5 A11 11 0 1 1 30 58.5 Z", "class": "pb-led-rim" }, led);
    refs.dome = sv("circle", { cx: 38, cy: 51, r: 8.4, "class": "pb-led-dome" }, led);
    sv("ellipse", { cx: 35, cy: 47.5, rx: 2.6, ry: 1.6, "class": "pb-shine" }, led);
    txt(g, 62, 70, "330 Ω", "pb-small", { "text-anchor": "middle" });
    txt(g, 38, 70, "LED", "pb-small", { "text-anchor": "middle" });
    return refs;
  }

  // a 12 mm tactile button between GP14 and GND
  function drawButton(g) {
    var refs = {};
    leg(g, 14, 0, 14, 16);
    leg(g, 40, 0, 40, 16);
    var bt = sv("g", { "class": "pb-button" }, g);
    title(bt, "button GP14 ↔ GND");
    [[7, 16], [41, 16], [7, 44], [41, 44]].forEach(function (c) {
      sv("rect", { x: c[0], y: c[1] - 1.5, width: 6, height: 3, "class": "pb-button-leg" }, bt);
    });
    sv("rect", { x: 11, y: 14, width: 32, height: 32, rx: 2, "class": "pb-button-body" }, bt);
    sv("circle", { cx: 15, cy: 18, r: 1.4, "class": "pb-button-dot" }, bt);
    sv("circle", { cx: 39, cy: 18, r: 1.4, "class": "pb-button-dot" }, bt);
    sv("circle", { cx: 15, cy: 42, r: 1.4, "class": "pb-button-dot" }, bt);
    sv("circle", { cx: 39, cy: 42, r: 1.4, "class": "pb-button-dot" }, bt);
    refs.cap = sv("circle", { cx: 27, cy: 30, r: 10, "class": "pb-button-cap" }, bt);
    // the bench script's finger
    refs.finger = sv("g", { "class": "pb-finger", visibility: "hidden" }, g);
    sv("path", { d: "M22 2 h10 a3 3 0 0 1 3 3 v18 a5 5 0 0 1 -5 5 h-6 a5 5 0 0 1 -5 -5 v-18 a3 3 0 0 1 3 -3 z", transform: "translate(0 10)" }, refs.finger);
    sv("circle", { cx: 27, cy: 34, r: 3, "class": "pb-finger-led" }, refs.finger);
    txt(g, 27, 58, "GP14", "pb-small", { "text-anchor": "middle" });
    return refs;
  }

  // 3V3 -> LDR -> GP26 (ADC0) -> 10 kohm -> AGND, a lamp above it
  function drawLight(g) {
    var refs = {};
    refs.lamp = sv("g", { "class": "pb-lamp" }, g);
    refs.rays = sv("g", { "class": "pb-rays" }, refs.lamp);
    for (var i = 0; i < 8; i++) {
      var a = i * Math.PI / 4;
      sv("line", { x1: 36 + Math.cos(a) * 9, y1: 13 + Math.sin(a) * 9, x2: 36 + Math.cos(a) * 13, y2: 13 + Math.sin(a) * 13 }, refs.rays);
    }
    refs.sun = sv("circle", { cx: 36, cy: 13, r: 6.5, "class": "pb-sun" }, refs.lamp);
    // the LDR from 3V3 to the node on GP26, the 10 kohm from the node to AGND
    leg(g, 10, 76, 10, 40);
    leg(g, 10, 40, 23, 40);
    leg(g, 49, 40, 62, 40);
    leg(g, 62, 40, 62, 76);
    var ldr = sv("g", null, g);
    title(ldr, "LDR (photoresistor)");
    sv("ellipse", { cx: 36, cy: 40, rx: 13, ry: 10, "class": "pb-ldr" }, ldr);
    sv("path", { d: "M27 36 h18 v3 h-18 v3 h18 v3 h-18", "class": "pb-ldr-track" }, ldr);
    leg(g, 36, 76, 36, 62);
    leg(g, 62, 62, 60, 62);
    resistor(g, 36, 62, 24, false, ["#7b4a1e", "#1e1e1e", "#e8761c", "#c9a23c"], "10 kΩ");
    txt(g, 33, 65, "10 kΩ", "pb-small", { "text-anchor": "end" });
    refs.value = txt(g, 52, 16, "", "pb-small pb-value");
    return refs;
  }

  // a passive piezo on GP16
  function drawBuzzer(g) {
    var refs = {};
    leg(g, 20, 76, 20, 50);
    leg(g, 36, 76, 36, 50);
    refs.waves = sv("g", { "class": "pb-waves" }, g);
    [10, 16, 22].forEach(function (r) {
      sv("path", { d: "M" + (28 + r) + " " + (34 - r * 0.8) + " a" + r + " " + r + " 0 0 1 0 " + (r * 1.6) }, refs.waves);
    });
    var bz = sv("g", null, g);
    title(bz, "passive buzzer (piezo)");
    sv("circle", { cx: 28, cy: 34, r: 18, "class": "pb-buzzer" }, bz);
    sv("circle", { cx: 28, cy: 34, r: 14, "class": "pb-buzzer-ring" }, bz);
    sv("circle", { cx: 28, cy: 34, r: 2.6, "class": "pb-buzzer-hole" }, bz);
    txt(g, 36, 25, "+", "pb-small pb-on-dark");
    refs.hz = txt(g, 28, 10, "", "pb-small pb-value", { "text-anchor": "middle" });
    return refs;
  }

  // the Waveshare Pico-Environment-Sensor (I2C0: SDA GP20, SCL GP21)
  function drawEnv(g, spec) {
    var refs = {};
    var board = sv("g", null, g);
    title(board, "Waveshare Pico-Environment-Sensor · I2C0 (SDA GP20, SCL GP21)");
    sv("rect", { x: 0, y: 0, width: 170, height: 66, rx: 4, "class": "pb-env" }, board);
    sv("rect", { x: 3, y: 3, width: 164, height: 60, rx: 3, "class": "pb-env-edge" }, board);
    var chips = [["BME280", "0x76", 10, 10, 15, 15, true], ["TSL25911", "0x29", 40, 10, 14, 12], ["ICM20948", "0x68", 70, 10, 14, 14],
                 ["LTR390", "0x53", 40, 36, 12, 10], ["SGP40", "0x59", 70, 38, 12, 12]];
    chips.forEach(function (c) {
      var cg = sv("g", null, board);
      title(cg, c[0] + " · " + c[1]);
      sv("rect", { x: c[2], y: c[3], width: c[4], height: c[5], rx: 1, fill: c[6] ? "url(#pb-metal)" : "url(#pb-chip)" }, cg);
      if (c[6]) sv("circle", { cx: c[2] + 4, cy: c[3] + 4, r: 1.2, fill: "#3a3d42" }, cg);
      txt(cg, c[2] + c[4] / 2, c[3] + c[5] + 7, c[1], "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    });
    // the readings, as the sliders set them
    refs.t = txt(board, 98, 18, "", "pb-env-text");
    refs.rh = txt(board, 98, 31, "", "pb-env-text");
    refs.p = txt(board, 98, 44, "", "pb-env-text");
    txt(board, 98, 57, "Environment Sensor", "pb-silk pb-silk-tiny");
    // the header the wires plug into
    ["VCC", "GND", "SCL", "SDA"].forEach(function (n, i) {
      var x = spec.leads[i][0];
      sv("rect", { x: x - 3.5, y: 68, width: 7, height: 9, rx: 1, "class": "pb-header" }, g);
      txt(g, x, 64, n, "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
      leg(g, x, 77, x, 84);
    });
    return refs;
  }

  // the Waveshare Pico-ePaper-2.13 (V4): 250 x 122, SPI1
  function drawEpd(g, spec, b) {
    var refs = {};
    var board = sv("g", null, g);
    title(board, "Waveshare Pico-ePaper-2.13 · SSD1680 · SPI1 (CLK GP10, DIN GP11, CS GP9, DC GP8, RST GP12, BUSY GP13)");
    sv("rect", { x: 0, y: 0, width: 300, height: 176, rx: 5, "class": "pb-epd-pcb" }, board);
    ["VCC", "GND", "DIN", "CLK", "CS", "DC", "RST", "BUSY"].forEach(function (n, i) {
      var x = spec.leads[i][0];
      sv("rect", { x: x - 4, y: 4, width: 8, height: 10, rx: 1, "class": "pb-header" }, g);
      txt(g, x, 22, n, "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    });
    refs.busy = sv("circle", { cx: 200, cy: 10, r: 3.2, "class": "pb-busy" }, g);
    txt(g, 207, 13, "BUSY", "pb-silk pb-silk-tiny");
    txt(g, 292, 18, "2.13inch e-Paper V4", "pb-silk pb-silk-tiny", { "text-anchor": "end" });
    // the glass, its ribbon, the active area 1:1
    sv("rect", { x: 10, y: 28, width: 280, height: 140, rx: 2, "class": "pb-epd-glass" }, g);
    sv("rect", { x: 272, y: 40, width: 18, height: 116, "class": "pb-epd-fpc" }, g);
    sv("rect", { x: 20, y: 37, width: 250, height: 122, "class": "pb-epd-paper" }, g);
    refs.image = sv("image", { x: 20, y: 37, width: 250, height: 122, preserveAspectRatio: "none", "class": "pb-epd-image" }, g);
    refs.flash = sv("rect", { x: 20, y: 37, width: 250, height: 122, "class": "pb-epd-flash" }, g);
    return refs;
  }

  // ---------- the parts without pins ----------

  function card(g, h, name, hint, width) {
    width = width || COL;
    sv("rect", { x: 0, y: 0, width: width, height: h, rx: 8, "class": "pb-card" }, g);
    txt(g, 12, 18, name, "pb-card-title");
    if (hint) txt(g, width - 12, 18, hint, "pb-card-hint", { "text-anchor": "end" });
  }

  // the arena's scale: under the breadboard and the cards across the whole
  // bench when it is wide (a PicoGo of 14 cm is 36 px there), in a card of
  // the column when it is narrow (layout() sets it)
  var ARENA = { w: 200, h: 120, s: 1.53, x: 12, y: 28, cw: COL };

  function arenaLayout(wide) {
    ARENA = wide ? { w: 200, h: 120, s: 2.6, x: Math.round((COL + GAP + COL - 520) / 2), y: 30, cw: COL + GAP + COL }
                 : { w: 200, h: 120, s: 1.53, x: 12, y: 28, cw: COL };
    SIDE.picogo.h = Math.round(ARENA.y + ARENA.h * ARENA.s + 26);
  }

  function ax(x) { return ARENA.x + x * ARENA.s; }
  function ay(y) { return ARENA.y + (ARENA.h - y) * ARENA.s; }

  function drawArena(g, b) {
    var refs = {};
    card(g, SIDE.picogo.h, t("boardRobot"), "200 × 120 cm", ARENA.cw);
    var A = ARENA;
    var floor = sv("g", { "class": "pb-arena" }, g);
    refs.floor = floor;
    sv("rect", { x: A.x - 4, y: A.y - 4, width: A.w * A.s + 8, height: A.h * A.s + 8, rx: 3, "class": "pb-arena-wall" }, floor);
    sv("rect", { x: A.x, y: A.y, width: A.w * A.s, height: A.h * A.s, "class": "pb-arena-floor" }, floor);
    for (var x = 20; x < A.w; x += 20) sv("line", { x1: ax(x), y1: A.y, x2: ax(x), y2: A.y + A.h * A.s, "class": "pb-arena-grid" }, floor);
    for (var y = 20; y < A.h; y += 20) sv("line", { x1: A.x, y1: ay(y), x2: A.x + A.w * A.s, y2: ay(y), "class": "pb-arena-grid" }, floor);
    refs.obstacles = sv("g", null, floor);
    // the bacon: the target (input arena.bacon)
    refs.bacon = sv("g", { "class": "pb-bacon pb-drag", tabindex: "-1" }, floor);
    title(refs.bacon, t("boardBacon"));
    sv("ellipse", { cx: 0, cy: 0, rx: 12, ry: 6.5, "class": "pb-bacon-fat" }, refs.bacon);
    sv("path", { d: "M-10 -2 q4 -4 8 0 t8 0 t5 -1", "class": "pb-bacon-meat" }, refs.bacon);
    sv("path", { d: "M-10 3 q4 -4 8 0 t8 0 t5 -1", "class": "pb-bacon-meat" }, refs.bacon);
    // the box (input arena.box), 20 x 20 cm
    refs.box = sv("g", { "class": "pb-box pb-drag", visibility: "hidden" }, floor);
    title(refs.box, t("boardBox"));
    sv("rect", { x: -10 * A.s, y: -10 * A.s, width: 20 * A.s, height: 20 * A.s, rx: 1.5, "class": "pb-box-card" }, refs.box);
    sv("rect", { x: -10 * A.s, y: -2, width: 20 * A.s, height: 4, "class": "pb-box-tape" }, refs.box);
    // the sensors' view
    refs.sonar = sv("line", { "class": "pb-sonar" }, floor);
    refs.sonarDot = sv("circle", { r: 2.2, "class": "pb-sonar-dot" }, floor);
    // the robot: body r 7 cm, wheels at +-5 cm (devices/picogo.rb)
    var s = A.s;
    refs.robot = sv("g", { "class": "pb-robot" }, floor);
    title(refs.robot, "Waveshare PicoGo");
    refs.irL = sv("path", { "class": "pb-ir", d: cone(1) }, refs.robot);
    refs.irR = sv("path", { "class": "pb-ir", d: cone(-1) }, refs.robot);
    // the chassis with its wheel wells, the wheels over them; the Pico on
    // top, the ultrasonic module and the IR sensors at the front, a caster
    // ball at the back
    sv("circle", { cx: 0, cy: 0, r: 7 * s, "class": "pb-robot-body" }, refs.robot);
    sv("circle", { cx: 0, cy: 0, r: 6.3 * s, "class": "pb-robot-rim" }, refs.robot);
    [-1, 1].forEach(function (side) {
      sv("rect", { x: -3.8 * s, y: side * 5 * s - 1.5 * s, width: 7.6 * s, height: 3 * s, rx: 0.6 * s, "class": "pb-robot-well" }, refs.robot);
    });
    refs.wheelL = wheel(refs.robot, -1, s);
    refs.wheelR = wheel(refs.robot, 1, s);
    sv("circle", { cx: -5.3 * s, cy: 0, r: 0.8 * s, "class": "pb-robot-caster" }, refs.robot);
    sv("rect", { x: -2.8 * s, y: -1.25 * s, width: 5.1 * s, height: 2.5 * s, rx: 0.3 * s, "class": "pb-robot-pico" }, refs.robot);
    sv("rect", { x: -2.95 * s, y: -0.45 * s, width: 0.7 * s, height: 0.9 * s, "class": "pb-robot-usb" }, refs.robot);
    sv("rect", { x: 4.4 * s, y: -2.6 * s, width: 1.4 * s, height: 5.2 * s, rx: 0.3 * s, "class": "pb-robot-sonar-board" }, refs.robot);
    sv("circle", { cx: 5.6 * s, cy: -1.4 * s, r: 0.95 * s, "class": "pb-robot-eye" }, refs.robot);
    sv("circle", { cx: 5.6 * s, cy: 1.4 * s, r: 0.95 * s, "class": "pb-robot-eye" }, refs.robot);
    refs.irDotL = sv("circle", { cx: Math.cos(0.35) * 6.3 * s, cy: -Math.sin(0.35) * 6.3 * s, r: 0.45 * s, "class": "pb-robot-ir" }, refs.robot);
    refs.irDotR = sv("circle", { cx: Math.cos(0.35) * 6.3 * s, cy: Math.sin(0.35) * 6.3 * s, r: 0.45 * s, "class": "pb-robot-ir" }, refs.robot);
    refs.robotBuzz = sv("circle", { cx: -4 * s, cy: 0, r: 1.2 * s, "class": "pb-robot-buzz" }, refs.robot);
    refs.info = txt(g, ARENA.x, SIDE.picogo.h - 9, "", "pb-small pb-info");
    // drags: the box and the bacon follow the pointer
    dragger(refs.bacon, "arena.bacon", b);
    dragger(refs.box, "arena.box", b);
    return refs;
  }

  // an IR sensor's 60° cone in the robot's own frame (x forward, svg y = -y)
  function cone(side) {
    var s = ARENA.s, r0 = 7 * s, r1 = (7 + 12) * s;
    var c = side * 20 * Math.PI / 180, a0 = c - Math.PI / 6, a1 = c + Math.PI / 6;
    var p = function (r, a) { return (Math.cos(a) * r).toFixed(1) + " " + (-Math.sin(a) * r).toFixed(1); };
    return "M" + p(r0, a0) + " L" + p(r1, a0) + " A" + r1 + " " + r1 + " 0 0 0 " + p(r1, a1) + " L" + p(r0, a1) + " A" + r0 + " " + r0 + " 0 0 1 " + p(r0, a0) + " Z";
  }

  // a wheel seen from above: its tread's ribs move with its speed (spin)
  function wheel(g, side, s) {
    var w = sv("g", null, g);
    sv("rect", { x: -3.3 * s, y: side * 5 * s - 1.1 * s, width: 6.6 * s, height: 2.2 * s, rx: 0.5 * s, "class": "pb-wheel" }, w);
    return sv("line", { x1: -3 * s, y1: side * 5 * s, x2: 3 * s, y2: side * 5 * s, "class": "pb-tread",
                        "stroke-width": 1.6 * s, "stroke-dasharray": (0.45 * s).toFixed(2) + " " + (0.55 * s).toFixed(2) }, w);
  }

  function dragger(node, key, b) {
    var active = false;
    node.addEventListener("pointerdown", function (e) {
      active = true;
      node.setPointerCapture(e.pointerId);
      e.preventDefault();
    });
    node.addEventListener("pointermove", function (e) {
      if (!active) return;
      var m = b.svg.getScreenCTM();
      if (!m) return;
      var pt = b.svg.createSVGPoint();
      pt.x = e.clientX;
      pt.y = e.clientY;
      var local = pt.matrixTransform(m.inverse());
      var gm = b.refs.picogo.g.transform.baseVal.consolidate();
      var ox = gm ? gm.matrix.e : 0, oy = gm ? gm.matrix.f : 0;
      var x = (local.x - ox - ARENA.x) / ARENA.s, y = ARENA.h - (local.y - oy - ARENA.y) / ARENA.s;
      setXY(key, x, y);
    });
    var end = function () { active = false; };
    node.addEventListener("pointerup", end);
    node.addEventListener("pointercancel", end);
  }

  function getXY(key) {
    var v = values[key] || (key === "arena.bacon" ? "170,30" : "150,60");
    var xy = v.split(",");
    return [Number(xy[0]) || 0, Number(xy[1]) || 0];
  }

  function setXY(key, x, y) {
    x = Math.max(12, Math.min(ARENA.w - 12, Math.round(x)));
    y = Math.max(12, Math.min(ARENA.h - 12, Math.round(y)));
    api.input(key, x + "," + y);
    if (bench && bench.state) render();
    else if (bench) drawArenaObjects(bench, null);
  }

  function drawCamera(g, b) {
    var refs = {};
    card(g, SIDE.camera.h, t("boardCamera"), "160 × 120");
    var mod = sv("g", { transform: "translate(16 36)" }, g);
    title(mod, t("boardCamera"));
    sv("rect", { x: 0, y: 0, width: 92, height: 92, rx: 5, "class": "pb-cam-pcb" }, mod);
    [[6, 6], [86, 6], [6, 86], [86, 86]].forEach(function (c) { sv("circle", { cx: c[0], cy: c[1], r: 3, "class": "pb-mount-hole" }, mod); });
    sv("rect", { x: 24, y: 24, width: 44, height: 44, rx: 3, fill: "#16181b" }, mod);
    sv("circle", { cx: 46, cy: 46, r: 18, "class": "pb-cam-barrel" }, mod);
    refs.lens = sv("circle", { cx: 46, cy: 46, r: 12, fill: "url(#pb-lens)" }, mod);
    sv("circle", { cx: 41, cy: 41, r: 3, "class": "pb-shine" }, mod);
    txt(mod, 46, 84, "SIM CAM", "pb-silk pb-silk-tiny", { "text-anchor": "middle" });
    sv("rect", { x: 140, y: 36, width: 166, height: 126, rx: 2, "class": "pb-photo-frame" }, g);
    refs.photo = sv("image", { x: 143, y: 39, width: 160, height: 120, preserveAspectRatio: "none", "class": "pb-photo" }, g);
    refs.flash = sv("rect", { x: 143, y: 39, width: 160, height: 120, "class": "pb-photo-flash" }, g);
    refs.caption = txt(g, 112, 158, "", "pb-small", { "text-anchor": "middle" });
    return refs;
  }

  function drawWifi(g, b) {
    var refs = {};
    card(g, SIDE.wifi.h, t("boardWifi"), "chunkynet");
    var ap = sv("g", { transform: "translate(16 36)" }, g);
    title(ap, "access point chunkynet");
    sv("rect", { x: 0, y: 26, width: 50, height: 22, rx: 4, "class": "pb-router" }, ap);
    sv("line", { x1: 10, y1: 26, x2: 6, y2: 4, "class": "pb-router-ant" }, ap);
    sv("line", { x1: 40, y1: 26, x2: 44, y2: 4, "class": "pb-router-ant" }, ap);
    refs.apLed = sv("circle", { cx: 12, cy: 37, r: 2.4, "class": "pb-router-led" }, ap);
    refs.linkLed = sv("circle", { cx: 21, cy: 37, r: 2.4, "class": "pb-router-led" }, ap);
    refs.waves = sv("g", { "class": "pb-wifi-waves" }, ap);
    [8, 13, 18].forEach(function (r) { sv("path", { d: "M" + (25 - r) + " " + (20 - r * 0.2) + " a" + r + " " + r + " 0 0 1 " + 2 * r + " 0" }, refs.waves); });
    refs.status = txt(g, 16, 104, "", "pb-small");
    // the requests, newest last
    sv("rect", { x: 84, y: 30, width: COL - 96, height: 86, rx: 5, "class": "pb-http" }, g);
    txt(g, 92, 44, "HTTP", "pb-http-title");
    refs.lines = [];
    for (var i = 0; i < 4; i++) refs.lines.push(txt(g, 92, 60 + i * 15, "", "pb-http-line"));
    return refs;
  }

  function drawLaptop(g, b) {
    var refs = {};
    card(g, SIDE.laptop.h, t("boardLaptop"), "BLE UART");
    var lap = sv("g", { transform: "translate(20 30)" }, g);
    sv("rect", { x: 0, y: 0, width: 290, height: 136, rx: 7, "class": "pb-laptop-lid" }, lap);
    sv("rect", { x: 8, y: 8, width: 274, height: 120, rx: 2, "class": "pb-laptop-screen" }, lap);
    sv("path", { d: "M-14 140 H304 L296 152 H-6 Z", "class": "pb-laptop-base" }, lap);
    sv("rect", { x: 120, y: 140, width: 50, height: 4, rx: 2, "class": "pb-laptop-notch" }, lap);
    refs.head = txt(lap, 16, 23, "", "pb-term pb-term-head");
    refs.dot = sv("circle", { cx: 272, cy: 19, r: 3.5, "class": "pb-ble-dot" }, lap);
    sv("line", { x1: 14, y1: 29, x2: 276, y2: 29, "class": "pb-term-rule" }, lap);
    refs.lines = [];
    for (var i = 0; i < 6; i++) refs.lines.push(txt(lap, 16, 44 + i * 14, "", "pb-term"));
    return refs;
  }

  // ---------- the controls under the drawing ----------

  function scriptedMark(row) {
    var mark = el("span", "pico-scripted", "🤖");
    mark.title = t("boardScripted");
    mark.setAttribute("aria-label", t("boardScripted"));
    mark.hidden = true;
    row.appendChild(mark);
    return mark;
  }

  function slider(box, b, key, label, min, max, step, value, unit, scale) {
    var row = el("label", "pico-slider");
    var name = el("span", "pico-slider-name", label);
    var input = el("input");
    input.type = "range";
    input.min = String(min);
    input.max = String(max);
    input.step = String(step);
    var shown = values[key] !== undefined ? Number(values[key]) * (scale || 1) : value;
    input.value = String(shown);
    var out = el("output", "pico-slider-value");
    var show = function (v) { out.textContent = num(v, step < 1 ? 1 : 0) + " " + unit; input.setAttribute("aria-valuetext", out.textContent); };
    show(shown);
    input.addEventListener("input", function () {
      show(Number(input.value));
      api.input(key, String(Number(input.value) / (scale || 1)));
    });
    row.appendChild(name);
    row.appendChild(input);
    row.appendChild(out);
    var mark = scriptedMark(row);
    box.appendChild(row);
    b.controls[key] = { input: input, show: show, mark: mark, scale: scale || 1 };
  }

  function buildControls(box, b) {
    var parts = b.parts;
    if (parts.indexOf("button14") >= 0) {
      var row = el("div", "pico-row");
      var press = el("button", "pico-press", t("boardButton"));
      press.type = "button";
      press.setAttribute("aria-pressed", "false");
      var down = function () { press.setAttribute("aria-pressed", "true"); api.input("pin14", "1"); render(); };
      var up = function () { if (press.getAttribute("aria-pressed") !== "true") return; press.setAttribute("aria-pressed", "false"); api.input("pin14", "0"); render(); };
      press.addEventListener("pointerdown", function (e) { press.setPointerCapture(e.pointerId); down(); });
      press.addEventListener("pointerup", up);
      press.addEventListener("pointercancel", up);
      press.addEventListener("keydown", function (e) {
        if ((e.key === " " || e.key === "Enter") && !e.repeat) { e.preventDefault(); down(); }
      });
      press.addEventListener("keyup", function (e) { if (e.key === " " || e.key === "Enter") { e.preventDefault(); up(); } });
      press.addEventListener("blur", up);
      press.addEventListener("click", function (e) { e.preventDefault(); });
      row.appendChild(press);
      b.controls.pin14 = { button: press, mark: scriptedMark(row) };
      box.appendChild(row);
    }
    if (parts.indexOf("light26") >= 0) slider(box, b, "adc26", t("boardLight") + " (GP26)", 0, 100, 1, 50, "%", 100);
    if (parts.indexOf("temp") >= 0) slider(box, b, "tempC", t("boardRoom"), -10, 45, 0.5, 21, "°C");
    if (parts.indexOf("envsensor") >= 0) {
      slider(box, b, "bme.t", t("boardTempC"), -10, 45, 0.5, 21, "°C");
      slider(box, b, "bme.rh", t("boardHumidity"), 0, 100, 1, 45, "%");
      slider(box, b, "bme.p", t("boardPressure"), 900, 1100, 1, 1013, "hPa");
    }
    if (parts.indexOf("picogo") >= 0) {
      var arena = el("div", "pico-row pico-arena-keys");
      var boxIn = el("label", "pico-check");
      var check = el("input");
      check.type = "checkbox";
      check.checked = values["arena.box"] !== undefined && values["arena.box"] !== "";
      check.addEventListener("change", function () {
        if (check.checked) { var xy = getXY("arena.box"); setXY("arena.box", xy[0], xy[1]); }
        else { api.input("arena.box", ""); render(); }
        moves.forEach(function (m) { if (m.key === "arena.box") m.btn.disabled = !check.checked; });
      });
      boxIn.appendChild(check);
      boxIn.appendChild(document.createTextNode(" " + t("boardBoxIn")));
      arena.appendChild(boxIn);
      var moves = [];
      [["arena.box", t("boardBox")], ["arena.bacon", t("boardBacon")]].forEach(function (o) {
        var grp = el("span", "pico-moves");
        grp.setAttribute("role", "group");
        grp.setAttribute("aria-label", o[1]);
        grp.appendChild(el("span", "pico-moves-name", o[1]));
        [["←", -5, 0, "boardLeft"], ["→", 5, 0, "boardRight"], ["↑", 0, 5, "boardUp"], ["↓", 0, -5, "boardDown"]].forEach(function (d) {
          var btn = el("button", "pico-move", d[0]);
          btn.type = "button";
          btn.setAttribute("aria-label", o[1] + " " + t(d[3]));
          btn.addEventListener("click", function () { var xy = getXY(o[0]); setXY(o[0], xy[0] + d[1], xy[1] + d[2]); });
          if (o[0] === "arena.box") btn.disabled = !check.checked;
          moves.push({ key: o[0], btn: btn });
          grp.appendChild(btn);
        });
        arena.appendChild(grp);
      });
      box.appendChild(arena);
    }
    if (parts.indexOf("camera") >= 0) {
      var cam = el("label", "pico-slider");
      cam.appendChild(el("span", "pico-slider-name", t("boardPicture")));
      var pick = el("select");
      ["chunky", "bacon"].forEach(function (n) {
        var o = el("option", null, n);
        o.value = n;
        pick.appendChild(o);
      });
      pick.value = values.camera || "chunky";
      pick.addEventListener("change", function () { api.input("camera", pick.value); showPhoto(b, pick.value, false); });
      cam.appendChild(pick);
      box.appendChild(cam);
      b.controls.camera = { select: pick };
      showPhoto(b, pick.value, false);
    }
    if (parts.indexOf("wifi") >= 0) {
      var off = el("label", "pico-check");
      var cb = el("input");
      cb.type = "checkbox";
      cb.checked = values["wifi.off"] === "1";
      cb.addEventListener("change", function () { api.input("wifi.off", cb.checked ? "1" : "0"); render(); });
      off.appendChild(cb);
      off.appendChild(document.createTextNode(" " + t("boardWifiOff")));
      var wrow = el("div", "pico-row");
      wrow.appendChild(off);
      b.controls["wifi.off"] = { check: cb, mark: scriptedMark(wrow) };
      box.appendChild(wrow);
    }
    if (parts.indexOf("laptop") >= 0) {
      var form = el("form", "pico-row pico-laptop-form");
      var link = el("label", "pico-check");
      var lc = el("input");
      lc.type = "checkbox";
      lc.checked = values["ble.connected"] !== "0";
      lc.addEventListener("change", function () { api.input("ble.connected", lc.checked ? "1" : "0"); });
      link.appendChild(lc);
      link.appendChild(document.createTextNode(" " + t("boardBleLink")));
      var lab = el("label", "pico-line");
      lab.appendChild(el("span", "pico-slider-name", t("boardLine")));
      var line = el("input");
      line.type = "text";
      line.autocomplete = "off";
      line.spellcheck = false;
      line.maxLength = 200;
      lab.appendChild(line);
      var send = el("button", "pico-send", t("boardSend"));
      send.type = "submit";
      form.addEventListener("submit", function (e) {
        e.preventDefault();
        if (line.value === "") return;
        if (!lc.checked) { lc.checked = true; api.input("ble.connected", "1"); }
        api.sendLine(line.value);
        line.value = "";
      });
      form.appendChild(lab);
      form.appendChild(send);
      form.appendChild(link);
      box.appendChild(form);
      b.controls.laptop = { line: line, link: lc };
    }
  }

  // ---------- drawing the state ----------

  var pendingFrame = 0;

  function schedule() {
    if (pendingFrame) return;
    pendingFrame = requestAnimationFrame(function () { pendingFrame = 0; render(); });
  }

  function render() {
    var b = bench;
    if (!b) return;
    var s = b.state || { pins: {}, parts: {}, scripted: {}, onboard: 0 };
    var parts = s.parts || {};
    var scripted = s.scripted || {};
    var pins = s.pins || {};
    // the pins
    for (var pin = 1; pin <= 40; pin++) {
      var gp = PINS[pin][1];
      var node = b.pico.pins[pin];
      var st = gp === undefined ? null : pins[String(gp)];
      var cls = "pb-pinstate";
      var opacity = "";
      if (st) {
        if (st === "o1") cls += " is-high";
        else if (st === "o0") cls += " is-low";
        else if (st[0] === "p") { cls += " is-pwm"; opacity = String(0.25 + 0.75 * Math.min(100, Number(st.slice(1)) || 0) / 100); }
        else if (/^in/.test(st)) cls += " is-in";
        else if (st === "adc") cls += " is-adc";
        else if (st === "i2c" || st === "spi" || st === "alt") cls += " is-bus";
      }
      node.setAttribute("class", cls);
      if (opacity) node.style.opacity = opacity; else node.style.opacity = "";
      var t0 = "pin " + pin + ": " + PINS[pin][0] + (st ? " · " + st : "");
      if (node.firstChild) node.firstChild.textContent = t0; else title(node, t0);
    }
    b.pico.ledGlow.style.opacity = s.onboard ? "1" : "0";
    b.pico.ledGlow.parentNode.querySelector(".pb-onboard").classList.toggle("is-on", !!s.onboard);
    var temp = parts.temp;
    b.pico.chipTemp.textContent = temp ? "🌡 " + num(temp.c, 1) + " °C" : "";
    // the parts
    var r = b.refs;
    if (r.led15) {
      var bright = parts.led15 ? Math.min(1, Number(parts.led15.b) || 0) : 0;
      r.led15.glow.style.opacity = String(bright);
      r.led15.dome.classList.toggle("is-on", bright > 0);
      r.led15.dome.style.fillOpacity = bright > 0 ? String(0.6 + 0.4 * bright) : "";
    }
    if (r.button14) {
      var pressed = parts.button14 ? !!parts.button14.pressed : values.pin14 === "1";
      var byScript = parts.button14 && parts.button14.scripted;
      r.button14.cap.classList.toggle("is-pressed", pressed);
      r.button14.finger.setAttribute("visibility", byScript && pressed ? "visible" : "hidden");
      if (b.controls.pin14) {
        b.controls.pin14.mark.hidden = !byScript;
        b.controls.pin14.button.classList.toggle("is-down", pressed);
      }
    }
    if (r.light26) {
      var light = parts.light26 ? Number(parts.light26.light) : (values.adc26 !== undefined ? Number(values.adc26) : 0.5);
      r.light26.sun.style.opacity = String(0.25 + 0.75 * light);
      r.light26.rays.style.opacity = String(light);
      r.light26.value.textContent = num(light * 3.3, 2) + " V";
    }
    if (r.buzzer16) {
      var hz = parts.buzzer16 ? Number(parts.buzzer16.hz) || 0 : 0;
      r.buzzer16.waves.style.opacity = hz > 0 ? "1" : "0";
      r.buzzer16.hz.textContent = hz > 0 ? hz + " Hz" : "";
    }
    if (r.envsensor) {
      var env = parts.envsensor || {};
      var tv = env.t !== undefined ? env.t : Number(values["bme.t"] || 21);
      var rh = env.rh !== undefined ? env.rh : Number(values["bme.rh"] || 45);
      var pr = env.p !== undefined ? env.p : Number(values["bme.p"] || 1013.25);
      r.envsensor.t.textContent = num(tv, 1) + " °C";
      r.envsensor.rh.textContent = num(rh, 0) + " % RH";
      r.envsensor.p.textContent = num(pr, 1) + " hPa";
    }
    if (r.epd213) {
      var e = parts.epd213 || {};
      r.epd213.busy.classList.toggle("is-on", !!e.busy);
      var flash = !!e.busy && (e.mode === "full" || e.mode === "fast") && !REDUCED;
      r.epd213.flash.classList.toggle("is-flashing", flash);
      r.epd213.flash.classList.toggle("is-fast", flash && e.mode === "fast");
    }
    if (r.picogo) drawArenaObjects(b, parts.picogo);
    if (r.wifi) {
      var wf = parts.wifi || { up: values["wifi.off"] !== "1", connected: false };
      r.wifi.apLed.classList.toggle("is-on", !!wf.up);
      r.wifi.linkLed.classList.toggle("is-on", !!wf.connected);
      r.wifi.waves.style.opacity = wf.up ? "1" : "0.15";
      r.wifi.status.textContent = wf.connected ? "192.168.4.23" : (wf.up ? "" : t("boardOff"));
      if (r.link) r.link.classList.toggle("is-on", !!wf.connected);
    }
    if (r.laptop) {
      var bl = parts.laptop || {};
      r.laptop.dot.classList.toggle("is-on", !!bl.connected);
      r.laptop.dot.classList.toggle("is-adv", !bl.connected && !!bl.adv);
      r.laptop.head.textContent = bl.adv ? "BLE · " + bl.adv + " · " + (bl.connected ? t("boardBleOn") : t("boardAdvertising")) : "BLE · …";
      if (r.link && !r.wifi) r.link.classList.toggle("is-on", !!bl.connected);
    }
    // scripted inputs: the sliders follow the exercise and wait
    Object.keys(b.controls).forEach(function (key) {
      var c = b.controls[key];
      if (!c.input) return;
      var on = scripted[key] !== undefined;
      c.mark.hidden = !on;
      c.input.disabled = on;
      if (on) {
        var v = Number(scripted[key]) * c.scale;
        c.input.value = String(v);
        c.show(v);
      }
    });
    if (b.controls["wifi.off"]) {
      var wOn = scripted["wifi.off"] !== undefined;
      b.controls["wifi.off"].mark.hidden = !wOn;
      b.controls["wifi.off"].check.disabled = wOn;
      if (wOn) b.controls["wifi.off"].check.checked = scripted["wifi.off"] === "1";
    }
    tone();
    narrate(b, s);
    describe(b);
  }

  function drawArenaObjects(b, robot) {
    var r = b.refs.picogo;
    var A = ARENA;
    var layout = robot ? robot.layout : (b.layout || "open");
    if (r.layout !== layout) {
      r.layout = layout;
      while (r.obstacles.firstChild) r.obstacles.removeChild(r.obstacles.firstChild);
      (layout === "wall60" ? [[97, 0, 6, 120]] : layout === "box" ? [[120, 50, 20, 20]] : []).forEach(function (o) {
        sv("rect", { x: ax(o[0]), y: ay(o[1] + o[3]), width: o[2] * A.s, height: o[3] * A.s, "class": "pb-obstacle" }, r.obstacles);
      });
    }
    // the page's own drags show at once, the worker's state follows
    var bacon = values["arena.bacon"] || !(robot && robot.bacon) ? getXY("arena.bacon") : robot.bacon.split(",").map(Number);
    r.bacon.setAttribute("transform", "translate(" + ax(bacon[0]) + " " + ay(bacon[1]) + ")");
    var boxVal = values["arena.box"] !== undefined ? values["arena.box"] : robot && robot.box;
    if (boxVal) {
      var bx = String(boxVal).split(",").map(Number);
      r.box.setAttribute("transform", "translate(" + ax(bx[0]) + " " + ay(bx[1]) + ")");
      r.box.setAttribute("visibility", "visible");
    } else r.box.setAttribute("visibility", "hidden");
    var x = robot ? robot.x : 30, y = robot ? robot.y : 60, h = robot ? robot.h : 0;
    r.robot.setAttribute("transform", "translate(" + ax(x).toFixed(1) + " " + ay(y).toFixed(1) + ") rotate(" + (-h).toFixed(1) + ")");
    var seenL = !!robot && robot.ir && robot.ir[0] === 0, seenR = !!robot && robot.ir && robot.ir[1] === 0;
    r.irL.classList.toggle("is-seen", seenL);
    r.irR.classList.toggle("is-seen", seenR);
    r.irDotL.classList.toggle("is-on", seenL);
    r.irDotR.classList.toggle("is-on", seenR);
    var pins = (b.state && b.state.pins) || {};
    r.robotBuzz.classList.toggle("is-on", pins["4"] === "o1");
    if (robot) {
      var rad = h * Math.PI / 180, d = Number(robot.sonar) + 7;
      var x0 = x + Math.cos(rad) * 7, y0 = y + Math.sin(rad) * 7, x1 = x + Math.cos(rad) * d, y1 = y + Math.sin(rad) * d;
      r.sonar.setAttribute("x1", ax(x0)); r.sonar.setAttribute("y1", ay(y0));
      r.sonar.setAttribute("x2", ax(x1)); r.sonar.setAttribute("y2", ay(y1));
      r.sonarDot.setAttribute("cx", ax(x1)); r.sonarDot.setAttribute("cy", ay(y1));
      r.sonar.style.display = r.sonarDot.style.display = "";
      var moving = (robot.l !== 0 || robot.r !== 0);
      r.robot.classList.toggle("is-hit", !!robot.hit);
      r.info.textContent = "sonar " + num(robot.sonar, 0) + " cm · IR " + (robot.ir[0] === 0 ? "L●" : "L○") + " " + (robot.ir[1] === 0 ? "R●" : "R○") +
        " · " + num(robot.l, 0) + " / " + num(robot.r, 0) + " cm/s" + (moving ? " · " + t("boardMotorsOn") : "");
      spin(b, robot);
    } else {
      r.sonar.style.display = r.sonarDot.style.display = "none";
      r.info.textContent = "";
    }
  }

  // the treads move with each wheel's speed (cm/s), drawn between states
  function spin(b, robot) {
    var r = b.refs.picogo;
    r.speeds = [robot.hit ? 0 : robot.l, robot.hit ? 0 : robot.r];
    if (REDUCED || r.spinning) return;
    if (!r.speeds[0] && !r.speeds[1]) return;
    r.spinning = true;
    r.off = r.off || [0, 0];
    var last = performance.now();
    var step = function (now) {
      if (bench !== b) return;
      var dt = (now - last) / 1000;
      last = now;
      // the ribs pass at the floor's speed (the dash pattern is 1 cm long)
      r.off[0] = (r.off[0] - r.speeds[0] * dt * ARENA.s) % (ARENA.s * 100);
      r.off[1] = (r.off[1] - r.speeds[1] * dt * ARENA.s) % (ARENA.s * 100);
      r.wheelL.style.strokeDashoffset = r.off[0].toFixed(1);
      r.wheelR.style.strokeDashoffset = r.off[1].toFixed(1);
      if (!r.speeds[0] && !r.speeds[1]) { r.spinning = false; return; }
      requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }

  function showPhoto(b, name, captured) {
    var r = b.refs.camera;
    if (!r) return;
    photo(name, function (url) {
      if (!url || bench !== b) return;
      r.photo.setAttribute("href", url);
      r.photo.classList.toggle("is-preview", !captured);
      r.caption.textContent = captured ? name + ".pgm" : "";
      if (captured && !REDUCED) {
        r.flash.classList.remove("is-flashing");
        void r.flash.getBoundingClientRect();
        r.flash.classList.add("is-flashing");
      }
    });
  }

  // the camera's canned pictures: 8-bit PGM (P5) to a data: URL
  var photos = {};
  function photo(name, done) {
    if (photos[name]) { if (photos[name].url) done(photos[name].url); else photos[name].waiting.push(done); return; }
    var entry = photos[name] = { url: "", waiting: [done] };
    fetch("assets/data/pico/camera/" + encodeURIComponent(name) + ".pgm").then(function (res) {
      if (!res.ok) throw new Error(res.status);
      return res.arrayBuffer();
    }).then(function (buf) {
      var bytes = new Uint8Array(buf);
      var fields = [], at = 0;
      while (fields.length < 4 && at < bytes.length) {
        while (at < bytes.length && /\s/.test(String.fromCharCode(bytes[at]))) at++;
        if (bytes[at] === 35) { while (at < bytes.length && bytes[at] !== 10) at++; continue; }
        var start = at;
        while (at < bytes.length && !/\s/.test(String.fromCharCode(bytes[at]))) at++;
        fields.push(String.fromCharCode.apply(null, bytes.subarray(start, at)));
      }
      at++;
      var w = Number(fields[1]), h = Number(fields[2]);
      var canvas = document.createElement("canvas");
      canvas.width = w;
      canvas.height = h;
      var ctx = canvas.getContext("2d");
      var img = ctx.createImageData(w, h);
      for (var i = 0; i < w * h; i++) {
        var v = bytes[at + i] || 0;
        img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v;
        img.data[i * 4 + 3] = 255;
      }
      ctx.putImageData(img, 0, 0);
      entry.url = canvas.toDataURL();
    }).catch(function () { entry.url = ""; }).then(function () {
      entry.waiting.forEach(function (f) { f(entry.url); });
      entry.waiting = [];
    });
  }

  // the panel's RAM (250 rows of 16 bytes, MSB first, 1 = white; row =
  // x, bit = 121 - y) as a 250 x 122 picture
  function epdPicture(hex) {
    var canvas = document.createElement("canvas");
    canvas.width = 250;
    canvas.height = 122;
    var ctx = canvas.getContext("2d");
    var img = ctx.createImageData(250, 122);
    var black = 0;
    for (var x = 0; x < 250; x++) {
      for (var y = 0; y < 122; y++) {
        var s = 121 - y;
        var i = (x * 16 + (s >> 3)) * 2;
        var byte = parseInt(hex.substr(i, 2), 16) || 0;
        var white = (byte & (0x80 >> (s & 7))) !== 0;
        var o = (y * 250 + x) * 4;
        if (!white) black++;
        img.data[o] = white ? 0xe8 : 0x1d;
        img.data[o + 1] = white ? 0xe6 : 0x1d;
        img.data[o + 2] = white ? 0xdf : 0x1d;
        img.data[o + 3] = 255;
      }
    }
    ctx.putImageData(img, 0, 0);
    return { url: canvas.toDataURL(), black: black };
  }

  // ---------- sound (muted until the learner turns it on) ----------

  function tone() {
    var b = bench;
    var hz = 0;
    if (b && b.sound && b.state) {
      var p = b.state.parts || {};
      if (p.buzzer16) hz = Number(p.buzzer16.hz) || 0;
      if (!hz && p.picogo && (b.state.pins || {})["4"] === "o1") hz = 2300;
    }
    if (!hz) { if (audio && audio.osc) { audio.osc.stop(); audio.osc = null; } return; }
    try {
      audio = audio || { ctx: new (window.AudioContext || window.webkitAudioContext)() };
      if (audio.ctx.state === "suspended") audio.ctx.resume();
      if (!audio.osc) {
        audio.gain = audio.ctx.createGain();
        audio.gain.gain.value = 0.04;
        audio.gain.connect(audio.ctx.destination);
        audio.osc = audio.ctx.createOscillator();
        audio.osc.type = "square";
        audio.osc.connect(audio.gain);
        audio.osc.start();
      }
      audio.osc.frequency.value = hz;
    } catch (e) { audio = null; }
  }

  // ---------- words: the live region and the text alternative ----------

  function say(b, text) {
    if (!text) return;
    b.pendingSay = b.pendingSay ? b.pendingSay + " " + text : text;
    var wait = Math.max(0, b.lastSay + SAY_EVERY - performance.now());
    if (b.sayTimer) return;
    b.sayTimer = setTimeout(function () {
      b.sayTimer = null;
      b.lastSay = performance.now();
      b.say.textContent = b.pendingSay;
      b.pendingSay = "";
    }, wait);
  }

  // what changed since the last state, in words
  function narrate(b, s) {
    var said = b.spoken;
    var parts = s.parts || {};
    var news = [];
    var change = function (key, value, text) {
      if (said[key] === undefined) { said[key] = value; return; }
      if (said[key] === value) return;
      said[key] = value;
      if (text) news.push(text);
    };
    if (parts.led15) change("led", parts.led15.b > 0, t("boardLed") + " " + (parts.led15.b > 0 ? t("boardOn") : t("boardOff")) + ".");
    change("onboard", !!s.onboard, t("boardOnboard") + " " + (s.onboard ? t("boardOn") : t("boardOff")) + ".");
    if (parts.button14) change("button", !!parts.button14.pressed, t("boardButton") + " " + (parts.button14.pressed ? t("boardPressed") : t("boardReleased")) + ".");
    if (parts.buzzer16) change("buzz", Number(parts.buzzer16.hz) || 0, t("boardBuzzer") + " " + (parts.buzzer16.hz ? parts.buzzer16.hz + " Hz" : t("boardSilent")) + ".");
    if (parts.picogo) {
      var g = parts.picogo;
      var moving = (g.l !== 0 || g.r !== 0) && !g.hit;
      change("hit", !!g.hit, g.hit ? t("boardRobotHit") + "." : "");
      change("moving", moving, moving ? t("boardRobotMoving") + "." : fill(t("boardRobotStopped"), num(Math.max(0, g.sonar), 0)) + ".");
    }
    if (parts.wifi) change("wifi", !!parts.wifi.connected, parts.wifi.connected ? t("boardWifiUp") + "." : "");
    if (parts.laptop) change("ble", !!parts.laptop.connected, (parts.laptop.connected ? t("boardBleOn") : t("boardBleOff")) + ".");
    if (news.length) say(b, news.join(" "));
  }

  function describe(b) {
    var s = b.state || { parts: {}, pins: {} };
    var bits = [t("boardTitle") + ": " + partNames(b).join(", ") + "."];
    var p = s.parts || {};
    if (p.led15) bits.push(t("boardLed") + " " + (p.led15.b > 0 ? t("boardOn") : t("boardOff")) + ".");
    if (s.onboard) bits.push(t("boardOnboard") + " " + t("boardOn") + ".");
    if (p.button14) bits.push(t("boardButton") + " " + (p.button14.pressed ? t("boardPressed") : t("boardReleased")) + ".");
    if (p.buzzer16 && p.buzzer16.hz) bits.push(t("boardBuzzer") + " " + p.buzzer16.hz + " Hz.");
    if (b.refs.epd213) bits.push(fill(t("boardEpdAlt"), epd.frames, epd.black) + ".");
    if (p.picogo) bits.push(t("boardRobot") + ": x " + num(p.picogo.x, 0) + " cm, y " + num(p.picogo.y, 0) + " cm, " + num(p.picogo.h, 0) + "°, sonar " + num(p.picogo.sonar, 0) + " cm.");
    var text = bits.join(" ");
    if (b.desc.textContent !== text) b.desc.textContent = text;
  }

  // ---------- events from the worker ----------

  function onFrame(b, text) {
    var bar = text.indexOf("|");
    var hex = bar >= 0 ? text.slice(bar + 1) : text;
    epd.frames++;
    epd.hex = hex;
    var pic = epdPicture(hex);
    epd.url = pic.url;
    epd.black = pic.black;
    if (b && b.refs.epd213) {
      b.refs.epd213.flash.classList.remove("is-flashing", "is-fast");
      b.refs.epd213.image.setAttribute("href", epd.url);
      say(b, t("boardEpdRefreshed") + " (" + epd.frames + ").");
      describe(b);
    }
  }

  function onBle(b, text) {
    var r = b.refs.laptop;
    if (text.indexOf("tx|") === 0) {
      window.dispatchEvent(new CustomEvent("chunky:pico-ble", { detail: { text: text.slice(3) } }));
      text.slice(3).split("\n").forEach(function (line, i, all) {
        if (line === "" && i === all.length - 1) return;
        b.ble.push("← " + line);
        say(b, t("boardBleGot") + ": " + line);
      });
    } else if (text.indexOf("rx|") === 0) {
      b.ble.push("→ " + text.slice(3));
    }
    while (b.ble.length > 6) b.ble.shift();
    if (r) r.lines.forEach(function (node, i) {
      var line = b.ble[i] || "";
      node.textContent = line.length > 40 ? line.slice(0, 39) + "…" : line;
      node.setAttribute("class", "pb-term" + (line.indexOf("←") === 0 ? " pb-term-in" : ""));
    });
  }

  function onLog(b, text) {
    if (/^camera /.test(text)) {
      showPhoto(b, text.slice(7), true);
      say(b, t("boardCaptured") + ".");
      return;
    }
    var m = /^(GET|POST|PUT|DELETE|HEAD|PATCH) (\S+) (\d+)( \(canned\))?/.exec(text);
    if (m && b.refs.wifi) {
      var url = m[2].replace(/^https?:\/\//, "");
      var line = m[1] + " " + url;
      var tail = " " + m[3] + (m[4] ? " · " + t("boardCanned") : "");
      if (line.length + tail.length > 44) line = line.slice(0, 43 - tail.length) + "…";
      b.http.push([line + tail, m[3] === "200" ? "ok" : "bad"]);
      while (b.http.length > 4) b.http.shift();
      b.refs.wifi.lines.forEach(function (node, i) {
        var e = b.http[i];
        node.textContent = e ? e[0] : "";
        node.setAttribute("class", "pb-http-line" + (e ? " is-" + e[1] : ""));
      });
      say(b, m[1] + " " + url.split("/")[0] + " " + m[3] + ".");
    }
  }

  // ---------- mounting ----------

  function slotWidth(slot) {
    return slot && slot.clientWidth ? slot.clientWidth : (document.querySelector(".cell") || document.body).clientWidth;
  }

  function attach(b, slot) {
    document.querySelectorAll(".pico-slot").forEach(function (s) { if (s !== slot) s.hidden = true; });
    slot.appendChild(b.el);
    slot.hidden = false;
    if (window.ResizeObserver) {
      if (api._observer) api._observer.disconnect();
      api._observer = new ResizeObserver(function () {
        if (!bench || bench.el.parentNode !== slot) return;
        var wide = slotWidth(slot) >= WIDE;
        if (wide !== bench.wide) rebuild(slot);
      });
      api._observer.observe(slot);
    }
  }

  function rebuild(slot) {
    var old = bench;
    var b = build(old.config, old.ui, slotWidth(slot));
    b.key = old.key; b.idx = old.idx; b.state = old.state; b.log = old.log; b.http = old.http; b.ble = old.ble;
    b.status = old.status; b.spoken = old.spoken; b.badge.textContent = old.badge.textContent; b.badge.className = old.badge.className;
    b.lastState = old.lastState; b.lastReset = old.lastReset; b.sound = false;
    // a message the old bench's live region was still waiting to say goes
    // to the new one
    if (old.sayTimer) clearTimeout(old.sayTimer);
    b.lastSay = old.lastSay;
    if (old.pendingSay) say(b, old.pendingSay);
    if (old.el.parentNode) old.el.parentNode.replaceChild(b.el, old.el);
    render();
  }

  function setBadge(b, text, cls) {
    b.badge.textContent = text;
    b.badge.className = "pico-badge" + (cls ? " is-" + cls : "");
  }

  // a run of the bench's cell ended (main.rb's answer): the Pico keeps its pins
  window.addEventListener("chunky:picoruby", function (e) {
    var d = e.detail || {};
    if (!bench || d.kind !== "cell" || String(d.idx) !== bench.idx || !d.board) return;
    if (d.status === "reset" || d.status === "stopped") return;
    setBadge(bench, t("boardEnded"), "ended");
  });

  var api = window.chunkyPicoBoard = {
    mount: function (idx, configJson, uiJson) {
      var config = {}, ui = {};
      try { config = JSON.parse(String(configJson || "{}")); } catch (e) { config = {}; }
      try { ui = uiJson ? JSON.parse(String(uiJson)) : (bench ? bench.ui : {}); } catch (e) { ui = {}; }
      var key = JSON.stringify([config.board, config.parts]);
      var slot = document.getElementById("pico-slot-" + idx);
      if (!bench || bench.key !== key) {
        if (bench && bench.el.parentNode) bench.el.parentNode.removeChild(bench.el);
        if (bench && bench.sayTimer) clearTimeout(bench.sayTimer);
        build(config, ui, slotWidth(slot));
        bench.key = key;
      }
      bench.config = config;
      bench.idx = String(idx);
      // until the worker takes this run, what it sends is the last run's
      bench.waiting = String(idx);
      bench.lastReset = "";
      // a cell's run is a reset of the board: the pins start over, the
      // e-paper keeps its picture
      if (config.reset !== false) {
        // a line sent to an earlier run is not sent again to this one
        delete values["ble.line"];
        bench.state = null;
        bench.layout = "open";
        bench.spoken = {};
        bench.ble = [];
        bench.log = [];
        onBle(bench, "");
      }
      if (slot) attach(bench, slot);
      setBadge(bench, "▶ " + t("boardRunning"), "running");
      render();
    },
    started: function (idx) {
      if (bench && bench.waiting === String(idx)) bench.waiting = "";
    },
    receive: function (kind, text) {
      if (!bench || bench.waiting) return;
      text = String(text);
      if (kind === "state") {
        bench.lastState = text;
        try { bench.state = JSON.parse(text); } catch (e) { return; }
        schedule();
      } else if (kind === "epd_frame") {
        onFrame(bench, text);
      } else {
        bench.log.push([kind, text]);
        if (bench.log.length > 50) bench.log.shift();
        if (kind === "ble") onBle(bench, text);
        else if (kind === "log") onLog(bench, text);
      }
    },
    inputs: function () { return JSON.stringify(values); },
    // the radio as the laptop's side sees it (html/pico_laptop.rb): the
    // Pico's advertising name while its cell runs, and the link
    ble: function () {
      var l = bench && bench.state && bench.state.parts && bench.state.parts.laptop || {};
      return JSON.stringify({ adv: l.adv || "", connected: !!l.connected,
                              running: !!bench && !bench.waiting && bench.badge.className.indexOf("is-running") >= 0 });
    },
    input: function (key, value) {
      values[String(key)] = String(value);
      // a value set from elsewhere (a test, the CRuby cell): the slider follows
      var c = bench && bench.controls[String(key)];
      if (c && c.input && document.activeElement !== c.input) {
        c.input.value = String(Number(value) * c.scale);
        c.show(Number(value) * c.scale);
      }
      if (window.chunkyPicoRuby && window.chunkyPicoRuby.input) window.chunkyPicoRuby.input(String(key), String(value));
    },
    // a line from the laptop's side (the bench's laptop panel, the CRuby cell)
    sendLine: function (text) {
      lineNo++;
      api.input("ble.line", lineNo + "|" + String(text));
    },
    reset: function (reason) {
      if (!bench) return;
      bench.lastReset = String(reason || "");
      // the worker is gone: LEDs off, motors stopped; the e-paper keeps its image
      var s = bench.state;
      if (s) {
        s.pins = {};
        s.onboard = 0;
        var p = s.parts || {};
        if (p.led15) p.led15.b = 0;
        if (p.buzzer16) p.buzzer16.hz = 0;
        if (p.picogo) { p.picogo.l = 0; p.picogo.r = 0; }
        if (p.epd213) p.epd213.busy = false;
        if (p.laptop) p.laptop.connected = false;
        if (p.wifi) p.wifi.connected = false;
      }
      setBadge(bench, "↺ " + t("boardReset"), "reset");
      say(bench, t("boardReset"));
      render();
    },
    unmount: function () {
      if (api._observer) api._observer.disconnect();
      if (bench && bench.el.parentNode) bench.el.parentNode.removeChild(bench.el);
      if (bench && bench.sayTimer) clearTimeout(bench.sayTimer);
      bench = null;
      values = {};
      epd = { frames: 0, hex: "", url: "", black: 0 };
      if (audio && audio.osc) { audio.osc.stop(); audio.osc = null; }
    },
    // for tests: what the bench holds now
    debug: function () {
      return bench ? { idx: bench.idx, frames: epd.frames, state: bench.lastState || "", frame: epd.hex,
                       log: bench.log.slice(), reset: bench.lastReset || "", wide: bench.wide,
                       black: epd.black, badge: bench.badge.textContent, said: bench.say.textContent } : null;
    }
  };
})();
