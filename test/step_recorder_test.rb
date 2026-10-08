# Minitest for the stepper's recorder (html/step_recorder.rb) under plain
# CRuby: the notebook semantics (one binding per lesson), the edge cases a
# learner can type, living together with the live runs' time limit
# (html/autorun.rb), and the cells of the lessons that show ⏯ ("stepper":
# true in lessons.js): ruby test/step_recorder_test.rb
require "json"
require "minitest/autorun"
require "stringio"
require_relative "../html/step_recorder"
require_relative "../html/autorun"
require_relative "../html/turtle"
require_relative "../html/object_graph"

class StepRecorderTest < Minitest::Test
  LESSONS = JSON.parse(File.read(File.expand_path("lessons.json", __dir__)))["lessons"]

  # a lesson's binding as main.rb makes it (TopLevel.binding): a scope of
  # its own, so no top-level local of the test shows up in a cell
  def setup
    @bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval
  end

  def run_plain(code) = eval(code, @bind, "chunky.rb")

  def record(code, **opts)
    rec = StepRecorder.new(code, **opts)
    old = $stdout
    $stdout = StringIO.new
    begin
      rec.run { eval(code, @bind, "chunky.rb") }
    rescue Exception # rubocop:disable Lint/RescueException
      nil
    ensure
      $stdout = old
    end
    rec.trace
  end

  def frames(trace, step) = step[:f].map { |i| trace[:frames][i] }
  def vars(trace, step, depth = -1) = frames(trace, step)[depth][:vars].to_h { |n, v, _| [n, v] }
  def events(trace) = trace[:steps].map { |s| s[:event].to_s }

  def test_locals_live_on_in_the_shared_binding
    run_plain("a = 1\n")
    t = record("b = a + 1\na += 10\n")
    assert_equal({ "a" => "1" }, vars(t, t[:steps][0]))
    assert_equal 1, t[:frames][t[:steps][0][:f][0]][:vars][0][2], "a is marked as from an earlier cell"
    assert_equal({ "a" => "11", "b" => "2" }, vars(t, t[:steps].last))
    assert_equal 13, run_plain("a + b"), "the next cell sees what the stepped cell did"
  end

  def test_hoisted_locals_are_hidden_until_assigned
    t = record("x = 1\ny = nil\nz = 3\n")
    assert_equal({}, vars(t, t[:steps][0]))
    assert_equal({ "x" => "1" }, vars(t, t[:steps][1]))
    assert_equal({ "x" => "1", "y" => "nil" }, vars(t, t[:steps][2]), "y = nil counts as assigned")
  end

  def test_methods_of_earlier_cells_are_not_stepped_into
    run_plain("def doppelt(n)\n  n * 2\nend\n")
    t = record("d = doppelt(4)\n")
    assert_equal %w[line end], events(t)
  end

  def test_methods_of_this_cell_are
    t = record("def doppelt(n)\n  n * 2\nend\ndoppelt(4)\n")
    assert_equal %w[line line call line return end], events(t)
    assert_equal "8", t[:steps][4][:value]
  end

  def test_numbered_parameters_and_it
    t = record("a = [1, 2].map { _1 * 2 }\nb = [3].map { it + 1 }\n[a, b]\n")
    assert_nil t[:steps].find { |s| s[:event] == "recorder-error" }
    assert_equal "[[2, 4], [4]]", t[:result]
  end

  def test_odd_values
    code = <<~RUBY
      class Kaputt
        def inspect = raise("no")
      end
      class Gross
        def initialize = (@daten = (1..100_000).to_a; @name = "g")
      end
      k = Kaputt.new
      g = Gross.new
      b = BasicObject.new
      s = "x" * 10_000
      h = (1..100).to_h { |i| [i, i] }
      st = Struct.new(:a).new(1)
      :ok
    RUBY
    t = record(code)
    last = vars(t, t[:steps].last)
    assert_equal "#<Kaputt>", last["k"]
    assert_match(/\A#<Gross @daten=\[1, 2, 3/, last["g"])
    assert_operator last["g"].length, :<=, StepRecorder::MAX_VALUE + 1
    assert_match(/BasicObject/, last["b"])
    assert_operator last["s"].length, :<=, StepRecorder::MAX_VALUE + 1
    assert_match(/… \(100\)/, last["h"])
    assert_equal ":ok", t[:result]
  end

  def test_the_cap_stops_recording_not_the_run
    t = record("s = 0\n1.upto(5_000) { |i| s += i }\ns\n", max_steps: 50)
    assert t[:truncated]
    assert_equal 51, t[:steps].length
    assert_equal "12502500", t[:result]
  end

  def test_errors_point_at_their_line_and_drop_the_unwinding
    t = record("def teile(a, b)\n  a / b\nend\nx = 1\nteile(x, 0)\n")
    assert_equal "error", t[:steps].last[:event].to_s
    assert_equal 2, t[:steps].last[:line]
    assert_match(/ZeroDivisionError/, t[:steps].last[:value])
    refute_includes events(t), "return"
  end

  def test_a_syntax_error_records_nothing
    t = record("def x(\n")
    refute t[:traced]
    assert_empty t[:steps]
    assert_match(/SyntaxError/, t[:error])
  end

  # an exercise before the learner wrote anything: only comments, no line to
  # stop at - and asking TracePoint for one would deafen every later
  # targeted TracePoint in the process
  def test_a_cell_of_comments_only
    t = record("# name = ...\n# age = ...\n")
    assert t[:traced]
    assert_equal %w[end], events(t)
    t = record("x = 1\n")
    assert_equal %w[line end], events(t), "the next cell is still recorded"
  end

  def test_output_offsets
    t = record("puts 'ä'\nputs 'b'\n")
    assert_equal [0, 3, 5], t[:steps].map { |s| s[:out] }
    assert_equal "ä\nb\n", t[:output]
  end

  def test_rescue_inside_the_cell_continues
    t = record("x = begin\n  Integer('zz')\nrescue ArgumentError\n  -1\nend\nx\n")
    assert_equal "-1", t[:result]
    assert_equal "end", t[:steps].last[:event].to_s
  end

  def test_deep_recursion_keeps_few_frames
    t = record("def tief(n) = n.zero? ? 0 : tief(n - 1)\ntief(50)\n", max_steps: 80)
    deepest = t[:steps].map { |s| s[:f].length }.max
    assert_equal StepRecorder::MAX_FRAMES + 1, deepest, "the innermost frames plus a '… n' marker"
    assert_equal "more", t[:frames][t[:steps][60][:f][0]][:kind].to_s
  end

  def test_with_the_live_time_limit
    code = "i = 0\nloop do\n  i += 1\nend\n"
    rec = StepRecorder.new(code, max_steps: 100)
    error = nil
    begin
      AutoRun.with_time_limit(["chunky.rb"], 0.3) { rec.run { eval(code, @bind, "chunky.rb") } }
    rescue AutoRun::Stopped => e
      error = e
    end
    assert error, "the time limit still stops an endless loop that is being recorded"
    assert rec.trace[:truncated]
    assert_match(/AutoRun::Stopped/, rec.trace[:error])
  end

  # ---------- in the course ----------

  def cells(id, lang)
    LESSONS.find { |l| l["id"] == id }[lang]["cells"].each_with_index.select { |c, _| %w[c x].include?(c["t"]) }
  end

  # check_exercise's locals live on in the lesson's binding: the next
  # stepped cell must not show them as variables of an earlier cell
  def test_what_a_check_leaves_in_the_binding_is_hidden
    main = File.read(File.expand_path("../html/main.rb", __dir__))
    check = main[/def check_exercise.*?\n  end\n/m]
    names = check.scan(/local_variable_set\(:(\w+)/).flatten.map(&:to_sym).uniq
    assert_operator names.length, :>=, 10
    assert_empty names - StepRecorder::HIDDEN
    run_plain("output = 'x'\nresult = 1\ngames = []\n")
    t = record("menge = 3\n")
    assert_equal({ "menge" => "3" }, vars(t, t[:steps].last))
  end

  # browser_test.mjs steps through this cell: 5 steps, i = 2 on the 4th with
  # two lines of output so far
  def test_the_loop_of_lesson_schleifen
    code = cells("schleifen", "de").find { |_, i| i == 3 }[0]["code"]
    assert_includes code, "3.times do |i|"
    t = record(code)
    assert_equal %w[line line line line end], events(t)
    fourth = t[:steps][3]
    assert_equal({ "i" => "2" }, vars(t, fourth))
    assert_equal 3, frames(t, fourth).last[:iter]
    assert_equal "Streifen Nummer 1\nStreifen Nummer 2\n", t[:output].byteslice(0, fourth[:out])
  end

  # turtle { } instance_evals the cell's block on a Turtle: still this
  # cell's code, so its lines are steps; Turtle's own methods are not
  def test_a_turtle_block
    code = cells("turtle", "en").first[0]["code"]
    t = record(code)
    assert_nil t[:error]
    assert_equal 1 + 1 + 8 + 1, t[:steps].length, "turtle do, 4.times do, 4 x (forward, right), the end"
    assert_match(/\A#<Turtle 4 lines/, t[:result])
    second_pass = frames(t, t[:steps][4])
    assert_equal %w[main block block], second_pass.map { |f| f[:kind].to_s }
    assert_equal [3, 2], [t[:steps][4][:line], second_pass.last[:iter]], "forward 100, in the second pass"
  end

  # every code cell of a lesson with "stepper": true records - in German and
  # English (Japanese runs the English code), one binding per lesson
  def test_the_cells_of_the_stepper_lessons
    flagged = LESSONS.select { |l| l["stepper"] }
    assert_operator flagged.length, :>=, 8
    side_trips = LESSONS.index { |l| l["section"] && LESSONS.index(l).positive? }
    assert(flagged.all? { |l| LESSONS.index(l) < side_trips }, "⏯ is for the Basics only")
    flagged.each do |lesson|
      %w[de en].each do |lang|
        setup
        cells(lesson["id"], lang).each do |cell, idx|
          t = record(cell["code"])
          where = "#{lesson['id']} #{lang} cell #{idx}"
          assert t[:traced], where
          code_lines = cell["code"].lines.grep_v(/\A\s*(#|\z)/)
          assert_equal code_lines.any?, events(t).include?("line"), where
          assert_nil t[:steps].find { |s| s[:event] == "recorder-error" }, where
          assert_nil t[:error], where unless cell["t"] == "x"
          assert_operator JSON.generate(t).bytesize, :<, 200_000, where
        end
      end
    end
  end
end
