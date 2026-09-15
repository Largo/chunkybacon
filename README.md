# Ruby lernen mit Chunky Bacon 🦊🥓

Learn Ruby in your browser — an interactive, notebook-style course in
**German and English**. No setup: Ruby itself runs client-side via
[ruby.wasm](https://github.com/ruby/ruby.wasm).

## What's inside

- **16 lessons** from `puts "Hallo, Welt!"` to classes, modules, IRB,
  gems, HTML parsing, and web routing with Sinatra and Roda.
- **Notebook UI**: lessons interleave text with runnable CodeMirror
  cells (Shift+Enter). All cells of a lesson share one binding, and every
  cell shows its last expression as `=> …` — `puts` is never required.
- **In-browser gem installer**: pure-Ruby gems install at runtime
  (`install_gem "chunky_png"`), fetched from a local cache or from
  rubygems.org through a same-origin nginx proxy. Native gems (nokogiri)
  fail with a friendly explanation of the wasm limitation.
- **Interactive widgets**: `show_irb` (a real IRB terminal with `_`,
  multi-line input, and authentic prompts), `show_browser` (a fake
  browser window that speaks Rack directly to your Sinatra/Roda app),
  and `show_image` (inline PNGs from chunky_png).
- Chunky Bacon, an original cartoon fox, cheers you on.

## Architecture

Built on the same foundation as
[BrowserRubyKoans](https://github.com/Largo/BrowserRubyKoans)
(koans.idogawa.com): `browser.script.iife.js` + `ruby-app.wasm` with app
logic written in Ruby (`html/main.rb`) via the JS bridge. Lesson content
lives in `html/lessons.js`; the gem loader in `html/browser_gems.rb`
unpacks `.gem` files in Ruby and hooks `require`/`autoload`.

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
CodeMirror, cached gems) remain under their own licenses.
