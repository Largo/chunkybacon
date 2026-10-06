# The kernel's side of a lesson with "engine": "picoruby" (the PicoRuby
# lesson, docs/HANDOVER.md §6l). Its cells and IRBs run on PicoRuby.wasm in
# a Web Worker (picoruby_lab.js, picoruby_worker.js, picoruby_lab.rb); what
# comes back is text - what the run printed, the inspect of its value, an
# error's class, line and message. This turns that text into what main.rb
# shows and checks: a value that compares like the object it describes, an
# exception of CRuby's class of the same name (so the friendly explanations
# and the line marks work as for CRuby), and CRuby's message for code that
# does not parse - PicoRuby parses with Prism too, but its compiler says no
# more than "no".
#
# Also loaded by test/check_harness.rb, which runs the exercise under CRuby
# and hands the check a Value, as the page does.
module PicoRubyCells
  # PicoRuby's value as CRuby sees it: its inspect text. Compares with an
  # object by that object's inspect, so a check can say
  # `result == {"chunky" => 2}` - CRuby 3.4+ and PicoRuby inspect a Hash,
  # an Array, a String and a number the same way.
  class Value
    def initialize(text)
      @text = text
    end

    def inspect = @text
    def to_s = @text
    def ==(other) = other.inspect == @text
    alias eql? ==
    def hash = @text.hash
  end

  # an error PicoRuby raised whose class CRuby does not have
  class Error < StandardError
    attr_reader :pico_class

    def initialize(pico_class, message)
      @pico_class = pico_class
      super(message)
    end
  end

  # the time limit ended the run (▶; a live run says AutoRun::Stopped)
  class Stopped < StandardError; end

  # PicoRuby could not be loaded
  class Unavailable < StandardError; end

  module_function

  # nil, true and false as themselves (main.rb leaves out "=> nil" after
  # output, as for CRuby), everything else as a Value
  def value(text)
    case text
    when "nil" then nil
    when "true" then true
    when "false" then false
    else Value.new(text)
    end
  end

  # what PicoRuby raised, as CRuby's exception of that name where there is
  # one (NoMethodError, ZeroDivisionError, ...), at the cell's line
  def error(name, message, line, file)
    klass = Object.const_get(name) if name.match?(/\A[A-Z]\w*\z/) && Object.const_defined?(name)
    error = if klass.is_a?(Class) && klass <= StandardError
      klass.new(message)
    else
      Error.new(name, message)
    end
    error.set_backtrace(line.positive? ? ["#{file}:#{line}:in '<main>'"] : [])
    error
  end

  # "NoMethodError" for the cell's error line
  def class_name(error) = error.is_a?(Error) ? error.pico_class : error.class.name

  # CRuby's SyntaxError for code that does not parse (Prism's messages,
  # what eval would say), nil for code that does
  def syntax_error(code, file)
    RubyVM::InstructionSequence.compile(code, file)
    nil
  rescue SyntaxError => e
    e
  end
end
