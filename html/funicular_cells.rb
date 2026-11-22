# The Funicular lesson's kernel side (lesson `funicular`). Funicular
# (https://github.com/picoruby/funicular, by HASUMI Hitoshi) is a framework
# for web apps in Ruby: components with state, a virtual DOM, PicoRuby.wasm
# in the browser. The course's PicoRuby.wasm has it compiled in, so the page
# runs each cell's app for real, in a preview below the cell
# (funicular_frame.js: a fresh PicoRuby in an iframe of its own).
#
# Before that, CRuby runs the same code here, with Funicular's own Ruby
# (html/funicular/vendor/, tools/vendor_funicular.rb - the files of the
# commit the wasm was built with) loaded the way Funicular's SSR loads it
# on a server (Funicular.server = true: no DOM). So a typo or a NameError is
# explained like in any lesson, with its line, before the preview starts,
# and an exercise's check can mount the component headless and click it:
#
#   app = result.mount          # result: what funicular(...) answered
#   app.text                    # => "Ampel: rot Weiter"
#   app.click("Weiter")         # the button's onclick, as a click would
#   app.state[:farbe]           # => "grün"
#
# In the lesson ("funicular": true in lessons.js) a cell's code is the
# program as it stands; ChunkyFunicular.cell_source wraps it in
# funicular(code, binding). Plain Ruby, no JS: the check harness runs it.
module ChunkyFunicular
  # in load order, as Funicular's SSR loads them (tools/vendor_funicular.rb)
  FILES = %w[
    0_tags environment_inquirer vdom html_serializer differ patcher styles
    runtime view_context debug component error_boundary router 0_validations
    1_validators db relation model store store_singleton store_collection
    form_builder http cable file_upload funicular
  ].freeze

  # What funicular(...) answers: the program and the component it started
  # (Funicular.start(Klass, container: "app")), nil if it started none.
  class App
    attr_reader :source, :component, :props

    def initialize(source, component, props)
      @source = source
      @component = component
      @props = props || {}
    end

    def started? = !@component.nil?

    # a fresh, headless instance of the started component
    def mount
      raise ArgumentError, "Funicular.start(...) was not called" unless @component

      Headless.new(@component, @props)
    end

    def html = mount.html

    def inspect = @component ? "#<Funicular app #{@component}>" : "#<Funicular program>"
    alias_method :to_s, :inspect
  end

  # A component mounted without a browser: the virtual DOM it renders, with
  # the child components expanded, and its handlers callable as a click or
  # a keystroke would call them. patch re-renders it, as on the page.
  class Headless
    # an element of the rendered tree; +owner+ is the component that
    # rendered it, the one a Symbol handler is sent to
    Node = Struct.new(:tag, :props, :children, :owner)

    # what a handler gets as its event: event.target[:value], .preventDefault
    class Target
      def initialize(value = "", checked = false)
        @attrs = { value: value, checked: checked }
      end

      def [](key) = @attrs[key.to_sym]

      def []=(key, value)
        @attrs[key.to_sym] = value
      end

      def value = @attrs[:value]
      def checked = @attrs[:checked]
    end

    class Event
      attr_reader :target, :type

      def initialize(type, target = Target.new, key: nil)
        @type = type
        @target = target
        @key = key
      end

      def [](name)
        case name.to_sym
        when :target, :currentTarget then @target
        when :type then @type
        when :key then @key
        end
      end

      def key = @key
      def currentTarget = @target
      def preventDefault = nil
      def stopPropagation = nil
    end

    attr_reader :root, :tree

    def initialize(klass, props = {})
      @children = {}
      @root = klass.new(props)
      prepare(@root)
      refresh
    end

    def state = @root.state

    # the page as HTML, the way the browser holds it
    def html = serialize(@tree)

    # its text, as a reader sees it: tags gone, spaces squeezed
    def text = text_of(@tree).gsub(/\s+/, " ").strip

    # every element, depth first
    def elements(node = @tree, out = [])
      return out unless node.is_a?(Node)

      out << node
      node.children.each { |child| elements(child, out) }
      out
    end

    # an element by "#id", ".class", a tag name, or the text on it
    # (a button's label): the first that has +event+ if any has
    def find(what, event = nil)
      all = elements
      hits = case what.to_s
             when /\A#(.+)/ then all.select { |n| n.props[:id].to_s == Regexp.last_match(1) }
             when /\A\.(.+)/
               name = Regexp.last_match(1)
               all.select { |n| n.props[:class].to_s.split.include?(name) }
             else
               label = what.to_s.strip
               by_text = all.select { |n| text_of(n).strip == label }
               by_text = all.select { |n| text_of(n).include?(label) } if by_text.empty?
               by_tag = all.select { |n| n.tag.to_s == label }
               by_text.empty? ? by_tag : by_text
             end
      hits = hits.select { |n| handler(n, event) } if event && hits.any? { |n| handler(n, event) }
      # the first match, but the innermost of nested ones: the button, not
      # the div around it that has the same text
      hits.find { |n| hits.none? { |m| !m.equal?(n) && elements(n).any? { |d| d.equal?(m) } } }
    end

    def click(what) = fire(what, :click)

    # types +value+ into an input: oninput, then onchange, as typing does
    def type(what, value)
      node = find(what, :input) || find(what, :change)
      raise ArgumentError, "no input #{what.inspect}" unless node

      target = Target.new(value.to_s)
      fired = false
      %i[input change].each do |name|
        next unless handler(node, name)

        call(node, name, Event.new(name.to_s, target))
        fired = true
      end
      raise ArgumentError, "#{what.inspect} has no oninput or onchange" unless fired

      self
    end

    def key(what, key)
      fire(what, :keydown, Event.new("keydown", Target.new(""), key: key))
    end

    def submit(what = "form") = fire(what, :submit)

    def fire(what, name, event = Event.new(name.to_s))
      node = find(what, name)
      raise ArgumentError, "nothing to #{name}: #{what.inspect}" unless node && handler(node, name)

      call(node, name, event)
      self
    end

    # patch calls this, on the root and on a child (see prepare)
    def refresh
      @seen = {}
      @tree = expand(@root.build_vdom, @root, "0")
      @children.select! { |path, _| @seen[path] }
      self
    end

    private

    def prepare(component)
      component.instance_variable_set(:@mounted, true)
      component.runtime = Funicular::Runtime.new(nil)
      headless = self
      # the page's re_render diffs and patches the DOM; here the tree is
      # built again
      component.define_singleton_method(:re_render) { headless.refresh }
    end

    def expand(vnode, owner, path)
      case vnode
      when Funicular::VDOM::Element
        kids = []
        vnode.children.flatten.each_with_index do |child, i|
          kid = expand(child, owner, "#{path}.#{i}")
          kids << kid unless kid.nil?
        end
        Node.new(vnode.tag.to_s, vnode.props, kids, owner)
      when Funicular::VDOM::Text then vnode.content.to_s
      when Funicular::VDOM::Component
        @seen[path] = true
        child = @children[path]
        if child.nil? || !child.is_a?(vnode.component_class)
          child = vnode.component_class.new(vnode.props)
          prepare(child)
          @children[path] = child
        else
          child.instance_variable_set(:@props, vnode.props)
        end
        child.children = vnode.children if child.respond_to?(:children=)
        expand(child.build_vdom, child, path)
      when nil then nil
      when Array then Node.new("#fragment", {}, vnode.map.with_index { |v, i| expand(v, owner, "#{path}.#{i}") }.compact, owner)
      else vnode.to_s
      end
    end

    def handler(node, name)
      node.props.each { |key, value| return value if key.to_s.downcase == "on#{name}" }
      nil
    end

    def call(node, name, event)
      value = handler(node, name)
      case value
      when Symbol
        method = node.owner.method(value)
        method.arity.zero? ? method.call : method.call(event)
      when Proc, Method
        value.arity.zero? ? value.call : value.call(event)
      else
        raise ArgumentError, "on#{name}: #{value.inspect} is no handler"
      end
    end

    def text_of(node)
      return node.to_s unless node.is_a?(Node)

      node.children.map { |child| text_of(child) }.join(" ")
    end

    def serialize(node)
      return escape(node.to_s) unless node.is_a?(Node)

      inner = node.children.map { |child| serialize(child) }.join
      return inner if node.tag == "#fragment"

      attrs = node.props.filter_map do |key, value|
        name = key.to_s
        next if %w[key ref].include?(name) || name.downcase.start_with?("on") || value.nil? || value == false

        value == true ? " #{name}" : " #{name}=\"#{escape(value.to_s).gsub('"', '&quot;')}\""
      end.join
      %w[input br hr img].include?(node.tag) ? "<#{node.tag}#{attrs}>" : "<#{node.tag}#{attrs}>#{inner}</#{node.tag}>"
    end

    def escape(text) = text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  # records what Funicular.start was given (it does no DOM work here)
  module StartHook
    def start(component_class = nil, container: "app", props: {}, hydrate: false, &block)
      ChunkyFunicular.started = [component_class, props] if component_class
      super
    end
  end

  class << self
    # ->(path) { the file's text, or nil }: fetchTextSync in the page,
    # File.read in the tests
    attr_accessor :fetch_text, :started

    def loaded? = @loaded == true

    # Funicular's Ruby, once per page: ~400 KB, fetched when a cell of the
    # lesson first runs
    def load!
      return if @loaded

      # patch asks whether a value is a JS::Object (ruby.wasm has one, plain
      # CRuby in the tests does not): nothing in a cell's state ever is
      Object.const_set(:JS, Module.new) unless defined?(::JS)
      ::JS.const_set(:Object, Class.new) unless ::JS.const_defined?(:Object, false)
      FILES.each do |name|
        source = fetch_text&.call("funicular/vendor/#{name}.rb")
        raise LoadError, "could not load Funicular (funicular/vendor/#{name}.rb)" unless source

        TOPLEVEL_BINDING.eval(source, "funicular/#{name}.rb", 1)
      end
      ::Funicular.server = true
      ::Funicular.singleton_class.prepend(StartHook)
      @loaded = true
    end

    # What a cell of a lesson with "funicular": true runs: its code IS the
    # program, handed to funicular(...) with the cell's binding, so its
    # errors keep the cell's file name and line.
    def cell_source(code)
      return code if code.match?(/\bfunicular\s*\(/)

      "funicular(#{code.inspect}, binding)"
    end

    # A run starts clean: a component the code defines is removed first, so
    # a method the learner deleted is gone (CRuby would keep it from the
    # last run; the preview's PicoRuby is new every time anyway).
    def forget_components(source)
      source.scan(/^\s*class\s+([A-Z]\w*)\s*</).flatten.uniq.each do |name|
        next unless Object.const_defined?(name, false)

        klass = Object.const_get(name)
        Object.send(:remove_const, name) if klass.is_a?(Class) && klass < ::Funicular::Component
      end
    end

    def run(source, bind)
      load!
      forget_components(source)
      self.started = nil
      file = begin
        bind.eval("__FILE__")
      rescue StandardError
        "(funicular)"
      end
      bind.eval(source, file, 1)
      component, props = started
      app = App.new(source, component, props)
      # render it once now: an error in initialize_state or render is
      # explained with its line here, before the preview starts
      app.mount if app.started?
      app
    end
  end
end

module Kernel
  # Runs +source+, a Funicular app: here headless (CRuby, Funicular's own
  # Ruby), then on the page in a preview below the cell (PicoRuby.wasm).
  # Answers a ChunkyFunicular::App, which a check can mount and click.
  def funicular(source, bind = TOPLEVEL_BINDING.dup)
    raise ArgumentError, "funicular takes the program as a String" unless source.is_a?(String)

    app = ChunkyFunicular.run(source, bind)
    ChunkyApp.instance.add_funicular(app) if defined?(ChunkyApp) && ChunkyApp.respond_to?(:instance)
    app
  end
end
