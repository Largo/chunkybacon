# require "herb" in the browser. Herb (Marco Roth, MIT) parses HTML and ERB
# together. Its gem is Ruby - the AST and its nodes, the errors, the
# visitor, Herb::Engine - around one C extension, "herb/herb": the parser,
# which ruby.wasm cannot load. This file is that extension, and nothing
# else: Herb.parse, lex, extract_ruby, extract_html and version hand the
# source to the same parser compiled to WebAssembly (@herb-tools/browser,
# html/assets/herb/, loaded by index.html's ensureHerb) and turn its answer
# into the gem's own objects. The answer is JSON with the field names of
# the gem's constructors - initialize(type, location, errors, <fields...>)
# for a node - so the conversion goes by those names, as the extension's
# C code does field by field.
#
# The gem itself comes from the cache (0.10.3, the version of the vendored
# parser); main.rb serves this file for its require "herb/herb".
require "json"

module Herb
  module Bridge
    class NotReady < StandardError; end

    module_function

    # one call into the parser; its answer as parsed JSON
    def call(op, args)
      state = JS.global[:chunkyHerb]
      unless state[:ready].to_s == "true"
        failed = state[:error].typeof == "string" ? state[:error].to_s : nil
        JS.global.call(:ensureHerb)
        raise NotReady, failed ? "Herb's parser could not be loaded: #{failed}" :
                                 "Herb's parser is still loading - run the cell again in a moment"
      end

      answer = JSON.parse(JS.global.call(:chunkyHerbCall, op, JSON.generate(args)).to_s)
      raise RuntimeError, "Herb: #{answer["error"]}" if answer.key?("error")

      answer["ok"]
    end

    # the gem's options for the parser (the C extension's names; timeout in
    # seconds there, in milliseconds for the WebAssembly build)
    def parser_options(options)
      options = options.transform_keys(&:to_s)
      options["timeout"] = (options["timeout"].to_f * 1000).round if options.key?("timeout")
      options
    end

    # "HTMLElementNode" -> "HTML_ELEMENT_NODE"
    def type_name(class_name)
      class_name.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').upcase
    end

    def classes(namespace, superclass, prefix = "")
      namespace.constants.filter_map do |name|
        klass = namespace.const_get(name)
        [prefix + type_name(name), klass] if klass.is_a?(Class) && klass <= superclass
      end.to_h
    end

    def nodes = @nodes ||= classes(Herb::AST, Herb::AST::Node, "AST_")
    def errors = @errors ||= classes(Herb::Errors, Herb::Errors::Error)
    def warnings = @warnings ||= classes(Herb::Warnings, Herb::Warnings::Warning)

    def position(data) = data && Herb::Position.new(data["line"], data["column"])

    def location(data)
      data && Herb::Location.new(position(data["start"]), position(data["end"]))
    end

    def range(data)
      data && Herb::Range.new(*(data.is_a?(Array) ? data : data.values_at("start", "end")))
    end

    def token(data)
      data && Herb::Token.new(data["value"], range(data["range"]), location(data["location"]), data["type"])
    end

    # a node, an error or a warning: its class's constructor, filled by the
    # names of its parameters
    def build(klass, data)
      params = klass.instance_method(:initialize).parameters.select { |kind, _| %i[req opt].include?(kind) }
      klass.new(*params.map { |_, name| name == :type ? data["type"] : value(name.to_s, data[name.to_s]) })
    end

    def value(key, data)
      case data
      when Array then data.map { value(key, _1) }
      when Hash
        type = data["type"].to_s
        if key == "location" then location(data)
        elsif key == "range" then range(data)
        elsif (klass = nodes[type]) then build(klass, data)
        elsif (klass = errors[type]) then build(klass, data)
        elsif (klass = warnings[type]) then build(klass, data)
        elsif type.start_with?("TOKEN_") || data.key?("range") then token(data)
        elsif data.key?("start") && data.key?("end") then location(data)
        else data
        end
      else data
      end
    end
  end

  class << self
    def parse(source, **options)
      raise TypeError, "wrong argument type #{source.class} (expected String)" unless source.is_a?(String)

      answer = Bridge.call("parse", { source: source, options: Bridge.parser_options(options) })
      document = Bridge.value("value", answer["value"])
      used = (answer["options"] || {}).transform_keys(&:to_sym).slice(*ParserOptions.instance_method(:initialize).parameters.map(&:last))
      used[:timeout] = used[:timeout].to_f / 1000 if used.key?(:timeout)
      used[:max_errors] = nil if used[:max_errors].to_i.zero? && used.key?(:max_errors)
      ParseResult.new(document, source,
                      Bridge.value("warnings", answer["warnings"] || []),
                      Bridge.value("errors", answer["errors"] || []),
                      ParserOptions.new(**used))
    end

    def lex(source, **_options)
      raise TypeError, "wrong argument type #{source.class} (expected String)" unless source.is_a?(String)

      answer = Bridge.call("lex", { source: source })
      LexResult.new(Bridge.value("tokens", answer["tokens"] || []), source,
                    Bridge.value("warnings", answer["warnings"] || []),
                    Bridge.value("errors", answer["errors"] || []))
    end

    def extract_ruby(source, **options)
      Bridge.call("extract_ruby", { source: source, options: options.transform_keys(&:to_s) })
    end

    def extract_html(source)
      Bridge.call("extract_html", { source: source })
    end

    # "herb gem v0.10.3, libprism@1.9.0, libherb@0.10.3 (WebAssembly)"
    def version
      "herb gem v#{VERSION}, #{Bridge.call('version', {})}"
    end

    %i[arena_stats leak_check diff].each do |name|
      define_method name do |*_args, **_options|
        raise NotImplementedError, "Herb.#{name} needs the gem's C extension - it works on your " \
                                   "computer, not in the browser"
      end
    end
  end
end
