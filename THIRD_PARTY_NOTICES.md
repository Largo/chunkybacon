# Third-party notices

Chunky Bacon ships the components below. Each stays under its own license;
this file names them and says where their license texts are. The course's
own license is in the README.

## Ruby in the browser

| Component | Version | License | Files |
|---|---|---|---|
| [ruby.wasm](https://github.com/ruby/ruby.wasm) (`@ruby/4.0-wasm-wasi`) | 2.10.1 | MIT | `html/browser.script.iife.js` (loader, patched to fetch the local wasm), `html/ruby+stdlib.wasm` |
| [CRuby](https://www.ruby-lang.org/) 4.0 and its standard library, inside the wasm | 4.0 | Ruby License or BSD-2-Clause | `html/ruby+stdlib.wasm` |
| LibYAML, zlib, wasi-libc, OpenSSL, wasi-vfs, inside the wasm | as built by ruby.wasm | each its own | `html/ruby+stdlib.wasm` |

The complete notices for all of these - CRuby's COPYING and LEGAL, and the
license texts of LibYAML, zlib, wasi-libc, OpenSSL, wasi-vfs and ruby.wasm
itself - are the comment at the top of `html/browser.script.iife.js`, as
ruby.wasm distributes them. Keep that comment when updating the loader
(`tools/update_ruby_wasm.rb`).

The page shell (`html/shell/`) runs on a second Ruby:

| Component | Version | License | Copyright | Files |
|---|---|---|---|---|
| [PicoRuby](https://github.com/picoruby/picoruby).wasm (`@picoruby/wasm-wasi`) | 4.0.3 | MIT | 2020 HASUMI Hitoshi | `html/assets/picoruby/`: `init.iife.js` (loader, patched to read `text/picoruby`, `tools/patch_picoruby_loader.rb`), `picoruby.js`, `picoruby.wasm` and their `.gz` copies |

The license text, the npm tarball's integrity digest and the SHA-256 of
every file are in `html/assets/picoruby/NOTICE.md`; keep it with the runtime.

## Python in the browser (`html/assets/pyodide/`)

Loaded only by the PyCall lessons (html/pycall.rb), each with the packages it
imports (matplotlib and the seven wheels after it in the table only by the
matplotlib lesson, or a workshop program that imports it); put there by
`tools/vendor_pyodide.rb` from the official Pyodide release, the wheels checked
against the release's SHA-256.

| Component | Version | License | Files |
|---|---|---|---|
| [Pyodide](https://pyodide.org/) | 314.0.7 | MPL-2.0 | `pyodide.mjs`, `pyodide.asm.mjs`, `pyodide.asm.wasm` (+ `.gz`), `pyodide-lock.json` (cut down to the vendored packages), `package.json` |
| [CPython](https://www.python.org/) 3.14 and its standard library, inside Pyodide | 3.14 | PSF License | `pyodide.asm.wasm`, `python_stdlib.zip` |
| C libraries Pyodide builds in (zlib, bzip2, libffi, sqlite and others) | as built by Pyodide | each its own | `pyodide.asm.wasm` - see Pyodide's repository |
| [pandas](https://pandas.pydata.org/) | 3.0.2 | BSD-3-Clause | `pandas-3.0.2-…wasm32.whl` (license in its `dist-info/LICENSE`) |
| [NumPy](https://numpy.org/) | 2.4.6 | BSD-3-Clause, with bundled parts under their own licenses | `numpy-2.4.6-…wasm32.whl` (`dist-info/licenses/`) |
| [python-dateutil](https://github.com/dateutil/dateutil) | 2.9.0.post0 | Apache-2.0 or BSD-3-Clause | its wheel (`dist-info/LICENSE`) |
| [pytz](https://pythonhosted.org/pytz/) | 2026.1.post1 | MIT | its wheel (`dist-info/LICENSE.txt`) |
| [six](https://github.com/benjaminp/six) | 1.17.0 | MIT | its wheel (`dist-info/LICENSE`) |
| [SymPy](https://www.sympy.org/) | 1.14.0 | BSD-3-Clause, with bundled parts under their own licenses | `sympy-1.14.0-py3-none-any.whl` (`dist-info/licenses/LICENSE`, `AUTHORS`) |
| [mpmath](https://mpmath.org/) | 1.4.1 | BSD-3-Clause | its wheel (`dist-info/licenses/LICENSE`) |
| [scikit-learn](https://scikit-learn.org/) | 1.8.0 | BSD-3-Clause | `scikit_learn-1.8.0-…wasm32.whl` (`dist-info/licenses/COPYING`) |
| [SciPy](https://scipy.org/) | 1.18.0 | BSD-3-Clause, with bundled parts under their own licenses | `scipy-1.18.0-…wasm32.whl` (`dist-info/LICENSE.txt`, which lists the bundled parts) |
| [joblib](https://joblib.readthedocs.io/) | 1.5.3 | BSD-3-Clause | its wheel (`dist-info/licenses/LICENSE.txt`) |
| [threadpoolctl](https://github.com/joblib/threadpoolctl) | 3.6.0 | BSD-3-Clause | its wheel (`dist-info/licenses/LICENSE`) |
| [matplotlib](https://matplotlib.org/) | 3.10.8 | matplotlib License (PSF-based, BSD-compatible), © 2012- Matplotlib Development Team | `matplotlib-3.10.8-…wasm32.whl` (`dist-info/LICENSE`); further bundled parts below |
| [DejaVu fonts](https://dejavu-fonts.github.io/), inside matplotlib (`mpl-data/fonts/ttf/DejaVu*.ttf`, the default font of every chart) | as bundled | Bitstream Vera Fonts License (© 2003 Bitstream, Inc.; DejaVu changes public domain) and Arev Fonts License (© 2006 Tavmjong Bah) | `mpl-data/fonts/ttf/LICENSE_DEJAVU` in the wheel |
| [STIX fonts](https://www.stixfonts.org/), inside matplotlib (`mpl-data/fonts/ttf/STIX*.ttf`, converted to TTF by matplotlib) | as bundled | SIL OFL 1.1 (© 2001-2010 the STI Pub Companies; portions © MicroPress, Inc. and Elsevier, Inc.) | `mpl-data/fonts/ttf/LICENSE_STIX` in the wheel |
| Other fonts and font metrics inside matplotlib: Computer Modern (BaKoMa, `cm*.ttf`, `cm*.afm`), Humor Sans, the Adobe AFM metrics of the 14 PDF core fonts (`pdfcorefonts/`) and further PostScript metrics (`afm/`) | as bundled | each its own (the AFM metrics: Adobe's terms in `pdfcorefonts/readme.txt`) | the wheel's `mpl-data/fonts/`; matplotlib's `LICENSE/` folder in its source lists them |
| C/C++ libraries matplotlib builds in: [FreeType](https://freetype.org/) (`ft2font`), Agg (Anti-Grain Geometry), Qhull | as built by Pyodide | FreeType License (FTL); Agg's modified BSD license; Qhull license | in its `.so` files - see matplotlib's `LICENSE/` folder. Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved. |
| [contourpy](https://github.com/contourpy/contourpy) | 1.3.3 | BSD-3-Clause | its wheel (`dist-info/LICENSE`) |
| [cycler](https://github.com/matplotlib/cycler) | 0.12.1 | BSD-3-Clause | its wheel (`dist-info/LICENSE`) |
| [fontTools](https://github.com/fonttools/fonttools) | 4.62.1 | MIT, with bundled parts under their own licenses | its wheel (`dist-info/licenses/LICENSE`, `LICENSE.external`) |
| [kiwisolver](https://github.com/nucleic/kiwi) | 1.5.0 | BSD-3-Clause | its wheel (`dist-info/licenses/LICENSE`) |
| [packaging](https://github.com/pypa/packaging) | 26.1 | Apache-2.0 or BSD-2-Clause | its wheel (`dist-info/licenses/`) |
| [Pillow](https://python-pillow.github.io/) | 12.2.0 | MIT-CMU (the PIL license) | its wheel (`dist-info/licenses/LICENSE`) |
| C libraries Pillow builds in (libjpeg-turbo, libtiff, libwebp, FreeType, zlib) | as built by Pyodide | each its own (BSD-style, libtiff's, BSD-3-Clause, FTL, zlib) | in its `.so` files - see Pyodide's and Pillow's repositories |
| [pyparsing](https://github.com/pyparsing/pyparsing) | 3.3.2 | MIT | its wheel (`dist-info/licenses/LICENSE`) |

## Editor, 3D, fonts, sql.js, Herb and ruby2d

| Component | Version | License | Copyright | License text |
|---|---|---|---|---|
| [CodeMirror](https://codemirror.net/5/) with its Ruby mode | 5.65.16 | MIT | Marijn Haverbeke and others | header of `html/assets/codemirror.js`; https://codemirror.net/5/LICENSE |
| [three.js](https://threejs.org/) with OrbitControls | r184 | MIT | 2010-2026 three.js authors | `html/assets/three/LICENSE` |
| [sql.js](https://sql.js.org/) (SQLite in WebAssembly, loaded by the Sequel lesson; `tools/vendor_sqljs.rb`) | 1.14.2 | MIT | 2017 sql.js authors | `html/assets/sqljs/LICENSE` |
| [SQLite](https://sqlite.org/), inside sql.js | 3.49.1 | public domain | - | https://sqlite.org/copyright.html |
| [Atkinson Hyperlegible Next](https://github.com/googlefonts/atkinson-hyperlegible-next) | Google Fonts build | SIL OFL 1.1 | 2020-2024 The Atkinson Hyperlegible Next Project Authors | `html/assets/fonts/OFL-atkinson-hyperlegible-next.txt` |
| [Atkinson Hyperlegible Mono](https://github.com/googlefonts/atkinson-hyperlegible-next-mono) | Google Fonts build | SIL OFL 1.1 | 2020-2024 The Atkinson Hyperlegible Mono Project Authors | `html/assets/fonts/OFL-atkinson-hyperlegible-mono.txt` |
| [Shantell Sans](https://github.com/arrowtype/shantell-sans) | Google Fonts build | SIL OFL 1.1 | 2022 The Shantell Sans Project Authors | `html/assets/fonts/OFL-shantell-sans.txt` |
| [Herb](https://herb-tools.dev) for the browser (`@herb-tools/browser`: libherb and its Prism as WebAssembly) | 0.10.3 | MIT | 2024-2025 Marco Roth | `html/assets/herb/LICENSE-herb.txt` |
| [Prism](https://github.com/ruby/prism) JavaScript files (`@ruby/prism`: deserialize, nodes, visitor) | 1.9.0 | MIT | 2022-present Shopify Inc. | `html/assets/herb/LICENSE-prism.md` |
| [ruby2d](https://www.ruby2d.com) - the gem's Ruby files (window, events, shapes, colours, text), joined unchanged into `html/assets/ruby2d/ruby2d.rb` by `tools/vendor_ruby2d.rb` (the lesson's `require "ruby2d"`; `html/ruby2d.rb`, the course's own code, stands in for its C extension) | 1.0.0 | MIT | 2026 Tom Black | `html/assets/ruby2d/LICENSE.md` |

The fonts are subsets (latin, latin-ext) of the variable fonts Google Fonts
serves, unmodified otherwise. `chunky-box-drawing.woff` next to them (box
drawing and block characters for the code font) is not third-party: it is
generated by `tools/build_box_font.rb` and part of the course's code (MIT).

## Cached gems (`html/gems/cache/`)

Gem archives the in-browser installer unpacks. They are the archives as
published on rubygems.org - `bigdecimal-pure`, `nokogiri` (nokogiri-pure) and
`ruby_pptx` are built from their own repositories by
`tools/build_gem_cache.rb`. Each archive carries its license file unless
noted.

| Gem | Version | License | Authors (per gemspec) | License file in the archive |
|---|---|---|---|---|
| base64 | 0.3.0 | Ruby, BSD-2-Clause | Yusuke Endoh | COPYING, LEGAL |
| benchmark | 0.5.0 | Ruby, BSD-2-Clause | Yukihiro Matsumoto | COPYING |
| bigdecimal-pure | 0.1.0 | MIT | Andi Idogawa | LICENSE |
| chunky_bacon | 0.1.0 | MIT; the fox drawing CC BY-SA 4.0 | Andi Idogawa | LICENSE, LICENSE-ASSETS |
| chunky_png | 1.4.0 | MIT | Willem van Bergen | LICENSE |
| cmdparse | 3.0.7 | MIT | Thomas Leitner | COPYING |
| concurrent-ruby | 1.3.8 | MIT | Jerry D'Antonio, Petr Chalupa, the Ruby Concurrency Team | LICENSE.txt |
| csv | 3.3.6 | Ruby, BSD-2-Clause | James Edward Gray II, Kouhei Sutou | LICENSE.txt |
| faker | 3.8.0 | MIT | Benjamin Curtis, Vitor Oliveira | License.txt |
| gammo | 0.3.0 | MIT | namusyaka | LICENSE.txt |
| geom2d | 0.4.1 | MIT | Thomas Leitner | LICENSE |
| herb | 0.10.3 | MIT | Marco Roth | LICENSE.txt |
| hexapdf | 1.11.0 | AGPL-3.0 (or a commercial licence from its author) | Thomas Leitner | LICENSE, agpl-3.0.txt; data/hexapdf/cmap/LICENSE.txt for its CMap data |
| i18n | 1.15.2 | MIT | Sven Fuchs, Joshua Harvey, Matt Aimonetti and others | MIT-LICENSE |
| jsg | 0.2.1 | MIT | Andi Idogawa | LICENSE.txt |
| lacci | 0.5.0 | MIT | Marco Concetto Rudilosso, Noah Gibbs | none - see below |
| logger | 1.7.0 | Ruby, BSD-2-Clause | Naotoshi Seo, SHIBATA Hiroshi | COPYING |
| matrix | 0.4.3 | Ruby, BSD-2-Clause | Marc-Andre Lafortune | COPYING |
| minitest | 5.27.0 | MIT | Ryan Davis | none - see below |
| mustermann | 4.0.0 | MIT | Konstantin Haase and others | LICENSE |
| nokogiri (nokogiri-pure) | 1.19.4 | MIT | Andi Idogawa; Nokogiri: Mike Dalessio, Aaron Patterson and others | LICENSE-nokogiri.md, LICENSE-DEPENDENCIES.md (the ported libxml2, libxslt and gumbo) |
| pastel | 0.8.0 | MIT | Piotr Murach | LICENSE.txt |
| pdf-core | 0.10.0 | Prawn's Ruby-style licence, GPL-2.0 or GPL-3.0, at your choice | Alexander Mankuta, Gregory Brown, Brad Ediger and others | LICENSE, COPYING, GPLv2, GPLv3 |
| prawn | 2.5.0 | Prawn's Ruby-style licence, GPL-2.0 or GPL-3.0, at your choice | Alexander Mankuta, Gregory Brown, Brad Ediger and others | LICENSE, COPYING, GPLv2, GPLv3 |
| pure_jpeg | 0.4.0 | MIT | Peter Cooper | LICENSE |
| racc | 1.8.1 | Ruby, BSD-2-Clause | Minero Aoki, Aaron Patterson | COPYING |
| rack | 3.2.7 | MIT | Leah Neukirchen | MIT-LICENSE |
| rack-protection | 4.2.1 | MIT | Sinatra contributors | License |
| rack-session | 2.1.2 | MIT | Samuel Williams, Jeremy Evans and others | license.md |
| rexml | 3.4.4 | BSD-2-Clause | Kouhei Sutou | LICENSE.txt |
| roda | 3.108.0 | MIT | Jeremy Evans | MIT-LICENSE |
| ruby_pptx | 0.2.0 | MIT | Andi Idogawa | LICENSE, NOTICE |
| rumale-core | 2.2.0 | BSD-3-Clause | yoshoku | LICENSE.txt |
| rumale-nearest_neighbors | 2.2.0 | BSD-3-Clause | yoshoku | LICENSE.txt |
| rubyzip | 3.7.0 | BSD-2-Clause | Robert Haines, John Lees-Miller, Alexander Simonov | LICENSE.md |
| scarpe-components | 0.5.0 | MIT | Marco Concetto Rudilosso, Noah Gibbs | none - see below |
| sequel | 5.109.0 | MIT | Sharon Rosner, Jeremy Evans and contributors | MIT-LICENSE |
| sinatra | 4.2.1 | MIT | Blake Mizerany, Ryan Tomayko, Simon Rozet, Konstantin Haase | LICENSE |
| strings | 0.2.1 | MIT | Piotr Murach | LICENSE.txt |
| strings-ansi | 0.2.0 | MIT | Piotr Murach | LICENSE.txt |
| three-rb | 0.2.1 | MIT | LEF | LICENSE |
| tilt | 2.9.0 | MIT | Ryan Tomayko, Magnus Holm, Jeremy Evans | COPYING |
| ttfunk | 1.8.0 | Prawn's Ruby-style licence, GPL-2.0 or GPL-3.0, at your choice | Alexander Mankuta, Gregory Brown, Brad Ediger, Cameron Dutro and others | LICENSE, COPYING, GPLv2, GPLv3 |
| tty-box | 0.7.0 | MIT | Piotr Murach | LICENSE.txt |
| tty-color | 0.6.0 | MIT | Piotr Murach | LICENSE.txt |
| tty-cursor | 0.7.1 | MIT | Piotr Murach | LICENSE.txt |
| tty-font | 0.5.0 | MIT | Piotr Murach | LICENSE.txt |
| tty-screen | 0.8.2 | MIT | Piotr Murach | LICENSE.txt |
| tty-table | 0.12.0 | MIT | Piotr Murach | LICENSE.txt |
| tty-tree | 0.4.0 | MIT | Piotr Murach | LICENSE.txt |
| unicode-display_width | 2.6.0 | MIT | Jan Lelis | MIT-LICENSE.txt |
| unicode_utils | 1.4.0 | BSD-2-Clause (gemspec declares none) | Stefan Lang | LICENSE.txt |

`tools/build_gem_cache.rb` rewrites this cache; update the table with it.

**HexaPDF** is served unmodified, as published on rubygems.org; the archive
is its complete source, with the AGPL text. The PDF lesson tells learners
what the AGPL means for programs of their own that use HexaPDF.

### Gems published without a license file

Their published archives contain no license file; their gemspecs declare MIT.
The copyright lines are from the upstream projects:

- **lacci**, **scarpe-components**: Copyright (c) 2022-present, Scarpe team
  and contributors (https://github.com/scarpe-team/scarpe, LICENSE.txt).
- **minitest**: Copyright (c) Ryan Davis, seattle.rb
  (https://github.com/minitest/minitest, README).

They are provided under the MIT License:

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Rumale's gems depend on numo-narray-alt, which is C and not cached:
`html/numo_narray.rb` is the course's own stand-in for it (MIT, like the
rest of the code), written against numo-narray-alt's documented behaviour.

The processing gem (https://github.com/xord/processing) draws through rays
and reflexion (C++, OpenGL) and is not cached: `html/processing.rb` is the
course's stand-in for it. Its constants, the table of colour names,
`Vector` and the maths helpers (`curvePoint`, `bezierPoint`,
`randomGaussian` …) are adapted from the gem's source, Copyright (c) 2019
xord.org, under the MIT License (the text above).

## Data

| Data | License | Source | Files |
|---|---|---|---|
| Optical Recognition of Handwritten Digits (the 1797 digits of its test part, as scikit-learn ships them) | CC BY 4.0 | E. Alpaydin, C. Kaynak, UCI Machine Learning Repository, https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits | `html/assets/data/digits.csv` (unchanged values, integers instead of floats) |

## Not bundled

Gems installed at runtime from rubygems.org, and pages fetched through the
same-origin bridges (`nginx/default.conf`), go straight from their source to the
learner's browser; the site only relays and caches them.
