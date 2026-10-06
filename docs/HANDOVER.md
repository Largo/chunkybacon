# Handover: Ruby lernen mit Chunky Bacon

Everything you need to run, change and extend the site. The README says
what the site is; this document says how it works and where the traps are.
Work in progress - what is unfinished, and in what state - is in
`docs/OPEN_WORK.md`.
Last updated 2026-10-06 (57 lessons in German, English and Japanese).

## 1. Where it runs

| | |
|---|---|
| Live | https://chunkybacon.idogawa.com/ (behind the host's reverse proxy); the host's address and paths are kept outside the repository |
| Host | container `chunkybacon` (nginx:1.27-alpine) |
| Checkout on the host | this repo, branch `main` |
| GitHub | https://github.com/Largo/chunkybacon (public) |

`docker-compose.yml` bind-mounts `html/` read-only into the container and
`nginx/` as its `conf.d` (the folder, not the file: git replaces a file on
update, and a single-file mount would keep serving the old one). Consequences:

- **Saving a file under `html/` is a deploy.** There is no build step and no
  restart. nginx sends `Cache-Control: no-cache` for html/rb/js/css/json, and
  `index.html` forces `cache: "no-cache"` on the `.rb` fetches, so a normal
  reload picks up the change.
- **Pushing to `main` is a deploy.** GitHub tells the host about every push
  (a webhook; it also checks by itself every few hours), and within seconds
  the host moves its checkout to `origin/main` and reloads nginx (only if
  `nginx -t` passes; otherwise the old config keeps running).
- **Changing `nginx/default.conf`** by hand on the host needs `docker exec chunkybacon nginx -t && docker exec chunkybacon nginx -s reload`.
- **Compression**: nginx gzips text on the fly; `ruby+stdlib.wasm` goes out
  as the `ruby+stdlib.wasm.gz` next to it (`gzip_static`, 33 → 10 MB). That
  `.gz` must match the wasm: `ruby tools/compress_assets.rb --check`
  (`tools/update_ruby_wasm.rb` rewrites it).
- The gem proxy's disk cache lives in the named volume `gemcache`.

The upstream test `cd test && node browser_test.mjs` runs against the live
port by default; see §8 for a private dev copy.

## 2. Repository layout

```
html/
  index.html            the page, JS helpers both Rubies call (fetch*Sync,
                        ensureThree, afterPaint, cell editors), import map
  shell/                THE PAGE, on PicoRuby (§2a): app.rb, course.rb,
                        view.rb, router.rb (addresses), store.rb, workspace.rb
                        (progress dialog, workshop file panel), jsg.rb,
                        support.rb, boot.rb;
                        manifest.txt (load order), loader.js, bridge.js
  assets/picoruby/      PicoRuby.wasm 4.0.3 (loader patched to text/picoruby;
                        tools/vendor_picoruby.rb) - the shell's, and the
                        PicoRuby lesson's second instance (§6m)
  browser.script.iife.js  ruby.wasm browser loader (patched: fetches OUR wasm)
  ruby+stdlib.wasm      Ruby 4.0 (@ruby/4.0-wasm-wasi 2.10.1), 32 MB
  main.rb               THE KERNEL, on CRuby: ChunkyApp runs cells, checks,
                        gems and widgets; ChunkyAudio (show_audio: a WAV's
                        samples, the wave as SVG); browser-environment fixups
  lessons.js            ALL lesson content + UI strings, as JSON in JS
  browser_gems.rb       gem installer + stdlib shims (socket, net/http, resolv)
  sandbox_sim.rb        virtual FS for relative paths, virtual sleep,
                        Fiber-based Thread, FileWatch (downloads)
  rack_playground.rb    show_browser: talks Rack to Sinatra/Roda apps, mock_get
  shoes_dom.rb          Lacci (Shoes) display service drawing into the page
  pycall.rb             require "pycall": PyCall's API over Pyodide, matplotlib's
                        backend for charts under the cell (§6d)
  numo_narray.rb        require "numo/narray": Numo in pure Ruby, for Rumale (§6e)
  sqlite3_sqljs.rb      require "sqlite3": the gem's API over sql.js, for Sequel (§6f)
  letter.js             show_letter's envelope: drawing, digits as 8x8 (§6e)
  ansi.rb               terminal colours in a cell's output: ANSI codes -> spans (§6g)
  object_graph.rb       show_objects: names and objects as boxes and arrows, an SVG (§6)
  turtle.rb             turtle { forward 100 }: Chunky draws, an animated SVG; checks read the path (§6)
  processing.rb         require "processing": the gem's API in pure Ruby, frames recorded (§6h)
  processing.js         a sketch's window: paints the frames, sends mouse and keys (§6h)
  game.rb               show_game: ChunkyGame, a grid game's cells, timers and keys in plain Ruby; runs headless for checks (§6)
  game.js               a game's grid: the loop on requestAnimationFrame, keys, focus, its live region (§6);
                        a ruby2d window's canvas (the same loop, draw commands, SDL key names)
  ruby2d.rb             require "ruby2d": ruby2d's C extension in Ruby (draw calls -> commands),
                        show handing the window to the page, the top-level mixing taken back (§6l)
  assets/ruby2d/        ruby2d 1.0.0's own Ruby files, joined unchanged (tools/vendor_ruby2d.rb), + LICENSE.md
  herb_bridge.rb        require "herb/herb": Herb's C parser, handed to its WebAssembly build (§6j)
  picoruby_lab.js       a lesson with "engine": "picoruby" (lesson 41): its runs and
                        IRB lines to a Web Worker, the time limits, chunky:picoruby (§6m)
  picoruby_worker.js    that worker: a second PicoRuby.wasm, its scheduler turned per request
  picoruby_lab.rb       the Ruby in the worker: a Task serving requests, a Sandbox per session
  picoruby_cells.rb     the kernel's side: PicoRuby's answers as values, errors, Prism's syntax errors
  assets/herb/          Herb's parser as WebAssembly + 3 files of @ruby/prism (tools/vendor_herb.rb)
  workshop.rb           the workshop's runs: project files as the virtual FS,
                        require_relative between them, gets, write-back
  autorun.rb            live runs (§6b): what may run by itself, the time
                        limit, taking back the files a rehearsal wrote
  step_recorder.rb      ⏯ step through (§6): a cell's run recorded line by
                        line - the line, each frame's variables, the output
  stepper.js            ⏯'s stepper below the cell: Chunky's sentence, the
                        variables, a slider; the line marked in the editor (§6)
  friendly_errors.rb    a failing cell's error explained in de/en/ja (§6);
                        its rules (_rules.rb) and texts (_messages.rb) apart
  storage.js            where the work lives: localStorage change times, the
                        progress file, a connected folder (File System Access)
  offline.js, sw.js     offline mode (§6c): the page's side and the service worker
  offline-files.txt     what the offline copy holds (tools/offline_files.rb)
  embed.html            one runnable cell for other sites' pages (§6k), served
                        sandboxed; embed-frame.js its inside (the kernel's
                        stand-ins), embed.css, embed-ui.js (generated: the ui
                        strings); embed.js turns <pre data-chunky> into it
  assets/               app.css, CodeMirror, three.js (vendored), the fox SVG,
                        fonts/ (self-hosted web fonts + fonts.css, OFL 1.1),
                        data/ (files lessons read: digits.csv)
  gems/cache/           .gem files + manifest.json (instant offline installs)
nginx/default.conf      static files + same-origin bridges (rubygems, ruby-lang),
                        the embed's sandbox (§7)
server/                 the optional Roda server (§7a): permalinks, /api, the bridges
docker-compose.yml
LICENSE                    MIT for the code; course content is CC BY-SA 4.0 (README)
THIRD_PARTY_NOTICES.md     bundled components and their licenses - update it
                           with the gem cache, the wasm or the vendored assets
tools/build_gem_cache.rb   regenerates html/gems/cache/
tools/update_ruby_wasm.rb  updates the wasm + loader from npm
tools/compress_assets.rb   the .gz copies nginx serves (the wasm runtimes)
tools/vendor_pyodide.rb    Pyodide + pandas, sympy, scikit-learn, matplotlib into html/assets/pyodide/ (§6d)
tools/vendor_sqljs.rb      sql.js (SQLite in WebAssembly) into html/assets/sqljs/ (§6f)
tools/build_box_font.rb    html/assets/fonts/chunky-box-drawing.woff, box drawing for the code font (§6g)
tools/vendor_herb.rb       Herb's WebAssembly parser into html/assets/herb/ (§6j)
tools/vendor_ruby2d.rb     ruby2d's Ruby files into html/assets/ruby2d/ruby2d.rb, the .gem checked against rubygems.org's SHA-256 (§6l)
tools/offline_files.rb     html/offline-files.txt - rerun after adding/removing a file
tools/dev_server.rb        nginx's stand-in without Docker: html/, the bridges, the same headers and rules (§7)
tools/build_embed_ui.rb    html/embed-ui.js from lessons.js's ui strings (--check: current?)
tools/make_embed_url.rb    a cell's address for some code: the URL, an <iframe>, a "▶ Run" link (§6k)
tools/patch_picoruby_loader.rb  PicoRuby's loader: text/ruby -> text/picoruby
tools/vendor_picoruby.rb   PicoRuby.wasm from npm into html/assets/picoruby/ (checksums,
                           loader patch, .gz, NOTICE.md); --check: offline, files as recorded
tools/measure_load.mjs, tools/shell_metrics.rb  load times, code size (PICORUBY_SHELL.md)
tools/render_social_cards.mjs  docs/social/card.html -> twitter-card.png (1600x900: X,
                           Bluesky, Mastodon, README) and github-social.png (1600x800:
                           GitHub social preview, og:image); fills in the lesson count,
                           so rerun it when that changes. og:image points at GitHub's
                           raw copy - switch it to the site's own URL once a domain is bound
docs/social/               the social cards: card.html (source) and the two PNGs
gem/chunky_bacon/          the companion gem: the course's helpers on a computer,
                           the fox, `chunkybacon run` (§10a)
gem/chunkybacon/, gem/chunky-bacon/  its alias gems (like rubyllm -> ruby_llm)
test/check_harness.rb      every lesson offline under CRuby
test/lint_lessons.rb       lessons.js content linter (lint_allow.txt: accepted
                           findings; lint_lessons_test.rb: its tests)
test/friendly_errors_harness.rb  70 beginner mistakes (friendly_errors_corpus.rb)
                           against the explanations; friendly_errors_robustness.rb
test/gems_harness.rb       gem installer offline under CRuby
test/shell/run.rb          Minitest for the shell, on a stub of PicoRuby's js
test/autorun_test.rb       live runs under CRuby: runnable?, the time limit
test/ansi_test.rb          ANSI colours to HTML under CRuby
test/object_graph_test.rb  show_objects under CRuby: walk, SVG, alt text, the gem's copy
test/turtle_test.rb        turtle graphics under CRuby: path, check helpers, SVG, texts, the gem's copy
test/game_test.rb          show_game under CRuby: the lesson's Snake by timer and keys, restart, the copies checks play
test/ruby2d_test.rb        ruby2d under CRuby: windows frame by frame, draw commands, keys, mouse, replayed copies, mixing, every cell of lesson 39
test/step_recorder_test.rb ⏯'s recorder under CRuby: steps, frames, hidden locals, caps, every cell of the stepper lessons
test/live_test.mjs         Playwright: live runs in a lesson and the workshop, a lesson without them
test/server_test.rb        the optional server under Rack::MockRequest
test/permalink_test.mjs    Playwright: permalinks, against the server (port 8012)
test/browser_test.mjs      Playwright end-to-end
test/progress_test.mjs     Playwright: progress file, workshop, folder (52 checks)
test/boot_failure_test.mjs Playwright: what the page says when a runtime fails
test/language_test.mjs     Playwright: which language a visitor gets (11 checks)
test/offline_test.mjs      Playwright: offline mode, behind a proxy it takes down
test/embed_test.mjs        Playwright: an embedded cell on another (made-up) site (§6k)
test/picoruby_test.mjs     Playwright: the PicoRuby lesson - cells, IRB, exercise, live runs, the stop (§6m)
test/dev_server_test.rb    the dev server's bridge rule and embed headers, and that nginx/default.conf says the same
test/make_lessons_json.js  writes test/lessons.json for the harnesses
docs/HANDOVER.md           this file
docs/PICORUBY_SHELL.md     the shell/kernel split in depth: bridge API,
                           PicoRuby's traps, measurements, jsg
```

## 2a. Two Rubies: the shell and the kernel

The page runs two Ruby VMs. **The shell** (`html/shell/*.rb`, PicoRuby.wasm,
0.9 MB gzipped, up in ~0.3 s) draws everything the learner reads: header,
index, lesson text and editors, language, routing, Chunky's bubble, the gems
panel, the progress dialog and the workshop's file panel. **The kernel**
(`html/main.rb`, CRuby's ruby.wasm, 10 MB gzipped) starts only after the
shell has drawn the page, and runs cells, checks, gems and widgets. A lesson
is readable in 0.4 s (1.0 s on a 20 Mbit/s line) instead of 1.2 s (5.8 s);
a Run clicked while the kernel loads waits and runs once it is up.

- `shell/loader.js` fetches the files in `shell/manifest.txt` and joins them
  into ONE `<script type="text/picoruby">` (PicoRuby runs every script tag as
  a concurrent task). PicoRuby's loader is patched to read `text/picoruby`,
  so it leaves `main.rb` (`text/ruby`) to CRuby's.
- `shell/bridge.js` is the only contact: the shell calls `ChunkyBridge.*`
  with plain values, the kernel listens for `chunky:*` events and answers
  through `ChunkyBridge.*` (table in PICORUBY_SHELL.md §2). It also parses
  `LESSONS_JSON` once into `window.LESSONS`: **never `JSON.parse` the lesson
  data in PicoRuby** - 35 s for 300 KB.
- **Where new code goes**: anything at lesson *render* time (an asset
  preload when a lesson opens, a new UI string on the page) belongs in the
  shell; anything at *run* time (`show_pdf`, widgets, checks) in `main.rb`.
- **PicoRuby is not CRuby** (PICORUBY_SHELL.md §5): no `\A`/`\z` in regexps,
  no `sort_by`/`group_by`/`each_slice`/`find_index`/`Struct`, no enumerator
  without a block, `NodeList#each` yields nothing. The Minitest suite runs
  under CRuby, so `test/shell/portability_test.rb` scans the shell for these.
- `?kernel=eager` in the URL starts CRuby with the page instead (for
  measuring; `bridge.js` makes it the default in one line).

Both Rubies drive the DOM in the style of [jsg](https://github.com/Largo/jsg).
In the shell, PicoRuby's own bridge already returns Ruby values
(`el.textContent`) and `shell/jsg.rb` adds the rest (`el.textContent = "x"`,
`el.hidden?`, `JSG.d`). The kernel loads the real gem from the cache at boot
(`BrowserGems.install("jsg")`, main.rb): `input.value`, `el.style.display =
"none"`, `$d.createElement("div").tap { ... }`, `$window.threeReady?`. What
jsg changes on ruby.wasm's `JS::Object`, for main.rb, shoes_dom.rb and
learners' cells alike:

- results come back as Ruby values: strings, `true`/`false`, **numbers as
  Float** (`.to_i` where an Integer is wanted), JS arrays as Arrays;
- JS `null` is `nil`: `el.closest(".x")` is nil when nothing matches, so
  `if widget` replaces the old `js_null?`;
- a property that is `undefined` raises `NoMethodError` - read optional ones
  with `obj[:prop]`, which jsg leaves as it was, like `call(:name, ...)`
  (three-rb uses only those two, so it is unaffected);
- a capitalized name without arguments is a constructor or namespace:
  `$window.URL.revokeObjectURL(url)`.

The two fetchers at the top of main.rb run before jsg is installed (they
install it), so they keep the plain style with `.to_s`.

## 3. Lessons

`html/lessons.js` is `window.LESSONS_JSON = JSON.stringify({ ui, lessons })`,
pretty-printed with two spaces. It round-trips through `JSON.parse` /
`JSON.stringify(d, null, 2)` byte-identically, so the safest way to edit
structure (insert a lesson, renumber) is a small node script that parses,
changes and rewrites it; prose edits can be done by hand.

```json
{ "id": "html",
  "section": { "de": "Grundkurs", "en": "Basics", "ja": "基礎コース" },   // optional: starts a group in the sidebar
  "files": { "digits.csv": "assets/data/digits.csv" },   // optional: files next to the code (§6e)
  "live": false,   // optional: no live runs in this lesson (§6b)
  "stepper": true, // optional: ⏯ beside ▶ on its code cells (§6)
  "engine": "picoruby", // optional: cells and IRBs run on PicoRuby.wasm, not CRuby (§6m)
  "de": { "title": "14. HTML parsen", "cells": [ ... ] },
  "en": { "title": "14. Parsing HTML", "cells": [ ... ] },
  "ja": { "title": "14. HTMLのパース", "cells": [ ... ] } }
```

A section opens a group in the sidebar's index and runs until the next one
(`View.nav_groups`); the group is named by its first lesson's id, which is
what `chunkyui_nav_closed` stores for a folded group. Give a section only to
lessons that start a real course - a lesson on its own belongs in "Ausflüge"
(side trips, 20-41), not in a group of one.

`"stepper": true` puts ⏯ (step through) beside every ▶ of the lesson but an
IRB's (`View.lesson_html`, `Course#stepper?`). It is on the Basics whose
cells are plain Ruby and short, where watching a run teaches something:
lessons 3-12 (variablen, strings, wenn, schleifen, arrays, hashes, methoden,
turtle, klassen, module) - assignments, a branch taken, a loop's passes,
a block's variable, a method called and returning, recursion. Not on
hallo and rechnen (one-line cells: one step), the IRB, nor on 14-19,
whose cells install gems, start servers or fetch from the web - nothing of
the learner's own to step through there. `test/step_recorder_test.rb`
records every code cell of the flagged lessons (de and en) and requires
them to be Basics; run it after flagging another.

The sidebar itself (`index.html` `#sidebar`, `shell/app.rb`, `app.css`): from
the top of the window to its foot with its own scroll; head with the course
count and a bacon progress strip, the workshop, the gems panel (folded, a
button like the workshop's; open, its chips scroll inside it), a search
over titles and section names (Enter opens the first hit, Escape empties
it), the groups with done counts. The fixed
`#sidebarToggle` puts it away on a wide screen (`chunkyui_sidebar`, a view
setting); at 820 px and below (`App::NARROW`, the same width as in app.css)
it is a drawer that a lesson, a tap beside it or Escape put away again.
The drawer is modal: opening it moves the focus to the workshop link, and
while it is out `.column` (header, lesson, footer) is `inert`
(`App#sidebar_expanded`, also when the window grows past NARROW); the
toggle and the skip link sit outside `.column` and stay reachable.

A language is whatever `ui` has a key for: the shell takes
the list from there, `index.html`'s `#langSelect` names them. German has its
own code (German names, Katze/Fuchs); **Japanese runs the English code** -
only the Ruby comments are translated, `check` is byte-identical to `en`, and
the harness checks `ja` with the English solutions. So a change to an English
code cell or check must be made in `ja` too (same cell, same code, comments
in Japanese). Japanese prose is です・ます体, hints are Chunky speaking
(casual); app.css adds Japanese fallback fonts under `:lang(ja)`.

Which language a visitor gets is decided in the browser, by
`shell/bridge.js` (`pickLang`, read by the shell as `ChunkyBridge.lang`), no
server involved:

1. `?lang=en` (or `de`, `ja`) in the address - for links in a given
   language. It is saved like a choice in the selector and removed from the
   address again, so a later switch is not undone by a reload.
2. the language chosen last time (`chunky_lang` in localStorage)
3. the first of the browser's preferred languages (`navigator.languages`,
   the list it also sends as `Accept-Language`) that the course has;
   `de-CH`, `de-AT` count as `de`
4. English

A detected language is not saved - only a choice is. `test/language_test.mjs`
covers the order; the other browser tests run with a `de-DE` locale because
they read the German interface.

Cells, per language:

| `t` | fields | meaning |
|---|---|---|
| `h` | `html` | prose block; `<div class='task'>` = the exercise text, `<div class='offweb'>` = "on your machine" box |
| `c` | `code` | runnable demo cell |
| `x` | `code`, `check`, `hint` | the ONE exercise cell of the lesson; `check` is Ruby evaluated in the lesson binding with locals `output`, `result`, `code`, `images`, `downloads`, `audios` (the WAVs `show_audio` got), `games` (copies of the games `show_game` made, to play headless) |

Rules that the code and tests rely on:

- `id` is stable and is the URL (`/#bigdecimal`); titles carry the number, so
  **inserting a lesson means renumbering every later title in all three
  languages** (see the script pattern in git history of lessons 18 and 21) -
  and the prose references like "lesson 22" / "Lektion 22" / 「レッスン22」.
- All cells of a lesson share one binding (notebook kernel). Demo and
  exercise names deliberately differ (Katze vs Fuchs) so a demo cannot
  satisfy the check.
- Checks accept output OR result; `puts` is never required.
- A local a check assigns lives on in the lesson's binding (an eval in a
  Binding keeps its new locals), and a block in the learner's next run
  then writes to it instead of to a variable of its own: the Snake
  check's `x, y = ...` once broke the learner's `x, y = fox.first`. Name
  a check's helpers as lambda or block parameters (`->(game, x = nil) {
  ... }.(games.last)`), as the Snake check does.
- `test/browser_test.mjs` asserts the lesson count (`'57 lessons in nav'`) -
  update it when adding one.
- `test/check_harness.rb` needs a `SOLUTIONS[id]` entry (one or more solution
  snippets for `de` and `en`; `ja` uses `en`'s) or it aborts. Its body runs in
  a method because lesson bindings capture top-level locals, and each
  language runs in a process of its own because top-level `def`/`class`
  outlive the binding (an English solution would let the Japanese starter
  pass). In `%()` literals write `\\d`.
- `test/lessons.json` is generated (gitignored):
  `node test/make_lessons_json.js`.
- Progress, language and per-cell code persist in `localStorage` - and from
  there in a progress file or a connected folder, see §6a.
- **Inserting, removing or moving cells** in a lesson, and rewriting a
  starter, is safe for learners' saved code: it is keyed by the cell's
  index and its starter's fingerprint (§6a), so it never lands in another
  cell. The price: a code cell whose index or starter changes opens with its
  starter, and the learner's version of it stays hidden in storage - and any
  cell inserted before a code cell, prose too, changes its index. So where
  the lesson reads as well either way, add cells after the code cells
  learners will have worked on, and leave starters alone for cosmetic fixes.
- `test/lint_lessons.rb` checks the mechanical half of these rules; after
  inserting a lesson run it with `--base=main` - every reference that now
  points at a different lesson is an error.

Helpers available in cells (defined in `main.rb`): `install_gem`,
`show_image` (a ChunkyPNG image, a PureJPEG encoder, PNG/JPEG/GIF/WebP bytes
or the name of a file the cell wrote), `show_objects(a: a, b: b)` /
`show_objects(binding)` (boxes and arrows, in `object_graph.rb`, §6),
`turtle { forward 100; right 90 }` (Chunky draws; `Turtle.from(images)` in a
check, in `turtle.rb`, §6),
`show_game(width:, height:) { |g| ... }` (a grid game the page drives; a
check plays `games`, in `game.rb`, §6),
`show_browser(app, path)` + `mock_get`, `show_irb`, `show_files`, `show_three(scene, camera, orbit:, &animate)`,
`show_shoes { ... }`, `show_letter(boxes:) { |digits| ... }` (§6e),
`download_file(data, name)`, `show_pdf(pdf)` (a file
name, PDF bytes, a Prawn or HexaPDF document), `show_audio(sound, rate:)`
(WAV bytes, a file name or an Array of samples, §6), `run_tests` (Minitest);
in `pycall.rb`: `show_plot(fig)` (a matplotlib figure, §6d).

## 4. Gems

### How installing works (`html/browser_gems.rb`)

`install_gem "x"` → `BrowserGems.install`:

1. `SUBSTITUTES` - `bigdecimal` → `bigdecimal-pure` (a dependency on the C
   extension installs the pure gem; also for a bare `require "bigdecimal"`).
2. `NATIVE_GEMS` fail fast - unless `builtin?` finds them in the wasm image
   (json, date, openssl … are compiled in and count as installed).
3. Source: `html/gems/cache/manifest.json` first, then rubygems.org through
   the nginx proxy (`/rubygems/api/v1/gems/<name>.json`, `/rubygems/gems/`).
   Runtime dependencies recurse, minus `OPTIONAL_NATIVE_DEPS` (ruby_pptx
   declares nokogiri but falls back to REXML).
4. The `.gem` (tar of metadata.gz + data.tar.gz) is unpacked in Ruby. A gem
   with `extconf.rb` is refused with a `NativeGemError` naming THAT gem (the
   UI says "X braucht Y"), except `PURE_FALLBACK_GEMS` (racc).
5. The whole gem is written to `/browser_gems/<name>-<version>/` on the wasm
   filesystem (writable memory; `BrowserGems.root`) and its gemspec
   `require_paths` go on `$LOAD_PATH`. From then on plain `require`,
   `require_relative`, `autoload`, `__dir__`, `Dir[]` and data files next to
   `lib/` work exactly as on disk. `POST_INSTALL_PATCHES` appends small fixes
   (lacci's changelog lookup).

Only the **shims** are still evaluated from memory: `Kernel#require` falls
back to them when the real feature fails to load. `socket`, `net/http`
(stdlib API over `Net::HTTP.transport`, wired in main.rb to sync XHR with a
host allowlist; GET/HEAD only), `net/https`, `resolv`. **Do not shim
`io/wait`**: the real `net/http` must keep failing so the shim wins.
`require_relative` in main.rb falls back to fetching the site's own files
over HTTP only for callers not on the filesystem (`caller_path` not starting
with `/`); stdlib and gems get a plain LoadError.

### The pure stand-ins

| gem | what | source of the cached file |
|---|---|---|
| `nokogiri-1.19.4.gem` | [nokogiri-pure](https://github.com/Largo/nokogiri-pure): Nokogiri with C ext, libxml2, libxslt, gumbo ported to Ruby, built from its `nokogiri.gemspec` (name `nokogiri`, so dependents resolve to it) | `tools/build_gem_cache.rb` builds it from a checkout (`NOKOGIRI_PURE=/path`, default `../../../../nokogiri-pure`) |
| `bigdecimal-pure-0.1.0.gem` | [bigdecimal-pure](https://github.com/Largo/bigdecimal-pure): BigDecimal on Rational, native preferred when present | downloaded from rubygems.org like any other gem |
| (no gem: a shim) | `sqlite3`: the sqlite3 gem's API on sql.js (`html/sqlite3_sqljs.rb`, §6f), so Sequel's SQLite adapter and other sqlite3 users run | `tools/vendor_sqljs.rb` |
| (no gem: a shim) | `ruby2d`: the gem's own Ruby (`html/assets/ruby2d/ruby2d.rb`) with its C extension stood in for by `html/ruby2d.rb` (§6l); `ruby2d` is in `NATIVE_GEMS`, so `install_gem "ruby2d"` finds it built in | `tools/vendor_ruby2d.rb` |

Nokogiri loads in about 2.3 s in Chrome (4 MB of Ruby compiled on the fly);
nokogiri-pure loads its files in a fresh Fiber because ruby.wasm compiles on
the JS native stack.

### Rebuilding the cache

`ruby tools/build_gem_cache.rb` downloads the LATEST version of every gem in
`GEMS` plus dependencies (`PINNED`, `EXTRA_DEPS`, `OPTIONAL_NATIVE_DEPS`
mirror the loader), builds `LOCAL_GEMS`, and rewrites `manifest.json`.
Because it takes latest versions it can move sinatra/roda/etc.; run the
three test suites afterwards. Manifest entries can also be added by hand
(`{version, file, deps}`) when only one gem changes.

### What works (probed in a real browser, 2026-09-30)

All 32 tried: nokogiri, loofah, sanitize, rails-html-sanitizer, premailer,
feedjira, rubyXL, roo, caxlsx, docx, reverse_markdown, kramdown, nori,
rouge, liquid, mustache, haml, slim, rqrcode, terminal-table, pastel, prawn,
asciidoctor, rspec-expectations, mail, i18n, zeitwerk, activesupport,
dry-types, parser, builder, tzinfo (+tzinfo-data). Network-using gems only
reach the hosts in `NET_HTTP_HOSTS` (ruby-lang.org, rubygems.org,
api.github.com). What cannot work: anything needing a C extension with no
pure stand-in (sqlite3, pg, ffi …), threads, sockets, subprocesses.

prawn and hexapdf are in the cache (lesson 22). prawn's ttfunk depends on
bigdecimal (→ bigdecimal-pure); hexapdf depends on openssl and strscan, both
compiled into the wasm (`NATIVE_GEMS` + `builtin?`; `tools/build_gem_cache.rb`
skips them as `BUILTIN`). In Chrome: both install from the cache in 0.5 s,
a 2-page Prawn PDF takes 0.12 s, HexaPDF open + stamp + write 0.17 s.

## 5. Browser-environment fixups (in `main.rb`, top)

Things ruby.wasm/WASI lacks that gems assume, each patched at boot:

- `/tmp` created and `Dir.tmpdir = "/tmp"` (WASI reports no permission bits,
  so stdlib's check rejects it).
- `File.chmod/chown/utime` swallow `ENOSYS`/`ENOTSUP` (rubyzip extracting).
- `Gem.find_files` stub and `rubygems/deprecate` (stripped `Gem` module);
  `ENV["MT_NO_PLUGINS"]` so a gem that loads full RubyGems (rubyzip) does
  not make Minitest pick up the image's bundled Minitest 6 over cached 5.x.
- Minitest 5.x from the cache with a serial `parallel_executor`.
- `sandbox_sim.rb`: relative paths go to an in-memory store behind
  `File`/`Dir`; absolute paths pass through. `File.binwrite` and
  `File.open`, what gems write with, are not redirected: their files land in
  the real working directory, so `File.read`/`exist?`/`delete` of a relative
  path fall back to a real file when the store does not have it (pure_jpeg
  asks `File.exist?` before `File.binread`). `sleep` is a virtual clock (a
  real sleep crashes the VM uncatchably); `Thread` is a Fiber scheduler that
  interleaves at sleep points. `FileWatch` snapshots both stores per cell run
  to offer downloads; it skips `BrowserGems.root` and `/tmp`. It compares
  contents, so it also notes what `File.open` and `File.binwrite` wrote: a run that
  writes the same bytes again (Prawn's PDFs are deterministic) still offers
  the file.
- Real `Module#autoload` works now that gems are files; the loader no longer
  hooks it.
- Every lesson, IRB widget and workshop file gets its binding from
  `TopLevel.binding`: compiled on its own, so it has a top-level scope of
  its own. Bindings made from `TOPLEVEL_BINDING` all share one, and a
  `using` in one cell then held for every later lesson and for main.rb
  itself (§6h).

## 6. Widgets and their traps

- **show_browser**: synthesises a Rack env; Sinatra's default 404 page
  references an external image (harmless console 404s in tests). The
  app's page sits in a shadow root of `.mb-view` (in a `.mb-page` div), so
  its `<style>` cannot restyle the course; its default CSS is
  `MB_PAGE_STYLE` in main.rb, and tests read `.mb-page` (Playwright's
  selectors pierce the shadow root, `textContent` of `.mb-view` is empty).
  A shadow root has no `<html>`/`<body>`, so `page_styles_scoped` points
  the page's `html`/`:root` selectors at `:host` and `body` at `.mb-page`
  (selectors only, not @-rules or values): Sinatra's 404 page is still
  grey and centred, inside the fake browser. Not handled: `html.x`
  (would need `:host(.x)`) and attributes on the `<body>` tag itself.
- **show_three**: one shared `Three::Backends::ThreeJS` for all stages
  (a second backend rebuilds a clean scene as defaults); canvas ids from a
  page-wide counter; contexts disposed on re-run/lesson change.
- **show_shoes** (`shoes_dom.rb`): Lacci allows one `Shoes::App` per process
  unless the display service claims multi-app support (it does); its
  `destroy` shuts down every app, so cells dispose only their own;
  `unsub_all_shoes_events` between lessons. Apps size to content unless
  `height:` is given.
- **show_irb**: continuation lines via a SyntaxError heuristic
  (`INCOMPLETE_RE`), `_` supported.
- **show_pdf**: an `<iframe>` on a Blob URL, so the browser's own viewer
  renders it. Headless Chromium and the Electron preview have no PDF viewer
  and show it blank - the tests check the bytes (`%PDF`), not the picture.
- **show_audio** (from `experiments/05-ruby-music`, lesson 37): WAV bytes,
  the name of a file the cell wrote (virtual or real), or an Array of
  samples in -1..1 (`ChunkyAudio.wav`, 16-bit mono, `rate:` 22,050) -
  an `<audio controls>` on a Blob URL like `show_pdf` (released on the
  cell's next run), above it the wave as an SVG `<img class="cell-wave">`:
  the whole sound as min/max bars and 12 ms around the loudest sample, so
  a sine, a square and a saw look like what they are. `ChunkyAudio.pcm`
  walks the RIFF chunks (first channel of a stereo file). The player is
  named "Ein Klang, 2,0 Sekunden" (`audioLabel`), which `#runStatus`
  reads (`App#picture_words`); the wave is `alt=""`, and as an `<img>`
  its "2.00 s" stays out of the status line's text. A check gets the
  WAVs as `audios`; `.wav` downloads as `audio/wav`; the workshop plays a
  WAV a program wrote (§6a). Computing sound is slow under the live
  runs' tracing (~36x in wasm), so the lesson has `"live": false` (§6b).
  Chromium decodes the WAVs headless too, so the tests read `duration`.
- **Running a cell** freezes the page (CRuby is synchronous); the shell
  paints the running look (stripe, dimmed editor, wobbling fox) and the
  bridge hands the run to the kernel after `afterPaint`; compositor-only CSS
  animations keep it moving. CRuby's ~1 s boot freezes the page the same way.
  Respects `prefers-reduced-motion`.
- **Keyboard and screen readers** (audit and measurements:
  `experiments/10-accessibility/NOTES.md`). An editor is named "Code,
  cell 2" (`codeLabel`, counting code cells only) with a hidden hint; Tab
  indents, Escape then Tab leaves it (`initCell` in index.html). Each Run
  button is named "Run cell 2" (`runCellLabel`, contains the visible "Run"),
  the exercise's says `aria-keyshortcuts="Alt+R"`. A run with ▶, Shift+Enter
  or Alt+R writes one line to `#runStatus` (`role=status`, `.sr-only`;
  `App#announce_run`): `ranOk`/`ranError` with the cell's output, cut at
  280 characters (an explained error by its headline only, `brief_output`),
  and for an exercise Chunky's bubble - emptied first, the
  text 50 ms later, so the same result twice is read twice. Live runs never
  write there, and `.cell-out` is no live region on purpose (live runs
  rewrite it while the learner types). The Run button keeps `disabled`
  while it runs (the tests check it), which drops the focus to `<body>`;
  `settle_cell` hands it back to the button if it was there
  (`@refocus`). After a lesson change (`select_lesson`, `open_workshop`:
  index, bubble link, search Enter, back/forward) the focus goes to the
  lesson's `<h2>` (`focus_heading`, `tabindex="-1"`), not on the first
  load. `#skipLink` is the first Tab stop (shown only when focused) and
  does the same; its `href="#lessonBody"` is never followed, as the router
  would take it for a lesson id. The language select has a hidden label
  (`langLabel`) and its options their own `lang`; the spinner's three
  texts are marked up the same way. Widgets (main.rb): the IRB history is a
  `role=log` live region and its input named (`irbInput`), the mini
  browser's status is live and its URL field named (`browserUrl`), a 3D
  canvas is `role=img` (`threeLabel`) and an animated scene stands still
  under `prefers-reduced-motion`, the letter's answer is mirrored into a
  live `.letter-answer`. The shell stub (`test/shell/stubs/js.rb`) keeps
  `document.activeElement` the way Chrome does.
- **A cell's error, explained** (`friendly_errors.rb`, from
  `experiments/04-friendly-errors`): below a failing cell a
  `.friendly-error` box in the lesson's language - a headline, the cell's
  line with a caret under the culprit (`.friendly-snippet`), what to do,
  and Ruby's own message folded away in a `<details>`. An ordered rule table
  (`friendly_errors_rules.rb`, first match wins) over the error, the cell's
  code and its binding (read with `local_variable_get` only, never `eval`);
  texts in `friendly_errors_messages.rb`. No rule, no box: the old
  `.cell-error` line stays (the learner's own `raise "…"`, JSON errors).
  `ChunkyApp#friendly_error` fetches the three files on the first error
  (~90 KB, ~55 ms, `fetchTextSync` + `eval` like `shoes_dom.rb`: a cell
  runs synchronously, where `require_relative` cannot fetch - so
  friendly_errors.rb only requires the other two when `FETCHED` is unset)
  and off the clock (`AutoRun.untraced`); an explanation takes 0-30 ms.
  A live run shows only the headline (`.friendly-brief`); one the time limit
  stopped shows the hint and below it all of it - why the loop never ends.
  An error inside another workshop file keeps Ruby's message with its
  "(helper.rb:3)". Traps: ruby.wasm's Prism **colours** a SyntaxError's
  code frame with ANSI codes (a Ruby in a pipe does not), so the rules read
  `Context#message`, stripped - the harness checks every syntax error both
  ways. And every cell is evaluated as `chunky.rb`: a method from an earlier
  cell reports that cell's line numbers, so the rules check that the line
  in the current cell looks right (a `def name` on it) before quoting it.
- **show_objects** (`object_graph.rb`, from `experiments/03-object-graph`):
  `show_objects(a: a, b: b)`, `show_objects(binding)` or
  `show_objects({ a: a }, max_depth: 2)` draws the names on the left and
  the objects behind them as boxes, an arrow per reference, in the style
  of Python Tutor (lessons 7, 8, 11: `dup` is shallow, two names for one
  object, `equal?`). All Ruby: a breadth-first walk by `__id__` gives a
  `Graph` (one box per object, however many arrows reach it; numbers,
  symbols, nil, true, false written inline; caps `max_depth: 6`,
  `max_nodes: 40`, `max_items: 10`, `max_text: 28`), a heuristic layout
  and an SVG with inline attributes (an `<img>` sees no page CSS or web
  fonts). The `Picture` goes through `show_image` (`to_data_url`), and
  app.css's `.cell-image[src^="data:image/svg+xml"]` keeps it at its
  own size - without that rule it would be the 160 px pixelated
  thumbnail meant for ChunkyPNG pictures. Like the turtle's drawings it
  has an alt text: `Graph#describe` ("a → #1, b → #1. #1 Array: …") travels
  as `alt_text` through `show_image` and `add_image(url, alt)`, and
  `#runStatus` reads it (`App#picture_words`); other pictures keep
  `alt=""`. Loaded at boot with `require_relative` (17 KB, ~10 ms to
  evaluate), so offline needs nothing beyond `offline-files.txt`.
  `show_objects(binding)` shows the cell's own locals and nothing of
  main.rb: the prototype hid `TOPLEVEL_BINDING.local_variables`
  (`app_path`, `numo`), but a cell's binding is `TopLevel.binding`, a
  scope of its own that never saw them - so the hiding is gone (it
  would have hidden a learner's own `numo`); `hide:` is still an
  option. The walk asks `Kernel` (`bind_call`) for class, ivars,
  `frozen?`, so a class overriding them or a `BasicObject` cannot break
  it. The companion gem ships a copy (`object_graph_test.rb` keeps it
  equal); the check harness requires the file, so the demo cells run
  there through its `show_image` stub.
- **Turtle graphics** (`turtle.rb`, from `experiments/06-turtle-graphics`,
  lesson 10): `turtle { ... }` instance_evals the block on a new `Turtle`,
  so `forward 100` needs no receiver and a learner's top-level `def`s
  (private methods of Object) can call it too; `turtle { |t| t.fd 10 }`
  works as well. Logo conventions: Chunky starts at (0, 0) looking up,
  headings are compass degrees, `right` turns clockwise, y grows upwards.
  The turtle **records** every step and turn; the picture is made from
  the record afterwards (`to_svg`: fitted to 460x400, strokes animated
  with `stroke-dasharray`, the fox along the path with SMIL
  `animateMotion`, still under `prefers-reduced-motion`), and so is the
  grading: `to_data_url` remembers a snapshot of the turtle by its data
  URL (the last 30), and `Turtle.from(images)` gives a check the turtles
  this run showed - `lines`, `edges` (straight runs joined), `corners`,
  `closed?`, `winding`, `regular_polygon?(n, side)`, `area`,
  `same_shape?`. No kernel change for the picture: it goes through
  `show_image` like `show_objects`, keeps its size by the same SVG rule,
  and its `alt_text` ("Chunky hat 4 Striche gezeichnet") is what
  `#runStatus` reads. `Turtle.lang` (set in `sync_state`) picks the
  language of that and of its errors (`Turtle::TooFar` after 100 000 steps
  or 200 000 turns - an endless loop or a recursion without a base case -
  and a refused colour; colours go into SVG attributes). A live run sets
  `Turtle.animations = false`: the picture is a still then, as an
  animation would start over at every pause in typing; ▶ animates.
  Loaded at boot (15 KB, ~6 ms to evaluate). The gem ships a copy
  (`turtle_test.rb` keeps it equal).
- **show_game** (`game.rb` + `game.js`, from `experiments/08-game-loop`,
  lesson 38, Chunky's Snake): `show_game(width: 20, height: 15) { |g| ... }`
  builds a `ChunkyGame` and runs the setup block at once, so its errors are
  the cell's (a block without `|g|` is instance_exec'd). In it:
  `g.cell(x, y, look)` / `g.cell(x, y)` (`:outside` beyond the edge),
  `g.clear`, `g.inside?`, `g.free_cells`, `g.on_key(:left) { }`,
  `g.on_click { |x, y| }`, `g.every(0.15) { }`, `g.status`, `g.game_over`.
  A look is a sprite name (`:chunky` 🦊, `:bacon` 🥓, `:wall` …), a colour
  (`:body` is Chunky's orange) or any emoji. Its traps:
  - **The page owns the loop.** CRuby runs on the page's thread, so a game
    can neither loop nor `sleep` (sandbox_sim's sleep is virtual: `loop {
    ...; sleep 0.15 }` would just hang). `mount_game` hands game.js a
    block, which game.js calls at most once per animation frame and only
    when a timer is due (the last answer's `next`) or events came in
    (`"k:left|c:3,4|r"`): one crossing each way, the events in as one
    string, the changed cells out as one JSON string; game.js touches
    only those cells. Its clock advances only while the game runs (at
    most 100 ms a frame), and Ruby catches up at most 3 runs per timer, so
    a pause or a sleeping tab never fast-forwards the game.
  - **It runs only while it has the focus and is not paused.** A click,
    or Tab and then Space/Enter, starts it; Esc pauses it and keeps the
    focus; Tab or a click elsewhere leaves it, paused. So the arrow keys
    never scroll the page or reach the editor, a live run mounts a game
    but never starts it (the lesson keeps its live runs, §6b), two games
    never both run, and nothing moves until the learner asks - that is
    its answer to `prefers-reduced-motion` too (nothing in its CSS
    animates). Role `application`, named "Spiel mit 20 × 15 Feldern"
    (`gameTitle`), described by `gamePlay` and `gameKeys`; the grid and
    the veil are `aria-hidden`. A polite live region inside
    (`.game-say`) says a changed status at most every 1.5 s, the end of a
    round and errors - never every tick (Snake sets the same status every
    round). `#runStatus` reads a game by its name, not its emoji
    (`App#brief_output`, `#picture_words`). `data-state` (paused, playing,
    over, error) and `data-over` are there for the tests.
  - **The time limit belongs to the running game.** A tick runs from the
    event loop, where no ▶ is running, so an endless loop in `every` would
    freeze the page for good. `GameGuard` (main.rb) is `AutoRun`'s
    mechanism - TracePoint `:line, :b_call, :c_call`, the clock read
    every 128 events, `AutoRun::Stopped` on the next event in the
    learner's file once it is late - switched on when the game starts running ("f:1" from game.js)
    and off when it stops ("f:0"); a step only moves the 1 s deadline
    (`GAME_TICK_LIMIT`, the message `gameTooLong`). Enabling a TracePoint
    per step instead costs 4-6 ms a step in ruby.wasm (CRuby
    re-instruments every loaded iseq); this way a Snake step costs ~2.3 ms
    with the guard and ~1 ms without (measurements in the experiment's
    NOTES).
  - **Keep game.rb's internals event-light**: under the guard the cost is
    TracePoint events, so no Ruby block per cell in what runs every tick
    (`clear` walks a Hash of the filled cells; `free_cells` walks all of
    them, but only when called).
  - **What stops a game**: a re-run of its cell (`dispose_games(idx)` in
    `run_cell`), another lesson or a reset (`sync_state`), game.js itself
    once its node has left the page, game over, an error in a tick (shown
    under the grid with its line), the time limit. A restart (click or
    Space after game over) runs the setup block again and empties what
    the last round left on the page. Each mount keeps the closure behind
    its JS function alive, as `show_letter` and `show_three` do.
  - **Checks play copies, under a time limit**: `games` holds
    `ChunkyGame#fresh` copies (the setup block once more), so a check's
    `press`/`advance` leaves the game below the cell at its start;
    `advance` runs every tick, uncapped. The check runs the learner's
    ticks at once, so `check_exercise` wraps it in
    `AutoRun.with_time_limit` (2 s) when there are games - without it an
    endless loop in a tick of the exercise cell froze the page. `puts` in
    a tick goes into a log under the grid.
  - The workshop takes the same path (the guard watches `Workshop.paths`)
    but has not been tried. The companion gem's `show_game` raises NotHere
    (a game on a computer: ruby2d or gosu, its message says).
- **ruby2d** (§6l, lesson 39): a ruby2d window is a game to the page -
  `show` hands a `Ruby2D::Page::Runner` to `add_game`, `mount_game` sees
  `canvas?` and gives game.js `canvas: true` (a `<canvas>` instead of the
  grid, the `r2d*` labels, no restart after `close`). Everything above
  holds for it: focus, pause, the guard, stop on re-run and lesson change.
- **Step through a cell, ⏯** (`step_recorder.rb` + `stepper.js`, from
  `experiments/02-time-travel-tracer`; lessons with `"stepper": true`, §3).
  ⏯ sends `ChunkyBridge.step(idx)`: the same run as ▶ (`chunky:run` with
  `step: true`, `run_cell(idx, step: true)`), with the eval wrapped in
  `StepRecorder#run`. After the output is written, `show_steps` hands the
  trace to `ChunkyBridge.steps(idx, json)`; bridge.js parses it (never
  PicoRuby) and `ChunkyStepper.show` puts the stepper on top of
  `#cell-out-<idx>`, above the run's own output: Chunky's sentence ("Zeile
  2 ist dran - zum 3. Mal."), the frames (the cell, a method with its
  arguments, a block with its pass; a value that changed in yellow, one
  from an earlier cell with ⟲), the output so far, ⏮ ◀ slider ▶ ⏭, "⏵
  Abspielen". The line about to run is marked in the cell's own editor
  (`addLineClass(.., "background", "step-now")`; `step-call`,
  `step-return`, `step-error` colour it). Its traps:
  - **The recorder is a targeted TracePoint.** A `:script_compiled` hook
    waits for the eval of exactly this code (`eval_script == code`, the
    iseq's path `chunky.rb`) and enables `:line, :call, :return, :b_call,
    :b_return` on that iseq only, which covers its methods and blocks: gems,
    the stdlib, the page's Ruby and **methods an earlier cell defined**
    (same file name) raise no events and are one step. A block given to
    `turtle` is this cell's code, so it is stepped (instance_eval'd or
    not). The eval is the normal one in the lesson's binding, so what the
    cell leaves behind is what ▶ leaves.
  - **A cell of comments only has no event to enable**, and
    `enable(target:)` then raises "can not enable any hooks" - and after
    that no targeted TracePoint in the process sees an event again (CRuby
    4.0.1; found while integrating). `events?` asks the iseqs first; such a
    cell records just its end ("=> nil"). An exercise before the learner
    wrote anything is exactly that.
  - **Hidden variables**: eval hoists every local of the cell (nil before
    its line ran), so a variable shows once it is non-nil, came from an
    earlier cell, or a line assigning it ran (a regex). The locals
    `check_exercise` sets live on in the binding and would show as ⟲ in
    the next cell: `StepRecorder::HIDDEN` lists them, and the test keeps it
    equal to `check_exercise`'s `local_variable_set`s - **add a new check
    local there too**.
  - **Caps**: 600 steps (then the tracing stops and the cell runs on at full
    speed; the stepper says it stopped taking notes), values cut at 60
    characters, big Arrays/Hashes summarised, 5 frames (recursion: the
    innermost), 16 variables; objects with Ruby's own `inspect` get a
    shallow one. Costs in ruby.wasm: about 0.1 ms a step, a Basics cell
    under 10 ms, the cap about 0.25 s with its JSON (the tree in lesson 10
    hits it: ~360 ms per ⏯ there, ~130 ms for the others, two paints
    included). Loaded at boot: 14 KB, ~6 ms to evaluate.
  - **Errors**: a targeted TracePoint never sees `:raise` (it happens in a C
    frame), so the last recorded line becomes the error step, with the
    state as it began; the friendly explanation (above) shows below the
    stepper as on ▶, and the line keeps its `.marker`.
  - **What ends a recording**: any change to the cell's code (the editor's
    `change`, setValue too: a reset), any run of the cell (`clearCellMarks`,
    which `run_cell` calls first), another lesson. **A language change
    keeps it** at its step where the cell's code is the same apart from
    comments (`ChunkyStepper.page`, called by `setState` after the paint:
    en ↔ ja, and German cells whose code is the English one, like
    schleifen's first) and drops it where it is not - the German code has
    other names. The binding is fresh then; the stepper is a recording.
  - **Keyboard and screen readers**: ⏯ is named "Schritt für Schritt
    durch Zelle 2" (`stepCellLabel`, the visible words plus the cell, like
    Run); after it the focus goes to the slider (`settle_cell`,
    `@refocus_step`; back to ⏯ when nothing was recorded), a native range
    input: arrows, Home, End, Page Up/Down; named `stepSlider`, its
    `aria-valuetext` "Schritt 3 von 12". ◀ ▶ ⏮ ⏭ are `aria-disabled` at
    the ends, never `disabled`, so the focus stays on them. A polite live
    region in the stepper says the step's sentence and what changed ("i =
    2") after a move of the learner's - not on ⏵'s ticks, and not on the
    first step (the slider's name and the run's status line are said
    then). `#runStatus` reads the run's output without the stepper
    (`App#brief_output`). ⏵ steps every 0.7 s, every 1.5 s under
    `prefers-reduced-motion`; nothing in the stepper animates. The group
    is named like ⏯.
  - Limits (the experiment's NOTES): steps are lines, not expressions; a
    one-line block shares its line with the statement around it; `_1` and
    `it` cannot be read from a binding; a `while` condition raises no
    event after its first pass; no object identity (that is
    `show_objects`). Not in the workshop: only the open file would be
    traced (`require_relative`'d files are iseqs of their own).
- CodeMirror cells must not be built while `#app` is `display:none`
  (blank editors after hard reload). Prose `pre/code` CSS stays scoped to
  `.lessonText`, or it bleeds into CodeMirror's internal `<pre>`s.

## 6a. Progress files, a connected folder, the workshop

Nothing is stored on a server - by design. The work stays on the learner's
machine:

- **localStorage** is the working copy, as before. `storage.js` wraps
  `Storage.prototype.setItem/removeItem`, so every `chunky_*` key main.rb
  writes gets a change time (in `chunkysync_times`, which is not synced).
- **Progress file** (every browser): the header button *Fortschritt* opens
  a dialog to download `chunkybacon-progress-<date>.json` and load it again.
  Format: `{format: "chunkybacon-progress", version: 1, entries: {key: {v, t}}}`.
  Loading merges key by key: the newer `t` wins, a removed key (lesson reset)
  travels as `v: null`, `chunky_done` is united. The shell re-renders on the
  `chunky-progress-loaded` event.
- **Folder** (Chrome/Edge, File System Access API): *Ordner wählen* picks a
  folder; its handle is kept in IndexedDB. Every change is merged into
  `chunkybacon-progress.json` there (800 ms debounce, flushed when the tab is
  hidden). After a browser restart the permission may need one click
  (*Ordner wieder öffnen*; the button shows an orange dot). **Needs a secure
  context**: https or localhost. The live site is https, so it works there;
  on a plain `http://<ip>` the browser hides the API and the dialog offers
  only the file.
- **A cell's saved code** is the key `chunky_cell_<lang>_<id>_<idx>@<fp>`:
  the cell's index in the lesson and a fingerprint of its starter code
  (`shell/store.rb`: a polynomial hash of the bytes, base 36, at most six
  characters). The kernel's `run_cell` hands the code it runs to the shell
  (`chunkySaveCode(idx, code)`, a callback from `App#wire_events`), which
  files it under the cell on screen; `render_lesson` shows saved code only
  under the key of the cell now at that index, and a reset removes that key.
  So when a lesson's cells change, saved code never shows in another cell: a
  cell whose index or starter changed opens with its starter, and what was
  saved for it before stays in storage, unused. `Store.fingerprint` must
  never change (a test pins it) - that would hide every learner's code.
- Keys from before the fingerprint (`chunky_cell_<lang>_<id>_<idx>`, until
  2026-10) are moved by `Store.migrate_code_keys`, at boot and after a
  progress file or folder was merged in (`chunky-progress-loaded`), so an
  old progress file lands right too: to the fingerprinted key of the cell
  they were saved for - in `arrays`, `hashes` and `klassen` shifted by two
  (`Store::LEGACY_SHIFTS`: the `show_objects` cells went in before their
  exercises, 7 → 9, 3 → 5, 3 → 5, in all three languages). Where both keys
  exist the newer wins (`chunkysync_times`); the old key is removed, so the
  removal travels and an old copy cannot bring it back. A key this course
  has no code cell for is left alone.
- **Workshop** (`#werkstatt`, link above the lessons): the learner's own
  programs. Without a folder the files are `chunky_file:<path>` keys (so they
  travel in the progress file); with a folder they are real files in it
  (read in at connect and on window focus; dotfiles, `node_modules`,
  `vendor` and files over 1 MB skipped). The editor is cell 0; main.rb's
  `run_cell` hands the run to `workshop.rb`: project files become
  `SandboxFS.store`, `require_relative` resolves project files, `gets` reads
  the input box, `$0` names the file; afterwards every file the program
  wrote (FileWatch: through SandboxFS or onto the real filesystem) and every
  deletion go back through `workspaceWrite`/`workspaceDelete`, and the
  lesson's demo files return. A run saves the open file. Files can be
  renamed (✎; without an extension typed, the old one stays).
- **Pictures, PDFs and sounds** (png, jpg, gif, webp, pdf, wav - the same
  list in `workshop.rb`, `storage.js` and `shell/workspace.rb`): kept as `data:`
  URLs in localStorage and in a run's snapshot, as real binary files in a
  connected folder; up to 1 MB, bigger ones stay downloads. A run gets their
  bytes in `SandboxFS` *and* as real files (so `File.binread`, ChunkyPNG's
  `from_file` and Prawn's `image` find them). The ones a run writes are
  previewed below the editor (unless the program called
  `show_image`/`show_pdf`/`show_audio` for the same bytes), and selecting one in the file
  list shows it in place of the editor - a picture from its data: URL (tiny
  ones pixelated at 160 px), a PDF in the browser's viewer and a WAV in a
  player named after the file, both from a Blob URL
  (`ChunkyBridge.objectUrl`, released when the preview goes). The editor
  never holds a picture's data: URL: saving, a run's save and a change from
  storage leave a previewed file alone.
- **SQLite databases** (db, sqlite, sqlite3 - `application/vnd.sqlite3`) are
  binary files the same way: `BINARY_TYPES` in `storage.js` and
  `workshop.rb` (its `PREVIEW_TYPES` stay pictures and PDFs, so a database
  is kept, not previewed after a run), allowed as uploads in
  `shell/workspace.rb`. Selected in the file list, a database shows a short
  card in place of the editor (`.ws-database`, the `wsDatabase` string with
  its size). How a program reads and writes one: §6f.
- Dev on this machine: serve on localhost (127.0.0.1 counts), where the
  folder API is available. `test/progress_test.mjs` drives the folder through
  the origin-private file system (same API, no native picker).

## 6b. Live runs

A cell runs by itself a second after the last key (`⚡ Live` beside ▶). The
shell does the timing, the kernel the guarding:

- **Shell** (`shell/app.rb`, *live runs*): index.html's `initCell` calls
  `window.chunkyEdited(idx)` on every change that is not `setValue` (the
  page's own); `edited` waits `LIVE_DELAY_MS` in a Task and asks
  `ChunkyBridge.autorun(idx)` - only for the latest key (`@live_gen`), on
  the page it was typed on (`@view_gen`), while the cell is idle, the
  switch on and the cell quick. `autorun` never queues: while CRuby loads,
  typing is just typing. A run (live or ▶) over `LIVE_SLOW` (0.3 s) pauses
  that cell's live runs until a quick ▶ run (the switch is struck through) -
  measured without installing and loading gems (`chunky:ran`'s `own`, from
  `AutoRun.library_time`), which a cell's first run does once.
  A live result is quiet: no shake, no reveal, no run time, no bubble - only
  a pass that is new (`@last_outcome`) cheers and marks the lesson done.
  Switches: `chunkyui_live` (lessons, on unless "off") and
  `chunkyui_live_ws` (workshop, off unless "on"); view settings, not synced.
- **A lesson without live runs**: `"live": false` on a lesson in
  `lessons.js` (the music lesson, 37: its sample loops take a second and
  more under the tracing, so every cell would be stopped). The shell's
  `live?` is false there (`App#lesson_live?`, `Course#live?`), so no key
  asks for a run; the switch stays in every toolbar, off, struck through,
  `aria-disabled` rather than `disabled` (it stays focusable, so its title,
  `liveLesson`, is read), and a click has Chunky say why and puts it in
  `#runStatus` - the page's own switch is left as it was. The kernel
  answers a live run in such a lesson with `skipped` too (`run_cell`).
- **Kernel** (`run_cell(idx, auto: true)`, `autorun.rb`): the code is stored
  as on ▶, then `AutoRun.runnable?` - it must compile (with the binding's
  locals declared, so `x /2` parses as on ▶), and IRB cells and loops that
  raise no TracePoint event (`while true; end`, one-line modifier loops) are
  refused outright → outcome `skipped`, output untouched. The run is a
  **rehearsal**: after the run - and after the exercise's check, which may
  read what it wrote (`end_rehearsal` in `finish_cell_run`) - a lesson's
  `SandboxFS` store is restored and files it wrote on the real filesystem
  are deleted (`AutoRun.take_back`); in the workshop nothing goes back to
  the project (`workspaceWrite`/`workshopAfterRun` are skipped). Its output,
  previews and downloads still show. **No downloads**: `install_gem` of a
  gem neither installed nor cached, the Net::HTTP transport and a write to
  a SQLite database opened before the live run (§6f) and importing a
  Python module Python has not imported yet (§6d) raise
  `AutoRun::NeedsRun` (outcome `needs`, a hint to press ▶); `require`
  auto-installs cached gems only. **A time limit**:
  `AutoRun.with_time_limit` (TracePoint `:line`, `:b_call`, `:c_call`, the
  clock read every 128 events) raises `AutoRun::Stopped` after `LIMIT`
  (1 s), but only on a line of the learner's own file(s) - never inside a
  gem being loaded or the app (outcome `stopped`, a hint). The sample and
  the stop are apart (`@late`): tied together - "every 128th event, if it
  is the learner's" - `loop { }`, two events a round (its block, a line in
  `<internal:kernel>`), was never stopped when the events before it had
  the wrong parity; a live run earlier on the page was enough to freeze a
  game for good (found 2026-10-06 with the ruby2d lesson;
  `autorun_test.rb` runs `loop { }` after four prefixes). Installing a
  cached gem and every `require` run untraced and off the clock
  (`AutoRun.untraced` moves the deadline by their time). Both exceptions
  descend from `Exception`, so `rescue => e` in learner code cannot swallow
  them. The output gets `.is-rehearsal` (errors fainter, an explained error
  as its headline only, §6); no line is marked.
- **Games** (`show_game`, §6): a live run mounts the game, paused, and
  never starts it - it runs only with the focus, which the editor keeps -
  so the Snake lesson keeps its live runs, and so does the ruby2d lesson
  (§6l): its windows are games to the page. The exercise's check plays a
  copy of the game, under its own time limit, on a live run too.
- **⏯ never runs live**: a live run is never recorded (`run_cell` ignores
  `step` with `auto`, and the shell asks for live runs from keys only). A
  key in a stepped cell ends its recording at once, before the live run a
  second later, which then writes its output without a stepper. Recording
  on every pause would cost up to 0.25 s a run (the cap), and the line
  numbers of a half-typed cell move under the slider.
- **▶ has no time limit**: TracePoint costs ~3x on gem-heavy code, so a
  manual run still can hang the page on an endless loop, as before.
  An endless loop that raises no TracePoint event and that `runnable?` does
  not recognise would hang a live run the same way - add its shape there
  (to probe a shape, run it in a child process with a timeout: an event-less
  loop hangs the tracing parent too).

## 6c. Offline mode

The progress dialog's *Offline lernen* keeps the whole course on the device
(~101 MB stored, up to ~68 MB to download; Pyodide is 52 / 45 of it): the course then opens and runs
without a connection. **Off until the learner turns it on** - before that
no service worker is registered and nothing changes. The choice is
`chunkyui_offline` (a view setting, not synced).

- **Python is a checkbox** ("Python mitnehmen", ticked by default; ~52 MB):
  `chunkyui_offline_python` = `off` leaves `assets/pyodide/` out.
  `offline.js` sends the choice with every refresh (`{ python }`), `sw.js`
  filters the list by it (`PYTHON`), so a change takes effect at once and the
  next index drops the files (a change during a download queues another
  one). A page from a copy without Python does not try to load it
  (`ensurePython` stops at once) and a PyCall cell says why (`pythonOffline`).

- **Online nothing changes.** `html/sw.js` sends every request to the
  network as before - a deploy is seen on the next load, just as without it.
  The copy only answers when the network does not (an error, a 5xx from a
  proxy whose server is down, or a page taking over 6 s). A page that came
  from the copy takes every file from it, so it is one version throughout.
- **The copy** is the files in `html/offline-files.txt` plus the page as
  `./` answers it (with the server: the permalink page, so `/de/methoden`
  works offline too). After an online visit, once the kernel is up, the
  worker checks it (at most every 10 minutes): a HEAD per file, and only
  files whose ETag/Last-Modified changed are fetched (no validator, as with
  the server's page: a SHA-256 of the body). A new copy counts only once
  complete and a second check saw no deploy meanwhile; one Cache Storage
  entry per file version, `__offline__/index.json` names the current ones -
  writing it is the switch. An interrupted download resumes where it was.
- **No build step for edits**: an edited file has a new ETag. **Adding,
  renaming or deleting a file under `html/`** needs `ruby
  tools/offline_files.rb` (`--check` says whether the list is current). A
  file missing from the list is simply not offline; a listed file that is
  gone is skipped.
- **Synchronous XHR does not pass a service worker in Chrome**, and the
  kernel fetches gems that way (`fetch*Sync` in index.html). So `sw.js`
  marks a page it serves from the copy (`<meta name="chunky-offline-copy">`),
  `offline.js` then reads the gem cache and the `.rb` files the kernel
  fetches on demand (`shoes_dom.rb`, `numo_narray.rb`, `processing.rb`,
  `herb_bridge.rb`, `ruby2d.rb` with `assets/ruby2d/ruby2d.rb`, the three `friendly_errors*.rb`) into memory before the kernel starts (`bridge.js` waits for
  `ChunkyOffline.kernelReady()`), and the sync helpers answer from there. A
  new file the kernel fetches synchronously must be added there too.
- **What needs the internet says so**: a gem not in the cache
  (`gemOffline`), `Net::HTTP` ("this page is offline"); `/api`, the bridges
  and the webhook are never answered from the copy.
- Tests: `test/offline_test.mjs` (Chromium, `BROWSER=firefox|webkit`; with
  the server on 8012 it also opens a permalink offline). Playwright's
  offline switch does not reach a service worker in Firefox, so the test
  puts a proxy in front of `BASE` and takes that down instead. To look at it
  in a browser: DevTools → Application → Service workers / Cache storage.

## 7. nginx and the proxy

Compression: `gzip on` for text (html, rb - typed `text/plain` in the app-code
location, since `mime.types` has no `.rb` -, js, css, json, svg) and
`gzip_static on`, which serves `ruby+stdlib.wasm.gz` in place of the wasm.
Only files that change through a tool get a `.gz` (`tools/compress_assets.rb`),
so a hand-edited lessons.js or main.rb can never be shadowed by a stale one.

`nginx/default.conf` is deliberately not an open proxy: upstream hosts are
hardcoded (`rubygems.org`, `www.ruby-lang.org`), only the path is forwarded,
`GET`/`HEAD` only, rubygems locked to `api/v1/gems/` and `gems/`, per-IP
`limit_req` 5 r/s with burst 60 (a gem with many dependencies makes two
requests per dependency), responses disk-cached (gems 60 days). Locations
are `^~` so the no-cache regex cannot capture proxied `.json`. The resolver
is Docker's `127.0.0.11`, which only exists on user-defined networks - a
container started with plain `docker run` on the default bridge gets 502s.

**The bridges serve the course's own pages only.** `map "$http_referer|$host"
$chunky_bridge_ok` (http context, top of `default.conf`) matches
`~*^https?://([^/:|]+)(:[0-9]+)?/[^|]*\|\1$`: the Referer's host name -
port and path left aside - must be the host the request was sent to (`\1`
is a PCRE backreference). Nothing is hard-coded, so it holds at the
server's address today and at the domain later, and the server's address
never appears in the repository. Each bridge location starts with
`if ($chunky_bridge_ok = 0) { return 403; }` (an `if` with only a `return`
is safe), and answers with `Cross-Origin-Resource-Policy: same-origin`
(another site's `<img>`/`<script>` cannot load it) - and no CORS header
(`proxy_hide_header` drops one rubygems.org might send).
The rate limit stays. No Referer means 403: the course's pages always send
one (default policy `strict-origin-when-cross-origin`, same-origin: the full
URL); `offline_test.mjs` checks that a request the service worker passes
on keeps it. The embed sends none (§6k). A script outside a browser can
send any Referer - that is what the rate limit is for; the rule stops
other sites using the bridges through their visitors' browsers.

- **Pinning it to the domain** once chunkybacon.idogawa.com is live is one
  line: in that map, replace the pattern line with
  `"~*^https://chunkybacon\.idogawa\.com/" 1;` (the comment above the map
  says so).
- **The host's reverse proxy must pass the `Host` header on** (as for the
  permalinks' canonical links). If it sent the container's address as Host,
  every bridge request from the domain would be 403.
- Same rule in `tools/dev_server.rb` (`CourseRules`, the same pattern) and
  in `server/app.rb`'s bridges; `test/dev_server_test.rb` checks the dev
  server over HTTP and reads the pattern and the headers out of
  `default.conf` to compare (no nginx on a dev machine to run `nginx -t`).

**Headers for the embed.** `add_header Access-Control-Allow-Origin "*"` at
server level for the static files, repeated in the app-code location
(a location with an `add_header` of its own inherits none of the
server's). `*`, not `null`: the files are public, nothing goes with
credentials, and `null` would not be narrower - every sandboxed frame and
`data:` page on any site is `null`. The bridges have their own
`add_header`s, so they do not get it. `location = /embed.html` (exact, so
the app-code regex does not take it) sends `Cache-Control: no-cache` and
the `Content-Security-Policy` of §6k with `always`. The embed lives on the
course's own host: no second server block or host name.
`tools/dev_server.rb` sends the same; `FRAME_ANCESTORS=...` replaces
https://idogawa.com there, for tests (`http://blog.test:*`).

## 6d. Python: Pyodide and the PyCall bridge

The PyCall lessons run real pandas (23), SymPy (24), NumPy (25), matplotlib
(26) and scikit-learn (27). The pycall gem cannot load in the browser - it opens
libpython with Fiddle - so:

- **Pyodide** (CPython 3.14 in WebAssembly) with pandas, numpy and their
  three small dependencies, sympy with mpmath, scikit-learn with scipy,
  joblib and threadpoolctl, and matplotlib with contourpy, cycler,
  fonttools, kiwisolver, packaging, pillow and pyparsing (9.1 MB), sits in
  `html/assets/pyodide/` (~52 MB; `PACKAGES` in the tool). Wheels are zip archives already, so they get no
  `.gz` (gzip saves under 2%):
  `tools/vendor_pyodide.rb` takes the core from the official GitHub release
  and the wheels from jsDelivr, checks each wheel against the release
  lockfile's SHA-256, and cuts `pyodide-lock.json` down to what is vendored
  (asking for another package then fails clearly). Bump `VERSION` there to
  update; then `ruby tools/compress_assets.rb` (the .gz of the wasm and
  `pyodide.asm.mjs`) and `ruby tools/offline_files.rb`. nginx serves `.mjs`
  as JavaScript (module scripts insist). A slimmer matplotlib wheel (3.6 MB
  of it are fonts: DejaVu Sans/Serif/Mono, STIX, Computer Modern) would save
  2.5-3 MB, but it would be a repacked third-party wheel whose SHA-256 is
  no longer the release's - left as it is.
- **Loading**: index.html's `ensurePython(code)` imports `pyodide.mjs` once
  (~9 MB), maps import names to vendored packages from `pyodide-lock.json`,
  loads the packages the `import_module("...")` calls in `code` name
  (pandas ~12 MB, sympy ~5 MB, scikit-learn ~19 MB with scipy, matplotlib
  ~9 MB with what it needs besides numpy; a dotted
  name counts by its first part, `sklearn.tree` -> `sklearn`) and
  collects what Python prints
  (`chunkyPython.takeOutput`). The shell calls it with a lesson's PyCall
  cells (render_lesson, like `ensureThree`; the names are read in JS, as
  PicoRuby has no `scan`); `shell/bridge.js` holds a run until Python is
  there, and live runs skip meanwhile. In the workshop the first `PyCall`
  call starts the core, and importing a vendored module not loaded yet
  starts loading it (`import_module` on `ModuleNotFoundError`); both ask to
  run again (`pythonLoading`).
- **The bridge** (`html/pycall.rb`, loaded by main.rb; `require "pycall"` is
  a shim) has PyCall's API: `PyCall.import_module`, `eval`, `exec`, `.new`
  for classes, `[]`/`[]=`, operators, keyword arguments, `to_a`/`to_h`.
  Python objects stay in a registry in Python; Ruby holds their numbers, and
  each operation is one JSON request through JavaScript - which keeps
  `int` and `float` apart (JavaScript would merge them), turns numpy scalars
  into numbers and Python exceptions into `PyCall::PyError`. A result with
  `_repr_html_` (a DataFrame) renders as pandas' table (`.py-table`); any
  other is its repr, a multi-line one (a Series) starting below the `=>`.
  `coerce` makes `2 * x` work (the 2 becomes a Python object, op `box`, as
  the gem's SwappedOperationAdapter does), and `to_a` turns sympy integers
  and floats into Ruby numbers. Ruby blocks cannot be passed to Python.
- **A tuple is an Array** of its converted items, as the gem's
  `pycall_pytuple_to_a` makes it (only an exact `tuple`; a namedtuple stays
  a PyObject there too): `fig, ax = plt.subplots` unpacks, `df.shape` is
  `[3, 4]`. A NumPy array does not unpack - `fig, (a, b) = plt.subplots(1, 2)`
  leaves `b` nil, as with the gem, whose PyObjectWrapper has no `to_ary` -
  so the lesson takes `axes[0]`, `axes[1]`. (`to_a` of a list of objects
  still gives their `str`, unlike the gem's PyCall::List.)
- **matplotlib** draws with the bridge's own backend (`BACKEND` in
  pycall.rb): written as `chunky_backend.py` into Pyodide's file system
  when the bridge starts, picked by `MPLBACKEND` (Pyodide's matplotlib
  would choose webagg, whose `show` wants a server), or by `switch_backend`
  when pyplot was imported first. It is Agg plus a `show` that renders
  every open figure as SVG and closes it (what matplotlib-inline does in
  Jupyter); the SVGs go along with that request's answer (`figures`), and
  `PyCall.request` puts each under the cell through `add_image` - an
  exercise's check sees it in `images`. `svg.fonttype: none` keeps text as
  text: smaller, the check can read a title, and the browser draws
  Japanese, which DejaVu Sans lacks (matplotlib only measures with it; a
  PNG from `savefig` shows boxes - the ja lesson says so). `savefig` with
  a relative name is read back and written into `SandboxFS` (`files`), so
  it is a download in a lesson and a project file in the workshop.
  `show_plot(fig)` (op `figure`) shows one figure explicitly; the
  companion gem has it too. After every run main.rb calls
  `PyCall.end_run`: figures drawn but not shown are closed, so the next
  run - a live one while typing too - starts with an empty board instead
  of drawing over the last one (Jupyter's inline backend does the same).
  Not covered: matplotlib's object API without pyplot
  (`matplotlib.figure.Figure.new`) never loads the backend, so its
  `savefig` stays in Pyodide; `File.binread` of a virtual file does not
  see SandboxFS (`File.read` does). A chart is 12-20 KB of SVG, a
  2000-point scatter ~225 KB.
- **matplotlib's first import** (`import matplotlib.pyplot`) takes 4-9 s,
  all of it Python on the main thread. When a lesson that imports it
  opens, `ensurePython` starts `warmMatplotlib` (index.html): the
  imports one module at a time (24 of them, the longest `import matplotlib`
  itself, ~1 s), with a pause between them so the page stays usable;
  `chunkyPython.warmSteps` has the times. Runs are not held meanwhile (a
  ▶ imports the rest itself; other lessons are not slowed), live runs
  are (bridge.js). In pycall.rb `import_module` runs untraced and counts
  as library time, like `require`, and a live run never imports a module
  Python does not have yet (`AutoRun::NeedsRun`, as with Faker, §6i), so
  typing does not freeze for it in the workshop either. The warm-up's last
  step draws a small chart off pyplot (the font, the caches - the first real
  chart would take ~0.3 s longer), and setting up the bridge, once per page,
  counts as loading a library too. After that a chart takes 0.2-0.5 s
  (`bbox_inches: "tight"` is about half of it; without it labels can be
  cut off) - around `LIVE_SLOW`, so a chart cell's live runs may pause
  after one (§6b) and ▶ draws it. `test/live_test.mjs` covers the rules.
- **The lesson** goes in small steps, one idea per cell: a DataFrame, one
  column (a Series), computing with columns, `sum`, a True/False mask, the
  rows it picks, back to Ruby with `tolist.to_a`, `value_counts`, `groupby`.
  A Python -> Ruby cheat sheet (`table.cheat`, app.css) sits after the
  import, and the plain-Ruby equivalent is shown next to the pandas way.
  Its code stays what the real gem runs (`tolist.to_a`, `to_dict.to_h`).
- **The SymPy lesson**: a float vs a `Rational` (a class, so `.new`), exact
  roots and `evalf(50)`, a symbol, `expand`/`factor`, `pretty` (with
  `use_unicode: false` - the code font has no fixed-width box-drawing
  glyphs, so the unicode drawing falls apart), `solve`, `subs` in a Ruby
  block, `diff`; the exercise finds where a cubic is flat (`diff` + `solve`).
- **The NumPy lesson**: arithmetic on a whole array, `mean`/`max`/`argmax`,
  a mask, `arange`/`linspace`, `reshape`/`shape`/`sum(axis:)`, seeded dice
  (`default_rng(42)`, so `bincount` is the same every run), `tolist.to_a`;
  the exercise counts scores >= 60 with `(a >= 60).sum`.
- **The matplotlib lesson**: `plt.plot` + `plt.show` (a line), `plt.bar`,
  then `fig, ax = plt.subplots` (the tuple unpacking, with a Python ->
  Ruby cheat sheet), NumPy's sin and cos with a legend, two panels from
  `plt.subplots(1, 2)` as `axes[0]`/`axes[1]` (the text says why not
  `fig, (a, b)`) with `plt.savefig("wetter.png")` before `show`; its
  scatter of ice creams by temperature leads to scikit-learn. The
  exercise draws the fox's mice as a bar chart titled `Fuchs-Jagd` /
  `Fox hunt`: the check wants `.bar` in the code and the title in an SVG
  under the cell.
- **The scikit-learn lesson**: `LinearRegression` (ice creams by
  temperature; `coef_`, `intercept_` - negative, which the text uses),
  a `DecisionTreeClassifier` cat-or-fox whose `export_text` shows it split
  on the ears only (the text builds on that: a heavy animal with short ears
  is a cat), then iris (bundled in the wheel, so offline too) with
  `train_test_split` and `score` (~0.96). The numbers in the text are what
  the code prints; check them after a scikit-learn update. The exercise
  predicts points for 6 study hours (87).
- **Tests**: the lessons need the browser - `check_harness.rb` skips them
  (`BROWSER_ONLY`), `test/browser_test.mjs` runs every cell (for
  matplotlib also the SVG, the download, the tuple rules, closing unshown
  figures, `show_plot`, Japanese text and the exercise's fail/pass).

## 6e. Rumale, a pure-Ruby Numo, and the letter

Lesson 29 does machine learning in Ruby itself, with
[Rumale](https://github.com/yoshoku/rumale): k-nearest neighbours on
vegetables, then on 1797 handwritten digits, then on a postcode the learner
writes onto a letter.

- **Numo is C.** Rumale is pure Ruby on Numo::NArray (numo-narray-alt since
  Rumale 2.x), which ruby.wasm cannot load. `html/numo_narray.rb` is Numo's
  API in plain Ruby: the dtype classes, broadcasting, indexing (integers,
  ranges, `true`, index arrays, Bit masks, one index counting flat), axis
  reductions, `dot`, `NMath`, and Numo's printing (`%g`, `(view)`,
  truncated lines) - compared against the real gem for every method the
  lesson and Rumale's kNN, GaussianNB and StandardScaler use. Not there: real
  views (`a[0, true]` is a copy), complex numbers, NaN options. main.rb serves
  it for `require "numo/narray"` and `"numo/narray/alt"` (fetched on the first
  require, like shoes_dom.rb); `numo-narray`/`numo-narray-alt` are in
  `NATIVE_GEMS`, and `builtin?` then finds the shim, so rumale-core installs.
  Only rumale-core and rumale-nearest_neighbors are cached: the `rumale`
  umbrella gem pulls in rumale-tree and numo-optimize (C), so the lesson
  requires `rumale/nearest_neighbors`.
- **Speed**: a 100x64 by 64x1500 `dot` takes ~1 s in Chrome (the stand-in
  skips zeros), and Rumale's own `predict` sorts every row of distances in
  Ruby (~45 ms a row there, the same with the real Numo). So the lesson
  trains on 1000 digits and tests on 50 (~2.5 s, 0.96), then refits on all
  1797 for the letter, which predicts 4 digits in well under a second.
- **Lesson files**: a lesson's `"files"` (name => path on the site) are put
  into the virtual filesystem when it opens (`load_lesson_files` in main.rb,
  sync XHR; `offline.js` preloads `assets/data/digits.csv` and
  `numo_narray.rb` for the offline copy), so `File.read("digits.csv")` works
  as next to a program on disk. `check_harness.rb` does the same.
- **`digits.csv`**: UCI's optdigits (CC BY 4.0, THIRD_PARTY_NOTICES), the
  1797 digits scikit-learn ships, taken out of the vendored wheel: 64
  numbers 0..16 (ink in each 4x4 block of a 32x32 bitmap), then the digit.
- **show_letter** (`letter.js`, `mount_letter` in main.rb): an envelope on a
  canvas with red postcode boxes. The strokes are kept as points; for each
  box the segments whose middle lies in it are scaled so the drawing's
  taller side fills 32 px (as the dataset's digits fill the height), drawn
  with a 4.2 px pen and counted in 4x4 blocks - the dataset's own recipe.
  When the pen lifts (250 ms later) the Ruby block gets the boxes with ink
  as JSON; its answer is written under the boxes with a postmark, an error
  below the canvas. The ink is kept per lesson/cell, so a re-run reads the
  same drawing with the new code. `data-answer` on the widget and
  `chunkyLetter.draw(strokes)` are for the tests. The words come from
  `ui.letter*`. The gem's `show_letter` raises NotHere.
- **Tests**: `check_harness.rb` runs the lesson on the stand-in (its
  `show_letter` feeds the block the dataset's 3, 0, 0, 0 and expects
  "3000 …"); `browser_test.mjs` writes 3000 on the letter and expects
  "3000 Bern".

## 6f. SQLite and Sequel: a sqlite3 stand-in on sql.js

Lesson 30 uses [Sequel](https://sequel.jeremyevans.net) with SQLite. Sequel
is pure Ruby (cached, `sequel-5.109.0.gem`); the sqlite3 gem under it is C.

- **sql.js** (SQLite 3.49 in WebAssembly, ~650 KB, 0.3 MB gzipped) sits in
  `html/assets/sqljs/`: `tools/vendor_sqljs.rb` takes the npm package and
  checks it against the registry's SHA-512; `tools/compress_assets.rb` makes
  the wasm's `.gz`. index.html's `ensureSqlite` loads it with a `<script>`
  tag (it defines `initSqlJs`); the shell calls it when a lesson's code
  mentions `Sequel` or `SQLite3`, and `shell/bridge.js` holds a run until
  `chunky:sqlite-ready`, as for Python. `window.chunkySqlite` has the calls:
  `open`, `close`, `query`, `batch`, `changes`, `lastInsertRowId`, JSON in
  and out (an INTEGER as text so 2**40 stays exact, a whole-looking REAL
  tagged so 3.0 stays a Float, a BLOB as base64).
- **The stand-in** (`html/sqlite3_sqljs.rb`, loaded by main.rb and
  registered as the `sqlite3` shim, so `install_gem "sqlite3"` counts it as
  built in): `SQLite3::Database` (`execute`, `execute_batch`, `query`,
  `prepare`, `transaction`, `changes`, `last_insert_row_id`, `quote`),
  `Statement`, `ResultSet` with `columns`/`types`, the exception classes,
  and `VERSION = "2.0.0"` (Sequel reads it). That is what Sequel's own
  `sequel/adapters/sqlite.rb` calls, so `Sequel.sqlite` runs unchanged.
- **Declared types**: Sequel converts result values by each column's
  declared type (1 -> true, "2026-10-05" -> Date). sql.js does not export
  `sqlite3_column_decltype`, so `query` reads `PRAGMA table_info` for the
  tables after FROM/JOIN and matches by column name; a computed column
  (`sum(...) AS total`) has no type and keeps SQLite's runtime type.
- **Databases in files**: no path (or `":memory:"`) is a database in memory,
  as before. `Sequel.sqlite("timelog.db")` is a SQLite file: opening reads
  its bytes (`chunkySqlite.open(base64)`), and at the end of each run
  main.rb calls `SQLite3::Database.save_all` - right before
  `FileWatch.changes_since`, so the file counts among the run's files (a
  lesson offers it as a download, the workshop keeps it with the project,
  in localStorage or as a real file in a connected folder). A relative path
  goes through `SandboxFS`, an absolute one to the wasm filesystem. Only a
  database the run used is saved, only if its bytes changed, never inside
  an open transaction. Not after every statement: sql.js's `export()` -
  `exportDb` - closes and reopens the database, which ends a transaction
  and forgets `last_insert_rowid`; the connection's `PRAGMA x = y`
  settings are set again after it (index.html). In the workshop every run
  is a program of its own, so `save_all(close: true)` closes its databases.
- **Live runs** (§6b): a database opened before the live run may only be
  read; a writing statement raises `AutoRun::NeedsRun` (the "press ▶" hint,
  `liveNeedsRun`). A database the live run opened itself may be changed -
  the rehearsal throws it away with its other files.
- **Loading**: a lesson loads sql.js when it opens; the shell's
  `start_cell_run` also calls `ensureSqlite` for any code that mentions
  `Sequel` or `SQLite3` (a workshop program, a changed cell), and the
  bridge holds the run until it is there.
- **Limits**: after a run that used a file database, its temp tables and
  `last_insert_rowid` are reset (the export reopens it). Two `Database`
  objects on one file, both used in one run: each saves, the one opened
  last wins. Transactions are tracked by the SQL's first word (BEGIN,
  COMMIT, END, ROLLBACK); a bare `SAVEPOINT` outside BEGIN is not. The
  workshop keeps binary files up to 1 MB (`Workshop::MAX_BINARY`),
  `storage.js` reads up to 1 MB per file from a folder and localStorage
  holds a few MB in all - bigger databases stay downloads. In lessons,
  in-memory databases of re-run cells are never closed (sql.js memory
  grows a little per re-run). No SQL functions written in Ruby
  (`create_function` raises, so Sequel's `setup_regexp_function` is out);
  errors carry the message but no extended code, and Sequel maps them by
  message (UNIQUE, NOT NULL, CHECK, FOREIGN KEY all come out right).
- **Threads**: a model's `save` runs in a transaction, and Sequel asks
  `Thread.current.status` before committing - `SimThread` has `status`
  for that (sandbox_sim.rb).
- **Tests**: the lesson needs the browser - `check_harness.rb` skips it
  (`BROWSER_ONLY`); `browser_test.mjs` runs every cell plus UNIQUE, a
  rollback, a big integer, and the file step (rows kept across runs, the
  download a SQLite file, a model's save, a transaction left open not
  saved); `live_test.mjs` the live-run rule and a workshop program's
  database (first run, re-run, reload, the card); `offline_test.mjs` runs
  Sequel and a file database from the copy.

## 6g. A terminal below the cell: TTY, colours, box drawing

Lesson 32 draws with the [TTY toolkit](https://ttytoolkit.org): pastel,
tty-table, tty-box, tty-tree, tty-font (all cached, with strings,
tty-screen, tty-color, tty-cursor, unicode-display_width - pinned to 2.6,
as strings wants < 3 - and unicode_utils). Three things make a cell's
output behave like a terminal:

- **Colours** (`html/ansi.rb`, `AnsiHtml.to_html`): the cell's stdout and
  IRB's go through it - SGR codes (`\e[31m`, bold, background, 256 and
  RGB colours, inverse) become spans with `ansi-*` classes (app.css: the
  16 colours as a light-background terminal shows them) or inline styles;
  cursor movements are dropped. pastel only colours a terminal, and a cell's
  output is a StringIO, so the lesson says `Pastel.new(enabled: true)`.
- **Box drawing** (`html/assets/fonts/chunky-box-drawing.woff`, built by
  `tools/build_box_font.rb`): Atkinson Hyperlegible Mono has no U+2500-259F,
  and a fallback font's are not as wide as its letters, so tables broke
  apart. The tool draws the 160 glyphs from rectangles (the arms read off
  the Unicode names), 0.632 em wide, the vertical strokes reaching the
  line box's edges at line-height 1.6; fonts.css maps the range onto the
  code font's family. Strokes thinner than ~1.4 px vanished at some
  heights in Chromium on Windows. SymPy's `pretty` still asks for ASCII
  (lesson 25) - its other symbols are not in this font.
- **No window size**: tty-screen checks for `ioctl` on the real `$stderr`
  at load time and then calls it on `$stdout` - a StringIO, which had
  none. `sandbox_sim.rb` gives StringIO an `ioctl` that raises ENOTTY, as
  an IO redirected to a file does, so it falls back to 80 columns.

Not in the lesson (an offweb box shows them): tty-prompt, tty-reader,
tty-spinner, tty-progressbar. tty-reader needs `io/wait`, which must stay
unloadable (§4), and the others redraw with the cursor; tty-progressbar
prints nothing when its output is no terminal.

## 6h. Processing: a stand-in that records, a canvas that paints

Lesson 33 is the [processing gem](https://github.com/xord/processing)
(xord, 1.4.0): `require "processing"`, `using Processing`, `setup do`,
`draw do`, the Processing names in camelCase. The gem is pure Ruby on
rays and reflexion, C++ on OpenGL, so it cannot run here.
`html/processing.rb` has its API (constants, colours and `colorMode`,
shapes, `beginShape`, text, `push`/`pop` and the 2D transforms, the maths
helpers, `Vector`, the mouse and key state and blocks,
`Processing(snake_case: true)`), read off the gem's `context.rb` and
`graphics_context.rb`; images, shaders, 3D and the camera raise
`NotImplementedError`.

- **Served like Numo** (§6e): a shim for `require "processing"` fetches
  and evaluates the file; `processing`, `rays`, `reflexion` and `rucy`
  are in `NATIVE_GEMS`, so `install_gem "processing"` finds it built in.
  The offline copy preloads it (`offline.js`).
- **Recording**: what a frame draws becomes `[name, *args]` commands, a
  `style` and a `matrix` command only when they changed (the matrix is
  tracked in Ruby, 2D affine). `processing.js` paints them on a canvas
  that keeps its pixels between frames, like the gem's window.
- **The lifecycle** follows the gem's window: the matrix and the stacks
  reset before every frame and every event, `draw` wrapped in
  `push`/`pop`, styles set in `setup` lasting. The gem starts its window
  `at_exit` and only if there is a draw or event block; here
  `Processing.start__` runs after the cell (inside the live run's time
  limit), runs `setup` and the first frame and hands the sketch over;
  every cell run starts with a fresh context. `$processing_context__`,
  which the refinement calls, is the sketch's own while its blocks run -
  a page can have several.
- **Frames** (`mount_sketch`): `requestAnimationFrame` calls the Ruby
  block with `{dt, events}`; Ruby applies the events (mouse, keys,
  wheel - each firing its block), runs `draw` unless `noLoop`, and
  calls `paint` with the next commands. A failing frame stops the sketch
  and shows its error below the canvas; what a frame prints goes there
  too. A sketch out of view rests (IntersectionObserver); re-running the
  cell or leaving the lesson stops it.
- **`using` must not leak.** A refinement switched on with `using` inside
  `eval` lands in the binding's top-level scope, and every binding made
  from `TOPLEVEL_BINDING` shares that one: after lesson 33, `text` in the
  Scarpe lesson was Processing's, and `loop do` would have been too.
  Lesson, IRB and workshop bindings now come from `TopLevel.binding`,
  an instruction sequence compiled on its own (main.rb), which has a
  scope of its own; `check_harness.rb` does the same.
- **Checks**: `sketch` is the cell's started sketch;
  `sketch.simulate__([["move", x, y], ["down", x, y], ...])` plays
  events frame by frame and returns the shapes drawn, with their
  colours, and puts the sketch's mouse and keys back afterwards.
  `check_harness.rb` loads the stand-in for `require "processing"` and
  starts sketches the same way; `browser_test.mjs` reads pixels, moves
  the real mouse and paints a line.
- Differences from the gem worth knowing: `noise` is Perlin noise of the
  same kind but not the same numbers; text uses the browser's sans-serif;
  `text(str, x, y)` ignores `textAlign` as the gem does (only the box
  form aligns).

## 6i. Faker and its six seconds

Lesson 34 is [Faker](https://github.com/faker-ruby/faker) 3.8 (cached with
i18n and concurrent-ruby; pure Ruby, psych is in the wasm image). Its
first lookup has I18n read the whole load path: 318 YAML files, 4.6 MB,
some 60 languages. In Chrome that is about six seconds - nearly all of it
libyaml and Psych building the tree (`Psych.parse` alone takes as long);
symbolizing and merging take 0.2 s. English is 42% of it, so loading only
the locales in use would still take seconds, and would make Faker behave
unlike the gem (`I18n.available_locales`, fallbacks); the lesson says
instead that the first call takes a few seconds, once per page.

A `POST_INSTALL_PATCHES` entry for i18n (`lib/i18n/backend/simple.rb`)
makes those seconds what they are, loading a library: `init_translations`
runs inside `AutoRun.untraced` (off the live run's clock, counted as
library time), and in a live run it raises `AutoRun::NeedsRun`, so typing
is never frozen for six seconds - the hint asks for ▶ (`liveNeedsRun`
names reading a gem's data now). Outside the browser (the harness) the
patch does nothing.

`Faker::Config.random` and `locale` are global (thread-locals), and so is
what `unique` remembers: a cell that throws six unique dice runs twice
only because it starts with `Faker::Number.unique.clear` - the lesson
says why. The exercise checks the seed (`Faker::Config.random.seed`) and
the shape of the customers, not their names.

## 6j. ERB, and Herb's parser as WebAssembly

Lesson 35 is ERB (stdlib: `result_with_hash`, `trim_mode: "-"`,
`ERB::Util.h` against XSS, a page through a Rack lambda in the mini
browser) and then [Herb](https://herb-tools.dev), which parses HTML and
ERB together and reports what ERB lets through. Herb's gem is Ruby - AST
nodes, errors, the visitor, `Herb::Engine` - around one C extension,
`herb/herb`, the parser.

- **The gem** is in the cache, pinned to 0.10.3 (`PINNED`), and installs
  despite its `extconf.rb` (`PURE_FALLBACK_GEMS` / `ALLOW_EXTENSIONS`).
  Its archive has `content_security_policy?.yml`, so it cannot be
  unpacked on Windows (the lesson says so); the wasm filesystem does
  not mind.
- **The parser**: `tools/vendor_herb.rb` takes `@herb-tools/browser`
  0.10.3 (libherb and its prism compiled to WebAssembly, inlined into one
  ES module as raw bytes - hence `-text` in `.gitattributes`) and the
  three files of `@ruby/prism` it imports, from the npm registry,
  checked against its sha512, and points those imports at the copies.
  No bundler, nothing installed or run. `index.html`'s `ensureHerb`
  imports it (the shell calls it for a lesson whose code has
  `require "herb"`; `bridge.js` holds runs until it is there, as for
  Python), and `chunkyHerbCall(op, json)` answers synchronously with the
  backend's raw result as JSON.
- **`herb_bridge.rb`**, served for `require "herb/herb"`, is the C
  extension's part: `Herb.parse`, `lex`, `extract_ruby`, `extract_html`,
  `version`. The JSON has the field names of the gem's constructors
  (`initialize(type, location, errors, <fields...>)`), so a node, an
  error or a warning is built from its class's parameters, by name; the
  class comes from the type (`AST_HTML_ELEMENT_NODE` - `HTMLElementNode`).
  Tokens, ranges, locations and the parser options (timeout in seconds
  for Ruby, milliseconds for the WebAssembly build) are converted on the
  way. `diff`, `arena_stats` and `leak_check` raise NotImplementedError.
  Everything above the parser - `ParseResult#errors`, the tree's
  `inspect`, `Herb::Engine` - is the gem's own code.
- **Tests**: `check_harness.rb` cannot run Herb (no WebAssembly under
  CRuby; the gem does not install on Windows), so the lesson is in
  `BROWSER_ONLY`; `browser_test.mjs` runs every cell and the exercise (a
  Minitest test with `assert_empty Herb.parse(...).errors`, then the
  repaired template).
- Offline: the copy preloads `herb_bridge.rb` (sync XHR); the module is
  imported, which the service worker answers.

## 6k. The embedded cell (embed.html)

One runnable cell on someone else's page (README "Embedding a cell";
experiments/09-embed-cell/NOTES.md has the measurements and the security
analysis it started from).

- **The pieces.** `embed.js`, on the host page, turns every
  `pre[data-chunky]` into an iframe of `embed.html`: the code without its
  shared indentation, deflate-raw and base64url into the fragment
  (`#code=…&gems=…&lang=…&load=…&run=1&id=…`; `src=` takes plain text for
  hand-made links), `loading="lazy"`, and the `sandbox` attribute as a
  second line of defence. The frame posts `{chunkyEmbed: "size", height}`
  and timings with `"*"`; the host page matches them by `event.source`
  (a sandboxed frame's origin is `"null"`) and follows the height. It
  listens only to its own cells (the frames it made, and hand-written
  iframes of the course's `embed.html`), names them itself (`chunky-N`,
  never an id a frame sends), checks that height and `ms` are finite
  numbers and a timing name is a short word, and keeps `timings` in
  prototype-less objects - another child frame on the host page (an ad,
  a video) could otherwise write onto the page's `Object.prototype` with
  an id `"__proto__"` (CodeRabbit, PR #21; `embed_test.mjs` checks it).
  `tools/make_embed_url.rb` writes the same address from Ruby (Zlib with
  window bits -15, `urlsafe_encode64(padding: false)`).
- **Inside** (`embed-frame.js`): the code is on screen as plain text at
  once, CodeMirror takes over when it has loaded. Ruby loads when the cell
  is in view (IntersectionObserver, which in a frame measures against the
  top page), on the first ▶ (`load=click`) or at once (`eager`). It stands
  in for what `index.html` and `shell/bridge.js` give the kernel: a
  one-lesson, one-cell `LESSONS_JSON` (`id: "embed"`), the ui strings from
  `embed-ui.js` (generated by `tools/build_embed_ui.rb`, 38 KB instead of
  lessons.js's 800; `--check` in the test run, as it goes stale with every
  ui string), the bridge subset main.rb calls (`kernelReady`, `ran`,
  `gems`, `installed`, `steps`), `getCellCode`/`markCellLine`, the sync
  fetch helpers, `afterPaint`, and before the kernel `letter.js`,
  `processing.js` and `game.js`. main.rb itself is unchanged: it keeps a
  cell's code only through the shell's `chunkySaveCode`, which the embed
  does not register.
- **Accessibility**: the editor is named (`ui.embedCode`) and described
  (`ui.codeHint`: Shift+Enter, and Escape then Tab leaves it - no keyboard
  trap); ▶ keeps the focus through a run (disabled while it runs, focused
  again after); a polite `#runStatus` says what the run did
  (`ui.embedRanOk` / `embedRanError`: the output, shortened, pictures,
  games and sounds by their names).
- **Security model.** The code comes from whoever made the link, and the
  page is on the course's host. So `embed.html` is served with
  `Content-Security-Policy: sandbox allow-scripts allow-popups
  allow-popups-to-escape-sandbox allow-downloads; frame-ancestors
  https://idogawa.com; …` (§7): it runs in an **opaque origin** however it
  is opened (iframe or plain link), with no localStorage, IndexedDB, Cache
  Storage, service worker or cookies - none of the learner's progress,
  workshop files, connected folder or offline copy (the experiment showed
  code reading the progress without it). No `allow-same-origin`, no
  `allow-top-navigation`, no `allow-forms`. `frame-ancestors` lets only
  https://idogawa.com frame it (not www., not http); a link opens it
  anywhere. The rest of the policy is hardening: scripts, styles, fonts,
  media and connections from its own host only (`'unsafe-eval'`: the js
  gem calls `JS.eval` while it boots; `'wasm-unsafe-eval'` for ruby.wasm).
  As the frame's origin is opaque, every file it loads from the course's
  host is cross-origin: static files carry `Access-Control-Allow-Origin:
  *` (§7). And if the header ever goes missing (`self.origin` is not
  `"null"`), `embed-frame.js` runs nothing and says so
  (`ui.embedNoSandbox`) - the optional server (§7a) serves the file
  without it, so there the cell only says that.
- **No bridges for the embed.** A page in an opaque origin sends **no
  Referer** (Referrer Policy: "if document's origin is opaque, no
  referrer"; checked in Chromium), so its requests to `/rubygems/` and
  `/proxy/ruby-lang/` look like any other site's sandboxed frame and are
  refused (§7). Gems come from the course's cache (`data-gems="chunky_png"`
  works), `Net::HTTP` and gems outside the cache do not. Letting them
  through would mean allowing `Origin: null` without a Referer - every
  sandboxed frame on every site.
- **Not here (yet)**: three.js (`ensureThree` is a stub), Python/PyCall
  and SQLite/Sequel (their `ensure*` from index.html), exercise checks,
  live runs, ⏯. Each is a copy of existing code, not new design.
- **Costs**: every iframe is its own ruby.wasm VM (about 1 s of compile and
  boot and tens of MB); Chrome partitions the HTTP cache by top-level
  site, so a reader with the course cached downloads the 10 MB once more
  per blog. `load=click` for a page with many cells.
- Not in the offline copy (`tools/offline_files.rb` leaves `embed*` out).
- Tests: `test/embed_test.mjs` against the dev server started with
  `FRAME_ANCESTORS="http://blog.test:*"` - a made-up blog (blog.test, a
  server in the test) embeds cells from course.test: the code, the opaque
  origin, ▶ by keyboard (result, focus, what is read out), the height,
  chunky_png from the cache, `load=click`/`visible`, the course's storage
  out of reach, a plain link, the bridge refused, evil.test not allowed to
  frame it, and the page without its header running nothing.

## 6l. ruby2d: the gem's own Ruby, its C extension in Ruby

Lesson 39 runs [ruby2d](https://www.ruby2d.com) 1.0.0 programs as they are
(the try-it tutorial on ruby2d.com uses the same API). The gem is Ruby -
`Window`, events, `Renderable`, `Color`, every shape, `Text`, the DSL -
around a C extension on SDL3 (`Ruby2D::Ext`, ~90 functions), which a
browser cannot load.

- **Its Ruby, unchanged**: `tools/vendor_ruby2d.rb` downloads the .gem,
  checks it against the SHA-256 rubygems.org lists, and joins 27 of its
  `lib/ruby2d/*.rb` - in the order its `ruby2d/core.rb` requires them -
  into `html/assets/ruby2d/ruby2d.rb` (~200 KB), with its LICENSE.md.
  Left out: the CLI and `cli/colorize.rb` (it adds `#bold`, `#error` … to
  every String of the page), sprites, sprite sheets, tilesets, the pixel
  canvas, bitmap text, buttons. A new ruby2d: bump `VERSION`, rerun, run
  `test/ruby2d_test.rb` and the lesson.
- **`html/ruby2d.rb`** is what the page adds: `Ruby2D::Ext` in Ruby - every
  draw call of a frame appends a command (`["q", 4 corners, rgba]`,
  `["c", x, y, r, sectors, rgba]`, `["x", text, ...]`, the list is at its
  top) that game.js paints; a Text's size comes from the page's canvas
  (`Ruby2D.measure__`, `chunkyCanvasTextWidth`; height 1.26 em, the gem's
  Outfit), drawn in Atkinson Hyperlegible Next. Images and `Audio` exist
  (the gem's classes) but `Ext.image_create`/`audio_load` raise
  `Ruby2D::Error` "not on this page" in the lesson's language
  (`Ruby2D.lang__`), and so do the left-out classes and any other `Ext`
  function (`method_missing`); `Font.default` need not exist on disk.
  Per-corner colours (`color: ["red", "yellow", "lime", "blue"]`) are
  drawn as 8 × 8 pieces of the blended colour; a polygon's are averaged.
- **`show` does not block.** The gem's CRuby `show` runs `tick until
  @close`. Here `Window#show` hands a `Page::Runner` to
  `Ruby2D.on_show__` (main.rb: `add_game`) and returns; the cell ends and
  `mount_game` mounts it like a `show_game` (§6). game.js calls
  `Runner#step(now, events)` every animation frame at most 60 a second
  (`next`; `set fps_cap: 30` halves it) with the events since the last:
  `k:left`/`u:left` (keys by SDL's scancode names, lowercased, from
  `e.code` - physical keys, as SDL gives them), `d:x,y,left`/`p:...`
  (mouse buttons), `m:x,y,dx,dy` (one move a frame), `w:dx,dy`. A step is
  the gem's tick: the events (`key_callback`, `mouse_callback`, which also
  fire per-object `on(:click)`), a held event for every key and button
  still down (SDL reports them every frame), `update_callback` (dt from
  the page's game clock, `Ext.now`), the scene (`render_objects`,
  `Window.frames` + 1). Its answer: `{"bg", "c": [commands], "next",
  "log", "over", "error"}`; the whole scene every frame. Code after `show`
  runs before the first frame - on a computer it runs after the window
  closed. `close` ends the frames (`over`; no restart: ▶ runs the cell
  again); the gem's web build ignores `close`, its desktop build quits.
- **One window per program**: the gem allows one (`DSL.window`,
  `Window.shown?`). Each cell run is a program: `run_cell` calls
  `Ruby2D.reset__`. Windows of other cells keep running, so while a
  frame runs `DSL.window` is that window (`Runner#current`) - a
  `Circle.new` in an `update` lands in its own window.
- **`require "ruby2d"`** is a shim in main.rb (like `processing`, §6h):
  the first fetches both files (sync XHR, untraced, library time; the
  offline copy preloads them) and evaluates them; then `Ruby2D.mix__`
  does what the gem's `ruby2d.rb` does with `include Ruby2D` and `extend
  Ruby2D::DSL`, in a way that can be undone: Ruby2D's constants set on
  Object, the DSL's methods as singleton methods of main. **All lessons
  share one Ruby**, so `sync_state` (another lesson, a reset) calls
  `unmix__` and forgets the shim ran (`BrowserGems.loaded`), and the next
  `require "ruby2d"` mixes again. `require "ruby2d/core"` loads without
  mixing, as in the gem. A learner's own `include Ruby2D` at the top level
  stays, as it would in any program.
- **Checks** get `games` as for Snake: `Runner#fresh` replays the cell's
  code (`source`, set by `run_cell`) in a binding of its own
  (`Ruby2D.replay__`: `TopLevel.binding`, `chunky.rb`), output dropped,
  under the check's time limit - so the window below the cell keeps its
  state. A check drives the copy with `press(key, frames:)`, `click(x,
  y)`, `move_mouse`, `tick(n)`, `advance(seconds)` and reads `objects`
  (the scene, the gem's own shape objects), `width`, `height`, `over?`.
  The replay sees no locals of earlier cells: exercise cells must stand
  alone (every cell of the lesson does). The lesson's check holds → and
  ← until Chunky must have reached both edges.
- **Speed**: a frame of the keys demo costs ~3-4 ms with the guard on
  (Chrome, headless); the first `require` ~0.3-0.5 s.
- **Tests**: `test/ruby2d_test.rb` (CRuby, no page), `check_harness.rb`
  (the same shim through `SHIMS_DIR`; `unmix_ruby2d` before every
  lesson), `browser_test.mjs` (the canvas's pixels, keys and the mouse via
  the log, error with line, time limit, `close`, a sprite refused, the
  exercise, the next lesson unmixed). The real gem was not run here: it
  needs SDL3 with SDL3_mixer, which Debian 13 does not package; the
  lesson's programs are checked against the gem's own Ruby instead.

## 6m. Other Rubies, and a lesson on PicoRuby

Lesson 40 (`rubies`) is plain CRuby: what an implementation is,
`RUBY_ENGINE`/`RUBY_PLATFORM` (`wasm32-wasi`, no YJIT in the browser),
JRuby, TruffleRuby, mruby, mruby/c, PicoRuby, IronRuby (with a link to
[Largo/ironruby](https://github.com/Largo/ironruby), the author's fork for
Ruby 4.0 on .NET), RubyMotion, DragonRuby and the rest, and an exercise
that maps engine names. Its version numbers were checked on 2026-10-06 -
JRuby 10.1 targets Ruby 4.0, TruffleRuby 40.0.0 is Ruby 4.0.2, mruby 4.0.0
(2026-04-20) has build configurations for Emscripten and WASI, IronRuby
4.0.1 (2026-10-02) runs on .NET 8 and 10, Artichoke's repository is
archived - and go stale with the next releases, in three languages.

Lesson 41 (`picoruby`, `"engine": "picoruby"`) runs its cells and its IRB
on **PicoRuby.wasm** instead of CRuby:

- **Nothing new to download.** It is the shell's runtime
  (`html/assets/picoruby/`, 0.9 MB gzipped, cached by then), a second
  instance - not in the page's window and not on its thread. PicoRuby keeps
  its JavaScript references and handlers in globals
  (`globalThis.picorubyRefs`, `picorubyEventHandlers`,
  `picorubyGenericCallbacks`), which two instances in one window would
  share; and it counts its time slices in ticks that only JavaScript
  advances, so `loop {}` never returns from `_mrb_run_step_status` - it
  would freeze the page. So it runs in a module **Web Worker**, which the
  page can end.
- `picoruby_lab.js` (the page): `ensurePicoRuby` (the shell calls it when
  the lesson opens, `Course#picoruby?`), `chunkyPicoRuby.run / irb /
  reset`, one request at a time, the time limits (a live run 1 s, ▶ and an
  IRB line 10 s), the answers as `chunky:picoruby` events.
  `picoruby_worker.js` boots the runtime (~0.3 s) and, per request, turns
  PicoRuby's scheduler itself (the tick and `_mrb_run_step_status`, what
  `init.iife.js` does on timers) until `picoruby_lab.rb` has answered.
  That file is a PicoRuby Task: it takes requests (`PicoLab.take`) and runs
  each in a `Sandbox` (picoruby-sandbox, what PicoRuby's own IRB uses) - one
  for the cells, one per IRB. Not `register_callback` blocks: a Sandbox
  starts a Task, and PicoRuby refuses the Task API inside a callback
  JavaScript calls synchronously ("Cannot use asynchronous Task API during
  synchronous execution").
- **A notebook**: a Sandbox compiles the next code with the local variables
  of its last run (picoruby-sandbox's `result` rebuilds the scope). The code
  is wrapped as in PicoRuby's IRB, `begin; _ = (code\n); rescue Exception
  => _; end; _`, so `_` is the last answer in cells and IRB alike, and an
  exception comes back as the value: its class, its message and the line
  from its backtrace. What the run printed comes from `Module.print`
  (the "Exception in task: ..." lines the Task machinery adds dropped; a
  marker line flushes a `print` without a newline, which Emscripten holds
  back otherwise).
- **The kernel's side** (`main.rb`, `picoruby_cells.rb`): `run_cell` hands
  the code over (`start_picoruby_run`) and returns `:pending`, so
  `finish_cell_run` leaves `ran` to `picoruby_answer`, which writes the
  output as `run_cell` does for CRuby (`show_picoruby_run`) and checks the
  exercise. Code that does not parse never goes out: CRuby's Prism says why
  and where (`RubyVM::InstructionSequence.compile`) - PicoRuby parses with
  Prism too, but its compiler answers only `false` - and the friendly
  explanation applies. A runtime error becomes CRuby's exception of the same
  name (`NoMethodError`, `RangeError`, ...) at `chunky.rb:<line>`, so the
  explanations and the line mark work; one CRuby lacks is a
  `PicoRubyCells::Error`. A check's `result` is a `PicoRubyCells::Value`,
  equal to an object with the same `inspect` (`result == {"a" => 1}`
  works, `{"a" => 1} == result` does not); `nil`, `true`, `false` come as
  themselves. The IRB is `show_irb`'s widget with `pico: true` in its
  session: Prism decides "unfinished" (`INCOMPLETE_RE`, as for CRuby), the
  line goes to the worker, the answer is appended when it comes.
- **Past the time limit** the worker is ended and a new one started: every
  variable of the cells and the IRBs is gone, and the message says so
  (`picoStopped`, `picoRestarted`; a live run says `liveStopped` first). A
  new page or a reset drops the sessions (`sync_state`), and answers for
  an earlier page are ignored (`seq`).
- PicoRuby is not CRuby, and the lesson says so: `RUBY_ENGINE` is
  `"mruby"` (PicoRuby 4 runs on mruby's VM; `PICORUBY_VERSION` is its own),
  no `sum`/`tally`/`sort_by`/`group_by`/`zip`/`each_slice`, no `Struct`,
  `Set` or blockless enumerators, 64-bit integers that raise `RangeError`;
  but `Task`, `sleep_ms`, JSON, YAML, Markdown and SQLite3. An unknown name
  says "undefined method 'x' for Class". `gets` answers nil (the worker has
  no `window.prompt`, which PicoRuby's would wait for). A Task that is not
  joined keeps running whenever the scheduler turns - in later runs.
- Not in the workshop, the embedded cell or ⏯. Tests:
  `test/check_harness.rb` runs the exercise under CRuby with the result
  handed over as a `Value` (the demos need PicoRuby and are skipped);
  `test/picoruby_test.mjs` the rest, in a browser.

## 7a. The optional server: permalinks and a backend

The course is a static site and stays one: without `server/` lessons live at
`/#methoden`. `server/app.rb` (Roda, run by Puma) adds what a static host
cannot:

- **Permalinks**: `/`, `/de`, `/de/methoden`, `/de/werkstatt` answer with
  `index.html`, plus `<base href="/">` (relative URLs keep pointing at the
  site's root) and `<meta name="chunky-permalinks" content="/">`. For a
  lesson also `<html lang>`, its title, its first paragraph as description
  and `og:` tags, a canonical link and `hreflang` alternates - what search
  engines and link previews read. Unknown languages and lessons are 404.
  The course comes from `html/lessons.js` itself (`server/course.rb`),
  parsed again when the file changes.
- **The page side**: `shell/bridge.js` reads the meta tag
  (`ChunkyBridge.permalinks`, the base path) and takes the language from the
  path; `shell/router.rb` builds links and addresses either way - `#id` or
  `/lang/id` - with `history.pushState`, back/forward through `popstate`,
  an old `/#methoden` link turned into `/de/methoden`, a language switch
  into `/en/methoden`. main.rb points `JS::RequireRemote` at
  `document.baseURI`: it would resolve `require_relative` against
  `location.href`, i.e. under `/de/`.
- **Backend code** goes under `/api` (`/api/lessons` for now: ids and
  titles as JSON).
- **Files** come from `html/` as they are (Roda's `public` plugin, the
  `.gz` copies of the wasm runtimes, `Cache-Control: no-cache`), text
  compressed by `Rack::Deflater`; the rubygems and ruby-lang bridges are
  the same as nginx's (hardcoded hosts, GET/HEAD, two path shapes on
  rubygems) - without nginx's cache and rate limit.

Locally: `cd server && bundle install && bundle exec puma -b
tcp://127.0.0.1:8012 config.ru`, then `test/permalink_test.mjs` against it
(`ruby test/server_test.rb` needs no port).

On the host: `docker compose --profile server up -d` starts it beside nginx
(port 8012 on localhost, `ruby:4.0`, gems in the `serverbundle` volume).
nginx keeps the files and the bridges and hands the page's addresses over -
inside the `server` block of `nginx/default.conf` (with a variable, nginx
starts even when the server does not run; those addresses are then 502):

```nginx
location ~ ^/((de|en|ja)(/[^/]*)?)?$ {
    resolver 127.0.0.11 ipv6=off valid=30s;
    set $chunky_server http://chunkybacon-server:9292;
    proxy_pass $chunky_server;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
}
location ^~ /api/ { ... the same ... }
```

The host's own reverse proxy must pass `X-Forwarded-Proto` through, or the
canonical links say `http`. A new language in `lessons.js` needs its code
in that regex.

## 8. Tests and a private dev copy

```sh
cd test
node make_lessons_json.js      # test/lessons.json
ruby check_harness.rb          # 57 lessons x 3 languages, starter fails, solutions pass
ruby lint_lessons.rb           # lessons.js content: de/en/ja parity, references, Japanese rules, Prism, gems, counts
ruby lint_lessons_test.rb      # the linter's fault-injection tests
ruby gems_harness.rb           # installer, sinatra/roda, nokogiri, bigdecimal, errors
ruby shell/run.rb              # the shell under Minitest, with PicoRuby portability scans
ruby autorun_test.rb           # live runs: runnable?, the time limit, rescue-proof
ruby ansi_test.rb              # terminal colours in a cell's output
ruby game_test.rb              # show_game headless: the lesson's Snake, restart, check copies
ruby ruby2d_test.rb            # ruby2d headless: frames, draw commands, keys, mouse, replayed copies, mixing, lesson 39's cells
ruby step_recorder_test.rb     # ⏯'s recorder: steps, frames, hidden locals, caps, the stepper lessons' cells
ruby friendly_errors_harness.rb --summary   # 70 beginner mistakes explained by the expected rule, de/en/ja
ruby friendly_errors_robustness.rb          # explain never raises, never leaves a %{...}
ruby ../tools/offline_files.rb --check   # the offline copy's file list is current
BASE=http://127.0.0.1:8011/ node browser_test.mjs   # Playwright, ~5 min
BASE=http://127.0.0.1:8011/ node offline_test.mjs   # offline mode (§6c), ~1 min
ruby dev_server_test.rb                  # the bridge rule and the embed's headers, dev server and nginx alike (§7)
ruby ../tools/build_embed_ui.rb --check  # html/embed-ui.js has the current ui strings
# with the dev server started as FRAME_ANCESTORS="http://blog.test:*" ruby tools/dev_server.rb:
BASE=http://127.0.0.1:8011/ node embed_test.mjs     # the embedded cell (§6k), ~1 min
BASE=http://127.0.0.1:8011/ node picoruby_test.mjs  # the PicoRuby lesson (§6m), ~30 s
ruby ../tools/vendor_picoruby.rb --check            # the PicoRuby runtime is what PICORUBY_VERSION.txt records
```

The CRuby harnesses exercise the real `browser_gems.rb` with `File.read`
fetchers and a temp `BrowserGems.root`. They use native nokogiri-pure /
bigdecimal under CRuby; force the pure BigDecimal with
`BIGDECIMAL_PURE=1 RUBYLIB=/path/to/bigdecimal-pure/lib`.
`browser_test.mjs` needs Playwright at `/usr/local/lib/node_modules/playwright`
and a server with the proxy (a plain `python -m http.server` fails the 4
proxy-dependent checks).

Because `html/` is live, develop risky changes in a worktree served by a
throwaway nginx on localhost:

```sh
git worktree add -b my-change ../chunkybacon-dev main
docker network create chunkybacon-dev
docker run -d --name chunkybacon-dev --network chunkybacon-dev -p 127.0.0.1:18011:80 \
  -v $PWD/../chunkybacon-dev/html:/usr/share/nginx/html:ro \
  -v $PWD/../chunkybacon-dev/nginx:/etc/nginx/conf.d:ro nginx:1.27-alpine
BASE=http://127.0.0.1:18011/ node test/browser_test.mjs
# then: git merge --ff-only, push (the host deploys it), remove container + worktree
```

A quick way to run arbitrary Ruby in a cell from Node (used for the gem
probes): set a demo cell's code with `window.cellEditors[idx].setValue(code)`,
click `.run-cell[data-idx=idx]` (with `noWaitAfter`, the page freezes) and
read `#cell-out-<idx>`.

## 9. Updating ruby.wasm

`ruby tools/update_ruby_wasm.rb` fetches the latest `@ruby/4.0-wasm-wasi`
npm package, installs `browser.script.iife.js` + `ruby+stdlib.wasm` into
`html/`, patches the loader's hardcoded jsDelivr URL to our host and rewrites
`ruby+stdlib.wasm.gz` (`tools/compress_assets.rb`). After
an update re-check: `io/wait` still absent (else the net/http shim loses),
`csv`/`benchmark` still not bundled (they auto-install from the cache),
Minitest, and the nokogiri load (deep-AST stack limits differ per build;
nokogiri-pure's CI has a wasm job for this).

## 9a. Vendored runtimes: each has a tool

The page loads its runtimes and libraries from its own server, and a push
to `main` is the deploy (§1) - so what it loads is in the repository. Each
part is written by a tool that downloads a pinned version from its
registry, checks it against the registry's checksum before unpacking, and
is rerun to update it:

| What | Where | Size | Tool | Check |
|---|---|---|---|---|
| CRuby (ruby.wasm) | `html/ruby+stdlib.wasm` | 32 MB (10 MB .gz) | `tools/update_ruby_wasm.rb` | `tools/compress_assets.rb --check` |
| PicoRuby.wasm | `html/assets/picoruby/` | 2 MB (0.9 MB .gz) | `tools/vendor_picoruby.rb [version]` | `tools/vendor_picoruby.rb --check` |
| Pyodide + packages | `html/assets/pyodide/` | 56 MB | `tools/vendor_pyodide.rb` | SHA-256 per wheel |
| sql.js | `html/assets/sqljs/` | 1 MB | `tools/vendor_sqljs.rb` | |
| Herb's parser | `html/assets/herb/` | 2 MB | `tools/vendor_herb.rb` | |
| ruby2d's Ruby | `html/assets/ruby2d/` | 0.2 MB | `tools/vendor_ruby2d.rb` | SHA-256 from rubygems.org |
| the gem cache | `html/gems/cache/` | 11 MB | `tools/build_gem_cache.rb` | |

Afterwards `tools/compress_assets.rb` (the `.gz` copies) and
`tools/offline_files.rb` (the offline copy's list). The PicoRuby lesson
(§6m) added no file to this: it runs a second instance of the shell's
runtime. Re-running `tools/vendor_picoruby.rb` for the pinned version
writes the same bytes; only `PICORUBY_VERSION.txt` and `NOTICE.md` are its
own record.

Leaving these out of git and generating them on the host would keep the
repository smaller (Pyodide is most of it), but needs a build step on
every deploy and the network on the host - and history keeps every
version committed so far either way. Worth it only together with a change
to how the host deploys; until then, update a runtime only when there is a
reason to, since every version stays in the history.

## 10. Related repositories

- [nokogiri-pure](https://github.com/Largo/nokogiri-pure) - differential
  tests against native Nokogiri; `wasm/test.sh` runs loofah &
  rails-html-sanitizer under ruby.wasm and diffs against native output.
- [bigdecimal-pure](https://github.com/Largo/bigdecimal-pure) - no NaN/
  Infinity, no `BigDecimal.limit/mode`; `BigMath` via Float.
- [ruby_pptx](https://github.com/Largo/ruby_pptx) - REXML backend
  (`RUBY_PPTX_XML_BACKEND`) is what runs here; lesson 21.
- [BrowserRubyKoans](https://github.com/Largo/BrowserRubyKoans) - the
  original foundation (koans.idogawa.com), linked as the follow-up course.
- [three-rb](https://github.com/lef237/three-rb), [lacci / scarpe](https://github.com/scarpe-team/scarpe)
  - lessons 20 and 31.
- [Prawn](https://github.com/prawnpdf/prawn), [HexaPDF](https://hexapdf.gettalong.org/)
  (AGPL-3.0 or commercial) - lesson 22.

## 10a. The companion gem (`gem/`)

`chunky_bacon` (named by the RubyGems guide: two words, underscore, module
`ChunkyBacon`) takes the course to the learner's computer. Pure Ruby, no
dependencies, Ruby >= 3.1. Code MIT; the fox drawing (`lib/chunky_bacon/fox.txt`,
read by `fox.rb`) CC BY-SA 4.0 like the course's other content
(`LICENSE-ASSETS`) - any further asset goes into a file of its own and under
that license too. Contact in the gemspecs: web@idogawa.com.

- `require "chunky_bacon"` defines the notebook helpers as private Kernel
  methods - same names, arguments and defaults as `main.rb`'s. What the page
  showed below a cell becomes a file in the program's folder
  (`ChunkyBacon.output_dir`), opened in the system viewer
  (`ChunkyBacon::Opener`; `CHUNKYBACON_OPEN=0` turns that off). Status lines
  go to stderr. `show_browser` runs `ChunkyBacon::Server`, a tiny HTTP server
  on 127.0.0.1, and keeps the program alive after its last line until
  Ctrl+C. `show_three`/`show_shoes`/`show_game` raise `ChunkyBacon::NotHere` with what
  to do instead. When `main.rb` changes a helper, change the gem's too.
  `show_objects` comes from `lib/chunky_bacon/object_graph.rb`, a copy of
  `html/object_graph.rb` (`test/object_graph_test.rb` fails when they
  differ); its SVG goes through the gem's `show_image` as
  `chunky-image-N.svg`. `turtle { }` likewise, from
  `lib/chunky_bacon/turtle.rb` (`test/turtle_test.rb`), an animated SVG.
  `show_audio` saves `chunky-sound-N.wav` (samples written as 16-bit mono)
  and opens it; a path opens that file.
- Under ruby.wasm (`ChunkyBacon.browser?`) the gem leaves the page's helpers
  alone and only adds the fox. Lesson 14 opens with
  `install_gem "chunky_bacon"` + `ChunkyBacon.shout`, from the gem cache
  (`html/gems/cache/chunky_bacon-0.1.0.gem`, the published file - same SHA-256
  as on rubygems.org; first in `tools/build_gem_cache.rb`'s list, so its chip
  leads the gems panel). A new release does not need a new cached copy unless
  the lesson uses something new.
- `chunkybacon` (exe): the fox; `chunkybacon run [FILE]` = a child Ruby with
  `-r chunky_bacon`, the terminal as stdin, its exit status.
- `gem/chunkybacon` and `gem/chunky-bacon` are aliases (like `rubyllm` for
  `ruby_llm`): each depends on `chunky_bacon >= 0.1` and requires it, and
  needs no new release when `chunky_bacon` gets one. They keep the other
  spellings from going to someone else.
- Tests: `cd gem/chunky_bacon && rake test` (Minitest; the CLI tests run the
  real command in a temp folder).
- Releasing: bump `lib/chunky_bacon/version.rb` and the CHANGELOG, commit,
  then push a tag `chunky_bacon-v<version>`. `.github/workflows/release.yaml`
  tests, checks the tag against `version.rb`, builds all three gems and
  pushes them by **trusted publishing** (rubygems.org trusts that workflow
  file in this repo with the `rubygems` environment; no API key exists - the
  environment name is part of each gem's trusted-publisher entry on
  rubygems.org, so rename both or neither). It
  pushes `chunky_bacon` first and skips versions already on rubygems.org, so
  the aliases stay at 0.1.0 until their own version is bumped. The workflow
  can also be started from the Actions tab.

## 11. Open ends

Current work in progress has its own file: `docs/OPEN_WORK.md`.

- Lesson 15 could show more Nokogiri (XPath, Builder) now that it works.
- `NATIVE_GEMS` is a hand-kept list; a gem not on it still gets downloaded
  before its `extconf.rb` is noticed (cheap, but the message arrives late).
- The mascot: Andi wanted _why's original foxes traced; the poignant
  guide's licence could not be verified, so the fox is an original drawing.
