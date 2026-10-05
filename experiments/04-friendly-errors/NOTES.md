# 04 – Friendly error explanations (de / en / ja)

**Integrated.** The three Ruby files now live in `html/`
(`friendly_errors.rb`, `_rules.rb`, `_messages.rb`), the CSS in
`html/assets/app.css` (classes renamed `friendly-title`, `-snippet`,
`-body`, `-original`, `-brief`: `.fe-title` was already the file
explorer's), and the corpus in `test/` as `friendly_errors_corpus.rb`,
`friendly_errors_harness.rb` (was `run_corpus.rb`, without `--html`;
exits 1 on a MISS) and `friendly_errors_robustness.rb` (README "Tests",
HANDOVER §6 and §8). Steps 1-5 of "Integration into html/main.rb" are done,
with these differences: the kernel cannot `require_relative` while a cell
runs, so `ChunkyApp#friendly_error` fetches and evals the three files like
`shoes_dom.rb` (and `offline.js` preloads them for the offline copy); a
run the time limit stopped shows the old hint *and* the full explanation
below it; an error inside another workshop file keeps Ruby's message with
its location; `#runStatus` reads only the headline. Tested in ruby.wasm in
the browser: the one difference was that Prism there **colours** a
SyntaxError's code frame with ANSI codes, so the diagnostics were not
found and missing `end`s and unclosed strings fell to the generic message -
`Context#message` strips them now, and the harness replays every syntax
error with the colours. Everything else probed (typo, argument count,
`6 x 7`, String + Integer, endless loop, de/en/ja) matched the CRuby output;
explain takes 0-30 ms there, loading the files ~55 ms. The
"all cells are `chunky.rb`" limit stays (`docs/OPEN_WORK.md`).
`preview.html`/`.png` and `tools/` stay here as the record; paths below are
the experiment's.

When a cell fails, the learner gets a short, kind explanation in the lesson's
language, plus a pointer into their own code (Elm/Rust style), instead of only
Ruby's `NoMethodError: undefined method 'upcase' for nil`. Ruby's own message
is still there, folded away under "Ruby's message".

```
-- `fox["name"]` is nil ------------------------------------------------

  1 | fox = { name: "Chunky", food: "bacon" }
> 2 | fox["name"].upcase
    | ^^^^^^^^^^^ this is nil

The hash `fox` has no key "name", so `fox["name"]` gives nil – and nil has
no method `upcase`. Its keys are symbols (:name, :food) – write `fox[:name]`
instead of `fox["name"]`.
```

## Files

| File | What it is |
|---|---|
| `friendly_errors.rb` | `FriendlyErrors.explain(error, source:, lang:, file:, binding:)` → `Result` (or nil); `Result#to_text`, `#to_html(brief:)`; the `Context` the rules use (source scanning, snippet with caret) |
| `friendly_errors_rules.rb` | the rule table (ordered, first match wins), 44 rules |
| `friendly_errors_messages.rb` | all texts, de/en/ja: first line = headline, rest = explanation |
| `friendly_errors.css` | proposed addition to `html/assets/app.css` |
| `corpus.rb` | 70 realistic beginner mistakes, mined from the exercises in `html/lessons.js` (lesson id per entry) |
| `run_corpus.rb` | runs each like a notebook cell, prints all 3 languages + coverage table; `--lang ja`, `--only <id>`, `--summary`, `--html` (writes `preview.html`) |
| `robustness_check.rb` | 350 `explain` calls with wrong sources, odd languages, other file names: must never raise or leave a `%{…}` |
| `preview.html`, `preview.png` | the corpus as it would look on the page (4 columns: code, de, en, ja) |
| `tools/` | `dump_exercises.rb` (lists lesson exercises), `probe*.rb` (what Ruby 4.0 / Prism report), `serve_preview.rb` (port 18104) |

Run: `ruby experiments/04-friendly-errors/run_corpus.rb` (also works with
`ruby --disable-did_you_mean …`, see below).

## Design

- **Rule table.** `rule :name, *exception_classes do |ctx| … end`. A block
  returns nil ("not mine") or `find(:message_key, {vars}, at: [line, col, len],
  label: :lbl_nil)`. Order matters: specific before generic (e.g. `else if`
  before "missing end", `str_numeric` before `str_plus`, `syn_generic` last).
  A rule that raises is skipped; `explain` itself rescues everything and
  returns nil, so the cell falls back to today's output.
- **Texts separate from logic** (`MESSAGES[key][lang]`, `%{var}` with
  `format`). Backticks become `<code>`. German uses "du" like the course,
  Japanese is です・ます (the page speaking, not Chunky). Small word tables for
  plurals ("1 argument" / "2 Argumente" / "引数2個") and lists ("a, b and c" /
  "a、b、c").
- **Where's the culprit.** The line comes from the error's backtrace frames
  in the cell's file (`chunky.rb`); the column from small scanners: the
  receiver expression before `.meth` (balanced `()[]{}` and quotes, so
  `projects.find { … }.upcase` underlines the whole `find {…}`), `x[...]`, or
  an operator. Syntax errors: Prism's own diagnostics are parsed **from the
  SyntaxError message** (`> 3 | code` / `| ^~~ text`), so no `require "prism"`
  is needed in ruby.wasm; plus a tokenizer for unclosed strings/brackets/`#{`
  and an indentation heuristic for `end`s, which finds the *real* opener
  (`class Fox … def shout` without end → "the `def` on line 6", where Prism
  blames the `class`).
- **Values, read only.** With `binding:` the rules may `local_variable_get`
  a plain identifier (hash keys, `"7"` stored as text) – never `eval`. Without
  a binding they fall back to the literal in the cell (`fox = { name: … }`).
- **did_you_mean optional.** Uses `error.corrections` when present, else an
  own Damerau–Levenshtein over locals, defs, params, constants, the
  receiver's methods. The corpus scores the same with `--disable-did_you_mean`.
- **Unknown errors stay Ruby's.** `RuntimeError` from the learner's own
  `raise "…"`, `JSON::ParserError` etc. get no explanation (nil) on purpose.

### What it covers

| Area | Rules / cases |
|---|---|
| SyntaxError | unclosed string, unclosed `#{`, missing `end` (finds the opener), extra `end`, missing `) ] }`, missing comma, missing `\|`, `else if`, `class fox`, `if … {`, `= >`, Python `:` / `for i in range()`, `x++`, `6 x 7`, generic fallback quoting Prism |
| NameError | typo (did_you_mean or own), used before assigned, outer local inside `def`, method called before its `def`, `True/None/null`, `elseif/elif`, constant typo (`Fxo`→`Fox`), constant not defined / "put it in quotes" / "run the other cell", `Name` vs `name` |
| NoMethodError on nil | missing hash key (lists keys; `fox["name"]` vs symbol keys), index past the end, `hours[k] += 1` on `{}` → `Hash.new(0)`, `@nmae` typo, `x = puts …`, `x = list.uniq!`, `match` returned nil, `find` found nothing, generic |
| NoMethodError other | method of another type (`["a"].upcase` → `map(&:upcase)`, `5.upcase` → `to_s`), missing `attr_reader`, method typo (`lenght`), `Puts` |
| ArgumentError | wrong number of args (method, `Class.new`/initialize, lambda), positional instead of keywords, missing/unknown keyword (lists the def's keywords), `Integer("08:30")`, comparison of mixed types |
| TypeError | String + Integer (interpolation / `to_s`), `"7"` stored as text (`to_i`), Integer + String, nil operand, `array[:key]` on an array of hashes |
| Others | ZeroDivisionError (empty list → `return 0 if list.empty?`), FrozenError, NoMatchingPatternError (add `else`), KeyError (`fetch`, lists keys), IndexError, SystemStackError (recursion without base case), LoadError, own exception class not rescued, **AutoRun::Stopped** (live-run time limit): only when a loop looks endless – `while i < 5` whose `i` never changes, `loop do` without `break` |

## Coverage over the corpus

`run_corpus.rb --summary`: **70 cases, 68 explained, 70 as expected** (the two
unexplained ones are the intended nils: a JSON parse error and the learner's
own `raise "…"`). Same result without did_you_mean. Robustness check: 350
calls, 0 problems. Both scripts exit 1 when a check fails.

Honest caveats: the corpus was written alongside the rules, so 100 % here
says the rules do what they were built for, not that they generalize. I read
every explanation in all three languages and fixed the misleading ones
(e.g. `animal[:age] + 1` was briefly told to use `Hash.new(0)`). The next
step is to replay real failing cells (see "Next").

## Sample outputs

German – missing `end`, opener found by indentation (Prism would blame `class`):

```
-- Hier fehlt ein `end` ------------------------------------------------

> 6 |   def shout
    |   ^^^ hier geöffnet

Das `def` in Zeile 6 ist noch offen – Ruby ist am Ende der Zelle angekommen,
ohne sein `end` zu finden. Jedes `def`, `class`, `if`, `do` … braucht sein
eigenes `end`.
```

Japanese – summing into an empty hash:

```
-- 最初は `hours[e[:project]]` が nil です -----------------------------------

  1 | hours = {}
> 2 | entries.each { |e| hours[e[:project]] += e[:hours] }
    |                    ^^^^^^^^^^^^^^^^^^ ここが nil です

空のハッシュは、新しいキーに対して nil を返します。nil に `+` は使えません。ハッシュに初期値を指定してください: `hours = Hash.new(0)`。
```

English – a live run stopped by the time limit:

```
-- This loop may never stop --------------------------------------------

  1 | i = 0
> 2 | while i < 5
    |       ^ never changes

The `while` loop on line 2 checks `i`, but `i` never changes inside it. With
▶ it would run until the page freezes – update `i` inside the loop, e.g.
`i += 1`.
```

English – keywords passed positionally (lesson 33):

```
-- `add_entry` wants keywords, not bare values -------------------------

> 5 | add_entry("X", "08:30", "10:00")
    | ^^^^^^^^^ this call

`add_entry` takes `project:`, `from:` and `to:` – by name. Write:
`add_entry(project: …, from: …, to: …)`.
```

All 70 × 3: `ruby experiments/04-friendly-errors/run_corpus.rb`, or open
`preview.html`.

## Integration into html/main.rb (proposed, not applied)

1. Copy `friendly_errors.rb`, `friendly_errors_rules.rb`,
   `friendly_errors_messages.rb` to `html/`. Add the three to
   `html/offline-files.txt` (`ruby tools/offline_files.rb`). Append
   `friendly_errors.css` to `html/assets/app.css`.
2. Load it lazily – it's ~90 KB of source (mostly the three languages' texts)
   and only needed once something fails. In `ChunkyApp`:

   ```ruby
   # the friendly explanation of a cell's error (friendly_errors.rb), loaded
   # on the first error; nil when there is none or loading fails
   def friendly_error(error, code, file, auto)
     return nil if error.is_a?(AutoRun::NeedsRun)

     unless defined?(FriendlyErrors)
       AutoRun.untraced { require_relative "friendly_errors" }
     end
     FriendlyErrors.explain(error, source: code, lang: @lang, file: file, binding: @bind)
   rescue StandardError, ScriptError
     nil
   end
   ```

3. In `run_cell`, the `if (hint = live_hint(error)) … elsif error` branch:

   ```diff
   -    if (hint = live_hint(error))
   +    friendly = error && friendly_error(error, code, file, auto)
   +    if friendly
   +      # a live run while typing shows just the headline; an endless loop all of it
   +      out_html += friendly.to_html(brief: auto && !error.is_a?(AutoRun::Stopped))
   +    elsif (hint = live_hint(error))
          out_html += "<div class=\"cell-hint\">#{escape_html(hint)}</div>"
        elsif error
          out_html += "<div class=\"cell-error\">…</div>"   # unchanged fallback
   ```

   `error_line`/`markCellLine` stay as they are (they already mark the line
   in the editor); `Result#line` could replace `error_line` later.
4. Workshop: `file` is the open file's path, `source` its code – works as is;
   errors from another project file just get no snippet (frames are matched
   by file name).
5. Tests: move `corpus.rb` + `run_corpus.rb --summary` into `test/` as a
   harness (exit 1 on a MISS), like `check_harness.rb`.

## Known limits / next

- **All cells share the file name `chunky.rb`.** A method defined in an
  earlier cell reports *that* cell's line numbers, which the rules then look
  up in the current cell's source. The rules check the line looks right
  (e.g. `def name` on that line) before quoting it, but a cleaner fix is to
  eval each cell as `chunky-<idx>.rb` (touches `error_line`, `AutoRun`'s path
  list, `EVAL_FILE`).
- ruby.wasm not tested in the browser yet: the module is plain Ruby 4.0 and
  doesn't need Prism, did_you_mean or error_highlight, but the message format
  of SyntaxErrors (Prism's) should be confirmed in the wasm build once.
- Japanese is wrapped by the browser only; the terminal output does not
  wrap it. In `preview.html` the Japanese snippet uses a proportional fallback
  font (the real page's `:lang(ja)` code font is monospace).
- Heuristics are line-based: multi-line expressions, heredocs, `%w[]` and
  regexps with brackets can confuse the bracket scanner (it then falls
  through to the generic syntax message, which is still correct).
- Ideas: replay real failing cells (the live-run rehearsals produce plenty)
  to grow the corpus; a "Chunky says" one-liner in the bubble using the
  headline; per-lesson hints (e.g. lesson 41 pattern matching → name the
  missing `in` branch).

Note for the coordinator: Playwright MCP wrote its page snapshot/console log
to `.playwright-mcp/` in the **main checkout's root** (outside this worktree,
not gitignored there) – safe to delete.
