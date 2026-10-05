# Experiment 01: matplotlib charts under PyCall cells

**Outcome: it works.** Pyodide's own matplotlib (3.10.8, from the vendored
Pyodide 314.0.7) loads through the existing bridge, unchanged. A Ruby cell
calling `plt.show()` gets the chart as an SVG under the cell, and
`plt.savefig("x.png")` offers the file as a download. A Chromium probe
passes 24 of 24 checks across de/en/ja. The cost is **+9.1 MB** of wheels,
downloaded only by a lesson that imports matplotlib, plus the offline copy
when "Python mitnehmen" is ticked. The first `import matplotlib.pyplot`
takes about 5-6 s. After that, a chart takes 0.2-0.5 s.

Nothing under `html/`, `test/`, `tools/` or `docs/` was changed. Every
change is a copy or a diff in this folder.

## What is here

| File | What |
|---|---|
| `pycall.rb` | `html/pycall.rb` plus matplotlib: the bridge's backend, `plt.show()` -> SVG, `savefig` -> Ruby's files, `Kernel#show_plot`. **`pycall.diff`** is the change against `html/pycall.rb`, about 110 added lines. |
| `plot.css` | One rule for `app.css`. An SVG `.cell-image` keeps its own size and is not pixelated. |
| `vendor_matplotlib.rb` | Reads the full Pyodide lockfile, walks matplotlib's dependencies, prints sizes, and with `--fetch` puts the new wheels and a merged `pyodide-lock.json` into `vendor/` (gitignored, 9.4 MB). It does the same SHA-256 check as `tools/vendor_pyodide.rb`. |
| `lesson_matplotlib.rb` -> `lesson_matplotlib.json` | A lesson sketch in de/en/ja: 10 cells, in the lessons.js format. |
| `serve.rb` | WEBrick on 127.0.0.1:18101. It serves `html/` with this folder laid over it: our `pycall.rb`, `app.css` + `plot.css`, `lessons.js` with the sketch inserted after "numpy", and the vendored lockfile and wheels. |
| `browser_probe.mjs` -> `probe.log` | Playwright end-to-end run: the whole lesson, the exercise, savefig, Japanese, timings and transfer sizes. Its screenshots are in `shots/`. |
| `debug_probe.mjs` -> `import_timing.log` | Where the first import spends its time, measured in Pyodide directly. |

Run it yourself:

```sh
ruby experiments/01-matplotlib-charts/vendor_matplotlib.rb --fetch
ruby experiments/01-matplotlib-charts/lesson_matplotlib.rb
PORT=18101 ruby experiments/01-matplotlib-charts/serve.rb        # background
PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/e41f203b7505f1fb/node_modules/playwright \
  BASE=http://127.0.0.1:18101/ node experiments/01-matplotlib-charts/browser_probe.mjs
```

## How it works

- **Loading needed no changes.** `ensurePython` already finds
  `import_module("matplotlib.pyplot")` in a lesson's code, maps it to the
  package `matplotlib` through `pyodide-lock.json`, and `loadPackage` brings
  in the dependencies. The workshop's load-on-ModuleNotFoundError path is
  the same mechanism. Of the 12 packages, numpy, python-dateutil, pytz and
  six are already vendored.
- **Backend.** Pyodide's matplotlib picks **webagg** by default. Its
  `show()` wants a tornado server, so that is useless here. The bridge
  therefore writes a small backend module, `chunky_backend.py`, into
  Pyodide's file system (`/home/pyodide/.chunky`, added to `sys.path`) and
  sets `MPLBACKEND=module://chunky_backend` when the bridge is created.
  That is before any cell can import matplotlib. If pyplot was imported
  earlier anyway, it calls `switch_backend` (tested). The module is Agg
  (draws into memory) plus a `show()` that renders every open figure to SVG
  and closes it. This is what `matplotlib-inline` does in Jupyter.
- **Getting figures to Ruby costs no extra round trip.** `run()` attaches
  the SVGs that `show()` produced to that request's JSON answer
  (`"figures"`). `PyCall.request` then calls `ChunkyApp#add_image` with a
  `data:image/svg+xml;base64,...` URL. This is the existing `show_image`
  route, so `main.rb` needs no change, and an exercise check sees the chart
  in `images`.
- **`plt.savefig("wetter.png")`.** The backend wraps `Figure.savefig`. For a
  relative file name it reads the written file back and sends it along
  (`"files"`). Ruby writes it into `SandboxFS`, so FileWatch offers it as a
  download. The workshop should also keep it in the project, but that is
  not tested. `File.read("wetter.png")` works in the next line of Ruby. The
  lesson code is exactly what runs on a computer with the real pycall gem,
  where `show()` opens a window and `savefig` writes the file.
- **`show_plot` / `show_plot(fig)`** (a `Kernel` helper) is the explicit
  form. It renders one figure through a new bridge op, `figure`, and closes
  it. The lesson does not need it, and it is the only part that would not
  run on a computer unless the companion gem adds it.
- **SVG with `svg.fonttype: none`.** Text stays `<text>`, so the browser
  draws it. That makes the file smaller, and **Japanese works** even though
  matplotlib's DejaVu Sans has no CJK glyphs: matplotlib only uses DejaVu
  to measure the text (screenshot `shots/6-japanese.png`). Its "Glyph ...
  missing" warnings are suppressed for the SVG.
- **CSS.** `.cell-image` is 160 px wide and pixelated, which suits the
  ChunkyPNG lessons. `plot.css` gives an SVG its natural size, so no
  `main.rb` change is needed.

## Evidence (probe.log, Chromium 1.62.1, localhost)

Everything passed: the line, bar, NumPy-curve and subplot charts; a second
run draws once (not twice); savefig -> `wetter.png` download (24 KB, a real
PNG); the starter fails and the solution passes; a Japanese title; two open
figures -> two images; `show_plot(fig)` closes the figure; savefig without
an extension -> `.png`; savefig as SVG; a matplotlib error ->
`PyCall::PyError`; the en and ja pages each draw their first cell.
Screenshots: `shots/1-line.png` … `shots/8-page-ja.png`.

### Sizes

| | |
|---|---|
| New wheels (`vendor_matplotlib.rb`) | matplotlib 6818 KB, fonttools 1126 KB, pillow 1013 KB, pyparsing 120 KB, contourpy 116 KB, packaging 94 KB, kiwisolver 36 KB, cycler 8 KB = **9.11 MB** (zip archives, so gzip does not help) |
| Already vendored and reused | numpy 2.9 MB, python-dateutil, pytz, six |
| First visit to the lesson (measured) | 18.7 MB from `assets/pyodide/`: core 6.2 MB + numpy etc. 3.4 MB + matplotlib 9.1 MB |
| Offline copy with Python | ~43 MB -> **~52 MB**. Offline total ~87 -> ~96 MB stored, up to ~55 -> ~64 MB to download |
| Inside the matplotlib wheel | 3.65 MB (compressed) is `mpl-data/fonts/ttf` (DejaVu Sans/Serif/Mono + STIX), 0.2 MB AFM, 0.12 MB PDF core fonts, 0.23 MB sample_data |
| An SVG chart | 12 KB (line or bar), 20 KB (two panels; a 10 000-value histogram). It grows with the marks: a 2000-point scatter is 225 KB |

### Timings (this machine, with 10 agents running in parallel, so treat as rough)

| | |
|---|---|
| First `import matplotlib.pyplot` (cell 1) | 5.7-9.0 s in the probe. Pyodide directly: numpy 0.9-1.25 s, PIL 0.1 s, matplotlib 1.9 s, font_manager 0.12-0.15 s (39 fonts, so a font cache is not the issue), pyplot 2.5-2.8 s |
| Each later chart | 0.2-0.5 s (warm re-run 0.27-0.47 s; histogram of 10 000 values 0.7-1.0 s) |
| First SVG / PNG save | 0.27-0.37 s / 0.34-0.43 s |

## What does not work, or is open

- **`fig, ax = plt.subplots` probably does not unpack** (not tested). This
  is a limit of the bridge, not of matplotlib: a Python tuple comes back as
  one `PyObject`, `to_ary` is refused, and `to_a` turns the elements into
  strings (`plain`). The sketch uses `plt.figure` + `fig.add_subplot`
  instead, which works. Fixing it means deciding what a tuple becomes, as
  the real gem does (`PyCall::Tuple`), and that touches every PyCall lesson
  (`df.shape`).
- **A PNG from `savefig` with Japanese text shows boxes**: DejaVu has no
  CJK glyphs. The SVG on screen is fine. A real fix would bundle a CJK font
  (several MB). The ja lesson runs the English code anyway (HANDOVER §3), so
  its labels are English.
- **First-import time (~6 s)** hits the first click. See next steps.
- **`File.binread` of a virtual file** does not see SandboxFS. `File.read`
  does. This is an existing SandboxFS limit, not specific to this
  experiment.
- **Live runs re-render the chart while you type.** The rehearsal output is
  shown faint (the ja screenshot shows this), which works. Not checked:
  whether the first ~6 s import hits AutoRun's time limit before it is
  warm.
- **matplotlib's OO API without pyplot** (`matplotlib.figure.Figure.new`)
  does not load the backend, so `savefig` is not passed to Ruby. Rare in a
  lesson.
- The red-data-tools `matplotlib` gem (`require "matplotlib/pyplot"`) is a
  pure-Ruby wrapper over pycall. It would need its own shim, and its code
  has no `import_module("...")` for `ensurePython` to see.

## Next steps to integrate

1. `tools/vendor_pyodide.rb`: `PACKAGES = %w[pandas sympy scikit-learn matplotlib]`.
   Run it, then `ruby tools/offline_files.rb` (8 new files). `compress_assets`
   is unchanged, because wheels get no `.gz`.
2. `html/pycall.rb`: apply `pycall.diff`.
3. `html/assets/app.css`: add `plot.css` (one rule).
4. The lesson: move `lesson_matplotlib.rb` into the `tmp/*_lesson.rb`
   generator style and insert it with `tmp/insert_lesson.js` after numpy.
   That renumbers sklearn and later lessons and the "lesson N" references.
   The sketch says "lesson 25" for NumPy and "next lesson" for
   scikit-learn, both of which match a slot right after NumPy. Then:
   - add `matplotlib` to `BROWSER_ONLY` in `test/check_harness.rb`;
   - in `test/browser_test.mjs`, change `46 lessons` to 47 and add the
     probe's core checks (an SVG under cell 1, savefig download, exercise
     pass);
   - the ja prose was written by me and needs a native check.
5. Sizes in the text: `lessons.js` ui `offlinePython` (de/en/ja "43 MB" ->
   "52 MB", and add matplotlib to the list), `offlineExplain` (55/87 MB);
   `README.md:75`; `docs/HANDOVER.md` §6c/§6d (43/36, 87, 55 MB; the
   package list); `html/index.html`'s ensurePython comment; the stale
   "~25 MB" in `html/offline.js:10` and `html/shell/workspace.rb:281`.
6. `THIRD_PARTY_NOTICES.md`: matplotlib (PSF-based matplotlib license,
   bundles DejaVu fonts (Bitstream Vera/DejaVu license), STIX fonts (OFL),
   FreeType, Qhull, Agg); contourpy (BSD-3), cycler (BSD-3), fonttools
   (MIT), kiwisolver (BSD-3), packaging (Apache-2.0/BSD-2), pillow (MIT-CMU,
   bundles libjpeg/libpng/zlib/freetype), pyparsing (MIT). Check each
   wheel's `dist-info` before writing these down.
7. Optional:
   - **Warm the import.** In `ensurePython`, after `loadPackage` has loaded
     matplotlib, set `MPLBACKEND` and run `import matplotlib.pyplot` in the
     background (`runPythonAsync`). The ~6 s then overlaps with reading
     the lesson text instead of the first click.
   - **A slimmer wheel.** Drop DejaVu Serif/Mono-variants, AFM/PDF core
     fonts and sample_data, and re-hash in the lockfile. About 2.5-3 MB
     less, but it is a repacked third-party wheel to maintain.
   - **The companion gem** (`gem/chunky_bacon`): `show_plot` = `savefig`
     to a temp file + open.
   - **A Figure as a cell's last value**, shown as its chart, like a
     DataFrame's table (`python_result_html`).
