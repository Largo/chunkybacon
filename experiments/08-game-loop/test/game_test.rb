# Headless: game.rb under plain CRuby, the Snake example driven by
# #press/#advance, no page.   ruby experiments/08-game-loop/test/game_test.rb
require "json"
require "stringio"
require "minitest/autorun"
require_relative "../site/game"

class GameTest < Minitest::Test
  SNAKE = File.read(File.expand_path("../examples/snake.rb", __dir__))

  def snake_game
    srand(1)
    eval(SNAKE, binding, "chunky.rb")
  end

  def frame(game, now, events = "")
    JSON.parse(game.step(now, events))
  end

  def test_snake_moves_on_its_timer
    g = snake_game
    assert_instance_of ChunkyGame, g
    frame(g, 1000)                     # starts the clock
    f = frame(g, 1160)                 # one tick
    assert_equal 1, g.ticks
    assert_equal :chunky, g.cell(6, 7)
    assert_equal "Bacon: 0", f["status"]
    assert_in_delta 1300, f["next"], 1
    look = f["d"].to_h
    assert_equal "🦊", look[7 * 20 + 6]
    assert_equal "bg:#f2a65a", look[7 * 20 + 4]
    assert_equal "🥓", look[7 * 20 + 12]
  end

  def test_snake_eats_bacon_and_grows
    g = snake_game
    frame(g, 0)
    6.times { |n| frame(g, 150 * (n + 1) + 1) }   # 6 steps right: 5 -> 11
    assert_equal :chunky, g.cell(11, 7)
    frame(g, 150 * 7 + 1)                          # onto the bacon at 12
    assert_equal :chunky, g.cell(12, 7)
    assert_equal "Bacon: 1", g.status_text
    assert_equal 4, 20.times.sum { |x| 15.times.count { |y| %i[body chunky].include?(g.cell(x, y)) } }
  end

  def test_keys_steer_and_the_wall_ends_it
    g = snake_game
    frame(g, 0)
    f = frame(g, 10, "k:up")
    assert_empty f["d"]                 # a key changes nothing on screen yet
    frame(g, 151)
    assert_equal :chunky, g.cell(5, 6)
    8.times { |n| frame(g, 151 + 150 * (n + 1)) }
    f = frame(g, 2000)
    assert g.over?
    assert_match(/Ouch/, f["over"])
    refute f.key?("next")
  end

  def test_errors_in_a_tick_stop_the_game_and_name_the_line
    g = eval("show_game { |g| g.every(0.1) { nil + 1 } }", binding, "chunky.rb")
    frame(g, 0)
    f = frame(g, 200)
    assert g.over?
    assert_match(/NoMethodError: .*\(line 1\)/, f["error"])
  end

  def test_restart_runs_setup_again
    g = snake_game
    frame(g, 0)
    frame(g, 151, "k:up")
    frame(g, 200, "r")
    assert_nil g.cell(5, 6)             # setup draws nothing until the first tick
    frame(g, 351)
    assert_equal :chunky, g.cell(6, 7)  # direction is right again
    refute g.over?
  end

  def test_advance_runs_every_tick_and_keeps_the_clock
    g = snake_game
    g.advance(0.15).advance(0.15)
    assert_equal 2, g.ticks
    assert_equal :chunky, g.cell(7, 7)
    g.press(:up)                        # must not move the clock
    g.advance(0.15)
    assert_equal 3, g.ticks
    assert_equal :chunky, g.cell(7, 6)
  end

  def test_advance_does_not_cap_long_spans
    g = ChunkyGame.new { |g| g.every(0.15) {} }
    g.advance(1.0)
    assert_equal 6, g.ticks
  end

  def test_puts_goes_to_the_games_log
    g = ChunkyGame.new { |g| g.on_key { |k| puts "key #{k}" } }
    f = JSON.parse(g.step(0, "k:space|k:a"))
    assert_equal "key space\nkey a\n", f["log"]
  end

  def test_block_without_argument_is_instance_exec
    g = ChunkyGame.new(width: 3, height: 3) { cell(1, 1, :bacon) }
    assert_equal :bacon, g.cell(1, 1)
    assert_equal :outside, g.cell(3, 0)
    assert_equal 8, g.free_cells.size
  end

  def test_step_cost
    g = snake_game
    frame(g, 0)
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n = 2000
    n.times { |i| g.step(151 + i * 150, g.over? ? "r" : (i.even? ? "k:up" : "k:right")) }
    per = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / n * 1e6
    puts format("\nstep (Snake tick + JSON) under native CRuby: %.1f us", per)
  end
end
