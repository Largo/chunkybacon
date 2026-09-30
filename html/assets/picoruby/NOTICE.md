# PicoRuby.wasm runtime

Bundled so that nobody needs npm or a download to use PicoRuby in a custom application.
Install into an app with `ruby scripts/install_picoruby.rb <app dir>` (see
`references/picoruby.md`), which unpacks the `.gz` files next to their compressed copies.

| | |
|---|---|
| Package | `@picoruby/wasm-wasi` 4.0.3 (npm registry) |
| Source | https://registry.npmjs.org/@picoruby/wasm-wasi/-/wasm-wasi-4.0.3.tgz |
| Tarball integrity | `sha512-cT6dU+AfKictr22fmZQTSyEItqqMHZXynlwP0ucZfDhTgX0gIWVaCpDf72GCaJd1JUp4Q5H1uMk18lYlv6v3uA==` (sha1 `be7716fa799f27043543d936411265846f9f985a`) |
| Project | https://github.com/picoruby/picoruby |
| License | MIT, text below |

Files from `package/dist/` of that tarball. `picoruby.js` and `picoruby.wasm` are stored
gzip-compressed (level 6) to save space; their content is unchanged.

| File in this skill | Bytes | SHA-256 of the file | Unpacked | SHA-256 of the unpacked file |
|---|---|---|---|---|
| `init.iife.js` | 5214 | `2c04422bd6ba1e2506aa1f48b3b379263125170618ac3462807e84711e489a2e` | - | - |
| `picoruby.js.gz` | 31101 | `cf48971b1197bd8741d6d04b2f3c3f8db54d8c614f09602367657f94fe1251ad` | `picoruby.js`, 135389 bytes | `d4c525ed29f14475a75bf346a083071b4a262637625692ad7eda063e2eb858a2` |
| `picoruby.wasm.gz` | 873831 | `13d8754e6edbccafdbd3d4e28f53f63f0b115b8a7d25bdceabf607a07d339e5d` | `picoruby.wasm`, 2104568 bytes | `477ccdab1f3d64a96ceb097d536565e78981dfaf83a73dde0550f2cac356b534` |

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
