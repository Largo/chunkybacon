# The rules for live runs (html/autorun.rb), under CRuby:
#   ruby test/autorun_test.rb
require "minitest/autorun"
require_relative "../html/autorun"

class AutoRunTest < Minitest::Test
  def runnable?(code, locals = []) = AutoRun.runnable?(code, locals)

  def test_code_that_parses_runs
    assert runnable?("1 + 1")
    assert runnable?("10.times do |i|\n  puts i\nend")
    assert runnable?("x = 0\nwhile x < 3\n  x += 1\nend")
    assert runnable?("x = 0; while x < 3\n  x += 1\nend"), "a while after a ; is not a modifier"
    assert runnable?("loop do\n  break\nend")
    assert runnable?("puts 'Speck' # while the pan is hot")
  end

  def test_half_typed_code_does_not
    refute runnable?("")
    refute runnable?("10.times do |i|")
    refute runnable?("puts \"Hallo")
    refute runnable?("def doppelt(x)")
  end

  def test_the_bindings_locals_decide_how_code_parses
    refute runnable?("x /2"), "without a local x this is a regexp that never ends"
    assert runnable?("x /2", [:x])
  end

  # loops that make no TracePoint events: the time limit could not stop them
  def test_loops_without_events_do_not_run
    refute runnable?("while true\nend")
    refute runnable?("until done; end")
    refute runnable?("while true do end")
    refute runnable?("while x\n  # warten\nend")
    refute runnable?("x = 0\nx += 1 while true")
    refute runnable?("x = 0\nx += 1 until false")
    refute runnable?("begin\nend while true")
  end

  def test_an_irb_cell_does_not
    refute runnable?("show_irb")
  end

  def test_the_time_limit_stops_the_learners_endless_loop
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(AutoRun::Stopped) do
      AutoRun.with_time_limit(["chunky.rb"], 0.2) { eval("x = 0\nloop do\n  x += 1\nend", binding, "chunky.rb") }
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
  end

  def test_a_one_line_loop_with_a_call_is_stopped_too
    assert_raises(AutoRun::Stopped) do
      AutoRun.with_time_limit(["chunky.rb"], 0.2) { eval("x = 0\nwhile true do x += 1 end", binding, "chunky.rb") }
    end
  end

  def test_code_elsewhere_is_never_cut_off
    result = AutoRun.with_time_limit(["chunky.rb"], 0.0) { eval("(1..20_000).sum { |i| i * 2 }", binding, "/gems/x.rb") }
    assert_equal 400_020_000, result
  end

  def test_a_rescue_in_the_learners_code_does_not_swallow_the_stop
    refute AutoRun::Stopped <= StandardError
    assert_raises(AutoRun::Stopped) do
      AutoRun.with_time_limit(["chunky.rb"], 0.1) do
        eval("loop do\n  begin\n    1 + 1\n  rescue => e\n    e\n  end\nend", binding, "chunky.rb")
      end
    end
  end

  def test_untraced_page_code_runs_through
    result = AutoRun.with_time_limit(["chunky.rb"], 0.05) do
      eval("AutoRun.untraced { sleep 0.2; :done }", binding, "chunky.rb")
    end
    assert_equal :done, result
  end
end
