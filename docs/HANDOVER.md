# Handover: Ruby lernen mit Chunky Bacon

Everything you need to run, change and extend the site. The README says
what the site is; this document says how it works and where the traps are.
Last updated 2026-09-30 (37 lessons in German, English and Japanese).

## 1. Where it runs

| | |
|---|---|
| Live | port 8011 on the server (no domain yet); its address and the host's paths are kept outside the repository |
| Host | container `chunkybacon` (nginx:1.27-alpine) |
| Checkout on the host | this repo, branch `main` |
| GitHub | https://github.com/Largo/chunkybacon (public) |

`docker-compose.yml` bind-mounts `html/` read-only into the container and
`nginx.conf` as the server config. Consequences:

- **Saving a file under `html/` is a deploy.** There is no build step and no
  restart. nginx sends `Cache-Control: no-cache` for html/rb/js/css/json, and
  `index.html` forces `cache: "no-cache"` on the `.rb` fetches, so a normal
  reload picks up the change.
- **Changing `nginx.conf`** needs `docker exec chunkybacon nginx -t && docker exec chunkybacon nginx -s reload`.
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
  index.html            page shell, JS helpers the Ruby side calls (fetch*Sync,
                        ensureThree, afterPaint, cell editors), import map
  browser.script.iife.js  ruby.wasm browser loader (patched: fetches OUR wasm)
  ruby+stdlib.wasm      Ruby 4.0 (@ruby/4.0-wasm-wasi 2.10.1), 32 MB
  main.rb               the app: ChunkyApp (lessons, cells, checks, widgets,
                        i18n, persistence) plus browser-environment fixups
  lessons.js            ALL lesson content + UI strings, as JSON in JS
  browser_gems.rb       gem installer + stdlib shims (socket, net/http, resolv)
  sandbox_sim.rb        virtual FS for relative paths, virtual sleep,
                        Fiber-based Thread, FileWatch (downloads)
  rack_playground.rb    show_browser: talks Rack to Sinatra/Roda apps, mock_get
  shoes_dom.rb          Lacci (Shoes) display service drawing into the page
  workshop.rb           the workshop's runs: project files as the virtual FS,
                        require_relative between them, gets, write-back
  storage.js            where the work lives: localStorage change times, the
                        progress file, a connected folder (File System Access)
  workspace_ui.js       the progress dialog and the workshop's file panel
  assets/               app.css, CodeMirror, three.js (vendored), the fox SVG,
                        fonts/ (self-hosted web fonts + fonts.css, OFL 1.1)
  gems/cache/           .gem files + manifest.json (instant offline installs)
nginx.conf              static files + same-origin bridges (rubygems, ruby-lang)
docker-compose.yml
LICENSE                    MIT for the code; course content is CC BY-SA 4.0 (README)
THIRD_PARTY_NOTICES.md     bundled components and their licenses - update it
                           with the gem cache, the wasm or the vendored assets
tools/build_gem_cache.rb   regenerates html/gems/cache/
tools/update_ruby_wasm.rb  updates the wasm + loader from npm
test/check_harness.rb      every lesson offline under CRuby
test/gems_harness.rb       gem installer offline under CRuby
test/browser_test.mjs      Playwright end-to-end (128 checks)
test/progress_test.mjs     Playwright: progress file, workshop, folder (37 checks)
docs/HANDOVER.md           this file
```

The JS/Ruby bridge: `main.rb` runs inside the wasm and drives the DOM through
`JS.global`. Property access on JS objects is `obj[:prop]`; a dot is a method
call. JS `false`/`null` come back as truthy Ruby objects: compare `.to_s`.

## 3. Lessons

`html/lessons.js` is `window.LESSONS_JSON = JSON.stringify({ ui, lessons })`,
pretty-printed with two spaces. It round-trips through `JSON.parse` /
`JSON.stringify(d, null, 2)` byte-identically, so the safest way to edit
structure (insert a lesson, renumber) is a small node script that parses,
changes and rewrites it; prose edits can be done by hand.

```json
{ "id": "html",
  "section": { "de": "Grundkurs", "en": "Basics", "ja": "基礎コース" },   // optional: starts a nav section
  "de": { "title": "14. HTML parsen", "cells": [ ... ] },
  "en": { "title": "14. Parsing HTML", "cells": [ ... ] },
  "ja": { "title": "14. HTMLのパース", "cells": [ ... ] } }
```

A language is whatever `ui` has a key for: main.rb and workspace_ui.js take
the list from there, `index.html`'s `#langSelect` names them. German has its
own code (German names, Katze/Fuchs); **Japanese runs the English code** -
only the Ruby comments are translated, `check` is byte-identical to `en`, and
the harness checks `ja` with the English solutions. So a change to an English
code cell or check must be made in `ja` too (same cell, same code, comments
in Japanese). Japanese prose is です・ます体, hints are Chunky speaking
(casual); app.css adds Japanese fallback fonts under `:lang(ja)`.

Cells, per language:

| `t` | fields | meaning |
|---|---|---|
| `h` | `html` | prose block; `<div class='task'>` = the exercise text, `<div class='offweb'>` = "on your machine" box |
| `c` | `code` | runnable demo cell |
| `x` | `code`, `check`, `hint` | the ONE exercise cell of the lesson; `check` is Ruby evaluated in the lesson binding with locals `output`, `result`, `code`, `images`, `downloads` |

Rules that the code and tests rely on:

- `id` is stable and is the URL (`/#bigdecimal`); titles carry the number, so
  **inserting a lesson means renumbering every later title in all three
  languages** (see the script pattern in git history of lesson 18) - and the
  prose references like "lesson 22" / "Lektion 22" / 「レッスン22」.
- All cells of a lesson share one binding (notebook kernel). Demo and
  exercise names deliberately differ (Katze vs Fuchs) so a demo cannot
  satisfy the check.
- Checks accept output OR result; `puts` is never required.
- `test/browser_test.mjs` asserts the lesson count (`'37 lessons in nav'`) -
  update it when adding one.
- `test/check_harness.rb` needs a `SOLUTIONS[id]` entry (one or more solution
  snippets for `de` and `en`; `ja` uses `en`'s) or it aborts. Its body runs in
  a method because lesson bindings capture top-level locals, and each
  language runs in a process of its own because top-level `def`/`class`
  outlive the binding (an English solution would let the Japanese starter
  pass). In `%()` literals write `\\d`.
- `test/lessons.json` is generated (gitignored):
  `node -e 'global.window={}; require("../html/lessons.js"); require("fs").writeFileSync("lessons.json", window.LESSONS_JSON)'`.
- Progress, language and per-cell code persist in `localStorage` - and from
  there in a progress file or a connected folder, see §6a.

Helpers available in cells (defined in `main.rb`): `install_gem`,
`show_image` (chunky_png), `show_browser(app, path)` + `mock_get`,
`show_irb`, `show_files`, `show_three(scene, camera, orbit:, &animate)`,
`show_shoes { ... }`, `download_file(data, name)`, `run_tests` (Minitest).

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
  `File`/`Dir`; absolute paths pass through. `sleep` is a virtual clock (a
  real sleep crashes the VM uncatchably); `Thread` is a Fiber scheduler that
  interleaves at sleep points. `FileWatch` snapshots both stores per cell run
  to offer downloads; it skips `BrowserGems.root` and `/tmp`.
- Real `Module#autoload` works now that gems are files; the loader no longer
  hooks it.

## 6. Widgets and their traps

- **show_browser**: synthesises a Rack env; Sinatra's default 404 page
  references an external image (harmless console 404s in tests).
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
- **Running a cell** freezes the page (Ruby is synchronous); the running
  look (stripe, dimmed editor, wobbling fox) is painted before the run via
  `afterPaint` and uses compositor-only CSS animations so it keeps moving.
  Respects `prefers-reduced-motion`.
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
  travels as `v: null`, `chunky_done` is united. main.rb re-renders on the
  `chunky-progress-loaded` event.
- **Folder** (Chrome/Edge, File System Access API): *Ordner wählen* picks a
  folder; its handle is kept in IndexedDB. Every change is merged into
  `chunkybacon-progress.json` there (800 ms debounce, flushed when the tab is
  hidden). After a browser restart the permission may need one click
  (*Ordner wieder öffnen*; the button shows an orange dot). **Needs a secure
  context**: https or localhost. On the current `http://<ip>:8011` the
  browser hides the API and the dialog offers only the file.
- **Workshop** (`#werkstatt`, link above the lessons): the learner's own
  programs. Without a folder the files are `chunky_file:<path>` keys (so they
  travel in the progress file); with a folder they are real text files in it
  (read in at connect and on window focus; dotfiles, `node_modules`,
  `vendor` and files over 1 MB skipped). The editor is cell 0; main.rb's
  `run_cell` hands the run to `workshop.rb`: project files become
  `SandboxFS.store`, `require_relative` resolves project files, `gets` reads
  the input box, `$0` names the file; afterwards written/deleted text files
  go back through `workspaceWrite`/`workspaceDelete` and the lesson's demo
  files return. A run saves the open file.
- Dev on this machine: serve on localhost (127.0.0.1 counts), where the
  folder API is available. `test/progress_test.mjs` drives the folder through
  the origin-private file system (same API, no native picker).

## 7. nginx and the proxy

Compression: `gzip on` for text (html, rb - typed `text/plain` in the app-code
location, since `mime.types` has no `.rb` -, js, css, json, svg) and
`gzip_static on`, which serves `ruby+stdlib.wasm.gz` in place of the wasm.
Only files that change through a tool get a `.gz` (`tools/compress_assets.rb`),
so a hand-edited lessons.js or main.rb can never be shadowed by a stale one.

`nginx.conf` is deliberately not an open proxy: upstream hosts are
hardcoded (`rubygems.org`, `www.ruby-lang.org`), only the path is forwarded,
`GET`/`HEAD` only, rubygems locked to `api/v1/gems/` and `gems/`, per-IP
`limit_req` 5 r/s with burst 60 (a gem with many dependencies makes two
requests per dependency), responses disk-cached (gems 60 days). Locations
are `^~` so the no-cache regex cannot capture proxied `.json`. The resolver
is Docker's `127.0.0.11`, which only exists on user-defined networks - a
container started with plain `docker run` on the default bridge gets 502s.

## 8. Tests and a private dev copy

```sh
cd test
node -e 'global.window={}; require("../html/lessons.js"); require("fs").writeFileSync("lessons.json", window.LESSONS_JSON)'
ruby check_harness.rb          # 37 lessons x 3 languages, starter fails, solutions pass
ruby gems_harness.rb           # installer, sinatra/roda, nokogiri, bigdecimal, errors
BASE=http://127.0.0.1:8011/ node browser_test.mjs   # Playwright, ~5 min
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
  -v $PWD/../chunkybacon-dev/nginx.conf:/etc/nginx/conf.d/default.conf:ro nginx:1.27-alpine
BASE=http://127.0.0.1:18011/ node test/browser_test.mjs
# then: git merge --ff-only, reload nginx if nginx.conf changed, push, remove container + worktree
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

## 10. Related repositories

- [nokogiri-pure](https://github.com/Largo/nokogiri-pure) - differential
  tests against native Nokogiri; `wasm/test.sh` runs loofah &
  rails-html-sanitizer under ruby.wasm and diffs against native output.
- [bigdecimal-pure](https://github.com/Largo/bigdecimal-pure) - no NaN/
  Infinity, no `BigDecimal.limit/mode`; `BigMath` via Float.
- [ruby_pptx](https://github.com/Largo/ruby_pptx) - REXML backend
  (`RUBY_PPTX_XML_BACKEND`) is what runs here; lesson 20.
- [BrowserRubyKoans](https://github.com/Largo/BrowserRubyKoans) - the
  original foundation (koans.idogawa.com), linked as the follow-up course.
- [three-rb](https://github.com/lef237/three-rb), [lacci / scarpe](https://github.com/scarpe-team/scarpe)
  - lessons 19 and 21.

## 11. Open ends

- No domain: when one is bound, add a Caddy reverse proxy in front; the site itself needs no change.
- Lesson 14 could show more Nokogiri (XPath, Builder) now that it works.
- `NATIVE_GEMS` is a hand-kept list; a gem not on it still gets downloaded
  before its `extconf.rb` is noticed (cheap, but the message arrives late).
- The mascot: Andi wanted _why's original foxes traced; the poignant
  guide's licence could not be verified, so the fox is an original drawing.
