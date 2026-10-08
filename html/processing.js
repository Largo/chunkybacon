// The window of a Processing sketch (html/processing.rb, lesson 36), as a
// canvas below the cell. Ruby records what a frame draws - a list of
// commands, styles and matrix included only when they change - and this
// paints them; the mouse and the keys go back with the next frame:
//
//   var sketch = chunkySketch(node, function (json) { ... sketch.paint(frameJson, looping) });
//   sketch.paint(firstFrameJson, true);   // setup and the first frame, then it runs
//   sketch.error("NoMethodError: ...");   // a frame failed: it stops
//   sketch.stop();                        // the cell runs again, the lesson changes
//
// The callback gets {"dt": ms, "events": [...]} as JSON. Like the gem's
// window the canvas keeps what was drawn: a frame paints over the last one
// unless it calls background. A sketch that is scrolled out of view rests.
(function () {
  "use strict";

  var DPR = Math.min(window.devicePixelRatio || 1, 2);
  var CAPS = { round: "round", butt: "butt", square: "square" };
  var JOINS = { miter: "miter", round: "round", square: "bevel" };
  var KEYS_TO_KEEP = { ArrowLeft: 1, ArrowRight: 1, ArrowUp: 1, ArrowDown: 1, " ": 1, Tab: 1 };

  function font(name, size) {
    var family = name ? JSON.stringify(String(name)) + ", sans-serif" : "sans-serif";
    return size + "px " + family;
  }

  // textWidth in Ruby asks the canvas
  var measurer = null;
  window.chunkySketchTextWidth = function (text, size, name) {
    measurer = measurer || document.createElement("canvas").getContext("2d");
    measurer.font = font(name, size);
    return measurer.measureText(String(text)).width;
  };

  function alphaOf(css) {
    var m = /,\s*([\d.]+)\)$/.exec(css || "");
    return m ? parseFloat(m[1]) : 1;
  }

  window.chunkySketch = function (node, onFrame) {
    var canvas = document.createElement("canvas");
    canvas.className = "sketch-canvas";
    canvas.tabIndex = 0;
    var message = document.createElement("div");
    message.className = "cell-error sketch-error";
    message.hidden = true;
    var printed = document.createElement("pre");   // what the frames print
    printed.className = "cell-stdout sketch-print";
    printed.hidden = true;
    node.className = "sketch-stage";
    node.appendChild(canvas);
    node.appendChild(printed);
    node.appendChild(message);
    var ctx = canvas.getContext("2d");

    var width = 0, height = 0;
    var style = { fill: "rgba(255,255,255,1)", stroke: "rgba(0,0,0,1)", weight: 1,
                  cap: "round", join: "miter", blend: "source-over", font: null, size: 12 };
    var matrix = [1, 0, 0, 1, 0, 0];
    var events = [];
    var looping = false, stopped = false, visible = true, scheduled = false;
    var last = null, frames = 0;

    function resize(w, h) {
      w = Math.max(1, Math.round(w));
      h = Math.max(1, Math.round(h));
      if (w === width && h === height) return;
      var old = null;
      if (width && height) {
        old = document.createElement("canvas");
        old.width = canvas.width;
        old.height = canvas.height;
        old.getContext("2d").drawImage(canvas, 0, 0);
      }
      width = w;
      height = h;
      canvas.width = w * DPR;
      canvas.height = h * DPR;
      canvas.style.width = w + "px";
      canvas.style.aspectRatio = w + " / " + h;
      if (old) {
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.drawImage(old, 0, 0);
      }
      applyMatrix();
    }

    function applyMatrix() {
      ctx.setTransform(DPR * matrix[0], DPR * matrix[1], DPR * matrix[2],
                       DPR * matrix[3], DPR * matrix[4], DPR * matrix[5]);
    }

    function applyStyle() {
      ctx.globalCompositeOperation = style.blend;
      if (style.fill) ctx.fillStyle = style.fill;
      if (style.stroke && style.weight > 0) {
        ctx.strokeStyle = style.stroke;
        ctx.lineWidth = style.weight;
        ctx.lineCap = CAPS[style.cap] || "round";
        ctx.lineJoin = JOINS[style.join] || "miter";
      }
    }

    function stroking() { return style.stroke && style.weight > 0; }

    function finish(rule) {
      if (style.fill) ctx.fill(rule || "nonzero");
      if (stroking()) ctx.stroke();
    }

    function path(points, close) {
      ctx.moveTo(points[0], points[1]);
      for (var i = 2; i + 1 < points.length; i += 2) ctx.lineTo(points[i], points[i + 1]);
      if (close) ctx.closePath();
    }

    var ops = {
      size: function (w, h) { resize(w, h); },
      background: function (css) {
        ctx.save();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.globalCompositeOperation = "source-over";
        if (alphaOf(css) < 1) ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = css;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.restore();
      },
      clear: function () {
        ctx.save();
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.restore();
      },
      style: function (fill, stroke, weight, cap, join, blend, name, size) {
        style = { fill: fill, stroke: stroke, weight: weight, cap: cap, join: join,
                  blend: blend, font: name, size: size };
      },
      matrix: function (a, b, c, d, e, f) {
        matrix = [a, b, c, d, e, f];
        applyMatrix();
      },
      point: function (x, y) {
        if (!stroking()) return;
        ctx.save();
        ctx.fillStyle = style.stroke;
        ctx.beginPath();
        if (style.cap === "round") ctx.arc(x, y, style.weight / 2, 0, Math.PI * 2);
        else ctx.rect(x - style.weight / 2, y - style.weight / 2, style.weight, style.weight);
        ctx.fill();
        ctx.restore();
      },
      line: function (x1, y1, x2, y2) {
        if (!stroking()) return;
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.stroke();
      },
      rect: function (x, y, w, h, lt, rt, rb, lb) {
        ctx.beginPath();
        if (lt !== undefined && ctx.roundRect) ctx.roundRect(x, y, w, h, [lt, rt, rb, lb]);
        else ctx.rect(x, y, w, h);
        finish();
      },
      ellipse: function (x, y, w, h) {
        ctx.beginPath();
        ctx.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, 0, Math.PI * 2);
        finish();
      },
      arc: function (x, y, w, h, start, stop) {
        ctx.beginPath();
        ctx.moveTo(x + w / 2, y + h / 2);
        ctx.ellipse(x + w / 2, y + h / 2, Math.abs(w / 2), Math.abs(h / 2), 0, start, stop);
        ctx.closePath();
        finish();
      },
      poly: function (points, close, holes) {
        if (!points || points.length < 4) return;
        ctx.beginPath();
        path(points, close);
        (holes || []).forEach(function (hole) { if (hole.length >= 4) path(hole, true); });
        // an open shape is filled too, as if closed; only its outline is open
        if (style.fill && points.length >= 6) ctx.fill(holes ? "evenodd" : "nonzero");
        if (stroking()) ctx.stroke();
      },
      text: function (str, x, y) {
        if (!style.fill) return;
        ctx.font = font(style.font, style.size);
        ctx.textAlign = "left";
        ctx.textBaseline = "alphabetic";
        ctx.fillText(str, x, y);
      },
      // the gem's text(str, x, y, w, h): aligned in the box, from the top
      textbox: function (str, x, y, w, h, alignH, alignV) {
        if (!style.fill) return;
        ctx.font = font(style.font, style.size);
        var metrics = ctx.measureText(str);
        var ascent = metrics.fontBoundingBoxAscent || style.size * 0.8;
        if (alignH === "right") x += w - metrics.width;
        else if (alignH === "center") x += (w - metrics.width) / 2;
        if (alignV === "bottom") y += h - ascent;
        else if (alignV === "center") y += (h - ascent) / 2;
        ctx.textAlign = "left";
        ctx.textBaseline = "alphabetic";
        ctx.fillText(str, x, y + ascent);
      }
    };

    function paint(json, loops) {
      if (stopped) return;
      var commands = JSON.parse(String(json));
      for (var i = 0; i < commands.length; i++) {
        var command = commands[i];
        var op = ops[command[0]];
        if (!op) continue;
        if (command[0] !== "style" && command[0] !== "matrix" && command[0] !== "size") applyStyle();
        op.apply(null, command.slice(1));
      }
      ctx.globalCompositeOperation = "source-over";
      frames += 1;
      node.setAttribute("data-frames", String(frames));   // for the tests
      looping = Boolean(loops);
      if (looping) schedule();
    }

    function schedule() {
      if (scheduled || stopped || !visible) return;
      scheduled = true;
      requestAnimationFrame(tick);
    }

    function tick(now) {
      scheduled = false;
      if (stopped) return;
      if (!visible) { last = null; return; }
      if (!looping && events.length === 0) return;
      var dt = last === null ? 1000 / 60 : now - last;
      last = now;
      var batch = events;
      events = [];
      // Ruby paints (or fails) from inside this call
      onFrame(JSON.stringify({ dt: dt, events: batch }));
    }

    function at(event) {
      var r = canvas.getBoundingClientRect();
      return { x: Math.round((event.clientX - r.left) * width / r.width * 10) / 10,
               y: Math.round((event.clientY - r.top) * height / r.height * 10) / 10 };
    }

    function push(event) {
      if (stopped) return;
      events.push(event);
      schedule();
    }

    canvas.addEventListener("pointermove", function (event) {
      var p = at(event);
      push({ t: "move", x: p.x, y: p.y, drag: event.buttons > 0 });
    });
    canvas.addEventListener("pointerdown", function (event) {
      canvas.focus({ preventScroll: true });
      canvas.setPointerCapture(event.pointerId);
      event.preventDefault();
      var p = at(event);
      push({ t: "down", x: p.x, y: p.y, b: event.button });
    });
    canvas.addEventListener("pointerup", function (event) {
      var p = at(event);
      push({ t: "up", x: p.x, y: p.y, b: event.button, clicks: event.detail });
    });
    canvas.addEventListener("pointerenter", function () { push({ t: "enter" }); });
    canvas.addEventListener("pointerleave", function () { push({ t: "leave" }); });
    canvas.addEventListener("wheel", function (event) {
      push({ t: "wheel", dx: event.deltaX, dy: event.deltaY });
    }, { passive: true });
    canvas.addEventListener("contextmenu", function (event) { event.preventDefault(); });
    canvas.addEventListener("keydown", function (event) {
      if (event.ctrlKey || event.metaKey) return;   // the page's own shortcuts
      if (KEYS_TO_KEEP[event.key]) event.preventDefault();
      push({ t: "keydown", key: event.key });
    });
    canvas.addEventListener("keyup", function (event) {
      push({ t: "keyup", key: event.key });
    });

    var observer = null;
    if ("IntersectionObserver" in window) {
      observer = new IntersectionObserver(function (entries) {
        visible = entries[entries.length - 1].isIntersecting;
        if (visible && looping) schedule();
      });
      observer.observe(canvas);
    }

    var controller = {
      paint: paint,
      error: function (text) {
        message.hidden = false;
        message.textContent = String(text);
        node.setAttribute("data-error", String(text));   // for the tests
        controller.stop();
      },
      // the last 40 lines that puts printed in a frame or an event
      print: function (text) {
        var lines = (printed.textContent + String(text)).split("\n");
        if (lines.length > 41) lines = lines.slice(lines.length - 41);
        printed.textContent = lines.join("\n");
        printed.hidden = false;
        printed.scrollTop = printed.scrollHeight;
      },
      stop: function () {
        stopped = true;
        if (observer) observer.disconnect();
      },
      // for the tests: events as if from the mouse or the keyboard, and
      // the colour of a pixel ([r, g, b, a]) in the sketch's coordinates
      send: function (list) { list.forEach(push); },
      pixel: function (x, y) {
        return Array.prototype.slice.call(ctx.getImageData(Math.round(x * DPR), Math.round(y * DPR), 1, 1).data);
      },
      frames: function () { return frames; }
    };
    node.chunkySketch = controller;
    return controller;
  };
})();
