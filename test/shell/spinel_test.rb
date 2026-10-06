# IRB on Spinel (html/shell/spinel.rb): the program an input becomes, the
# lines of a message, what a run's output says - plain Ruby, so CRuby runs
# the programs here the way Spinel's would (both print the same).
# The widgets themselves are tried in a browser (test/spinel_test.mjs).
require_relative "harness"
require "open3"
require "rbconfig"

class SpinelSessionTest < Minitest::Test
  # what a program prints, run by this Ruby: the stand-in for the compiled module
  def run_program(source)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-", stdin_data: source)
    [status.exitstatus, stdout, stderr]
  end

  def submit(session, input)
    program, first = session.program(input)
    code, stdout, stderr = run_program(program)
    session.outcome(input, first, code, stdout, stderr)
  end

  def test_a_value
    session = ChunkyShell::SpinelSession.new
    result = submit(session, "x = 6 * 7")
    assert result["ok"], result.inspect
    assert_equal "42", result["value"]
    assert_equal "", result["output"]
    assert_equal ["x = 6 * 7"], session.lines
  end

  def test_the_earlier_lines_run_again_but_only_the_new_output_shows
    session = ChunkyShell::SpinelSession.new
    submit(session, %(puts "first"))
    result = submit(session, %(puts "second"))
    assert_equal "second\n", result["output"]
    assert_equal "nil", result["value"]
  end

  def test_a_method_answers_its_name_and_stays
    session = ChunkyShell::SpinelSession.new
    assert_equal ":double", submit(session, "def double(n)\n  n * 2\nend")["value"]
    assert_equal ":triple", submit(session, "def triple(n) = n * 3")["value"]
    assert_equal ":empty?", submit(session, "def self.empty? = true")["value"]
    assert_equal "6", submit(session, "double(3)")["value"]
  end

  def test_a_class_answers_nil
    session = ChunkyShell::SpinelSession.new
    assert_equal "nil", submit(session, "class Fox\n  def name = \"Chunky\"\nend")["value"]
    assert_equal "\"Chunky\"", submit(session, "Fox.new.name")["value"]
  end

  def test_a_failed_line_is_not_kept_and_its_line_is_irbs
    session = ChunkyShell::SpinelSession.new
    submit(session, "x = 1")
    submit(session, "y = 2")
    program, first = session.program("z = 3\nraise ArgumentError, \"nein\"")
    code, stdout, stderr = run_program(program)
    result = session.outcome("z = 3\nraise ArgumentError, \"nein\"", first, code, stdout, stderr)
    refute result["ok"]
    assert_equal ["x = 1", "y = 2"], session.lines
    renumbered = ChunkyShell::SpinelSession.renumber(stderr.gsub("-:", "main.rb:"), first)
    assert_includes renumbered, "(irb):2"
  end

  def test_renumber
    assert_equal "(irb):1: no", ChunkyShell::SpinelSession.renumber("main.rb:7: no", 7)
    assert_equal "(irb):3 and (irb):1", ChunkyShell::SpinelSession.renumber("main.rb:9 and main.rb:2", 7)
  end

  def test_the_input_starts_on_the_line_it_says
    session = ChunkyShell::SpinelSession.new
    session.lines.concat(["a = 1", "b = 2"])
    %w[value def class].each do |kind|
      input = { "value" => "a + b", "def" => "def c = 3", "class" => "class C; end" }[kind]
      program, first = session.program(input)
      assert_equal input.lines.first.chomp, program.lines[first - 1].chomp, kind
    end
  end

  def test_output_without_the_markers_is_a_failure
    result = ChunkyShell::SpinelSession.new.outcome("x", 2, 1, "", "boom (RuntimeError)")
    refute result["ok"]
    assert_equal "boom (RuntimeError)", result["messages"]
  end
end
