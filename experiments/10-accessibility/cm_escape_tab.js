// Prototype of the proposed CodeMirror keyboard fix (NOTES.md, fix 1), as it
// would go into window.initCell in index.html. Applied here to editors that
// already exist, so verify_fixes.mjs can try it on the real page.
//
// - Tab still indents (what people writing code expect), but Escape arms
//   "leave mode": the next Tab / Shift+Tab is left to the browser, which
//   moves focus out of the editor (the pattern CodeMirror 6 uses).
//   CodeMirror.Pass would not do: it falls through to the default keymap,
//   which indents again; e.codemirrorIgnore makes CodeMirror skip the key.
// - The editor's hidden textarea gets a name and a description.
// - .CodeMirror-focused gets a visible focus ring (CSS, see NOTES.md).
window.chunkyEditorKeys = function (cm, label, hint) {
  var leave = false;
  cm.on("keydown", function (cm, e) {
    if (e.key === "Escape") { leave = true; return; }
    if (e.key === "Tab" && leave) { e.codemirrorIgnore = true; leave = false; return; }
    if (e.key !== "Shift") leave = false;
  });
  cm.on("blur", function () { leave = false; });
  cm.setOption("screenReaderLabel", label);
  if (hint) {
    var id = "cm-hint-" + Math.random().toString(36).slice(2);
    var p = document.createElement("span");
    p.id = id; p.hidden = true; p.textContent = hint;
    cm.getWrapperElement().appendChild(p);
    cm.getInputField().setAttribute("aria-describedby", id);
  }
};
