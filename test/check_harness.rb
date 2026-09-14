# Offline harness for the notebook format: for every lesson/lang it runs the
# demo cells in a shared binding (like the browser kernel), then verifies that
# the exercise starter does NOT pass the check while every known-good solution
# (puts-style and no-puts-style) DOES pass. Mirrors main.rb's eval mechanics.
require 'json'
require 'stringio'

data = JSON.parse(File.read(File.expand_path("lessons.json", __dir__)))

SOLUTIONS = {
  "hallo" => {
    "de" => [%(puts "Hallo, Welt!"), %("Hallo, Welt!")],
    "en" => [%(puts "Hello, World!"), %("Hello, World!")]
  },
  "rechnen" => {
    "de" => [%(puts 6 * 7), %(6 * 7)],
    "en" => [%(puts 6 * 7), %(6 * 7)]
  },
  "variablen" => {
    "de" => [%(name = "Kaz"\nalter = 7)],
    "en" => [%(name = "Kaz"\nage = 7)]
  },
  "strings" => {
    "de" => [%(lieblingsessen = "Chunky Bacon"\nputs "Ich mag \#{lieblingsessen}!"), %(lieblingsessen = "Chunky Bacon"\n"Ich mag \#{lieblingsessen}!")],
    "en" => [%(favorite_food = "Chunky Bacon"\nputs "I love \#{favorite_food}!"), %(favorite_food = "Chunky Bacon"\n"I love \#{favorite_food}!")]
  },
  "wenn" => {
    "de" => [%(zahl = 7\nif zahl > 5\n  puts "gross"\nelse\n  puts "klein"\nend), %(zahl = 7\nif zahl > 5\n  "gross"\nelse\n  "klein"\nend)],
    "en" => [%(number = 7\nif number > 5\n  puts "big"\nelse\n  puts "small"\nend), %(number = 7\nif number > 5\n  "big"\nelse\n  "small"\nend)]
  },
  "schleifen" => {
    "de" => [%(5.times do\n  puts "Chunky Bacon!"\nend), %(5.times.map { "Chunky Bacon!" })],
    "en" => [%(5.times do\n  puts "Chunky Bacon!"\nend), %(5.times.map { "Chunky Bacon!" })]
  },
  "arrays" => {
    "de" => [%(fruehstueck = ["Ei", "Brot"]\nfruehstueck << "Speck"\nfruehstueck.each do |sache|\n  puts sache\nend), %(fruehstueck = ["Ei", "Brot"]\nfruehstueck << "Speck")],
    "en" => [%(breakfast = ["egg", "toast"]\nbreakfast << "bacon"\nbreakfast.each do |item|\n  puts item\nend), %(breakfast = ["egg", "toast"]\nbreakfast << "bacon")]
  },
  "hashes" => {
    "de" => [%(fuchs = { name: "Chunky", essen: "Speck" }\nfuchs[:name])],
    "en" => [%(fox = { name: "Chunky", food: "bacon" }\nfox[:name])]
  },
  "methoden" => {
    "de" => [%(def quadrat(zahl)\n  zahl * zahl\nend\n\nquadrat(9))],
    "en" => [%(def square(number)\n  number * number\nend\n\nsquare(9))]
  },
  "klassen" => {
    "de" => [%(class Fuchs\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def ruf\n    "Chunky Bacon!"\n  end\nend\nf = Fuchs.new("Kaz")\nf.ruf)],
    "en" => [%(class Fox\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def shout\n    "Chunky Bacon!"\n  end\nend\nf = Fox.new("Kaz")\nf.shout)]
  }
}

def run_in(bind, code)
  old_stdout = $stdout
  buffer = StringIO.new
  $stdout = buffer
  error = nil
  result = nil
  begin
    result = eval(code, bind, "chunky.rb")
  rescue Exception => e
    error = e
  ensure
    $stdout = old_stdout
  end
  [result, buffer.string, error]
end

failures = 0

data["lessons"].each do |lesson|
  %w[de en].each do |lang|
    l = lesson[lang]
    exercise = l["cells"].find { |c| c["t"] == "x" }
    demos = l["cells"].select { |c| c["t"] == "c" }
    variants = [["starter", exercise["code"]]] +
               SOLUTIONS.fetch(lesson["id"]).fetch(lang).each_with_index.map { |s, i| ["solution#{i + 1}", s] }

    variants.each do |label, candidate|
      bind = eval("proc { binding }.call", TOPLEVEL_BINDING)

      demo_failed = false
      demos.each do |demo|
        _, _, err = run_in(bind, demo["code"])
        if err
          puts "FAIL #{lesson["id"]}/#{lang}: demo cell raised #{err.class}: #{err.message}"
          failures += 1
          demo_failed = true
        end
      end
      next if demo_failed

      result, output, error = run_in(bind, candidate)
      if error && label != "starter"
        puts "FAIL #{lesson["id"]}/#{lang} (#{label}): raised #{error.class}: #{error.message}"
        failures += 1
        next
      end

      bind.local_variable_set(:output, output)
      bind.local_variable_set(:result, result)
      bind.local_variable_set(:code, candidate)
      passed = begin
        !!eval(exercise["check"], bind, "check.rb")
      rescue Exception
        false
      end

      if label == "starter" && passed
        puts "FAIL #{lesson["id"]}/#{lang}: starter code already passes check!"
        failures += 1
      elsif label != "starter" && !passed
        puts "FAIL #{lesson["id"]}/#{lang} (#{label}): does not pass check"
        failures += 1
      end
    end
  end
end

puts failures.zero? ? "ALL CHECKS OK (#{data["lessons"].length} lessons x 2 langs, puts + no-puts variants)" : "#{failures} failures"
exit(failures.zero? ? 0 : 1)
