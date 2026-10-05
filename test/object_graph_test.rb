# Minitest for show_objects (html/object_graph.rb): the walk, the SVG, the
# words for the alt text: ruby test/object_graph_test.rb
require "minitest/autorun"
require "rexml/document"
require_relative "../html/object_graph"

class ObjectGraphTest < Minitest::Test
  def slot_ref(graph, name) = graph.roots.find { |s| s.label == name }.ref

  def test_two_names_one_array
    a = [1, "x"]
    g = ObjectGraph.graph({ a: a, b: a })
    assert_equal slot_ref(g, "a"), slot_ref(g, "b")
    arr = g.nodes[slot_ref(g, "a")]
    assert_equal "Array", arr.title
    assert_equal "1", arr.slots[0].text          # numbers stay inline
    assert_equal :string, g.nodes[arr.slots[1].ref].kind
  end

  def test_dup_is_shallow
    a = ["Speck"]
    g = ObjectGraph.graph({ a: a, b: a.dup })
    refute_equal slot_ref(g, "a"), slot_ref(g, "b")
    first = ->(name) { g.nodes[slot_ref(g, name)].slots[0].ref }
    assert_equal first.("a"), first.("b")
  end

  def test_cycle_terminates_and_shares_node
    a = [1]
    a << a
    g = ObjectGraph.graph({ a: a })
    assert_equal 1, g.nodes.size
    assert_equal 0, g.nodes[0].slots[1].ref
  end

  def test_frozen_and_ivars
    klass = Class.new { def initialize = (@name = "Kaz".freeze; @alter = 3) }
    g = ObjectGraph.graph({ o: klass.new })
    obj = g.nodes[0]
    assert_equal %w[@name @alter], obj.slots.map(&:label)
    assert g.nodes[obj.slots[0].ref].frozen
    assert_equal "3", obj.slots[1].text
  end

  def test_hash_struct_data
    s = Struct.new(:a).new([1])
    d = Data.define(:x).new(x: "y")
    g = ObjectGraph.graph({ h: { k: s, "s" => d } })
    h = g.nodes[0]
    assert_equal [":k", "\"s\""], h.slots.map(&:label)
    assert_equal ["a"], g.nodes[h.slots[0].ref].slots.map(&:label)
    assert g.nodes[h.slots[1].ref].frozen # Data is frozen
  end

  def test_caps
    g = ObjectGraph.graph({ a: (1..30).map(&:to_s) }, max_items: 5, max_nodes: 4)
    arr = g.nodes[0]
    assert_equal 5, arr.slots.size
    assert_equal 25, arr.more
    assert_equal 4, g.nodes.size
    assert arr.slots.last.cut
    deep = [[[[["x"]]]]]
    g = ObjectGraph.graph({ d: deep }, max_depth: 2)
    assert_equal 2, g.nodes.size
  end

  def test_hostile_objects
    basic = BasicObject.new
    liar = Class.new { def inspect = raise("no"); def class = :nope; def frozen? = raise("no") }.new
    g = ObjectGraph.graph({ b: basic, l: liar })
    assert_equal %w[BasicObject], [g.nodes[0].title]
    assert_match(/#<Class/, g.nodes[1].title) # anonymous class
  end

  def test_binding_skips_underscore
    x = [1]
    _y = 2
    g = ObjectGraph.graph(binding)
    assert_includes g.roots.map(&:label), "x"
    assert_equal x.size, g.nodes[0].slots.size
    refute_includes g.roots.map(&:label), "_y"
  end

  def test_svg_is_wellformed_and_escaped
    svg = ObjectGraph.svg({ "<b>" => ["a&b", "<i>", "キツネ"] })
    doc = REXML::Document.new(svg)
    assert_equal "svg", doc.root.name
    assert_includes svg, "&lt;b&gt;"
    pic = show_objects(a: [1])
    assert pic.to_data_url.start_with?("data:image/svg+xml;base64,")
  end

  def test_show_objects_names_and_options_together
    deep = [[[["x"]]]]
    svg = show_objects(d: deep, max_depth: 2).svg
    refute_includes svg, "max_depth"
    assert_equal ObjectGraph.svg({ d: deep }, max_depth: 2), svg
  end

  # the alt text: the arrows in words, so a screen reader hears what is shared
  def test_describe_says_what_the_arrows_show
    breakfast = ["egg", 1]
    g = ObjectGraph.graph({ breakfast: breakfast, same: breakfast, copy: breakfast.dup.freeze })
    assert_equal 'breakfast → #1, same → #1, copy → #2. #1 Array: 0 → #3, 1 → 1. ' \
                 '#2 Array ❄: 0 → #3, 1 → 1. #3 String "egg".', g.describe
    assert_equal g.describe, show_objects(breakfast: breakfast, same: breakfast, copy: breakfast.dup.freeze).alt_text
  end

  def test_describe_counts_what_is_cut
    g = ObjectGraph.graph({ a: (1..12).to_a }, max_items: 3)
    assert_equal "a → #1. #1 Array: 0 → 1, 1 → 2, 2 → 3, … 9 more.", g.describe
  end

  # where there is a show_image (main.rb, the check harness, the gem), the
  # picture goes there
  def test_show_objects_goes_through_show_image
    shown = []
    host = Object.new
    host.define_singleton_method(:show_image) { |image| shown << image }
    assert_nil host.show_objects(a: [1])
    assert_instance_of ObjectGraph::Picture, shown.first
    assert_includes shown.first.alt_text, "a → #1"
  end

  # the companion gem ships its own copy, so a program on a computer draws
  # the same picture
  def test_the_gems_copy_is_this_file
    html = File.expand_path("../html/object_graph.rb", __dir__)
    gem = File.expand_path("../gem/chunky_bacon/lib/chunky_bacon/object_graph.rb", __dir__)
    assert File.read(html) == File.read(gem),
           "gem/chunky_bacon/lib/chunky_bacon/object_graph.rb differs from html/object_graph.rb - copy it over"
  end
end
