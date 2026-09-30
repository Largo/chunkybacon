// The UI for storage.js: the progress dialog behind the header button, and
// the workshop's file panel. main.rb renders the workshop's skeleton and
// runs the programs; this fills in the files around its editor (cell 0) and
// keeps them saved. Every name the learner or a folder brings in goes into
// the page as text, never as HTML.
(function () {
  "use strict";

  var S = window.ChunkyStorage;
  var UI = JSON.parse(window.LESSONS_JSON).ui;
  var OPEN_KEY = "chunkyui_ws_open";   // no "chunky_": a view setting, not progress

  function lang() { var l = document.documentElement.lang; return UI[l] ? l : "de"; }
  function t(key, arg) {
    var text = (UI[lang()] && UI[lang()][key]) || UI.de[key] || key;
    return arg === undefined ? text : text.replace("%s", arg);
  }

  function el(tag, props, children) {
    var node = document.createElement(tag);
    Object.keys(props || {}).forEach(function (k) {
      if (k === "on") {
        Object.keys(props.on).forEach(function (type) { node.addEventListener(type, props.on[type]); });
      } else if (k in node) {
        node[k] = props[k];
      } else {
        node.setAttribute(k, props[k]);
      }
    });
    (children || []).forEach(function (c) {
      if (c) node.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    });
    return node;
  }

  // replaceChildren, skipping the parts left out (null)
  function fill(node, children) {
    node.replaceChildren.apply(node, children.filter(Boolean));
  }

  function storageGet(key) { try { return localStorage.getItem(key); } catch (e) { return null; } }
  function storageSet(key, value) { try { localStorage.setItem(key, value); } catch (e) { /* view setting only */ } }

  function download(name, text) {
    var url = URL.createObjectURL(new Blob([text], { type: "text/plain;charset=utf-8" }));
    var a = el("a", { href: url, download: name.split("/").pop() });
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 10000);
  }

  // ---------- the progress dialog ----------

  var button = document.getElementById("progressBtn");
  var dialog = document.getElementById("progressDialog");
  var message = null;   // [text, "ok" | "error"] after an action

  function clock(date) {
    var locale = { de: "de-CH", en: "en-GB", ja: "ja-JP" }[lang()] || "de-CH";
    return date.toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" });
  }

  function renderButton() {
    document.getElementById("progressLabel").textContent = t("progressButton");
    button.setAttribute("aria-label", t("progressButton"));
    var state = S.state();
    button.classList.toggle("is-connected", state === "folder" && !S.error());
    button.classList.toggle("needs-attention", state === "locked" || !!S.error());
  }

  function act(promise, okText) {
    promise.then(function () {
      message = okText ? [okText, "ok"] : null;
      renderDialog();
    }, function (e) {
      // closing the folder picker is not an error
      message = e && e.name === "AbortError" ? null : [t("folderError", (e && e.message) || e), "error"];
      renderDialog();
    });
  }

  function folderSection() {
    if (!S.supported) return [el("p", {}, [t("folderUnsupported")])];
    var state = S.state(), name = S.folderName(), out = [el("h3", {}, [t("folderTitle")])];
    if (state === "none") {
      out.push(el("p", {}, [t("folderExplain")]));
      out.push(el("div", { className: "pd-actions" }, [
        el("button", { type: "button", className: "pd-primary", on: { click: function () { act(S.connectFolder()); } } }, [t("folderChoose")])
      ]));
    } else if (state === "locked") {
      out.push(el("p", {}, [t("folderResumeNote")]));
      out.push(el("div", { className: "pd-actions" }, [
        el("button", { type: "button", className: "pd-primary", on: { click: function () { act(S.resumeFolder()); } } }, [t("folderResume", name)]),
        el("button", { type: "button", className: "pd-secondary", on: { click: function () { act(S.disconnectFolder()); } } }, [t("folderDisconnect")])
      ]));
    } else {
      var saved = S.savedAt();
      out.push(el("p", { className: "pd-connected" }, [
        "📁 " + t("folderConnected", name) + (saved ? " " + t("folderSavedAt", clock(saved)) : "")
      ]));
      out.push(el("div", { className: "pd-actions" }, [
        el("button", { type: "button", className: "pd-secondary", on: { click: function () { act(S.disconnectFolder()); } } }, [t("folderDisconnect")])
      ]));
    }
    if (S.error()) out.push(el("p", { className: "pd-error" }, [t("folderError", S.error())]));
    return out;
  }

  function fileSection() {
    var input = el("input", { type: "file", accept: ".json,application/json", hidden: true, on: {
      change: function () {
        var file = input.files[0];
        if (!file) return;
        S.loadProgressFile(file).then(function (changed) {
          message = [t(changed ? "fileLoaded" : "fileUnchanged"), "ok"];
          renderDialog();
        }, function () {
          message = [t("fileInvalid"), "error"];
          renderDialog();
        });
      }
    } });
    return [
      el("h3", {}, [t("fileTitle")]),
      el("p", {}, [t("fileExplain")]),
      el("div", { className: "pd-actions" }, [
        el("button", { type: "button", className: "pd-secondary", on: { click: function () { S.downloadProgress(); } } }, [t("fileDownload")]),
        el("button", { type: "button", className: "pd-secondary", on: { click: function () { input.click(); } } }, [t("fileLoad")]),
        input
      ])
    ];
  }

  function renderDialog() {
    if (!dialog.open) return;
    var close = el("button", { type: "button", className: "pd-close", "aria-label": t("close"), title: t("close"),
      on: { click: function () { dialog.close(); } } }, ["×"]);
    fill(dialog, [
      el("div", { className: "pd-head" }, [el("h2", { id: "progressTitle" }, [t("progressTitle")]), close]),
      el("p", { className: "pd-intro" }, [t("progressIntro")]),
      el("section", {}, folderSection()),
      el("section", {}, fileSection()),
      el("p", { className: "pd-message" + (message ? " is-" + message[1] : ""), role: "status" }, [message ? message[0] : ""])
    ]);
  }

  button.addEventListener("click", function () {
    message = null;
    dialog.showModal();
    renderDialog();
  });
  // a click on the backdrop closes it, like Escape
  dialog.addEventListener("click", function (e) { if (e.target === dialog) dialog.close(); });

  // ---------- the workshop's file panel ----------

  var ws = { open: null, editor: null, dirty: false, timer: null, creating: false, nameError: "", stdin: "" };

  function isRuby(path) { return /\.rb$|^(Gemfile|Rakefile)$/.test(path.split("/").pop()); }

  function preferred(list) {
    var want = storageGet(OPEN_KEY);
    if (want && list.indexOf(want) >= 0) return want;
    if (list.indexOf("main.rb") >= 0) return "main.rb";
    return list.filter(isRuby)[0] || list[0] || null;
  }

  function ensureStarter() {
    if (S.files.list().length === 0) S.files.write("main.rb", t("wsStarter"));
  }

  function flushSave() {
    clearTimeout(ws.timer);
    if (!ws.dirty || !ws.open || !ws.editor) return;
    ws.dirty = false;
    S.files.write(ws.open, ws.editor.getValue());
  }

  function openFile(path) {
    flushSave();
    ws.open = path;
    if (!path || !ws.editor) return renderFiles();
    storageSet(OPEN_KEY, path);
    var text = S.files.read(path);
    ws.editor.setValue(text === null ? "" : text);
    ws.editor.setOption("mode", isRuby(path) ? "text/x-ruby" : "text/plain");
    ws.editor.clearHistory();
    var tab = document.getElementById("wsTab");
    if (tab) tab.textContent = path;
    var run = document.querySelector('.run-cell[data-idx="0"]');
    if (run) {
      run.disabled = !isRuby(path);
      run.title = isRuby(path) ? "" : t("wsNotRuby");
    }
    renderFiles();
  }

  function validName(path) {
    if (!path || path.length > 80 || path === S.PROGRESS_FILE) return false;
    if (!/\.[A-Za-z0-9]+$|^(Gemfile|Rakefile)$/.test(path.split("/").pop())) return false;
    return path.split("/").every(function (part) { return /^[A-Za-z0-9_äöüÄÖÜ][A-Za-z0-9_.\-äöüÄÖÜ]*$/.test(part); });
  }

  function createFile(raw) {
    var path = raw.trim();
    if (path && !/\.[^\/]+$/.test(path)) path += ".rb";
    if (!validName(path)) { ws.nameError = t("wsBadName"); return renderFiles(); }
    if (S.files.read(path) !== null) { ws.nameError = t("wsExists", path); return renderFiles(); }
    ws.creating = false;
    ws.nameError = "";
    S.files.write(path, "");
    openFile(path);
    if (ws.editor) ws.editor.focus();
  }

  function removeFile(path) {
    if (!window.confirm(t("wsDeleteConfirm", path))) return;
    if (path === ws.open) { ws.dirty = false; clearTimeout(ws.timer); }
    S.files.remove(path);
    if (path === ws.open) {
      ensureStarter();
      openFile(preferred(S.files.list()));
    } else {
      renderFiles();
    }
  }

  function upload(fileList) {
    var picked = Array.prototype.slice.call(fileList).filter(function (f) { return f.size <= 1000000 && validName(f.name); });
    Promise.all(picked.map(function (f) {
      return f.text().then(function (text) { return S.files.write(f.name, text).then(function () { return f.name; }); });
    })).then(function (names) {
      ws.nameError = picked.length < fileList.length ? t("wsBadName") : "";
      if (names.length) openFile(names[0]); else renderFiles();
    });
  }

  function renderFiles() {
    var box = document.getElementById("wsFiles");
    if (!box) return;
    var state = S.state(), list = S.files.list();
    var where = S.files.kind() === "folder" ? "📁 " + t("wsInFolder", S.folderName()) : t("wsInBrowser");
    var items = list.map(function (path) {
      return el("li", { className: path === ws.open ? "is-open" : "" }, [
        el("button", { type: "button", className: "ws-file", "aria-current": path === ws.open ? "true" : "false",
          on: { click: function () { if (path !== ws.open) openFile(path); } } }, [path]),
        el("button", { type: "button", className: "ws-del", "aria-label": t("wsDelete", path), title: t("wsDelete", path),
          on: { click: function () { removeFile(path); } } }, ["×"])
      ]);
    });
    var create;
    if (ws.creating) {
      var input = el("input", { type: "text", className: "ws-newname", placeholder: "name.rb", spellcheck: false,
        "aria-label": t("wsNewFile"), on: { keydown: function (e) {
          if (e.key === "Enter") { e.preventDefault(); createFile(input.value); }
          if (e.key === "Escape") { ws.creating = false; ws.nameError = ""; renderFiles(); }
        } } });
      create = input;
      setTimeout(function () { input.focus(); }, 0);
    } else {
      create = el("button", { type: "button", className: "ws-action", on: { click: function () { ws.creating = true; renderFiles(); } } }, [t("wsNewFile")]);
    }
    var picker = el("input", { type: "file", multiple: true, hidden: true, accept: ".rb,.txt,.csv,.tsv,.json,.md,.yml,.yaml,.erb,.html,.css,.xml",
      on: { change: function () { upload(picker.files); } } });
    fill(box, [
      el("h3", {}, [t("wsFiles")]),
      el("p", { className: "ws-where" }, [where]),
      state === "locked" ? el("p", { className: "ws-locked" }, [
        t("wsLocked", S.folderName()) + " ",
        el("button", { type: "button", className: "ws-action", on: { click: function () { S.resumeFolder().catch(function () {}); } } }, [t("wsUnlock")])
      ]) : null,
      el("ul", { className: "ws-list" }, items),
      create,
      ws.nameError ? el("p", { className: "ws-error", role: "alert" }, [ws.nameError]) : null,
      el("div", { className: "ws-actions" }, [
        el("button", { type: "button", className: "ws-action", on: { click: function () { picker.click(); } } }, [t("wsUpload")]),
        el("button", { type: "button", className: "ws-action", disabled: !ws.open, on: { click: function () {
          flushSave();
          if (ws.open) download(ws.open, S.files.read(ws.open) || "");
        } } }, [t("wsDownload")]),
        picker
      ])
    ]);
  }

  function renderStdin() {
    var box = document.getElementById("wsStdinBox");
    if (!box) return;
    var area = el("textarea", { id: "wsStdin", rows: 3, spellcheck: false, placeholder: t("wsStdinHint"), value: ws.stdin,
      on: { input: function () { ws.stdin = area.value; } } });
    box.replaceChildren(el("details", { open: ws.stdin !== "" }, [el("summary", {}, [t("wsStdin")]), area]));
  }

  // main.rb, after rendering the workshop and creating its editor
  window.workshopMount = function () {
    flushSave();
    ws.editor = window.cellEditors[0];
    ws.creating = false;
    ws.nameError = "";
    ensureStarter();
    ws.editor.on("change", function (cm, change) {
      if (change.origin === "setValue") return;
      ws.dirty = true;
      clearTimeout(ws.timer);
      ws.timer = setTimeout(flushSave, 500);
    });
    renderStdin();
    openFile(preferred(S.files.list()));
  };

  // what main.rb asks for while it runs a program
  window.workshopOpenPath = function () { return ws.open || ""; };
  window.workshopStdin = function () { return ws.stdin; };
  window.workspaceSnapshot = function () { return JSON.stringify(S.files.snapshot()); };
  // a file the program wrote; the one in the editor shows the new text
  window.workspaceWrite = function (path, text) {
    if (path === ws.open && ws.editor) {
      ws.dirty = false;
      clearTimeout(ws.timer);
      ws.editor.setValue(text);
    }
    S.files.write(path, text);
  };
  window.workspaceDelete = function (path) { S.files.remove(path); };
  // a run saves the file in the editor, like any IDE (unless the program
  // itself just wrote that file, which workspaceWrite put in the editor)
  window.workshopAfterRun = function () {
    clearTimeout(ws.timer);
    ws.dirty = false;
    if (ws.open && ws.editor && S.files.read(ws.open) !== ws.editor.getValue()) {
      S.files.write(ws.open, ws.editor.getValue());
    }
    renderFiles();
  };

  // the folder came or went, or its files changed
  S.on("workspace", function () {
    if (!document.getElementById("wsFiles") || !ws.editor) return;
    ensureStarter();
    var list = S.files.list();
    if (!ws.open || list.indexOf(ws.open) < 0) return openFile(preferred(list));
    if (!ws.dirty) {
      var text = S.files.read(ws.open);
      if (text !== null && text !== ws.editor.getValue()) ws.editor.setValue(text);
    }
    renderFiles();
  });
  S.on("status", function () {
    renderButton();
    renderDialog();
    renderFiles();
  });

  // files edited in another program come in when the tab gets focus back
  window.addEventListener("focus", function () {
    if (document.getElementById("wsFiles")) S.files.refresh();
  });

  // main.rb sets <html lang> on every render, so a language switch shows here
  new MutationObserver(function () {
    renderButton();
    renderDialog();
  }).observe(document.documentElement, { attributes: true, attributeFilter: ["lang"] });

  renderButton();
})();
