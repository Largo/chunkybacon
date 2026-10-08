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

## Editor, 3D and fonts

| Component | Version | License | Copyright | License text |
|---|---|---|---|---|
| [CodeMirror](https://codemirror.net/5/) with its Ruby mode | 5.65.16 | MIT | Marijn Haverbeke and others | header of `html/assets/codemirror.js`; https://codemirror.net/5/LICENSE |
| [three.js](https://threejs.org/) with OrbitControls | r184 | MIT | 2010-2026 three.js authors | `html/assets/three/LICENSE` |
| [Atkinson Hyperlegible Next](https://github.com/googlefonts/atkinson-hyperlegible-next) | Google Fonts build | SIL OFL 1.1 | 2020-2024 The Atkinson Hyperlegible Next Project Authors | `html/assets/fonts/OFL-atkinson-hyperlegible-next.txt` |
| [Atkinson Hyperlegible Mono](https://github.com/googlefonts/atkinson-hyperlegible-next-mono) | Google Fonts build | SIL OFL 1.1 | 2020-2024 The Atkinson Hyperlegible Mono Project Authors | `html/assets/fonts/OFL-atkinson-hyperlegible-mono.txt` |
| [Shantell Sans](https://github.com/arrowtype/shantell-sans) | Google Fonts build | SIL OFL 1.1 | 2022 The Shantell Sans Project Authors | `html/assets/fonts/OFL-shantell-sans.txt` |

The fonts are subsets (latin, latin-ext) of the variable fonts Google Fonts
serves, unmodified otherwise.

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
| csv | 3.3.6 | Ruby, BSD-2-Clause | James Edward Gray II, Kouhei Sutou | LICENSE.txt |
| gammo | 0.3.0 | MIT | namusyaka | LICENSE.txt |
| geom2d | 0.4.1 | MIT | Thomas Leitner | LICENSE |
| hexapdf | 1.11.0 | AGPL-3.0 (or a commercial licence from its author) | Thomas Leitner | LICENSE, agpl-3.0.txt; data/hexapdf/cmap/LICENSE.txt for its CMap data |
| jsg | 0.2.1 | MIT | Andi Idogawa | LICENSE.txt |
| lacci | 0.5.0 | MIT | Marco Concetto Rudilosso, Noah Gibbs | none - see below |
| logger | 1.7.0 | Ruby, BSD-2-Clause | Naotoshi Seo, SHIBATA Hiroshi | COPYING |
| matrix | 0.4.3 | Ruby, BSD-2-Clause | Marc-Andre Lafortune | COPYING |
| minitest | 5.27.0 | MIT | Ryan Davis | none - see below |
| mustermann | 4.0.0 | MIT | Konstantin Haase and others | LICENSE |
| nokogiri (nokogiri-pure) | 1.19.4 | MIT | Andi Idogawa; Nokogiri: Mike Dalessio, Aaron Patterson and others | LICENSE-nokogiri.md, LICENSE-DEPENDENCIES.md (the ported libxml2, libxslt and gumbo) |
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
| rubyzip | 3.7.0 | BSD-2-Clause | Robert Haines, John Lees-Miller, Alexander Simonov | LICENSE.md |
| scarpe-components | 0.5.0 | MIT | Marco Concetto Rudilosso, Noah Gibbs | none - see below |
| sinatra | 4.2.1 | MIT | Blake Mizerany, Ryan Tomayko, Simon Rozet, Konstantin Haase | LICENSE |
| three-rb | 0.2.1 | MIT | LEF | LICENSE |
| tilt | 2.9.0 | MIT | Ryan Tomayko, Magnus Holm, Jeremy Evans | COPYING |
| ttfunk | 1.8.0 | Prawn's Ruby-style licence, GPL-2.0 or GPL-3.0, at your choice | Alexander Mankuta, Gregory Brown, Brad Ediger, Cameron Dutro and others | LICENSE, COPYING, GPLv2, GPLv3 |

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

## Not bundled

Gems installed at runtime from rubygems.org, and pages fetched through the
same-origin bridges (`nginx/default.conf`), go straight from their source to the
learner's browser; the site only relays and caches them.

## The 📦 Program button (optional, `html/compile/`)

The toolchain that turns a cell into a Windows or Linux program is built by
`tools/compile/build.sh` into `html/compile/toolchain/` and is not part of the
repository; a deployment that builds it ships these:

| Component | Version | License | Where |
|---|---|---|---|
| [Spinel](https://github.com/matz/spinel) (compiler as wasm, runtime archives and headers inside every program) | master 84f5b50 | MIT | `toolchain/spinel.wasm`, `toolchain/pkg/` |
| [LLVM](https://llvm.org/) clang and lld as wasm | 20.1.2 | Apache-2.0 WITH LLVM-exception | `toolchain/clang.*`, `toolchain/lld.*` |
| [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) / [mingw-w64](https://www.mingw-w64.org/) headers and libraries (linked into every `.exe`) | 20261006 | ZPL-2.1 and public domain (headers, import libraries), BSD/MIT parts | `toolchain/pkg/win.tar.gz` |
| [musl libc](https://musl.libc.org/) (linked statically into every Linux program) | Alpine's | MIT | `toolchain/pkg/linux.tar.gz` |
| libgcc, libgcc_eh (Alpine's gcc) | Alpine's | GPL-3.0 WITH GCC-exception | `toolchain/pkg/linux.tar.gz` |
| [wasi-sdk](https://github.com/WebAssembly/wasi-sdk) (builds Spinel's wasm) | 34 | Apache-2.0 WITH LLVM-exception, wasi-libc MIT/BSD | not shipped |
| [@bjorn3/browser_wasi_shim](https://github.com/bjorn3/browser_wasi_shim) | 0.4.2 | MIT OR Apache-2.0 | `html/compile/wasi-shim/` (licenses beside it) |
