# html/microscope.rb under CRuby: the YARV simulator gets the same result
# as Ruby itself for code of every kind the lessons use (and more), its
# steps have frames and sentences, unsupported code says so; the pictures
# draw without raising.
#
#   ruby test/microscope_rb_test.rb
require "minitest/autorun"
require_relative "../html/microscope"

class MicroscopeRbTest < Minitest::Test
  PROGRAMS = [
    "a = 1 + 2\nputs a * 3\na",
    "def msc_sq(x) = x * x\nmsc_sq(4) + 1",
    "sum = 0\n[1, 2, 3].each { |i| sum += i }\nsum",
    "x = 2 * 3 + 4\nx > 5 ? :big : :small",
    "case 2\nwhen 1 then :a\nwhen 2 then :b\nend",
    "case \"x\"\nwhen /y/ then 1\nelse 2\nend",
    "def msc_twice = yield(yield(1))\nmsc_twice { |v| v * 10 }",
    "count = 0\ninc = -> { count += 1 }\ninc.call\ninc.call\ncount",
    "def msc_counter\n  n = 0\n  -> { n += 1 }\nend\nf = msc_counter\nf.call\nf.call",
    "s = \"chunky\"\ns << \" bacon\"\ns.upcase",
    "words = %w[a bb ccc]\nwords.map { |w| w.size }.sum",
    "def msc_fact(n) = n <= 1 ? 1 : n * msc_fact(n - 1)\nmsc_fact(5)",
    "i = 0\nwhile i < 3\n  i += 1\nend\ni",
    "h = { fox: 1 }\nh[:bacon] = 2\nh.size",
    "a, b = [1, 2]\nb - a",
    "\"#{1 + 1} foxes\"",
    "[3, 9].max + (1..4).sum",
    "def msc_opt(a, b = 10) = a + b\nmsc_opt(1) + msc_opt(1, 2)",
    "Struct.new(:x).new(4).x"
  ].freeze

  def test_the_simulator_agrees_with_ruby
    PROGRAMS.each do |code|
      data = Microscope::Yarv.new(code).run
      assert data["same"], "#{code.inspect}: #{data["result"]} vs #{data["real"]} #{data["error"].inspect}"
      assert_equal "done", data["steps"].last["note"].first
    end
  end

  def test_steps_show_frames_ep_and_output
    data = Microscope::Yarv.new("sum = 0\n[1, 2].each { |i| sum += i }\nputs sum\nsum").run
    block_step = data["steps"].find { |s| s["frames"].size == 3 }
    kinds = block_step["frames"].map { |f| f["kind"] }
    assert_equal %w[top cfunc block], kinds
    assert_equal block_step["frames"].first["id"], block_step["frames"].last["ep"]
    assert(data["steps"].any? { |s| s["note"].first == "getOuter" })
    assert_equal "3\n", data["output"]
  end

  def test_an_env_left_behind_is_on_the_heap
    data = Microscope::Yarv.new("def msc_mk\n  n = 0\n  -> { n += 1 }\nend\nf = msc_mk\nf.call").run
    lambda_step = data["steps"].find { |s| s["frames"].any? { |f| f["kind"] == "block" } }
    block = lambda_step["frames"].find { |f| f["kind"] == "block" }
    assert_equal false, block["epLive"]
  end

  def test_unsupported_code_says_so
    data = Microscope::Yarv.new("class MscTmp; end\n1").run
    refute data["same"]
    assert_equal "unsupported", data["error"].first
  end

  def test_pictures_draw
    assert_match(/<svg/, Microscope.tokens_svg("x = 1 if y?").to_svg)
    assert_match(/LocalVariableWrite/, Microscope.ast_svg("total = price * 2").to_svg)
    assert_match(/Fixnum/, Microscope.value_svg([7, nil, :fox, "x"]).alt_text)
    assert_match(/STRING/, Microscope.slots_svg(["x", "a" * 1000]).alt_text)
    assert_match(/<rect/, Microscope.bars_svg({ "a" => 1, "b" => 2 }).to_svg)
    mod = Module.new { def msc_hi = "m" }
    klass = Class.new { include mod }
    frames = Microscope.lookup_frames(klass.new, :msc_hi)
    assert_equal "lookupDone", frames.last["note"].first
    a = ["x", ["y"]]
    gc = Microscope.gc_frames({ a: a }, [["lost"]])
    assert_equal "gcSweep", gc.last["note"].first
    assert_equal "2", gc.last["note"][1]   # the Array and its String
  end
end
