require_relative "harness"

# html/shell/jsg.rb: the jsg gem's syntax on PicoRuby's interop
class JsgTest < Minitest::Test
  def setup
    @obj = JS.to_rb({ "name" => "Chunky", "empty" => "", "zero" => 0, "yes" => true, "no" => false,
                      "list" => [1, 2], "greet" => proc { |who| "hi #{who}" }, "Ctor" => proc { :constructed } })
  end

  def test_setter_writes_the_property
    @obj.name = "Kaz"
    assert_equal "Kaz", @obj[:name]
  end

  def test_setter_returns_the_value
    assert_equal 5, (@obj.count = 5)
  end

  def test_nested_setter
    style = JS.to_rb({ "style" => {} })
    style.style.display = "none"
    assert_equal "none", style.style[:display]
  end

  def test_reads_and_calls_go_to_picoruby
    assert_equal "Chunky", @obj.name
    assert_equal "hi Isi", @obj.greet("Isi")
  end

  def test_predicates_use_javascript_truthiness
    assert @obj.name?
    assert @obj.yes?
    refute @obj.no?
    refute @obj.empty?
    refute @obj.zero?
    assert @obj.list?, "an object is true"
    refute @obj.missing?
  end

  def test_predicate_calls_a_function
    assert @obj.greet?("x")
  end

  def test_capitalized_name_is_the_property_not_a_call
    ctor = @obj.Ctor
    assert ctor.is_a?(JS::Object)
    assert_equal :function, ctor.typeof
  end

  def test_each_iterates_what_picoruby_would_skip
    seen = []
    @obj.list.each { |x| seen << x }
    assert_equal [1, 2], seen
  end

  def test_setter_detection
    assert JSG.setter?("innerText=")
    assert JSG.setter?("_x=")
    refute JSG.setter?("==")
    refute JSG.setter?("[]=")
    refute JSG.setter?("a=b=")
  end

  def test_truthy
    refute JSG.truthy?(nil)
    refute JSG.truthy?(false)
    refute JSG.truthy?(0)
    refute JSG.truthy?("")
    assert JSG.truthy?("0")
    assert JSG.truthy?(@obj)
  end

  def test_shortcuts
    JS.reset!
    assert JSG.w == JS.global
    assert JSG.d == JS.document
    assert_equal JSG.q("#lessonNav").to_a.length, 1
  end
end
