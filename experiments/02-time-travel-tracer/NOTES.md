# 02 - Time-travel tracer: step through a cell

**Integrated.** `step_recorder.rb` moved to `html/` (loaded at boot like
`autorun.rb`: 14 KB, ~6 ms to evaluate in ruby.wasm; in
`offline-files.txt`), `test_step_recorder.rb` to
`test/step_recorder_test.rb` (now with the course's binding, a check that
`HIDDEN` covers every local `check_exercise` sets, schleifen's loop, a
turtle block, and every code cell of the flagged lessons in de and en).
The button is ⏯ beside ▶, only in lessons with `"stepper": true` - the
user's decision: the Basics 3-12 (variablen, strings, wenn, schleifen,
arrays, hashes, methoden, turtle, klassen, module); not hallo/rechnen
(one-liners), the IRB, or 14-19 (gems, servers, the network). It sends
`ChunkyBridge.step(idx)`, `run_cell(idx, step: true)` wraps the eval in
the recorder, and `show_steps` hands the JSON to `ChunkyBridge.steps`,
which parses it in JS. The widget is plain JS, `html/stepper.js` (not
the shell: it re-renders on every move), built from `scrubber.html`'s
`render()`: the current line marked in the CodeMirror editor itself
(`addLineClass`), Chunky's sentence, the frames, the output so far and
the controls in `#cell-out-<idx>` above the run's output; its strings are
`ui.step*` in lessons.js (from the mock's `T`), its CSS in `app.css`.
Changes on the way: **a cell of comments only** (an exercise's starter)
made `TracePoint#enable(target:)` raise - and after that no targeted
TracePoint in the process saw an event again; `events?` now checks the
iseqs first and such a cell records just its end. The hide list grew by
`sketch`, `audios`, `games`, and the `hide: TOPLEVEL_BINDING...` argument
went (a cell's binding is `TopLevel.binding`, it never saw main.rb's
locals). Accessibility: ⏯ named "Schritt für Schritt durch Zelle 2", the
focus to the slider after a run (a native range: arrows, Home, End), its
value "Schritt 3 von 5", ◀ ▶ aria-disabled at the ends, a polite live
region with the sentence and what changed on the learner's moves only,
⏵ with its word on it (alone it looked like ▶) and slower under
`prefers-reduced-motion`. A language change keeps the step where the
cell's code is the same apart from comments (en ↔ ja, German cells with
the English code) and drops it otherwise (German names); any edit or run
of the cell ends it; live runs never record. Left out: the tick strip
(thin past ~200 steps), stepping in the workshop, `show_steps` as a cell
helper; the companion gem needs nothing. `record_samples.rb`,
`measure_overhead.rb` and `wasm_probe.mjs` now load the recorder from
`html/`; `scrubber.html` and its samples are the experiment's record.

Idea: run a cell under TracePoint, record every step (line about to run plus
the local variables of each frame, inspected and truncated), and let the
learner scrub back and forth: the current line highlighted, the variables
beside it, a loop's passes visible.

Status: proof of concept that works. The recorder runs unchanged under CRuby
4.0.1 and in the real page on ruby.wasm (4.0.0, wasm32-wasi). There is a
static scrubber mock fed with recorded traces, 13 Minitest checks, and
measurements. Nothing outside this folder was changed.

## Files

| File | What |
|---|---|
| `step_recorder.rb` (now `html/step_recorder.rb`) | **The recorder** (`StepRecorder`), about 380 lines, stdlib `json` only |
| `test_step_recorder.rb` (now `test/step_recorder_test.rb`) | Minitest, 13 tests / 48 assertions: shared binding, hoisting, earlier-cell methods, `_1`/`it`, odd values (raising `inspect`, BasicObject, big objects), cap, errors, syntax errors, output offsets, deep recursion, nesting under `AutoRun.with_time_limit` |
| `record_samples.rb` | Mini kernel (one binding, `eval(code, bind, "chunky.rb")`, `$stdout` as a StringIO, like `run_cell`). Records 9 samples from schleifen/arrays/methoden plus recursion, an error, and a long loop → `samples.js` / `samples.json` |
| `scrubber.html` | Static mock of the widget: reads `samples.js`, works from `file://`, has de/en/ja strings. `?sample=<id>&step=<n>&lang=<l>` |
| `shots/*.png` | Playwright screenshots of the mock (`screenshots.mjs`) |
| `measure_overhead.rb` → `measure_cruby.txt` | CRuby numbers |
| `wasm_probe.mjs` + `wasm_probe_tail.rb` → `wasm_probe_result.txt` | The recorder pasted into a lesson cell on the real page (dev server), with timings |
| `probe_targeted.rb`, `probe_unwind.rb` | The TracePoint facts the design rests on |
| `dump_trace.rb` | Prints a recorded trace compactly (`ruby dump_trace.rb fehler`) |
| `make_lessons_json.js`, `dump_cells.rb` | List the lesson cells (writes `lessons.json` here, not in `test/`) |

Run: `ruby test_step_recorder.rb`, `ruby record_samples.rb`, then open
`scrubber.html`. For screenshots:
`PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/e41f203b7505f1fb/node_modules/playwright node screenshots.mjs`.

## How it works (the parts that matter)

1. **Targeted TracePoint.** A `:script_compiled` hook waits for the eval of
   exactly this cell's code (`tp.eval_script == code` and
   `tp.instruction_sequence.path == file`; note that `tp.path` there is the
   *caller's* file, not the eval's). Inside the hook it calls
   `tracer.enable(target: iseq)`. The trace then covers that iseq and every
   method and block it defines, recursively, and **nothing else**:
   - gems, the stdlib, the page's own Ruby, and Ruby-level core methods
     (`Integer#times` lives in `numeric.rb`) raise no events. Gem-heavy code
     costs about 1.2-2.5x instead of the 3-6x of a global TracePoint;
   - **methods an earlier cell defined are not stepped into**, even though
     they have the same file name `chunky.rb` (`probe_targeted.rb`: `gruss`
     from cell 1 stays a single step). Without targeting, their lines would
     be drawn onto the wrong cell's source.
2. **The run is the cell's normal eval** in the shared lesson binding. The
   recorder only wraps it (`rec.run { eval(code, @bind, file) }`), so
   locals, methods and constants persist to the next cell exactly as on ▶
   (tested).
3. **Events:** `:line` (one step, "line N is next", state *before* it runs),
   `:call` (step, frame pushed, args shown), `:return` (step with the return
   value), `:b_call`/`:b_return` (block frame pushed/popped with a pass
   counter, **no step of their own**, so a loop pass is one step per body
   line).
4. **Frames:** main, method, and block frames are snapshotted per step, outer
   first. A block frame shows only its own locals. These come exactly from
   the iseqs (`each_child` → `to_a[10]`, indexed by first line); outer
   variables show in the frame that owns them. Snapshots are interned by
   identity: an unchanged frame reuses its Hash, and the trace has a frame
   table that steps point into (`f: [0, 3]`).
5. **Hoisted locals are hidden.** Eval allocates every local of the cell up
   front (`x` is nil on line 1 even if line 5 sets it). A variable shows
   once it is non-nil, came from an earlier cell (marked ⟲), or a line that
   assigns it has run (a regex on that line, so `y = nil` and `x = gets`
   still show).
6. **Errors.** A targeted TracePoint never sees `:raise`: the raise happens
   in a C frame such as `Integer#+` or `Kernel#raise` (`probe_unwind.rb`), and
   `$!` is not set during the unwinding `:return`s. So `finish` turns the
   last recorded line into the error step, with the state at that moment,
   and drops the `return` steps of unwound frames. Only after the cap does
   it fall back to the backtrace.
7. **Caps:** `MAX_STEPS` 600 (then `tracer.disable` and the cell runs on at
   full speed; the trace says `truncated` and still ends with the final
   state and result), `MAX_VALUE` 60 characters, Arrays/Hashes over 12
   items summarised as `[1, 2, 3, … (100000)]` without inspecting the rest,
   `MAX_FRAMES` 5 (recursion shows the innermost ones plus "… n more"),
   `MAX_VARS` 16. Objects with Ruby's default `Kernel#inspect` get a
   **shallow** inspect (4 ivars, one level deep). Without it, one object
   holding a big Array made every step cost that Array: it showed up as
   3.8 ms per step when the recorder itself was in scope. Raising `inspect`
   → `#<Kaputt>`; BasicObject → `#<BasicObject>`.
8. **Output per step:** `out` is the byte offset into the captured `$stdout`
   (the StringIO `run_cell` already uses). The widget shows the output up to
   that step; the mock converts bytes to UTF-16 with TextEncoder.
9. The recorder never breaks a run: an internal error records a
   `recorder-error` step and switches tracing off. The learner's exceptions
   (including `AutoRun::Stopped`, an `Exception`) propagate unchanged.

Trace shape (JSON):
```
{ code, file, output, result, error, truncated, traced,
  frames: [ {kind: "main"|"method"|"block"|"more", name, line, iter, vars: [[name, inspect, fromEarlierCell 0|1]]} ],
  steps:  [ {event: "line"|"call"|"return"|"error"|"end", line, hit, out, value, f: [frameIdx...]} ] }
```

## Evidence

- **Samples** (`ruby dump_trace.rb <id>`), all correct by hand:
  `3.times` gives 5 steps (one per pass, `i` = 0/1/2, output growing);
  `while` with a sum gives 13; `arrays` cell 5 after cell 1 shows
  `fruehstueck` ⟲ from the earlier cell, and the `<<` mutation appears in the
  next step; `methoden` cell 3 does not step into `begruessung` from
  cell 1; `quadrat` inside `map` shows Zelle → Block (pass 2, `z=2`) →
  Methode (`zahl=2 ergebnis=4`); `fakultaet(4)` stacks 4 method frames
  and returns 1, 2, 6, 24; the error sample stops on line 4, pass 3, `p=nil`,
  `total=8`; the 10,000-pass loop is truncated at 600 steps and still ends
  with `=> 50005000`.
- **Screenshots:** `shots/methoden-map-11-de.png`, `shots/rekursion-12-de.png`,
  `shots/fehler-6-de.png`, `shots/schleifen-times-3-ja.png`,
  `shots/lang-600-de.png` and others.
- **Tests:** `ruby test_step_recorder.rb`: 13 runs, 48 assertions, 0 failures.

## Numbers

The machine was busy (other agents running), so CRuby timings jump 2-3x
between runs. Read them as orders of magnitude.

CRuby 4.0.1 (`measure_cruby.txt`, median of 7):

| program | plain | recorded | steps | JSON |
|---|---|---|---|---|
| 3.times | 0.02-0.06 ms | 0.1-0.3 ms | 5 | 0.8 KB |
| quadrat in map | 0.02-0.14 ms | 0.3-1.2 ms | 19 | 2.3 KB |
| while 200 | 0.02-0.09 ms | 3-13 ms | 405 | 54 KB |
| fib(15) | 0.07-0.3 ms | 14-37 ms | 601 (cap) | 74 KB |
| 100k loop | 6-20 ms | 19-33 ms | 601 (cap, then full speed) | 125 KB |
| CSV, gem-heavy, 3 own lines | 27-29 ms | 35-73 ms | 601 | 98 KB |
| (same CSV under a *global* TracePoint, nothing recorded) | | 88-206 ms | | |

About 10-90 µs per step in CRuby (one frame, a few variables).

ruby.wasm in Chromium (`wasm_probe_result.txt`, single runs, final recorder):

| program | plain | recorded | steps | `trace` | JSON.generate |
|---|---|---|---|---|---|
| 3.times | 0.9 ms | 6.8 ms | 5 | 0.8 ms | 0.7 ms (0.8 KB) |
| quadrat in map | 0.2 ms | 6.1 ms | 19 | 0.5 ms | 0.5 ms |
| while 200 | 0.2 ms | 49 ms | 405 | 6.6 ms | 11 ms (54 KB) |
| fib(15) | 0.2 ms | 128-222 ms | 601 (cap) | 14 ms | 21 ms (74 KB) |
| 100k loop | 41 ms | 183 ms | 601 (cap) | 13 ms | 36 ms (125 KB) |
| error sample | 1.1 ms | 3.1 ms | 7 | 0.3 ms | 0.3 ms |

So in wasm: about **0.1 ms per step** with one frame, and up to about 0.4 ms
with 5 frames. The worst case at the 600-step cap is about 0.25 s including
JSON. A typical basics cell (5-30 steps) costs **under 10 ms**. Interning by
value (hashing nested Hashes) took 171 ms for fib's JSON on wasm; by identity
it is 14 + 21 ms.

## Limitations

- **Blocks:** one-line blocks (`xs.map { |z| quadrat(z) }`) share their line
  with the outer statement, so the line shows as "next" once outside and
  once per pass. Numbered parameters (`_1`) and `it` cannot be read from a
  binding (NameError, and `it` has no name in the iseq), so such a block
  frame shows no variables. A block passed to a method of an *earlier* cell
  that yields is still traced (it is this cell's iseq), but the method is
  not.
- **Steps are lines, not expressions.** `a = 1; b = 2` on one line is one
  step. A `while` condition line raises no event after its first pass
  (Ruby compiles the condition to the loop's end), so the body lines carry
  the pass count. One-line modifier loops are a single step, just as they
  are for `AutoRun`.
- **Methods from earlier cells are opaque** (by design, and the only option
  while every cell evals as `chunky.rb`). Their `puts` output still shows.
- **Values are strings at that moment.** There are no object arrows: two
  variables holding the same Array are not shown as shared. Mutation shows
  in the step after it happens.
- **Error detection uses the last recorded line.** That is correct for
  errors in C methods and in earlier cells' methods. The exception is a run
  past the cap, where the first `chunky.rb` backtrace line is used, and
  that line may belong to an earlier cell.
- **Recursion:** only the innermost 5 frames are snapshotted, and the steps
  run out quickly (fib(15) hits the cap in the first branch). The default
  cap of 600 is a guess. 300 might be enough for beginners and halves the
  worst case.
- The "assigned" regex is a heuristic. Multiple assignment (`a, b = nil, 1`)
  of a nil value stays hidden until it is non-nil.
- The workshop: only the open file (`Workshop.paths` has the others) would be
  traced. A `require_relative`'d project file has its own iseq and would
  need its own `:script_compiled` match. Not done.
- The mock's tick strip gets too thin past about 200 steps. It should group
  into passes there.

## Integration (proposed, not applied)

**Kernel (`html/main.rb`):** about 15 lines plus the file.

1. Add `html/step_recorder.rb` (this file) and load it like `autorun.rb`
   (wherever main.rb pulls in its siblings). Add it to `offline-files.txt`
   via `tools/offline_files.rb`.
2. `run_cell(idx, auto: false, step: false)`: in the `begin` block that
   evaluates:
   ```ruby
   result = if auto
     AutoRun.with_time_limit(...) { evaluate(code, file) }
   elsif step
     @recorder = StepRecorder.new(code, file: file, hide: TOPLEVEL_BINDING.local_variables)
     @recorder.run { evaluate(code, file) }
   else
     evaluate(code, file)
   end
   ```
   The stdout StringIO is already in place, so output offsets work. After
   `out_el.innerHTML = out_html`, if `@recorder`, hand the trace to the
   shell: `bridge.steps(idx, @recorder.to_json)` (a new `ChunkyBridge`
   method), then set `@recorder = nil`. `check_exercise` runs as usual, and
   its locals are in `StepRecorder::HIDDEN`.
3. Live runs stay as they are. Do **not** record on every ▶: the cost is
   small for basics cells but adds up to 0.25 s at the cap. The cleaner
   choice is an explicit "⏯ Schritt für Schritt" button per code cell (or a
   per-lesson switch for the basics lessons), which sends
   `chunky:run` with `step: true`.
4. Optional: `show_steps` as a Kernel helper in a cell (`show_steps { ... }`)
   is possible but awkward: the recorder must match an eval, and a block
   is not one. Recording the cell itself via the button is simpler and is
   what the mock shows.

**Shell (PicoRuby, `html/shell/`):** the widget is render-time UI, so it
belongs in the shell, or in plain JS in `index.html` like `markCellLine`.

- `bridge.js`: `ChunkyBridge.steps(idx, json)`. **Parse the JSON in JS, not
  in PicoRuby** (HANDOVER: `JSON.parse` in PicoRuby is pathologically slow).
  Keep the trace on `window.cellSteps[idx]`.
- The widget is basically `scrubber.html`'s `render()`: about 150 lines of
  JS plus about 60 lines of CSS for `app.css`. Highlight the current line in
  the **CodeMirror editor itself** (`addLineClass`, as `markCellLine`
  does) instead of a separate code copy, and put the variables panel, the
  step slider and Chunky's sentence into `#cell-out-<idx>`. Any edit
  clears the trace (the line numbers no longer match).
- UI strings (`stepBy`, `stepLine`, `stepCall`, `stepReturn`, `stepEnd`,
  `stepError`, `stepPass`, `stepTruncated`, ...) go into `lessons.js` `ui`
  for de/en/ja. The texts in `scrubber.html`'s `T` are a starting point.
- Lessons: the button fits schleifen, arrays, hashes, methoden, and
  rekursion-like exercises. A lesson flag (`"stepper": true`) could show it
  only there.

**Tests to add:** `test_step_recorder.rb` as `test/step_recorder_test.rb`,
plus a `live_test.mjs`-style Playwright check: click ⏯ on schleifen cell 3,
expect 5 steps, slider to step 3, expect `i 1` and two output lines.

## Not tried

- Value-change-only (delta) encoding of steps. Identity interning already
  takes JSON to about 0.1 KB/step for one frame.
- Object identity / arrows (Python Tutor style).
- Stepping into `require_relative` files in the workshop.
- Prism-based "assigned" detection (more exact than the regex). Prism's
  availability in ruby.wasm was not checked.
