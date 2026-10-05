# Probe: can a :script_compiled hook switch on a TracePoint targeted at the
# iseq that eval is about to run (so gem code and earlier cells cost nothing)?
bind = eval("proc { binding }.call", TOPLEVEL_BINDING)

# cell 1 defines a method, as an earlier cell would
eval("def gruss(n)\n  \"Hallo \#{n}\"\nend\nalt = 1\n", bind, "chunky.rb")

code = <<~RUBY
  summe = 0
  3.times do |i|
    summe += i
  end
  x = gruss("Kaz")
  def quadrat(z)
    q = z * z
    q
  end
  quadrat(4)
  [1, 2].map { |v| quadrat(v) }
RUBY

events = []
line_tp = TracePoint.new(:line, :call, :return, :b_call, :b_return, :raise) do |tp|
  events << [tp.event, tp.lineno, tp.binding&.local_variables]
end
compiled = TracePoint.new(:script_compiled) do |tp|
  next unless tp.eval_script == code
  line_tp.enable(target: tp.instruction_sequence)
  compiled.disable
end
compiled.enable
r = eval(code, bind, "chunky.rb")
line_tp.disable
compiled.disable
p r
events.each { |e| p e }

puts "--- :return during an exception?"
ev2 = []
tp2 = TracePoint.new(:call, :return, :raise, :line) { |tp| ev2 << [tp.event, tp.lineno, tp.method_id] }
def boom(n) = n.zero? ? raise("weg") : boom(n - 1)
tp2.enable { boom(2) rescue nil }
ev2.each { |e| p e }

puts "--- Binding#local_variables order inside a block"
a = 1
[5].each { |b; c| p binding.local_variables }
