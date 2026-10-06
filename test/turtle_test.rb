# Minitest for turtle graphics (html/turtle.rb): the recorded path, the
# check helpers lesson 10 grades with, the SVG, the safety nets, the words
# for the alt text: ruby test/turtle_test.rb
require "minitest/autorun"
require "rexml/document"
require_relative "../html/turtle"

class TurtleTest < Minitest::Test
  def teardown
    Turtle.lang = nil
    Turtle.animations = nil
  end

  def draw(&block) = Turtle.new.tap { |t| t.instance_eval(&block) }

  def koch(t, length, depth)
    return t.forward(length) if depth.zero?

    koch(t, length / 3.0, depth - 1)
    t.left 60
    koch(t, length / 3.0, depth - 1)
    t.right 120
    koch(t, length / 3.0, depth - 1)
    t.left 60
    koch(t, length / 3.0, depth - 1)
  end

  def test_square
    sq = draw { 4.times { forward 100; right 90 } }
    assert sq.regular_polygon?(4, 100)
    refute sq.regular_polygon?(4, 90)
    assert sq.closed?
    assert_equal 1, sq.winding
    assert_in_delta 10_000, sq.area, 1e-6
    assert_equal [0.0, 0.0], sq.position
    assert_equal "#<Turtle 4 lines, Chunky at (0, 0) looking 0°>", sq.inspect
  end

  def test_star_goes_round_twice
    star = draw { 5.times { forward 160; right 144 } }
    assert star.regular_polygon?(5, 160)
    assert_equal 2, star.winding
  end

  def test_koch_snowflake
    flake = Turtle.new
    3.times { koch(flake, 270, 3); flake.right 120 }
    assert_equal 192, flake.lines.size
    assert flake.closed?
    assert(flake.lines.all? { |l| (l.length - 10).abs < 0.01 })
    assert_equal 1, flake.winding
    # 1 + 1/3 + 4/27 + 16/243 of the triangle (8/5 at infinite depth)
    assert_in_delta 1.547, flake.area / (Math.sqrt(3) / 4 * 270**2), 0.001
    assert_empty flake.corners.map(&:round) - [60, -60, 120, -120]
  end

  def test_edges_join_a_side_drawn_in_two_steps
    split = draw { 4.times { forward 50; forward 50; right 90 } }
    assert_equal 8, split.lines.size
    assert_equal 4, split.edges.size
    assert split.regular_polygon?(4, 100)
  end

  def test_same_shape_and_open_paths
    big = draw { 4.times { forward 100; right 90 } }
    small = draw { 4.times { forward 30; right 90 } }
    assert big.same_shape?(small, scale: true)
    refute big.same_shape?(small)
    refute draw { forward 10; right 90; forward 10 }.closed?
  end

  def test_pen_up_moves_draw_nothing
    t = draw { pen_up; forward 50; pen_down; forward 20; jump 10; back 5 }
    assert_equal 2, t.lines.size
    assert_equal [0.0, 75.0], t.position
  end

  # the turtle helper: bare commands in the block, the learner's own
  # methods too, and the picture goes to show_image
  def test_turtle_helper_shows_the_picture
    shown = []
    host = Object.new
    host.define_singleton_method(:show_image) { |image| shown << image.to_data_url }
    # a method defined at the top level of a cell is a private one of Object
    Object.send(:define_method, :turtle_test_side) { forward 10 }
    Object.send(:private, :turtle_test_side)
    t = host.send(:turtle) { 3.times { turtle_test_side; right 120 } }
    assert t.regular_polygon?(3, 10)
    assert_equal 1, shown.size
    assert shown.first.start_with?("data:image/svg+xml;base64,")
    assert Turtle.from(shown).first.regular_polygon?(3, 10)
    assert_equal [], Turtle.from(["data:image/png;base64,xyz"])
  ensure
    Object.send(:remove_method, :turtle_test_side)
  end

  # what a check sees is a snapshot: drawing on afterwards changes nothing
  def test_from_images_is_a_snapshot
    t = draw { forward 10 }
    url = t.to_data_url
    t.forward 10
    assert_equal 1, Turtle.from([url]).first.lines.size
  end

  def test_svg_is_wellformed_and_animated_unless_still
    t = draw { color "hsl(120, 80%, 40%)"; 4.times { forward 100; right 90 } }
    animated = t.to_svg
    REXML::Document.new(animated)
    assert_includes animated, "animateMotion"
    still = t.to_svg(animate: false)
    REXML::Document.new(still)
    refute_includes still, "animateMotion"
  end

  # during a live run main.rb asks for stills
  def test_animations_off_gives_stills
    host = Object.new
    host.define_singleton_method(:show_image) { |_image| nil }
    Turtle.animations = false
    refute_includes host.send(:turtle) { forward 10 }.to_svg, "animateMotion"
    Turtle.animations = true
    assert_includes host.send(:turtle) { forward 10 }.to_svg, "animateMotion"
  end

  def test_safety_nets
    error = assert_raises(Turtle::TooFar) { draw { loop { forward 1 } } }
    assert_match(/tired/, error.message)
    error = assert_raises(Turtle::TooFar) { draw { loop { right 90 } } }
    assert_match(/dizzy/, error.message)
    # colours go into SVG attributes
    assert_raises(ArgumentError) { Turtle.new.color("red\" onload=\"x") }
  end

  def test_alt_text_and_errors_in_the_lesson_language
    t = draw { 4.times { forward 100; right 90 } }
    assert_equal "Chunky drew 4 lines", t.alt_text
    assert_equal "Chunky drew 1 line", draw { forward 1 }.alt_text
    Turtle.lang = "de"
    assert_equal "Chunky hat 4 Striche gezeichnet", t.alt_text
    assert_match(/keine Farbe/, assert_raises(ArgumentError) { t.color("nope!") }.message)
    Turtle.lang = "ja"
    assert_equal "Chunkyが線を4本かきました", t.alt_text
    assert_includes t.to_svg, "<title>Chunkyが線を4本かきました</title>"
    Turtle.lang = "fr"
    assert_equal "Chunky drew 4 lines", t.alt_text
    # every language says everything
    keys = Turtle::TEXTS["en"].keys
    Turtle::TEXTS.each_value { |texts| assert_equal keys, texts.keys }
  end

  # the companion gem ships its own copy, so `turtle { }` draws the same
  # picture on a computer
  def test_the_gems_copy_is_this_file
    html = File.expand_path("../html/turtle.rb", __dir__)
    gem = File.expand_path("../gem/chunky_bacon/lib/chunky_bacon/turtle.rb", __dir__)
    assert File.read(html) == File.read(gem),
           "gem/chunky_bacon/lib/chunky_bacon/turtle.rb differs from html/turtle.rb - copy it over"
  end
end
