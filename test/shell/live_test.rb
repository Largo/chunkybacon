require_relative "harness"

# Live runs: a key in a cell asks the kernel for a rehearsal a moment later
# (main.rb's AutoRun does the rest); the page keeps quiet about it unless
# an exercise passes.
class LiveTest < Minitest::Test
  include ShellTest

  def run_button(idx) = find(".run-cell[data-idx='#{idx}']")
  def cell(idx) = run_button(idx).js_closest(".cell")
  def toggle(idx) = cell(idx).js_querySelector(".live-toggle")
  def exercise_idx = find(".cell.exercise .run-cell").attrs["data-idx"].to_i
  def type_in(idx, text) = window.props["cellEditors"][idx.to_s].type(text)

  # the page, with the kernel up
  def start_ready(**options)
    start(**options) { window.props["ChunkyBridge"]["ready"] = true }
    fire("chunky:kernel-ready")
  end

  def live_ran(idx, outcome, elapsed = 0.05)
    fire("chunky:ran", { "idx" => idx, "outcome" => outcome, "elapsed" => elapsed, "auto" => true, "own" => elapsed })
  end

  def test_a_key_runs_the_cell_a_moment_later
    start_ready
    Task.held = []
    type_in(1, "puts 3")
    assert_empty calls("autorun"), "not while typing"
    Task.release
    assert_equal [["autorun", 1]], calls("autorun")
    assert_empty calls("run")
    refute_includes cell(1).attrs["class"], "running", "a live run has no running look"
    refute run_button(1).props["disabled"]
  end

  def test_only_the_last_key_runs
    start_ready
    Task.held = []
    type_in(1, "puts")
    type_in(1, "puts 3")
    Task.release
    assert_equal 1, calls("autorun").length
  end

  def test_code_put_in_by_the_page_does_not_run
    start_ready
    window.props["cellEditors"]["1"].js_setValue("puts 3")
    assert_empty calls("autorun")
  end

  def test_nothing_runs_live_before_the_kernel_is_up
    start
    type_in(1, "puts 3")
    assert_empty calls("autorun")
    assert_empty calls("run"), "and nothing is queued for later"
  end

  def test_the_switch_turns_live_runs_off_and_on
    start_ready
    assert_equal "true", toggle(1).attrs["aria-pressed"]
    click(toggle(1))
    assert_equal "off", window.storage["chunkyui_live"]
    assert(find_all(".live-toggle").all? { |button| button.attrs["aria-pressed"] == "false" }, "every cell's switch")
    assert_includes toggle(1).props["title"], "Live ist aus"
    type_in(1, "puts 3")
    assert_empty calls("autorun")
    click(toggle(1))
    assert_equal "on", window.storage["chunkyui_live"]
    type_in(1, "puts 4")
    assert_equal [["autorun", 1]], calls("autorun")
  end

  def test_the_switch_is_remembered
    start_ready(storage: { "chunkyui_live" => "off" })
    assert_equal "false", toggle(1).attrs["aria-pressed"]
    type_in(1, "puts 3")
    assert_empty calls("autorun")
  end

  def test_a_live_error_or_wrong_answer_stays_quiet
    start_ready
    idx = exercise_idx
    welcome = bubble
    live_ran(idx, "error")
    refute_includes cell(idx).attrs["class"], "shake"
    live_ran(idx, "fail")
    assert_equal welcome, bubble, "no bubble"
    assert_nil cell(idx).js_querySelector(".run-time"), "no run time either"
    refute_includes byid("cell-out-#{idx}").attrs["class"].to_s, "reveal"
  end

  def test_a_live_pass_cheers_when_it_is_new
    start_ready
    idx = exercise_idx
    live_ran(idx, "pass")
    assert_equal "pass", bubble_state
    assert_includes cell(idx).attrs["class"], "celebrate"
    assert_equal '["hallo"]', window.storage["chunky_done"]
    window.storage["chunky_done"] = "[]"
    live_ran(idx, "pass")
    assert_equal "[]", window.storage["chunky_done"], "the same pass again: no new cheer"
    live_ran(idx, "skipped")
    live_ran(idx, "pass")
    assert_equal "[]", window.storage["chunky_done"], "a skipped run changes nothing"
    live_ran(idx, "fail")
    live_ran(idx, "pass")
    assert_equal '["hallo"]', window.storage["chunky_done"], "passed again after a miss"
  end

  def test_a_slow_cell_waits_for_run
    start_ready
    fire("chunky:ran", { "idx" => 1, "outcome" => "ok", "elapsed" => 0.8, "auto" => false, "own" => 0.8 })
    assert_includes toggle(1).attrs["class"], "is-paused"
    assert_includes toggle(1).props["title"], "zu lange"
    refute_includes toggle(exercise_idx).attrs["class"].to_s, "is-paused", "only that cell"
    type_in(1, "puts 3")
    assert_empty calls("autorun")
    fire("chunky:ran", { "idx" => 1, "outcome" => "ok", "elapsed" => 0.05, "auto" => false, "own" => 0.05 })
    refute_includes toggle(1).attrs["class"], "is-paused"
    type_in(1, "puts 4")
    assert_equal [["autorun", 1]], calls("autorun")
  end

  # elapsed 2.5 s, of which installing and loading a gem took all but 0.05 s
  def test_installing_a_gem_does_not_make_a_cell_slow
    start_ready
    fire("chunky:ran", { "idx" => 1, "outcome" => "ok", "elapsed" => 2.5, "auto" => false, "own" => 0.05 })
    refute_includes toggle(1).attrs["class"].to_s, "is-paused"
    assert_equal "2,5 s", cell(1).js_querySelector(".run-time").text, "the run time is the whole run"
    type_in(1, "puts 4")
    assert_equal [["autorun", 1]], calls("autorun")
  end

  def test_a_live_run_stopped_by_its_time_limit_pauses_the_cell
    start_ready
    live_ran(1, "stopped", 1.02)
    assert_includes toggle(1).attrs["class"], "is-paused"
  end

  def test_a_click_on_run_drops_the_waiting_live_run
    start_ready
    Task.held = []
    type_in(1, "puts 3")
    click(run_button(1))
    Task.release
    assert_empty calls("autorun")
    assert_equal [["run", 1]], calls("run")
  end

  def test_no_live_run_while_the_cell_runs
    start_ready
    click(run_button(1))
    type_in(1, "puts 3")
    assert_empty calls("autorun")
  end

  def test_another_lesson_drops_the_waiting_live_run
    start_ready
    Task.held = []
    type_in(1, "puts 3")
    click(find('#lessonNav a[data-id="rechnen"]'))
    Task.release
    assert_empty calls("autorun")
  end

  def test_the_workshop_starts_with_live_off
    start_ready(hash: "#werkstatt")
    assert_equal "false", toggle(0).attrs["aria-pressed"]
    type_in(0, "puts 3")
    assert_empty calls("autorun")
    click(toggle(0))
    assert_equal "on", window.storage["chunkyui_live_ws"]
    assert_nil window.storage["chunkyui_live"], "the lessons keep their own switch"
    type_in(0, "puts 4")
    assert_equal [["autorun", 0]], calls("autorun")
  end

  def test_an_irb_has_no_switch
    start_ready(hash: "#irb")
    irb = find_all("#lessonBody .cell").length
    switches = find_all("#lessonBody .live-toggle").length
    assert_equal irb - 1, switches
    assert_empty JS.console_errors
  end
end
