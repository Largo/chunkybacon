# What recording costs, under plain CRuby: each program run plainly (eval in
# a binding, as main.rb does) vs. under StepRecorder; also the cost of the
# JSON, and - for contrast - a global (untargeted) TracePoint like the live
# runs' time limit uses.
#   ruby measure_overhead.rb
require "json"
require "stringio"
require "csv"
require_relative "step_recorder"

def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def fresh = eval("proc { binding }.call", TOPLEVEL_BINDING)

def quiet
  old = $stdout
  $stdout = StringIO.new
  yield
ensure
  $stdout = old
end

# median of n runs, in ms
def median_ms(n)
  times = Array.new(n) do
    t = clock
    yield
    (clock - t) * 1000
  end
  times.sort[n / 2]
end

PROGRAMS = {
  "schleifen 3.times" => "3.times do |i|\n  puts \"Streifen Nummer \#{i + 1}\"\nend\n",
  "methoden map" => "def quadrat(zahl)\n  ergebnis = zahl * zahl\n  ergebnis\nend\nzahlen = [1, 2, 3]\nquadrate = zahlen.map { |z| quadrat(z) }\n",
  "while 200 (≈400 steps)" => "summe = 0\nzahl = 1\nwhile zahl <= 200\n  summe += zahl\n  zahl += 1\nend\nsumme\n",
  "fib(15) recursion" => "def fib(n)\n  n < 2 ? n : fib(n - 1) + fib(n - 2)\nend\nfib(15)\n",
  "100k loop (cap hit)" => "s = 0\n1.upto(100_000) do |i|\n  s += i\nend\ns\n",
  "big array in scope" => "gross = (1..50_000).to_a\nsumme = 0\n10.times do |i|\n  summe += gross[i]\nend\nsumme\n",
  "CSV (gem-heavy, 3 own lines)" => "rows = (1..5_000).map { |i| [\"p\#{i % 7}\", i * 1.5] }\ncsv = CSV.generate { |out| rows.each { |r| out << r } }\nCSV.parse(csv).sum { |r| r[1].to_f }\n"
}.freeze

N = 7
puts format("%-30s %9s %9s %7s %6s %8s %9s %9s", "program", "plain ms", "rec ms", "x", "steps", "json KB", "json ms", "globalTP")
PROGRAMS.each do |name, code|
  plain = median_ms(N) { quiet { eval(code, fresh, "chunky.rb") } }
  rec = nil
  recorded = median_ms(N) do
    quiet do
      rec = StepRecorder.new(code, file: "chunky.rb", hide: TOPLEVEL_BINDING.local_variables)
      rec.run { eval(code, fresh, "chunky.rb") }
    end
  end
  json = nil
  json_ms = median_ms(N) { json = rec.to_json }
  # contrast: what a global :line/:call/:b_call TracePoint (no recording) costs
  global = median_ms(N) do
    quiet { TracePoint.new(:line, :call, :return, :b_call, :b_return) { |_| }.enable { eval(code, fresh, "chunky.rb") } }
  end
  puts format("%-30s %9.2f %9.2f %7.1f %6d %8.1f %9.2f %9.2f", name, plain, recorded, recorded / plain,
              rec.steps.length, json.bytesize / 1024.0, json_ms, global)
end

# cost per recorded step, from the while loop (no cap, one frame)
code = "s = 0\nz = 1\nwhile z <= 250\n  s += z\n  z += 1\nend\n"
rec = nil
ms = median_ms(N) do
  rec = StepRecorder.new(code, max_steps: 10_000)
  rec.run { eval(code, fresh, "chunky.rb") }
end
plain = median_ms(N) { eval(code, fresh, "chunky.rb") }
puts format("per step: %.1f µs (%d steps, %.2f ms recorded vs %.3f ms plain)",
            (ms - plain) * 1000 / rec.steps.length, rec.steps.length, ms, plain)
