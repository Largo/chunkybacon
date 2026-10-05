# 07 - Lesson linter

`lint_lessons.rb` is a content linter for `html/lessons.js`. It covers what
`test/check_harness.rb` does not check (the harness only checks that a
starter fails and its solutions pass). It is plain Ruby with no gems: Prism,
JSON and `Gem::Package` come with Ruby 3.4/4.0. It reads `lessons.js`
directly, taking the JSON out of `JSON.stringify(...)`, so it needs neither
node nor `test/lessons.json`. Every finding names the lesson id, language
and cell, plus the line in `lessons.js`. A full run takes about 2.5 s.

```sh
ruby experiments/07-lesson-linter/lint_lessons.rb               # errors + warnings
ruby experiments/07-lesson-linter/lint_lessons.rb --verbose     # + info, keys, the reference table
ruby experiments/07-lesson-linter/lint_lessons.rb --only=refs,ja
ruby experiments/07-lesson-linter/lint_lessons.rb --base=origin/main  # exact renumbering check
ruby experiments/07-lesson-linter/lint_lessons.rb --net         # + HEAD every external link
ruby experiments/07-lesson-linter/lint_lessons.rb --json
ruby experiments/07-lesson-linter/lint_lessons.rb --root=../other-worktree
ruby experiments/07-lesson-linter/lint_lessons_test.rb          # 24 fault-injection tests
```

The exit status is 1 when there is an ERROR that `allow.txt` does not accept.
`allow.txt` holds one key glob per line; `--verbose` prints each finding's
key, e.g. `long-line@tl-capstone[de]cell3@L14`.

## Checks

| group | what | severity |
|---|---|---|
| structure | duplicate ids; a language missing; the title number differs from the position; unknown keys/cell types; required fields; exactly one `x` cell and one `div.task` per lesson; `section` in all languages; `files:` exist; every id has a `SOLUTIONS` entry in check_harness.rb (or is in `BROWSER_ONLY`), and no stale entries | E/W |
| parity: ui | a key present in all three languages; same type; arrays the same length; **format placeholders** (`%s`, `%{x}`) the same; HTML tags the same; ja/de left equal to en | E/W |
| parity: lessons | same cell type sequence; **ja code equals en code once comments are stripped** (Prism comment locations); **ja `check` byte-identical**; English comments left untranslated in ja/de code (commented-out code is ignored); de code shape (line count) and number literals compared with en; block structure per cell (`div.task`, `div.offweb`, `pre`, `table`, `img`, `h2/h3`; `p`/`li` as info); link targets per cell (`/deed.ja` and other language segments count as one URL; the same sites with different pages are only info); `<pre>` blocks en/ja; **inline `<code>` spans en vs ja** (a Japanese placeholder like `sp.solve(式, x)` matches `sp.solve(expression, x)`); de spans that are language-neutral (info); `install_gem`/`require` lists the same in all languages | E/W/I |
| html | balanced tags; **unknown tags** (`Array<String>` in prose would disappear); a legacy entity without `;` (`&not_found` shows as `¬_found`); raw `<` / `&` (info) | E/I |
| refs | "Lektion N" / "lesson N" / "レッスンN" (prose, hints, code comments) within 1..count; the same references in all three languages per cell; **context check**: a lesson name right next to the number (within 30 chars) that belongs to another lesson ("Roda from lesson 15") is suspect. Lesson names are title words that appear in at least two languages' titles and are rare in the course text. `--verbose` prints a table of all references as *confirmed* (the sentence names the target), *confirmed by content* (shares a rare word/identifier with the target) or *unverified*. `--base=GITREF` maps every reference through the old numbering (`git show REF:html/lessons.js`, read-only), so a reference that meant lesson X and now points elsewhere is an ERROR. This is exact and needs no heuristics. Also `#id`/`/de/id` links in lessons and docs | E/W/I |
| ja | です・ます in Japanese prose: sentences that end in a plain form. Skipped: list items, headings, parenthesised asides, noun endings, numbered steps, enumerations. Hints that use です/ます (info: hints are Chunky, casual); German left in en/ja prose; English sentences left in ja prose; task/offweb labels consistent per language; ja titles equal to en | W/I |
| ruby | every `code` and `check` parses with Prism. Locals from earlier cells are passed as scopes, so `x -1` is judged as in the notebook, and checks get `output result code images downloads`. Prism warnings (the `ruby -w` parse warnings; "assigned but unused" is dropped because the notebook shows the value); line width in display columns, with CJK counted double: info above 76 (cells do not wrap, and the 44rem column at 15px mono shows about 76), warn above 100; `<pre>` blocks that look like Ruby (info); tabs, trailing spaces | E/W/I |
| gems | every `install_gem` name is in `html/gems/cache/manifest.json` (or a substitute); native gems; manifest files exist, deps are cached (native, stand-in and optional deps are skipped), and no orphan `.gem` files; **`require` of a feature that a cached gem provides** (index built from each `.gem`'s file list) without an earlier `install_gem` in the lesson, when `auto_install_feature` would not cover it (`require "shoes"` needs `install_gem "lacci"`) | E/W |
| counts | "N lessons / Lektionen / レッスン" in README, docs, tests, index.html, shell, server and ui strings against the real count; "N lessons × 3"; section ranges in the docs ("side trips, 19-30") against the `section` boundaries | E/W |
| links | relative links in prose exist under `html/`; with `--net`, HEAD on every external URL (GET with a range when HEAD is refused) | E/W |

`lint_lessons_test.rb` breaks a copy of the real lessons.js once per test,
then asserts that the linter notices. It covers ja code/check drift, title
numbers, ui keys/placeholders, cell sequences, references (range, parity,
context, a lesson inserted without fixing references, `--base` exact and
with correct renumbering), unbalanced/unknown tags, syntax errors/warnings,
locals across cells, uncached gems, require-before-install, the Japanese
rules, untranslated comments, code spans, links, ui counts, task blocks and
the de drift signals. A baseline test checks that the real file has no
unexpected ERROR. `demo_renumber.rb` shows the renumbering scenario.

## Real issues found

In this worktree (`worktree-ideas`, 46 lessons):

1. **`tl-cli` [de] cell 2: a stray `</div>`** (`lessons.js:5514`). The
   paragraph after the OptionParser demo ends in `</p></div>`; en/ja end in
   `</p>`. It looks like a leftover from moving the offweb box into the next
   cell. Browsers drop it in innerHTML, but it is wrong. It is also present
   in the `ocran-lesson`, `improve-lessons` and `tty-processing-faker-erb-lessons`
   worktrees. Fix: delete `</div>` at the end of that html string.
2. **`docs/PICORUBY_SHELL.md:510` says "ALL CHECKS OK (37 lessons × de, en, ja)"**.
   There are 46.
3. **ja style, `rubykaigi` [ja] cell 1 and 7**: "…とびきり変なコードも書ける。"
   and "遅いけれど美しい。" are plain form in です・ます prose. They may be
   deliberate (a talk's punchline). Decide, then fix or add to allow.txt.
4. Long code lines: `sequel` [de] cell 5 line 2 is 102 columns (the `puts`
   with `"Fr."`). 68 more lines are 77-100 columns and scroll sideways in a
   cell (info).

Clean, which is worth knowing: all 46 lessons have identical cell sequences
in de/en/ja. ja code equals en apart from comments, and every ja check is
byte-identical. ui keys and placeholders match. All 39 lesson references are
in range, the same in all three languages, and correct: 27 confirmed
mechanically, the other 12 checked by hand. All external links answer (`--net`,
2026-10-05). No Prism errors or warnings in any cell or check. Every
`install_gem` is in the cache. `--base=HEAD~3` (before the Rumale and Sequel
lessons) shows 18 lessons renumbered and no stale reference, so those two
insertions updated their references correctly.

In the sibling worktrees, read-only with `--root` (they are other branches,
not fixed here):

- `tty-processing-faker-erb-lessons`: **`faker` [ja] cell 5 runs different
  code than en** (`Faker::Config.locale = "ja"` vs `"en-AU"`). That breaks
  "ja runs the English code" and the harness assumption that ja passes with
  en's solutions. Either keep en's locale, or document the exception and
  allow it. Also stale counts: `docs/OPEN_WORK.md:73,74,80` say 46 lessons
  (48), and `docs/HANDOVER.md:193` gives side trips as 19-31 where
  lessons.js has 19-32.
- `improve-lessons` (49 lessons): README, HANDOVER and `test/browser_test.mjs:44`
  say **45 lessons**. HANDOVER:188 gives side trips as 19-29, the file has
  23-33. The `fehler` cell 15 code does not parse in all three languages
  (probably an intentional SyntaxError demo, so allow-list it). The `doku`
  [ja] code spans quote the Japanese reference manual's signatures
  (`each_slice(n) -> Enumerator`), which is intentional. `module` [ja]
  cell 9 has an extra `<=>` span and "Enumerable はレッスン9…": check
  whether lesson 9 (now iterators) is meant.

## False positives remaining

- `plain-form` stays a heuristic. Quoted speech without 「」 and plain-form
  instructions inside prose paragraphs are flagged (in improve-lessons:
  "犬は動物である。", "示された場所を直す。"). Expect one or two per new
  lesson; allow-list them by key.
- `ref-context` can flag a sentence where a lesson's name sits next to a
  reference on purpose ("Enumerable … lesson 9" when lesson 9 also teaches
  Enumerable). `--base` is the reliable check for renumbering; the
  heuristic is for when no base is at hand.
- `untranslated-comment` uses an English stop-word count and skips
  anything that looks like code. A short English comment (fewer than 4
  words) slips through.
- `code-spans-ja` is right to flag ja spans that quote Japanese docs, but
  those are intentional (allow-list them).
- Info-level noise (hidden without `--verbose`): `raw-amp` for `&block` in
  code spans, `raw-lt` for `a < b`, `pre-syntax` for directory trees and
  log samples, `long-line` from 77 to 100 columns.

## Wiring it in (proposed; shared files not edited)

1. Move `lint_lessons.rb` to `test/lint_lessons.rb`, `allow.txt` to
   `test/lint_allow.txt` (change the default `--allow` path) and the tests
   to `test/lint_lessons_test.rb`. The root default (`../..` from
   `__dir__`) becomes `..`: change
   `File.expand_path("../..", __dir__)` to `File.expand_path("..", __dir__)`
   in `main` and in the test's `ROOT`.
2. README "Tests" block, after `ruby check_harness.rb`:
   ```
   ruby lint_lessons.rb      # lessons.js content: de/en/ja parity, references, Japanese rules, Prism, gems, counts
   ```
   HANDOVER §3, add to "Rules that the code and tests rely on":
   "`test/lint_lessons.rb` checks the mechanical half of these rules; after
   inserting a lesson run it with `--base=main` - every reference that now
   points at a different lesson is an error."
   HANDOVER §8: the same line as in README.
3. CI: run it in the existing tests workflow, before the harness (it needs
   no node and no lessons.json):
   ```yaml
   - name: Lesson lint
     run: ruby test/lint_lessons.rb --base=origin/${{ github.base_ref || 'main' }}
   ```
   (with `fetch-depth: 0`, so that the base revision exists). Only ERRORs fail
   the job, so warnings do not block a merge but show up in the log.
   `--net` should not run on every push; a weekly job is enough.
4. Fix `tl-cli` [de] cell 2 (`</div>`) and `docs/PICORUBY_SHELL.md:510`
   first; then the baseline test can drop its one exception.
5. For the lesson generators in `tmp/`: run the linter after
   `insert_lesson.js` with `--base=HEAD`. That replaces checking "lesson N"
   references by hand when merging worktrees (OPEN_WORK).

The ruby.wasm Ruby may be older than the Prism in the CI Ruby. If a
syntax-version difference ever matters, pass
`version: "3.4"` to `Prism.parse` in `check_ruby`.

## Files

- `lint_lessons.rb` - the linter (modules `Text`, `Source`, `GemCache`, `Linter`, `Report`)
- `lint_lessons_test.rb` - fault-injection tests (Minitest)
- `allow.txt` - accepted findings
- `demo_renumber.rb` - inserts a lesson without fixing references and shows what is caught
