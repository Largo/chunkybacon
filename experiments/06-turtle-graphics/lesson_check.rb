# The draft lesson under the rules of test/check_harness.rb: demo cells run
# in one binding, the exercise starter must NOT pass its check, the
# solutions must. Each language in a process of its own (top-level defs
# outlive a binding); ja runs the English solutions.
#   ruby lesson_check.rb          # all three
require "json"
require "stringio"
require "rbconfig"

SOLUTION_BODY = {
  "de" => ["laenge", "tiefe"],
  "en" => ["length", "depth"]
}.freeze

def solution(lang, inward: false)
  len, dep = SOLUTION_BODY[lang == "de" ? "de" : "en"]
  a, b = inward ? %w[right left] : %w[left right]
  call = "koch(#{len} / 3.0, #{dep} - 1)"
  <<~RUBY
    def koch(#{len}, #{dep})
      if #{dep} == 0
        forward #{len}
      else
        #{call}
        #{a} 60
        #{call}
        #{b} 120
        #{call}
        #{a} 60
        #{call}
      end
    end

    turtle do
      3.times do
        koch(270, 3)
        right 120
      end
    end
  RUBY
end

# not snowflakes: must fail
WRONG = [
  "turtle { 48.times { forward 10; right 7.5 } }",                       # a 48-gon
  "turtle { 3.times { forward 270; right 120 } }"                        # the triangle
].freeze

def run_lang(lang)
  require_relative "../../html/turtle"
  $shown = []
  Kernel.define_method(:show_image) { |image| $shown << image.to_data_url; nil }
  cells = JSON.parse(File.read(File.join(__dir__, "lesson_turtle.json")))[lang]["cells"]
  bind = eval("proc { binding }.call", TOPLEVEL_BINDING)
  ok = true
  run = lambda do |code|
    $shown = []
    out = StringIO.new
    old = $stdout
    $stdout = out
    result = eval(code, bind, "chunky.rb")
    [out.string, result, nil]
  rescue Exception => e # rubocop:disable Lint/RescueException
    [out.string, nil, e]
  ensure
    $stdout = old
  end
  passes = lambda do |cell, code|
    output, result, error = run.call(code)
    return false if error

    { output: output, result: result, code: code, images: $shown.dup }.each { |k, v| bind.local_variable_set(k, v) }
    !!eval(cell["check"], bind, "check.rb")
  rescue Exception # rubocop:disable Lint/RescueException
    false
  end
  report = ->(label, value) { puts "#{lang} #{value ? 'ok  ' : 'FAIL'} #{label}"; ok &&= value }

  cells.each_with_index do |cell, i|
    case cell["t"]
    when "c"
      _out, result, error = run.call(cell["code"])
      report.call("demo cell #{i} runs (#{error ? error.message : result.inspect[0, 50]})", error.nil? && $shown.any?)
    when "x"
      report.call("starter does not pass", !passes.call(cell, cell["code"]))
      report.call("solution passes", passes.call(cell, solution(lang)))
      report.call("inward variant passes too", passes.call(cell, solution(lang, inward: true)))
      WRONG.each { |code| report.call("not a snowflake: #{code[0, 40]}", !passes.call(cell, code)) }
    end
  end
  exit(ok ? 0 : 1)
end

if ARGV[0]
  run_lang(ARGV[0])
else
  results = %w[de en ja].map { |lang| system(RbConfig.ruby, __FILE__, lang) }
  exit(results.all? ? 0 : 1)
end
