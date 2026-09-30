# jsg for PicoRuby: the syntax of the jsg gem (https://github.com/Largo/jsg)
# on top of PicoRuby.wasm's own js interop.
#
# The gem itself cannot run here (docs/PICORUBY_SHELL.md): its \A...\z
# regexps are rejected by PicoRuby (they compile to JavaScript RegExp), it
# needs require_relative, and it is built on ruby.wasm's JS::Null, #to_rb and
# #strictly_eql?, which PicoRuby does not have. Most of it is not needed
# either: PicoRuby already hands back Ruby values (String, Integer, Float,
# true, false, nil for null AND undefined) and reads a property without
# brackets (el.textContent). What is left to add, and all this file does:
#
#   el.textContent = "Hi"        property write (else el[:textContent] = "Hi")
#   el.hidden?, list.includes?(x) JavaScript truthiness; a method is called
#   JSG.w.Object.keys(obj)       a capitalized name without arguments is the
#                                constructor/namespace, not a call of it
#   JSG.q("li").each { ... }     NodeList, HTMLCollection, Array: PicoRuby's
#                                own each on them silently yields nothing
#   JSG.w / JSG.d / JSG.q("p")   window, document, querySelectorAll
require 'js'

module JSG
  module Sugar
    def method_missing(name, *args, &block)
      key = name.to_s
      last = key[-1]
      if last == "=" && args.length == 1 && block.nil? && JSG.setter?(key)
        self[key.chop] = args[0]
        return args[0]
      end
      if last == "?" && block.nil?
        prop = key.chop
        value = self[prop]
        value = super(prop.to_sym, *args) if value.is_a?(JS::Object) && value.typeof == :function
        return JSG.truthy?(value)
      end
      return self[key] if args.empty? && block.nil? && JSG.capitalized?(key)

      super
    end

    def each(&block)
      to_a.each(&block)
      self
    end
  end

  # "innerText=", not "==", "!=" or "[]=" (those are real methods anyway)
  def self.setter?(key)
    JSG.name_start?(key[0]) && key.index("=") == key.length - 1
  end

  def self.capitalized?(key)
    key[0] >= "A" && key[0] <= "Z"
  end

  def self.name_start?(char)
    char == "_" || (char >= "a" && char <= "z") || (char >= "A" && char <= "Z")
  end

  # JavaScript's idea of false: false, null/undefined (nil here), 0 and "";
  # any object or function is true
  def self.truthy?(value)
    return true if value.is_a?(JS::Object)

    !(value.nil? || value == false || value == 0 || value == "")
  end

  def self.window = JS.global
  def self.document = JS.document
  def self.querySelectorAll(selector) = JS.document.querySelectorAll(selector)
  def self.w = JS.global
  def self.d = JS.document
  def self.q(selector) = JS.document.querySelectorAll(selector)
end

JS::Object.prepend(JSG::Sugar)
