# Minitest for the Spinel lesson's kernel side (html/spinel.rb): CRuby's run
# of the program - what the check reads and the page compares with:
# ruby test/spinel_rb_test.rb   (the page and Spinel itself: node spinel_test.mjs)
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

  # what the shell needs for its widget (shell/spinel.rb): plain strings
  # main.rb hands over, and every ui string it names, in every language
  def test_the_shells_labels_are_in_lessons_js
    text = File.read(File.expand_path("../html/lessons.js", __dir__), encoding: "UTF-8")
    data = JSON.parse(text[/JSON\.stringify\((.*)\);\s*\z/m, 1])
    shell = File.read(File.expand_path("../html/shell/spinel.rb", __dir__))
    keys = shell.scan(/t\("(spinel[A-Za-z]+|irbExitNote)"/).flatten.uniq
    assert_operator keys.size, :>=, 20
    %w[de en ja].each do |lang|
      keys.each { |key| assert data["ui"][lang].key?(key), "ui.#{key} missing in #{lang}" }
    end
  end
end
