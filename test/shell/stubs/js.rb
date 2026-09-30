# PicoRuby.wasm's `js` interop for CRuby, so html/shell/*.rb loads and runs
# under Minitest. It copies what PicoRuby 4.0.3 does (probed in Chrome,
# docs/PICORUBY_SHELL.md), including what trips code up there:
#
# - property reads come back as Ruby values: String, Integer, Float,
#   true/false, nil for null AND undefined; objects stay JS::Object
# - a dot read of a missing property answers nil and logs
#   "Method not found or not a function" (JS.console_errors)
# - JS::Object is a BasicObject: no Kernel methods (display, select, ...)
# - Hash, Array and Symbol arguments raise TypeError ("Unsupported argument
#   type"); a string with "\n" or "\t" next to a non-string argument makes
#   the call fail ("Bad control character ... in JSON")
# - JS::Object#each yields nothing (use to_a, or jsg's each)
# - a Task's block runs with another self
#
# The DOM is a small tree: innerHTML is parsed (well-formed markup only),
# and getElementById / querySelector(All) / closest understand the selectors
# the shell uses: tag, #id, .class, [attr], [attr='value'], combined.
require "json"

module JS
  class << self
    attr_accessor :console_errors, :window, :documents

    def global = window
    def document = window.__target.document_node.wrap

    def to_rb(value)
      case value
      when ::Hash, ::Array, ::Proc, Node then Object.new(value)
      else value
      end
    end

    def to_js(value)
      value.is_a?(Object) ? value.__target : value
    end

    def reset!
      self.console_errors = []
      self.window = Object.new(Window.new)
    end
  end

  class Object < BasicObject
    def self.register_callback(*) = nil

    def initialize(target)
      @target = target
    end

    def __target = @target
    def is_a?(klass) = klass == ::JS::Object || klass == ::BasicObject
    alias kind_of? is_a?
    def ==(other) = other.is_a?(::JS::Object) && ::JS.to_js(other).equal?(@target)
    def typeof = @target.is_a?(::Proc) ? :function : :object
    def inspect = "#<JS::Object #{@target.class}>"
    def to_s = inspect
    def each(&) = self   # PicoRuby's own each on a NodeList: nothing

    def to_a
      list = @target.is_a?(Node) ? @target.js_list : @target
      list.is_a?(::Array) ? list.map { |item| ::JS.to_rb(item) } : []
    end

    def to_binary = ::JS.to_rb(@target.is_a?(::Hash) ? @target["__body"] : nil)

    def [](key) = ::JS.to_rb(get(key.to_s))

    def []=(key, value)
      set(key.to_s, ::JS.to_js(value))
    end

    def addEventListener(type, sync: false, &block)
      listeners = get("__listeners") || set("__listeners", {})
      (listeners[type.to_s] ||= []) << block
      nil
    end

    def method_missing(name, *args, &block)
      key = name.to_s
      value = get(key)
      if value.is_a?(::Proc)
        ::JS.check_args(key, args)
        return ::JS.to_rb(value.call(*args.map { |a| ::JS.to_js(a) }, &block))
      end
      if value.nil? && !has?(key)
        ::JS.console_errors << "Method not found or not a function: #{key}"
        return nil
      end
      ::JS.to_rb(value)
    end

    def respond_to_missing?(*) = true

    private

    def has?(key)
      case @target
      when ::Hash then @target.key?(key)
      when Node then @target.js_has?(key)
      when ::Array then key == "length"
      else false
      end
    end

    def get(key)
      case @target
      when ::Hash then @target[key]
      when Node then @target.js_get(key)
      when ::Array then key == "length" ? @target.length : @target[key.to_i]
      end
    end

    def set(key, value)
      case @target
      when ::Hash then @target[key] = value
      when Node then @target.js_set(key, value)
      end
      value
    end
  end

  # PicoRuby's argument checks (see the top of this file)
  def self.check_args(name, args)
    bad = args.find { |a| a.is_a?(::Hash) || a.is_a?(::Array) || a.is_a?(::Symbol) }
    raise TypeError, "Unsupported argument type for #{name} at position: #{args.index(bad)}" if bad

    mixed = args.any? { |a| !a.is_a?(::String) }
    if mixed && args.any? { |a| a.is_a?(::String) && a.match?(/[\n\t]/) }
      raise "Bad control character in string literal in JSON (#{name})"
    end
  end

  # ---------- the DOM ----------

  class Node
    VOID = %w[br img input hr meta link wbr source area col].freeze
    attr_accessor :parent
    attr_reader :tag, :attrs, :children, :props

    def initialize(tag, attrs = {})
      @tag = tag
      @attrs = attrs
      @children = []
      @props = {}
      @wrapper = nil
    end

    def wrap = (@wrapper ||= JS::Object.new(self))
    def text? = tag == "#text"
    def elements = children.reject(&:text?)
    def js_list = nil

    def js_has?(key) = js_get(key) != nil || props.key?(key) || %w[hidden disabled value title].include?(key)

    def js_get(key)
      case key
      when "id" then attrs["id"]
      when "className" then attrs["class"].to_s
      when "tagName" then tag.upcase
      when "innerHTML" then children.map(&:html).join
      when "textContent", "innerText" then text
      when "classList" then ClassList.new(self)
      when "style" then (props["style"] ||= {})
      when "firstChild" then children.first
      when "offsetWidth" then 0
      when "hidden", "disabled" then props.fetch(key, attrs.key?(key))
      when "value" then props.fetch("value", attrs["value"].to_s)
      when "title" then props.fetch("title", attrs["title"])
      else
        method = "js_#{key}"
        respond_to?(method) ? proc { |*args, &block| send(method, *args, &block) } : props[key]
      end
    end

    def js_set(key, value)
      case key
      when "id" then attrs["id"] = value
      when "className" then attrs["class"] = value.to_s
      when "innerHTML" then replace_children(HTML.parse(value.to_s))
      when "textContent", "innerText" then replace_children([Node.text(value.to_s)])
      else props[key] = value
      end
    end

    def self.text(content) = new("#text", "content" => content)

    def text = text? ? attrs["content"] : children.map(&:text).join

    def html
      return attrs["content"] if text?

      inner = attrs.reject { |k, _| k == "content" }.map { |k, v| %( #{k}="#{v}") }.join
      VOID.include?(tag) ? "<#{tag}#{inner}>" : "<#{tag}#{inner}>#{children.map(&:html).join}</#{tag}>"
    end

    def replace_children(nodes)
      children.each { |c| c.parent = nil }
      @children = []
      nodes.each { |n| js_appendChild(n) }
    end

    def descendants = elements.flat_map { |e| [e] + e.descendants }

    # ---- DOM methods (JS functions on the element) ----
    def js_getAttribute(name) = attrs[name.to_s]
    def js_setAttribute(name, value) = (attrs[name.to_s] = value.to_s) && nil
    def js_hasAttribute(name) = attrs.key?(name.to_s)
    def js_querySelector(selector) = descendants.find { |e| Selector.match?(e, selector) }
    def js_querySelectorAll(selector) = NodeList.new(descendants.select { |e| Selector.match?(e, selector) })
    def js_getElementById(id) = descendants.find { |e| e.attrs["id"] == id }

    def js_closest(selector)
      node = self
      node = node.parent while node && !(node.is_a?(Node) && !node.text? && Selector.match?(node, selector))
      node
    end

    def js_appendChild(node)
      node.parent&.children&.delete(node)
      node.parent = self
      children << node
      node
    end

    def js_insertBefore(node, ref)
      node.parent&.children&.delete(node)
      node.parent = self
      index = ref ? children.index(ref) || children.length : children.length
      children.insert(index, node)
      node
    end

    def js_remove = parent&.children&.delete(self)
    def js_focus = nil
    def js_click = JS.fire(wrap, "click")
    def js_addEventListener(*) = nil

    def listeners(type) = (props["__listeners"] || {})[type.to_s] || []
  end

  class NodeList < Node
    def initialize(nodes)
      super("#nodelist")
      @nodes = nodes
    end

    def js_list = @nodes
    def js_get(key) = key == "length" ? @nodes.length : super
  end

  class ClassList
    def initialize(node) = (@node = node)
    def names = @node.attrs["class"].to_s.split
    def write(list) = (@node.attrs["class"] = list.join(" "))
    def add(*classes) = write((names + classes).uniq) && nil
    def remove(*classes) = write(names - classes) && nil
    def contains(name) = names.include?(name)

    def toggle(name, force = nil)
      on = force.nil? ? !contains(name) : force
      on ? add(name) : remove(name)
      on
    end
  end

  # tag, #id, .class, [attr], [attr='value'], combined, and descendants
  # ("#lessonNav a.active")
  module Selector
    PART = /([#.]?[\w-]+)|\[([\w-]+)(?:=['"]?([^'"\]]*)['"]?)?\]/

    def self.match?(node, selector)
      *ancestors, last = selector.strip.split(/\s+/)   # no spaces inside [attr='v'] here
      return false unless compound?(node, last)

      up = node.parent
      ancestors.reverse_each do |part|
        up = up.parent while up && !compound?(up, part)
        return false unless up

        up = up.parent
      end
      true
    end

    def self.compound?(node, selector)
      return false if !node.is_a?(Node) || node.text? || node.is_a?(NodeList)

      selector.scan(PART).all? do |simple, attr, value|
        if simple&.start_with?("#") then node.attrs["id"] == simple[1..]
        elsif simple&.start_with?(".") then node.attrs["class"].to_s.split.include?(simple[1..])
        elsif simple then node.tag == simple.downcase
        elsif value then node.attrs[attr] == value
        else node.attrs.key?(attr)
        end
      end
    end
  end

  # Enough HTML for the shell's own markup and the lessons' prose.
  module HTML
    TOKEN = /<!--.*?-->|<\/([a-zA-Z][\w-]*)\s*>|<([a-zA-Z][\w-]*)((?:\s+[^\s=>\/]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*\/?>|([^<]+|<)/m
    ATTR = /([^\s=>\/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/

    def self.parse(source)
      root = Node.new("#fragment")
      stack = [root]
      source.scan(TOKEN) do |closing, opening, attrs, text|
        if closing
          stack.pop while stack.length > 1 && stack.last.tag != closing.downcase && stack.any? { |n| n.tag == closing.downcase }
          stack.pop if stack.length > 1 && stack.last.tag == closing.downcase
        elsif opening
          node = Node.new(opening.downcase, parse_attrs(attrs.to_s))
          stack.last.js_appendChild(node)
          stack.push(node) unless Node::VOID.include?(node.tag)
        elsif text
          stack.last.js_appendChild(Node.text(text))
        end
      end
      root.children.dup
    end

    def self.parse_attrs(source)
      source.scan(ATTR).to_h { |name, dq, sq, bare| [name, dq || sq || bare || ""] }
    end
  end

  class Document < Node
    def initialize(body_html)
      super("#document")
      @html = Node.new("html", "lang" => "de")
      @body = Node.new("body")
      js_appendChild(@html)
      @html.js_appendChild(@body)
      @body.replace_children(HTML.parse(body_html))
      props["title"] = ""
    end

    def js_get(key)
      case key
      when "body" then @body
      when "documentElement" then @html
      when "readyState" then "loading"
      else super
      end
    end

    def js_createElement(tag) = Node.new(tag.to_s.downcase)
    def js_addEventListener(*) = nil
  end

  # window: what html/index.html, storage.js and shell/bridge.js provide
  class Window < Node
    attr_reader :document_node, :calls, :storage

    def initialize
      super("#window")
      body = File.read(File.expand_path("../../../html/index.html", __dir__))[%r{<body>(.*)</body>}m, 1]
      @document_node = Document.new(body.gsub(%r{<script.*?</script>}m, ""))
      @storage = {}
      @calls = []
      props["location"] = { "hash" => "" }
      props["history"] = { "replaceState" => proc { |_s, _t, url| props["location"]["hash"] = url.to_s } }
      props["localStorage"] = {
        "getItem" => proc { |k| @storage[k] },
        "setItem" => proc { |k, v| @storage[k] = v.to_s; nil },
        "removeItem" => proc { |k| @storage.delete(k); nil }
      }
      props["console"] = { "error" => proc { |*a| JS.console_errors << a.join(" "); nil } }
      props["JSON"] = { "parse" => proc { |text| JSON.parse(text.to_s) } }
      props["Object"] = { "keys" => proc { |o| o.is_a?(::Hash) ? o.keys : [] } }
      props["LESSONS"] = JSON.parse(File.read(File.expand_path("../../lessons.json", __dir__)))
      @confirm = true
      %w[initCell setCellCode refreshAllCells ensureThree workshopMount scrollTo].each do |name|
        props[name] = proc { |*args| @calls << [name, *args]; nil }
      end
      props["confirm"] = proc { |_msg| @confirm }
      props["ChunkyBridge"] = bridge
    end

    attr_writer :confirm

    def location = props["location"]

    def js_get(key)
      return document_node if key == "document"

      super
    end

    # shell/bridge.js as a recorder: what the shell asked for
    def bridge
      requests = @calls
      {
        "ready" => false,
        "failed" => false,
        "setState" => proc { |*a| requests << ["setState", *a]; nil },
        "reset" => proc { requests << ["reset"]; nil },
        "run" => proc { |idx| requests << ["run", idx]; props["ChunkyBridge"]["ready"] },
        "install" => proc { |name| requests << ["install", name]; props["ChunkyBridge"]["ready"] },
        "shellReady" => proc { requests << ["shellReady"]; nil }
      }
    end

    # fetch(url) { |response| } inside a Task: the file under html/
    def js_fetch(url, &block)
      path = File.expand_path("../../../html/#{url}", __dir__)
      found = File.file?(path)
      block.call(JS.to_rb({ "status" => found ? 200 : 404, "__body" => found ? File.read(path) : "" }))
      nil
    end
  end

  # dispatches an event to the listeners registered on target
  def self.fire(target, type, fields = {})
    node = to_js(target)
    prevented = false
    event = {
      "type" => type, "target" => fields.fetch("target", node),
      "ctrlKey" => false, "metaKey" => false, "shiftKey" => false, "altKey" => false, "button" => 0,
      "preventDefault" => proc { prevented = true; nil }
    }.merge(fields)
    node.listeners(type).each { |listener| listener.call(to_rb(event)) }
    prevented
  end
end

# PicoRuby's Task, run at once - with another self, as in PicoRuby
class Task
  def initialize(&block)
    Object.new.instance_exec(&block)
  end
end

def sleep_ms(_ms) = nil

JS.reset!
