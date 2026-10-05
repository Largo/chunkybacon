# Minitest for the walk and the SVG: ruby object_graph_test.rb
require "minitest/autorun"
require "rexml/document"
require_relative "object_graph"

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
end
