# Ruby lernen mit Chunky Bacon 🦊🥓

Learn Ruby in your browser — an interactive, notebook-style course in
**German and English**. No setup: Ruby itself runs client-side via
[ruby.wasm](https://github.com/ruby/ruby.wasm).

## What's inside

- **37 lessons** from `puts "Hallo, Welt!"` to classes, modules, IRB,
  gems, HTML parsing with Nokogiri, exact arithmetic with BigDecimal, web
  routing with Sinatra and Roda, 3D graphics,
  PowerPoint decks with [ruby_pptx](https://github.com/Largo/ruby_pptx), and
  a project track that builds a small time tracker.
- **Notebook UI**: lessons interleave text with runnable CodeMirror
  cells (Shift+Enter). All cells of a lesson share one binding, and every
  cell shows its last expression as `=> …` — `puts` is never required.
- **In-browser gem installer**: pure-Ruby gems install at runtime
  (`install_gem "chunky_png"`), fetched from a local cache or from
  rubygems.org through a same-origin nginx proxy, and unpacked onto the
  wasm filesystem (writable memory) with their declared load paths on
  `$LOAD_PATH` - so `require`, `require_relative`, `autoload`, `__dir__`
  and data files next to `lib/` behave as on disk.
- **Nokogiri in the browser**: the cache holds
  [nokogiri-pure](https://github.com/Largo/nokogiri-pure) - Nokogiri
  1.19.4 with its C extension, libxml2, libxslt and gumbo ported to Ruby -
  built under the name `nokogiri`, so gems that depend on nokogiri
  (loofah, sanitize, rails-html-sanitizer, premailer, feedjira, rubyXL,
  roo, caxlsx, reverse_markdown …) install and run too. Other native gems
  fail with a friendly explanation of the wasm limitation that names the
  gem with the C code (often a dependency), unless it is built into the
  wasm image (json, date, openssl …), has a pure-Ruby stand-in in the
  cache (`SUBSTITUTES`: a dependency on `bigdecimal` installs
  [bigdecimal-pure](https://github.com/Largo/bigdecimal-pure), which
  unblocks activesupport, liquid, prawn, dry-types …) or the gem that
  wants it can do without it (`OPTIONAL_NATIVE_DEPS`: ruby_pptx falls
  back to REXML).
- **Downloads**: any file a cell writes - `deck.save("chunky.pptx")`,
  `File.write("notes.txt", …)` - appears below the cell as a download link;
  `download_file(data, "name")` offers data that never went through a file.
- **Interactive widgets**: `show_irb` (a real IRB terminal with `_`,
  multi-line input, and authentic prompts), `show_browser` (a fake
  browser window that speaks Rack directly to your Sinatra/Roda app),
  `show_image` (inline PNGs from chunky_png), and `show_three` (a WebGL
  stage for scenes built with [three-rb](https://github.com/lef237/three-rb),
  optionally animated per frame and orbitable with the mouse).
- Chunky Bacon, an original cartoon fox, cheers you on.

## Architecture

For operations, internals and traps see [docs/HANDOVER.md](docs/HANDOVER.md).

Built on the same foundation as
[BrowserRubyKoans](https://github.com/Largo/BrowserRubyKoans)
(koans.idogawa.com): `browser.script.iife.js` + `ruby-app.wasm` with app
logic written in Ruby (`html/main.rb`) via the JS bridge. Lesson content
lives in `html/lessons.js`; the gem loader in `html/browser_gems.rb`
unpacks `.gem` files in Ruby onto the wasm filesystem, and hooks `require`
for shims of stdlib that cannot load in WASI (socket, net/http over the
browser's fetch, resolv).

three.js is vendored under `html/assets/three/` and imported lazily
(`window.ensureThree` in `index.html`) only by lessons whose cells call
`show_three` - three-rb builds the scene graph in Ruby and looks the
library up as `globalThis.THREE`. All stages on the page share one
`Three::Backends::ThreeJS`: that backend caches the three.js objects it
built and afterwards only pushes what changed, so a second one would
rebuild an already-clean scene as bare defaults.

## Run locally

```sh
docker compose up -d      # serves on port 8011
```

Or any static file server over `html/` (the rubygems proxy then needs
nginx, see `nginx.conf`).

## Tests

```sh
cd test
node -e 'global.window={}; require("../html/lessons.js"); require("fs").writeFileSync("lessons.json", window.LESSONS_JSON)'
ruby check_harness.rb     # every lesson: starter fails, solutions pass
ruby gems_harness.rb      # gem installer, sinatra + roda offline
node browser_test.mjs     # Playwright end-to-end against port 8011
```

## License

Course content: CC BY-NC-SA 4.0, © [Andi Idogawa](https://idogawa.com).
The phrase "Chunky Bacon" is an homage to _why's (poignant) guide to
Ruby_ by why the lucky stiff — fondly remembered. The mascot is an
original character. Bundled third-party components (ruby.wasm build,
CodeMirror, three.js, cached gems, the web fonts under SIL OFL 1.1) remain
under their own licenses.
