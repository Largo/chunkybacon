# frozen_string_literal: true

# Fault injection for lint_lessons.rb: every test breaks a copy of the real
# html/lessons.js in one way and asserts the linter notices - and the
# baseline test asserts the real file has no unexpected ERROR.
#   ruby lint_lessons_test.rb
require "minitest/autorun"
require_relative "lint_lessons"

class LessonLintTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GEMS = LessonLint::GemCache.new(ROOT)
  # the file as written: references as {{nr:id}}, titles without numbers
  BASE = LessonLint::Source.new(ROOT).raw.freeze

  def data = Marshal.load(Marshal.dump(BASE))

  # +allowed+: leave out what lint_allow.txt accepts, as the real run does
  def lint(d, only: LessonLint::GROUPS - %w[links], allowed: false)
    text = LessonLint::Source.dump(d)
    allow = allowed ? File.join(ROOT, "test", "lint_allow.txt") : nil
    findings = LessonLint::Linter.new(ROOT, allow_path: allow, text: text, gems: GEMS).run(only)
    allowed ? findings.reject(&:allowed) : findings
  end

  def lesson(d, id) = d["lessons"].find { |l| l["id"] == id }

  def cell(d, id, lang, &pick)
    lesson(d, id)[lang]["cells"].find(&pick)
  end

  def assert_finds(findings, code, where = nil)
    hit = findings.find { |f| f.code == code && (where.nil? || f.where.start_with?(where)) }
    assert hit, "expected #{code} #{where}, got: #{findings.map { |f| "#{f.code}@#{f.where}" }.uniq.first(15).join(", ")}"
    hit
  end

  def refute_finds(findings, code)
    bad = findings.select { |f| f.code == code }
    assert_empty bad, bad.map { |f| "#{f.where}: #{f.message}" }.join("\n")
  end

  def test_real_file_has_no_unexpected_errors
    f = lint(data)
    errors = f.select { |x| x.severity == "ERROR" }
    assert_empty errors, errors.map { |x| "#{x.code} #{x.where}: #{x.message}" }.join("\n")
  end

  def test_ja_code_must_equal_en
    d = data
    cell(d, "methoden", "ja") { |c| c["t"] == "c" }["code"] = "def greeting(name)\n  \"Hallo, \#{name}!\"\nend"
    assert_finds lint(d, only: %w[parity]), "ja-code", "methoden[ja]"
  end

  def test_ja_comments_may_differ
    d = data
    c = cell(d, "methoden", "ja") { |x| x["t"] == "x" }
    c["code"] = "# これはコメントです\n#{c["code"]}"
    refute_finds lint(d, only: %w[parity]), "ja-code"
  end

  def test_de_drift_signals
    d = data
    c = cell(d, "methoden", "de") { |x| x["t"] == "c" }
    c["code"] = "# Kommentar\n#{c["code"]}\n42"
    p_cell = cell(d, "methoden", "de") { |x| x["t"] == "h" }
    p_cell["html"] += "<p>Noch ein Absatz mit <code>greeting</code>.</p>"
    f = lint(d, only: %w[parity])
    assert_finds f, "comment-count", "methoden[de]"
    assert_finds f, "de-code-numbers", "methoden[de]"
    assert_finds f, "block-p", "methoden"
  end

  def test_ja_check_must_be_identical
    d = data
    cell(d, "methoden", "ja") { |c| c["t"] == "x" }["check"] = "square(9) == 81"
    assert_finds lint(d, only: %w[parity]), "ja-check", "methoden[ja]"
  end

  def test_title_number
    d = data
    lesson(d, "arrays")["en"]["title"] = "8. Arrays"
    assert_finds lint(d, only: %w[structure]), "title-number", "arrays[en]"
  end

  def test_ui_missing_and_placeholder
    d = data
    d["ui"]["ja"].delete("reset")
    d["ui"]["ja"]["nativeGem"] = d["ui"]["ja"]["nativeGem"].sub("%s", "この gem")
    f = lint(d, only: %w[parity])
    assert_finds f, "ui-missing", "ui.reset"
    assert_finds f, "ui-placeholder", "ui.nativeGem"
  end

  def test_cell_sequence
    d = data
    lesson(d, "hashes")["de"]["cells"].delete_at(1)
    assert_finds lint(d, only: %w[parity]), "cell-sequence", "hashes"
  end

  def test_a_reference_names_a_lesson
    d = data
    cell(d, "arrays", "de") { |c| c["t"] == "h" }["html"] += "<p>Mehr dazu in Lektion {{nr:gibtsnicht}}.</p>"
    assert_finds lint(d, only: %w[refs]), "ref-unknown", "arrays[de]"
  end

  # a number written out goes stale with the next lesson put in between -
  # in the prose, a hint and a code comment alike
  def test_a_reference_is_written_by_id
    d = data
    cell(d, "arrays", "de") { |c| c["t"] == "h" }["html"] += "<p>Mehr dazu in Lektion 9.</p>"
    cell(d, "arrays", "en") { |c| c["t"] == "x" }["hint"] += " See lesson 9."
    cell(d, "arrays", "ja") { |c| c["t"] == "c" }["code"] += "\n# レッスン9を見てね"
    f = lint(d, only: %w[refs])
    %w[arrays[de] arrays[en] arrays[ja]].each { |where| assert_finds f, "ref-literal", where }
  end

  def test_reference_parity
    d = data
    c = cell(d, "sequel", "en") { |x| x["html"].to_s.include?("lesson {{nr:roda}}") }
    c["html"] = c["html"].sub("lesson {{nr:roda}}", "lesson {{nr:sinatra}}")
    f = lint(d, only: %w[refs])
    assert_finds f, "ref-parity", "sequel"
    assert_finds f, "ref-context", "sequel[en]" # the sentence names Roda, the token Sinatra
  end

  # the scenario that used to break references: a lesson put in between.
  # Now nothing else has to change - the numbers move along by themselves.
  def test_a_lesson_put_in_between_changes_nothing_else
    d = data
    extra = Marshal.load(Marshal.dump(lesson(d, "wenn")))
    extra["id"] = "neu"
    d["lessons"].insert(4, extra)
    f = lint(d, only: %w[refs structure], allowed: true)
    %w[title-number ref-context ref-parity ref-unknown ref-literal ref-range].each { |code| refute_finds f, code }
    resolved = LessonLint::Source.new(ROOT, text: LessonLint::Source.dump(d)).data
    roda = resolved["lessons"].index { |l| l["id"] == "roda" } + 1
    sequel = resolved["lessons"].find { |l| l["id"] == "sequel" }
    assert(sequel["en"]["cells"].any? { |c| c["html"].to_s.include?("Roda from lesson #{roda})") }, "Roda is lesson #{roda} now")
  end

  def test_unbalanced_html_and_unknown_tag
    d = data
    c = cell(d, "arrays", "en") { |x| x["t"] == "h" }
    c["html"] += "<p>An <strong>open tag</p><p>Array<String> in prose</p>"
    f = lint(d, only: %w[html])
    assert_finds f, "unbalanced", "arrays[en]"
    assert(f.any? { |x| x.message.include?("<string> is no HTML tag") })
  end

  def test_syntax_error_and_warning
    d = data
    cell(d, "arrays", "de") { |c| c["t"] == "c" }["code"] = "def x(\n  1 +\nend"
    cell(d, "hashes", "de") { |c| c["t"] == "c" }["code"] = "h = { a: 1, a: 2 }\nh"
    f = lint(d, only: %w[ruby])
    assert_finds f, "syntax", "arrays[de]"
    assert_finds f, "warning", "hashes[de]"
  end

  def test_locals_from_earlier_cells_are_known
    # "x -1" is ambiguous only when x is a method; a local from an earlier
    # cell must not trigger the warning
    d = data
    cells = lesson(d, "variablen")["de"]["cells"].select { |c| c["t"] == "c" }
    cells[0]["code"] = "x = 5"
    cells[1]["code"] = "p x -1"
    refute(lint(d, only: %w[ruby]).any? { |f| f.where.start_with?("variablen[de]") && f.message.include?("ambiguous") })
  end

  def test_gem_not_in_cache_and_parity
    d = data
    c = cell(d, "gems", "en") { |x| x["t"] == "c" }
    c["code"] = "install_gem \"no_such_gem_xyz\"\n#{c["code"]}"
    f = lint(d, only: %w[gems parity])
    assert_finds f, "not-cached", "gems[en]"
    assert_finds f, "gem-usage", "gems"
  end

  def test_require_before_install
    d = data
    c = cell(d, "scarpe", "en") { |x| x["code"].to_s.include?("install_gem \"lacci\"") }
    c["code"] = c["code"].sub("install_gem \"lacci\"\n", "")
    assert_finds lint(d, only: %w[gems]), "require-before-install", "scarpe[en]"
  end

  def test_japanese_rules
    d = data
    c = cell(d, "arrays", "ja") { |x| x["t"] == "h" }
    c["html"] += "<p>これは配列だ。Aufgabe: noch nicht übersetzt.</p><p>This is the part that we forgot to translate here.</p>"
    f = lint(d, only: %w[ja])
    assert_finds f, "plain-form", "arrays[ja]"
    assert_finds f, "german-left", "arrays[ja]"
    assert_finds f, "english-left", "arrays[ja]"
  end

  def test_polite_japanese_is_fine
    d = data
    c = cell(d, "arrays", "ja") { |x| x["t"] == "h" }
    c["html"] += "<p>これは配列です。試してみましょう。<code>x</code>（等しい。すごい！）を使います。</p><ul><li>短く書く</li></ul>"
    refute(lint(d, only: %w[ja]).any? { |f| f.code == "plain-form" && f.where.start_with?("arrays[ja]") })
  end

  def test_untranslated_comment
    d = data
    %w[en ja].each do |g|
      c = cell(d, "schleifen", g) { |x| x["t"] == "c" }
      c["code"] = "# this is where the loop starts and you can change it\n#{c["code"]}"
    end
    assert_finds lint(d, only: %w[parity]), "untranslated-comment", "schleifen[ja]"
  end

  def test_inline_code_spans
    d = data
    c = cell(d, "methoden", "ja") { |x| x["html"].to_s.include?("<code>square(9)</code>") }
    c["html"] = c["html"].sub("<code>square(9)</code>", "<code>square(8)</code>")
    assert_finds lint(d, only: %w[parity]), "code-spans-ja", "methoden[ja]"
  end

  def test_link_parity_and_stale_ui_count
    d = data
    cell(d, "hallo", "en") { |x| x["t"] == "h" }["html"] += "<p><a href='https://example.org/x'>x</a></p>"
    d["ui"]["de"]["subtitle"] += " #{d["lessons"].size + 7} Lektionen." # stale whatever the real count is
    f = lint(d, only: %w[parity counts])
    assert_finds f, "links", "hallo"
    assert_finds f, "ui-count", "ui.subtitle[de]"
  end

  def test_task_block_missing
    d = data
    c = cell(d, "arrays", "en") { |x| x["html"].to_s.include?("<div class='task'>") }
    c["html"] = c["html"].sub("<div class='task'>", "<div>")
    f = lint(d, only: %w[structure parity])
    assert_finds f, "task-count", "arrays[en]"
    assert_finds f, "block-div.task", "arrays"
  end

  # ---------- the Pico lessons' fields (test/pico_lint.rb) ----------

  # a small lesson with every field, as tmp lesson writers make them
  def pico_lesson
    tabs = [{ "name" => "epd2in13.rb", "src" => "pico/lib/en/epd2in13.rb" },
            { "name" => "helper.rb", "code" => "# en\ndef helper = 1\n", "readonly" => false }]
    lesson = { "id" => "pico-lint", "engine" => "picoruby", "live" => false, "pico" => { "board" => "pico2w" } }
    %w[de en ja].each do |lang|
      lesson[lang] = { "title" => "Pico #{lang}", "cells" => [
        { "t" => "h", "html" => "<p>x</p><div class='task'>t</div>" },
        { "t" => "c", "code" => "require \"gpio\"\n", "board" => { "parts" => %w[led15 epd213] }, "tabs" => tabs.map(&:dup) },
        { "t" => "x", "code" => "x = 1\n", "check" => "board.level(15) == 1",
          "hint" => "h", "board" => { "parts" => %w[led15 button14] }, "bench" => [{ "at" => 300, "press" => 14 }] }
      ] }
    end
    lesson
  end

  def with_pico
    d = data
    l = pico_lesson
    yield l if block_given?
    d["lessons"] << l
    lint(d, only: %w[pico])
  end

  def test_pico_lesson_is_clean
    findings = with_pico
    assert_empty findings.select { |f| f.severity == "ERROR" }.map { |f| "#{f.code} #{f.where}: #{f.message}" }
  end

  def test_pico_unknown_part_and_pin_clash
    assert_finds(with_pico { |l| l["en"]["cells"][1]["board"]["parts"] << "laser" }, "board-part")
    f = with_pico { |l| %w[de en ja].each { |g| l[g]["cells"][1]["board"] = { "parts" => %w[picogo envsensor] } } }
    assert_finds f, "board-pins"
  end

  def test_pico_tabs
    assert_finds(with_pico { |l| l["en"]["cells"][1]["tabs"][0]["src"] = "pico/lib/en/nope.rb" }, "tab-source")
    assert_finds(with_pico { |l| l["en"]["cells"][1]["tabs"][1]["name"] = "epd2in13.rb" }, "tab-name")
    assert_finds(with_pico { |l| l["en"]["cells"][1]["tabs"][1]["name"] = "gpio.rb" }, "tab-name")
    assert_finds(with_pico { |l| l["en"]["cells"][1]["tabs"][0]["readonly"] = false }, "tab-readonly")
    assert_finds(with_pico { |l| l["ja"]["cells"][1]["tabs"].reverse! }, "pico-parity")
    assert_finds(with_pico { |l| l["de"]["cells"][1]["tabs"][1]["code"] = "def helper = 2\n" }, "pico-parity")
    refute_finds(with_pico { |l| l["ja"]["cells"][1]["tabs"][1]["code"] = "# ja\ndef helper = 1\n" }, "pico-parity")
  end

  def test_pico_bench_and_engine
    assert_finds(with_pico { |l| l["en"]["cells"][2]["bench"] << { "at" => 10, "push" => 14 } }, "bench")
    assert_finds(with_pico { |l| l["en"]["cells"][2]["bench"] << { "at" => 10, "arena" => "wall60" } }, "bench")
    assert_finds(with_pico { |l| l["en"]["cells"][2].delete("board") }, "bench")
    f = with_pico { |l| %w[de en ja].each { |g| l[g]["cells"][2].delete("bench") } }
    assert_finds f, "bench-missing"
    assert_finds(with_pico { |l| l["en"]["cells"][1]["engine"] = "jruby" }, "cell-engine")
    assert_finds(with_pico { |l| l["pico"] = { "board" => "esp32" } }, "pico-board")
    assert_finds(with_pico { |l| l.delete("engine") }, "pico-engine")
  end

  def test_check_may_use_board
    d = data
    l = pico_lesson
    d["lessons"] << l
    refute_finds lint(d, only: %w[ruby]).select { |f| f.where.start_with?("pico-lint") }, "check-warning"
  end
end
