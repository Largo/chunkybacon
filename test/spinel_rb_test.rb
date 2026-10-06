# Minitest for the Spinel lesson's Ruby side (html/spinel.rb): CRuby's run
# of the program (what the check reads and the page compares with), IRB's
# question whether an input is complete, the widget's JSON:
# ruby test/spinel_rb_test.rb   (Spinel itself: node spinel_test.mjs)
require "minitest/autorun"
require "json"
require_relative "../html/spinel"

class SpinelRbTest < Minitest::Test
  def test_the_oracle_captures_the_output
    program = spinel(%(def fib(n) = n < 2 ? n : fib(n - 1) + fib(n - 2)\nputs fib(20)\np [1, 2]\n))
    assert_kind_of ChunkySpinel::Program, program
    assert program.ok?
    assert_equal "6765\n[1, 2]\n", program.output
    assert_operator program.ms, :>=, 0
  end

  def test_the_cell_keeps_its_own_stdout
    before = $stdout
    spinel(%(puts "inside"\n))
    assert_same before, $stdout
  end

  def test_an_exception_is_the_programs_not_the_cells
    program = spinel(%(puts "before"\nraise ArgumentError, "kaputt\\nmore"\n))
    refute program.ok?
    assert_equal "before\n", program.output
    assert_equal "ArgumentError: kaputt", program.error
  end

  def test_a_syntax_error_is_an_error_of_the_program
    program = spinel("def x(\n")
    refute program.ok?
    assert_match(/\ASyntaxError/, program.error)
  end

  def test_the_program_runs_in_a_scope_of_its_own
    spinel(%(geheim = 42\n))
    refute binding.local_variable_defined?(:geheim)
  end

  def test_only_a_string_is_a_program
    error = assert_raises(ArgumentError) { spinel(nil) }
    assert_match(/<<~RUBY/, error.message)
  end

  def test_inspect_is_short
    assert_equal "#<Spinel::Program 2 lines>", spinel(%(a = 1\nb = 2\n)).inspect
  end

  def test_complete_says_ok_more_or_error
    assert_equal "ok", ChunkySpinel.complete("x = 6 * 7")
    assert_equal "ok", ChunkySpinel.complete("   ")
    assert_equal "more", ChunkySpinel.complete("def double(n)")
    assert_equal "more", ChunkySpinel.complete("def double(n)\n  n * 2")
    assert_equal "ok", ChunkySpinel.complete("def double(n)\n  n * 2\nend")
    assert_equal "more", ChunkySpinel.complete(%([1, 2,))
    assert_equal "more", ChunkySpinel.complete(%("unterminated))
    assert_equal "more", ChunkySpinel.complete("[1, 2].each do |x|")
    verdict = ChunkySpinel.complete("1 +* 2")
    assert verdict.start_with?("error (irb):1: "), verdict
  end

  def test_widget_json_names_every_label
    ui = ChunkySpinel::LABELS.values.to_h { |key| [key, "<#{key}>"] }
    json = JSON.parse(ChunkySpinel.widget_json(spinel(%(puts 1\n)), ui, "de"))
    assert_equal "de", json["lang"]
    assert_equal "puts 1\n", json["source"]
    assert_equal "1\n", json.dig("cruby", "output")
    assert_nil json.dig("cruby", "error")
    ChunkySpinel::LABELS.each { |name, key| assert_equal "<#{key}>", json["labels"][name] }
  end

  # every label is a ui string of the course, in every language
  def test_the_labels_are_in_lessons_js
    text = File.read(File.expand_path("../html/lessons.js", __dir__), encoding: "UTF-8")
    data = JSON.parse(text[/JSON\.stringify\((.*)\);\s*\z/m, 1])
    %w[de en ja].each do |lang|
      ChunkySpinel::LABELS.each_value do |key|
        assert data["ui"][lang].key?(key), "ui.#{key} missing in #{lang}"
      end
    end
  end
end
