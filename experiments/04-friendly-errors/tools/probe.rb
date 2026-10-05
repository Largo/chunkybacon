# What do Ruby 4.0's exceptions look like for cell code? Prints class,
# message, detailed_message and the Prism errors for a few snippets.
#   ruby experiments/04-friendly-errors/tools/probe.rb
SNIPPETS = [
  "name = 'Kaz'\nnmae.upcase",
  "h = {name: 'x'}\nh[:nme].upcase",
  "\"age: \" + 7",
  "7 + \"3\"",
  "def square(n)\n  n * n\nend\nsquare(1, 2)",
  "def foo\n  1\n",
  "if x > 1\n  2\n",
  "puts \"hi",
  "[1, 2, 3].each do |x|\n  puts x\n",
  "x = (1 + 2",
  "class fox\nend",
  "1 / 0",
  "s = 'abc'.freeze\ns << 'd'",
  "case [1]\nin [String]\nend",
  "Integer('abc')",
  "def f = f\nf",
  "foo(",
  "a = [1,2]\na.lenght",
  "Fxo.new",
  "puts 'a' 'b')",
  "def greet(name:)\nend\ngreet",
  "def x\n  1\nend\nend",
  "{ name: 'a', }[:name].upcase()",
  "nil + 1",
  "[1,2].fetch(5)",
  "{a: 1}.fetch(:b)",
]

SNIPPETS.each do |code|
  puts "=" * 60
  puts code
  puts "-" * 20
  begin
    eval(code, TOPLEVEL_BINDING.dup, "chunky.rb")
    puts "(no error)"
  rescue Exception => e
    puts "class:   #{e.class}"
    puts "message: #{e.message.inspect}"
    dm = e.detailed_message(highlight: false) rescue "(n/a)"
    puts "detailed: #{dm.inspect}" if dm != e.message
    puts "corrections: #{e.corrections.inspect}" if e.respond_to?(:corrections)
    puts "name: #{e.name.inspect}" if e.respond_to?(:name)
    puts "receiver: #{(e.receiver.inspect rescue '?')}" if e.respond_to?(:receiver)
    puts "backtrace0: #{e.backtrace&.first}"
    puts "locations: #{e.backtrace_locations&.first&.lineno}"
    if e.is_a?(SyntaxError)
      require "prism"
      Prism.parse(code).errors.each do |err|
        puts "prism: #{err.type} #{err.location.start_line}:#{err.location.start_column} #{err.message}"
      end
    end
  end
end
puts "ErrorHighlight: #{defined?(ErrorHighlight).inspect}  DidYouMean: #{defined?(DidYouMean).inspect}"
puts "Prism version: #{Prism::VERSION}"
