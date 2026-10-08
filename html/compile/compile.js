// "📦 Program": a cell's Ruby as a program for Windows or Linux, built in
// this browser tab. Spinel (Matz's Ruby-to-C compiler) and clang/lld, all
// compiled to WebAssembly, run in compile/worker.js; nothing is sent
// anywhere. The toolchain (compile/toolchain/, about 45 MB, built by
// tools/compile/build.sh) is optional: without compile/toolchain/ready.json
// no button appears. Plain JS next to the PicoRuby shell: it adds a button
// to each cell's toolbar as lessons are drawn.
(function () {
  "use strict";

  var TEXT = {
    de: {
      button: "📦 Programm", title: "Diesen Code als eigenständiges Programm bauen (Spinel)",
      win: "Windows (.exe)", linux: "Linux (x86_64)",
      intro: "Baut aus dem Code ein Programm, das ohne Ruby läuft – hier im Browser, nichts wird hochgeladen.",
      first: "Beim ersten Mal lädt der Compiler (etwa 45 MB) – danach ist er im Cache.",
      translate: "Ruby wird zu C übersetzt …", fetch: "Lade Compiler …", compile: "C wird kompiliert …", link: "Programm wird gelinkt …",
      done: "Fertig: ", error: "Das ging nicht:", note: "Spinel kennt nur einen Teil von Ruby, und die Hilfen der Seite (show_image, show_irb …) gibt es im Programm nicht."
    },
    en: {
      button: "📦 Program", title: "Build this code as a standalone program (Spinel)",
      win: "Windows (.exe)", linux: "Linux (x86_64)",
      intro: "Turns the code into a program that runs without Ruby - right here in the browser, nothing is uploaded.",
      first: "The first time it loads the compiler (about 45 MB) - after that it is cached.",
      translate: "Translating Ruby to C …", fetch: "Loading the compiler …", compile: "Compiling the C …", link: "Linking the program …",
      done: "Done: ", error: "That did not work:", note: "Spinel supports only part of Ruby, and the page's helpers (show_image, show_irb …) do not exist in the program."
    },
    ja: {
      button: "📦 プログラム", title: "このコードを単体のプログラムとしてビルド（Spinel）",
      win: "Windows (.exe)", linux: "Linux (x86_64)",
      intro: "Ruby なしで動くプログラムにします。ブラウザの中で完結し、何も送信されません。",
      first: "初回はコンパイラ（約 45 MB）を読み込みます。以降はキャッシュされます。",
      translate: "Ruby を C に変換中 …", fetch: "コンパイラを読み込み中 …", compile: "C をコンパイル中 …", link: "リンク中 …",
      done: "完成：", error: "うまくいきませんでした：", note: "Spinel は Ruby の一部だけに対応しています。このページの補助（show_image、show_irb など）はプログラムでは使えません。"
    }
  };
  function t() { return TEXT[document.documentElement.lang] || TEXT.en; }

  var worker = null, job = 0, busy = null, available = false;

  function startWorker() {
    if (worker) return worker;
    worker = new Worker("compile/worker.js", { type: "module" });
    worker.onmessage = function (e) {
      var d = e.data;
      if (!busy) return;
      if (d.type === "log") {
        busy.status.textContent = t()[d.key === "loaded" ? "fetch" : d.key] || "";
      } else if (d.type === "done") {
        finish(busy, d);
      } else if (d.type === "error") {
        fail(busy, d.m);
      }
    };
    worker.onerror = function (e) { if (busy) fail(busy, e.message || "worker error"); };
    return worker;
  }

  function release(panel) { busy = null; panel.el.classList.remove("busy"); }

  function finish(panel, d) {
    var name = d.target === "win" ? "programm.exe" : "programm";
    if (document.documentElement.lang === "en") name = d.target === "win" ? "program.exe" : "program";
    var url = URL.createObjectURL(new Blob([d.bin], { type: "application/octet-stream" }));
    var a = document.createElement("a");
    a.href = url; a.download = name;
    a.textContent = name + " (" + Math.round(d.bin.length / 1024) + " KB)";
    panel.status.textContent = t().done;
    panel.status.appendChild(a);
    panel.detail.textContent = "";
    release(panel);
    a.click();
  }

  function fail(panel, message) {
    panel.status.textContent = t().error;
    panel.detail.textContent = message;
    // a crashed worker is replaced on the next try
    worker.terminate(); worker = null;
    release(panel);
  }

  function build(panel, target) {
    if (busy) return;
    var code = typeof window.getCellCode === "function" ? window.getCellCode(panel.idx) : "";
    if (!code.trim()) return;
    busy = panel;
    panel.el.classList.add("busy");
    panel.detail.textContent = "";
    panel.status.textContent = t().fetch;
    startWorker().postMessage({ ruby: code, target: target, id: ++job });
  }

  function makePanel(idx, toolbar) {
    var el = document.createElement("div");
    el.className = "compile-panel";
    el.hidden = true;
    var x = t();
    el.innerHTML =
      '<p class="compile-intro"></p>' +
      '<div class="compile-targets"><button type="button" data-target="win"></button><button type="button" data-target="linux"></button></div>' +
      '<p class="compile-status" role="status"></p><pre class="compile-detail"></pre>' +
      '<p class="compile-note"></p>';
    el.querySelector(".compile-intro").textContent = x.intro + " " + x.first;
    el.querySelector('[data-target="win"]').textContent = x.win;
    el.querySelector('[data-target="linux"]').textContent = x.linux;
    el.querySelector(".compile-note").textContent = x.note;
    var panel = { idx: idx, el: el, status: el.querySelector(".compile-status"), detail: el.querySelector(".compile-detail") };
    el.addEventListener("click", function (e) {
      var target = e.target.getAttribute && e.target.getAttribute("data-target");
      if (target) build(panel, target);
    });
    toolbar.parentNode.insertBefore(el, toolbar.nextSibling);
    return panel;
  }

  function decorate(root) {
    if (!available) return;
    root.querySelectorAll(".cell-toolbar").forEach(function (toolbar) {
      if (toolbar.querySelector(".compile-cell")) return;
      var run = toolbar.querySelector(".run-cell");
      if (!run) return;
      var idx = run.getAttribute("data-idx");
      var button = document.createElement("button");
      button.type = "button";
      button.className = "compile-cell";
      button.textContent = t().button;
      button.title = t().title;
      var panel = null;
      button.addEventListener("click", function () {
        if (!panel) panel = makePanel(idx, toolbar);
        panel.el.hidden = !panel.el.hidden;
        button.setAttribute("aria-expanded", String(!panel.el.hidden));
      });
      toolbar.insertBefore(button, run);
    });
  }

  function watch() {
    var body = document.getElementById("lessonBody");
    if (!body) return;
    decorate(body);
    new MutationObserver(function () { decorate(body); }).observe(body, { childList: true });
  }

  // the toolchain is built apart (tools/compile/build.sh); no ready.json, no button
  fetch("compile/toolchain/ready.json", { cache: "no-cache" }).then(function (r) {
    if (!r.ok) return;
    available = true;
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", watch); else watch();
  }).catch(function () {});
})();
