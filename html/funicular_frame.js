// The preview of a Funicular app (lesson `funicular`): main.rb's
// mount_funicular calls chunkyFunicular(node, code, opts) after CRuby has
// run the cell's code headless (funicular_cells.rb). Here the same code runs
// for real: a fresh PicoRuby.wasm - the course's own runtime, Funicular
// compiled in - in an iframe of its own, so its globals (picorubyRefs, the
// event handlers) never meet the page shell's PicoRuby.
//
// What makes it a lesson rather than a screenshot: a MutationObserver on
// the app's container sees every change Funicular's patcher makes to the
// DOM. Each one flashes on an overlay above the app (never a class on the
// app's own elements: the patcher owns those), and a log below says what an
// update touched and how much it left alone - the virtual DOM's diff, seen.
// What the app prints (puts, and PicoRuby's errors) shows under the log.
(function () {
  "use strict";

  var LOADER = "assets/picoruby/init.iife.js";
  var hubs = {};
  var seq = 0;
  window.__chunkyFunicularHubs = hubs;

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    return node;
  }

  function fill(template, n) {
    return String(template).replace("%d", String(n));
  }

  // what the iframe runs before PicoRuby: it reports to its hub
  function frameHtml(id, lang) {
    var base = new URL(".", document.baseURI).href;
    return "<!doctype html><html lang='" + lang + "'><head><meta charset='utf-8'>" +
      "<base href='" + base + "'>" +
      "<style>" +
      "html{background:#fff;color:#1e2229}" +
      "body{margin:0;padding:12px 14px;font:16px/1.45 system-ui,-apple-system,'Segoe UI',sans-serif}" +
      "button{font:inherit;padding:.3em .8em;margin:.15em;border:1.5px solid #1e2229;border-radius:5px;background:#ede5d0;cursor:pointer}" +
      "button:hover{background:#e2b034}" +
      "input{font:inherit;padding:.25em .45em;border:1.5px solid #1e2229;border-radius:4px}" +
      "h1,h2,h3{margin:.2em 0 .4em;line-height:1.2}" +
      "p{margin:.35em 0}ul{margin:.3em 0;padding-left:1.4em}" +
      "#fn-layer{position:absolute;left:0;top:0;width:0;height:0;pointer-events:none}" +
      ".fn-flash{position:absolute;border:2px solid #ee3f24;background:rgba(238,63,36,.14);border-radius:3px;" +
      "animation:fn-flash 1.1s ease-out forwards}" +
      "@keyframes fn-flash{0%{opacity:1}70%{opacity:.8}100%{opacity:0}}" +
      "@media (prefers-reduced-motion:reduce){.fn-flash{animation:none;opacity:.8}}" +
      "</style></head><body><div id='app'></div><div id='fn-layer' aria-hidden='true'></div>" +
      "<script>(function(){var hub=parent.__chunkyFunicularHubs['" + id + "'];if(!hub)return;" +
      "['log','info','warn','error'].forEach(function(k){var o=console[k];console[k]=function(){" +
      "try{hub.print(k,Array.prototype.map.call(arguments,String).join(' '))}catch(e){}o.apply(console,arguments)}});" +
      "addEventListener('error',function(e){hub.print('error',String(e.message))});" +
      "addEventListener('unhandledrejection',function(e){hub.print('error',String(e.reason))});" +
      "var s=document.createElement('script');s.type='text/picoruby';s.textContent=hub.code;document.body.appendChild(s);" +
      "hub.attach(window,document);})();<\/script>" +
      "<script src='" + LOADER + "'><\/script></body></html>";
  }

  window.chunkyFunicular = function (node, code, optsJson) {
    var opts = JSON.parse(optsJson || "{}");
    var L = opts.labels || {};
    var id = "fn" + (++seq);

    node.className = "funicular-box";
    var head = el("div", "funicular-head");
    head.appendChild(el("span", "funicular-name", L.title || "Funicular"));
    head.appendChild(el("span", "funicular-engine", "PicoRuby.wasm"));
    var spacer = el("span", "funicular-spacer");
    head.appendChild(spacer);
    var flashLabel = el("label", "funicular-toggle");
    var flash = el("input");
    flash.type = "checkbox";
    flash.checked = opts.flash !== false;
    flashLabel.appendChild(flash);
    flashLabel.appendChild(document.createTextNode(" " + (L.flash || "Show changes")));
    head.appendChild(flashLabel);
    var restart = el("button", "funicular-restart", "↻ " + (L.restart || "Restart"));
    restart.type = "button";
    head.appendChild(restart);
    node.appendChild(head);

    var frame = el("iframe", "funicular-frame");
    frame.title = L.frameTitle || "Funicular app";
    node.appendChild(frame);
    var status = el("p", "funicular-status", L.loading || "Starting PicoRuby …");
    status.setAttribute("role", "status");
    node.appendChild(status);
    var log = el("ol", "funicular-log");
    log.setAttribute("aria-label", L.logTitle || "Updates");
    node.appendChild(log);
    var out = el("pre", "funicular-out");
    out.hidden = true;
    node.appendChild(out);

    var hub = { code: code, updates: 0, started: false, win: null, observer: null, resize: null, timer: null };
    hubs[id] = hub;

    function line(kind, text) {
      // PicoRuby's own chatter, and Emscripten's
      if (/^\[Funicular\] (Starting|Mount)|^Starting Funicular/.test(text)) return;
      out.hidden = false;
      var row = el("span", kind === "error" ? "funicular-err" : null, text + "\n");
      out.appendChild(row);
      while (out.childNodes.length > 200) out.removeChild(out.firstChild);
    }
    hub.print = function (kind, text) {
      if (/Exception|Error/.test(text) && kind !== "error") kind = "error";
      line(kind, text);
      if (kind === "error" && !hub.started) status.textContent = L.failed || "The app did not start.";
    };

    function countNodes(root) {
      var n = 0;
      var walker = root.ownerDocument.createTreeWalker(root, 5); // elements and text
      while (walker.nextNode()) {
        var t = walker.currentNode;
        if (t.nodeType === 3 && !t.nodeValue.trim()) continue;
        n++;
      }
      return n;
    }

    function flashAt(win, layer, target) {
      if (!flash.checked) return;
      var elt = target.nodeType === 1 ? target : target.parentElement;
      if (!elt || !elt.getBoundingClientRect) return;
      var r = elt.getBoundingClientRect();
      if (!r.width && !r.height) return;
      var box = win.document.createElement("div");
      box.className = "fn-flash";
      box.style.left = (r.left + win.scrollX - 3) + "px";
      box.style.top = (r.top + win.scrollY - 3) + "px";
      box.style.width = (r.width + 6) + "px";
      box.style.height = (r.height + 6) + "px";
      layer.appendChild(box);
      win.setTimeout(function () { box.remove(); }, 1300);
    }

    function addLog(text, cls) {
      var item = el("li", cls || null, text);
      log.insertBefore(item, log.firstChild);
      while (log.childNodes.length > 6) log.removeChild(log.lastChild);
    }

    hub.attach = function (win, doc) {
      hub.win = win;
      var app = doc.getElementById("app");
      var layer = doc.getElementById("fn-layer");
      hub.observer = new win.MutationObserver(function (records) {
        // what a reader would call one change: a text whose words changed
        // (the patcher may swap its node: counted once, by its element), an
        // attribute whose value really differs (Funicular re-sets some on
        // every render), an element that came or went
        var texts = new Set(), attrs = new Set(), added = 0, removed = 0;
        var touched = [];
        records.forEach(function (r) {
          if (r.type === "characterData") {
            if (r.oldValue === r.target.nodeValue) return;
            texts.add(r.target.parentNode || r.target);
            touched.push(r.target);
          } else if (r.type === "attributes") {
            var now = r.target.getAttribute(r.attributeName);
            if (now === r.oldValue) return;
            attrs.add(r.target);
            touched.push(r.target);
          } else {
            Array.prototype.forEach.call(r.addedNodes, function (n) {
              if (n.nodeType === 3) texts.add(r.target); else added++;
              touched.push(n);
            });
            Array.prototype.forEach.call(r.removedNodes, function (n) {
              if (n.nodeType === 3) texts.add(r.target); else removed++;
            });
            if (r.removedNodes.length && !r.addedNodes.length) touched.push(r.target);
          }
        });
        var text = texts.size;
        attrs = attrs.size;
        var total = countNodes(app);
        if (!hub.started) {
          hub.started = true;
          status.textContent = fill(L.mounted || "Started: %d nodes on the page.", total);
          touched.forEach(function (n) { flashAt(win, layer, n); });
          return;
        }
        if (!text && !attrs && !added && !removed) return;   // a render that changed nothing
        hub.updates++;
        var parts = [];
        if (text) parts.push(fill(L.text || "%d text", text));
        if (attrs) parts.push(fill(L.attrs || "%d attributes", attrs));
        if (added) parts.push(fill(L.added || "%d elements added", added));
        if (removed) parts.push(fill(L.removed || "%d elements removed", removed));
        var changed = text + attrs + added;
        var kept = Math.max(0, total - changed);
        var head = fill(L.update || "Update %d:", hub.updates);
        // a Japanese label ends in a full-width colon, which needs no space
        addLog(head + (/：$/.test(head) ? "" : " ") + parts.join(/：$/.test(head) ? "、" : ", ") +
               " – " + fill(L.kept || "%d nodes left alone", kept));
        touched.forEach(function (n) { flashAt(win, layer, n); });
      });
      hub.observer.observe(app, { subtree: true, childList: true, characterData: true, characterDataOldValue: true, attributes: true, attributeOldValue: true });
      // the frame is as tall as the app (same origin: its size can be read)
      if (win.ResizeObserver) {
        hub.resize = new win.ResizeObserver(function () {
          var h = Math.min(640, Math.max(60, doc.documentElement.scrollHeight));
          frame.style.height = h + "px";
        });
        hub.resize.observe(doc.body);
      }
      hub.timer = setTimeout(function () {
        if (!hub.started) status.textContent = L.slow || "Nothing shown yet - did the code call Funicular.start?";
      }, 8000);
    };

    function start() {
      if (hub.observer) hub.observer.disconnect();
      if (hub.resize) hub.resize.disconnect();
      clearTimeout(hub.timer);
      hub.started = false;
      hub.updates = 0;
      log.textContent = "";
      out.textContent = "";
      out.hidden = true;
      status.textContent = L.loading || "Starting PicoRuby …";
      frame.srcdoc = frameHtml(id, document.documentElement.lang || "en");
    }
    restart.addEventListener("click", start);
    start();
    return id;
  };

  // a cell that runs again replaces its preview: the old PicoRuby goes
  // with its iframe
  window.chunkyFunicularDispose = function (node) {
    if (!node) return;
    node.querySelectorAll("iframe.funicular-frame").forEach(function (f) {
      f.srcdoc = "";
      f.remove();
    });
  };
})();
