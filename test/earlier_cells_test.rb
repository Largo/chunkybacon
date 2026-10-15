# The cells ▶ runs first (html/earlier_cells.rb): which of the code cells
# above a cell have not run in the binding with the code they show now.
# What running them does to every lesson: check_harness.rb.
#   ruby test/earlier_cells_test.rb
require "minitest/autorun"
require_relative "../html/earlier_cells"

class EarlierCellsTest < Minitest::Test
  CELLS = [
    { "t" => "h", "html" => "<p>intro</p>" },
    { "t" => "c", "code" => "fox = \"Kaz\"" },            # 1
    { "t" => "h", "html" => "<p>more</p>" },
    { "t" => "c", "code" => "def greet = \"Hi \#{fox}\"" }, # 3
    { "t" => "c", "code" => "greet" },                    # 4
    { "t" => "x", "code" => "# your code\n", "check" => "true" }, # 5
    { "t" => "c", "code" => "after" }                     # 6
  ].freeze

  def before(idx, ran = {}, editors = {})
    EarlierCells.before(idx, CELLS, ran) { |i| editors.fetch(i) { CELLS[i]["code"] } }.map(&:first)
  end

  def test_a_fresh_binding_runs_every_code_cell_above_in_order
    assert_equal [1, 3], before(4)
    assert_equal [], before(1), "nothing above the first"
    assert_equal [], before(0)
  end

  def test_cells_that_ran_with_the_code_they_show_are_skipped
    assert_equal [3], before(4, { 1 => CELLS[1]["code"] })
    assert_equal [], before(4, { 1 => CELLS[1]["code"], 3 => CELLS[3]["code"] })
    assert_equal [1], before(4, { 3 => CELLS[3]["code"] }), "a cell below that ran does not stand in for one above"
  end

  def test_a_cell_edited_after_it_ran_runs_again_with_its_new_code
    ran = { 1 => CELLS[1]["code"], 3 => CELLS[3]["code"] }
    list = EarlierCells.before(4, CELLS, ran) { |i| i == 1 ? "fox = \"Chunky\"" : CELLS[i]["code"] }
    assert_equal [[1, "fox = \"Chunky\""]], list
  end

  def test_the_exercise_is_left_out_while_it_holds_its_starter
    assert_equal [1, 3, 4], before(6)
    assert_equal [1, 3, 4], before(6, {}, { 5 => "\n  # your code\n\n" }), "blank lines and indentation are no change"
    assert_equal [1, 3, 4, 5], before(6, {}, { 5 => "# your code\nshout = \"CHUNKY\"" }), "the learner's code runs"
  end

  def test_the_code_comes_from_the_editor
    list = EarlierCells.before(4, CELLS, {}) { |i| "edited #{i}" }
    assert_equal [[1, "edited 1"], [3, "edited 3"]], list
  end
end
