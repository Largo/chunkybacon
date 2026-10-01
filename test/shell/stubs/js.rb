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
# - a Task's block, and a register_callback block called from JavaScript,
#   run with another self
# - promise.await (inside a Task) answers the value or raises RuntimeError
#
# The DOM is a small tree: innerHTML is parsed (well-formed markup only),
# and getElementById / querySelector(All) / closest understand the selectors
# the shell uses: tag, #id, .class, [attr], [attr='value'], combined.
# storage.js (window.ChunkyStorage) is a Hash-backed fake, CodeMirror
# (window.cellEditors) a fake editor per initCell.
require "json"

module JS
  class << self
    attr_accessor :console_errors, :window, :documents, :callbacks

    def global = window
    def document = window.__target.document_node.wrap
    def generic_callbacks = callbacks.transform_values { |fn| Object.new(fn) }

    def to_rb(value)
      case value
      when ::Hash, ::Array, ::Proc, Node, Promise then Object.new(value)
      else value
      end
    end

    def to_js(value)
      value.is_a?(Object) ? value.__target : value
    end

    def reset!
      self.console_errors = []
      self.callbacks = {}
      self.window = Object.new(Window.new)
    end
  end

  # a settled JavaScript promise; await answers it (PicoRuby: inside a Task)
  class Promise
    attr_reader :value, :error

    def self.resolve(value = nil) = new(value, nil)
    def self.reject(message) = new(nil, message)

    def initialize(value, error)
      @value = value
      @error = error
    end
  end

  class Object < BasicObject
    # JavaScript calls the block with its arguments as Ruby values; the block
    # does not run with the self it was written in
    def self.register_callback(name, &block)
      ::JS.callbacks[name.to_sym] = proc do |*args|
        ::JS.to_js(::Object.new.instance_exec(*args.map { |a| ::JS.to_rb(a) }, &block))
      end
      nil
    end

    def await
      return self unless @target.is_a?(::JS::Promise)
      raise @target.error if @target.error

      ::JS.to_rb(@target.value)
    end

    def initialize(target)
      @target = target
    end

    def __target = @target
    def nil? = false   # PicoRuby's JS::Object has nil?; null itself arrives as nil
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

    def js_has?(key) = js_get(key) != nil || props.key?(key) || %w[hidden disabled value title open].include?(key)

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
      when "hidden", "disabled", "open" then props.fetch(key, attrs.key?(key))
      when "files" then props["files"] || []
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
    def js_focus = (props["focused"] = true) && nil
    def js_click = JS.fire(wrap, "click")
    def js_addEventListener(*) = nil
    def js_showModal = (props["open"] = true) && nil
    def js_close = (props["open"] = false) && nil

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
    def js_createTextNode(text) = Node.text(text.to_s)
    def js_addEventListener(*) = nil
  end

  # CodeMirror, as far as the shell uses it
  class Editor < Node
    def initialize
      super("#editor")
      @value = ""
      @on_change = []
    end

    def js_getValue = @value
    def js_setOption(*) = nil
    def js_clearHistory = nil
    def js_refresh = (props["refreshed"] = true) && nil   # redraw after being hidden
    def js_on(_type, fn) = (@on_change << fn) && nil

    def js_setValue(text) = change(text.to_s, "setValue")
    def type(text) = change(text, "+input")   # the learner typing

    def change(text, origin)
      @value = text
      @on_change.each { |fn| fn.call(wrap.__target, { "origin" => origin }) }
      nil
    end
  end

  # storage.js: the browser's files, no folder; records what is asked
  class Storage
    attr_reader :files, :listeners, :calls
    attr_accessor :state, :error, :load_result

    def initialize
      @files = {}
      @listeners = Hash.new { |h, k| h[k] = [] }
      @calls = []
      @state = "none"
      @error = nil
      @load_result = JS::Promise.resolve(true)
    end

    def emit(name) = listeners[name].each(&:call)

    def js
      files = @files
      {
        "supported" => false, "PROGRESS_FILE" => "chunkybacon-progress.json",
        "state" => proc { @state }, "error" => proc { @error }, "folderName" => proc { "kurs" }, "savedAt" => proc { nil },
        "on" => proc { |name, fn| @listeners[name] << fn; nil },
        "downloadProgress" => proc { @calls << ["downloadProgress"]; nil },
        "loadProgressFile" => proc { |file| @calls << ["loadProgressFile", file]; @load_result },
        "connectFolder" => proc { @calls << ["connectFolder"]; JS::Promise.resolve },
        "resumeFolder" => proc { @calls << ["resumeFolder"]; JS::Promise.resolve },
        "disconnectFolder" => proc { @calls << ["disconnectFolder"]; JS::Promise.resolve },
        "files" => {
          "kind" => proc { "browser" },
          "list" => proc { files.keys.sort },
          "read" => proc { |path| files[path] },
          "write" => proc { |path, text| files[path] = text; JS::Promise.resolve },
          "remove" => proc { |path| files.delete(path); JS::Promise.resolve },
          "rename" => proc { |from, to| files[to] = files.delete(from) if files.key?(from) && from != to; JS::Promise.resolve },
          "readDataUrl" => proc { |file| JS::Promise.resolve("data:image/png;base64,#{file["name"]}") },
          "isBinary" => proc { |path| path.to_s.downcase.match?(/\.(png|jpe?g|gif|webp|pdf)\z/) },
          "refresh" => proc { JS::Promise.resolve(false) },
          "snapshot" => proc { files.dup }
        }
      }
    end
  end

  # window: what html/index.html, storage.js and shell/bridge.js provide
  class Window < Node
    attr_reader :document_node, :calls, :storage, :fs, :editors

    def initialize
      super("#window")
      body = File.read(File.expand_path("../../../html/index.html", __dir__))[%r{<body>(.*)</body>}m, 1]
      @document_node = Document.new(body.gsub(%r{<script.*?</script>}m, ""))
      @storage = {}
      @calls = []
      @fs = Storage.new
      @editors = {}
      props["ChunkyStorage"] = @fs.js
      props["cellEditors"] = @editors
      props["initCell"] = proc do |idx|
        @calls << ["initCell", idx]
        editor = @editors[idx.to_s] = Editor.new
        # index.html: a key in the editor tells the shell (live runs)
        editor.js_on("change", proc do |_cm, change|
          edited = props["chunkyEdited"]
          edited.call(idx.to_s) if edited && change["origin"] != "setValue"
        end)
        nil
      end
      props["location"] = { "hash" => "", "pathname" => "/" }
      props["history"] = {
        "replaceState" => proc { |_s, _t, url| go_to(url.to_s); nil },
        "pushState" => proc { |_s, _t, url| @calls << ["pushState", url.to_s]; go_to(url.to_s); nil }
      }
      props["localStorage"] = {
        "getItem" => proc { |k| @storage[k] },
        "setItem" => proc { |k, v| @storage[k] = v.to_s; nil },
        "removeItem" => proc { |k| @storage.delete(k); nil }
      }
      props["console"] = { "error" => proc { |*a| JS.console_errors << a.join(" "); nil } }
      props["JSON"] = { "parse" => proc { |text| JSON.parse(text.to_s) }, "stringify" => proc { |o| JSON.generate(o) } }
      props["Object"] = { "keys" => proc { |o| o.is_a?(::Hash) ? o.keys : [] } }
      props["LESSONS"] = JSON.parse(File.read(File.expand_path("../../lessons.json", __dir__)))
      @confirm = true
      %w[setCellCode refreshAllCells ensureThree scrollTo].each do |name|
        props[name] = proc { |*args| @calls << [name, *args]; nil }
      end
      props["confirm"] = proc { |_msg| @confirm }
      props["ChunkyBridge"] = bridge
    end

    attr_writer :confirm

    def location = props["location"]

    # history.replaceState/pushState: "#id" changes the hash, "/de/id" the
    # path (and drops the hash, as a URL without one does)
    def go_to(url)
      if url.start_with?("#")
        location["hash"] = url
      else
        path, fragment = url.split("#", 2)
        location["pathname"] = path
        location["hash"] = fragment ? "##{fragment}" : ""
      end
    end

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
        # a live run goes out only once the kernel is up, never queued
        "autorun" => proc { |idx| props["ChunkyBridge"]["ready"] && (requests << ["autorun", idx]) && true },
        "install" => proc { |name| requests << ["install", name]; props["ChunkyBridge"]["ready"] },
        "shellReady" => proc { requests << ["shellReady"]; nil },
        "saveText" => proc { |name, text| requests << ["saveText", name, text]; nil },
        "objectUrl" => proc { |url| requests << ["objectUrl", url]; "blob:preview-#{requests.length}" },
        "revokeUrl" => proc { |url| requests << ["revokeUrl", url]; nil },
        "settle" => proc do |promise|
          JS::Promise.resolve(promise.error ? { "ok" => false, "name" => "Error", "message" => promise.error }
                                            : { "ok" => true, "value" => promise.value })
        end
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

# PicoRuby's Task, run at once - with another self, as in PicoRuby. With
# Task.held set to [], blocks wait there until Task.release (a test looks
# at the page between a key and the live run a second later).
class Task
  class << self
    attr_accessor :held

    def release
      blocks = held || []
      self.held = []
      blocks.each { |block| Object.new.instance_exec(&block) }
    end
  end

  def initialize(&block)
    if Task.held
      Task.held << block
    else
      Object.new.instance_exec(&block)
    end
  end
end

def sleep_ms(_ms) = nil

JS.reset!
