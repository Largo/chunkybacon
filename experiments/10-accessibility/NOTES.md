# 10 - Accessibility audit (keyboard, screen readers, contrast, motion)

Audited 2026-10-04 against branch `worktree-ideas`, dev server on port 18110,
Chromium from Playwright 1.62.1 (npx cache), axe-core 4.13.0 (installed into
this folder). Nothing outside this folder was changed. All fixes below are
**proposals** (diffs, not applied).

## Method

| script | what it does | evidence |
|---|---|---|
| `audit.mjs` | Loads the page per language (de/en/ja, `?lang=`), waits for the kernel, opens 6 lessons/pages by hash, **runs their cells** so the widgets exist (basics `hallo`, `irb`, `sinatra` = mini browser, `three` = WebGL, `rumale` = the letter, `werkstatt` = workshop), plus the progress dialog open and the sidebar drawer open on a 390x844 phone viewport. Injects axe-core, saves violations + "incomplete" results. | `out/axe-<lang>-<page>.json` (24 files), `out/axe-summary.json`, `out/audit-run.log`, `shots/<lang>-<page>.png` |
| `keyboard.mjs` | Scripted "manual" checks: a Tab walk through a lesson, what Tab/Escape/Shift+Tab do in an editor, where focus goes after Run / a lesson link / "next lesson" / the drawer / the dialog, live regions, `lang` of Japanese text, own contrast computation (axe gives up on most text because of the grid background image), `prefers-reduced-motion`, the IRB widget, the 3D canvas, reflow at 320 px. | `out/keyboard-run.log`, `out/keyboard.json`, `out/tab-walk-en-hallo.txt`, screenshots |
| `focus_shots.mjs` | What keyboard focus on an editor looks like. | `shots/en-editor-keyboard-focus.png` |
| `verify_fixes.mjs` + `cm_escape_tab.js` | Tries fix 1 (editor keyboard) on the live page by script injection. | `out/verify_fixes.json`, `shots/fix-editor-focus-ring.png` |
| `contrast_details.mjs`, `contrast_calc.mjs`, `lang_scan.mjs`, `show.mjs` | Group axe's contrast failures by colour pair; compute candidate colours; look for Japanese text in the de/en lessons (none found); print one axe file. | console |

Rerun (dev server on 18110 first): `npm install` here, then `node audit.mjs`
(~2 min), `node keyboard.mjs` (~3 min). `PLAYWRIGHT_DIR` overrides the
Playwright copy, `BASE` the URL.

axe results are identical across de/en/ja (same counts per page), so the
problems are structural, not translation-specific.

## What already works (keep it)

- Progress dialog: native `showModal`, focus goes in, Tab stays in, Escape
  closes and focus returns to the Progress button (`progress-dialog` PASS).
- `prefers-reduced-motion`: with `reduce`, **no** CSS animation runs, neither
  on the loading screen nor during a run/pass (`motion-reduce` INFO: `[]`).
  The CSS block at the end of app.css is complete.
- Drawer: Escape closes it and gives focus back to the toggle; a closed
  drawer is `visibility: hidden`, so it leaves the tab order; `aria-expanded`
  on the toggle and on group heads; `aria-current="page"` on the active lesson.
- `<html lang>` follows the language (also at `domcontentloaded`, via bridge.js).
- `:focus-visible` ring `#2f6db5`, 5.28:1 on paper; body text ink 18.5:1,
  ink-soft 7.5:1; ink on fox-orange buttons 6.1:1.
- Reflow: no horizontal scroll at 320 CSS px.
- The lessons' de/en texts contain no unmarked Japanese (`lang_scan.mjs`).

## Findings, by severity

### High - blocks keyboard or screen-reader users

**H1. CodeMirror cells are a keyboard trap, unnamed, and show no focus.**
(WCAG 2.1.2 No Keyboard Trap, 4.1.2 Name/Role/Value, 2.4.7 Focus Visible)
- Tab into a cell: Tab inserts indentation (and edits the learner's code,
  which also starts a live run), Shift+Tab re-indents, **Escape then Tab also
  stays** (`codemirror-trap` FAIL). Only the mouse gets you out. Every lesson
  has editors before its Run buttons, so a keyboard user cannot reach Run,
  Live, Reset, the bubble's "next lesson" link or the footer.
- The hidden textarea CodeMirror focuses has no name: axe `label` (critical)
  on every page, 1-7 nodes each. `fromTextArea` does not copy the textarea's
  `title="code"`; CodeMirror 5.65 has a `screenReaderLabel` option for it.
- Focus on an editor shows only a 1 px caret, no ring
  (`shots/en-editor-keyboard-focus.png`; the focused textarea is 1000x13 px
  offscreen with `outline: none`).
- Verified fix: Escape arms "leave mode", next Tab/Shift+Tab leaves
  (`out/verify_fixes.json`: Esc+Tab -> Live button, Esc+Shift+Tab -> language
  select; Tab alone still indents) + label + ring
  (`shots/fix-editor-focus-ring.png`). Note `CodeMirror.Pass` does **not**
  work for this (falls through to the default keymap, which indents);
  `e.codemirrorIgnore = true` in a `keydown` handler does. -> **Fix 1**

**H2. Results are never announced.** (WCAG 4.1.3 Status Messages)
No `aria-live`/`role=status` on `#cell-out-N`, on Chunky's bubble, the run
time, the IRB history or the mini browser (`output-announced`, `irb-widget`
FAIL). The only live region is `#kernelStatus`. A blind learner presses Run
and hears nothing - neither `=> 2`, nor the error, nor "passed, next lesson".
Making `.cell-out` itself live would be wrong: live runs rewrite it every
second while typing. -> **Fix 2** (one polite status line the shell writes
after an explicit run: output + Chunky's verdict).

**H3. Focus is dropped to `<body>` in four places.** (WCAG 2.4.3 Focus Order)
- Enter on Run: `button.disabled = true` (app.rb `start_cell_run`) blurs it;
  focus is on BODY during **and after** the run (`focus-after-run` FAIL). The
  next Tab starts at the top of the page again (56 stops away).
- Enter on a lesson link in the index: `render_nav` replaces the index with
  `innerHTML`, the focused link is gone (`focus-after-nav-link` FAIL).
- Enter on "next lesson" in the bubble: same (`focus-after-next-lesson`).
- Choosing a lesson in the phone drawer: drawer closes, focus BODY
  (`drawer-pick-lesson` FAIL); Alt+R also leaves focus on BODY.
-> **Fix 3** (give focus back to Run after a run) and **Fix 4** (after any
lesson change, focus the lesson's `<h2>`).

**H4. The mini browser leaks the app's CSS into the whole course.**
`navigate_browser` (main.rb) does `view.innerHTML = body`. Sinatra's 404 page
carries `<style>body { text-align:center; color:#888; font-size:22px }</style>`,
so after the Sinatra lesson's starter cell runs, **the entire page** - lesson
text, code, Chunky's bubble, the sidebar - turns grey, centred and 22 px
(`shots/en-sinatra.png`). axe: `color-contrast` 39 nodes (#888 on paper
3.54:1, on code-bg 3.15:1, on the fail bubble 2.95:1) and `image-alt`
critical (`<img src="/__sinatra__/404.png">`). Any app that ships a
`<style>` does this; it is a visual bug too, not only an a11y one. It persists
until the next lesson re-render. -> **Fix 5** (render into a shadow root).

### Medium

**M1. The phone drawer is not modal.** Opening it leaves focus on the toggle
(fine), Tab goes through the drawer, but after 53 stops it walks on to the
Progress button, the language select and the lesson **behind the scrim**,
invisible (`drawer-focus` FAIL, `shots/en-drawer-focus-leak.png`). No `inert`,
no `aria-modal`; screen readers can read the page behind. -> **Fix 6**

**M2. No skip link.** 56 Tab presses from the top of a lesson to its first
control (toggle, workshop, gems, search, 3 group heads, 46 lessons, progress,
language) (`bypass-blocks`, `out/tab-walk-en-hallo.txt`). Landmarks exist
(`aside`, `nav`, `main`), which is why axe's `bypass` rule passes, but
keyboard-only users do not get landmark navigation. -> **Fix 7**

**M3. Contrast under AA** (own computation in `keyboard.mjs`, axe's in the
JSON; ratios from `contrast_calc.mjs`):

| element | now | ratio | proposal | new ratio |
|---|---|---|---|---|
| CodeMirror line numbers | `#7d8894` on paper | 3.61 | `#5f6b78` | 5.44 (4.83 on code-bg) |
| links (`--bacon`) on `--code-bg` (e.g. `.offweb` boxes in rumale) | `#c14a2e` | 4.35 | `--bacon: #b3401f` | 5.09 (5.72 on paper) |
| mini browser `.mb-status.ok` (`--ok`) on `#e3f2e4` | `#2e7d32` | 4.41 | `--ok: #276d2b` | 5.47 |
| download size `.cell-download small` (opacity .75) | `#d17762` | 3.22 | opacity 1 | 4.90 |
| workshop rename/delete `✎ ×` (opacity .45 until hover/focus) | `#b7b1ac` | 2.12 | opacity .8 | 4.50 |

(The grid background makes axe report most text as "incomplete" rather than
pass/fail; the own check uses the paper colour under the grid. Text on paper
is fine everywhere else.)

**M4. Language markup.** (WCAG 3.1.2 Language of Parts)
- In de/en, `日本語` in the language select and `言語` in its `title` sit in a
  `lang="de"/"en"` page; in every language `Deutsch`/`English` likewise. No
  `<option lang>` (`lang-de`, `lang-en` FAIL).
- The loading screen text "Einen Moment … / One moment … / 少々お待ちください …"
  is one unmarked string; with `?lang=ja` the tab title on the loading screen
  is German (`spinner-lang`, `shots/ja-spinner.png`).
- `#mascot` and the spinner image have `alt="Chunky Bacon Fuchs"` (German) in
  every language; the shell never localises them.
- The language select has only a `title` as its label (axe
  `label-title-only`, serious, every page).
-> **Fix 8**

**M5. Widgets without names or announcements.**
- IRB: input named only by `title="irb"` (axe `label-title-only`); results
  appended to `.irb-history` are not announced (`irb-widget` FAIL). Focus
  does stay in the input after Enter (good).
- Mini browser: URL field named by `title="URL"` (axe); the status (`404`) and
  the page are not announced.
- 3D: `<canvas>` with no role or name (`three-canvas-name` FAIL).
- Letter (rumale): pointer-only drawing (WCAG 2.1.1 - an inherent part of the
  exercise, but a typed-digits fallback would keep the lesson usable), and
  the classifier's answer is drawn **only into the canvas**, so a screen
  reader never hears it.
-> **Fix 9**

### Low

- **L1** Animated 3D scenes ignore `prefers-reduced-motion` and have no pause
  (the canvas keeps changing under `reduce`, `three-reduced-motion` WARN;
  WCAG 2.2.2 for motion > 5 s). Sketch in Fix 9.
- **L2** All run buttons are named "▶ Run" (3 identical names in `hallo`, up
  to 8 per lesson) - ambiguous in a screen reader's button list. Fix 10.
- **L3** Shortcuts (Shift+Enter, Alt+R, the new Escape+Tab) are not exposed
  (`aria-keyshortcuts`) and not in the editor's description. Fix 1 + 10.
- **L4** axe noise, no action needed: `scrollable-region-focusable` on
  `.CodeMirror-scroll` (the editor itself scrolls with the caret), and
  `skip-link` (moderate, 31 nodes) - axe reads the index's `href="#roda"`
  hash routes as in-page skip links without targets; gone with permalinks.

## Prioritised fix list

1. Fix 1 - editors: escape from Tab, name, focus ring (H1) - small, verified.
2. Fix 3 + 4 - keep focus after Run and after lesson changes (H3).
3. Fix 2 - announce run results (H2).
4. Fix 5 - shadow root for the mini browser (H4) - also a visible bug.
5. Fix 6 + 7 - modal drawer, skip link (M1, M2).
6. CSS contrast tweaks (M3) - five one-line changes.
7. Fix 8, 9, 10 - language parts, widget names, run-button names (M4, M5, L).

New UI strings used below (lessons.js `ui.de/en/ja`; proposed wording):

| key | de | en | ja |
|---|---|---|---|
| `codeLabel` | `Code, Zelle %d` | `Code, cell %d` | `コード（セル%d）` |
| `codeHint` | `Umschalt+Enter führt aus. Escape, dann Tab verlässt den Editor.` | `Shift+Enter runs it. Escape, then Tab, leaves the editor.` | `Shift+Enterで実行。Escapeの後にTabでエディタを離れます。` |
| `ranOk` | `Zelle %d ausgeführt: %s` | `Cell %d ran: %s` | `セル%dを実行しました：%s` |
| `ranError` | `Zelle %d mit Fehler: %s` | `Cell %d failed: %s` | `セル%dでエラー：%s` |
| `runCellLabel` | `Zelle %d ausführen` | `Run cell %d` | `セル%dを実行` |
| `skipLink` | `Zur Lektion springen` | `Skip to the lesson` | `レッスンへ移動` |
| `langLabel` | `Sprache` | `Language` | `言語` |
| `mascotAlt` | `Chunky Bacon, der Fuchs` | `Chunky Bacon, the fox` | `キツネのチャンキー・ベーコン` |
| (main.rb `ui`) `irbInput`, `browserUrl`, `threeLabel` | `IRB-Eingabe`, `Adresse`, `3D-Szene` | `IRB input`, `Address`, `3D scene` | `IRBの入力`, `アドレス`, `3Dシーン` |

### Fix 1 - editors (index.html, app.rb, app.css) - verified by `verify_fixes.mjs`

```diff
--- a/html/index.html
+++ b/html/index.html
@@ window.initCell
-    window.initCell = function (idx) {
+    // +label+ names the editor for screen readers ("Code, cell 2"), +hint+
+    // says how to run and how to leave it (shell/app.rb, UI strings)
+    window.initCell = function (idx, label, hint) {
       var ta = document.getElementById("cell-code-" + idx);
       if (!ta) return;
-      window.cellEditors[idx] = CodeMirror.fromTextArea(ta, {
+      var cm = window.cellEditors[idx] = CodeMirror.fromTextArea(ta, {
         lineNumbers: true,
         mode: "text/x-ruby",
         matchBrackets: true,
         indentUnit: 2,
         viewportMargin: Infinity,
+        screenReaderLabel: label || null,
         extraKeys: {
           "Shift-Enter": function () {
             var btn = document.querySelector('.run-cell[data-idx="' + idx + '"]');
             if (btn) btn.click();
           }
         }
       });
+      // Tab indents, as in any code editor - but Escape, then Tab (or
+      // Shift+Tab) leaves it; without that the keyboard is trapped (WCAG
+      // 2.1.2). CodeMirror.Pass would fall through to the default keymap
+      // and indent anyway; codemirrorIgnore leaves the key to the browser.
+      var leave = false;
+      cm.on("keydown", function (cm, e) {
+        if (e.key === "Escape") { leave = true; return; }
+        if (e.key === "Tab" && leave) { e.codemirrorIgnore = true; leave = false; return; }
+        if (e.key !== "Shift") leave = false;
+      });
+      cm.on("blur", function () { leave = false; });
+      if (hint) {
+        var note = document.createElement("span");
+        note.id = "cell-hint-" + idx;
+        note.hidden = true;
+        note.textContent = hint;
+        cm.getWrapperElement().appendChild(note);
+        cm.getInputField().setAttribute("aria-describedby", note.id);
+        cm.getInputField().setAttribute("aria-keyshortcuts", "Shift+Enter");
+      }
```

```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def render_lesson
       el("lessonBody").innerHTML = View.lesson_html(cells, ui.taskLabel, ui.runCell, live_toggle_html)
+      number = 0
       cells.each_with_index do |cell, i|
         next unless code_cell?(cell)
 
-        JSG.w.initCell(i)
+        number += 1
+        # all strings: PicoRuby 4.0.3 mangles "\n" in strings next to a number
+        JSG.w.initCell(i.to_s, format(ui.codeLabel, number), ui.codeHint)
         set_code(i, Store.get(Store.code_key(@lang, id, i), cell.code))
       end
@@ def render_workshop
-      JSG.w.initCell(0)
+      JSG.w.initCell("0", ui.workshopTitle, ui.codeHint)
```

```diff
--- a/html/assets/app.css
+++ b/html/assets/app.css
@@ (after .cell .CodeMirror-selected)
+/* the editor's input is a hidden textarea: the ring goes on the editor,
+   inset, as the cell clips what sticks out */
+.cell .CodeMirror-focused { outline: 3px solid var(--focus); outline-offset: -3px; }
```

(`test/shell/stubs/js.rb:512` fakes `initCell` with a `proc do |idx|`,
which ignores the extra arguments; `test/shell/app_test.rb:41` asserts
`["initCell", 1]` and would need `"1"` - or keep passing the Integer if
PicoRuby's string-escaping problem does not hit these two plain strings.)

### Fix 2 - announce runs (index.html, app.rb, app.css)

```diff
--- a/html/index.html
+++ b/html/index.html
           <main>
             <article id="lessonBody"></article>
+            <!-- what an explicit run did, for screen readers (shell/app.rb
+                 announce_run); live runs never write here -->
+            <p id="runStatus" class="sr-only" role="status" aria-live="polite"></p>
```

```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def ran(detail)
       settle_cell(idx, outcome, detail.elapsed)
-      return if workshop?
+      return announce_run(idx, outcome) if workshop?
 
       cell = current_cells[idx]
-      return unless cell && cell.t == "x"
+      return announce_run(idx, outcome) unless cell && cell.t == "x"
 
       if outcome == "error"
         show_bubble(ui.errorIntro, "fail")
       elsif outcome == "pass"
         exercise_passed
       elsif outcome == "fail"
         show_bubble(View.failed_html(ui, cell.hint), "fail")
       end
+      announce_run(idx, outcome, el("chunkyText").textContent.to_s)
     end
+
+    # One polite status message per explicit run: the cell's output,
+    # shortened, and for an exercise Chunky's verdict. Cleared first, so the
+    # same result twice is announced twice.
+    def announce_run(idx, outcome, verdict = nil)
+      out = el("cell-out-#{idx}")
+      text = out ? out.textContent.to_s.strip : ""
+      text = "#{text[0, 280]} …" if text.length > 280
+      number = current_cells[0, idx + 1].count { |c| code_cell?(c) }
+      message = format(outcome == "error" ? ui.ranError : ui.ranOk, workshop? ? 1 : number, text)
+      message = "#{message} #{verdict}" if verdict && verdict != ""
+      status = el("runStatus")
+      status.textContent = ""
+      JSG.w.setTimeout(-> { status.textContent = message }, 50)
+    end
```
(If a lambda cannot go through PicoRuby's `setTimeout`, write the text
directly - Chrome/NVDA announce a changed text node; only an identical text
needs the clear-then-set.)

```diff
--- a/html/assets/app.css
+++ b/html/assets/app.css
+.sr-only {
+  position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
+  overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; border: 0;
+}
```

### Fix 3 - keep focus on Run (app.rb)

The tests check `.disabled` (browser_test.mjs, live_test.mjs, shell tests), so
keep `disabled` and give the focus back:

```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def start_cell_run(idx)
       @running[idx] = true
       drop_live_run(idx)   # this run replaces the live one still waiting
+      # a disabled button drops the keyboard focus to <body>: remember that
+      # it was here, settle_cell hands it back
+      focused = JSG.d.activeElement
+      @refocus = idx if focused && focused.getAttribute("data-idx").to_s == idx.to_s &&
+                        focused.className.to_s.include?("run-cell")
@@ def settle_cell(idx, outcome, elapsed)
       if button
         button.disabled = false
         button.textContent = ui.runCell
+        if @refocus == idx
+          @refocus = nil
+          button.focus if JSG.d.activeElement.tagName.to_s == "BODY"
+        end
       end
```
Better, later: `aria-disabled="true"` instead of `disabled` (the guard
`return if @running[idx]` already ignores a second click), so focus never
leaves and "running …" is read out; needs the 8 `.disabled` checks in
test/ changed to `[aria-disabled="true"]`.

### Fix 4 - focus the lesson after navigating (app.rb, app.css)

```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def select_lesson(id)
       show_bubble(ui.welcome, nil)
       # a new lesson starts at its top
       JSG.w.scrollTo(0, 0)
+      focus_heading
     end
@@ def open_workshop
       show_bubble(ui.workshopWelcome, nil)
       JSG.w.scrollTo(0, 0)
+      focus_heading
     end
+
+    # The index is drawn anew (innerHTML) and the drawer closes, so the
+    # link that was used is gone and the focus with it: it goes to the
+    # lesson's heading, where a screen reader starts reading. Also the
+    # skip link's target (Fix 7).
+    def focus_heading
+      heading = JSG.d.querySelector("#lessonBody h2")
+      return unless heading
+
+      heading.setAttribute("tabindex", "-1")
+      heading.focus
+    end
```
`select_lesson` covers the index, "next lesson", the drawer and Enter in the
search field. Not called from `route_from_address` on first load (focus
should stay at the top there); on back/forward it may be, same reasoning.

```diff
+#lessonBody h2[tabindex="-1"]:focus:not(:focus-visible) { outline: none; }
```

### Fix 5 - mini browser in a shadow root (main.rb) - sketch, untested

```diff
--- a/html/main.rb
+++ b/html/main.rb
@@ def navigate_browser(widget)
-      view.innerHTML = content_type.empty? || content_type.include?("html") ? body : "<pre>#{escape_html(body)}</pre>"
+      # the app's page in its own shadow root: its <style> (Sinatra's 404
+      # page sets body { color:#888; text-align:center; font-size:22px })
+      # stays inside the fake browser instead of restyling the course
+      root = view[:shadowRoot]
+      if root == JS::Null
+        options = JS.global[:Object].new
+        options[:mode] = "open"
+        root = view.attachShadow(options)
+      end
+      root[:innerHTML] = content_type.empty? || content_type.include?("html") ? body : "<pre>#{escape_html(body)}</pre>"
@@ $d.getElementById("lessonBody").addEventListener("click") do |event|
-      elsif target.tagName == "A" && target.closest(".mb-view")
+      elsif css_class.include?("mb-view") && (link = event.composedPath[0].closest("a")) != JS::Null
         # links inside the fake browser navigate the fake browser
+        # (from a shadow root the event arrives retargeted to .mb-view)
         event.preventDefault
         widget = target.closest(".mini-browser")
         if widget
-          widget.querySelector(".mb-url").value = target.getAttribute("href").to_s
+          widget.querySelector(".mb-url").value = link.getAttribute("href").to_s
           navigate_browser(widget)
         end
```
Tests that read `.mb-view` text (browser_test.mjs, the sinatra/roda checks)
then read `.mb-view`'s `shadowRoot.textContent`. Also give the 404 image an
alt in the cache? No - it is Sinatra's own page; the shadow root at least
keeps it out of the course. Add `aria-live="polite"` to `.mb-status` in
`browser_widget_html` so "404" is heard.

### Fix 6 - modal drawer on a phone (app.rb)

```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def toggle_sidebar
       list = JSG.d.body.classList
       if narrow?
-        list.toggle("sidebar-open")
+        open = list.toggle("sidebar-open") == true
+        sidebar_expanded
+        # the keyboard goes into the drawer, as into a dialog
+        el("workshopLink").focus if open
+        return
       else
@@ def sidebar_expanded
       showing = narrow? ? body_class?("sidebar-open") : !body_class?("sidebar-closed")
       el("sidebarToggle").setAttribute("aria-expanded", showing.to_s)
+      # an open drawer is modal: the page behind the scrim leaves the tab
+      # order and the screen reader (inert); also undone when the window
+      # grows past NARROW with the drawer out
+      JSG.d.querySelector(".column").inert = narrow? && body_class?("sidebar-open")
     end
```
(`close_drawer` and the media-query listener already call `sidebar_expanded`.
The toggle sits outside `.column`, so it stays reachable to close the drawer.)

### Fix 7 - skip link (index.html, app.rb, app.css)

```diff
--- a/html/index.html
+++ b/html/index.html
     <div id="app" style="display:none">
+      <!-- first stop for the keyboard: past the 50+ links of the index -->
+      <a id="skipLink" class="skip-link" href="#lessonBody"></a>
       <button id="sidebarToggle" ...
```
```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def wire_events
+      # a hash link would be read as a lesson id by the router
+      el("skipLink").addEventListener("click", sync: true) { |event| event.preventDefault; guard("skip") { focus_heading } }
@@ def render_all
+      el("skipLink").textContent = ui.skipLink
```
```diff
+.skip-link {
+  position: fixed; left: 3.5rem; top: -4rem; z-index: 60;
+  padding: 0.4rem 0.8rem; background: var(--paper); color: var(--ink);
+  border: 2px solid var(--ink); border-radius: 6px;
+}
+.skip-link:focus { top: 0.6rem; }
```

### Fix 8 - language parts and the language select (index.html, app.rb)

```diff
--- a/html/index.html
+++ b/html/index.html
-      <p id="spinnerText">Einen Moment … / One moment … / 少々お待ちください …</p>
+      <p id="spinnerText"><span lang="de">Einen Moment …</span> / <span lang="en">One moment …</span> / <span lang="ja">少々お待ちください …</span></p>
@@
-            <select id="langSelect" title="Sprache / Language / 言語">
-              <option value="de">Deutsch</option>
-              <option value="en">English</option>
-              <option value="ja">日本語</option>
+            <label for="langSelect" id="langLabel" class="sr-only">Sprache</label>
+            <select id="langSelect" title="Sprache / Language / 言語">
+              <option value="de" lang="de">Deutsch</option>
+              <option value="en" lang="en">English</option>
+              <option value="ja" lang="ja">日本語</option>
```
(`spinnerText` is also rewritten by `bridge.js`/`loader.js` on a failure -
those texts are in one language, so fine. The `title` stays as a tooltip
but should then be per language: set it in `render_all`.)

```diff
--- a/html/shell/app.rb
+++ b/html/shell/app.rb
@@ def render_all
       el("langSelect").value = @lang
+      el("langLabel").textContent = ui.langLabel
+      el("langSelect").setAttribute("title", ui.langLabel)
+      el("mascot").setAttribute("alt", ui.mascotAlt)
```

### Fix 9 - widgets (main.rb, letter.js)

```diff
@@ def irb_widget_html(sid)
-        <div class="irb-history"></div>
+        <div class="irb-history" role="log" aria-live="polite"></div>
         <div class="irb-line">
-          <span class="irb-prompt">irb(main):001:0&gt;</span>
-          <input class="irb-input" spellcheck="false" autocomplete="off" title="irb">
+          <span class="irb-prompt" aria-hidden="true">irb(main):001:0&gt;</span>
+          <input class="irb-input" spellcheck="false" autocomplete="off" title="irb" aria-label="#{escape_html(ui["irbInput"])}">
@@ def browser_widget_html(bid, path)
-          <input class="mb-url" value="#{escape_html(path)}" spellcheck="false" title="URL">
+          <input class="mb-url" value="#{escape_html(path)}" spellcheck="false" title="URL" aria-label="#{escape_html(ui["browserUrl"])}">
           <button type="button" class="mb-go">#{ui["browserGo"]}</button>
-          <span class="mb-status"></span>
+          <span class="mb-status" aria-live="polite"></span>
@@ def three_widget_html(tid, spec)
-        <canvas id="three-canvas-#{tid}" width="#{spec[:width]}" height="#{spec[:height]}"></canvas>
+        <canvas id="three-canvas-#{tid}" width="#{spec[:width]}" height="#{spec[:height]}" role="img" aria-label="#{escape_html(ui["threeLabel"])}"></canvas>
@@ def mount_three(idx, tid, spec)
-    if animate || controls
+    # reduced motion: one still frame of an animated scene (orbiting by
+    # hand still works - controls alone do not move by themselves)
+    still = animate && $window.matchMedia("(prefers-reduced-motion: reduce)")[:matches] == true
+    if (animate && !still) || controls
       frame = 0
       renderer.animation_loop do
         frame += 1
-        animate.call(frame) if animate
+        animate.call(frame) if animate && !still
```
(Check the three lesson's checks first - if one counts frames, add a
"pause" button on `.three-stage` instead that calls `setAnimationLoop(null)`.)

letter.js: mirror the answer into text, e.g. give `sees` a sibling
`<span class="letter-answer" aria-live="polite">` that `render()` fills with
`answer`; a typed fallback (an `<input inputmode="numeric">` that draws the
digits into the boxes in a handwriting font) would make the exercise
keyboard-usable.

### Fix 10 - run buttons with their cell (view.rb)

```diff
--- a/html/shell/view.rb
+++ b/html/shell/view.rb
-    def self.cell_html(idx, exercise, task_label, run_label, live = "")
+    # +name+: "Run cell 2" for screen readers; it contains the visible
+    # "Run" (WCAG 2.5.3 Label in Name)
+    def self.cell_html(idx, exercise, task_label, run_label, live = "", name = "")
+      label = name == "" ? "" : %( aria-label="#{escape_html(name)}")
+      keys = exercise ? ' aria-keyshortcuts="Alt+R"' : ""
       <<~HTML
         <div class="cell#{exercise ? ' exercise' : ''}" data-label="#{task_label}">
           <textarea title="code" id="cell-code-#{idx}"></textarea>
-          <div class="cell-toolbar">#{live}<button type="button" class="run-cell" data-idx="#{idx}">#{run_label}</button></div>
+          <div class="cell-toolbar">#{live}<button type="button" class="run-cell" data-idx="#{idx}"#{label}#{keys}>#{run_label}</button></div>
```
(`lesson_html` passes `format(ui.runCellLabel, number)`. The ja label
"セル2を実行" contains the visible "実行". While running, the aria-label
hides "running …" - acceptable once Fix 2 announces the result.)

### CSS contrast (M3)

```diff
--- a/html/assets/app.css
+++ b/html/assets/app.css
-  --bacon: #c14a2e;       /* links; 4.9:1 on paper */
+  --bacon: #b3401f;       /* links; 5.7:1 on paper, 5.1:1 on code-bg and fat */
-  --ok: #2e7d32;
+  --ok: #276d2b;          /* 5.5:1 on the light green status chips */
-.cell .CodeMirror-linenumber { color: #7d8894; padding: 0 0.5rem 0 0.4rem; }
+.cell .CodeMirror-linenumber { color: #5f6b78; padding: 0 0.5rem 0 0.4rem; }
-.cell-download small { opacity: 0.75; }
+.cell-download small { opacity: 1; }
 .ws-files button.ws-del, .ws-files button.ws-ren {
   ...
-  opacity: 0.45;
+  opacity: 0.8;           /* 4.5:1; full at hover and focus */
```
(`--bacon` also colours the bacon stripes of the load bar - a shade darker
there is harmless.)

## Not covered

Real screen readers (NVDA/VoiceOver) were not run - announcements are
inferred from the DOM (live regions, names). Not audited: the PyCall/SymPy
lessons (Pyodide load), Shoes/Scarpe apps, the file explorer widget, the
gems panel's install flow, Windows High Contrast / forced colours, 200 %
text zoom.
