# Open work

What is unfinished, what state it is in, and where the context for it lives.
`docs/HANDOVER.md` explains how everything works; this file lists what is in
flight. Keep it short and current: tick items off, delete finished sections.

Last updated 2026-10-06.

## Where the context is defined

| What | Where |
|---|---|
| What the site is, its features | `README.md` |
| How it works, where the traps are | `docs/HANDOVER.md` - §2 layout, §3 lessons (format, renumbering, the Japanese rules), §4 gems and the pure stand-ins, §6a workshop and storage, §6b live runs, §6c offline mode, §6d Python (and matplotlib), §6e Rumale, §6f SQLite and Sequel (databases in files too), §6g TTY and terminal colours, §6h Processing, §6i Faker, §6j ERB and Herb, §8 tests, §11 older open ends |
| The page shell on PicoRuby, its portability rules | `docs/PICORUBY_SHELL.md`, `test/shell/portability_test.rb` |
| Every bundled component and its licence | `THIRD_PARTY_NOTICES.md` |
| All lesson text, code, checks and UI strings | `html/lessons.js` - the source of truth |
| Lesson generators (scratch, **not in git**) | `tmp/*_lesson.rb` (pycall_lesson_v2, sympy, numpy, matplotlib, sklearn, sequel) write `tmp/<id>_lesson.json`; `tmp/insert_lesson.js` inserts and renumbers (`tmp/insert_lesson_into.js`: the same for a worktree's `LESSONS_JS`; `tmp/matplotlib_lesson_edits.js`: the edits around the matplotlib lesson), `tmp/replace_lesson.js` swaps one lesson; afterwards `ruby test/lint_lessons.rb --base=origin/main` catches every lesson reference that now points elsewhere. A hand edit to `lessons.js` is lost if a generator runs again - edit the generator too, or only `lessons.js` |
| Local Playwright helper (scratch, **not in git**) | `tmp/playwright_redirect.mjs` + `tmp/playwright_resolve_hook.mjs` (see "Working on this machine") |
| Experiments (prototypes, not on the site) | `experiments/NN-<idea>/NOTES.md` - what was tried, measurements, integration steps |
| Hosting details | `docs/HOSTING.local.md` - local only, excluded from git |

## State of the repository

- `main` has 56 lessons (2026-10-06). The site does NOT show it yet: the
  host's checkout stopped following `main` on 2026-09-30 (the history
  rewrite; GitHub's push webhook is answered with 202, but the live
  `lessons.js` is from 2026-09-30). On the host: `git status`, then
  `git fetch && git reset --hard origin/main` and reload nginx
  (`docs/HOSTING.local.md`); after that check that a push deploys again.
- Merged 2026-10-05: PR #2 Sequel (HANDOVER §6f), PR #3 TTY, Processing,
  Faker, ERB + Herb (§6g-§6j), the experiments' early fixes #15-#17, PR #19
  matplotlib (§6d), and the experiments #5-#13 as `experiments/NN-<idea>/`.
- The experiments are on the page since the integration PR (2026-10-06),
  one commit each; their `NOTES.md` start with an "Integrated" paragraph
  (what went where, what was left out), the rest of each is the record of
  the prototype:
  - 07 the lesson linter: `test/lint_lessons.rb` (no CI runs it yet).
  - 10 accessibility: results read out (`#runStatus`), focus kept after a
    run and a lesson change, skip link, modal phone drawer, contrast,
    names for widgets and run buttons.
  - 04 friendly errors: a failing cell explains itself in de/en/ja
    (`html/friendly_errors*.rb`, loaded on the first error).
  - 03 `show_objects` (`html/object_graph.rb`), demo cells in lessons 7,
    8 and 11; saved cell code is keyed by the cell's starter since then,
    with a migration of the old keys (HANDOVER §6a).
  - 06 turtle graphics, lesson 10 (`html/turtle.rb`).
  - 05 `show_audio` and "Ruby macht Musik", lesson 37; lessons can turn
    live runs off (`"live": false`, §6b).
  - 08 `show_game` and "Chunkys Snake", lesson 38 (`html/game.rb`,
    `game.js`).
  - 02 the ⏯ step-through player on lessons 3-12 (`"stepper": true`,
    `html/step_recorder.rb`, `stepper.js`).
  - 09 one runnable cell for idogawa.com (`html/embed*`, README
    "Embedding a cell", HANDOVER §6k); the bridges (`/rubygems/`,
    `/proxy/ruby-lang/`) answer only the course's own pages: the Referer's
    host must be the host asked (nginx `map`, the same in
    `tools/dev_server.rb` and `server/app.rb`, HANDOVER §7). The nginx
    config was never run through `nginx -t` (no nginx on the dev machine)
    - check it on the host with the deploy.
- Other sessions work in git worktrees under `.claude/worktrees/`
  (2026-10-05: `improve-lessons`, `tty-processing-faker-erb-lessons` -
  behind `main`, its PR is merged - `ocran-lesson`, `rumale-lesson`,
  `pyodide-llm-rubyllm-988ed8`, `ideas`). Branches that insert lessons
  conflict with `main` in `html/lessons.js`, the count tests, README and
  HANDOVER: rebase onto `main`, re-run the `tmp/insert_lesson.js`-style
  renumbering rather than hand-merging, then
  `ruby test/lint_lessons.rb --base=origin/main`. (`git` also warns that it
  cannot delete `.git/worktrees/agent-a88082be1e674fa38`, a stale entry -
  harmless.)

## Smaller open ends found on the way

- A re-run of a cell with `DB = Sequel.sqlite` reassigns a constant; the
  cell shows only its result (`=> [:eintraege]`), no warning (checked
  2026-10-05). The file step uses a local variable.
- A code cell that moves within its lesson (cells inserted before it) or
  gets a new starter opens with its starter: the learner's saved version
  stays in storage under the old index or fingerprint, unused (HANDOVER
  §6a, §3). It could follow its cell: when a lesson renders, a cell with
  nothing saved could take a key of the same lesson with its fingerprint
  whose own index now holds another cell.
- No CI runs the tests (`.github/workflows/` has only the gem release).
  When a tests workflow exists, run `ruby test/lint_lessons.rb
  --base=origin/${{ github.base_ref || 'main' }}` in it, with
  `fetch-depth: 0` (`experiments/07-lesson-linter/NOTES.md`, "Wiring it
  in", step 3).
- Found by the experiments, in today's code (details in their `NOTES.md`):
  the live-run tracer makes code about 36x slower in ruby.wasm, so a cell
  looping over ~100k elements hits the 1 s limit (a lesson can now say
  `"live": false`, HANDOVER §6b - the music lesson does; a cheaper tracer,
  `experiments/05-ruby-music/NOTES.md` option 3, would help every cell);
  once any time-limit tracer has been on, plain runs stay
  about 40% slower for the rest of the visit (#11); every cell is evaluated
  as `chunky.rb`, so an error in a method from an earlier cell reports that
  cell's line numbers (#7, #5). The friendly error explanations (#4,
  `html/friendly_errors.rb`) work around it by checking that the line in
  the current cell looks right before quoting it; evaluating each cell as
  `chunky-<idx>.rb` would fix it for both (touches `error_line`,
  `AutoRun`'s paths, `EVAL_FILE`, the explanations' `file:`).
- Friendly errors, after integrating #4: the corpus was written alongside
  the rules, so replaying real failing cells (live-run rehearsals produce
  plenty) would show what they miss; the heuristics are line-based
  (multi-line expressions, heredocs, `%w[]` fall through to the generic
  syntax message); per-lesson hints (`tl-pattern`: name the missing
  `in` branch) and a "Chunky says" line from the headline are ideas in
  `experiments/04-friendly-errors/NOTES.md`.
- Accessibility, after integrating the audit (`experiments/10-accessibility`,
  "Integrated"): the letter (Rumale) is pointer-only - a typed-digits
  fallback would make it keyboard-usable; Run buttons still turn
  `disabled` while running (`aria-disabled` would keep the focus and read
  "running …", but needs the tests' `.disabled` checks changed); the
  loading screen's tab title is German under `?lang=ja`; no real screen
  reader (NVDA, VoiceOver) has been tried. `keyboard.mjs` still reports
  four FAILs that are its own assumptions (Tab indenting, no Enter on the
  skip link, a live `.cell-out`, the first Tab opening the drawer) -
  worth updating if the audit is rerun.
- Turtle graphics (lesson 10, `html/turtle.rb`): `forward 100` outside
  `turtle { }` is a plain NoMethodError for main, which the friendly
  errors explain as "defined in another cell? run that one first" - a
  rule for the turtle's commands (`forward`, `right`, `pen_up` …) saying
  "only inside `turtle do … end`" would fit (`friendly_errors_rules.rb`,
  before `name_lower`; a corpus entry needs the harness to require
  turtle.rb). Defining the commands on main was rejected: it would
  shadow a learner's own `def right`. More exercises the check helpers
  already grade are listed in `experiments/06-turtle-graphics/NOTES.md`
  (a house without lifting the pen, a 7-point star, a spiral); `fill`
  and `write "text"` are not there yet.
- Music (lesson 37, `show_audio`): the lesson's "on your machine" box
  names the `wavefile` gem (pure Ruby, `install_gem "wavefile"`), which is
  not in the gem cache: it installs through the rubygems proxy and writes
  a WAV that `show_audio` plays (checked 2026-10-06), but fails offline -
  `tools/build_gem_cache.rb` `GEMS` + THIRD_PARTY_NOTICES would fix that
  (`experiments/05-ruby-music/NOTES.md`, step 7). The lesson has no
  exercise on `audios` yet (a check can read what was played without a
  file), and `music.rb`'s `C4*2` durations and sharps were left out.
- Games (lesson 38, `show_game`, `html/game.rb`/`game.js`): `:chunky` is
  the 🦊 emoji, and emoji look different on every system (headless
  Chromium draws 🥓 as a small red glyph) - a head-only Chunky sprite and
  a sprite sheet in `assets/` (`"img:url"` looks work already) would make
  the grid the same everywhere. Not tried: the workshop (same path, the
  guard watches `Workshop.paths`) and a real screen reader on the game
  (its name, description and live region are checked in browser_test).
  Two arrow keys within one round can still turn Chunky straight back
  (the classic Snake bug; a queue of turns would fix it). `on_click` has
  no lesson cell yet.
- Stepping through a cell (⏯, lessons 3-12, `html/step_recorder.rb`,
  `html/stepper.js`): no lesson text mentions ⏯ yet - a sentence in
  schleifen's prose ("watch the loop with ⏯") would point learners at it.
  Past ~200 steps the slider moves in slivers; the experiment's tick
  strip, grouped by passes, was left out. Steps are lines, not
  expressions (a one-line block shares its line; `_1`/`it` show no
  variables); the "assigned" detection is a regex (Prism would be exact).
  Not in the workshop (each `require_relative`'d file would need its own
  `:script_compiled` match). No real screen reader tried on the slider
  and its live region.
- The embedded cell (`html/embed.html`, HANDOVER §6k): three.js, Python,
  SQLite, exercise checks and live runs are not wired up (copies of
  `index.html`'s `ensure*`); gems outside the cache and `Net::HTTP` do not
  work in it, as a sandboxed page sends no Referer and the bridges refuse
  it - opening them to `Origin: null` would open them to every sandboxed
  frame. Tested in Chromium only (Firefox and WebKit: the sandbox, the
  missing Referer, `frame-ancestors`). Once chunkybacon.idogawa.com is
  live: check that the host's reverse proxy passes `Host` on (else every
  bridge request is 403), pin the bridge map to the domain (HANDOVER §7),
  and try an embed from a real idogawa.com page. An "Open in the
  workshop" link would need the course to import code from a fragment.
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
