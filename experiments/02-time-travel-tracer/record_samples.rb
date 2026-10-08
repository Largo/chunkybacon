# Records sample cells from the basics lessons the way the kernel runs them
# (main.rb: one binding per lesson, eval with file "chunky.rb", $stdout a
# StringIO) and writes samples.js (window.SAMPLES = [...]) for scrubber.html,
# plus samples.json.
#   ruby record_samples.rb
require "json"
require "stringio"
require_relative "../../html/step_recorder"   # (moved there when it was integrated)

# a kernel in miniature: what ChunkyApp#run_cell does around the eval
class MiniKernel
  def initialize
    @bind = eval("proc { binding }.call", TOPLEVEL_BINDING)
  end

  # a normal (▶) run, untraced
  def run(code)
    with_stdout { eval(code, @bind, "chunky.rb") }
  end

  # a stepping run: the same eval, recorded
  def step(code)
    rec = StepRecorder.new(code, file: "chunky.rb", hide: TOPLEVEL_BINDING.local_variables)
    with_stdout do
      rec.run { eval(code, @bind, "chunky.rb") }
    rescue StandardError
      nil # the trace has the error
    end
    rec.trace
  end

  private

  def with_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = old
  end
end

samples = []

add = lambda do |id, title, cell, before: []|
  kernel = MiniKernel.new
  before.each { |c| kernel.run(c) }
  trace = kernel.step(cell)
  samples << { id: id, title: title, before: before, trace: trace }
  puts format("%-22s %4d steps%s", id, trace[:steps].length, trace[:truncated] ? " (truncated)" : "")
end

# schleifen, cell 3 (as in lessons.js)
add.call("schleifen-times", "Schleifen: 3.times do |i|", <<~RUBY)
  3.times do |i|
    puts "Streifen Nummer \#{i + 1}"
  end
RUBY

# schleifen: a while loop with a running total (each/while are the lesson's topic)
add.call("schleifen-while", "Schleifen: while mit Summe", <<~RUBY)
  summe = 0
  zahl = 1
  while zahl <= 4
    summe += zahl
    zahl += 1
  end
  summe
RUBY

# arrays, cell 5 - after cell 1 ran: fruehstueck comes from the shared binding
add.call("arrays-each", "Arrays: << und each (nach Zelle 1)", <<~RUBY, before: ["fruehstueck = [\"Ei\", \"Brot\"]\nfruehstueck.length\n"])
  fruehstueck << "Kaffee"
  fruehstueck.each do |sache|
    puts sache
  end
RUBY

# methoden, cell 1
add.call("methoden-def", "Methoden: def begruessung", <<~RUBY)
  def begruessung(name)
    "Hallo, \#{name}!"
  end

  begruessung("Kaz")
RUBY

# methoden, cell 3 - begruessung is from an earlier cell: not stepped into
add.call("methoden-earlier", "Methoden: Methode aus früherer Zelle", <<~RUBY, before: ["def begruessung(name)\n  \"Hallo, \#{name}!\"\nend\n"])
  mit_klammern  = begruessung("Kaz")
  ohne_klammern = begruessung "Kaz"

  [mit_klammern, ohne_klammern]
RUBY

# methoden: a method called from a block (the exercise's quadrat, used in map)
add.call("methoden-map", "Methoden: quadrat in map", <<~RUBY)
  def quadrat(zahl)
    ergebnis = zahl * zahl
    ergebnis
  end

  zahlen = [1, 2, 3]
  quadrate = zahlen.map { |z| quadrat(z) }
RUBY

# recursion: the frame stack grows and shrinks
add.call("rekursion", "Rekursion: fakultaet(4)", <<~RUBY)
  def fakultaet(n)
    return 1 if n <= 1
    n * fakultaet(n - 1)
  end

  fakultaet(4)
RUBY

# an error in the third pass of a loop
add.call("fehler", "Fehler im dritten Durchlauf", <<~RUBY)
  preise = [3, 5, nil, 2]
  total = 0
  preise.each do |p|
    total += p
  end
  total
RUBY

# a loop longer than the cap: the stepper stops recording, the cell runs on
add.call("lang", "Lange Schleife (Kappung)", <<~RUBY)
  summe = 0
  1.upto(10_000) do |i|
    summe += i
  end
  summe
RUBY

File.write(File.join(__dir__, "samples.json"), JSON.generate(samples))
File.write(File.join(__dir__, "samples.js"), "window.SAMPLES = #{JSON.generate(samples)};\n")
puts "wrote samples.json (#{File.size(File.join(__dir__, 'samples.json'))} bytes) and samples.js"
