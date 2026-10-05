// The letter for show_letter (main.rb, lesson 27): an envelope drawn into a
// canvas, with red boxes for the postcode. The learner writes a digit into
// each box; when the pen lifts, every box with ink becomes 64 numbers the
// way the digits in digits.csv were made (the drawing scaled to the full
// height of a 32x32 square, then counted in 4x4 blocks: 0..16 each), and
// the kernel's callback gets them as JSON. Its answer is written on the
// letter, next to the boxes.
//
//   var letter = chunkyLetter(node, 4, "rumale-5", labelsJson, function (json) { ... });
//   letter.answer("8000 Zürich", false);
//
// The ink outlives a re-run of the cell (per key), so a changed program
// reads the same drawing again.
(function () {
  "use strict";

  var W = 480, H = 300;
  var BOX_W = 54, BOX_H = 68, BOX_GAP = 10, BOX_X = 52, BOX_Y = 168;
  var SIDE = 32;        // the digits' drawings: 32x32 pixels...
  var BLOCK = 4;        // ...counted in 4x4 blocks: 8x8 numbers
  var PEN = 4.2;        // stroke width in those 32 pixels
  var INK = "#1f3a8a";
  var inks = {};        // key -> strokes, kept across re-runs
  var fox = null;       // the stamp's picture

  function foxImage() {
    if (!fox) {
      fox = new Image();
      fox.src = "assets/chunky.svg";
    }
    return fox;
  }

  function boxRect(i) {
    return { x: BOX_X + i * (BOX_W + BOX_GAP), y: BOX_Y, w: BOX_W, h: BOX_H };
  }

  function drawEnvelope(ctx, labels, boxes) {
    ctx.fillStyle = "#fbf7ee";
    ctx.fillRect(0, 0, W, H);
    // airmail border
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, 0, W, H);
    ctx.rect(9, 9, W - 18, H - 18);
    ctx.clip("evenodd");
    for (var s = -H, n = 0; s < W + H; s += 28, n++) {
      ctx.fillStyle = n % 2 === 0 ? "#c8372d" : "#2b4fa3";
      ctx.beginPath();
      ctx.moveTo(s, 0);
      ctx.lineTo(s + 14, 0);
      ctx.lineTo(s + 14 - H, H);
      ctx.lineTo(s - H, H);
      ctx.fill();
    }
    ctx.restore();

    // sender, small, top left
    ctx.fillStyle = "#5f5247";
    ctx.font = "13px 'Shantell Sans', 'Segoe Print', sans-serif";
    ctx.fillText(labels.from || "", 28, 38);

    // the stamp: a perforated edge, the fox, a value
    var sx = W - 102, sy = 24, sw = 72, sh = 86;
    ctx.fillStyle = "#fff";
    ctx.fillRect(sx, sy, sw, sh);
    ctx.fillStyle = "#fbf7ee";
    for (var px = sx; px <= sx + sw; px += 8) {
      dot(ctx, px, sy, 3); dot(ctx, px, sy + sh, 3);
    }
    for (var py = sy; py <= sy + sh; py += 8) {
      dot(ctx, sx, py, 3); dot(ctx, sx + sw, py, 3);
    }
    ctx.fillStyle = "#fdeee3";
    ctx.fillRect(sx + 7, sy + 7, sw - 14, sh - 14);
    var img = foxImage();
    if (img.complete && img.naturalWidth) {
      ctx.drawImage(img, sx + 12, sy + 10, sw - 24, sw - 24);
    }
    ctx.fillStyle = "#c14a2e";
    ctx.font = "bold 12px 'Atkinson Hyperlegible Next', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(labels.value || "", sx + sw / 2, sy + sh - 13);
    ctx.textAlign = "left";

    // the address
    ctx.fillStyle = "#1a1208";
    ctx.font = "22px 'Shantell Sans', 'Segoe Print', sans-serif";
    ctx.fillText(labels.to || "", BOX_X, 122);
    ctx.fillText(labels.street || "", BOX_X, 152);

    // the postcode boxes
    ctx.strokeStyle = "#d33a2c";
    ctx.lineWidth = 2;
    for (var i = 0; i < boxes; i++) {
      var r = boxRect(i);
      ctx.strokeRect(r.x, r.y, r.w, r.h);
    }
  }

  function dot(ctx, x, y, r) {
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }

  // the postmark over the stamp, once there is an answer
  function drawPostmark(ctx, labels) {
    var d = new Date();
    var date = ("0" + d.getDate()).slice(-2) + "." + ("0" + (d.getMonth() + 1)).slice(-2) + "." + String(d.getFullYear()).slice(-2);
    ctx.save();
    ctx.translate(W - 112, 92);
    ctx.rotate(-0.22);
    ctx.strokeStyle = "rgba(40, 40, 60, 0.6)";
    ctx.fillStyle = "rgba(40, 40, 60, 0.6)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 0, 34, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(0, 0, 26, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = "bold 10px 'Atkinson Hyperlegible Next', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(date, 0, 4);
    ctx.font = "bold 7px 'Atkinson Hyperlegible Next', sans-serif";
    ctx.fillText((labels.post || "").toUpperCase(), 0, -12);
    // wavy cancellation lines
    for (var k = 0; k < 3; k++) {
      ctx.beginPath();
      for (var x = 38; x < 110; x += 2) {
        var y = -10 + k * 10 + Math.sin(x / 7) * 3;
        if (x === 38) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawStrokes(ctx, strokes) {
    ctx.strokeStyle = INK;
    ctx.fillStyle = INK;
    ctx.lineWidth = 3.5;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    strokes.forEach(function (stroke) {
      if (stroke.length === 1) {
        dot(ctx, stroke[0][0], stroke[0][1], 1.8);
        return;
      }
      ctx.beginPath();
      ctx.moveTo(stroke[0][0], stroke[0][1]);
      for (var i = 1; i < stroke.length; i++) ctx.lineTo(stroke[i][0], stroke[i][1]);
      ctx.stroke();
    });
  }

  // The pieces of the strokes that belong to box i: a segment counts where
  // its middle lies (the box and a little around it, for a pen that
  // overshoots the line).
  function segmentsIn(strokes, i) {
    var r = boxRect(i), m = 6;
    var inside = function (x, y) {
      return x >= r.x - m && x <= r.x + r.w + m && y >= r.y - m && y <= r.y + r.h + m;
    };
    var segs = [];
    strokes.forEach(function (stroke) {
      if (stroke.length === 1) {
        if (inside(stroke[0][0], stroke[0][1])) segs.push([stroke[0], stroke[0]]);
        return;
      }
      for (var k = 1; k < stroke.length; k++) {
        var a = stroke[k - 1], b = stroke[k];
        if (inside((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)) segs.push([a, b]);
      }
    });
    return segs;
  }

  // 64 numbers 0..16 for one box, or null when it has no ink: the drawing
  // scaled so that its height (or its width, when wider) fills the 32
  // pixels, centred, drawn with a thick pen, counted in 4x4 blocks
  function digitOf(strokes, i, scratch) {
    var segs = segmentsIn(strokes, i);
    if (segs.length === 0) return null;
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    segs.forEach(function (s) {
      s.forEach(function (p) {
        minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]);
        minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1]);
      });
    });
    var size = Math.max(maxX - minX, maxY - minY, 8);
    var scale = (SIDE - PEN) / size;
    var cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    var ctx = scratch.getContext("2d", { willReadFrequently: true });
    ctx.clearRect(0, 0, SIDE, SIDE);
    ctx.strokeStyle = "#000";
    ctx.fillStyle = "#000";
    ctx.lineWidth = PEN;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    segs.forEach(function (s) {
      var ax = (s[0][0] - cx) * scale + SIDE / 2, ay = (s[0][1] - cy) * scale + SIDE / 2;
      var bx = (s[1][0] - cx) * scale + SIDE / 2, by = (s[1][1] - cy) * scale + SIDE / 2;
      ctx.beginPath();
      ctx.moveTo(ax, ay);
      ctx.lineTo(bx, by);
      ctx.stroke();
    });
    var alpha = ctx.getImageData(0, 0, SIDE, SIDE).data;
    var cells = [];
    for (var by8 = 0; by8 < SIDE / BLOCK; by8++) {
      for (var bx8 = 0; bx8 < SIDE / BLOCK; bx8++) {
        var sum = 0;
        for (var y = 0; y < BLOCK; y++) {
          for (var x = 0; x < BLOCK; x++) {
            sum += alpha[((by8 * BLOCK + y) * SIDE + bx8 * BLOCK + x) * 4 + 3] / 255;
          }
        }
        cells.push(Math.min(16, Math.round(sum)));
      }
    }
    return cells;
  }

  // what Ruby gets, as small grey pictures under the letter
  function drawPreview(canvas, cells) {
    var ctx = canvas.getContext("2d");
    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, 8, 8);
    if (!cells) return;
    var img = ctx.createImageData(8, 8);
    for (var i = 0; i < 64; i++) {
      var v = 255 - Math.round(cells[i] * 255 / 16);
      img.data[i * 4] = v; img.data[i * 4 + 1] = v; img.data[i * 4 + 2] = v; img.data[i * 4 + 3] = 255;
    }
    ctx.putImageData(img, 0, 0);
  }

  window.chunkyLetter = function (node, boxes, key, labelsJson, callback) {
    var labels = {};
    try { labels = JSON.parse(String(labelsJson)); } catch (e) { labels = {}; }
    boxes = Math.max(1, Math.min(6, Number(boxes) || 4));
    var strokes = inks[key] || (inks[key] = []);
    var answer = "", answerError = false, timer = null, current = null;

    node.className = "letter-widget";
    var canvas = document.createElement("canvas");
    canvas.className = "letter-canvas";
    canvas.setAttribute("role", "img");
    canvas.setAttribute("aria-label", labels.hint || "");
    var ratio = window.devicePixelRatio || 1;
    canvas.width = W * ratio;
    canvas.height = H * ratio;
    var bar = document.createElement("div");
    bar.className = "letter-bar";
    var clear = document.createElement("button");
    clear.type = "button";
    clear.className = "letter-clear";
    clear.textContent = labels.clear || "Clear";
    var sees = document.createElement("span");
    sees.className = "letter-sees";
    sees.textContent = labels.sees || "";
    var previews = [];
    var strip = document.createElement("span");
    strip.className = "letter-previews";
    for (var i = 0; i < boxes; i++) {
      var p = document.createElement("canvas");
      p.width = 8; p.height = 8;
      p.className = "letter-preview";
      strip.appendChild(p);
      previews.push(p);
    }
    var message = document.createElement("div");
    message.className = "letter-error";
    message.hidden = true;
    // the answer is drawn into the canvas; a screen reader hears it from here
    var spoken = document.createElement("span");
    spoken.className = "letter-answer sr-only";
    spoken.setAttribute("aria-live", "polite");
    bar.appendChild(clear);
    bar.appendChild(sees);
    bar.appendChild(strip);
    bar.appendChild(spoken);
    node.appendChild(canvas);
    node.appendChild(bar);
    node.appendChild(message);

    var scratch = document.createElement("canvas");
    scratch.width = SIDE;
    scratch.height = SIDE;

    function render() {
      var ctx = canvas.getContext("2d");
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      drawEnvelope(ctx, labels, boxes);
      if (answer && !answerError) {
        drawPostmark(ctx, labels);
        ctx.fillStyle = "#1a1208";
        // the answer on the line under the boxes, where the town goes
        ctx.font = "24px 'Shantell Sans', 'Segoe Print', sans-serif";
        var text = answer, room = W - 30 - BOX_X;
        while (text.length > 1 && ctx.measureText(text).width > room) text = text.slice(0, -2) + "…";
        ctx.fillText(text, BOX_X, BOX_Y + BOX_H + 30);
      } else if (strokes.length === 0) {
        ctx.fillStyle = "#9a8f84";
        ctx.font = "15px 'Shantell Sans', 'Segoe Print', sans-serif";
        ctx.fillText(labels.hint || "", BOX_X, BOX_Y + BOX_H + 26);
      }
      drawStrokes(ctx, strokes);
    }

    function digits() {
      var found = [];
      for (var i = 0; i < boxes; i++) {
        var cells = digitOf(strokes, i, scratch);
        drawPreview(previews[i], cells);
        if (cells) found.push(cells);
      }
      return found;
    }

    function ask() {
      timer = null;
      if (!node.isConnected) return;
      var found = digits();
      if (found.length === 0) return;
      try {
        callback(JSON.stringify(found));
      } catch (e) {
        controller.answer(String(e), true);
      }
    }

    function later() {
      if (timer) clearTimeout(timer);
      timer = setTimeout(ask, 250);
    }

    function point(event) {
      var r = canvas.getBoundingClientRect();
      return [Math.round((event.clientX - r.left) * W / r.width * 10) / 10,
              Math.round((event.clientY - r.top) * H / r.height * 10) / 10];
    }

    canvas.addEventListener("pointerdown", function (event) {
      event.preventDefault();
      canvas.setPointerCapture(event.pointerId);
      if (timer) { clearTimeout(timer); timer = null; }
      current = [point(event)];
      strokes.push(current);
      render();
    });
    canvas.addEventListener("pointermove", function (event) {
      if (!current) return;
      var p = point(event), last = current[current.length - 1];
      if (Math.abs(p[0] - last[0]) + Math.abs(p[1] - last[1]) < 1.5) return;
      current.push(p);
      render();
    });
    function lift() {
      if (!current) return;
      current = null;
      later();
    }
    canvas.addEventListener("pointerup", lift);
    canvas.addEventListener("pointercancel", lift);

    clear.addEventListener("click", function () {
      strokes.length = 0;
      answer = "";
      answerError = false;
      message.hidden = true;
      node.removeAttribute("data-answer");
      spoken.textContent = "";
      previews.forEach(function (p) { drawPreview(p, null); });
      render();
    });

    var controller = {
      answer: function (text, isError) {
        answer = String(text);
        answerError = Boolean(isError);
        node.setAttribute("data-answer", answerError ? "" : answer);   // for the tests
        message.hidden = !answerError;
        message.textContent = answerError ? answer : "";
        spoken.textContent = answer;
        render();
      },
      // for the tests: draw strokes as if with the pen, given in the
      // letter's own coordinates (480 x 300)
      draw: function (list) {
        list.forEach(function (stroke) { strokes.push(stroke); });
        render();
        later();
      },
      digits: function () { return JSON.stringify(digits()); }
    };
    node.chunkyLetter = controller;

    previews.forEach(function (p) { drawPreview(p, null); });
    render();
    // the fox and the hand font may arrive after the first drawing
    var img = foxImage();
    if (!img.complete) img.addEventListener("load", render, { once: true });
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(render);
    // a re-run keeps the drawing: read it again with the new code
    if (strokes.length) later();
    return controller;
  };
})();
