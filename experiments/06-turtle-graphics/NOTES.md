# 06 - Turtle graphics with Chunky the fox

```ruby
turtle { 4.times { forward 100; right 90 } }   # a square, drawn below the cell
```

Status: proof of concept, **working in the real page** (ruby.wasm), the
draft lesson's exercise auto-grades there. Nothing outside this folder was
changed.

## Files

| File | What |
|---|---|
| `turtle.rb` | the whole feature: `class Turtle` + `Kernel#turtle` (pure Ruby, ~420 lines, no gem) |
| `examples.rb` | renders `examples/*.svg` (animated) and `*-still.svg`, and tests the check helpers (13 asserts) |
| `examples/` | square, star, polygons 3..8, spiral, Koch snowflake (depth 3), tree (depth 8) |
| `preview.html` | the examples as `<img>`, the way a cell shows them |
| `make_lesson.rb` -> `lesson_turtle.json` | the draft lesson, de/en/ja, in the shape of one `lessons.js` entry |
| `lesson_check.rb` | the lesson under `check_harness.rb`'s rules: demos run, starter fails, solutions pass, per language in its own process (ja with en code) |
| `serve.rb` | serves `html/` *as if integrated*: `main.rb`, `lessons.js`, `app.css` changed in memory, `turtle.rb` added; this folder under `/turtle/` |
| `browser_check.mjs` | Playwright against `serve.rb`: the lesson's cells draw SVGs, starter fails, Koch passes (Chunky's bubble says pass) |
| `shots/` | screenshots: `preview-midway.png` (animation half way), `preview-end.png`, `app-*.png` (in the course) |

Run: `ruby examples.rb`, `ruby make_lesson.rb && ruby lesson_check.rb`,
`PORT=18106 ruby experiments/06-turtle-graphics/serve.rb` +
`PLAYWRIGHT_DIR=.../playwright node experiments/06-turtle-graphics/browser_check.mjs`.

## Design

- **The turtle is a recorder.** `Turtle` keeps every step
  (`Step = Struct(x1, y1, x2, y2, pen, color, width)`) and every turn. The
  picture is made from that record afterwards, so the same record serves
  drawing *and* grading. Coordinates are maths-style (y up), rounded to 1e-9
  so `4.times { forward 100; right 90 }` ends exactly at (0, 0).
- **Logo conventions**: Chunky starts at (0, 0) looking *up*; headings are
  compass degrees (0 up, 90 right), `right` turns clockwise. Commands:
  `forward/fd`, `back/bk`, `right/rt`, `left/lt`, `pen_up/pu`,
  `pen_down/pd`, `color "red" | "#c14a2e" | "hsl(...)"`, `pen_width 5`,
  `goto x, y`, `home`, `jump n` (forward without drawing), `face deg`,
  `circle r`, `hide`/`show` (the fox). English names only, like Ruby's own
  methods; German lessons keep German names for the learner's methods
  (`vieleck`, `baum`).
- **`turtle { ... }`** instance_evals the block on a new Turtle, so bare
  `forward 100` works *and* top-level `def`s (private methods of Object)
  can call `forward` when invoked inside the block - methods, parameters and
  recursion need no `t.` prefix. `turtle { |t| t.forward 10 }` also works.
  It calls `show_image(turtle)` and returns the turtle, whose `inspect` is a
  one-line log: `#<Turtle 4 lines, Chunky at (0, 0) looking 0°>`.
- **No kernel change needed to display**: `show_image` already accepts
  anything with `to_data_url`; the turtle answers
  `data:image/svg+xml;base64,...`. In the course it lands in
  `<img class="cell-image">` - SVG CSS animations and SMIL run inside an
  `<img>` (verified in Chromium).
- **The SVG** (`Turtle#to_svg`): fitted to 460x400 px (never enlarged
  beyond 1.5x), y flipped, pen widths and the fox scaled so they stay the
  same on screen whatever the drawing's size. Consecutive drawn steps of one
  colour/width form one `<path>`; animation = `stroke-dasharray` /
  `stroke-dashoffset` per path, each path's delay and duration proportional
  to the distance walked (pen-up moves take time too), total 0.6-4 s
  (`turtle(duration: 2)` to choose, `animate: false` for a still).
  Chunky runs along the whole walk with SMIL `<animateMotion
  calcMode="paced" rotate="auto">` - paced = constant speed, which matches
  the strokes' timing - and is swapped (CSS, at the end time) for a static
  fox at the final position and heading. `prefers-reduced-motion` shows the
  finished picture at once. Sizes: square 1.6 KB, Koch depth 3 5.7 KB, tree
  depth 8 (510 lines, colour changes) 56 KB.
- **The fox sprite** is a top-down Chunky in the course's ink-and-white
  style (`html/assets/chunky.svg`), orange tail tip, nose along +x, ~45 px.
  A designer could do better; it is one `<g id="fox">` in `fox_svg`.
- **Safety nets**: more than 100 000 steps raises `Turtle::TooFar`
  ("Chunky is tired: ... a loop that never ends, or a recursion without a
  base case?") instead of freezing the tab, and so do more than 200 000
  turns ("Chunky is dizzy", for `loop { right 90 }`); colours are validated (they go
  into SVG attributes); `save("x.svg")` writes a still SVG, which the course
  offers as a download like any file a cell writes.

## Checks on the recorded path

In a check, `images` holds the data URLs this run showed; `Turtle.from(images)`
maps them back to (snapshots of) the turtles that made them - a registry of
the last 30, filled by `to_data_url`. So checks need **no kernel change** and
work the same in `test/check_harness.rb` (its `show_image` stores
`to_data_url` too). Helpers:

| Helper | Meaning |
|---|---|
| `lines` | drawn steps (pen down, non-zero) |
| `edges` | lines with straight runs joined (`forward 50; forward 50` = one edge of 100) |
| `closed?` | the drawing ends where it began |
| `corners` | turn between consecutive edges, signed degrees (+ right), wrapping if closed |
| `winding` | `corners.sum / 360`: 1 for a square, 2 for a 5-point star |
| `regular_polygon?(n, side = nil)` | closed, n equal edges (of length `side`), equal corners |
| `area` | shoelace area of a closed drawing |
| `total_length`, `bounds`, `colors`, `position`, `heading` | the obvious |
| `same_shape?(other, scale: false)` | same edge lengths and corners as a reference turtle (not cyclic-shift invariant) |

Examples: square `t.regular_polygon?(4, 100) && t.winding == 1`; star
`t.regular_polygon?(5) && t.winding.abs == 2`; the lesson's Koch check below.

## Lesson draft (`lesson_turtle.json`)

id `turtle`, "10. Malen mit Chunky" / "10. Drawing with Chunky" /
"10. Chunkyとお絵かき", proposed **right after `methoden`** (lesson 9): it
reuses loops (6) and methods with parameters (9) and introduces recursion,
which no lesson teaches yet. 8 cells (4 text, 3 demos, 1 exercise):

1. h - Logo, Seymour Papert, Chunky as the turtle; the commands.
2. c - the square: `turtle do 4.times do forward 100; right 90 end end`.
3. h - the `=> #<Turtle ...>` log; 360 degrees per polygon; a method with two parameters works inside the block.
4. c - `def vieleck(ecken, seite)` (en `polygon(corners, side)`), polygons 3..8 in hsl colours, then a star (`right 144`).
5. h - recursion: a tree is a trunk with two smaller trees; base case; `back` so the caller continues.
6. c - `def baum(laenge, tiefe)` (en `tree(length, depth)`), depth 7.
7. h task - the Koch snowflake: depth 0 is a line, depth n is four curves of n-1 at a third, `left 60, right 120, left 60` between; fill in the `else` branch.
8. x - starter with an empty `else` (draws nothing, fails). Check (identical in de/en/ja):

```ruby
(t = Turtle.from(images).last) && t.closed? && [48, 192, 768].include?(t.edges.size) &&
  t.edges.map { |e| e.length.round(1) }.uniq.size == 1 &&
  (t.corners.map(&:round) - [60, -60, 120, -120]).empty?
```

Accepts depth 2-4 and the inward ("anti-snowflake") variant - both are
correct recursion; rejects the triangle and a 48-gon of equal edges.
`lesson_check.rb`: all 8 checks per language pass. In the browser:
starter fails, solution passes, the lesson gets its tick.

Japanese follows the rules: English code with Japanese comments, check
byte-identical to en, prose です・ます, hint in Chunky's casual voice. The
Japanese text is a draft by a non-native writer - worth a native read.

## Integration steps

1. `git mv`-style copy: `experiments/06-turtle-graphics/turtle.rb` -> `html/turtle.rb`.
2. `html/main.rb`, after `require_relative "autorun"`:
   ```diff
    require_relative "autorun"
   +# turtle { forward 100 }: drawings with Chunky as the turtle, as animated SVG
   +require_relative "turtle"
   ```
   (Eager: 14 KB of Ruby, parsed in a few ms. Alternatively lazy like
   numo: define `Kernel#turtle` in main.rb to fetch-and-eval `turtle.rb` on
   first use - then `Turtle.from` in checks must not be called before.)
3. `html/assets/app.css` - `.cell-image` is a 160 px pixelated thumbnail; SVGs need their own size:
   ```diff
   +/* turtle graphics: an SVG picture keeps its own size and stays sharp */
   +.cell-image[src^="data:image/svg+xml"] { width: auto; image-rendering: auto; }
   ```
4. `html/lessons.js`: insert `lesson_turtle.json` after `methoden` and
   renumber every later title (10 -> 11 ...) and prose "Lektion N" /
   "lesson N" / 「レッスンN」 references in all three languages
   (`tmp/insert_lesson.js` pattern, HANDOVER §3). Or, with no renumbering
   of the basics, as the first side trip before `three` (then titles "19."
   and the prose's "Lektion 6/9" references still hold).
5. `test/check_harness.rb`: `require_relative "../html/turtle"` near the
   top (after its own `show_image`, which already stores `to_data_url`), and
   `SOLUTIONS["turtle"]` = the de and en Koch solutions from
   `lesson_check.rb#solution`.
6. `test/browser_test.mjs`: lesson count 46 -> 47; optionally port
   `browser_check.mjs`'s three asserts.
7. `tools/offline_files.rb` (adds `turtle.rb` to `html/offline-files.txt`).
8. README feature list (+ lesson count), HANDOVER §2 layout line for
   `turtle.rb`, social card count (`tools/render_social_cards.mjs`).
9. Companion gem (`gem/chunky_bacon`): ship `turtle.rb` too, so
   `turtle { }` runs on a computer; there `show_image` writes the SVG.
10. The workshop gets it for free (same Kernel).

## Open ends / ideas

- Error for `forward` called *outside* `turtle { }` is Ruby's plain
  `NoMethodError ... for main`; a friendlier message would fit
  `live_hint`/error rendering in main.rb. (Defining `forward` on main was
  rejected: it would shadow a learner's own top-level `def right`.)
- Error messages are English only; route them through `ui` strings for de/ja.
- SMIL ignores `prefers-reduced-motion`; the moving fox is hidden by CSS
  then, which is enough.
- Live runs replay the animation on every pause while typing - fun, but
  maybe `animate: false` during rehearsals (`ChunkyApp.instance.auto_run?`).
- More exercises the helpers already grade: "a house without lifting the
  pen" (`closed?` false allowed, `lines.size`, `same_shape?`), "a star with
  7 points" (`regular_polygon?(7) && winding == 3`), "a spiral"
  (`lines.map(&:length)` strictly increasing).
- `fill`/filled shapes and `write "text"` are not there; easy to add to the record.
- Playwright: the MCP browser is shared with the other agents (my first
  `browser_navigate` ended up on another agent's page) - use a private
  `chromium.launch()` script like `browser_check.mjs` instead. The MCP call
  also left `.playwright-mcp/` logs in the main checkout's root (outside the worktree).
