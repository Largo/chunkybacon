# Offline harness for the notebook format: for every lesson/lang it runs the
# demo cells in a shared binding (like the browser kernel), then verifies that
# the exercise starter does NOT pass the check while every known-good solution
# (puts-style and no-puts-style) DOES pass. Mirrors main.rb's eval mechanics.
require 'json'
require 'stringio'
require_relative "../html/browser_gems"
require_relative "../html/rack_playground"
require_relative "../html/sandbox_sim"

CACHE = File.expand_path("../html/gems/cache", __dir__)
BrowserGems.cache_base = "cache"
BrowserGems.proxy_base = "remote"
BrowserGems.fetch_binary = ->(url) { (p = url.sub("cache/", "#{CACHE}/")) && File.exist?(p) ? File.binread(p) : nil }
BrowserGems.fetch_text = ->(url) { (p = url.sub("cache/", "#{CACHE}/")) && File.exist?(p) ? File.read(p) : nil }

# cell helpers as provided by main.rb in the browser
$shown_images = []
$shown_scenes = []
module Kernel
  def install_gem(name)
    "#{name} #{BrowserGems.install(name)}"
  end

  def show_image(image)
    $shown_images << (image.respond_to?(:to_data_url) ? image.to_data_url : image.to_s)
    nil
  end

  def show_browser(_app, _path = "/")
    nil
  end

  # 3D needs a WebGL canvas, so offline we only record the scene and run the
  # animation block once - enough for the checks, which look at the graph.
  def show_three(scene, _camera, **_options)
    $shown_scenes << scene
    yield 1 if block_given?
    nil
  end

  def show_irb
    nil
  end

  def show_files
    nil
  end

  def run_tests
    require "minitest"
    result = Minitest.run([])
    Minitest::Runnable.runnables.clear
    result
  end
end

require "minitest"
Minitest::Runnable.runnables.clear

# NB: the harness body lives inside a method on purpose. Lesson bindings are
# created from TOPLEVEL_BINDING, so any top-level local here would be captured
# and clobbered by lesson code (the HTTP lesson's `data = ...` did exactly
# that). Method locals are invisible to those bindings.

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
  },
  "module" => {
    "de" => [%(module Laut\n  def ruf\n    "CHUNKY BACON!"\n  end\nend\n\nclass Dachs\n  include Laut\nend\n\nDachs.new.ruf)],
    "en" => [%(module Loud\n  def shout\n    "CHUNKY BACON!"\n  end\nend\n\nclass Badger\n  include Loud\nend\n\nBadger.new.shout)]
  },
  "irb" => {
    "de" => [%([4, 8, 15].map { |x| x * 3 })],
    "en" => [%([4, 8, 15].map { |x| x * 3 })]
  },
  "gems" => {
    "de" => [%(install_gem "chunky_png"\nrequire "chunky_png"\nbild = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times do |y|\n  next unless y.even?\n  8.times { |x| bild[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }\nend\nshow_image bild)],
    "en" => [%(install_gem "chunky_png"\nrequire "chunky_png"\nimage = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::WHITE)\n8.times do |y|\n  next unless y.even?\n  8.times { |x| image[x, y] = ChunkyPNG::Color.rgb(193, 74, 46) }\nend\nshow_image image)]
  },
  "html" => {
    "de" => [%(links = doc.css("a").map { |link| link.attributes.to_h["href"] }\nlinks)],
    "en" => [%(links = doc.css("a").map { |link| link.attributes.to_h["href"] }\nlinks)]
  },
  "sinatra" => {
    "de" => [%(install_gem "sinatra"\nrequire "sinatra/base"\nclass MeineSeite < Sinatra::Base\n  get "/" do\n    "<h1>Meine Seite</h1>"\n  end\n  get "/speck" do\n    "CHUNKY BACON!"\n  end\nend\nshow_browser MeineSeite, "/speck")],
    "en" => [%(install_gem "sinatra"\nrequire "sinatra/base"\nclass MySite < Sinatra::Base\n  get "/" do\n    "<h1>My Site</h1>"\n  end\n  get "/bacon" do\n    "CHUNKY BACON!"\n  end\nend\nshow_browser MySite, "/bacon")]
  },
  "http" => {
    "de" => [%(require "net/http"\nrequire "json"\ninfo = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/sinatra.json")))\ninfo["downloads"])],
    "en" => [%(require "net/http"\nrequire "json"\ninfo = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/sinatra.json")))\ninfo["downloads"])]
  },
  "three" => {
    "de" => [
      %(turm = Three::Scene.new\nturm.add(Three::AmbientLight.new(0xffffff, 0.4))\nlampe = Three::DirectionalLight.new(0xffffff, 2.0)\nlampe.position.set(2, 4, 3)\nturm.add(lampe)\n\n3.times do |i|\n  klotz = Three::Mesh.new(\n    Three::BoxGeometry.new(1, 1, 1),\n    Three::MeshStandardMaterial.new(color: 0xe8722a)\n  )\n  klotz.position.y = i - 1.0\n  turm.add(klotz)\nend\n\nshow_three turm, kamera do\n  turm.rotation.y += 0.01\nend)
    ],
    "en" => [
      %(tower = Three::Scene.new\ntower.add(Three::AmbientLight.new(0xffffff, 0.4))\nsun = Three::DirectionalLight.new(0xffffff, 2.0)\nsun.position.set(2, 4, 3)\ntower.add(sun)\n\n3.times do |i|\n  block = Three::Mesh.new(\n    Three::BoxGeometry.new(1, 1, 1),\n    Three::MeshStandardMaterial.new(color: 0xe8722a)\n  )\n  block.position.y = i - 1.0\n  tower.add(block)\nend\n\nshow_three tower, camera do\n  tower.rotation.y += 0.01\nend)
    ]
  },
  "tl-collections" => {
    "de" => [%(eintraege = [{ projekt: "ProjectX", stunden: 3.5 }, { projekt: "Intern", stunden: 2.0 }, { projekt: "ProjectX", stunden: 3.0 }]
stunden = eintraege.group_by { |e| e[:projekt] }.transform_values { |l| l.sum { |e| e[:stunden] } })],
    "en" => [%(entries = [{ project: "ProjectX", hours: 3.5 }, { project: "Intern", hours: 2.0 }, { project: "ProjectX", hours: 3.0 }]
hours = entries.group_by { |e| e[:project] }.transform_values { |l| l.sum { |e| e[:hours] } })]
  },
  "tl-parsing" => {
    "de" => [%(def parse_zeile(zeile)
  muster = /(?<datum>\\d{4}-\\d{2}-\\d{2}) (?<von>\\d{2}:\\d{2})-(?<bis>\\d{2}:\\d{2}) (?<projekt>\\S+)/
  treffer = zeile.match(muster)
  return nil unless treffer
  { projekt: treffer[:projekt], von: treffer[:von], bis: treffer[:bis] }
end)],
    "en" => [%(def parse_line(line)
  pattern = /(?<date>\\d{4}-\\d{2}-\\d{2}) (?<from>\\d{2}:\\d{2})-(?<to>\\d{2}:\\d{2}) (?<project>\\S+)/
  hit = line.match(pattern)
  return nil unless hit
  { project: hit[:project], from: hit[:from], to: hit[:to] }
end)]
  },
  "tl-methods" => {
    "de" => [%(def als_stunden(uhrzeit)
  h, m = uhrzeit.split(":").map(&:to_i)
  h + m / 60.0
end

def add_entry(projekt:, von:, bis:, notiz: nil)
  { projekt: projekt, von: von, bis: bis, notiz: notiz, stunden: als_stunden(bis) - als_stunden(von) }
end)],
    "en" => [%(def as_hours(time)
  h, m = time.split(":").map(&:to_i)
  h + m / 60.0
end

def add_entry(project:, from:, to:, note: nil)
  { project: project, from: from, to: to, note: note, hours: as_hours(to) - as_hours(from) }
end)]
  },
  "tl-classes" => {
    "de" => [%(class Timesheet
  def initialize
    @eintraege = []
  end

  def add(entry)
    @eintraege << entry
    self
  end

  def total_for(projekt)
    @eintraege.select { |e| e.projekt == projekt }.sum(&:stunden)
  end
end)],
    "en" => [%(class Timesheet
  def initialize
    @entries = []
  end

  def add(entry)
    @entries << entry
    self
  end

  def total_for(project)
    @entries.select { |e| e.project == project }.sum(&:hours)
  end
end)]
  },
  "tl-minitest" => {
    "de" => [%(class Eintrag
  attr_reader :projekt, :stunden
  def initialize(projekt, stunden)
    @projekt = projekt
    @stunden = stunden
  end
  def gueltig?
    stunden > 0 && !projekt.to_s.empty?
  end
end

class TestEintrag < Minitest::Test
  def test_gueltig
    assert Eintrag.new("X", 2.0).gueltig?
  end

  def test_negative_stunden
    refute Eintrag.new("X", -1).gueltig?
  end
end

run_tests)],
    "en" => [%(class Entry
  attr_reader :project, :hours
  def initialize(project, hours)
    @project = project
    @hours = hours
  end
  def valid?
    hours > 0 && !project.to_s.empty?
  end
end

class TestEntry < Minitest::Test
  def test_valid
    assert Entry.new("X", 2.0).valid?
  end

  def test_negative_hours
    refute Entry.new("X", -1).valid?
  end
end

run_tests)]
  },
  "tl-mixins" => {
    "de" => [%(class Timesheet
  include Enumerable

  def initialize(eintraege)
    @eintraege = eintraege
  end

  def each(&block)
    @eintraege.each(&block)
  end
end

ts = Timesheet.new([{ projekt: "A", stunden: 2.0 }, { projekt: "B", stunden: 1.0 }])
ts.sum { |e| e[:stunden] })],
    "en" => [%(class Timesheet
  include Enumerable

  def initialize(entries)
    @entries = entries
  end

  def each(&block)
    @entries.each(&block)
  end
end

ts = Timesheet.new([{ project: "A", hours: 2.0 }, { project: "B", hours: 1.0 }])
ts.sum { |e| e[:hours] })]
  },
  "tl-blocks" => {
    "de" => [%(def each_projekt(eintraege)
  eintraege.group_by { |e| e[:projekt] }.each { |projekt, liste| yield(projekt, liste) }
end)],
    "en" => [%(def each_project(entries)
  entries.group_by { |e| e[:project] }.each { |project, list| yield(project, list) }
end)]
  },
  "tl-errors" => {
    "de" => [%(class TimelogError < StandardError; end

def sync_mit_retry(dienst, max:)
  versuche = 0
  begin
    versuche += 1
    dienst.call
  rescue TimelogError
    retry if versuche < max
    raise
  end
end)],
    "en" => [%(class TimelogError < StandardError; end

def sync_with_retry(service, max:)
  attempts = 0
  begin
    attempts += 1
    service.call
  rescue TimelogError
    retry if attempts < max
    raise
  end
end)]
  },
  "tl-formats" => {
    "de" => [%(require "csv"

def nach_csv(eintraege)
  CSV.generate do |csv|
    csv << ["projekt", "stunden"]
    eintraege.each { |e| csv << [e[:projekt], e[:stunden]] }
  end
end

def aus_csv(text)
  CSV.parse(text, headers: true).map { |z| { projekt: z["projekt"], stunden: z["stunden"].to_f } }
end

daten = [{ projekt: "A", stunden: 1.5 }, { projekt: "B", stunden: 2.0 }]
File.write("eintraege.csv", nach_csv(daten))
aus_csv(File.read("eintraege.csv")))],
    "en" => [%(require "csv"

def to_csv(entries)
  CSV.generate do |csv|
    csv << ["project", "hours"]
    entries.each { |e| csv << [e[:project], e[:hours]] }
  end
end

def from_csv(text)
  CSV.parse(text, headers: true).map { |r| { project: r["project"], hours: r["hours"].to_f } }
end

data = [{ project: "A", hours: 1.5 }, { project: "B", hours: 2.0 }]
File.write("entries.csv", to_csv(data))
from_csv(File.read("entries.csv")))]
  },
  "tl-cli" => {
    "de" => [%(require "optparse"

def parse_argv(argv)
  optionen = { woche: false, format: "text" }
  parser = OptionParser.new do |p|
    p.on("--week") { optionen[:woche] = true }
    p.on("--format FORMAT") { |f| optionen[:format] = f }
  end
  rest = parser.parse(argv)
  { befehl: rest.first, woche: optionen[:woche], format: optionen[:format] }
end)],
    "en" => [%(require "optparse"

def parse_argv(argv)
  options = { week: false, format: "text" }
  parser = OptionParser.new do |p|
    p.on("--week") { options[:week] = true }
    p.on("--format FORMAT") { |f| options[:format] = f }
  end
  rest = parser.parse(argv)
  { command: rest.first, week: options[:week], format: options[:format] }
end)]
  },
  "tl-pattern" => {
    "de" => [%(def dispatch(befehl)
  case befehl
  in ["add", projekt, stunden]
    "Eintrag: \#{projekt} (\#{stunden}h)"
  in ["report"]
    "Bericht"
  in ["export", format]
    "Export als \#{format}"
  else
    "Unbekanntes Kommando"
  end
end)],
    "en" => [%(def dispatch(command)
  case command
  in ["add", project, hours]
    "Entry: \#{project} (\#{hours}h)"
  in ["report"]
    "Report"
  in ["export", format]
    "Export as \#{format}"
  else
    "Unknown command"
  end
end)]
  },
  "tl-meta" => {
    "de" => [%(class Modell
  def self.validates_presence_of(*felder)
    define_method(:valid?) do
      felder.all? { |f| wert = send(f); !wert.nil? && wert != "" }
    end
  end
end

class Buchung < Modell
  attr_accessor :projekt, :stunden
  validates_presence_of :projekt
end)],
    "en" => [%(class BaseModel
  def self.validates_presence_of(*fields)
    define_method(:valid?) do
      fields.all? { |f| value = send(f); !value.nil? && value != "" }
    end
  end
end

class Booking < BaseModel
  attr_accessor :project, :hours
  validates_presence_of :project
end)]
  },
  "tl-dsl" => {
    "de" => [%(module Timelog
  class Konfiguration
    attr_reader :projekte, :raster

    def initialize
      @projekte = {}
      @raster = 60
    end

    def projekt(name, satz:)
      @projekte[name] = satz
    end

    def runde_auf(minuten)
      @raster = minuten
    end
  end

  def self.configure(&block)
    @config = Konfiguration.new
    @config.instance_eval(&block)
    @config
  end

  def self.config
    @config
  end
end)],
    "en" => [%(module Timelog
  class Configuration
    attr_reader :projects, :grid

    def initialize
      @projects = {}
      @grid = 60
    end

    def project(name, rate:)
      @projects[name] = rate
    end

    def round_to(minutes)
      @grid = minutes
    end
  end

  def self.configure(&block)
    @config = Configuration.new
    @config.instance_eval(&block)
    @config
  end

  def self.config
    @config
  end
end)]
  },
  "tl-quality" => {
    "de" => [%(def runde(minuten, raster)
  (minuten.to_f / raster).round * raster
end)],
    "en" => [%(def round_to(minutes, grid)
  (minutes.to_f / grid).round * grid
end)]
  },
  "tl-performance" => {
    "de" => [%(eintraege = 500.times.map { |i| { projekt: "P\#{i % 5}", stunden: 1.0 } }

def langsamer_bericht(eintraege)
  eintraege.map { |e| e[:projekt] }.uniq.to_h do |p|
    [p, eintraege.select { |e| e[:projekt] == p }.sum { |e| e[:stunden] }]
  end
end

def schneller_bericht(eintraege)
  eintraege.group_by { |e| e[:projekt] }.transform_values { |l| l.sum { |e| e[:stunden] } }
end)],
    "en" => [%(entries = 500.times.map { |i| { project: "P\#{i % 5}", hours: 1.0 } }

def slow_report(entries)
  entries.map { |e| e[:project] }.uniq.to_h do |p|
    [p, entries.select { |e| e[:project] == p }.sum { |e| e[:hours] }]
  end
end

def fast_report(entries)
  entries.group_by { |e| e[:project] }.transform_values { |l| l.sum { |e| e[:hours] } }
end)]
  },
  "tl-capstone" => {
    "de" => [%(install_gem "roda"
require "roda"
require "erb"

EINTRAEGE = [
  { projekt: "ProjectX", stunden: 3.5 },
  { projekt: "Intern",   stunden: 2.0 },
  { projekt: "ProjectX", stunden: 3.0 }
]

class TimelogWeb < Roda
  route do |r|
    r.root do
      "<h1>timelog</h1><a href='/projekt/ProjectX'>ProjectX</a>"
    end

    r.get "projekt", String do |name|
      passende = EINTRAEGE.select { |e| e[:projekt] == name }
      "<h2>\#{name}</h2>" + passende.map { |e| "\#{e[:stunden]}h" }.join(", ")
    end
  end
end

show_browser TimelogWeb, "/")],
    "en" => [%(install_gem "roda"
require "roda"
require "erb"

ENTRIES = [
  { project: "ProjectX", hours: 3.5 },
  { project: "Intern",   hours: 2.0 },
  { project: "ProjectX", hours: 3.0 }
]

class TimelogWeb < Roda
  route do |r|
    r.root do
      "<h1>timelog</h1><a href='/project/ProjectX'>ProjectX</a>"
    end

    r.get "project", String do |name|
      matching = ENTRIES.select { |e| e[:project] == name }
      "<h2>\#{name}</h2>" + matching.map { |e| "\#{e[:hours]}h" }.join(", ")
    end
  end
end

show_browser TimelogWeb, "/")]
  },
  "roda" => {
    "de" => [%(install_gem "roda"\nrequire "roda"\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      "<h1>Kiosk</h1>"\n    end\n    r.get "bestellung", Integer do |anzahl|\n      "\#{anzahl} Streifen Speck, kommt sofort!"\n    end\n  end\nend\nshow_browser Kiosk, "/bestellung/5")],
    "en" => [%(install_gem "roda"\nrequire "roda"\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      "<h1>Kiosk</h1>"\n    end\n    r.get "order", Integer do |amount|\n      "\#{amount} strips of bacon, coming right up!"\n    end\n  end\nend\nshow_browser Kiosk, "/order/5")]
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

def run_harness
  data = JSON.parse(File.read(File.expand_path("lessons.json", __dir__)))
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
        # the nokogiri demo cell is SUPPOSED to raise NativeGemError
        next if err.is_a?(BrowserGems::NativeGemError)
        if err
          puts "FAIL #{lesson["id"]}/#{lang}: demo cell raised #{err.class}: #{err.message}"
          failures += 1
          demo_failed = true
        end
      end
      next if demo_failed

      $shown_images = []
      $shown_scenes = []
      SandboxFS.reset!
      result, output, error = run_in(bind, candidate)
      if error && label != "starter"
        puts "FAIL #{lesson["id"]}/#{lang} (#{label}): raised #{error.class}: #{error.message}"
        failures += 1
        next
      end

      bind.local_variable_set(:output, output)
      bind.local_variable_set(:result, result)
      bind.local_variable_set(:code, candidate)
      bind.local_variable_set(:images, $shown_images.dup)
      bind.local_variable_set(:scenes, $shown_scenes.dup)
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
  failures.zero?
end

exit(run_harness ? 0 : 1)
