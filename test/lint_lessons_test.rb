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
  BASE = LessonLint::Source.new(ROOT).data.freeze

  def data = Marshal.load(Marshal.dump(BASE))

  def lint(d, only: LessonLint::GROUPS - %w[links])
    text = LessonLint::Source.dump(d)
    LessonLint::Linter.new(ROOT, allow_path: nil, text: text, gems: GEMS).run(only)
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

  def test_reference_out_of_range
    d = data
    cell(d, "arrays", "de") { |c| c["t"] == "h" }["html"] += "<p>Mehr dazu in Lektion 99.</p>"
    assert_finds lint(d, only: %w[refs]), "ref-range", "arrays[de]"
  end

  def test_reference_parity
    d = data
    c = cell(d, "sequel", "en") { |x| x["html"].to_s.include?("lesson 17") }
    c["html"] = c["html"].sub("lesson 17", "lesson 16")
    f = lint(d, only: %w[refs])
    assert_finds f, "ref-parity", "sequel"
    assert_finds f, "ref-context", "sequel[en]" # the sentence names Roda, 16 is Sinatra
  end

  # the scenario from OPEN_WORK: a lesson inserted, later titles renumbered,
  # but the "lesson N" references in the prose left alone
  def test_insert_lesson_without_fixing_references
    d = data
    extra = Marshal.load(Marshal.dump(lesson(d, "wenn")))
    extra["id"] = "neu"
    d["lessons"].insert(4, extra)
    d["lessons"].each_with_index do |l, i|
      LessonLint::LANGS.each { |g| l[g]["title"] = l[g]["title"].sub(/\A\d+\./, "#{i + 1}.") }
    end
    f = lint(d, only: %w[refs structure])
    refute_finds f, "title-number"
    suspects = f.select { |x| x.code == "ref-context" }
    assert_operator suspects.size, :>=, 3, "only #{suspects.map(&:where)}"
    assert(suspects.any? { |x| x.where.start_with?("sequel") }, "Roda reference not caught")
    assert(suspects.any? { |x| x.where.start_with?("numpy") || x.where.start_with?("sympy") }, "pandas reference not caught")
  end

  def insert_at_5(d)
    extra = Marshal.load(Marshal.dump(lesson(d, "wenn")))
    extra["id"] = "neu"
    d["lessons"].insert(4, extra)
    d["lessons"].each_with_index do |l, i|
      LessonLint::LANGS.each { |g| l[g]["title"] = l[g]["title"].sub(/\A\d+\./, "#{i + 1}.") }
    end
    d
  end

  def lint_with_base(d)
    LessonLint::Linter.new(ROOT, allow_path: nil, text: LessonLint::Source.dump(d), gems: GEMS,
                           base_text: LessonLint::Source.dump(data)).run(%w[refs])
  end

  def test_base_mode_catches_every_stale_reference
    f = lint_with_base(insert_at_5(data))
    moved = f.select { |x| x.code == "ref-moved" }
    # every reference to lessons 5..46 in every language is now stale
    expected = 0
    BASE["lessons"].each do |l|
      LessonLint::LANGS.each do |g|
        l[g]["cells"].each do |c|
          expected += [c["html"], c["hint"]].compact.join(" ").scan(LessonLint::Linter::REF[g]).count { |a, _| a.to_i >= 5 }
        end
      end
    end
    assert_operator expected, :>, 10
    assert_equal expected, moved.size, moved.map(&:message).first(5).join("\n")
  end

  def test_base_mode_accepts_fixed_references
    d = insert_at_5(data)
    d["lessons"].each do |l|
      LessonLint::LANGS.each do |g|
        l[g]["cells"].each do |c|
          %w[html hint].each do |k|
            next unless c[k]
            c[k] = c[k].gsub(LessonLint::Linter::REF[g]) { |m| m.sub(/\d+/) { |n| n.to_i >= 5 ? (n.to_i + 1).to_s : n } }
          end
        end
      end
    end
    refute_finds lint_with_base(d), "ref-moved"
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
end
