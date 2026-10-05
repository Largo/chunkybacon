# Open work

What is unfinished, what state it is in, and where the context for it lives.
`docs/HANDOVER.md` explains how everything works; this file lists what is in
flight. Keep it short and current: tick items off, delete finished sections.

Last updated 2026-10-05.

## Where the context is defined

| What | Where |
|---|---|
| What the site is, its features | `README.md` |
| How it works, where the traps are | `docs/HANDOVER.md` - §2 layout, §3 lessons (format, renumbering, the Japanese rules), §4 gems and the pure stand-ins, §6a workshop and storage, §6b live runs, §6c offline mode, §6d Python (and matplotlib), §6e Rumale, §6f SQLite and Sequel (databases in files too), §6g TTY and terminal colours, §6h Processing, §6i Faker, §6j ERB and Herb, §8 tests, §11 older open ends |
| The page shell on PicoRuby, its portability rules | `docs/PICORUBY_SHELL.md`, `test/shell/portability_test.rb` |
| Every bundled component and its licence | `THIRD_PARTY_NOTICES.md` |
| All lesson text, code, checks and UI strings | `html/lessons.js` - the source of truth |
| Lesson generators (scratch, **not in git**) | `tmp/*_lesson.rb` (pycall_lesson_v2, sympy, numpy, matplotlib, sklearn, sequel) write `tmp/<id>_lesson.json`; `tmp/insert_lesson.js` inserts and renumbers (`tmp/insert_lesson_into.js`: the same for a worktree's `LESSONS_JS`; `tmp/matplotlib_lesson_edits.js`: the edits around the matplotlib lesson), `tmp/replace_lesson.js` swaps one lesson. A hand edit to `lessons.js` is lost if a generator runs again - edit the generator too, or only `lessons.js` |
| Local Playwright helper (scratch, **not in git**) | `tmp/playwright_redirect.mjs` + `tmp/playwright_resolve_hook.mjs` (see "Working on this machine") |
| Experiments (prototypes, not on the site) | `experiments/NN-<idea>/NOTES.md` - what was tried, measurements, integration steps |
| Hosting details | `docs/HOSTING.local.md` - local only, excluded from git |

## State of the repository

- `main` is deployed (2026-10-05), 51 lessons. Merged that day: PR #2
  Sequel and SQLite databases in files (HANDOVER §6f); PR #3 the four
  side trips after Scarpe, TTY, Processing, Faker, ERB + Herb (HANDOVER
  §6g-§6j), each lesson with its own top-level scope
  (`TopLevel.binding`); the experiments' fixes #15 (an SVG under a cell
  keeps its size), #16 (Escape, then Tab leaves a code cell; editors named,
  focus ring) and #17 (the mini browser draws in a shadow root, HANDOVER
  §6); PR #19, lesson 26 matplotlib (HANDOVER §6d, supersedes #4), which
  renumbered scikit-learn and every later lesson and turns a Python tuple
  into a Ruby Array.
- The experiments #5-#13 are merged too (2026-10-05, rebased): each is
  only `experiments/NN-<idea>/` (prototype, tests, `NOTES.md` with
  measurements and integration steps), nothing under `html/`, so none of
  them is on the site yet. 02 stepping through a cell, 03 `show_objects`,
  04 friendly error messages, 05 sound synthesis, 06 turtle graphics,
  07 the `lessons.js` linter, 08 a game loop (Snake), 09 one runnable cell
  embedded elsewhere (with a security analysis), 10 the accessibility
  audit. They were written against `sequel-lesson`, so lesson and line
  numbers in their notes are older than `main`. Before the merge every
  CodeRabbit finding was fixed or answered, and all of them were tested
  together on top of `main`: each experiment's Ruby checks
  (`test_step_recorder.rb`, `object_graph_test.rb`, `run_corpus.rb`,
  `robustness_check.rb`, `lesson_check.rb` of 05 and 06, `examples.rb`,
  `lint_lessons_test.rb`, `lint_lessons.rb`, `game_test.rb`) and the
  browser checks of 06 (`browser_check.mjs`), 09 (`test_embed.mjs check`)
  and 10 (`verify_fixes.mjs`, `keyboard.mjs`). Not re-run: the
  measurement scripts (`wasm_probe.mjs`, `measure_in_page.mjs`,
  `play_snake.js`, `test_embed.mjs measure`) and 05's `wavefile_check.rb`
  (needs the wavefile gem in `vendor/`, not in git).
- Taking an experiment onto the site means following its `NOTES.md`
  integration steps in `html/` - a normal change with the browser tests.
- Other sessions work in git worktrees under `.claude/worktrees/`
  (2026-10-05: `improve-lessons`, `tty-processing-faker-erb-lessons` -
  behind `main`, its PR is merged - `ocran-lesson`, `rumale-lesson`,
  `pyodide-llm-rubyllm-988ed8`, `ideas`). `ocran-lesson` inserts a
  lesson right after Scarpe, so it conflicts with `main` in
  `html/lessons.js`, the count tests, README and HANDOVER: rebase it onto
  `main` and re-run the `tmp/insert_lesson.js`-style renumbering rather
  than hand-merging. (`git` also warns that it cannot delete
  `.git/worktrees/agent-a88082be1e674fa38`, a stale entry - harmless.)

## Smaller open ends found on the way

- A re-run of a cell with `DB = Sequel.sqlite` reassigns a constant; the
  cell shows only its result (`=> [:eintraege]`), no warning (checked
  2026-10-05). The file step uses a local variable.
- The lesson linter (`ruby experiments/07-lesson-linter/lint_lessons.rb`,
  on `main`, not in CI) still warns: `rubykaigi` [ja] cells 1 and 7 end
  in plain form (perhaps on purpose - a talk's punchline), `sequel` [de]
  cell 5 has a 102-column line, and `docs/PICORUBY_SHELL.md` quotes an
  old lesson count. Decide, then fix or accept (`allow.txt`). Its
  `--base=origin/main` run finds every lesson reference pointing at the
  same lesson as on `main`.
- Found by the experiments, in today's code (details in their `NOTES.md`):
  the live-run tracer makes code about 36x slower in ruby.wasm, so a cell
  looping over ~100k elements hits the 1 s limit (#8 suggests a per-lesson
  `"live": false`); once any time-limit tracer has been on, plain runs stay
  about 40% slower for the rest of the visit (#11); every cell is evaluated
  as `chunky.rb`, so an error in a method from an earlier cell reports that
  cell's line numbers (#7, #5); the accessibility audit's other findings -
  no live region for results, focus lost after a run or a lesson change,
  the phone drawer not modal, no skip link, five contrasts (#13). Re-run
  on `main` 2026-10-05: the unnamed editor (axe `label`) is gone and
  Escape, then Tab leaves a cell (#16); Tab still indents and Shift+Tab
  stays in the editor, so `keyboard.mjs` still reports the trap; the
  rest unchanged (Sinatra's contrast findings 39 -> 21).
- The offline dialog's sizes (`offlineExplain`, `offlinePython`, README,
  HANDOVER §6c, `test/shell/workspace_test.rb`) are measured by hand: the
  files of `offline-files.txt` in MiB, a text file without a `.gz` counted
  gzipped (`tmp/offline_size.rb`). Re-measure after adding big files.
  Last measured with matplotlib: 100.8 MB stored, ~67.8 MB to download,
  Pyodide 51.7 / 44.9 MB of it.
- sql.js binds an integer beyond 32 bits as text (`BigInt` -> string);
  column affinity makes it an integer in an INTEGER column, not in a bare
  expression.
- Declared result types come from `PRAGMA table_info` of the tables after
  FROM/JOIN (a regex): subqueries, CTEs and computed columns get none.
- Sequel's `setup_regexp_function` cannot work (`create_function` raises).
- The limits of file databases (temp tables and `last_insert_rowid` reset
  after a run, two connections to one file, `SAVEPOINT` outside BEGIN, the
  1 MB size limit) are documented in HANDOVER §6f; change the design if one
  of them starts to matter.
- Not done on purpose: CodeRabbit's docstring-coverage warning (not this
  repository's style); `.gz` copies of Python wheels (zip already, gzip
  saves under 2%); compiling sqlite3 into ruby.wasm (a custom wasm build
  for every ruby.wasm update - revisit if ActiveRecord is wanted).
- matplotlib (HANDOVER §6d), not done: a PNG from `savefig` shows boxes
  for Japanese (DejaVu Sans has none; a CJK font would add several MB -
  the SVG on screen is fine); a slimmer wheel without the unused fonts
  (2.5-3 MB less, but a repacked wheel with its own SHA-256); a Figure as
  a cell's last value shown as its chart, like a DataFrame's table;
  `to_a` of a Python list of objects gives their `str` (the gem's
  PyCall::List keeps the objects); the red-data-tools `matplotlib` gem
  (`require "matplotlib/pyplot"`) would need its own shim.
- PR #1's description only covers its first commit (merged anyway).

## Working on this machine (Windows)

- Browser tests need Playwright from the npx cache and the local redirect
  hook (both outside git):
  `PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/<hash>/node_modules/playwright BASE=http://127.0.0.1:18021/ node --import ./tmp/playwright_redirect.mjs test/browser_test.mjs`
  (1.62.1 matches the installed Chromium). Worth moving the hook into
  `tools/` if it stays needed. The experiments' scripts take
  `PLAYWRIGHT_DIR` directly, without the hook; `experiments/10-accessibility`
  needs `npm ci` there first (axe-core).
- Dev server: `PORT=18021 ruby tools/dev_server.rb`. Stopping it as a
  background task can leave `ruby.exe` running, and Windows lets two
  servers share a port - the old one may answer. Check with
  `Get-NetTCPConnection -LocalPort <port>`.
- `core.autocrlf` is on: vendored assets are `-text` in `.gitattributes`.
  If `tools/compress_assets.rb --check` says STALE after a checkout, delete
  the file and check it out again.
- Helper scripts are files (in `tmp/` or `tools/`), not inline `-e`
  commands - the machine runs endpoint protection.
