# PicoRuby.wasm runtime

Written by `tools/vendor_picoruby.rb` - rerun it rather than editing these files.
The page's shell runs on this runtime (`html/shell/`, docs/PICORUBY_SHELL.md), and the
PicoRuby lesson runs a second instance of it in a Web Worker (`html/picoruby_worker.js`).

| | |
|---|---|
| Package | `@picoruby/wasm-wasi` 4.0.3 (npm registry) |
| Source | https://registry.npmjs.org/@picoruby/wasm-wasi/-/wasm-wasi-4.0.3.tgz |
| Tarball integrity | `sha512-cT6dU+AfKictr22fmZQTSyEItqqMHZXynlwP0ucZfDhTgX0gIWVaCpDf72GCaJd1JUp4Q5H1uMk18lYlv6v3uA==` |
| Project | https://github.com/picoruby/picoruby |
| License | MIT, text below |

Files from `package/dist/` of that tarball; `init.iife.js` is patched to run
`<script type="text/picoruby">` instead of `text/ruby` (`tools/patch_picoruby_loader.rb`).
The `.gz` copies next to `picoruby.js` and `picoruby.wasm` are written by
`tools/compress_assets.rb` (nginx serves them, `gzip_static`).

| File | Bytes | SHA-256 |
|---|---|---|
| `init.iife.js` | 5218 | `24d7c602322ffe50155a355d2003b9955c78d124e96ac4426d01693c8183b451` |
| `picoruby.js` | 135389 | `d4c525ed29f14475a75bf346a083071b4a262637625692ad7eda063e2eb858a2` |
| `picoruby.wasm` | 2104568 | `477ccdab1f3d64a96ceb097d536565e78981dfaf83a73dde0550f2cac356b534` |

## License

```
Copyright © 2020 HASUMI Hitoshi

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```
