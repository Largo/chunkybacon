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

- PR #2 (branch `sequel-lesson`: the Sequel lesson, lesson 28, and SQLite
  databases in files - HANDOVER §6f) was merged into `main` on 2026-10-05
  (`4ebafb7`). The site is deployed from it.
- PR #3 (branch `worktree-tty-processing-faker-erb-lessons`) adds four side
  trips after Scarpe: 30 TTY, 31 Processing, 32 Faker, 33 ERB + Herb (50
  lessons; HANDOVER §6g-§6j). It was branched from `a30d2b0` and rebased
  onto `main` on 2026-10-05: one commit per lesson as before, each
  inserting its lesson into main's `lessons.js` with the
  `tmp/insert_lesson.js` renumbering (the PR's numbers from 28 on moved up
  by one for Sequel; its handover sections 6f-6i became 6g-6j), then one
  commit with the lesson linter's findings, the offline sizes and this
  file. Both sides of the gem cache, the offline file list,
  `.gitattributes`, `compress_assets.rb` and the notices are kept.
  `TopLevel.binding` (each lesson its own top-level scope) works with the
  Sequel lesson: `DB = Sequel.sqlite` and a re-run of it, the file step,
  and Sequel after a lesson that switched `using Processing` on.
- Verified 2026-10-05 on this machine: `check_harness.rb` (50 lessons x
  de/en/ja), `gems_harness.rb`, shell tests (150 runs), `autorun_test.rb`,
  `server_test.rb`, `ansi_test.rb`, `offline_files.rb --check`,
  `compress_assets.rb --check`, and `browser_test.mjs`, `live_test.mjs`,
  `offline_test.mjs`, `progress_test.mjs`, `language_test.mjs`,
  `boot_failure_test.mjs` - all OK. Not run: `permalink_test.mjs` (needs
  the optional Puma server).
- [ ] Review and merge PR #3. Merging into `main` deploys the site
  (HANDOVER §1).
- Other sessions work in git worktrees under `.claude/worktrees/` (on
  2026-10-05: `improve-lessons` and `tty-processing-faker-erb-lessons`
  locked, i.e. in use; `ocran-lesson`; `rumale-lesson`; `ideas`, whose
  untracked `experiments/` holds the lesson linter). `ocran-lesson` also
  inserts a lesson right after Scarpe, so it conflicts with PR #3 in
  `html/lessons.js`, the count tests, README and HANDOVER: rebase it onto
  `main` once PR #3 is in and re-run the `tmp/insert_lesson.js`-style
  renumbering rather than hand-merging. (`git` also warns that it cannot
  delete `.git/worktrees/agent-a88082be1e674fa38`, a stale entry - harmless.)

## Smaller open ends found on the way

- A re-run of a cell with `DB = Sequel.sqlite` reassigns a constant; the
  cell shows only its result (`=> [:eintraege]`), no warning (checked
  2026-10-05). The file step uses a local variable.
- The lesson linter (`experiments/07-lesson-linter/lint_lessons.rb` in the
  `ideas` worktree, not in git) still warns, as on `main`: `rubykaigi` [ja]
  cells 1 and 7 end in plain form (perhaps on purpose - a talk's
  punchline), and `sequel` [de] cell 5 has a 102-column line. Decide, then
  fix or accept. Its `--base=origin/main` run finds every lesson reference
  pointing at the same lesson as on `main`.
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
