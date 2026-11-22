# html/funicular_cells.rb under CRuby: Funicular's vendored Ruby loads, a
# cell's code runs, Funicular.start is recorded, and the headless mount
# renders, clicks, types and re-renders as the page would.
#
#   ruby test/funicular_test.rb
require "minitest/autorun"
require_relative "../html/funicular_cells"

ChunkyFunicular.fetch_text = lambda do |path|
  file = File.expand_path("../html/#{path}", __dir__)
  File.exist?(file) ? File.read(file) : nil
end

class FunicularTest < Minitest::Test
  COUNTER = <<~RUBY
    class TestZaehler < Funicular::Component
      def initialize_state
        { n: 0 }
      end

      def plus(event)
        patch(n: state[:n] + 1)
      end

      def render
        div do
          p { "Zahl: \#{state[:n]}" }
          button(onclick: :plus) { "+1" }
        end
      end
    end

    Funicular.start(TestZaehler, container: "app")
  RUBY

  def test_counter_renders_and_clicks
    app = funicular(COUNTER)
    assert_equal TestZaehler, app.component
    mounted = app.mount
    assert_equal "Zahl: 0 +1", mounted.text
    mounted.click("+1").click("+1")
    assert_equal 2, mounted.state[:n]
    assert_includes mounted.html, "<p>Zahl: 2</p>"
  end

  def test_input_and_children_with_props
    app = funicular(<<~RUBY)
      class TestStern < Funicular::Component
        def render
          button(class: "stern", onclick: -> { props[:waehlen].call(props[:nr]) }) { props[:an] ? "*" : "." }
        end
      end

      class TestBewertung < Funicular::Component
        def initialize_state = { sterne: 0, name: "" }

        def tippen(event)
          patch(name: event.target[:value].to_s)
        end

        def render
          div do
            input(value: state[:name], oninput: :tippen)
            p { "Hallo, \#{state[:name]}!" }
            div do
              [1, 2, 3].each do |nr|
                component(TestStern, nr: nr, an: nr <= state[:sterne], waehlen: ->(n) { patch(sterne: n) })
              end
            end
          end
        end
      end

      Funicular.start(TestBewertung, container: "app")
    RUBY
    mounted = app.mount
    mounted.type("input", "Chunky")
    assert_includes mounted.text, "Hallo, Chunky!"
    mounted.fire(".stern", :click)
    assert_equal 1, mounted.state[:sterne]
    stars = mounted.elements.select { |n| n.props[:class] == "stern" }
    assert_equal ["*", ".", "."], stars.map { |n| n.children.join }
  end

  def test_a_rerun_forgets_deleted_methods
    funicular(COUNTER)
    assert TestZaehler.method_defined?(:plus)
    funicular(COUNTER.sub(/def plus.*?end\n/m, ""))
    refute TestZaehler.method_defined?(:plus)
  end

  def test_errors_keep_the_line
    bind = binding
    error = assert_raises(NameError) { funicular("x = 1\nundefined_thing_here\n", bind) }
    assert_match(/undefined_thing_here/, error.message)
    assert(error.backtrace_locations.any? { |l| l.lineno == 2 })
  end

  def test_render_errors_surface_before_the_preview
    assert_raises(NoMethodError) do
      funicular(<<~RUBY)
        class TestKaputt < Funicular::Component
          def render
            div { nil.upcase }
          end
        end
        Funicular.start(TestKaputt, container: "app")
      RUBY
    end
  end

  def test_cell_source
    assert_equal %(funicular("1 + 1", binding)), ChunkyFunicular.cell_source("1 + 1")
  end
end
