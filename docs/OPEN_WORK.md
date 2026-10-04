# Open work

What is unfinished, what state it is in, and where the context for it lives.
`docs/HANDOVER.md` explains how everything works; this file lists what is in
flight. Keep it short and current: tick items off, delete finished sections.

Last updated 2026-10-04.

## Where the context is defined

| What | Where |
|---|---|
| What the site is, its features | `README.md` |
| How it works, where the traps are | `docs/HANDOVER.md` - §2 layout, §3 lessons (format, renumbering, the Japanese rules), §4 gems and the pure stand-ins, §6a workshop and storage, §6b live runs, §6c offline mode, §6d Python, §6e Rumale, §6f SQLite and Sequel (databases in files too), §8 tests, §11 older open ends |
| The page shell on PicoRuby, its portability rules | `docs/PICORUBY_SHELL.md`, `test/shell/portability_test.rb` |
| Every bundled component and its licence | `THIRD_PARTY_NOTICES.md` |
| All lesson text, code, checks and UI strings | `html/lessons.js` - the source of truth |
| Lesson generators (scratch, **not in git**) | `tmp/*_lesson.rb` (pycall_lesson_v2, sympy, numpy, sklearn, sequel) write `tmp/<id>_lesson.json`; `tmp/insert_lesson.js` inserts and renumbers, `tmp/replace_lesson.js` swaps one lesson. A hand edit to `lessons.js` is lost if a generator runs again - edit the generator too, or only `lessons.js` |
| Local Playwright helper (scratch, **not in git**) | `tmp/playwright_redirect.mjs` + `tmp/playwright_resolve_hook.mjs` (see "Working on this machine") |
| Hosting details | `docs/HOSTING.local.md` - local only, excluded from git |

## State of the repository

- Branch `sequel-lesson` (from `a30d2b0`, the Rumale lesson) holds two
  commits, in a PR against `main`:
  1. the Sequel lesson and the sqlite3 stand-in over sql.js;
  2. SQLite databases in files - `Sequel.sqlite("timelog.db")` is a real
     SQLite file: a download in a lesson, kept with the project in the
     workshop; lesson 28's step "keep it in a file". HANDOVER §6f.
- Verified 2026-10-04 on this machine: shell tests, `check_harness.rb`,
  `autorun_test.rb`, `server_test.rb`, `offline_files.rb --check`,
  `browser_test.mjs`, `live_test.mjs`, `offline_test.mjs`. A database the
  browser wrote opens with the real sqlite3 gem (`PRAGMA integrity_check`
  ok).
- [ ] Merge the PR. Merging into `main` deploys the site (HANDOVER §1).
- Other sessions work in git worktrees under `.claude/worktrees/` (on
  2026-10-04: `improve-lessons` and `tty-processing-faker-erb-lessons`,
  both locked, i.e. in use; `ocran-lesson`; `rumale-lesson`), branched from
  `a30d2b0` or earlier. New lessons there renumber `html/lessons.js` too, so
  expect conflicts in titles, "lesson N" references and the lesson counts in
  the tests: merge one at a time and re-run `tmp/insert_lesson.js`-style
  renumbering rather than hand-merging. (`git` also warns that it cannot
  delete `.git/worktrees/agent-a88082be1e674fa38`, a stale entry - harmless.)

## Smaller open ends found on the way

- A re-run of a cell with `DB = Sequel.sqlite` reassigns a constant; not
  checked what the cell shows for Ruby's warning. (The file step uses a
  local variable, so it has no such warning.)
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
