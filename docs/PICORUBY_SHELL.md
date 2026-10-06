# The page on PicoRuby, the cells on CRuby - a prototype

Branch `picoruby-shell`, based on `main` at 8fafae1 (before the PDF lesson).
Written 2026-09-30. Nothing here is live: the branch is a prototype and this
is its report.

**In one paragraph.** The page itself - header, index, lesson text and
editors, language switch, routing, Chunky's bubble, reset, the gems panel,
and (second step, done too) the progress dialog and the workshop's file
panel - now runs as Ruby on [PicoRuby.wasm](https://github.com/picoruby/picoruby)
4.0.3 (0.9 MB gzipped), so a lesson can be read **0.4 s** after the page is
requested instead of 1.2 s, and **1.0 s instead of 5.8 s** on a 20 Mbit/s
line. `main.rb` stays on CRuby ruby.wasm as the *kernel*: it runs cells,
checks, gems and every widget, loads in the background, and a Run clicked
before it is ready waits for it. The first cell run comes 0.1 s later than
today, 0.5-0.7 s later on the slow line (0.3 s with `?kernel=eager`, at the
cost of 0.17 s of readability). `storage.js` (the storage engine) stays
JavaScript. All existing suites pass (with two new browser checks), a new
one covers the two failure paths, a Minitest suite (93 tests) covers the
shell under CRuby, and a PicoRuby port of the jsg idea is in use - though on
PicoRuby it saves only about 1 % of tokens, because PicoRuby's own interop
already does most of what jsg adds to ruby.wasm. Recommendation
(section 11): merge after the PDF lesson has landed, with the lazy kernel.

## Contents

1. Architecture
2. The bridge
3. Files
4. Running, testing, measuring
5. PicoRuby pitfalls hit
6. Load-time measurements
7. Code size and tokens
8. jsg on PicoRuby
9. Test results
10. Open issues and next steps
11. Merge recommendation

## 1. Architecture

```
                       index.html (static, nginx)
   ┌──────────────────────────────────────────────────────────────────┐
   │ lessons.js  CodeMirror  storage.js                   (plain JS)   │
   │                                                                  │
   │  SHELL  html/shell/*.rb          BRIDGE             KERNEL        │
   │  PicoRuby.wasm 4.0.3     ──►  shell/bridge.js  ──►  html/main.rb  │
   │  0.9 MB gz, up in ~0.3 s  ◄──  chunky:* events  ◄──  CRuby 4.0     │
   │  renders everything the        queue while the      ruby.wasm     │
   │  learner reads                 kernel loads         10 MB gz      │
   └──────────────────────────────────────────────────────────────────┘
```

Who owns what:

| | shell (PicoRuby) | kernel (CRuby, main.rb) | plain JS |
|---|---|---|---|
| header, footer, `<html lang>`, tab title | yes | | |
| index (nav), sections, done marks, workshop link | yes | | |
| lesson text, cell markup, CodeMirror editors (via `initCell`/`setCellCode`) | yes | reads the code (`getCellCode`), marks error lines | `index.html` helpers |
| language (de/en/ja), routing (`location.hash`, back/forward, bad ids), reset | yes | follows the shell's state | |
| Chunky's bubble (welcome, praise, next-lesson link, hints, errors, gem messages) | yes | composes gem error texts | |
| Run button look (running, fox, shake/celebrate, run time), Alt+R, Shift+Enter | yes | | Shift+Enter in `initCell` |
| lesson done list (`chunky_done`), `chunky_lang`, `chunky_current`, a cell's saved code (`Store.code_key`, HANDOVER §6a) | yes | hands over the code it runs (`chunkySaveCode`) | |
| running cells, checks (`check_exercise`), `=>` output | | yes | |
| gems: installing, installed list | chips, button, bubble | `BrowserGems` | |
| IRB, mini browser, 3D, Shoes, file explorer, downloads, workshop runs | | yes | |
| progress dialog, workshop file panel (`shell/workspace.rb`, formerly `workspace_ui.js`) | yes | asks for the project's files during a run | |
| where the work lives: localStorage change times, progress file, connected folder | | | `storage.js` |

Boot, in order:

1. `index.html` parses; its head preloads the PicoRuby runtime
   (`picoruby.js` as modulepreload, `picoruby.wasm` as fetch,
   `init.iife.js`). **`browser.script.iife.js` is no longer in the head.**
2. `shell/bridge.js` defines `window.ChunkyBridge` and parses
   `LESSONS_JSON` once into `window.LESSONS` (JavaScript's `JSON.parse`).
3. `shell/loader.js` fetches `shell/manifest.txt` and the files it lists,
   joins them into one `<script type="text/picoruby">` and adds
   `assets/picoruby/init.iife.js`.
4. PicoRuby boots, `boot.rb` runs `ChunkyShell::App.new.start`: listeners,
   the `Workspace` (progress button, storage.js listeners, the window
   functions the kernel calls), spinner off, `#app` on, the whole page
   rendered, the bubble, then `ChunkyBridge.shellReady()` and a Task that
   fetches the gem cache's manifest for the chips.
5. `shellReady()` adds `browser.script.iife.js`; CRuby downloads, compiles,
   runs `main.rb` (still `<script type="text/ruby">`), whose
   `ChunkyApp.new` reads `ChunkyBridge.state`, installs its listeners and
   calls `ChunkyBridge.kernelReady(installed gems)`.
6. Runs and installs asked for meanwhile go to the kernel, in order; the
   header's "Ruby wird geladen …" (`#kernelStatus`) disappears.

`?kernel=eager` in the URL starts step 5 at step 2 instead (for comparison,
section 6; making it the default is one line in `bridge.js`).

## 2. The bridge

`html/shell/bridge.js` (about 120 lines, half of them comments). Neither Ruby calls into the
other: the shell calls `ChunkyBridge.*` with plain values (PicoRuby can pass
strings, numbers, booleans and nil - not Hashes, Arrays or Symbols), the
kernel listens for `chunky:*` events on `window` and answers through
`ChunkyBridge.*`, whose answers reach the shell as `chunky:*` events.

| call | by | does |
|---|---|---|
| `setState(lang, lesson, workshop)` | shell, on every lesson render | stores `state`, `seq += 1`, drops queued runs, sends `chunky:lesson`; after the paint tells `stepper.js` (`ChunkyStepper.page`: a recording survives a language change where the code is the same) |
| `reset()` | shell, lesson reset | `seq += 1`, sends `chunky:lesson`, drops the stepper's recordings |
| `run(idx)` → `true` / `false` | shell, Run / Shift+Enter / Alt+R | kernel up: `chunky:run` after the next paint (`afterPaint`); else queued. Returns whether it went now |
| `autorun(idx)` → `true` / `false` | shell, a second after the last key (live runs, HANDOVER §6b) | kernel up: `chunky:run {auto: true}` after the next paint; else `false` - never queued |
| `step(idx)` → `true` / `false` | shell, ⏯ (a lesson with `"stepper": true`, HANDOVER §6) | as `run`, with `chunky:run {step: true}`: the run is recorded |
| `install(name)` → `true` / `false` | shell, gem chip / button | `chunky:install` after the next paint, or queued |
| `shellReady()` | shell, after the first render | `chunky:shell-ready`, starts the kernel |
| `kernelReady(installedJson)` | kernel, end of `ChunkyApp#initialize` | `ready = true`, `chunky:kernel-ready`, `chunky:gems`, then the queue |
| (none: an unhandled rejection before `ready`) | CRuby's loader | `failed = true`, queue dropped, `chunky:kernel-failed {reason}` |
| `ran(idx, outcome, elapsed, auto, own)` | kernel, after every run | `chunky:ran {idx, outcome: ok/error/pass/fail (a live run also skipped/stopped/needs), elapsed, auto, own}` - `own`: elapsed without installing and loading gems |
| `gems(installedJson)` | kernel, after runs and installs | `chunky:gems {installed}` |
| `installed(name, ok, message)` | kernel, panel install | `chunky:installed {name, ok, message}` |
| `steps(idx, json)` | kernel, after a ⏯ run (`show_steps`) | parses the recording here (never in PicoRuby) and hands it to `ChunkyStepper.show` (`stepper.js`); no event |
| `ready`, `state` | both | `state = {lang, lesson, workshop, seq}`; the kernel reads it at boot |
| `settle(promise)` → promise of `{ok, value, name, message}` | shell (workspace.rb) | never rejects; PicoRuby's `await` would raise and lose the error's name |
| `saveText(name, text)` | shell (workspace.rb) | a text file to the downloads (a Blob needs an array argument) |

The kernel reaches the workshop through window functions the shell
registers (`JS::Object.register_callback`): `workshopOpenPath`,
`workshopStdin`, `workspaceSnapshot`, `workspaceWrite(path, text)`,
`workspaceDelete(path)`, `workshopAfterRun` - the same names
`workspace_ui.js` had, so `run_cell` did not change. One more such
function, `chunkyEdited(idx)`, is for index.html's editors: a key in a
cell, which starts the shell's live-run timer; and `chunkySaveCode(idx,
code)` is the kernel's again: the code a run uses, which the shell keeps
(later than this report: HANDOVER §6a).

| event | to | detail |
|---|---|---|
| `chunky:run` | kernel | `{idx, auto, step, lang, lesson, workshop, seq}` - `auto`: a live run; `step`: ⏯, recorded |
| `chunky:lesson` | kernel | `{lang, lesson, workshop, seq}` - a new `seq` means a fresh binding, old 3D/Shoes stages disposed (`sync_state`) |
| `chunky:install` | kernel | `{name, ...state}` |
| `chunky:ran`, `chunky:gems`, `chunky:installed`, `chunky:kernel-ready`, `chunky:kernel-failed` | shell | as above |
| `chunky:shell-ready` | anyone | (used by the measurements) |

Design points, each learned the hard way:

- **Answers are delivered synchronously**, still inside the kernel's call,
  and the shell listens with `sync: true`. A first version sent them with
  `setTimeout(0)`; Playwright (and a learner) could then see the finished
  output next to an unsettled bubble - `browser_test.mjs` caught it
  ("http exercise passes"). Requests to the kernel do not run inside the
  shell's handler: runs and installs go out after the next paint,
  `chunky:lesson` on `setTimeout(0)` - so CRuby never runs inside a
  PicoRuby handler, only PicoRuby (briefly, to settle the cell) inside
  CRuby's call.
- **Every run carries the state** it was asked for, so a kernel that booted
  late, or missed an event, still evaluates in the right lesson, language
  and binding.
- **The running look comes first**: the shell paints it, the bridge waits
  two frames (`afterPaint`) before CRuby blocks the main thread - the same
  contract as before, now across two runtimes.

The kernel side is small: `ChunkyApp#sync_state`, `#bridge`, three
listeners in `#setup_elements`, and `finish_cell_run` / `panel_install`
reporting to the bridge. `run_cell` lost one line (the error bubble);
`check_exercise` returns the check's result and no longer talks to the page.
Gone from `main.rb` (now in the shell): the page listeners of
`setup_elements` (reset, language, index, Run buttons, bubble link, Alt+R,
gems panel, hashchange, progress loaded), `render_all`, `render_gems_panel`,
`render_nav`, `render_lesson`, `render_workshop`, `open_workshop`,
`show_bubble`, `select_lesson`, `go_to_next_lesson`, `switch_lang`,
`reset_lesson`, `stored`, `done_ids`, `mark_done`, `hash_lesson_id`,
`set_lesson_hash`, `route_from_hash`, `workshop_hash?`, `exercise_index`,
`start_cell_run`, `settle_cell`, `replay`, `show_run_time`, `cell_parts`,
`WORKSHOP_ID`, and the spinner/`#app` switch in `initialize`. The widget
listeners (mini browser, file explorer, IRB) stay, on `#lessonBody` beside
the shell's.

## 3. Files

New:

| file | what |
|---|---|
| `html/shell/manifest.txt` | load order; read by `loader.js` and `test/shell/harness.rb` |
| `html/shell/jsg.rb` | the jsg-style layer for PicoRuby (section 8) |
| `html/shell/support.rb` | `escape_html`, `code_cell?`, `el(id)`, `guard` (logs a failing handler) |
| `html/shell/course.rb` | `Course`: the lessons through the bridge (`window.LESSONS`) |
| `html/shell/store.rb` | `Store`: localStorage keys, done list |
| `html/shell/view.rb` | `View`: the HTML strings (nav, lesson, cell, workshop, chips, bubble texts) |
| `html/shell/router.rb` | `Router`: the address - `/#methoden`, or `/de/methoden` when the optional server announces permalinks (HANDOVER §7a) |
| `html/shell/workspace.rb` | `Workspace`: the progress dialog and the workshop's file panel (the port of `workspace_ui.js`, which is gone) |
| `html/shell/app.rb` | `App`: state, events, routing, rendering, the run cycle, gems panel |
| `html/shell/boot.rb` | starts the page |
| `html/shell/bridge.js`, `html/shell/loader.js` | section 2, boot step 3 |
| `html/assets/picoruby/` | the runtime: `init.iife.js` (patched), `picoruby.js`, `picoruby.wasm`, `.gz` copies, `PICORUBY_VERSION.txt`, `NOTICE.md` (MIT, checksums) |
| `tools/patch_picoruby_loader.rb` | `text/ruby` → `text/picoruby` in PicoRuby's loader, anchor-checked, idempotent, `--check` |
| `tools/shell_metrics.rb` | section 7's tables; `--desugar DIR` writes and tests the sugar-free shell |
| `tools/measure_load.mjs` | section 6's measurements |
| `test/shell/` | `run.rb`, `harness.rb`, `stubs/js.rb`, five `*_test.rb` (section 9) |
| `test/make_lessons_json.js` | writes `test/lessons.json` (the README's `node -e` line as a file) |
| `test/boot_failure_test.mjs` | Playwright: what the page says when CRuby or PicoRuby cannot load |
| `.gitattributes` | the runtime's bytes are never line-ending-converted (its `.gz` and checksums must match) |

Removed: `html/workspace_ui.js` (now `shell/workspace.rb`).

Changed: `html/main.rb` (1298 → 963 lines; section 2), `html/index.html`
(preloads, `#kernelStatus`, script order, spinner text), `html/assets/app.css`
(`.kernel-status`), `html/storage.js` (one comment), `tools/compress_assets.rb`
(checks the runtime's `.gz`), `THIRD_PARTY_NOTICES.md` (PicoRuby),
`test/browser_test.mjs` and `test/progress_test.mjs` (wait for the kernel;
section 9). `docs/HANDOVER.md` still describes `workspace_ui.js` and the
old boot; it was left alone on this branch. `nginx.conf` needs
no change: `.js`/`.rb` get `no-cache` and gzip as before, `picoruby.wasm`
and `picoruby.js` go out as their `.gz` (`gzip_static`), `manifest.txt` is
fetched with `cache: "no-cache"` by the loader.

## 4. Running, testing, measuring

```sh
# the runtime from npm, checked against the registry's SHA-512; the tool
# also patches the loader, writes the .gz copies and NOTICE.md (it was
# first installed with the create-jobrouter-custom-application skill's
# installer - the same bytes)
ruby tools/vendor_picoruby.rb                  # --check: offline, the recorded files
ruby tools/patch_picoruby_loader.rb --check    # the loader reads text/picoruby
ruby tools/compress_assets.rb --check          # the .gz copies match

node test/make_lessons_json.js
ruby test/check_harness.rb && ruby test/gems_harness.rb
ruby test/shell/run.rb                          # the shell, under CRuby
ruby tools/shell_metrics.rb --desugar tmp/desugared_shell
BASE=http://127.0.0.1:18011/ node test/browser_test.mjs
BASE=http://127.0.0.1:18011/ node test/progress_test.mjs
BASE=http://127.0.0.1:18011/ node test/boot_failure_test.mjs
SITES="baseline=http://127.0.0.1:18012/,prototype=http://127.0.0.1:18011/" \
  RUNS=5 node tools/measure_load.mjs            # interleaved; PROFILES=warm for repeat visits
```

The install script is idempotent but rewrites `init.iife.js` from the
bundle: run the patch after it. The Playwright suites and the
measurement import Playwright from the server path; on a machine without it
there, a resolve hook that maps the import (as in the main checkout's
untracked `tmp/playwright_redirect.mjs`) runs them unchanged. A local server
must gzip like nginx (the main checkout's untracked `tools/dev_server.rb`
does, and bridges rubygems); a plain static server measures wrong sizes.

## 5. PicoRuby pitfalls hit

Probed in headless Chromium against PicoRuby.wasm 4.0.3 (probe pages kept
out of the repository; results quoted). Each is either avoided in the shell
and guarded by a test, or handled by the stub so the unit tests fail the
same way PicoRuby would.

| # | pitfall | what happens | what the shell does | guarded by |
|---|---|---|---|---|
| 1 | both loaders run every `<script type="text/ruby">` | PicoRuby would try to run main.rb | loader patched to `text/picoruby` | `tools/patch_picoruby_loader.rb --check` |
| 2 | each script tag is its own concurrently scheduled Task | definitions used before they exist | one tag from the manifest | portability test: manifest lists every file, `jsg.rb` first, `boot.rb` last |
| 3 | `JSON.parse` of the 322 KB lesson JSON | 34.6 s | JavaScript parses once (`window.LESSONS`), Ruby reads fields (~1 µs each: 1,000 reads 2.8 ms) | - |
| 4 | **a string argument with `\n` or `\t` next to a non-string argument** (`setCellCode(1, "a\nb")`) | the call throws "Bad control character in string literal in JSON" - PicoRuby JSON-encodes the arguments and skips escaping in the mixed-type path; all-string calls are fine | the cell number goes over as a string (`App#set_code`) | stub raises the same error; mutation run: 27 errors |
| 5 | a dot read of a missing property (`lesson.section`) | answers nil but logs "Method not found or not a function: section" | optional fields with brackets (`lesson[:section]`) | stub logs the same; boot test asserts no console errors |
| 6 | Hash, Array or Symbol arguments to a JS call | `TypeError: Unsupported argument type` (so `CustomEvent.new(name, {detail: ..})` is impossible) | JS helpers in `bridge.js` take plain values | Prism scan `js_arguments`; stub raises |
| 7 | a Task's block runs with another `self` | `NoMethodError: undefined method 'guard' for Object` | `app = self; Task.new { app.fetch_gem_names }` | Prism scan `task_self`; stub runs Task blocks with another self |
| 8 | listeners without `sync: true` | run ~40 ms later (measured 40.7 ms) - and cannot `preventDefault` | every shell listener is `sync: true` and never suspends | - |
| 9 | `JS::Object#each` on a NodeList | yields nothing, silently | jsg.rb's `each` (to_a) | jsg_test |
| 10 | `\A`, `\z`, `\Z`, `\h` in regexps | `ArgumentError: invalid regular expression` (compiled to JS RegExp) | none used | Prism scan `regexp_escapes` |
| 11 | missing: `find_index sort_by group_by each_slice sum each_with_object min_by max_by filter_map count zip scan drop tally catch/throw`, `Struct`, `Enumerator`, `require 'singleton'`; enumerators without a block (`each_with_index.map`, `times.map`, `map.with_index`) | `NoMethodError` / `NameError` / `NotImplementedError: fiber required` | none used | Prism scans `missing_methods`, `missing_constants`, `blockless_enumerators`, `requires` |
| 12 | `$1`/`$~` after `=~`, named captures, `String#[regexp]` | nil / not supported / `TypeError` | none used | Prism scan `match_globals` |
| 13 | `promise.then(fn)` | `ArgumentError: wrong number of arguments` (a Ruby `then` answers) | `promise.await` inside a Task | - |
| 14 | `JS::Object#typeof` | returns a Symbol (`:function`), ruby.wasm returns a String | jsg.rb compares with `:function` | jsg_test |
| 15 | NUL in a string argument | truncates it (C strings) | - | - |
| 16 | `await` on a rejected promise | raises `RuntimeError` with the message only - the error's `name` (`AbortError`: the folder picker was closed) is lost | `ChunkyBridge.settle(promise)` answers `{ok, value, name, message}` | workspace_test |
| 17 | a promise awaited in a Task that starts later | if it rejects before the Task attaches, the browser reports an unhandled rejection (and `bridge.js` would take it for CRuby failing while CRuby loads) | `settle` is attached at once, in the handler; only the waiting happens in the Task (`Workspace#later`) | found by `progress_test.mjs` ("[pageerror] not a progress file") |
| 18 | a `register_callback` block called from JavaScript | runs synchronously, gets its arguments as Ruby values (strings with newlines intact), may return String/Integer/true/nil; its `self` was not probed | explicit receivers (`ws.open_path`) | stub runs callbacks with another self |
| 19 | the folder picker and the file chooser need the user's click (transient activation) | - | the picker call happens inside the `sync: true` click handler, where the activation is certain; only the waiting is in a Task | `progress_test.mjs` |

What works and was relied on: `sync: true` + `preventDefault`, `Module#prepend`
on `JS::Object` (with `super` into the C `method_missing`), Ruby values from
property reads, `nil` for a JS `null` from a call (`getElementById`) and
`JS::Object#nil?`, `Array#index` with a block, heredocs, `format`, `%()`,
endless defs, `Kernel#eval`, `fetch` + `to_binary` inside a Task, UTF-8
through the bridge both ways ("Grüsse 日本語 🦊" intact), JavaScript
exceptions arriving as rescuable `RuntimeError`s, `JS::Object.register_callback`
blocks called synchronously by JavaScript (also from CRuby's calls, nested),
`promise.await` and `sleep_ms` in a Task (0 ms ≈ 5 ms; the workshop's
half-second save debounce is one), a Task started from a sync handler or a
callback, `replaceChildren`/`appendChild`/`createTextNode`, `dialog.showModal`.

## 6. Load-time measurements

`tools/measure_load.mjs`, headless Chromium (Playwright 1.62.1) on the
development laptop, local dev server with nginx's gzip behaviour (the
`.wasm.gz` files, text gzipped on the fly); baseline = the same server on a
copy of `html/` at 8fafae1. Fresh browser context per run (cold cache).
*readable*: the lesson's `<h2>` is laid out (next frame); *first run*:
`#cell-out-1` of `#hallo` shows `=> 2`, its Run button clicked by the page
itself the moment the button exists. Throttling: CDP
`Network.emulateNetworkConditions`, 20 Mbit/s down, 40 ms latency.

**Final numbers** - the finished branch (with the workshop UI in Ruby),
median of 5, the three sites' runs interleaved so that the laptop's other
load hits them alike:

| site | network | readable | kernel ready | first run | MB until readable | MB total | requests |
|---|---|---|---|---|---|---|---|
| baseline | unthrottled | 1151 ms | - | 1181 ms | 10.66 | 10.72 | 23 |
| **prototype** | unthrottled | **400 ms** | 1269 ms | 1317 ms | **1.37** | 11.64 | 37 |
| prototype `?kernel=eager` | unthrottled | 452 ms | 1246 ms | 1290 ms | 1.41 | 11.64 | 37 |
| baseline | 20 Mbit/s, 40 ms | 5846 ms | - | 5882 ms | 10.66 | 10.72 | 23 |
| **prototype** | 20 Mbit/s, 40 ms | **953 ms** | 6532 ms | 6578 ms | **1.37** | 11.64 | 37 |
| prototype `?kernel=eager` | 20 Mbit/s, 40 ms | 1125 ms | 6170 ms | 6208 ms | 1.41 | 11.64 | 37 |
| baseline | repeat visit | 1440 ms | - | 1482 ms | (10.05) | (10.05) | 23 |
| **prototype** | repeat visit | **397 ms** | 1544 ms | 1584 ms | 0.00 | (10.05) | 37 |

Single runs (readable / first run, ms), unthrottled: baseline 1151/1181,
1102/1137, 1195/1234, 1250/1278, 1070/1097; prototype 400/1309, 423/1317,
570/1906, 388/1289, 396/1318; eager 498/1311, 429/1207, 604/1676, 452/1290,
422/1282. At 20 Mbit/s: baseline 5878/5909, 5842/5870, 5846/5882,
5869/5900, 5845/5881; prototype 953/6578, 960/6557, 952/6877, 976/6611,
950/6553; eager 1136/6123, 1101/6036, 1118/6208, 1125/6260, 1191/6391.
Repeat visits: baseline 1610/1661, 1604/1660, 1440/1482, 1122/1156,
1062/1100; prototype 397/1707, 458/1584, 461/1639, 335/1181, 364/1348.

An earlier series (before the workshop UI port, median of 3, the sites one
after the other) agrees: baseline 1221/1256 ms unthrottled and 6061/6099 ms
throttled, prototype 408/1446 and 941/6432, eager 437/1482 and 1101/6106,
repeat visits 1131/1168 vs 335/1246.

First contentful paint (the spinner) is the same unthrottled (124 vs
136 ms) and ~60 ms later at 20 Mbit/s (320 vs 384 ms: the runtime's
preloads share the line with the spinner's fox and fonts) - irrelevant next
to the lesson text arriving 5 s sooner.

Bytes by kind (prototype, cold): PicoRuby runtime 907,622, shell files
23,292 (all eight `.rb`, the manifest, bridge and loader, gzipped), CRuby
10,209,827 (wasm, loader, main.rb and its files, the minitest gem), common
499,939 (HTML, lessons.js, CodeMirror, CSS, fonts, fox; `workspace_ui.js`
no longer among them). The prototype adds the 0.9 MB runtime.

Reading it:

- **Readable: 2.9× sooner unthrottled, 6.1× sooner at 20 Mbit/s**, and
  before an eighth of the bytes. What remains on the critical path at
  20 Mbit/s is 1.37 MB: the 0.9 MB runtime, the fonts, CodeMirror and
  lessons.js.
- **First run: +0.14 s unthrottled, +0.5 to +0.7 s at 20 Mbit/s** with the
  lazy kernel (+0.33 s in the earlier series), because CRuby starts only
  once the page is up: the 0.9 MB runtime comes first, then the 10 MB. With
  `?kernel=eager` the first run is +0.1 s / +0.3 s, and the page is
  readable 50 ms / 170 ms later than with the lazy kernel: the two
  downloads share the line.
- **Repeat visits** cannot be measured fully here: Playwright's contexts keep
  only an in-memory cache and download the 10 MB `ruby+stdlib.wasm` again
  (both sites, the bracketed numbers); a real browser's disk cache would
  not. The shell part is real: readable in 0.4 s, from cache.
- Absolute times are this laptop's and move with its load (the baseline's
  unthrottled readable ranged from 1.06 to 2.05 s over the day); the ratios
  are the point. CRuby's boot (compile + `main.rb` + minitest from the
  cache) is ~1 s of main-thread work in both versions, and while it runs the
  shell's page does not react to clicks (it still scrolls) - the same
  freeze the baseline had behind its spinner.

## 7. Code size and tokens

`tools/shell_metrics.rb`. No tokenizer offline: bytes, lines, lexical tokens
(`Prism.lex` for Ruby without comments/newlines, a regex split for JS) and
an estimate at 3.5 bytes per model token; "code" = without comments and
blank lines (the house style comments generously). "Before" is 8fafae1.

**The frontend before and after** (code bytes / lexical tokens / est. model tokens):

| | before | after |
|---|---|---|
| `main.rb` | 36,137 / 7,581 / 10,325 (page + kernel) | 25,121 / 5,109 / 7,177 (kernel) |
| `shell/*.rb` (8 files, jsg.rb and workspace.rb included) | - | 35,085 / 7,698 / 10,024 |
| `shell/bridge.js` + `loader.js` | - | 5,478 / 1,310 / 1,565 |
| `workspace_ui.js` | 13,914 / 3,833 / 3,975 | - (now `shell/workspace.rb`) |
| `storage.js` | 13,969 / 3,651 / 3,991 | the same |
| `index.html` inline JS | 5,414 / 1,243 / 1,547 | 5,414 / 1,243 / 1,547 |
| **total** | **69,434 / 16,308 / 19,838** | **85,067 / 19,011 / 24,305** (+23 % bytes, +17 % lexical tokens) |

With comments: 85,600 → 112,277 bytes, 2,329 → 3,151 lines.

**One component in both languages** - the progress dialog and the
workshop's file panel, `workspace_ui.js` before and `shell/workspace.rb`
after, the same behaviour (37 checks of `progress_test.mjs`):

| progress dialog + file panel | code bytes | lexical tokens | est. tokens |
|---|---|---|---|
| `workspace_ui.js` (JavaScript) | 13,914 | 3,833 | 3,975 |
| `workspace.rb`, PicoRuby's plain interop | 15,166 | 3,456 | 4,333 |
| `workspace.rb`, with the jsg-style sugar (as shipped) | 15,092 | 3,436 | 4,312 |

Ruby needs 10 % fewer lexical tokens and 8 % more bytes than the
JavaScript (longer words - `end`, `def`, keyword names - fewer braces and
semicolons); in model tokens that is roughly even.

**What left main.rb vs what does that job now:** 11,016 code bytes / 2,472
lexical tokens left `main.rb`; the shell without `workspace.rb` is 19,993 /
4,262, with the bridge 25,471 / 5,572. The difference is not the language:
**like for like** - the 20 methods that do the same job under the same
names (`render_*`, `show_bubble`, `select_lesson`, `switch_lang`,
`reset_lesson`, routing, `start_cell_run`, `settle_cell`, `replay`,
`show_run_time`, `cell_parts`, plus the `View` helpers they call) - the code
is the same size:

| same 20 methods | code bytes | lexical tokens | est. tokens |
|---|---|---|---|
| main.rb before (CRuby, js gem: `el[:x]`, `.to_s`, `js_null?`) | 8,278 | 1,802 | 2,365 |
| shell, PicoRuby's plain interop | 8,867 | 1,764 | 2,533 |
| shell, with the jsg-style sugar (as shipped) | 8,733 | 1,702 | 2,495 |

(+5 % bytes, -6 % lexical tokens old → shipped.) The extra code is the
split itself: the event wiring for 15 listeners, the kernel's answers
(`ran`, `gems_changed`, `installed`, `exercise_passed` - formerly inside
`run_cell`/`check_exercise`), the queue-aware install, the kernel status
and its failure path, the gem list fetched in a Task, `Course`/`Store`
wrappers around the bridge, `jsg.rb` (1,375), and `bridge.js`/`loader.js`
(5,478). For an agent or a person working on the page, the relevant
context shrank anyway: the page code (the shell without the workshop UI)
is ~5.7k estimated tokens, where it used to sit inside a 10.3k-token
`main.rb` next to the gem installer, IRB, 3D and Shoes.

Per shell file (code bytes / lexical tokens): `workspace.rb` 15,092 / 3,436,
`app.rb` 13,169 / 2,757, `view.rb` 3,161 / 522, `jsg.rb` 1,375 / 376,
`store.rb` 740 / 199, `course.rb` 738 / 193, `support.rb` 488 / 139,
`boot.rb` 322 / 76.

## 8. jsg on PicoRuby

### Can the jsg gem itself run in PicoRuby? No.

`lib/jsg.rb` loaded into PicoRuby 4.0.3 (source evaluated with
`Kernel#eval`, which PicoRuby has):

- **As published it does not load**: `require_relative "jsg/version"` has no
  filesystem to read, and `SETTER = /\A[A-Za-z_]\w*=\z/` raises
  `ArgumentError: invalid regular expression` (`\A`/`\z` are not JavaScript).
- **With `\A`/`\z` rewritten to `^`/`$` it loads - and breaks PicoRuby's
  interop**, because it is written against ruby.wasm's `js` API:
  - `JSG.document` → `NameError: uninitialized constant JS::Null` (its `nil?`)
  - `el.hidden?` → `NoMethodError: undefined method 'typeof' for FalseClass`,
    `document.title` → `... 'typeof' for String`: PicoRuby already returns
    Ruby values, which have no `typeof`/`to_rb`
  - `document.getElementById("box")` **returns nil**: PicoRuby's `typeof`
    answers `:function` (a Symbol), jsg compares with `"function"` and falls
    through to `to_rb`, which PicoRuby does not have
  - `JSG.q("#box span")` → `TypeError: Unsupported argument type` (it calls
    `call(:querySelectorAll, ...)` with a Symbol)
  - only the setter (`el.innerText = "x"`) worked.

What PicoRuby lacks of what jsg builds on: `JS::Null`, `JS::Undefined`,
`JS::True`, `#strictly_eql?`, `#to_rb`/`JS.try_convert`, `typeof` as a
String, `call` with a Symbol, `Enumerator`. What PicoRuby already does that
jsg adds to ruby.wasm: property reads without brackets (`el.textContent`),
Ruby values back (String, Integer, Float, true/false, nil for null and
undefined), method calls with results converted.

### The idea works: `html/shell/jsg.rb`

76 lines (1,375 code bytes), prepended to `JS::Object` like the gem:

| you write | instead of (PicoRuby plain) |
|---|---|
| `el.textContent = "x"`, `el.style.display = "none"` | `el[:textContent] = "x"`, `el.style[:display] = "none"` |
| `el.hidden?`, `list.includes?(3)` (JS truthiness, a function is called) | `el.hidden` (fine for booleans), `JSG.truthy?(...)` |
| `JSG.w.Object.keys(obj)`, `JSG.w.JSON.parse(s)`, `JSG.w.LESSONS` | `JS.global[:Object].keys(obj)` - without brackets PicoRuby *calls* `Object()` and `.keys` fails |
| `JSG.q("li").each { ... }` | `.to_a.each` - PicoRuby's own `each` silently yields nothing |
| `JSG.w`, `JSG.d`, `JSG.q(sel)` | `JS.global`, `JS.document`, `JS.document.querySelectorAll(sel)` |

### Does it save tokens?

Measured by desugaring the shipped shell mechanically (Prism rewrite in
`tools/shell_metrics.rb --desugar`; the result passes the same app,
course/store/view, workspace and portability tests, so it is the same
program):

| shell without jsg.rb | code bytes | lexical tokens | est. tokens |
|---|---|---|---|
| PicoRuby's plain interop | 34,026 | 7,428 | 9,722 |
| with the sugar (as shipped) | 33,710 | 7,322 | 9,631 |
| **saved** | **316 (0.9 %)** | **106 (1.4 %)** | **~90** |

(For the page code alone, without `workspace.rb`: 246 bytes, 86 lexical
tokens, 1.3 % / 2.2 %.) `jsg.rb` itself costs 1,375 code bytes (~390
tokens), so on a shell this size it does not pay for itself in bytes. Its
value is elsewhere: one
syntax on both Rubies (the kernel could use the real gem on ruby.wasm), and
two rules that prevent silent bugs (capitalized names are properties;
`each` works on NodeLists). The big saving against the old code comes from
PicoRuby itself - no `[:prop]` on reads, no `.to_s`, no `js_null?`. In the
kernel, where the gem proper would run, `main.rb` still has 77 lines with
`[:prop]`, 44 with `.to_s` and 11 with `js_null?`: that is where jsg would
shorten code most.

### A proposal for the gem: ship a PicoRuby variant

- `lib/jsg/pico.rb` (or a `jsg-pico.rb` in the release assets): one file,
  no `require_relative`, no `\A`/`\z`, meant to be concatenated into a
  PicoRuby page - essentially `html/shell/jsg.rb`: setter, predicate,
  capitalized-property, `each`, `JSG.w/d/q`, `JSG.truthy?`.
- Make the core portable where it costs nothing: `^`/`$` instead of
  `\A`/`\z` for method names (they never contain newlines), compare
  `typeof.to_s`, and keep engine specifics (`to_rb`, `JS::Null`,
  `strictly_eql?`) in the ruby.wasm file.
- Document the differences: numbers stay Integer on PicoRuby (Float on
  ruby.wasm via `to_rb`); null and undefined are both nil (no `undefined?`);
  arguments must be plain values; dot reads of missing properties log.
- A test like `test/shell/jsg_test.rb` on a stub of PicoRuby's `js`
  (`test/shell/stubs/js.rb` could be the start), since PicoRuby has no
  Node.js test runner like ruby.wasm's.

## 9. Test results

All on this branch, against the prototype on a local server:

| suite | result |
|---|---|
| `ruby test/check_harness.rb` | ALL CHECKS OK (every lesson × de, en, ja; 37 at the time) |
| `ruby test/gems_harness.rb` | ALL GEM CHECKS OK |
| `test/browser_test.mjs` | **130/130** (the 128 checks plus two new ones) |
| `test/progress_test.mjs` | **37/37** - with the progress dialog and file panel in Ruby |
| `test/boot_failure_test.mjs` (new) | **5/5** - CRuby's wasm blocked: header message, waiting run freed, lesson still readable; PicoRuby's wasm blocked: the spinner says so |
| `ruby test/shell/run.rb` | **93 runs, 405 assertions, 0 failures** |
| the same tests on the desugared shell (all but jsg_test.rb) | pass |

Changes to the Playwright suites are boot assumptions only: after `#app` is
visible they wait for `ChunkyBridge.ready` (first load, reload, each new
context). Nothing they check was weakened. Two checks were added: *the lesson
is readable before the kernel has loaded* and *a run clicked while the kernel
loads runs once it is up*. The two `404` console lines are Sinatra's default
error page image (as before).

`test/shell/` (Minitest, CRuby, no browser, under a second):

- `stubs/js.rb` - PicoRuby's `js` for CRuby, copying its behaviour and its
  traps (pitfalls 4-7, 9, 14, 16, 18): a small DOM built from `index.html`'s
  body (innerHTML is parsed; `getElementById`, `querySelector(All)`,
  `closest` with tag/id/class/attribute/descendant selectors, dialogs),
  localStorage, location, history, a recording `ChunkyBridge`, `fetch`
  reading `html/`, a fake `storage.js` and CodeMirror, settled promises with
  `await`, and `Task` and callback blocks running with another `self`.
- `app_test.rb` (30 tests) - boot, kernel never ready, URL vs stored
  lesson, index clicks and modified clicks, hash routing and bad ids,
  workshop, language switch and fallback, progress file loaded, the run
  cycle (look, queue, double click, settle, run time), error/fail/pass
  bubbles, all-done, Alt+R, reset and its confirm, gems panel (chips from
  the cache manifest, installed marks, queued install, outcomes, escaping).
- `workspace_test.rb` (29) - the progress button and dialog (language,
  locked folder, download, loading a good and a bad file, close, backdrop),
  the workshop (starter file, last open file, new file, bad and taken
  names, name rules, typing saves, non-Ruby files, delete, download,
  renaming - the extension kept, the open file following, bad/taken names
  and Escape -, pictures and PDFs in place of the editor - a tiny picture
  pixelated, the PDF's Blob URL released, a picture the program writes, a
  picture downloaded as what it is -,
  stdin) and what the kernel asks for during a run (open path, snapshot,
  files written and deleted, save after the run, files changed elsewhere).
- `course_store_view_test.rb` (14) - on the real course from
  `test/lessons.json`.
- `jsg_test.rb` (11) - the sugar.
- `portability_test.rb` (17) - Prism scans of `html/shell/*.rb` for
  pitfalls 2, 6, 7, 10-12; each scan also runs on a bad sample so it cannot
  go blind.

Mutation check: reintroducing pitfalls 4, 5 and 7 in a copy of the shell
(`SHELL_DIR=...`) fails the suite (27 errors "Bad control character", the
boot test's "Method not found: section", the `task_self` scan and a
`NameError` from the Task).

## 10. Open issues and next steps

- **`storage.js` is still JavaScript**, deliberately: it overrides
  `Storage.prototype.setItem` synchronously (CRuby writes localStorage
  through it), walks folders with `for await`, and chains IndexedDB and
  File System Access promises with a serial queue and a debounce - an engine
  with a small API (`window.ChunkyStorage`), awkward from PicoRuby (no
  Hash/Array arguments, `await` only in Tasks, callbacks for every
  `onsuccess`). Porting it would add bridge code rather than remove any; its
  UI, which was the part worth having in Ruby, is ported.
- **Failure texts are not in `lessons.js` yet.** If CRuby does not come up
  (its loader fails, the wasm cannot be fetched or compiled, main.rb raises
  at boot - all surface as an unhandled rejection, which `bridge.js` turns
  into `chunky:kernel-failed`), the header says so in the page's language
  and waiting runs are freed; the three texts live in `App::KERNEL_FAILED`.
  If the shell never comes up, `bridge.js` replaces the spinner's text after
  20 s with a trilingual line, like the spinner's own. Both belong in the
  `ui` strings; `lessons.js` was left alone to keep the merge small. There
  is no timeout for a slow kernel download (on a slow line 10 MB may
  legitimately take minutes), and no retry button. Any other unhandled
  rejection before the kernel is up would also count as a kernel failure;
  the shell's own promises are settled at once for that reason (pitfall 17).
- **The `loading` UI string says "ca. 35 MB"**; gzipped it is 10 MB. Content
  change for `lessons.js` (all three languages).
- **Lazy vs eager kernel**: lazy is the default (section 6). A middle way to
  try: start CRuby when PicoRuby's wasm has *downloaded* rather than when
  the page is rendered, or `fetchpriority="low"` on an early preload.
- **Main-thread contention**: CRuby's ~1 s boot freezes the already visible
  page (clicks wait). Moving CRuby into a Worker would remove it but is a
  large change (DOM access from the kernel).
- **Parallel work on main**: a new lesson or cell helper that needs page
  work at *render* time (like `ensureThree` for 3D: an asset preload when a
  lesson opens) must now go into the shell's `render_lesson`; anything at
  *run* time (`show_pdf`, widgets) stays in `main.rb` and just works. The
  removed `main.rb` methods are listed in section 2; a merge conflict in one
  of them means the change belongs in `html/shell/`. Changes to
  `workspace_ui.js` on main must be redone in `shell/workspace.rb`.
- `docs/HANDOVER.md` and the README still describe the single-Ruby page;
  they need a section on the shell once this is merged.
- The kernel still uses ruby.wasm's bracket style; the jsg gem could be
  loaded there (section 8).
- `test/shell/stubs/js.rb` models PicoRuby as probed; a PicoRuby update can
  change behaviour the stub still copies. Re-probe on updates (and re-run
  `tools/patch_picoruby_loader.rb`, which aborts if the loader changed).
- The prototype was measured on one laptop in headless Chromium; not yet
  in Firefox/Safari, not on a phone. The folder API was tested through the
  origin-private file system (as before), not a real picker.

## 11. Merge recommendation

**Merge, after the PDF lesson has landed on main, with the lazy kernel as
it is** (moving the two failure texts into `lessons.js` on the way). The
gain is large and user-visible - a lesson readable in 0.4-1.0 s instead of
1.2-5.8 s, 1.4 MB instead of 10.7 MB before the first word - and the cost
is small and bounded: +0.9 MB of total transfer, a first run 0.1 s later
(0.5-0.7 s on a 20 Mbit/s line, 0.3 s with `?kernel=eager` - worth
revisiting once real users' lines are known), about a fifth more code for
the bridge and the split. Every existing check still passes, the kernel change is surgical
(`run_cell` untouched but for one line), and the new code has its own fast
tests that model PicoRuby's traps. The workshop UI port is its own commit:
it passes the same 37 progress checks as the JavaScript it replaces, and
can be merged with the rest or held back without affecting it (restore
`workspace_ui.js` and its script tag, drop `workspace.rb` from the
manifest). Before merging: rebase onto main, rerun the five suites plus
`ruby test/shell/run.rb`, move any render-time additions from main.rb into
the shell and any `workspace_ui.js` changes into `workspace.rb`
(section 10), update HANDOVER, and deploy with
`ruby tools/patch_picoruby_loader.rb --check` and
`ruby tools/compress_assets.rb --check` green.
