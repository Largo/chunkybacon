# Offline harness for the notebook format: for every lesson/lang it runs the
# demo cells in a shared binding (like the browser kernel), then verifies that
# the exercise starter does NOT pass the check while every known-good solution
# (puts-style and no-puts-style) DOES pass. Mirrors main.rb's eval mechanics.
require 'json'
require 'stringio'
require_relative "../html/browser_gems"
require_relative "../html/rack_playground"
require_relative "../html/sandbox_sim"
require "tmpdir"
require "fileutils"

# Gem code "lives" under BrowserGems.root and cells write files relative to
# the working directory; both are temp dirs here, as both are wasm memory in
# the browser, so nothing lands in the checkout or the real filesystem root.
BrowserGems.root = Dir.mktmpdir("browser_gems")
WORKDIR = Dir.mktmpdir("chunky_cwd")
at_exit { FileUtils.rm_rf([BrowserGems.root, WORKDIR]) }

CACHE = File.expand_path("../html/gems/cache", __dir__)
BrowserGems.cache_base = "cache"
BrowserGems.proxy_base = "remote"
BrowserGems.fetch_binary = ->(url) { (p = url.sub("cache/", "#{CACHE}/")) && File.exist?(p) ? File.binread(p) : nil }
BrowserGems.fetch_text = ->(url) { (p = url.sub("cache/", "#{CACHE}/")) && File.exist?(p) ? File.read(p) : nil }

# cell helpers as provided by main.rb in the browser
$shown_images = []
$shown_scenes = []
$shown_apps = []
$explicit_downloads = []
$letter_answers = []
$shown_audios = []
# Numo is C; the lessons run on the browser's pure-Ruby stand-in, which
# main.rb serves for these requires - here even where the real gem is installed
require_relative "../html/numo_narray"
$LOADED_FEATURES.push("numo/narray.rb", "numo/narray/alt.rb")
# processing draws through C++ (rays, reflexion); require "processing" finds
# the browser's stand-in, on the first require as in the browser. A cell's
# sketch starts after the cell, as main.rb starts it; $shown_sketches has it
SHIMS_DIR = Dir.mktmpdir("chunky_shims")
at_exit { FileUtils.rm_rf(SHIMS_DIR) }
File.write(File.join(SHIMS_DIR, "processing.rb"),
           "load #{File.expand_path('../html/processing.rb', __dir__).inspect}\n")
$LOAD_PATH.unshift(SHIMS_DIR)
$shown_sketches = []
# show_objects (lessons 7, 8, 11) draws through the show_image below, as in
# the browser, so a check finds its picture in images
require_relative "../html/object_graph"
# turtle { } (lesson 10) shows its picture the same way; Turtle.from(images)
# finds the turtles behind it, which is what the lesson's check grades
require_relative "../html/turtle"
# show_game (lesson 38): game.rb runs headless as it is; the stub below
# records each game, and a check plays copies of them (games), as in main.rb
require_relative "../html/game"
# a lesson with "engine": "picoruby" runs on PicoRuby.wasm in the browser;
# here its exercise runs under CRuby, and the check gets the result as the
# page hands it over - a PicoRubyCells::Value, PicoRuby's inspect text
require_relative "../html/picoruby_cells"
$shown_games = []
# require "ruby2d" finds the browser's stand-in (html/ruby2d.rb over the
# gem's own Ruby, assets/ruby2d/), mixed into the top level as in main.rb;
# a shown window goes to $shown_games, and a check plays a replayed copy
File.write(File.join(SHIMS_DIR, "ruby2d.rb"),
           "load #{File.expand_path('../html/ruby2d.rb', __dir__).inspect} unless defined?(Ruby2D::Page)\n" \
           "Ruby2D.on_show__ = ->(runner) { $shown_games << runner }\nRuby2D.mix__\n")
# a lesson after the ruby2d one must not find `show` or `Square` at the top
# level, as in main.rb (sync_state); the next require mixes again
def unmix_ruby2d
  return unless defined?(Ruby2D::Page)

  Ruby2D.unmix__
  $LOADED_FEATURES.delete_if { |f| f.start_with?(SHIMS_DIR) && f.end_with?("/ruby2d.rb") }
end
module Kernel
  def download_file(data, name = nil)
    $explicit_downloads << (name || data).to_s
    nil
  end

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

  def show_pdf(_pdf)
    nil
  end

  # what main.rb's show_audio takes - WAV bytes, a file's name, an Array of
  # samples - recorded as WAV bytes for a check's `audios`
  def show_audio(sound, rate: 22_050)
    bytes = if sound.is_a?(Array)
              data = sound.map { |s| (s.to_f.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
              ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16, "data", data.bytesize]
                .pack("a4Va4a4VvvVVvva4V") + data
            elsif sound.to_s.b.start_with?("RIFF") then sound.to_s.b
            elsif SandboxFS.virtual?(sound.to_s) && SandboxFS.exist?(sound.to_s) then SandboxFS.read(sound.to_s).b
            else File.binread(sound.to_s)
            end
    raise ArgumentError, "show_audio: not a WAV file" unless bytes.start_with?("RIFF")

    $shown_audios << bytes
    nil
  end

  # Offline there is no DOM, so the app runs against a display service that
  # only records which drawables Lacci asked for - the same list ShoesDom
  # exposes to checks in the browser.
  def show_shoes(width: 460, height: 260, &block)
    HarnessShoes.run(&block)
    nil
  end

  # 3D needs a WebGL canvas, so offline we only record the scene and run the
  # animation block once - enough for the checks, which look at the graph.
  def show_three(scene, _camera, **_options)
    $shown_scenes << scene
    yield 1 if block_given?
    nil
  end

  # The letter needs a pen; offline the block gets four digits from
  # digits.csv, 3, 0, 0, 0 - the postcode both lessons' tables have
  def show_letter(boxes: 4, &block)
    rows = File.read(File.expand_path("../html/assets/data/digits.csv", __dir__)).lines.map { |l| l.split(",").map(&:to_i) }
    written = [3, 0, 0, 0].first(boxes).map { |d| rows.find { |r| r.last == d }.first(64) }
    $letter_answers << block.call(written).to_s
    nil
  end

  def show_game(width: 20, height: 15, &setup)
    $shown_games << ChunkyGame.new(width: width, height: height, &setup)
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

# Lacci display service for the harness: no DOM, it only records the Shoes
# class names created, into the last entry of $shown_apps.
module HarnessShoes
  module NullLog
    module Logger
      def self.debug(*) = nil
      def self.info(*) = nil
      def self.warn(*) = nil
      def self.error(*) = nil
      def self.fatal(*) = nil
    end
    def self.logger_for_component(_c) = Logger
    def self.configure_logger(_c) = nil
  end

  def self.setup!
    return if @setup

    Shoes::Log.instance = NullLog unless Shoes::Log.instance
    # same as ShoesDom: every cell's app lives at once
    Shoes::FEATURES << :multi_app unless Shoes::FEATURES.include?(:multi_app)
    drawable = Class.new(Shoes::Linkable) do
      def initialize(id) = super(linkable_id: id)
    end
    app = Class.new(drawable) do
      def initialize(id)
        super
        bind_shoes_event(event_name: "run") { send_shoes_event("return", event_name: "custom_event_loop") }
      end
    end
    service = Class.new(Shoes::DisplayService) do
      define_method(:create_display_drawable_for) do |cls, id, _props, parent_id:, is_widget:|
        $shown_apps.last << cls unless cls == "App"
        d = cls == "App" ? app.new(id) : drawable.new(id)
        set_drawable_pairing(id, d)
        d
      end
      define_method(:destroy) { nil }
    end
    Shoes::DisplayService.set_display_service_class(service)
    @setup = true
  end

  def self.run(&block)
    setup!
    $shown_apps << []
    Shoes.app(title: "Shoes", width: 460, height: 260, &block)
  end
end

# NB: the harness body lives inside a method on purpose. Lesson bindings are
# created from TOPLEVEL_BINDING, so any top-level local here would be captured
# and clobbered by lesson code (the HTTP lesson's `data = ...` did exactly
# that). Method locals are invisible to those bindings.

LANGS = %w[de en ja].freeze
# The Japanese lessons run the English code (only its comments are
# translated), so they are checked with the English solutions.
SOLUTION_LANG = { "ja" => "en" }.freeze

# Lessons that need the browser: PyCall talks to Pyodide (html/pycall.rb),
# Sequel's sqlite3 to sql.js (html/sqlite3_sqljs.rb), and Herb's parser is
# its WebAssembly build (html/herb_bridge.rb) - only a page has them;
# test/browser_test.mjs runs them.
BROWSER_ONLY = %w[pycall sympy numpy matplotlib sklearn sequel erb].freeze

# the Rumale exercise's picture of a seven (its starter defines it too)
RUMALE_SEVEN = "PIC = %w[.######. ......#. .....#.. ....#... ...#.... ...#.... ..#..... ..#.....].join(\"\\n\") + \"\\n\"\n"

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
  # the snowflake, and the inward one ("anti-snowflake"): both are the recursion
  "turtle" => {
    "de" => [%(def koch(laenge, tiefe)\n  if tiefe == 0\n    forward laenge\n  else\n    koch(laenge / 3.0, tiefe - 1)\n    left 60\n    koch(laenge / 3.0, tiefe - 1)\n    right 120\n    koch(laenge / 3.0, tiefe - 1)\n    left 60\n    koch(laenge / 3.0, tiefe - 1)\n  end\nend\n\nturtle do\n  3.times do\n    koch(270, 3)\n    right 120\n  end\nend),
             %(def koch(laenge, tiefe)\n  if tiefe == 0\n    forward laenge\n  else\n    koch(laenge / 3.0, tiefe - 1)\n    right 60\n    koch(laenge / 3.0, tiefe - 1)\n    left 120\n    koch(laenge / 3.0, tiefe - 1)\n    right 60\n    koch(laenge / 3.0, tiefe - 1)\n  end\nend\n\nturtle do\n  3.times do\n    koch(270, 3)\n    right 120\n  end\nend)],
    "en" => [%(def koch(length, depth)\n  if depth == 0\n    forward length\n  else\n    koch(length / 3.0, depth - 1)\n    left 60\n    koch(length / 3.0, depth - 1)\n    right 120\n    koch(length / 3.0, depth - 1)\n    left 60\n    koch(length / 3.0, depth - 1)\n  end\nend\n\nturtle do\n  3.times do\n    koch(270, 3)\n    right 120\n  end\nend),
             %(def koch(length, depth)\n  if depth == 0\n    forward length\n  else\n    koch(length / 3.0, depth - 1)\n    right 60\n    koch(length / 3.0, depth - 1)\n    left 120\n    koch(length / 3.0, depth - 1)\n    right 60\n    koch(length / 3.0, depth - 1)\n  end\nend\n\nturtle do\n  3.times do\n    koch(270, 3)\n    right 120\n  end\nend)]
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
    "de" => [%(links = doc.css("a").map { |link| link["href"] }\nlinks)],
    "en" => [%(links = doc.css("a").map { |link| link["href"] }\nlinks)]
  },
  "sinatra" => {
    "de" => [%(install_gem "sinatra"\nrequire "sinatra/base"\nclass MeineSeite < Sinatra::Base\n  get "/" do\n    "<h1>Meine Seite</h1>"\n  end\n  get "/speck" do\n    "CHUNKY BACON!"\n  end\nend\nshow_browser MeineSeite, "/speck")],
    "en" => [%(install_gem "sinatra"\nrequire "sinatra/base"\nclass MySite < Sinatra::Base\n  get "/" do\n    "<h1>My Site</h1>"\n  end\n  get "/bacon" do\n    "CHUNKY BACON!"\n  end\nend\nshow_browser MySite, "/bacon")]
  },
  "http" => {
    "de" => [%(require "net/http"\nrequire "json"\ninfo = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/sinatra.json")))\ninfo["downloads"])],
    "en" => [%(require "net/http"\nrequire "json"\ninfo = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/sinatra.json")))\ninfo["downloads"])]
  },
  "bigdecimal" => {
    "de" => [%(require "bigdecimal/util"\ntotal = "4.20".to_d * 3 + "1.15".to_d * 2 + "3.80".to_d\ntotal)],
    "en" => [%(require "bigdecimal/util"\ntotal = "4.20".to_d * 3 + "1.15".to_d * 2 + "3.80".to_d\ntotal)]
  },
  "three" => {
    "de" => [
      %(turm = Three::Scene.new\nturm.add(Three::AmbientLight.new(0xffffff, 0.4))\nlampe = Three::DirectionalLight.new(0xffffff, 2.0)\nlampe.position.set(2, 4, 3)\nturm.add(lampe)\n\n3.times do |i|\n  klotz = Three::Mesh.new(\n    Three::BoxGeometry.new(1, 1, 1),\n    Three::MeshStandardMaterial.new(color: 0xe8722a)\n  )\n  klotz.position.y = i - 1.0\n  turm.add(klotz)\nend\n\nshow_three turm, kamera do\n  turm.rotation.y += 0.01\nend)
    ],
    "en" => [
      %(tower = Three::Scene.new\ntower.add(Three::AmbientLight.new(0xffffff, 0.4))\nsun = Three::DirectionalLight.new(0xffffff, 2.0)\nsun.position.set(2, 4, 3)\ntower.add(sun)\n\n3.times do |i|\n  block = Three::Mesh.new(\n    Three::BoxGeometry.new(1, 1, 1),\n    Three::MeshStandardMaterial.new(color: 0xe8722a)\n  )\n  block.position.y = i - 1.0\n  tower.add(block)\nend\n\nshow_three tower, camera do\n  tower.rotation.y += 0.01\nend)
    ]
  },
  "pptx" => {
    "de" => [%(karte = Pptx::Presentation.new_default
titel = karte.slides.add(karte.slide_layouts["Title Slide"])
titel.shapes.title.text = "Speisekarte"
%w[Vorspeisen Hauptgänge].each do |gang|
  folie = karte.slides.add(karte.slide_layouts["Title and Content"])
  folie.shapes.title.text = gang
  folie.placeholders[1].text_frame.text = "Speck\nEier"
end
karte.save("karte.pptx"))],
    "en" => [%(menu = Pptx::Presentation.new_default
title = menu.slides.add(menu.slide_layouts["Title Slide"])
title.shapes.title.text = "Menu"
%w[Starters Mains].each do |course|
  slide = menu.slides.add(menu.slide_layouts["Title and Content"])
  slide.shapes.title.text = course
  slide.placeholders[1].text_frame.text = "Bacon\nEggs"
end
menu.save("menu.pptx"))]
  },
  "pdf" => {
    "de" => [%(require "prawn"
Prawn::Document.generate("urkunde.pdf") do
  text "Stufe 1"
  start_new_page
  text "Stufe 2"
  start_new_page
  text "Stufe 3"
end), %(install_gem "prawn"
pdf = Prawn::Document.new
3.times do |i|
  pdf.start_new_page unless i.zero?
  pdf.text "Stufe \#{i + 1}"
end
pdf.render_file "urkunde.pdf")],
    "en" => [%(require "prawn"
Prawn::Document.generate("certificate.pdf") do
  text "Level 1"
  start_new_page
  text "Level 2"
  start_new_page
  text "Level 3"
end), %(install_gem "prawn"
pdf = Prawn::Document.new
3.times do |i|
  pdf.start_new_page unless i.zero?
  pdf.text "Level \#{i + 1}"
end
pdf.render_file "certificate.pdf")]
  },
  "jpeg" => {
    "de" => [%(require "pure_jpeg"
karte = PureJPEG::Source::RawSource.new(80, 60) do |x, y|
  y < 30 ? [100, 160, 230] : [60, 160, 60]
end
PureJPEG.encode(karte).write("postkarte.jpg")), %(install_gem "pure_jpeg"
karte = PureJPEG::Source::RawSource.new(80, 60)
80.times do |x|
  60.times { |y| y < 30 ? karte.set(x, y, 100, 160, 230) : karte.set(x, y, 60, 160, 60) }
end
PureJPEG.encode(karte, quality: 60).write("postkarte.jpg"))],
    "en" => [%(require "pure_jpeg"
card = PureJPEG::Source::RawSource.new(80, 60) do |x, y|
  y < 30 ? [100, 160, 230] : [60, 160, 60]
end
PureJPEG.encode(card).write("postcard.jpg")), %(install_gem "pure_jpeg"
card = PureJPEG::Source::RawSource.new(80, 60)
80.times do |x|
  60.times { |y| y < 30 ? card.set(x, y, 100, 160, 230) : card.set(x, y, 60, 160, 60) }
end
PureJPEG.encode(card, quality: 60).write("postcard.jpg"))]
  },
  "scarpe" => {
    "de" => [
      %(show_shoes do\n  stack do\n    title "Gruss-App"\n    @feld = edit_line ""\n    @gruss = para "Wer bist du?"\n    button "Gruess mich" do\n      @gruss.replace("Hallo, \#{@feld.text}!")\n    end\n  end\nend)
    ],
    "en" => [
      %(show_shoes do\n  stack do\n    title "Greeter"\n    @field = edit_line ""\n    @greeting = para "Who are you?"\n    button "Greet me" do\n      @greeting.replace("Hello, \#{@field.text}!")\n    end\n  end\nend)
    ]
  },
  "rubykaigi" => {
    "de" => [%(require "prism"
def eingaben(zeilen)
  fertig = []
  puffer = []
  zeilen.each do |zeile|
    puffer << zeile
    code = puffer.join("\n")
    if Prism.parse(code).success?
      fertig << code
      puffer = []
    end
  end
  fertig
end), %(def eingaben(zeilen)
  ergebnis = []
  code = nil
  zeilen.each do |zeile|
    code = code ? code + "\n" + zeile : zeile
    begin
      RubyVM::InstructionSequence.compile(code)
      ergebnis << code
      code = nil
    rescue SyntaxError
    end
  end
  ergebnis
end)],
    "en" => [%(require "prism"
def inputs(lines)
  done = []
  buffer = []
  lines.each do |line|
    buffer << line
    code = buffer.join("\n")
    if Prism.parse(code).success?
      done << code
      buffer = []
    end
  end
  done
end), %(def inputs(lines)
  result = []
  code = nil
  lines.each do |line|
    code = code ? code + "\n" + line : line
    begin
      RubyVM::InstructionSequence.compile(code)
      result << code
      code = nil
    rescue SyntaxError
    end
  end
  result
end)]
  },
  # one with File.binwrite (a real file), one with File.write (the virtual
  # store) and other waves - the check reads either, and finds the notes in
  # any wave shape
  "musik" => {
    "de" => [
      %(akkord = zusammen(*%w[C4 E4 G4 C5].map { |name| huelle(ton(frequenz(name), 1.0, :sinus, 0.2)) })
File.binwrite("tusch.wav", wav(noten("C4 E4 G4 C5") + akkord))),
      %(akkord = zusammen(*%w[C4 E4 G4 C5].map { |n| ton(frequenz(n), 1.0, :rechteck, 0.15) })
File.write("tusch.wav", wav(noten("C4 E4 G4 C5", welle: :rechteck) + akkord))
show_audio "tusch.wav")
    ],
    "en" => [
      %(chord = mix(*%w[C4 E4 G4 C5].map { |name| envelope(tone(frequency(name), 1.0, :sine, 0.2)) })
File.binwrite("fanfare.wav", wav(notes("C4 E4 G4 C5") + chord))),
      %(chord = mix(*%w[C4 E4 G4 C5].map { |n| tone(frequency(n), 1.0, :saw, 0.15) })
File.write("fanfare.wav", wav(notes("C4 E4 G4 C5", wave: :saw) + chord))
show_audio "fanfare.wav")
    ]
  },
  # Snake without walls: % (the hint's way), and the edges one by one; the
  # check plays a copy of the game headless (games, ChunkyGame#fresh)
  "snake" => {
    "de" => [%(show_game(width: 16, height: 12) do |g|
  fuchs = [[4, 6], [3, 6], [2, 6]]
  kurs = [1, 0]
  futter = [10, 6]
  gefressen = 0
  g.on_key(:left)  { kurs = [-1, 0] unless kurs == [1, 0] }
  g.on_key(:right) { kurs = [1, 0]  unless kurs == [-1, 0] }
  g.on_key(:up)    { kurs = [0, -1] unless kurs == [0, 1] }
  g.on_key(:down)  { kurs = [0, 1]  unless kurs == [0, -1] }
  g.cell(*futter, :bacon)
  fuchs.each { |teil| g.cell(*teil, :body) }
  g.every(0.15) do
    x, y = fuchs.first
    kopf = [(x + kurs[0]) % 16, (y + kurs[1]) % 12]
    if fuchs.include?(kopf)
      g.game_over("Autsch! \#{gefressen} Speck.")
      next
    end
    fuchs.unshift(kopf)
    if kopf == futter
      gefressen += 1
      futter = g.free_cells.sample
    else
      fuchs.pop
    end
    g.clear
    g.cell(*futter, :bacon)
    fuchs.each { |teil| g.cell(*teil, :body) }
    g.cell(*kopf, :chunky)
    g.status("Speck: \#{gefressen}")
  end
end),
             %(show_game(width: 16, height: 12) do |g|
  fuchs = [[4, 6], [3, 6], [2, 6]]
  kurs = [1, 0]
  futter = [10, 6]
  gefressen = 0
  g.on_key(:left)  { kurs = [-1, 0] unless kurs == [1, 0] }
  g.on_key(:right) { kurs = [1, 0]  unless kurs == [-1, 0] }
  g.on_key(:up)    { kurs = [0, -1] unless kurs == [0, 1] }
  g.on_key(:down)  { kurs = [0, 1]  unless kurs == [0, -1] }
  g.cell(*futter, :bacon)
  fuchs.each { |teil| g.cell(*teil, :body) }
  g.every(0.15) do
    x, y = fuchs.first
    kopf = [x + kurs[0], y + kurs[1]]
    kopf[0] = 0 if kopf[0] == g.width
    kopf[0] = g.width - 1 if kopf[0] < 0
    kopf[1] = 0 if kopf[1] == g.height
    kopf[1] = g.height - 1 if kopf[1] < 0
    if fuchs.include?(kopf)
      g.game_over("Autsch! \#{gefressen} Speck.")
      next
    end
    fuchs.unshift(kopf)
    if kopf == futter
      gefressen += 1
      futter = g.free_cells.sample
    else
      fuchs.pop
    end
    g.clear
    g.cell(*futter, :bacon)
    fuchs.each { |teil| g.cell(*teil, :body) }
    g.cell(*kopf, :chunky)
    g.status("Speck: \#{gefressen}")
  end
end)],
    "en" => [%(show_game(width: 16, height: 12) do |g|
  fox = [[4, 6], [3, 6], [2, 6]]
  heading = [1, 0]
  food = [10, 6]
  eaten = 0
  g.on_key(:left)  { heading = [-1, 0] unless heading == [1, 0] }
  g.on_key(:right) { heading = [1, 0]  unless heading == [-1, 0] }
  g.on_key(:up)    { heading = [0, -1] unless heading == [0, 1] }
  g.on_key(:down)  { heading = [0, 1]  unless heading == [0, -1] }
  g.cell(*food, :bacon)
  fox.each { |part| g.cell(*part, :body) }
  g.every(0.15) do
    x, y = fox.first
    head = [(x + heading[0]) % g.width, (y + heading[1]) % g.height]
    if fox.include?(head)
      g.game_over("Ouch! \#{eaten} bacon.")
      next
    end
    fox.unshift(head)
    if head == food
      eaten += 1
      food = g.free_cells.sample
    else
      fox.pop
    end
    g.clear
    g.cell(*food, :bacon)
    fox.each { |part| g.cell(*part, :body) }
    g.cell(*head, :chunky)
    g.status("Bacon: \#{eaten}")
  end
end),
             %(show_game(width: 16, height: 12) do |g|
  fox = [[4, 6], [3, 6], [2, 6]]
  heading = [1, 0]
  food = [10, 6]
  eaten = 0
  g.on_key(:left)  { heading = [-1, 0] unless heading == [1, 0] }
  g.on_key(:right) { heading = [1, 0]  unless heading == [-1, 0] }
  g.on_key(:up)    { heading = [0, -1] unless heading == [0, 1] }
  g.on_key(:down)  { heading = [0, 1]  unless heading == [0, -1] }
  g.cell(*food, :bacon)
  fox.each { |part| g.cell(*part, :body) }
  g.every(0.15) do
    x, y = fox.first
    head = [x + heading[0], y + heading[1]]
    head[0] = 0 if head[0] == 16
    head[0] = 15 if head[0] == -1
    head[1] = 0 if head[1] == 12
    head[1] = 11 if head[1] == -1
    if fox.include?(head)
      g.game_over("Ouch! \#{eaten} bacon.")
      next
    end
    fox.unshift(head)
    if head == food
      eaten += 1
      food = g.free_cells.sample
    else
      fox.pop
    end
    g.clear
    g.cell(*food, :bacon)
    fox.each { |part| g.cell(*part, :body) }
    g.cell(*head, :chunky)
    g.status("Bacon: \#{eaten}")
  end
end)]
  },
  # the ruby2d window (ruby2d.rb): the check replays the cell and holds the
  # arrow keys on that copy until Chunky reaches both edges
  "ruby2d" => {
    "de" => [%(require "ruby2d"
set title: "Chunky bleibt da", width: 400, height: 300
fuchs = Rectangle.new(x: 170, y: 240, width: 60, height: 40, color: "orange")
on :key_held do |event|
  fuchs.x -= 5 if event.key?(:left)
  fuchs.x += 5 if event.key?(:right)
  fuchs.x = fuchs.x.clamp(0, Window.width - fuchs.width)
end
show),
             %(require "ruby2d"
set title: "Chunky bleibt da", width: 400, height: 300
fuchs = Rectangle.new(x: 170, y: 240, width: 60, height: 40, color: "orange")
on :key_held do |event|
  fuchs.x -= 5 if event.key?(:left) && fuchs.x > 0
  fuchs.x += 5 if event.key?(:right) && fuchs.x + fuchs.width < Window.width
end
show)],
    "en" => [%(require "ruby2d"
set title: "Chunky stays", width: 400, height: 300
fox = Rectangle.new(x: 170, y: 240, width: 60, height: 40, color: "orange")
on :key_held do |event|
  fox.x -= 5 if event.key?(:left)
  fox.x += 5 if event.key?(:right)
  fox.x = fox.x.clamp(0, Window.width - fox.width)
end
show),
             %(require "ruby2d"
set title: "Chunky stays", width: 400, height: 300
fox = Rectangle.new(x: 170, y: 240, width: 60, height: 40, color: "orange")
on :key_held do |event|
  fox.x -= 5 if event.key?(:left)
  fox.x += 5 if event.key?(:right)
end
update do
  fox.x = 0 if fox.x < 0
  fox.x = Window.width - fox.width if fox.x + fox.width > Window.width
end
show)]
  },
  # a case and a Hash with a default
  "rubies" => {
    "de" => [%(def welches_ruby(engine)
  case engine
  when "ruby" then "CRuby"
  when "jruby" then "JRuby"
  when "truffleruby" then "TruffleRuby"
  else engine
  end
end

welches_ruby(RUBY_ENGINE)),
             %(NAMEN = { "ruby" => "CRuby", "jruby" => "JRuby", "truffleruby" => "TruffleRuby", "mruby" => "mruby" }
def welches_ruby(engine) = NAMEN.fetch(engine, engine)
puts welches_ruby(RUBY_ENGINE))],
    "en" => [%(def which_ruby(engine)
  case engine
  when "ruby" then "CRuby"
  when "jruby" then "JRuby"
  when "truffleruby" then "TruffleRuby"
  else engine
  end
end

which_ruby(RUBY_ENGINE)),
             %(NAMES = { "ruby" => "CRuby", "jruby" => "JRuby", "truffleruby" => "TruffleRuby", "mruby" => "mruby" }
def which_ruby(engine) = NAMES.fetch(engine, engine)
puts which_ruby(RUBY_ENGINE))]
  },
  # PicoRuby has no tally: by hand, with || and with Hash.new(0)
  "picoruby" => {
    "de" => [%(def woerter_zaehlen(woerter)
  anzahl = {}
  woerter.each { |wort| anzahl[wort] = (anzahl[wort] || 0) + 1 }
  anzahl
end

woerter_zaehlen(%w[chunky bacon chunky fuchs chunky])),
             %(def woerter_zaehlen(woerter)
  anzahl = Hash.new(0)
  woerter.each { |wort| anzahl[wort] += 1 }
  anzahl
end

woerter_zaehlen(%w[chunky bacon chunky fuchs chunky]))],
    "en" => [%(def count_words(words)
  counts = {}
  words.each { |word| counts[word] = (counts[word] || 0) + 1 }
  counts
end

count_words(%w[chunky bacon chunky fox chunky])),
             %(def count_words(words)
  counts = Hash.new(0)
  words.each { |word| counts[word] += 1 }
  counts
end

count_words(%w[chunky bacon chunky fox chunky]))]
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
  "tty" => {
    "de" => [%(zettel = TTY::Table.new(header: ["Artikel", "Menge"], rows: [["Speck", 3], ["Brezel", 2]])\nputs zettel.render(:unicode)),
             %(TTY::Table.new(header: ["Artikel", "Menge"], rows: [["Speck", 3], ["Brezel", 2]]).render(:unicode, padding: [0, 1]))],
    "en" => [%(list = TTY::Table.new(header: ["Item", "Qty"], rows: [["Bacon", 3], ["Pretzel", 2]])\nputs list.render(:unicode)),
             %(TTY::Table.new(header: ["Item", "Qty"], rows: [["Bacon", 3], ["Pretzel", 2]]).render(:unicode, padding: [0, 1]))]
  },
  "processing" => {
    "de" => [%(require "processing"\nusing Processing\nsetup do\n  size 400, 300\n  background 255\nend\ndraw do\n  line pmouseX, pmouseY, mouseX, mouseY if mousePressed\nend),
             %(require "processing"\nusing Processing\nsetup do\n  size 400, 300\n  background 255\n  stroke 200, 0, 0\n  strokeWeight 4\nend\ndraw do\nend\nmouseDragged do\n  line pmouseX, pmouseY, mouseX, mouseY\nend)],
    "en" => [%(require "processing"\nusing Processing\nsetup do\n  size 400, 300\n  background 255\nend\ndraw do\n  if mousePressed\n    line pmouseX, pmouseY, mouseX, mouseY\n  end\nend),
             %(require "processing"\nusing Processing(snake_case: true)\nsetup do\n  size 400, 300\n  background 255\nend\ndraw do\nend\nmouse_dragged do\n  line pmouse_x, pmouse_y, mouse_x, mouse_y\nend)]
  },
  "faker" => {
    "de" => [%(install_gem "faker"\nrequire "faker"\nFaker::Config.random = Random.new(2024)\nkunden = 5.times.map { { name: Faker::Name.name, email: Faker::Internet.email } }),
             %(Faker::Config.random = Random.new(2024)\nkunden = []\n5.times do\n  name = Faker::Name.name\n  kunden << { name: name, email: Faker::Internet.email(name: name) }\nend\nputs kunden.map { |k| k[:email] })],
    "en" => [%(install_gem "faker"\nrequire "faker"\nFaker::Config.random = Random.new(2024)\ncustomers = 5.times.map { { name: Faker::Name.name, email: Faker::Internet.email } }),
             %(Faker::Config.random = Random.new(2024)\nFaker::Name.unique.clear\n5.times.map { { name: Faker::Name.unique.name, email: Faker::Internet.unique.email } })]
  },
  "rumale" => {
    "de" => [%(#{RUMALE_SEVEN.sub("PIC", "sieben")}pixel = sieben.delete("\\n").chars.map { |z| z == "#" ? 16 : 0 }\nziffer = lerner.predict(Numo::DFloat[pixel])[0]),
             %(#{RUMALE_SEVEN.sub("PIC", "sieben")}ziffer = lerner.predict(Numo::DFloat[sieben.delete("\\n").chars.map { |z| z == "#" ? 16 : 0 }])[0]\nputs ziffer)],
    "en" => [%(#{RUMALE_SEVEN.sub("PIC", "seven")}pixels = seven.delete("\\n").chars.map { |c| c == "#" ? 16 : 0 }\ndigit = learner.predict(Numo::DFloat[pixels])[0]),
             %(#{RUMALE_SEVEN.sub("PIC", "seven")}digit = learner.predict(Numo::DFloat[seven.delete("\\n").chars.map { |c| c == "#" ? 16 : 0 }])[0]\nputs digit)]
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
    Processing.reset__ if defined?(Processing::Context)
    Ruby2D.reset__ if defined?(Ruby2D::Page)
    shown = $shown_games.length
    result = eval(code, bind, "chunky.rb")
    $shown_games.drop(shown).each { |game| game.source = code if game.respond_to?(:source=) }
    sketch = Processing.start__ if defined?(Processing::Context)
    $shown_sketches << sketch if sketch
  rescue Exception => e
    error = e
  ensure
    $stdout = old_stdout
  end
  [result, buffer.string, error]
end

# the files a lesson brings (lessons.js "files"), as main.rb puts them next
# to its code
def load_lesson_files(lesson)
  (lesson["files"] || {}).each do |name, path|
    SandboxFS.write(name, File.read(File.expand_path("../html/#{path}", __dir__)))
  end
end

def run_harness(langs)
  data = JSON.parse(File.read(File.expand_path("lessons.json", __dir__)))
  failures = 0
  Dir.chdir(WORKDIR)

  data["lessons"].each do |lesson|
  next if BROWSER_ONLY.include?(lesson["id"])

  langs.each do |lang|
    l = lesson.fetch(lang)
    exercise = l["cells"].find { |c| c["t"] == "x" }
    demos = l["cells"].select { |c| c["t"] == "c" }
    solutions = SOLUTIONS.fetch(lesson["id"]).fetch(SOLUTION_LANG.fetch(lang, lang))
    variants = [["starter", exercise["code"]]] +
               solutions.each_with_index.map { |s, i| ["solution#{i + 1}", s] }

    variants.each do |label, candidate|
      # its own top-level scope, as main.rb's TopLevel.binding: a `using`
      # stays in its lesson
      bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval
      unmix_ruby2d
      load_lesson_files(lesson)
      $letter_answers = []

      demo_failed = false
      # a PicoRuby lesson's demos use what only PicoRuby has (Task,
      # sleep_ms, PICORUBY_VERSION): test/picoruby_test.mjs runs them
      demos = [] if lesson["engine"] == "picoruby"
      demos.each do |demo|
        _, _, err = run_in(bind, demo["code"])
        if err
          puts "FAIL #{lesson["id"]}/#{lang}: demo cell raised #{err.class}: #{err.message}"
          failures += 1
          demo_failed = true
        end
      end
      next if demo_failed

      # the letter's block read 3000 from the digits it got
      unless $letter_answers.all? { |answer| answer.start_with?("3000 ") }
        puts "FAIL #{lesson["id"]}/#{lang}: the letter answered #{$letter_answers.inspect}"
        failures += 1
      end

      $shown_images = []
      $shown_scenes = []
      $shown_apps = []
      $shown_sketches = []
      $shown_audios = []
      $shown_games = []
      $explicit_downloads = []
      SandboxFS.reset!
      load_lesson_files(lesson)
      watch = FileWatch.snapshot
      result, output, error = run_in(bind, candidate)
      downloads = FileWatch.changes_since(watch).map(&:first) | $explicit_downloads
      if error && label != "starter"
        puts "FAIL #{lesson["id"]}/#{lang} (#{label}): raised #{error.class}: #{error.message}"
        failures += 1
        next
      end

      bind.local_variable_set(:output, output)
      # the page hands a PicoRuby lesson's check the value's inspect text
      result = PicoRubyCells.value(result.inspect) if lesson["engine"] == "picoruby"
      bind.local_variable_set(:result, result)
      bind.local_variable_set(:code, candidate)
      bind.local_variable_set(:images, $shown_images.dup)
      bind.local_variable_set(:scenes, $shown_scenes.dup)
      bind.local_variable_set(:apps, $shown_apps.length)
      bind.local_variable_set(:shoes_types, $shown_apps.last || [])
      bind.local_variable_set(:downloads, downloads)
      bind.local_variable_set(:sketch, $shown_sketches.last)
      bind.local_variable_set(:audios, $shown_audios.dup)
      bind.local_variable_set(:games, $shown_games.map(&:fresh))
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

  puts failures.zero? ? "ALL CHECKS OK (#{data["lessons"].length} lessons x #{langs.join("+")}, puts + no-puts variants)" : "#{failures} failures (#{langs.join("+")})"
  failures.zero?
end

# One process per language: lesson code defines methods and classes at the
# top level, which outlive the binding, and ja runs the same code as en - an
# en solution's `def square` would let the ja starter pass.
if (lang = ENV["HARNESS_LANG"])
  exit(run_harness([lang]) ? 0 : 1)
else
  require "rbconfig"
  results = LANGS.map { |l| system({ "HARNESS_LANG" => l }, RbConfig.ruby, __FILE__) }
  exit(results.all? ? 0 : 1)
end
