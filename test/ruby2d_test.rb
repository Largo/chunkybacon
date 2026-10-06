# Minitest for ruby2d on the page (html/ruby2d.rb over the gem's own Ruby in
# html/assets/ruby2d/) under plain CRuby, no page: windows shown headless and
# driven frame by frame (Page::Runner#step, #press, #click, #tick), the draw
# commands game.js paints, every code cell of lesson 39 in de/en/ja, the
# copy a check plays, the top-level mixing taken back, what is not here:
# ruby test/ruby2d_test.rb
require "json"
require "stringio"
require "minitest/autorun"
require "tmpdir"
require_relative "../html/ruby2d"

# require "ruby2d" in a program finds the stand-in, already loaded (each
# test mixes it in, as main.rb's shim does)
SHIM_DIR = Dir.mktmpdir("ruby2d_shim")
File.write(File.join(SHIM_DIR, "ruby2d.rb"), "")
$LOAD_PATH.unshift(SHIM_DIR)
Minitest.after_run { FileUtils.rm_rf(SHIM_DIR) }

class Ruby2DTest < Minitest::Test
  LESSON = JSON.parse(File.read(File.expand_path("lessons.json", __dir__)))["lessons"]
               .find { |lesson| lesson["id"] == "ruby2d" }
  MAIN = TOPLEVEL_BINDING.receiver

  def setup
    Ruby2D.reset__
    Ruby2D.on_show__ = nil
    Ruby2D.lang__ = "en"
    Ruby2D.mix__(MAIN)
  end

  def teardown
    Ruby2D.unmix__
  end

  # a program as a cell runs it: its own top-level binding, file chunky.rb;
  # returns the Runner of the window it showed
  def run_program(code)
    Ruby2D.reset__
    out = $stdout
    $stdout = StringIO.new
    eval(code, RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval, "chunky.rb")
    Ruby2D::Page.shown_runners.last&.tap { |runner| runner.source = code }
  ensure
    $stdout = out
  end

  def frame(runner, ms, events = "")
    JSON.parse(runner.step(ms, events))
  end

  def test_the_vendored_gem_is_ruby2d_1_0_0
    head = File.read(File.expand_path("../html/assets/ruby2d/ruby2d.rb", __dir__), 300)
    assert_match(/ruby2d 1\.0\.0/, head)
    assert File.exist?(File.expand_path("../html/assets/ruby2d/LICENSE.md", __dir__))
    # the gem's real classes, not stand-ins
    assert_equal [:color, :colour, :fill, :opacity, :rotate, :stroke_color, :stroke_width, :x, :y, :z],
                 (Ruby2D::Circle.instance_method(:initialize).parameters.map(&:last) &
                  %i[x y z color colour opacity rotate fill stroke_width stroke_color]).sort
  end

  def test_a_square_on_navy
    r = run_program(%(require "ruby2d"\nset title: "Hi", background: "navy"\nSquare.new(x: 270, y: 190, size: 100, color: "orange")\nshow))
    assert_equal [640, 480, "Hi"], [r.width, r.height, r.title]
    first = JSON.parse(r.full_json)
    assert_equal [0.0, 31 / 255.0, 63 / 255.0, 1.0].map { |v| v.round(4) }, first["bg"].map { |v| v.round(4) }
    quad = first["c"].first
    assert_equal "q", quad[0]
    assert_equal [270, 190, 370, 190, 370, 290, 270, 290], quad[1, 8]
    assert_equal [1.0, 0x85 / 255.0, 0x1b / 255.0, 1.0].map { |v| v.round(4) }, quad[9, 4].map { |v| v.round(4) }
    assert_equal 0, Ruby2D::Window.frames, "no frame yet before the first step"
    assert_in_delta 1000 * 0.75 / 60, first["next"], 1
  end

  def test_shapes_text_z_and_colours
    r = run_program(<<~RUBY)
      require "ruby2d"
      Circle.new(x: 50, y: 60, radius: 20, color: "white", opacity: 0.5, z: 2)
      Triangle.new(x1: 0, y1: 0, x2: 10, y2: 0, x3: 0, y3: 10, color: ["red", "lime", "blue"])
      Line.new(x1: 0, y1: 0, x2: 100, y2: 0, stroke_width: 4, color: ["red", "blue"])
      Square.new(size: 30, color: ["red", "yellow", "lime", "blue"])
      Ellipse.new(x: 10, y: 10, xradius: 30, yradius: 10, color: "teal")
      Text.new("Score: 0", x: 10, y: 10, size: 24, color: "#ffffff", style: :bold)
      Polygon.new(points: [[0, 0], [10, 0], [10, 10], [0, 10], [5, 15]], color: "silver")
      Rectangle.new(width: 10, height: 10, color: "random", stroke_width: 2, stroke_color: "black")
      show
    RUBY
    cmds = JSON.parse(r.full_json)["c"]
    kinds = cmds.map(&:first)
    assert_equal %w[T l Q e x p q s c], kinds, "z order: the circle (z: 2) last, the rest as made"
    assert_equal 0.5, cmds.last[8]
    assert_equal 12, cmds[0][7].length, "a colour per corner of the triangle"
    assert_equal [1.0, 0x41 / 255.0, 0x36 / 255.0, 1.0].map { |v| v.round(4) }, cmds[1][8].map { |v| v.round(4) }, "the line starts red"
    text = cmds[4]
    assert_equal ["Score: 0", 10, 10, 24, 1], text[1, 5]
    t = Ruby2D::Window.current.instance_variable_get(:@objects).grep(Ruby2D::Text).first
    assert t.width.positive?
    assert_equal 30, t.height
  end

  def test_update_runs_each_frame_and_counts_them
    r = run_program(%(require "ruby2d"\nball = Circle.new(x: 0, y: 240, radius: 40)\nseen = []\nupdate do |dt|\n  ball.x += 2\n  seen << dt\nend\nshow))
    ball = r.objects.first
    frame(r, 1000)
    frame(r, 1016)
    frame(r, 1500)
    assert_equal 6, ball.x
    assert_equal 3, r.ticks
    assert_equal 3, r.window.frames
    dts = r.window.instance_variable_get(:@update_proc).binding.local_variable_get(:seen)
    assert_equal [0.0, 0.016, 0.1], dts.map { |d| d.round(3) }, "dt clamped to 0.1 s as the gem does"
  end

  def test_keys_by_sdl_names_down_held_up
    r = run_program(<<~RUBY)
      require "ruby2d"
      log = []
      on(:key_down) { |e| log << "down \#{e.key}" }
      on(:key_held) { |e| log << "held \#{e.key}" }
      on(:key_up) { |e| log << "up \#{e.key}" }
      on(key_down: :space) { log << "space!" }
      update { log << "update" }
      show
      LOG = log
    RUBY
    r.press("space", frames: 2)
    assert_equal ["down space", "space!", "held space", "update", "held space", "update", "up space", "update"],
                 Object.const_get(:LOG)
  ensure
    Object.send(:remove_const, :LOG) if Object.const_defined?(:LOG)
  end

  def test_mouse_and_contains
    r = run_program(<<~RUBY)
      require "ruby2d"
      target = Circle.new(x: 320, y: 240, radius: 40, color: "red")
      $hits = []
      on :mouse_down do |event|
        $hits << [event.button, event.x, event.y, target.contains?(event.x, event.y)]
      end
      target.on(:click) { $hits << :clicked }
      show
    RUBY
    r.click(330, 250)
    r.click(10, 10, button: :right)
    assert_equal [[:left, 330, 250, true], :clicked, [:right, 10, 10, false]], $hits
    assert_equal [10, 10], r.window.mouse_position
  ensure
    $hits = nil
  end

  def test_each_window_is_current_while_its_frame_runs
    a = run_program(%(require "ruby2d"\nset width: 300\n$a = []\nupdate { $a << Window.width; Square.new(size: 1) if $a.length == 1 }\nshow))
    b = run_program(%(require "ruby2d"\nset width: 500\nshow))
    frame(a, 10)
    assert_equal [300], $a
    assert_equal 1, a.objects.length, "made in a's update: added to a, not to b"
    assert_empty b.objects
  ensure
    $a = nil
  end

  def test_show_does_not_block_but_only_once
    error = assert_raises(Ruby2D::Error) { run_program(%(require "ruby2d"\nshow\nshow)) }
    assert_match(/called multiple times/, error.message)
    assert run_program(%(require "ruby2d"\nshow)), "a new cell, a new program"
  end

  def test_close_ends_the_frames
    r = run_program(%(require "ruby2d"\n$closed = 0\non(:close) { $closed += 1 }\non(:key_down) { close }\nshow))
    f = frame(r, 10, "k:x")
    assert r.over?
    assert_equal "", f["over"]
    refute f.key?("next")
    assert_equal 1, $closed
  ensure
    $closed = nil
  end

  def test_an_error_in_a_frame_names_the_line
    r = run_program(%(require "ruby2d"\nupdate do\n  nil.grow\nend\nshow))
    f = frame(r, 10)
    assert_match(/NoMethodError.*grow.*\(line 3\)/, f["error"])
    assert r.over?
  end

  def test_puts_in_a_frame_goes_to_the_log
    r = run_program(%(require "ruby2d"\nupdate { puts "frame \#{Window.frames}" }\nshow))
    assert_equal "frame 0\n", frame(r, 10)["log"]
    assert_equal "frame 1\n", frame(r, 26)["log"]
  end

  def test_fps_cap_slows_the_frames
    r = run_program(%(require "ruby2d"\nset fps_cap: 30\nshow))
    assert_in_delta 1000 + 750.0 / 30, frame(r, 1000)["next"], 1
  end

  def test_fresh_replays_the_cell_into_a_copy
    r = run_program(%(require "ruby2d"\nfox = Square.new(x: 0)\non(:key_held) { fox.x += 5 }\nshow))
    copy = r.fresh
    copy.press(:right, frames: 10)
    assert_equal 50, copy.objects.first.x
    assert_equal 0, r.objects.first.x, "the window below the cell is untouched"
    refute_same r.window, copy.window
  end

  def test_what_is_not_here_says_so_in_the_lessons_language
    Ruby2D.lang__ = "de"
    %w[Sprite Tileset Canvas Button].each do |name|
      error = assert_raises(Ruby2D::Error) { Ruby2D.const_get(name).new("x.png") }
      assert_match(/#{name} gibt es auf dieser Seite nicht/, error.message)
    end
    File.write(path = File.join(Dir.tmpdir, "chunky-r2d.png"), "PNG")
    assert_match(/Image gibt es/, assert_raises(Ruby2D::Error) { Ruby2D::Image.new(path) }.message)
    assert_match(/not found/, assert_raises(Ruby2D::Error) { Ruby2D::Image.new("nowhere.png") }.message)
    Ruby2D.lang__ = "ja"
    assert_match(/Audioはこのページでは使えません/, assert_raises(Ruby2D::Error) { Ruby2D::Audio.new(path) }.message)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_mixing_is_taken_back
    assert_equal Ruby2D::Square, Object.const_get(:Square)
    assert MAIN.respond_to?(:show)
    Ruby2D.unmix__
    refute Object.const_defined?(:Square, false)
    refute MAIN.respond_to?(:show)
    refute MAIN.respond_to?(:update)
    refute "".respond_to?(:warning), "the gem's String colours stay out"
    Ruby2D.mix__(MAIN)
    assert MAIN.respond_to?(:set)
  end

  # every code cell of the lesson runs and shows one window; the exercise's
  # starter and a solution do what the check says
  def test_the_lessons_cells
    %w[de en ja].each do |lang|
      LESSON[lang]["cells"].select { |c| %w[c x].include?(c["t"]) }.each_with_index do |cell, i|
        r = run_program(cell["code"])
        assert r, "#{lang} cell #{i}: no window"
        frame(r, 16)
        r.press(:right, frames: 3)
        r.click(320, 240)
        refute r.over?, "#{lang} cell #{i}: #{r.inspect}"
      end
    end
  end

  def test_the_exercise_check
    check = LESSON["en"]["cells"].find { |c| c["t"] == "x" }
    games = [run_program(check["code"]).fresh]
    refute eval(check["check"]), "the starter walks out"
    solved = check["code"].sub("  fox.x += 5 if event.key?(:right)\n",
                               "  fox.x += 5 if event.key?(:right)\n  fox.x = fox.x.clamp(0, Window.width - fox.width)\n")
    games = [run_program(solved).fresh]
    assert eval(check["check"]), "clamped, he stays"
  end
end
