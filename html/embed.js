// Runnable Ruby on any page: every <pre data-chunky> becomes a Chunky Bacon
// cell (an iframe of embed.html), with one script tag:
//
//   <pre data-chunky data-gems="chunky_png" data-lang="en">puts 1 + 1</pre>
//   <script src="https://chunkybacon.idogawa.com/embed.js" defer></script>
//
// Attributes (all optional): data-gems="a,b", data-lang="de|en|ja",
// data-load="visible|click|eager" (when ruby.wasm loads, default visible),
// data-run="1" (run once loaded), aria-label (the iframe's title).
//
// The cells come from the course's host: where this script came from, or
// the script tag's data-base="https://chunkybacon.idogawa.com/". Only pages
// that host allows may frame them (Content-Security-Policy frame-ancestors,
// nginx/default.conf: https://idogawa.com); elsewhere the iframe stays empty.
//
// The code goes into the iframe's fragment (deflate-raw, base64url), so the
// embed's server never sees it. The iframe tells this page its height
// (postMessage); this page follows. ChunkyEmbed.url(code, options) makes the
// address for a hand-written <iframe> or a plain link.
(function () {
  "use strict";
  if (window.ChunkyEmbed) return;

  var script = document.currentScript;
  var configured = script && script.getAttribute("data-base");
  var base = new URL(configured || ".", script ? script.src : location.href).href;
  if (!/\/$/.test(base)) base += "/";

  function bytesToBase64url(bytes) {
    var chunks = [];
    for (var i = 0; i < bytes.length; i += 0x8000) {
      chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000)));
    }
    return btoa(chunks.join("")).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  function deflate(text) {
    var stream = new Blob([new TextEncoder().encode(text)]).stream()
      .pipeThrough(new CompressionStream("deflate-raw"));
    return new Response(stream).arrayBuffer().then(function (buf) { return new Uint8Array(buf); });
  }
  // the code as a <pre> holds it: without the blank first and last lines,
  // and without the indentation all its lines share
  function tidy(text) {
    var lines = text.replace(/\r\n?/g, "\n").replace(/^\s*\n/, "").replace(/\s+$/, "").split("\n");
    var indent = Math.min.apply(null, lines.filter(function (l) { return l.trim(); })
      .map(function (l) { return l.match(/^ */)[0].length; }).concat([Infinity]));
    if (!isFinite(indent)) indent = 0;
    return lines.map(function (l) { return l.slice(indent); }).join("\n");
  }

  function url(code, options) {
    options = options || {};
    return deflate(code).then(function (bytes) {
      var fragment = new URLSearchParams();
      fragment.set("code", bytesToBase64url(bytes));
      ["gems", "lang", "load", "run", "id"].forEach(function (key) {
        if (options[key]) fragment.set(key, String(options[key]));
      });
      return base + "embed.html#" + fragment.toString();
    });
  }

  var frames = [];
  // keyed by ids and names a frame sends: no prototype, so "__proto__" is
  // just a key and can't reach this page's Object.prototype
  var timings = Object.create(null);
  var count = 0;

  function upgrade(pre) {
    if (pre.dataset.chunkyDone) return;
    pre.dataset.chunkyDone = "1";
    var code = tidy(pre.textContent);
    var id = "chunky-" + (++count);
    var lines = code.split("\n").length;
    var frame = document.createElement("iframe");
    frame.title = pre.getAttribute("aria-label") || "Ruby code you can run (Chunky Bacon)";
    frame.loading = "lazy";
    // defence in depth: the server sends the same sandbox as a header
    // (NOTES.md); without allow-same-origin the cell has an origin of its
    // own, with no storage of this page's or the course's
    frame.setAttribute("sandbox", "allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads");
    frame.style.cssText = "display:block;width:100%;border:0;overflow:hidden;" +
      "height:" + Math.round(lines * 23.25 + 60) + "px";   // close to the real height: little jump
    frame.dataset.chunkyId = id;
    frames.push(frame);
    url(code, {
      gems: pre.dataset.gems, lang: pre.dataset.lang || document.documentElement.lang,
      load: pre.dataset.load, run: pre.dataset.run, id: id
    }).then(function (src) {
      frame.src = src;
      pre.replaceWith(frame);
    });
  }

  window.addEventListener("message", function (event) {
    var data = event.data;
    if (!data || typeof data !== "object" || !data.chunkyEmbed) return;
    // a sandboxed embed's origin is "null": who sent it is the frame itself.
    // Only our cells count - the ones upgrade made, and hand-written
    // <iframe>s of this course's embed.html - not any other child frame
    var frame = Array.prototype.filter.call(document.getElementsByTagName("iframe"),
      function (f) { return f.contentWindow === event.source; })[0];
    if (!frame) return;
    if (frames.indexOf(frame) < 0 && frame.src.indexOf(base + "embed.html") !== 0) return;
    // the id is this page's, never one the frame names
    if (!frame.dataset.chunkyId) frame.dataset.chunkyId = "chunky-" + (++count);
    var number = function (value) { return typeof value === "number" && isFinite(value); };
    if (data.chunkyEmbed === "size" && number(data.height) && data.height > 0 && data.height < 20000) {
      frame.style.height = data.height + "px";
    } else if (data.chunkyEmbed === "timing" && typeof data.name === "string" &&
               /^[\w-]{1,40}$/.test(data.name) && number(data.ms)) {
      var id = frame.dataset.chunkyId;
      (timings[id] = timings[id] || Object.create(null))[data.name] = data.ms;
      frame.dispatchEvent(new CustomEvent("chunky-embed:timing",
        { bubbles: true, detail: { id: id, name: data.name, ms: data.ms } }));
    }
  });

  function upgradeAll() {
    Array.prototype.forEach.call(document.querySelectorAll("pre[data-chunky]"), upgrade);
  }
  window.ChunkyEmbed = { url: url, upgrade: upgrade, upgradeAll: upgradeAll, frames: frames, timings: timings };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", upgradeAll);
  else upgradeAll();
})();
