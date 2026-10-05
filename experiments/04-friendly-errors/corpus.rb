# Realistic beginner mistakes, mined from the exercises of html/lessons.js
# (lesson id in +lesson+). Each is what a learner might type into the
# exercise cell; +setup+ is an earlier cell of the lesson (it runs first, in
# the same binding), +live+ runs it under the live-run time limit, +expect+
# is the rule that should explain it (nil: no rule is expected to).
module FriendlyErrors
  CORPUS = [
    # ---- 1 hallo
    { id: "hello-unclosed-string", lesson: "hallo", code: %(puts "Hello, World!), expect: :syn_string },
    { id: "hello-no-quotes", lesson: "hallo", code: %(puts Hello), expect: :constant },
    { id: "hello-capital-puts", lesson: "hallo", code: %(Puts "Hello, World!"), expect: :method_typo },
    # ---- 2 rechnen
    { id: "times-as-x", lesson: "rechnen", code: %(6 x 7), expect: :syn_times_x },
    { id: "unexpected-paren", lesson: "rechnen", code: %{puts (6 * 7))}, expect: :syn_generic },
    { id: "number-times-string", lesson: "rechnen", code: %(6 * "7"), expect: :num_plus_str },
    # ---- 3 variablen
    { id: "string-without-quotes", lesson: "variablen", code: %(name = Kaz\nage = 7), expect: :constant },
    { id: "age-is-text", lesson: "variablen", code: %(name = "Kaz"\nage = "7"\nage + 1), expect: :str_numeric },
    { id: "name-typo", lesson: "variablen", code: %(name = "Kaz"\nage = 7\nnmae.upcase), expect: :name_lower },
    { id: "de-string-plus-int", lesson: "variablen", lang: "de", code: %(name = "Kaz"\nalter = 7\nputs "Ich bin " + alter + " Jahre alt"), expect: :str_plus },
    { id: "used-before-assigned", lesson: "variablen", code: %(puts name\nname = "Kaz"), expect: :name_lower },
    # ---- 4 strings
    { id: "interpolation-unclosed", lesson: "strings", code: %(favorite_food = "Chunky Bacon"\n"I love \#{favorite_food!"), expect: :syn_interpolation },
    { id: "interpolation-typo", lesson: "strings", code: %(favorite_food = "Chunky Bacon"\n"I love \#{favorite_fod}!"), expect: :name_lower },
    # ---- 5 wenn
    { id: "if-missing-end", lesson: "wenn", code: %(number = 7\nif number > 5\n  "big"\nelse\n  "small"), expect: :syn_missing_end },
    { id: "if-python-colon", lesson: "wenn", code: %(number = 7\nif number > 5:\n  "big"\nelse:\n  "small"\nend), expect: :syn_python_colon },
    { id: "else-if", lesson: "wenn", code: %(number = 7\nif number > 5\n  "big"\nelse if number < 0\n  "negative"\nelse\n  "small"\nend), expect: :syn_else_if },
    { id: "eq-space-gt", lesson: "wenn", code: %(number = 7\nif number = > 5\n  "big"\nend), expect: :syn_eq_gt },
    { id: "if-braces", lesson: "wenn", code: %(number = 7\nif number > 5 {\n  "big"\n}), expect: :syn_if_brace },
    { id: "de-elseif", lesson: "wenn", lang: "de", code: %(zahl = 7\nif zahl > 5\n  "groß"\nelseif zahl < 0\n  "negativ"\nend), expect: :name_elseif },
    # ---- 6 schleifen
    { id: "times-missing-end", lesson: "schleifen", code: %(5.times do\n  puts "Chunky Bacon!"), expect: :syn_missing_end },
    { id: "python-for-range", lesson: "schleifen", code: %(for i in range(5):\n  puts "Chunky Bacon!"), expect: :syn_python_for },
    { id: "while-never-counts", lesson: "schleifen", live: true, code: %(i = 0\nwhile i < 5\n  puts "Chunky Bacon!"\nend), expect: :endless_loop },
    { id: "plusplus", lesson: "schleifen", code: %(i = 0\nwhile i < 5\n  puts "Chunky Bacon!"\n  i++\nend), expect: :syn_plusplus },
    { id: "loop-without-break", lesson: "schleifen", live: true, code: %(loop do\n  puts "Chunky Bacon!"\nend), expect: :endless_loop },
    # ---- 7 arrays
    { id: "array-missing-bracket", lesson: "arrays", code: %(breakfast = ["egg", "toast"\nbreakfast << "bacon"), expect: :syn_bracket },
    { id: "push-missing-paren", lesson: "arrays", code: "breakfast = [\"egg\", \"toast\"]\nbreakfast.push(\"bacon\"\nbreakfast", expect: :syn_bracket },
    { id: "array-upcase", lesson: "arrays", code: %(breakfast = ["egg", "toast"]\nbreakfast.upcase), expect: :method_wrong_type },
    { id: "array-index-past-end", lesson: "arrays", code: %(breakfast = ["egg", "toast"]\nbreakfast[2].upcase), expect: :nil_receiver },
    { id: "length-typo", lesson: "arrays", code: %(breakfast = ["egg", "toast"]\nbreakfast.lenght), expect: :method_typo },
    { id: "block-pipe-open", lesson: "arrays", code: %(breakfast = ["egg", "toast"]\nbreakfast.each do |item\n  puts item\nend), expect: :syn_block_pipe },
    # ---- 8 hashes
    { id: "hash-string-key", lesson: "hashes", code: %(fox = { name: "Chunky", food: "bacon" }\nfox["name"].upcase), expect: :nil_receiver },
    { id: "hash-key-typo", lesson: "hashes", code: %(fox = { name: "Chunky", food: "bacon" }\nfox[:nmae].upcase), expect: :nil_receiver },
    { id: "hash-key-other-cell", lesson: "hashes", setup: %(animal = { name: "Chunky", food: "bacon" }), code: %(animal[:age] + 1), expect: :nil_receiver },
    { id: "hash-no-colon", lesson: "hashes", code: %(fox = { name "Chunky", food: "bacon" }), expect: :syn_hash_rocket },
    { id: "hash-fetch-missing", lesson: "hashes", code: %(fox = { name: "Chunky", food: "bacon" }\nfox.fetch(:age)), expect: :key_error },
    # ---- 9 methoden
    { id: "square-two-args", lesson: "methoden", code: %(def square(number)\n  number * number\nend\n\nsquare(9, 2)), expect: :arity },
    { id: "square-called-before-def", lesson: "methoden", code: %(square(9)\n\ndef square(number)\n  number * number\nend), expect: :name_lower },
    { id: "param-typo", lesson: "methoden", code: %(def square(number)\n  numbr * numbr\nend\n\nsquare(9)), expect: :name_lower },
    { id: "outer-variable-in-def", lesson: "methoden", code: %(factor = 2\n\ndef double(n)\n  n * factor\nend\n\ndouble(4)), expect: :name_lower },
    { id: "def-python-colon", lesson: "methoden", code: %(def square(number):\n  number * number\nend), expect: :syn_python_colon },
    { id: "recursion-no-base", lesson: "methoden", code: %(def countdown(n)\n  puts n\n  countdown(n - 1)\nend\n\ncountdown(3)), expect: :stack },
    { id: "extra-end", lesson: "methoden", code: %(def square(number)\n  number * number\nend\nend), expect: :syn_extra_end },
    # ---- 10 klassen
    { id: "class-lowercase", lesson: "klassen", code: %(class fox\n  def shout\n    "Chunky Bacon!"\n  end\nend), expect: :syn_class_name },
    { id: "class-def-missing-end", lesson: "klassen", code: %(class Fox\n  def initialize(name)\n    @name = name\n  end\n\n  def shout\n    "Chunky Bacon!"\nend\n\nFox.new("Kaz").shout), expect: :syn_missing_end },
    { id: "no-attr-reader", lesson: "klassen", code: %(class Fox\n  def initialize(name)\n    @name = name\n  end\nend\n\nf = Fox.new("Kaz")\nf.name), expect: :attr_missing },
    { id: "ivar-typo", lesson: "klassen", code: %(class Fox\n  def initialize(name)\n    @name = name\n  end\n\n  def shout\n    @nmae.upcase + "!"\n  end\nend\n\nFox.new("Kaz").shout), expect: :nil_receiver },
    { id: "new-without-name", lesson: "klassen", code: %(class Fox\n  attr_reader :name\n\n  def initialize(name)\n    @name = name\n  end\nend\n\nFox.new), expect: :arity },
    { id: "class-name-typo", lesson: "klassen", setup: %(class Fox\n  def initialize(name) = @name = name\nend), code: %(Fxo.new("Kaz")), expect: :constant },
    { id: "de-class-in-other-cell", lesson: "klassen", lang: "de", code: %(f = Fuchs.new("Kaz")\nf.ruf), expect: :constant },
    # ---- 11 module
    { id: "module-missing-end", lesson: "module", code: %(module Loud\n  def shout\n    "CHUNKY BACON!"\n  end\n\nclass Badger\n  include Loud\nend), expect: :syn_missing_end },
    # ---- 31 tl-collections
    { id: "array-of-hashes-key", lesson: "tl-collections", setup: %(entries = [\n  { project: "ProjectX", hours: 3.5 },\n  { project: "Intern",   hours: 2.0 }\n]), code: %(entries[:project]), expect: :array_key },
    { id: "sum-into-empty-hash", lesson: "tl-collections", setup: %(entries = [\n  { project: "ProjectX", hours: 3.5 },\n  { project: "Intern",   hours: 2.0 }\n]), code: %(hours = {}\nentries.each { |e| hours[e[:project]] += e[:hours] }\nhours), expect: :nil_receiver },
    { id: "average-of-empty", lesson: "tl-collections", code: %(def average(list)\n  list.sum / list.length\nend\n\naverage([])), expect: :zero_div },
    { id: "mixed-max", lesson: "tl-collections", code: %(hours = [3, "2", 1]\nhours.max), expect: :comparison },
    # ---- 32 tl-parsing
    { id: "match-found-nothing", lesson: "tl-parsing", code: %(line = "coffee break"\nhit = line.match(/(?<from>\\d{2}:\\d{2}) (?<project>\\S+)/)\nhit[:project]), expect: :nil_receiver },
    { id: "integer-of-time", lesson: "tl-parsing", code: %(Integer("08:30")), expect: :int_parse },
    # ---- 33 tl-methods
    { id: "keyword-missing", lesson: "tl-methods", code: %(def add_entry(project:, from:, to:, note: nil)\n  { project: project, from: from, to: to, note: note }\nend\n\nadd_entry(project: "X", from: "08:30")), expect: :keywords },
    { id: "keyword-as-positional", lesson: "tl-methods", code: %(def add_entry(project:, from:, to:, note: nil)\n  { project: project, from: from, to: to, note: note }\nend\n\nadd_entry("X", "08:30", "10:00")), expect: :arity },
    { id: "keyword-typo", lesson: "tl-methods", code: %(def add_entry(project:, from:, to:, note: nil)\n  { project: project, from: from, to: to, note: note }\nend\n\nadd_entry(project: "X", from: "08:30", to: "10:00", notes: "docs")), expect: :keywords },
    { id: "uniq-bang-nil", lesson: "tl-methods", code: %(projects = ["X", "Intern"]\nunique = projects.uniq!\nunique.length), expect: :nil_receiver },
    { id: "puts-returns-nil", lesson: "tl-methods", code: %(total = puts 3.5 + 2.0\ntotal.round), expect: :nil_receiver },
    # ---- 36/37 tl-mixins, tl-blocks
    { id: "frozen-constant", lesson: "tl-mixins", code: %(PROJECTS = ["ProjectX", "Intern"].freeze\nPROJECTS << "Docs"), expect: :frozen },
    { id: "lambda-two-args", lesson: "tl-blocks", code: %(square = ->(x) { x * x }\nsquare.call(2, 3)), expect: :arity },
    { id: "find-nothing", lesson: "tl-blocks", code: %(projects = ["ProjectX", "Intern"]\nprojects.find { |p| p.start_with?("Docs") }.upcase), expect: :nil_receiver },
    # ---- 38 tl-errors
    { id: "own-error-unrescued", lesson: "tl-errors", code: %(class TimelogError < StandardError; end\n\ndef sync\n  raise TimelogError, "network error"\nend\n\nsync), expect: :own_error },
    # ---- 41 tl-pattern
    { id: "case-in-no-else", lesson: "tl-pattern", code: %(def dispatch(command)\n  case command\n  in ["add", project, hours]\n    "Entry: \#{project} (\#{hours}h)"\n  in ["report"]\n    "Report"\n  end\nend\n\ndispatch(["dance"])), expect: :no_pattern },
    # ---- 39/40 tl-formats, gems
    { id: "require-typo", lesson: "gems", code: %(require "chunky_pgn"), expect: :load_error },
    { id: "python-true", lesson: "tl-cli", code: %(verbose = True\nputs "on" if verbose), expect: :name_python_kw },
    { id: "json-parse-error", lesson: "tl-formats", code: %(require "json"\nJSON.parse("{name: 1}")), expect: nil },
    { id: "own-raise-string", lesson: "tl-errors", code: %(raise "line 7 is not a time entry"), expect: nil },
  ].freeze
end
