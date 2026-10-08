# Renders the example object graphs into examples/*.svg and a gallery page
# (examples/index.html). Plain CRuby: ruby render_examples.rb (the code is
# html/object_graph.rb now)
require_relative "../../html/object_graph"

OUT = File.join(__dir__, "examples")
Dir.mkdir(OUT) unless Dir.exist?(OUT)

class Fuchs
  attr_accessor :name, :freund

  def initialize(name) = @name = name
end

class Pfanne
  def initialize
    @inhalt = ["Speck", "Ei"]
    @heiss = true
  end
end

Punkt = Data.define(:x, :y)
Zutat = Struct.new(:name, :menge)

def build_examples
  ex = {}

  # 1. two names, one array
  a = [1, "x"]
  b = a
  ex["01_alias"] = ["a = [1, \"x\"]; b = a", { a: a, b: b }]

  # 2. dup copies the array, not the strings in it
  essen = ["Speck", "Ei"]
  kopie = essen.dup
  kopie << "Toast"
  ex["02_dup_shallow"] = ["essen = [\"Speck\", \"Ei\"]; kopie = essen.dup; kopie << \"Toast\"", { essen: essen, kopie: kopie }]

  # 3. mutation through an alias, and a real copy
  s = +"Speck"
  t = s
  u = s.dup
  t << "!"
  ex["03_string_alias"] = ["s = \"Speck\"; t = s; u = s.dup; t << \"!\"", { s: s, t: t, u: u }]

  # 4. a hash with nested values
  rezept = { name: "Pfannkuchen", zutaten: ["Mehl", "Ei", "Milch"], portionen: 4, "scharf" => false }
  ex["04_hash"] = ["rezept = { name: ..., zutaten: [...], portionen: 4, \"scharf\" => false }", { rezept: rezept }]

  # 5. objects that point at each other (a cycle) and at themselves
  kaz = Fuchs.new("Kaz")
  mimi = Fuchs.new("Mimi")
  kaz.freund = mimi
  mimi.freund = kaz
  solo = Fuchs.new("Solo")
  solo.freund = solo
  ex["05_cycle"] = ["kaz.freund = mimi; mimi.freund = kaz; solo.freund = solo", { kaz: kaz, mimi: mimi, solo: solo }]

  # 6. frozen things, Data and Struct
  farben = ["rot", "blau"].freeze
  name = "Kaz".freeze
  p = Punkt.new(x: 1, y: 2)
  z = Zutat.new("Speck", 3)
  ex["06_frozen"] = ["farben = [\"rot\", \"blau\"].freeze; name = \"Kaz\".freeze; Data, Struct", { farben: farben, name: name, p: p, z: z }]

  # 7. caps: long arrays and deep nesting
  zahlen = (1..30).map(&:to_s)
  tief = [[[[[[[["unten"]]]]]]]]
  ex["07_caps"] = ["zahlen = 30 Strings; tief = 8 Ebenen (max_items: 6, max_depth: 5)", [{ zahlen: zahlen, tief: tief }, { max_items: 6, max_depth: 5 }]]

  # 8. a whole binding, with a custom object holding a shared array
  ex["08_binding"] = ["pfanne = Pfanne.new; inhalt = pfanne's @inhalt; zahl = 42; show_objects(binding)", pfanne_binding]

  # 9. an object with a cycle through an array, plus Japanese text
  liste = ["キツネ", "ベーコン"]
  liste << liste
  ex["09_self_array"] = ["liste = [\"キツネ\", \"ベーコン\"]; liste << liste", { liste: liste }]
  ex
end

def pfanne_binding
  pfanne = Pfanne.new
  inhalt = pfanne.instance_variable_get(:@inhalt)
  zahl = 42
  [pfanne, inhalt, zahl] # all used
  binding
end

examples = build_examples
gallery = +"<!doctype html><meta charset='utf-8'><title>show_objects examples</title>" \
           "<style>body{font-family:system-ui;margin:20px;background:#f6f6f6} figure{margin:0 0 24px} " \
           "figcaption{font:13px monospace;margin-bottom:6px} img{background:#fff;border:1px solid #ccc}</style>"
examples.each do |name, (caption, roots)|
  roots, options = roots.is_a?(Array) ? roots : [roots, {}]
  svg = ObjectGraph.svg(roots, **options)
  File.write(File.join(OUT, "#{name}.svg"), svg)
  gallery << "<figure><figcaption>#{name}: #{caption.gsub('<', '&lt;')}</figcaption><img src='#{name}.svg'></figure>"
  puts "#{name}.svg  #{svg.bytesize} bytes"
end
File.write(File.join(OUT, "index.html"), gallery)
