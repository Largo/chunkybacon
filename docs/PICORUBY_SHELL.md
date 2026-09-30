# The page on PicoRuby, the cells on CRuby - a prototype

Branch `picoruby-shell`, based on `main` at 8fafae1 (before the PDF lesson).
Written 2026-09-30. Nothing here is live: the branch is a prototype and this
is its report.

**In one paragraph.** The page itself - header, index, lesson text and
editors, language switch, routing, Chunky's bubble, reset, the gems panel -
now runs as Ruby on [PicoRuby.wasm](https://github.com/picoruby/picoruby)
4.0.3 (0.9 MB gzipped), so a lesson can be read **0.4 s** after the page is
requested instead of 1.2 s, and **0.9 s instead of 6.1 s** on a 20 Mbit/s
line. `main.rb` stays on CRuby ruby.wasm as the *kernel*: it runs cells,
checks, gems and every widget, loads in the background, and a Run clicked
before it is ready waits for it. The first cell run comes 0.2-0.3 s later
than today (or at the same time with `?kernel=eager`, at the cost of 0.16 s
of readability on a slow line). All existing suites pass (with two new
browser checks), a Minitest suite covers the shell under CRuby, and a
PicoRuby port of the jsg idea is in use - though on PicoRuby it saves only
about 2 % of tokens, because PicoRuby's own interop already does most of
what jsg adds to ruby.wasm. Recommendation (section 11): merge it behind the
current behaviour after the PDF lesson has landed, keeping the lazy kernel.

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
   │ lessons.js  CodeMirror  storage.js  workspace_ui.js  (plain JS)   │
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
| lesson done list (`chunky_done`), `chunky_lang`, `chunky_current` | yes | | |
| running cells, checks (`check_exercise`), `=>` output, cell code keys | | yes | |
| gems: installing, installed list | chips, button, bubble | `BrowserGems` | |
| IRB, mini browser, 3D, Shoes, file explorer, downloads, workshop runs | | yes | |
| progress dialog, workshop file panel, folder, progress file | | | `storage.js`, `workspace_ui.js` (next phase: shell) |

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
   spinner off, `#app` on, the whole page rendered, the bubble, then
   `ChunkyBridge.shellReady()` and a Task that fetches the gem cache's
   manifest for the chips.
5. `shellReady()` adds `browser.script.iife.js`; CRuby downloads, compiles,
   runs `main.rb` (still `<script type="text/ruby">`), whose
   `ChunkyApp.new` reads `ChunkyBridge.state`, installs its listeners and
   calls `ChunkyBridge.kernelReady(installed gems)`.
6. Runs and installs asked for meanwhile go to the kernel, in order; the
   header's "Ruby wird geladen …" (`#kernelStatus`) disappears.

`?kernel=eager` in the URL starts step 5 at step 2 instead (for comparison,
section 6).

## 2. The bridge

`html/shell/bridge.js` (about 120 lines, half of them comments). Neither Ruby calls into the
other: the shell calls `ChunkyBridge.*` with plain values (PicoRuby can pass
strings, numbers, booleans and nil - not Hashes, Arrays or Symbols), the
kernel listens for `chunky:*` events on `window` and answers through
`ChunkyBridge.*`, whose answers reach the shell as `chunky:*` events.

| call | by | does |
|---|---|---|
| `setState(lang, lesson, workshop)` | shell, on every lesson render | stores `state`, `seq += 1`, drops queued runs, sends `chunky:lesson` |
| `reset()` | shell, lesson reset | `seq += 1`, sends `chunky:lesson` |
| `run(idx)` → `true` / `false` | shell, Run / Shift+Enter / Alt+R | kernel up: `chunky:run` after the next paint (`afterPaint`); else queued. Returns whether it went now |
| `install(name)` → `true` / `false` | shell, gem chip / button | `chunky:install` after the next paint, or queued |
| `shellReady()` | shell, after the first render | `chunky:shell-ready`, starts the kernel |
| `kernelReady(installedJson)` | kernel, end of `ChunkyApp#initialize` | `ready = true`, `chunky:kernel-ready`, `chunky:gems`, then the queue |
| (none: an unhandled rejection before `ready`) | CRuby's loader | `failed = true`, queue dropped, `chunky:kernel-failed {reason}` |
| `ran(idx, outcome, elapsed)` | kernel, after every run | `chunky:ran {idx, outcome: ok/error/pass/fail, elapsed}` |
| `gems(installedJson)` | kernel, after runs and installs | `chunky:gems {installed}` |
| `installed(name, ok, message)` | kernel, panel install | `chunky:installed {name, ok, message}` |
| `ready`, `state` | both | `state = {lang, lesson, workshop, seq}`; the kernel reads it at boot |

| event | to | detail |
|---|---|---|
| `chunky:run` | kernel | `{idx, lang, lesson, workshop, seq}` |
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
| `html/shell/app.rb` | `App`: state, events, routing, rendering, the run cycle, gems panel |
| `html/shell/boot.rb` | starts the page |
| `html/shell/bridge.js`, `html/shell/loader.js` | section 2, boot step 3 |
| `html/assets/picoruby/` | the runtime: `init.iife.js` (patched), `picoruby.js`, `picoruby.wasm`, `.gz` copies, `PICORUBY_VERSION.txt`, `NOTICE.md` (MIT, checksums) |
| `tools/patch_picoruby_loader.rb` | `text/ruby` → `text/picoruby` in PicoRuby's loader, anchor-checked, idempotent, `--check` |
| `tools/shell_metrics.rb` | section 7's tables; `--desugar DIR` writes and tests the sugar-free shell |
| `tools/measure_load.mjs` | section 6's measurements |
| `test/shell/` | `run.rb`, `harness.rb`, `stubs/js.rb`, four `*_test.rb` (section 9) |
| `test/make_lessons_json.js` | writes `test/lessons.json` (the README's `node -e` line as a file) |
| `test/boot_failure_test.mjs` | Playwright: what the page says when CRuby or PicoRuby cannot load |
| `.gitattributes` | the runtime's bytes are never line-ending-converted (its `.gz` and checksums must match) |

Changed: `html/main.rb` (1298 → 963 lines; section 2), `html/index.html`
(preloads, `#kernelStatus`, script order, spinner text), `html/assets/app.css`
(`.kernel-status`), `tools/compress_assets.rb` (checks the runtime's `.gz`),
`THIRD_PARTY_NOTICES.md` (PicoRuby), `test/browser_test.mjs` and
`test/progress_test.mjs` (wait for the kernel; section 9). `nginx.conf` needs
no change: `.js`/`.rb` get `no-cache` and gzip as before, `picoruby.wasm`
and `picoruby.js` go out as their `.gz` (`gzip_static`), `manifest.txt` is
fetched with `cache: "no-cache"` by the loader.

## 4. Running, testing, measuring

```sh
# the runtime (bundled with the create-jobrouter-custom-application skill,
# checksum-verified, no download), then the loader patch
ruby <skill dir>/scripts/install_picoruby.rb html
cp <skill dir>/assets/picoruby/NOTICE.md html/assets/picoruby/
ruby tools/patch_picoruby_loader.rb            # --check to verify
ruby tools/compress_assets.rb --check          # the .gz copies match

node test/make_lessons_json.js
ruby test/check_harness.rb && ruby test/gems_harness.rb
ruby test/shell/run.rb                          # the shell, under CRuby
ruby tools/shell_metrics.rb --desugar tmp/desugared_shell
BASE=http://127.0.0.1:18011/ node test/browser_test.mjs
BASE=http://127.0.0.1:18011/ node test/progress_test.mjs
BASE=http://127.0.0.1:18011/ node test/boot_failure_test.mjs
BASE=http://127.0.0.1:18011/ LABEL=prototype node tools/measure_load.mjs
```

The install script is idempotent but rewrites `init.iife.js` from the
bundle: run the patch after it. The two Playwright suites and the
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
| 13 | `promise.then(fn)` | `ArgumentError: wrong number of arguments` (a Ruby `then` answers) | not needed yet; `promise.await` inside a Task works | - |
| 14 | `JS::Object#typeof` | returns a Symbol (`:function`), ruby.wasm returns a String | jsg.rb compares with `:function` | jsg_test |
| 15 | NUL in a string argument | truncates it (C strings) | - | - |

What works and was relied on: `sync: true` + `preventDefault`, `Module#prepend`
on `JS::Object` (with `super` into the C `method_missing`), Ruby values from
property reads, `nil` for a JS `null` from a call (`getElementById`) and
`JS::Object#nil?`, `Array#index` with a block, heredocs, `format`, `%()`,
endless defs, `Kernel#eval`, `fetch` + `to_binary` inside a Task, UTF-8
through the bridge both ways ("Grüsse 日本語 🦊" intact), JavaScript
exceptions arriving as rescuable `RuntimeError`s. Probed for the next phase
(section 10): `JS::Object.register_callback` blocks called synchronously by
JavaScript with arguments and returning Strings, Integers, true or nil;
`promise.await` inside a Task; `sleep_ms` in a Task (0 ms ≈ 5 ms).

## 6. Load-time measurements

`tools/measure_load.mjs`, headless Chromium (Playwright 1.62.1) on the
development laptop, local dev server with nginx's gzip behaviour (the
`.wasm.gz` files, text gzipped on the fly); baseline = the same server on a
copy of `html/` at 8fafae1. Fresh browser context per run (cold cache),
median of 3. *readable*: the lesson's `<h2>` is laid out (next frame);
*first run*: `#cell-out-1` of `#hallo` shows `=> 2`, its Run button clicked
by the page itself the moment the button exists. Throttling: CDP
`Network.emulateNetworkConditions`, 20 Mbit/s down, 40 ms latency.

| site | network | readable | kernel ready | first run | MB until readable | MB total | requests |
|---|---|---|---|---|---|---|---|
| baseline | unthrottled | 1221 ms | - | 1256 ms | 10.66 | 10.72 | 23 |
| **prototype** | unthrottled | **408 ms** | 1396 ms | 1446 ms | **1.37** | 11.64 | 37 |
| prototype `?kernel=eager` | unthrottled | 437 ms | 1443 ms | 1482 ms | 1.41 | 11.64 | 37 |
| baseline | 20 Mbit/s, 40 ms | 6061 ms | - | 6099 ms | 10.66 | 10.72 | 23 |
| **prototype** | 20 Mbit/s, 40 ms | **941 ms** | 6396 ms | 6432 ms | **1.37** | 11.64 | 37 |
| prototype `?kernel=eager` | 20 Mbit/s, 40 ms | 1101 ms | 6055 ms | 6106 ms | 1.41 | 11.64 | 37 |
| baseline | repeat visit | 1131 ms | - | 1168 ms | (10.05) | (10.05) | 23 |
| **prototype** | repeat visit | **335 ms** | 1204 ms | 1246 ms | 0.00 | (10.05) | 37 |

Single runs (readable / first run, ms): baseline 1332/1359, 1170/1204,
1221/1256 and 6324/6361, 6016/6050, 6061/6099; prototype 408/1688, 419/1446,
392/1314 and 936/6432, 941/6505, 943/6396; eager 558/1585, 401/1382,
437/1482 and 1119/6154, 1101/6106, 1085/6088; repeat visits 1127/1163,
1137/1168, 1131/1171 vs 339/1228, 320/1333, 335/1246. First contentful paint
(the spinner) is the same unthrottled (132 vs 128 ms) and 90 ms later at
20 Mbit/s (304 vs 396 ms: the runtime's preloads share the line with the
spinner's fox and fonts) - irrelevant next to the lesson text arriving
5 s sooner.

Bytes by kind (prototype, cold): PicoRuby runtime 907,622, shell files
15,900 (all seven `.rb`, manifest, bridge and loader, gzipped), CRuby
10,209,827 (wasm, loader, main.rb and its files, the minitest gem), common
504,904 (HTML, lessons.js, CodeMirror, CSS, fonts, fox). The baseline's
common part is the same; the prototype adds the 0.9 MB runtime.

Reading it:

- **Readable: 3× sooner unthrottled, 6.4× sooner at 20 Mbit/s**, and
  before a tenth of the bytes. What remains on the critical path at
  20 Mbit/s is 1.37 MB: the 0.9 MB runtime, the fonts, CodeMirror and
  lessons.js.
- **First run: +190 ms unthrottled, +333 ms at 20 Mbit/s** with the lazy
  kernel, because CRuby starts only once the page is up: the 0.9 MB runtime
  comes first. With `?kernel=eager` the first run matches the baseline
  (6106 vs 6099 ms) and the page is readable 160 ms later than with the lazy
  kernel (1101 vs 941 ms): the two downloads share the line.
- **Repeat visits** cannot be measured fully here: Playwright's contexts keep
  only an in-memory cache and download the 10 MB `ruby+stdlib.wasm` again
  (both sites, the bracketed numbers); a real browser's disk cache would
  not. The shell part is real: readable in 335 ms, 0 bytes.
- Absolute times are this laptop's; the ratios are the point. CRuby's boot
  (compile + `main.rb` + minitest from the cache) is ~1 s of main-thread work
  in both versions, and while it runs the shell's page does not react to
  clicks (it still scrolls) - the same freeze the baseline had behind its
  spinner.

## 7. Code size and tokens

`tools/shell_metrics.rb`. No tokenizer offline: bytes, lines, lexical tokens
(`Prism.lex` for Ruby without comments/newlines, a regex split for JS) and
an estimate at 3.5 bytes per model token; "code" = without comments and
blank lines (the house style comments generously). "Before" is 8fafae1.

**The frontend before and after** (code bytes / lexical tokens / est. model tokens):

| | before | after |
|---|---|---|
| `main.rb` | 36,137 / 7,581 / 10,325 (page + kernel) | 25,121 / 5,109 / 7,177 (kernel) |
| `shell/*.rb` (7 files, jsg.rb included) | - | 18,995 / 4,108 / 5,427 |
| `shell/bridge.js` + `loader.js` | - | 3,854 / 964 / 1,101 |
| `storage.js` + `workspace_ui.js` (unchanged) | 27,883 / 7,484 / 7,966 | the same |
| `index.html` inline JS | 5,414 / 1,243 / 1,547 | 5,414 / 1,243 / 1,547 |
| **total** | **69,434 / 16,308 / 19,838** | **81,267 / 18,908 / 23,219** (+17 % bytes, +16 % tokens) |

With comments: 85,600 → 106,031 bytes, 2,329 → 2,908 lines.

**What left main.rb vs what does that job now:** 11,016 code bytes / 2,472
lexical tokens left `main.rb`; the shell is 18,995 / 4,108, with the bridge
22,849 / 5,072. The difference is not the language: **like for like** - the
20 methods that do the same job under the same names (`render_*`,
`show_bubble`, `select_lesson`, `switch_lang`, `reset_lesson`, routing,
`start_cell_run`, `settle_cell`, `replay`, `show_run_time`, `cell_parts`,
plus the `View` helpers they call) - the code is the same size:

| same 20 methods | code bytes | lexical tokens | est. tokens |
|---|---|---|---|
| main.rb before (CRuby, js gem: `el[:x]`, `.to_s`, `js_null?`) | 8,278 | 1,802 | 2,365 |
| shell, PicoRuby's plain interop | 8,767 | 1,752 | 2,505 |
| shell, with the jsg-style sugar (as shipped) | 8,629 | 1,690 | 2,465 |

(+4 % bytes, -6 % lexical tokens old → shipped.) The extra code is the
split itself: the event wiring for 14 listeners, the kernel's answers
(`ran`, `gems_changed`, `installed`, `exercise_passed` - formerly inside
`run_cell`/`check_exercise`), the queue-aware install, the kernel status,
the gem list fetched in a Task, `Course`/`Store` wrappers around the
bridge, `jsg.rb` (1,375), and `bridge.js`/`loader.js` (3,854). For an agent
or a person working on the page, the relevant context shrank: the shell
alone is ~5.4k estimated tokens, where the page code used to sit inside a
10.3k-token `main.rb` next to the gem installer, IRB, 3D and Shoes.

Per shell file (code bytes / lexical tokens): `app.rb` 12,171 / 2,603,
`view.rb` 3,161 / 522, `jsg.rb` 1,375 / 376, `store.rb` 740 / 199,
`course.rb` 738 / 193, `support.rb` 488 / 139, `boot.rb` 322 / 76.

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
`tools/shell_metrics.rb --desugar`; the result passes the same app, course/
store/view and portability tests, so it is the same program):

| shell without jsg.rb | code bytes | lexical tokens | est. tokens |
|---|---|---|---|
| PicoRuby's plain interop | 17,866 | 3,818 | 5,105 |
| with the sugar (as shipped) | 17,620 | 3,732 | 5,034 |
| **saved** | **246 (1.4 %)** | **86 (2.3 %)** | **~70** |

`jsg.rb` itself costs 1,375 code bytes (~390 tokens), so on a shell this
size it does not pay for itself in bytes. Its value is elsewhere: one
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
| `ruby test/check_harness.rb` | ALL CHECKS OK (37 lessons × de, en, ja) |
| `ruby test/gems_harness.rb` | ALL GEM CHECKS OK |
| `test/browser_test.mjs` | **130/130** (the 128 checks plus two new ones) |
| `test/progress_test.mjs` | **37/37** |
| `test/boot_failure_test.mjs` (new) | **5/5** - CRuby's wasm blocked: header message, waiting run freed, lesson still readable; PicoRuby's wasm blocked: the spinner says so |
| `ruby test/shell/run.rb` | **72 runs, 326 assertions, 0 failures** |
| the same tests on the desugared shell (without jsg_test.rb) | pass |

Changes to the Playwright suites are boot assumptions only: after `#app` is
visible they wait for `ChunkyBridge.ready` (first load, reload, each new
context). Nothing they check was weakened. Two checks were added: *the lesson
is readable before the kernel has loaded* and *a run clicked while the kernel
loads runs once it is up*. The two `404` console lines are Sinatra's default
error page image (as before).

`test/shell/` (Minitest, CRuby, no browser):

- `stubs/js.rb` - PicoRuby's `js` for CRuby, copying its behaviour and its
  traps (pitfalls 4-7, 9, 14): a small DOM built from `index.html`'s body
  (innerHTML is parsed; `getElementById`, `querySelector(All)`, `closest`
  with tag/id/class/attribute/descendant selectors), localStorage, location,
  history, a recording `ChunkyBridge`, `fetch` reading `html/`, and `Task`
  running its block with another `self`.
- `app_test.rb` (30 tests) - boot, kernel never ready, URL vs stored lesson, index clicks and
  modified clicks, hash routing and bad ids, workshop, language switch and
  fallback, progress file loaded, the run cycle (look, queue, double click,
  settle, run time), error/fail/pass bubbles, all-done, Alt+R, reset and its
  confirm, gems panel (chips from the cache manifest, installed marks,
  queued install, outcomes, escaping).
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

- **Not done: `storage.js` / `workspace_ui.js` in Ruby.** The next phase.
  Suggested split: `workspace_ui.js` (dialog and file panel, 367 lines of
  DOM building) becomes shell Ruby first - it is UI, the shell's job, and
  `test/progress_test.mjs` (37 checks) covers it closely; `storage.js`
  stays a JavaScript engine behind a small API for now, because it overrides
  `Storage.prototype.setItem` synchronously (CRuby writes through it),
  iterates directories with `for await`, and chains IndexedDB and File
  System Access promises - all awkward from PicoRuby (Tasks, `sync: true`
  handlers that must not suspend, no Hash arguments). What the UI port
  needs: CodeMirror `change` handlers (`JS::Object.register_callback`),
  a debounce (a Task with `sleep_ms`, not `setTimeout` from a sync
  handler), promise results via Tasks, and `el(...)` builders.
- **Failure texts are not in `lessons.js` yet.** If CRuby does not come up
  (its loader fails, the wasm cannot be fetched or compiled, main.rb raises
  at boot - all surface as an unhandled rejection, which `bridge.js` turns
  into `chunky:kernel-failed`), the header says so in the page's language
  and waiting runs are freed; the three texts live in `App::KERNEL_FAILED`.
  If the shell never comes up, `bridge.js` replaces the spinner's text after
  20 s with a trilingual line, like the spinner's own. Both belong in the
  `ui` strings; `lessons.js` was left alone to keep the merge small. There
  is no timeout for a slow kernel download (on a slow line 10 MB may
  legitimately take minutes), and no retry button.
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
  of them means the change belongs in `html/shell/`.
- The kernel still uses ruby.wasm's bracket style; the jsg gem could be
  loaded there (section 8).
- `test/shell/stubs/js.rb` models PicoRuby as probed; a PicoRuby update can
  change behaviour the stub still copies. Re-probe on updates (and re-run
  `tools/patch_picoruby_loader.rb`, which aborts if the loader changed).
- The prototype was measured on one laptop in headless Chromium; not yet
  in Firefox/Safari, not on a phone.

## 11. Merge recommendation

**Merge, after the PDF lesson has landed on main, with the lazy kernel as
it is** (moving the two failure texts into `lessons.js` on the way). The
gain is large and user-visible - a lesson readable in
0.4-0.9 s instead of 1.2-6 s, 1.4 MB instead of 10.7 MB before the first
word - and the cost is small and bounded: +0.9 MB of total transfer,
0.2-0.3 s later first run (or none with `?kernel=eager`), +17 % code
through the bridge. Every existing check still passes, the kernel change is
surgical (`run_cell` untouched but for one line), and the new code has its
own fast tests that model PicoRuby's traps. Keep `storage.js` /
`workspace_ui.js` as they are for the merge and port the workspace UI in a
follow-up. Before merging: rebase onto main, rerun the four suites plus
`ruby test/shell/run.rb`, move any render-time additions from main.rb into
the shell (section 10), and deploy with `ruby tools/patch_picoruby_loader.rb
--check` and `ruby tools/compress_assets.rb --check` green.
