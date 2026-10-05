# Open work

What is unfinished, what state it is in, and where the context for it lives.
`docs/HANDOVER.md` explains how everything works; this file lists what is in
flight. Keep it short and current: tick items off, delete finished sections.

Last updated 2026-10-05.

## Where the context is defined

| What | Where |
|---|---|
| What the site is, its features | `README.md` |
| How it works, where the traps are | `docs/HANDOVER.md` - §2 layout, §3 lessons (format, renumbering, the Japanese rules), §4 gems and the pure stand-ins, §6a workshop and storage, §6b live runs, §6c offline mode, §6d Python, §6e Rumale, §6f SQLite and Sequel (databases in files too), §6g TTY and terminal colours, §6h Processing, §6i Faker, §6j ERB and Herb, §8 tests, §11 older open ends |
| The page shell on PicoRuby, its portability rules | `docs/PICORUBY_SHELL.md`, `test/shell/portability_test.rb` |
| Every bundled component and its licence | `THIRD_PARTY_NOTICES.md` |
| All lesson text, code, checks and UI strings | `html/lessons.js` - the source of truth |
| Lesson generators (scratch, **not in git**) | `tmp/*_lesson.rb` (pycall_lesson_v2, sympy, numpy, sklearn, sequel) write `tmp/<id>_lesson.json`; `tmp/insert_lesson.js` inserts and renumbers, `tmp/replace_lesson.js` swaps one lesson. A hand edit to `lessons.js` is lost if a generator runs again - edit the generator too, or only `lessons.js` |
| Local Playwright helper (scratch, **not in git**) | `tmp/playwright_redirect.mjs` + `tmp/playwright_resolve_hook.mjs` (see "Working on this machine") |
| Hosting details | `docs/HOSTING.local.md` - local only, excluded from git |

## State of the repository

- `main` is deployed (2026-10-05), 50 lessons:
  - PR #2, the Sequel lesson (28) and SQLite databases in files (HANDOVER
    §6f), merged 2026-10-05 (`4ebafb7`), with the review fix that a file
    database whose write failed is written again after the next run.
  - PR #3, four side trips after Scarpe: 30 TTY, 31 Processing, 32 Faker,
    33 ERB + Herb (HANDOVER §6g-§6j), rebased onto Sequel and merged
    2026-10-05. Each lesson has its own top-level scope now
    (`TopLevel.binding`), checked with the Sequel lesson's constants.
  - Verified before the merge: `check_harness.rb` (50 lessons x de/en/ja),
    `gems_harness.rb`, shell tests, `autorun_test.rb`, `server_test.rb`,
    `ansi_test.rb`, `offline_files.rb --check`, `compress_assets.rb
    --check`, and `browser_test.mjs`, `live_test.mjs`, `offline_test.mjs`,
    `progress_test.mjs`, `language_test.mjs`, `boot_failure_test.mjs`. Not
    run: `permalink_test.mjs` (needs the optional Puma server).
  - Then three fixes the experiments found, merged 2026-10-05 together
    with this file, tested stacked on top of #3 (`browser_test.mjs`, shell
    tests):
    - #15 an SVG under a cell keeps its own size (`.cell-image` is a 160px
      pixelated thumbnail); needed by #6, #9 and #4.
    - #16 code cells: Escape, then Tab leaves the editor; editors named for
      screen readers; a focus ring (the accessibility audit's worst
      finding, WCAG 2.1.2).
    - #17 the mini browser draws the app's page in a shadow root, so a
      `<style>` it brings (Sinatra's 404 page) no longer restyles the
      course; the page's `html`/`body`/`:root` rules still style it inside
      the fake browser (HANDOVER §6).
- Open experiment PRs #4-#13: each adds only `experiments/NN-<idea>/`
  (prototype, tests, `NOTES.md` with measurements and integration steps),
  nothing under `html/`, so merging them deploys nothing. Built on
  `sequel-lesson` (46 lessons), so lesson and line numbers in their notes
  are older than `main`. #4 matplotlib charts, #5 stepping through a cell,
  #6 `show_objects`, #7 friendly error messages, #8 sound synthesis,
  #9 turtle graphics, #10 the `lessons.js` linter, #11 a game loop (Snake),
  #12 one runnable cell embedded elsewhere (with a security analysis),
  #13 the accessibility audit.
- Other sessions work in git worktrees under `.claude/worktrees/`
  (2026-10-05: `improve-lessons` and `tty-processing-faker-erb-lessons`
  locked, i.e. in use - the latter now behind `main`, its PR is merged;
  `ocran-lesson`; `rumale-lesson`; `ideas`). `ocran-lesson` inserts a
  lesson right after Scarpe, so it conflicts with `main` in
  `html/lessons.js`, the count tests, README and HANDOVER: rebase it onto
  `main` and re-run the `tmp/insert_lesson.js`-style renumbering rather
  than hand-merging. (`git` also warns that it cannot delete
  `.git/worktrees/agent-a88082be1e674fa38`, a stale entry - harmless.)

## Smaller open ends found on the way

- A re-run of a cell with `DB = Sequel.sqlite` reassigns a constant; the
  cell shows only its result (`=> [:eintraege]`), no warning (checked
  2026-10-05). The file step uses a local variable.
- The lesson linter (`experiments/07-lesson-linter/lint_lessons.rb`, PR #10,
  not on `main` yet) still warns: `rubykaigi` [ja]
  cells 1 and 7 end in plain form (perhaps on purpose - a talk's
  punchline), and `sequel` [de] cell 5 has a 102-column line. Decide, then
  fix or accept. Its `--base=origin/main` run finds every lesson reference
  pointing at the same lesson as on `main`.
- Found by the experiments, in today's code (details in their `NOTES.md`):
  the live-run tracer makes code about 36x slower in ruby.wasm, so a cell
  looping over ~100k elements hits the 1 s limit (#8 suggests a per-lesson
  `"live": false`); once any time-limit tracer has been on, plain runs stay
  about 40% slower for the rest of the visit (#11); every cell is evaluated
  as `chunky.rb`, so an error in a method from an earlier cell reports that
  cell's line numbers (#7, #5); the accessibility audit's other findings -
  no live region for results, focus lost after a run or a lesson change,
  the phone drawer not modal, no skip link, five contrasts (#13).
- The offline dialog's sizes (`offlineExplain`, README, HANDOVER §6c) are
  measured by hand: the files of `offline-files.txt` in MiB, a text file
  without a `.gz` counted gzipped. Re-measure after adding big files.
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
- Ideas discussed, not started: matplotlib for the PyCall lessons (charts
  need an SVG/PNG under the cell); PR #1's description only covers its
  first commit (merged anyway).

## Working on this machine (Windows)

- Browser tests need Playwright from the npx cache and the local redirect
  hook (both outside git):
  `PLAYWRIGHT_DIR=~/AppData/Local/npm-cache/_npx/<hash>/node_modules/playwright BASE=http://127.0.0.1:18021/ node --import ./tmp/playwright_redirect.mjs test/browser_test.mjs`
  (1.62.1 matches the installed Chromium). Worth moving the hook into
  `tools/` if it stays needed.
- Dev server: `PORT=18021 ruby tools/dev_server.rb`. Stopping it as a
  background task can leave `ruby.exe` running, and Windows lets two
  servers share a port - the old one may answer. Check with
  `Get-NetTCPConnection -LocalPort <port>`.
- `core.autocrlf` is on: vendored assets are `-text` in `.gitattributes`.
  If `tools/compress_assets.rb --check` says STALE after a checkout, delete
  the file and check it out again.
- Helper scripts are files (in `tmp/` or `tools/`), not inline `-e`
  commands - the machine runs endpoint protection.
