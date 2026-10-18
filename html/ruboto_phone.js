// The phone of the Ruboto lesson ("android": true, docs/HANDOVER.md §6u):
// draws what the simulated Android in the JRuby worker shows, and sends the
// learner's taps back to it. Plain JS, like pico_board.js; loaded by
// window.ensureRubotoPhone (index.html) when the lesson opens.
//
// The worker owns the phone (ruboto_sim.rb, the Java stand-ins in jruby.js);
// this file only draws its snapshots: the activity's view tree (LinearLayout
// as a flexbox, TextView, Button ... at 1 dp = 1 CSS px), the app bar and its
// menu, a dialog, toasts, the home screen, the "has stopped" dialog, and
// logcat beside it. Every input - a tap, a key, Back, Home, a rotation, a
// tick of the phone's clock - goes to the worker as one event
// (chunkyJRuby.phone) and comes back as a new snapshot ("chunky:phone").
//
//   chunkyRubotoPhone.mount(idx, json)   main.rb: a cell started an app; its
//                                        phone is the live one from now on
//   chunkyRubotoPhone.stale(reason)      the worker's phone is gone (a reset,
//                                        a stopped worker): every phone says so
//
// Only one phone is live: the worker has one. A cell run later makes the
// phones of the cells before it stale ("▶ runs this app again").
(function () {
  "use strict";

  var TEXT = {
    de: { back: "Zurück", home: "Startbildschirm", recents: "Letzte Apps", rotate: "⟳ Drehen", rotateTitle: "Das Handy drehen (Hoch- und Querformat)",
          logcat: "Logcat", clear: "Leeren", badge: "Simuliertes Android 14 (API 34) · JRuby", stopped: "„%s“ wurde beendet",
          closeApp: "App schließen", openAgain: "App wieder öffnen", stale: "Dieses Handy zeigt nicht mehr den aktuellen Stand – ein anderer Lauf hat eine neue App gestartet. ▶ startet diese wieder.",
          workerGone: "JRuby wurde beendet – ▶ startet die App wieder.", more: "Weitere Optionen", empty: "(keine Zeilen)",
          noApp: "Keine App" },
    en: { back: "Back", home: "Home", recents: "Recent apps", rotate: "⟳ Rotate", rotateTitle: "Rotate the phone (portrait and landscape)",
          logcat: "Logcat", clear: "Clear", badge: "Simulated Android 14 (API 34) · JRuby", stopped: "%s has stopped",
          closeApp: "Close app", openAgain: "Open app again", stale: "This phone is out of date – another run started a new app. ▶ starts this one again.",
          workerGone: "JRuby was stopped – ▶ starts the app again.", more: "More options", empty: "(no lines)",
          noApp: "No app" },
    ja: { back: "戻る", home: "ホーム", recents: "最近のアプリ", rotate: "⟳ 回転", rotateTitle: "スマホを回転（縦向き・横向き）",
          logcat: "Logcat", clear: "クリア", badge: "シミュレーションのAndroid 14（API 34）・JRuby", stopped: "「%s」が停止しました",
          closeApp: "アプリを閉じる", openAgain: "アプリをもう一度開く", stale: "このスマホは最新ではありません。別の実行が新しいアプリを起動しました。▶でこのアプリをもう一度起動します。",
          workerGone: "JRubyが停止しました。▶でアプリをもう一度起動します。", more: "その他のオプション", empty: "（行がありません）",
          noApp: "アプリなし" }
  };
  var DRAWABLES = {
    chunky: "assets/chunky.svg",
    saturn_v: "assets/ruboto/drawable/saturn_v.jpg",
    earthrise: "assets/ruboto/drawable/earthrise.jpg",
    moonwalk: "assets/ruboto/drawable/moonwalk.jpg",
    blue_marble: "assets/ruboto/drawable/blue_marble.jpg",
    aurora: "assets/ruboto/drawable/aurora.jpg",
    hurricane: "assets/ruboto/drawable/hurricane.jpg"
  };
  var LOG_MAX = 400;
  var SCREEN = { portrait: [360, 640], landscape: [640, 360] };

  var live = null;   // the live phone: {idx, slot, state, ...}

  function lang() {
    var l = (document.documentElement.lang || "de").slice(0, 2);
    return TEXT[l] ? l : "de";
  }
  function t(key) { return TEXT[lang()][key]; }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
  }

  // ARGB int (unsigned) -> CSS
  function color(argb) {
    var a = Math.floor(argb / 16777216) & 255;
    var r = (argb >> 16) & 255, g = (argb >> 8) & 255, b = argb & 255;
    return "rgba(" + r + "," + g + "," + b + "," + (a / 255).toFixed(3) + ")";
  }

  // Android's Gravity: the horizontal and the vertical part
  function hgrav(g) {
    if (g === undefined || g < 0) return null;
    var h = g & 7;
    return h === 1 ? "center" : h === 5 ? "end" : h === 7 ? "stretch" : h === 3 ? "start" : null;
  }
  function vgrav(g) {
    if (g === undefined || g < 0) return null;
    var v = g & 0x70;
    return v === 0x10 ? "center" : v === 0x50 ? "end" : v === 0x70 ? "stretch" : v === 0x30 ? "start" : null;
  }
  var JUSTIFY = { start: "flex-start", center: "center", end: "flex-end", stretch: "flex-start" };
  var ALIGN = { start: "flex-start", center: "center", end: "flex-end", stretch: "stretch" };

  // ---------- the view tree ----------

  function build(view, phone, parent) {
    var e;
    switch (view.type) {
      case "LinearLayout":
        e = el("div", "rp-v rp-linear is-" + view.orientation);
        var horizontal = view.orientation === "horizontal";
        var main = horizontal ? hgrav(view.gravity) : vgrav(view.gravity);
        var cross = horizontal ? vgrav(view.gravity) : hgrav(view.gravity);
        if (main) e.style.justifyContent = JUSTIFY[main];
        e.style.alignItems = cross && cross !== "stretch" ? ALIGN[cross] : "flex-start";
        children(view, e, phone);
        break;
      case "FrameLayout":
      case "ScrollView":
      case "ViewGroup":
        e = el("div", "rp-v rp-frame" + (view.type === "ScrollView" ? " rp-scroll" : ""));
        children(view, e, phone);
        break;
      case "Button":
        e = el("button", "rp-v rp-button", view.text);
        e.type = "button";
        textStyle(e, view, true);
        break;
      case "EditText":
        var multi = view.inputType & 0x20000;
        e = el(multi ? "textarea" : "input", "rp-v rp-edit");
        if (!multi) {
          var cls = view.inputType & 15;
          e.type = (view.inputType & 0x80) ? "password" : "text";
          if (cls === 2) e.inputMode = (view.inputType & 0x2000) ? "decimal" : "numeric";
          if (cls === 3) e.inputMode = "tel";
        }
        e.value = view.text || "";
        if (view.hint) e.placeholder = view.hint;
        textStyle(e, view, false);
        e.setAttribute("data-sim", view.sim);
        var timer = null;
        e.addEventListener("input", function () {
          clearTimeout(timer);
          var value = e.value;
          timer = setTimeout(function () { phone.send({ action: "text", sim: view.sim, text: value }); }, 200);
        });
        break;
      case "CheckBox":
      case "Switch":
        e = el("label", "rp-v rp-check" + (view.type === "Switch" ? " is-switch" : ""));
        var box = el("input");
        box.type = "checkbox";
        box.checked = !!view.checked;
        if (view.type === "Switch") box.setAttribute("role", "switch");
        if (view.enabled === false) box.disabled = true;
        box.addEventListener("click", function (event) {
          event.preventDefault();   // the app decides; the snapshot draws it
          phone.send({ action: "click", sim: view.sim });
        });
        e.appendChild(box);
        e.appendChild(el("span", "rp-check-text", view.text));
        textStyle(e, view, false);
        break;
      case "SeekBar":
        e = el("input", "rp-v rp-seek");
        e.type = "range";
        e.min = 0;
        e.max = view.max;
        e.value = view.progress;
        e.addEventListener("change", function () { phone.send({ action: "seek", sim: view.sim, value: Number(e.value) }); });
        break;
      case "ProgressBar":
        e = el("progress", "rp-v rp-progress");
        if (!view.indeterminate) { e.max = view.max; e.value = view.progress; }
        break;
      case "ImageView":
        // wrap_content: the picture's own height; otherwise it fills the box
        e = el("div", "rp-v rp-image" + ((view.layout || {}).height === -2 ? " is-wrap" : ""));
        if (view.drawable && DRAWABLES[view.drawable]) {
          var img = el("img");
          img.src = DRAWABLES[view.drawable];
          img.alt = view.drawable;
          img.draggable = false;
          var fit = { CENTER_CROP: "cover", FIT_XY: "fill", CENTER: "none", CENTER_INSIDE: "scale-down" }[view.scaleType] || "contain";
          img.style.objectFit = fit;
          if (view.scaleType === "FIT_START") img.style.objectPosition = "left top";
          if (view.scaleType === "FIT_END") img.style.objectPosition = "right bottom";
          e.appendChild(img);
        }
        break;
      case "ListView":
        e = el("div", "rp-v rp-list");
        e.setAttribute("role", "list");
        (view.items || []).forEach(function (item, i) {
          var row = el(view.itemClickable ? "button" : "div", "rp-row", item);
          row.setAttribute("role", "listitem");
          if (view.itemClickable) {
            row.type = "button";
            row.addEventListener("click", function () { phone.send({ action: "item", sim: view.sim, index: i }); });
          }
          e.appendChild(row);
        });
        break;
      case "Spinner":
        e = el("select", "rp-v rp-spinner");
        (view.items || []).forEach(function (item, i) {
          var option = el("option", null, item);
          option.value = i;
          if (i === view.selected) option.selected = true;
          e.appendChild(option);
        });
        e.addEventListener("change", function () { phone.send({ action: "select", sim: view.sim, index: Number(e.value) }); });
        break;
      case "TextView":
        e = el("div", "rp-v rp-text");
        var span = el("span", null, view.text);
        e.appendChild(span);
        textStyle(e, view, false);
        var v = vgrav(view.gravity);
        if (v && v !== "start") e.style.justifyContent = JUSTIFY[v];
        break;
      default:
        e = el("div", "rp-v rp-plain");
        if (view.children) children(view, e, phone);
    }
    common(e, view, phone, parent);
    return e;
  }

  function children(view, e, phone) {
    (view.children || []).forEach(function (child) { e.appendChild(build(child, phone, view)); });
  }

  function textStyle(e, view, button) {
    if (view.textSize) e.style.fontSize = view.textSize + "px";
    if (view.textColor !== undefined) e.style.color = color(view.textColor);
    if (view.font === "monospace") e.style.fontFamily = "ui-monospace, monospace";
    if (view.font === "serif") e.style.fontFamily = "Georgia, serif";
    if (view.bold) e.style.fontWeight = "700";
    if (view.italic) e.style.fontStyle = "italic";
    var h = hgrav(view.gravity);
    if (view.textAlignment === 4) h = "center";
    if (!button && h) e.style.textAlign = h === "end" ? "right" : h === "center" ? "center" : "left";
    if (view.maxLines === 1) e.classList.add("is-single");
  }

  // what every view has: its size in the parent, padding, margins, colours,
  // visibility, and a click
  function common(e, view, phone, parent) {
    e.setAttribute("data-sim", view.sim);
    var lp = view.layout || {};
    var horizontal = parent && parent.type === "LinearLayout" && parent.orientation === "horizontal";
    var linear = parent && parent.type === "LinearLayout";
    var w = lp.width, h = lp.height;
    if (!parent) {
      e.classList.add("rp-root");
    } else {
      size(e, "width", w, horizontal && linear, linear);
      size(e, "height", h, !horizontal && linear, linear);
      if (lp.weight > 0 && linear) {
        e.style.flex = lp.weight + " 1 0px";
        e.style[horizontal ? "minWidth" : "minHeight"] = "0";
      }
      if (lp.gravity !== undefined && lp.gravity >= 0) {
        var g = horizontal ? vgrav(lp.gravity) : hgrav(lp.gravity);
        if (linear && g) e.style.alignSelf = ALIGN[g];
        if (!linear) {
          var hg = hgrav(lp.gravity), vg = vgrav(lp.gravity);
          if (hg) e.style.justifySelf = hg === "stretch" ? "stretch" : hg;
          if (vg) e.style.alignSelf = vg;
        }
      }
      if (lp.margins) e.style.margin = lp.margins[1] + "px " + lp.margins[2] + "px " + lp.margins[3] + "px " + lp.margins[0] + "px";
    }
    if (view.padding) e.style.padding = view.padding[1] + "px " + view.padding[2] + "px " + view.padding[3] + "px " + view.padding[0] + "px";
    if (view.background !== undefined) e.style.background = color(view.background);
    if (view.alpha !== undefined) e.style.opacity = view.alpha;
    if (view.minHeight) e.style.minHeight = view.minHeight + "px";
    if (view.minWidth) e.style.minWidth = view.minWidth + "px";
    if (view.visibility === "gone") e.style.display = "none";
    if (view.visibility === "invisible") e.style.visibility = "hidden";
    if (view.enabled === false) {
      e.classList.add("is-disabled");
      if ("disabled" in e) e.disabled = true;
    }
    var clickable = view.clickable && view.type !== "CheckBox" && view.type !== "Switch";
    if (clickable && view.enabled !== false) {
      if (e.tagName !== "BUTTON") { e.setAttribute("role", "button"); e.tabIndex = 0; }
      e.classList.add("is-clickable");
      e.addEventListener("click", function (event) {
        event.stopPropagation();
        phone.send({ action: "click", sim: view.sim });
      });
      e.addEventListener("keydown", function (event) {
        if (e.tagName !== "BUTTON" && (event.key === "Enter" || event.key === " ")) {
          event.preventDefault();
          phone.send({ action: "click", sim: view.sim });
        }
      });
    }
    if (view.longClickable && view.enabled !== false) {
      e.addEventListener("contextmenu", function (event) {
        event.preventDefault();
        event.stopPropagation();
        phone.send({ action: "longclick", sim: view.sim });
      });
    }
  }

  // match_parent fills the parent, wrap_content fits the content, a number is dp
  function size(e, prop, value, mainAxis, linear) {
    if (value === undefined) return;
    if (value === -1) {
      if (!linear) { e.style[prop] = "100%"; return; }
      if (mainAxis) e.style.flex = "1 1 auto";
      else e.style.alignSelf = "stretch";
      e.style[prop === "width" ? "minWidth" : "minHeight"] = "0";
    } else if (value >= 0) {
      e.style[prop] = value + "px";
      e.style.flexShrink = "0";
      if (mainAxis && value === 0) e.style.flexBasis = "0px";
    }
  }

  // ---------- one phone ----------

  function Phone(idx, slot) {
    this.idx = idx;
    this.slot = slot;
    this.state = null;
    this.toasts = [];
    this.toastTimer = null;
    this.tickTimer = null;
    this.snapAt = 0;
    this.menuOpen = false;
    this.alive = true;
    this.frame();
  }

  Phone.prototype.frame = function () {
    var self = this;
    var slot = this.slot;
    slot.innerHTML = "";
    var bar = el("div", "rp-bar");
    var rotate = el("button", "rp-rotate", t("rotate"));
    rotate.type = "button";
    rotate.title = t("rotateTitle");
    rotate.addEventListener("click", function () { self.send({ action: "rotate" }); });
    bar.appendChild(rotate);
    bar.appendChild(el("span", "rp-badge", t("badge")));
    slot.appendChild(bar);

    var stage = el("div", "rp-stage");
    var holder = el("div", "rp-holder");
    var device = el("div", "rp-device is-portrait");
    var screen = el("div", "rp-screen");
    var status = el("div", "rp-status");
    status.appendChild(el("span", "rp-clock", "12:00"));
    status.appendChild(el("span", "rp-icons", "▴ ▮"));
    screen.appendChild(status);
    var body = el("div", "rp-body");
    screen.appendChild(body);
    var nav = el("div", "rp-nav");
    [["back", "◀", { action: "back" }], ["home", "●", { action: "home" }], ["recents", "■", null]].forEach(function (b) {
      var button = el("button", "rp-nav-" + b[0], b[1]);
      button.type = "button";
      button.setAttribute("aria-label", t(b[0]));
      button.title = t(b[0]);
      if (b[2]) button.addEventListener("click", function () { self.send(b[2]); });
      else button.disabled = true;
      nav.appendChild(button);
    });
    screen.appendChild(nav);
    device.appendChild(screen);
    holder.appendChild(device);
    stage.appendChild(holder);

    var logcat = el("div", "rp-logcat");
    var head = el("div", "rp-logcat-head");
    head.appendChild(el("span", "rp-logcat-title", t("logcat")));
    var clear = el("button", "rp-logcat-clear", t("clear"));
    clear.type = "button";
    clear.addEventListener("click", function () { self.lines.innerHTML = ""; });
    head.appendChild(clear);
    logcat.appendChild(head);
    this.lines = el("div", "rp-logcat-lines");
    this.lines.setAttribute("role", "log");
    logcat.appendChild(this.lines);
    stage.appendChild(logcat);
    slot.appendChild(stage);

    var note = el("div", "rp-note");
    note.hidden = true;
    slot.appendChild(note);

    this.device = device;
    this.holder = holder;
    this.body = body;
    this.clock = status.firstChild;
    this.note = note;
    this.rotateButton = rotate;
  };

  Phone.prototype.send = function (event) {
    if (!this.alive || live !== this || !window.chunkyJRuby) return;
    if (event.action !== "tick") this.menuOpen = false;
    window.chunkyJRuby.phone(event);
  };

  // a new snapshot from the worker (+all+: the whole log, as at the start)
  Phone.prototype.show = function (json, all) {
    var data;
    try { data = JSON.parse(json); } catch (e) { return; }
    this.state = data;
    this.snapAt = performance.now();
    var device = data.device || {};
    this.log(device.log || [], all);
    (device.toasts || []).forEach(function (toast) { this.toasts.push(toast); }, this);
    this.draw();
    this.nextToast();
    this.schedule();
  };

  Phone.prototype.draw = function () {
    var data = this.state;
    if (!data) return;
    var device = data.device || {};
    var orientation = device.orientation === "landscape" ? "landscape" : "portrait";
    this.device.className = "rp-device is-" + orientation;
    this.fit(orientation);
    var minutes = Math.floor((device.clock || 0) / 60000);
    this.clock.textContent = "12:" + String(minutes % 60).padStart(2, "0");

    // keep the caret where the learner types
    var focus = document.activeElement;
    var focusSim = focus && this.body.contains(focus) ? focus.getAttribute("data-sim") : null;
    var caret = focusSim && typeof focus.selectionStart === "number" ? focus.selectionStart : null;

    var body = this.body;
    body.innerHTML = "";
    var activity = !data.home && device.activity;
    if (activity) {
      body.appendChild(this.appBar(activity));
      var content = el("div", "rp-content" + (activity.dialogTheme ? " is-dialog-theme" : ""));
      if (activity.content) {
        var root = build(activity.content, this, null);
        if (activity.dialogTheme) {
          var card = el("div", "rp-dialog rp-dialog-activity");
          card.appendChild(root);
          content.appendChild(card);
        } else {
          content.appendChild(root);
        }
      }
      body.appendChild(content);
      if (this.menuOpen) body.appendChild(this.menuPopup(activity));
    } else {
      body.appendChild(this.homeScreen(data));
    }
    if (device.dialog) body.appendChild(this.dialog(device.dialog));
    if (device.crash) body.appendChild(this.crashDialog(device.crash));
    this.toastLayer = el("div", "rp-toasts");
    body.appendChild(this.toastLayer);
    if (this.toastShown) this.toastLayer.appendChild(this.toastShown);

    if (focusSim) {
      var again = body.querySelector('[data-sim="' + focusSim + '"]');
      if (again && again.focus) {
        again.focus();
        if (caret !== null && typeof again.setSelectionRange === "function") {
          var at = Math.min(caret, again.value.length);
          try { again.setSelectionRange(at, at); } catch (e) { /* not a text field */ }
        }
      }
    }
  };

  Phone.prototype.appBar = function (activity) {
    var self = this;
    var bar = el("div", "rp-appbar");
    if (activity.dialogTheme) bar.hidden = true;
    bar.appendChild(el("div", "rp-title", activity.title || (this.state && this.state.app) || ""));
    var menu = activity.menu || [];
    menu.filter(function (item) { return item.action; }).forEach(function (item) {
      var b = el("button", "rp-action", item.title);
      b.type = "button";
      if (item.enabled === false) b.disabled = true;
      b.addEventListener("click", function () { self.send({ action: "menu", index: item.index }); });
      bar.appendChild(b);
    });
    if (menu.some(function (item) { return !item.action; })) {
      var more = el("button", "rp-more", "⋮");
      more.type = "button";
      more.setAttribute("aria-label", t("more"));
      more.setAttribute("aria-expanded", this.menuOpen ? "true" : "false");
      more.addEventListener("click", function () { self.menuOpen = !self.menuOpen; self.draw(); });
      bar.appendChild(more);
    }
    return bar;
  };

  Phone.prototype.menuPopup = function (activity) {
    var self = this;
    var layer = el("div", "rp-menu-layer");
    layer.addEventListener("click", function () { self.menuOpen = false; self.draw(); });
    var popup = el("div", "rp-menu");
    popup.setAttribute("role", "menu");
    (activity.menu || []).filter(function (item) { return !item.action; }).forEach(function (item) {
      var b = el("button", "rp-menu-item", (item.checked === undefined ? "" : item.checked ? "☑ " : "☐ ") + item.title);
      b.type = "button";
      b.setAttribute("role", "menuitem");
      if (item.enabled === false) b.disabled = true;
      b.addEventListener("click", function (event) {
        event.stopPropagation();
        self.send({ action: "menu", index: item.index });
      });
      popup.appendChild(b);
    });
    layer.appendChild(popup);
    return layer;
  };

  Phone.prototype.dialog = function (d) {
    var self = this;
    var scrim = el("div", "rp-scrim");
    scrim.addEventListener("click", function (event) {
      if (event.target === scrim && d.cancelable) self.send({ action: "back" });
    });
    var box = el("div", "rp-dialog");
    box.setAttribute("role", "dialog");
    if (d.title) box.appendChild(el("div", "rp-dialog-title", d.title));
    if (d.message) box.appendChild(el("div", "rp-dialog-message", d.message));
    (d.items || []).forEach(function (item, i) {
      var b = el("button", "rp-dialog-item", item);
      b.type = "button";
      b.addEventListener("click", function () { self.send({ action: "dialog", which: i }); });
      box.appendChild(b);
    });
    if (d.view) box.appendChild(build(d.view, this, { type: "FrameLayout" }));
    var buttons = el("div", "rp-dialog-buttons");
    (d.buttons || []).forEach(function (button) {
      var b = el("button", "rp-dialog-button", button.text);
      b.type = "button";
      b.addEventListener("click", function () { self.send({ action: "dialog", which: button.which }); });
      buttons.appendChild(b);
    });
    if (d.buttons && d.buttons.length) box.appendChild(buttons);
    scrim.appendChild(box);
    return scrim;
  };

  Phone.prototype.crashDialog = function (label) {
    var self = this;
    var scrim = el("div", "rp-scrim");
    var box = el("div", "rp-dialog is-crash");
    box.setAttribute("role", "alertdialog");
    box.appendChild(el("div", "rp-dialog-title", t("stopped").replace("%s", label)));
    var again = el("button", "rp-dialog-item", "↻ " + t("openAgain"));
    again.type = "button";
    again.addEventListener("click", function () { self.send({ action: "close" }); self.send({ action: "launch" }); });
    var close = el("button", "rp-dialog-item", "✕ " + t("closeApp"));
    close.type = "button";
    close.addEventListener("click", function () { self.send({ action: "close" }); });
    box.appendChild(again);
    box.appendChild(close);
    scrim.appendChild(box);
    return scrim;
  };

  Phone.prototype.homeScreen = function (data) {
    var self = this;
    var home = el("div", "rp-home");
    var device = data.device || {};
    var minutes = Math.floor((device.clock || 0) / 60000);
    home.appendChild(el("div", "rp-home-clock", "12:" + String(minutes % 60).padStart(2, "0")));
    if (data.app) {
      var icon = el("button", "rp-app-icon");
      icon.type = "button";
      var img = el("img");
      img.src = DRAWABLES.chunky;
      img.alt = "";
      icon.appendChild(img);
      icon.appendChild(el("span", null, data.app));
      icon.addEventListener("click", function () { self.send({ action: "launch" }); });
      home.appendChild(icon);
    } else {
      home.appendChild(el("div", "rp-home-empty", t("noApp")));
    }
    return home;
  };

  // toasts one after another: 2 s short, 3.5 s long, as Android's
  Phone.prototype.nextToast = function () {
    var self = this;
    if (this.toastTimer || this.toasts.length === 0) return;
    var toast = this.toasts.shift();
    var e = el("div", "rp-toast", toast.text);
    e.setAttribute("role", "status");
    this.toastShown = e;
    if (this.toastLayer) this.toastLayer.appendChild(e);
    this.toastTimer = setTimeout(function () {
      self.toastTimer = null;
      if (self.toastShown && self.toastShown.parentNode) self.toastShown.parentNode.removeChild(self.toastShown);
      self.toastShown = null;
      self.nextToast();
    }, toast.long ? 3500 : 2000);
  };

  // the Runnables a Handler posted: the phone's clock goes on in real time
  Phone.prototype.schedule = function () {
    var self = this;
    clearTimeout(this.tickTimer);
    this.tickTimer = null;
    var device = (this.state && this.state.device) || {};
    if (!this.alive || live !== this || device.nextTimer === undefined || device.nextTimer < 0) return;
    var wait = Math.max(30, Math.min(device.nextTimer, 5000));
    this.tickTimer = setTimeout(function tick() {
      self.tickTimer = null;
      if (!self.alive || live !== self) return;
      if (!document.body.contains(self.slot)) { self.alive = false; return; }
      if (document.hidden || (window.chunkyJRuby && window.chunkyJRuby.busy())) {
        self.tickTimer = setTimeout(tick, 250);
        return;
      }
      self.send({ action: "tick", ms: Math.round(performance.now() - self.snapAt) });
    }, wait);
  };

  Phone.prototype.log = function (entries, all) {
    if (all) this.lines.innerHTML = "";
    var stick = this.lines.scrollTop + this.lines.clientHeight >= this.lines.scrollHeight - 8;
    entries.forEach(function (entry) {
      var level = entry[0], tag = entry[1], message = entry[2], ms = entry[3];
      var line = el("div", "rp-log is-" + level);
      line.appendChild(el("span", "rp-log-time", stamp(ms)));
      line.appendChild(el("span", "rp-log-level", level));
      line.appendChild(el("span", "rp-log-tag", tag + ":"));
      line.appendChild(el("span", "rp-log-msg", " " + message));
      this.lines.appendChild(line);
    }, this);
    while (this.lines.childNodes.length > LOG_MAX) this.lines.removeChild(this.lines.firstChild);
    if (stick || all) this.lines.scrollTop = this.lines.scrollHeight;
  };

  function stamp(ms) {
    var s = Math.floor(ms / 1000);
    return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0") + "." + String(ms % 1000).padStart(3, "0");
  }

  // the phone at 1 dp = 1 px, smaller when the column is narrower
  Phone.prototype.fit = function (orientation) {
    var size = SCREEN[orientation];
    var outerW = size[0] + 24, outerH = size[1] + 24 + 48 + 24;
    var style = getComputedStyle(this.slot);
    var avail = (this.slot.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)) || outerW;
    var scale = Math.min(1, (avail - 4) / outerW);
    this.device.style.transform = scale < 1 ? "scale(" + scale.toFixed(3) + ")" : "";
    this.holder.style.width = Math.round(outerW * scale) + "px";
    this.holder.style.height = Math.round(outerH * scale) + "px";
  };

  Phone.prototype.retire = function (message) {
    this.alive = false;
    clearTimeout(this.tickTimer);
    clearTimeout(this.toastTimer);
    this.toasts = [];
    this.slot.classList.add("is-stale");
    this.note.textContent = message;
    this.note.hidden = false;
  };

  // ---------- the page's side ----------

  var api = window.chunkyRubotoPhone = {
    mount: function (idx, json) {
      var out = document.getElementById("cell-out-" + idx);
      if (!out) return;
      if (live && live.slot !== null) live.retire(t("stale"));
      // the class body's value (=> :onCreate) says nothing next to the app
      var arrow = out.querySelector(".cell-result");
      if (arrow) arrow.parentNode.removeChild(arrow);
      var slot = el("div", "ruboto-slot");
      slot.id = "ruboto-slot-" + idx;
      out.appendChild(slot);
      live = new Phone(Number(idx), slot);
      live.show(String(json), true);
    },
    stale: function (reason) {
      if (live) live.retire(reason === "stopped" ? t("workerGone") : t("stale"));
      live = null;
    },
    debug: function () { return live; }
  };

  window.addEventListener("chunky:phone", function (event) {
    var d = event.detail || {};
    if (!live) return;
    if (d.status === "ok" && d.phone) live.show(d.phone, false);
    else if (d.status === "stopped" || d.status === "failed") api.stale("stopped");
  });
  window.addEventListener("resize", function () { if (live && live.state) live.draw(); });

  // calls made before this file had loaded (index.html's stand-in)
  var pending = window.chunkyRubotoPhonePending || [];
  window.chunkyRubotoPhonePending = null;
  pending.forEach(function (call) { api[call[0]].apply(api, call[1]); });
})();
