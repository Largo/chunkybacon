# 09 - Embeddable runnable Ruby (one Chunky cell on any page)

Prototype, 2026-10-05. Nothing outside this folder was changed.

**In one paragraph.** `embed.html` shows one runnable Chunky Bacon cell, and
the code comes from the address's fragment (`#code=<deflate-raw, base64url>`,
which never reaches the server). The kernel is the course's real,
**unchanged `main.rb`**. A blog post either writes the `<iframe>` itself, or
writes `<pre data-chunky>puts 1+1</pre>` and adds one `<script src=".../embed.js">`
that turns every such block into a cell. The code is on screen **0.1 s**
after the frame starts loading (0.2 s at 20 Mbit/s), after **132 KB**. Ruby
loads only when the cell scrolls into view (or on the first ▶). The first
result arrives **1.4 s** after the host page starts loading (cold cache,
fast line), 1.0 s with ruby.wasm cached, and 6.4 s cold at 20 Mbit/s. The
frame reports its height by postMessage and the host page sizes the iframe to
fit. **Security:** in the course's own origin, code from a link could read
and overwrite the learner's progress, workshop files and the connected
folder (proven below). So `embed.html` is served with
`Content-Security-Policy: sandbox allow-scripts …`, which gives it an
opaque origin with no storage at all, whoever opens it. The kernel runs fine
like that (proven). It still belongs on its own host name.

## What is here

| file | what |
|---|---|
| `site/embed.html` | the cell page: editor, ▶, output, `#lessonBody` for the kernel's widget listeners; a static `<script type="text/ruby" src="main.rb">` that stays inert until ruby.wasm loads |
| `site/embed-frame.js` | the inside of the cell. It reads the fragment, inflates it (`DecompressionStream("deflate-raw")`), shows the code as plain text, then loads CodeMirror. It also stands in for what `index.html` and `shell/bridge.js` give `main.rb`: a one-lesson, one-cell `LESSONS_JSON` stub, the `ChunkyBridge` subset the kernel calls, `getCellCode`/`markCellLine`, the sync XHR helpers and `afterPaint`. It starts ruby.wasm lazily (IntersectionObserver or the first Run) and posts size and timing messages |
| `site/embed-kernel.rb` | the only kernel change, evaluated after `kernelReady`: `ChunkyApp#store` does nothing, so no `chunky_cell_*` keys are written (in the sandbox `localStorage` would throw anyway) |
| `site/embed.js` | for the host page: turns `pre[data-chunky]` into a lazy, sandboxed iframe, strips the shared indentation, follows the iframe's height, and offers `ChunkyEmbed.url(code, opts)` |
| `site/embed.css` | the cell on a transparent page (on top of the course's `app.css`) |
| `site/embed-ui.js` | generated: the course's `ui` strings (de/en/ja, 30 KB, 10 KB gzipped) instead of the 600 KB `lessons.js` |
| `site/demo/host.html` | a fake blog post on `blog.test`: three `pre data-chunky` cells (one with chunky_png, one below the fold), a hand-written iframe (`load=click`) and a probe cell that tries to read the course's storage |
| `site/demo/one.html` | one cell with `data-run=1`, used for the host-side measurement |
| `build_embed_ui.mjs` | `node build_embed_ui.mjs` writes `site/embed-ui.js` from `html/lessons.js` |
| `make_embed_url.rb` | `ruby make_embed_url.rb file.rb [--gems x] [--lang en] [--load click] [--base URL]` prints the address, an `<iframe>` snippet and a Markdown "▶ Run" link (Zlib raw deflate, `Base64.urlsafe_encode64(padding: false)`, the same bytes as the browser) |
| `serve_embed.rb` | dev server on port 18109 that lays `site/` over `html/`, gzips like nginx, and sends the embed headers (CSP sandbox, `Access-Control-Allow-Origin: *`). `?nosandbox` and `?csp=strict` on embed.html switch the headers for comparison |
| `test_embed.mjs` | Playwright: `check` (14 checks) and `measure` (`RUNS=3`), with two made-up sites via `--host-resolver-rules` (`blog.test` embeds `embed.test`) |
| `measurements.json`, `screenshots/` | results |

The fragment parameters are `code` (compressed) or `src` (plain text, for
hand-made links), plus `gems=a,b`, `lang=de|en|ja` (default: the browser's
language, falling back to en), `load=visible|click|eager` (default visible),
`run=1` (run once Ruby is up) and `id` (echoed in messages).

Running it:

```sh
PORT=18109 ruby experiments/09-embed-cell/serve_embed.rb          # background task
node experiments/09-embed-cell/test_embed.mjs check                # or measure / all
# by hand: http://localhost:18109/demo/host.html?embed=http://127.0.0.1:18109/
```

## What works (all 14 checks pass)

- `<pre data-chunky>` becomes an iframe. The code shows up de-indented and is
  then upgraded to CodeMirror (Shift+Enter runs it). ▶ gives the course's
  `=> {"chunky" => 2, …}` output, including the running look (bacon bar,
  wobbling fox) and the run time.
- The iframe's height follows the cell to the pixel (154 vs 154 px) by
  postMessage. The host matches messages by `event.source`, because a
  sandboxed frame's `event.origin` is `"null"`. Hand-written iframes resize
  too, as long as embed.js is on the page.
- `data-gems="chunky_png"` and `show_image` draw the picture under the cell
  (from the gem cache on the embed origin). Widgets come from main.rb as they
  are.
- With `load=click`, ruby.wasm is not requested before ▶. With `load=visible`,
  a cell below the fold loads no Ruby until it is scrolled to, and the iframe
  itself is `loading="lazy"`.
- **The kernel runs in an opaque origin.** It runs with the CSP `sandbox`
  header plus the `sandbox` attribute, with `self.origin === "null"`. It also
  runs under a strict CSP on top (`connect-src 'self'`, `script-src 'self'
  'wasm-unsafe-eval' 'unsafe-eval'`). `'unsafe-eval'` cannot go: the js gem
  calls `JS.eval` while it boots (`js.rb:46`, EvalError without it).
- No console errors on the host page.

Not wired up in the embed yet: three.js (`show_three` says it is loading
forever, because `ensureThree` is stubbed out), Python/PyCall and SQLite/Sequel
(their `ensure*` helpers would have to be copied over from `index.html`), the
rubygems.org proxy for gems that are not cached (the dev server has no
bridge; nginx on the embed host would need the same `/rubygems/` locations),
exercise checks (`t: "x"`), and live runs. Each of these is a copy of
existing code, not new design.

## Numbers

Medians of 3, measured locally (Playwright Chromium, server on loopback;
"20 Mbit/s" is CDP throttling at 20 Mbit/s down with 40 ms latency, the slow
profile from PICORUBY_SHELL.md). "Warm" means a second visit in the same
on-disk profile. An incognito context's memory cache does not keep the 10 MB
wasm, so the first warm numbers were wrong.

**embed.html as its own page** (an iframe's own clock, ms from its navigation, `run=1`):

| profile | code visible | editor | Ruby up | **first result** | re-run | KB before Ruby | ruby.wasm KB |
|---|---:|---:|---:|---:|---:|---:|---:|
| fast, cold | **107** | 143 | 1543 | **1585** | 26 | 132 | 9813 |
| fast, warm | 62 | 90 | 1016 | 1037 | 25 | 2 | 0 |
| fast, warm, no sandbox | 74 | 123 | 1230 | 1262 | 26 | 2 | 0 |
| 20 Mbit/s, cold | **213** | 250 | 6688 | **6708** | 23 | 132 | 9813 |
| 20 Mbit/s, warm | 160 | 234 | 1730 | 1757 | 27 | 2 | 0 |
| 20 Mbit/s, warm, no sandbox | 213 | 226 | 1417 | 1445 | 28 | 2 | 0 |

**Inside a host page** (`demo/one.html` on blog.test, the host's clock, ms
from the host page's navigation):

| profile | code visible | editor | Ruby up | **first result** |
|---|---:|---:|---:|---:|
| fast, cold | 267 | 287 | 1352 | **1378** |
| fast, warm | 248 | 271 | 941 | **966** |
| 20 Mbit/s, cold | 409 | 430 | 6366 | **6401** |

What the numbers say:

- Time to code visible stays under a quarter of a second. Before Ruby the
  embed fetches 132 KB: the fonts, CodeMirror, app.css, the ui strings and its
  own files. There is no PicoRuby, no lessons.js, and no 0.9 MB shell.
- Time to first result is set by the 10 MB ruby.wasm download, the same as in
  the course. Once it is cached, Ruby is up in about 1 s, which is compile
  plus main.rb's boot.
- The sandbox does not stop caching. Opaque-origin documents reuse the HTTP
  cache (0 KB of wasm when warm), and the sandboxed and unsandboxed numbers
  are within noise of each other.
- One cost that cannot be avoided: Chrome partitions the HTTP cache by
  top-level site. A reader who has the course cached still downloads 10 MB
  the first time they meet an embed on someone's blog, once per blog site.
- Every iframe is its own ruby.wasm VM (about 1 s of compile and boot and
  tens of MB of memory each). `load=visible` keeps that to the cells the
  reader actually reaches. For a slide deck with many cells, use `load=click`.

## Security analysis

**What the embed changes.** The course already runs any code the learner
types, but the learner typed it. An embed runs code that **someone else**
chose, as soon as the reader presses ▶ (or straight away with `run=1`). It
only takes a link or an iframe on any page, and clickjacking can get the ▶
pressed. If `embed.html` ran in the course's origin
(`chunkybacon.idogawa.com`), that code would have everything the course page
has:

| what | exposure on the course origin |
|---|---|
| `localStorage`: progress (`chunky_done`), cell code, language, **workshop files** (storage.js) | read, exfiltrate, overwrite or wipe. **Demonstrated:** the probe cell with `?nosandbox` prints `["hallo","methoden","klassen"]` (`screenshots/cell-probe-unsandboxed.png`) |
| the **connected folder** (a `FileSystemDirectoryHandle` in IndexedDB, storage.js) | `indexedDB.open` works (probe: `indexed_db: "open"`). If the folder permission is still granted (same session, or Chrome's "allow on every visit"), code can read, write and delete the learner's **real files** in that folder |
| the **offline copy** (Cache Storage + `sw.js`) | `caches.open(...).put("/index.html", evil)` would poison the offline course. That is persistent XSS on the course origin, served from cache whenever the learner is offline |
| cookies | none today. With the Roda server's `/api` there may be sessions later, which the code could then read or set |
| reputation | arbitrary HTML and phishing shown on `chunkybacon.idogawa.com` |

**Mitigation, in layers (the first two were built and tested here):**

1. **`Content-Security-Policy: sandbox allow-scripts allow-popups
   allow-popups-to-escape-sandbox allow-downloads` on `embed.html` (server
   side).** The document gets an opaque origin however it is opened: an
   iframe with or without a `sandbox` attribute, or a plain top-level link
   (the README case). It then has no `localStorage` and no IndexedDB (probe:
   `SecurityError` for both, `screenshots/cell-probe-sandboxed.png`), no
   cookies, no Cache Storage and no service worker. There is no
   `allow-same-origin`, no `allow-top-navigation` and no `allow-forms`. Its
   requests are cross-origin (`Origin: null`), so the static files need
   `Access-Control-Allow-Origin: *`. That is harmless for public files and
   must never be combined with credentials.
2. **The `sandbox` attribute on the iframe** (embed.js and make_embed_url.rb
   add it) as defence in depth, in case the header is lost behind a CDN.
3. **A host of its own**, such as `embed.chunkybacon.idogawa.com`, or better
   a separate registrable domain (GitHub uses `githubusercontent.com` and
   CodePen uses `cdpn.io` for the same reason). Serve only the embed's files
   there, and never `index.html`, `storage.js`, `offline.js` or `sw.js`. Then
   a missing sandbox header (a misconfiguration, an old browser) still lands
   in an origin with nothing in it. A subdomain is same-site, so code on it
   could still set cookies for `.idogawa.com` (cookie tossing into koans or
   the course). A separate domain also rules that out.
4. **Do not serve `embed.html` on the course origin** at all: return a 404 or
   redirect to the embed host. Otherwise a link to
   `chunkybacon.idogawa.com/embed.html#code=…` is exactly the exposure
   described above.
5. Optional: a strict CSP (`connect-src 'self'`, `img-src 'self' data:
   blob:`, `form-action 'none'`) makes it harder to send typed data
   elsewhere. It cannot be airtight: `allow-popups` lets `window.open(url)`
   carry data, and the js gem needs `'unsafe-eval'`. With an opaque origin
   there is little worth taking, so this is hardening only. Tested: the
   kernel runs under it.

What the sandbox does **not** solve: the code can still burn CPU (an
infinite loop freezes the frame; with site isolation on desktop the host
page stays responsive, on Android it may not), open popups (an
`allow-popups` choice that keeps the "Chunky Bacon" link working), and show
any content inside the frame. `run=1` should therefore be something the host
asks for, never a default. The postMessage channel carries only heights and
timings, sent with `"*"`, and the host checks `event.source`.

## Integration steps

1. Move `site/embed.html`, `embed.js`, `embed-frame.js`, `embed-kernel.rb` and
   `embed.css` to `html/`. Turn `build_embed_ui.mjs` into
   `tools/build_embed_ui.rb` or `.mjs` writing `html/embed-ui.js`, with a
   `--check` mode in the test run (it goes stale whenever the ui strings in
   lessons.js change). Alternative: split `ui` out of `lessons.js` into
   `html/ui.js` and load that in both pages.
2. nginx: a second `server` block for the embed host, using the same root
   but an allow-list of locations (`embed.*`, `main.rb` and the `.rb` files
   it requires, `browser.script.iife.js`, `ruby+stdlib.wasm(.gz)`, `assets/`,
   `gems/cache/`, the `/rubygems/` and `/proxy/ruby-lang/` bridges with their
   rate limit). On `embed.html` add
   `add_header Content-Security-Policy "sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads" always;`.
   On static files add `add_header Access-Control-Allow-Origin "*";`. Send no
   `X-Frame-Options`. On the course's own server block, deny `/embed.html`.
   (`serve_embed.rb` shows the headers.)
3. Optional, a tiny change to main.rb so `embed-kernel.rb` is no longer
   needed:
   ```diff
    def store(key, value)
   -  $window.localStorage.setItem(key, value)
   +  $window.localStorage.setItem(key, value) unless @lesson_id == "embed"
    end
   ```
   (or `rescue JS::Error`, which also covers browsers that block storage).
4. `html/offline-files.txt`: leave the embed out. The offline copy belongs to
   the course origin.
5. README: a section "Embedding a cell" (a `pre data-chunky` with the script
   tag, the iframe, `make_embed_url.rb` for README links, since GitHub strips
   iframes). Add `test_embed.mjs check` to the browser suites.
6. Later: copy `ensureSqlite`, `ensurePython` and `ensureThree` from
   `index.html` into embed-frame.js (and call them on Run when the code
   mentions Sequel, PyCall or `show_three`). An "Open in the workshop" link
   (`#werkstatt?code=…`) needs the course to import a project from a
   fragment, which is a feature of its own.

## Screenshots

- `screenshots/host-page.png`: the fake blog post with two cells run (a Hash
  result, a chunky_png picture)
- `screenshots/cell-before-run.png`: a `load=click` cell before ▶ (no Ruby loaded)
- `screenshots/cell-result.png`, `screenshots/cell-chunky-png.png`: results
- `screenshots/cell-probe-sandboxed.png`: embedded code sees `origin: "null"`
  and `SecurityError` for localStorage and IndexedDB
- `screenshots/cell-probe-unsandboxed.png`: the same code without the
  sandbox reads the course's progress
