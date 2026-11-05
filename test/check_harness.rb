# Offline harness for the notebook format: for every lesson/lang it runs the
# demo cells in a shared binding (like the browser kernel), then verifies that
# the exercise starter does NOT pass the check while every known-good solution
# (puts-style and no-puts-style) DOES pass. Mirrors main.rb's eval mechanics.
# The demo cells are the ones ▶ on the exercise runs first on a fresh page
# (html/earlier_cells.rb), so each lesson also shows that any of its cells
# can be the first one a learner runs.
require 'json'
require 'stringio'
require_relative "../html/browser_gems"
require_relative "../html/rack_playground"
require_relative "../html/sandbox_sim"
require_relative "../html/earlier_cells"
require "tmpdir"
require "fileutils"
require "rbconfig"

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
# show_game (lesson 41): game.rb runs headless as it is; the stub below
# records each game, and a check plays copies of them (games), as in main.rb
require_relative "../html/game"
# a lesson with "engine": "picoruby" runs on PicoRuby.wasm in the browser;
# here its exercise runs under CRuby, and the check gets the result as the
# page hands it over - a PicoRubyCells::Value, PicoRuby's inspect text
require_relative "../html/picoruby_cells"
# a lesson with "engine": "jruby" runs on JRuby (TeaVM) in the browser; its
# exercise's check runs in CRuby there too, on the same USGS snapshot, which
# JRubyCells.load_data reads from the vendored html/assets/jruby/data/
# (tools/vendor_jruby.rb) - the lesson is skipped when it is not there
require_relative "../html/jruby_cells"
JRubyCells.fetch_text = lambda do |url|
  path = File.expand_path("../html/#{url}", __dir__)
  File.exist?(path) ? File.read(path) : nil
end
# a lesson with "engine": "ironruby" runs on IronRuby (.NET in WebAssembly)
# in the browser; here its cells, starter and solutions run on the same
# bundle under Node (ironruby_node.mjs, check_ironruby below), and the
# CRuby half of the check gets result and probe as the page hands them over
require_relative "../html/ironruby_cells"
require "open3"
$shown_games = []
# spinel(code) (lesson 45): without the page, spinel.rb is CRuby's run of the
# program, which is what the lesson's check reads (result.output)
require_relative "../html/spinel"
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

  # a Rubyvis chart (lessons 31, 32) is drawn and kept as its SVG, as main.rb does
  def show_image(image, alt: nil)
    if image.respond_to?(:to_svg) && !image.respond_to?(:to_data_url)
      image.render if image.respond_to?(:render)
      image = image.to_svg
    end
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
BROWSER_ONLY = %w[pycall sympy numpy matplotlib sklearn sequel erb activerecord rails-mvc rails-forms rails-crud rails-associations].freeze

# the Rumale exercise's picture of a seven (its starter defines it too)
RUMALE_SEVEN = "PIC = %w[.######. ......#. .....#.. ....#... ...#.... ...#.... ..#..... ..#.....].join(\"\\n\") + \"\\n\"\n"

# The IronRuby lesson's solutions: the loops of bacon_svg, and by index with
# ModuleMatrix. <<~'RUBY': the #{} are IronRuby's, not the harness's.
IRONRUBY_SOLUTIONS = [<<~'RUBY', <<~'RUBY'].freeze
    def qr_svg(text, cell = 6)
      level = QRCoder::QRCodeGenerator::ECCLevel.Q
      data = QRCoder::QRCodeGenerator.new.CreateQrCode(text, level)
      rects = []
      data.module_matrix.each_with_index do |row, y|
        row.each_with_index do |dark, x|
          rects << %(<rect x="#{x * cell}" y="#{y * cell}" width="#{cell}" height="#{cell}"/>) if dark
        end
      end
      size = data.module_matrix.count * cell
      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{size}" ) +
        %(height="#{size}" style="background:#fff">#{rects.join}</svg>)
    end

    show_svg qr_svg("Chunky Bacon")
  RUBY
    def qr_svg(text, cell = 6)
      data = QRCoder::QRCodeGenerator.new.CreateQrCode(text, QRCoder::QRCodeGenerator::ECCLevel.Q)
      matrix = data.ModuleMatrix
      n = matrix.Count
      rects = (0...n).flat_map do |y|
        (0...n).select { |x| matrix[y][x] }.map do |x|
          %(<rect x="#{x * cell}" y="#{y * cell}" width="#{cell}" height="#{cell}"/>)
        end
      end
      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{n * cell}" height="#{n * cell}">#{rects.join}</svg>)
    end

    qr_svg("Chunky Bacon").size
  RUBY

# ...and answers that look right but are not: a rect for every module, all
# rects on one spot, the light modules. Each must fail the check (the probe
# compares the rects with QRCoder's dark modules, not just their number).
# The Ruboto lesson's counter (lesson `ruboto`), as the starter has it, with
# +read+ for where onCreate takes the count from and +save+ for what
# onSaveInstanceState does with it (nil: no onSaveInstanceState)
def ruboto_counter(var, up, label, title, read:, save:)
  saving = save ? "\n  def onSaveInstanceState(out_state)\n    super\n    #{save}\n  end\n" : ""
  <<~RUBY
    require 'ruboto/widget'
    ruboto_import_widgets :LinearLayout, :TextView, :Button

    class CounterActivity
      def onCreate(bundle)
        super
        set_title '#{title}'
        #{var} = #{read}
        self.content_view = linear_layout orientation: :vertical, gravity: :center do
          #{label} = text_view text: #{var}.to_s, text_size: 64, gravity: :center
          button text: '+1', on_click_listener: proc { #{up} }
        end
      end

      def #{up}
        #{var} += 1
        #{label}.text = #{var}.to_s
      end
    #{saving}end
  RUBY
end

# Ruboto counters that must fail the check: saved but never read back, read
# but never saved, and one that starts at 3
RUBOTO_WRONG = [
  ruboto_counter("@count", "count_up", "@label", "Counter", read: "0", save: "out_state.putInt('count', @count)"),
  ruboto_counter("@count", "count_up", "@label", "Counter", read: "bundle ? bundle.getInt('count') : 0", save: nil),
  ruboto_counter("@count", "count_up", "@label", "Counter", read: "3", save: "out_state.putInt('count', @count)")
].freeze

IRONRUBY_WRONG = [
  %(rects << %(<rect x="\#{x * cell}" y="\#{y * cell}" width="\#{cell}" height="\#{cell}"/>)),
  %(rects << %(<rect x="0" y="0" width="\#{cell}" height="\#{cell}"/>) if dark),
  %(rects << %(<rect x="\#{x * cell}" y="\#{y * cell}" width="\#{cell}" height="\#{cell}"/>) unless dark)
].map { |line| IRONRUBY_SOLUTIONS.first.sub(/^ *rects << .*$/, "      " + line) }.freeze

SOLUTIONS = {
  "hallo" => {
    "de" => [%(puts "Hallo, Welt!"), %("Hallo, Welt!")],
    "en" => [%(puts "Hello, World!"), %("Hello, World!")]
  },
  "rechnen" => {
    "de" => [%(puts 3 * 17 / 4.0), %(3 * 17 / 4.0), %((3 * 17).fdiv(4))],
    "en" => [%(puts 3 * 17 / 4.0), %(3 * 17 / 4.0), %((3 * 17).fdiv(4))]
  },
  "variablen" => {
    "de" => [%(name = "Kaz"\nalter = 7)],
    "en" => [%(name = "Kaz"\nage = 7)]
  },
  "strings" => {
    "de" => [%(lieblingsessen = "Chunky Bacon"\nputs "Ich mag \#{lieblingsessen.upcase}!"), %(lieblingsessen = "Chunky Bacon"\n"Ich mag \#{lieblingsessen.upcase}!")],
    "en" => [%(favorite_food = "Chunky Bacon"\nputs "I love \#{favorite_food.upcase}!"), %(favorite_food = "Chunky Bacon"\n"I love \#{favorite_food.upcase}!")]
  },
  "wenn" => {
    "de" => [%(zahl = 7\nif zahl > 10\n  puts "gross"\nelsif zahl > 5\n  puts "mittel"\nelse\n  puts "klein"\nend), %(zahl = 7\nif zahl > 10\n  "gross"\nelsif zahl > 5\n  "mittel"\nelse\n  "klein"\nend)],
    "en" => [%(number = 7\nif number > 10\n  puts "big"\nelsif number > 5\n  puts "medium"\nelse\n  puts "small"\nend), %(number = 7\nif number > 10\n  "big"\nelsif number > 5\n  "medium"\nelse\n  "small"\nend)]
  },
  "schleifen" => {
    "de" => [%(5.times do\n  puts "Chunky Bacon!"\nend), %(5.times.map { "Chunky Bacon!" })],
    "en" => [%(5.times do\n  puts "Chunky Bacon!"\nend), %(5.times.map { "Chunky Bacon!" })]
  },
  "arrays" => {
    "de" => [%(fruehstueck = ["Ei", "Brot"]\nfruehstueck << "Speck"\nputs fruehstueck.sort.join(", ")), %(fruehstueck = ["Ei", "Brot"]\nfruehstueck << "Speck"\nfruehstueck.sort.join(", "))],
    "en" => [%(breakfast = ["egg", "toast"]\nbreakfast << "bacon"\nputs breakfast.sort.join(", ")), %(breakfast = ["egg", "toast"]\nbreakfast << "bacon"\nbreakfast.sort.join(", "))]
  },
  "hashes" => {
    "de" => [%(fuchs = { name: "Chunky", essen: "Speck" }\nfuchs[:alter] = 3\nfuchs)],
    "en" => [%(fox = { name: "Chunky", food: "bacon" }\nfox[:age] = 3\nfox)]
  },
  "iteratoren" => {
    "de" => [%(punkte = [72, 45, 88, 91, 30, 60]\nbestanden = punkte.select { |punkt| punkt >= 60 }\nmit_bonus = bestanden.map { |punkt| punkt + 5 }),
             %(punkte = [72, 45, 88, 91, 30, 60]\nbestanden = punkte.select { _1 >= 60 }\nmit_bonus = bestanden.map { |p| p + 5 }\np mit_bonus)],
    "en" => [%(scores = [72, 45, 88, 91, 30, 60]\npassed = scores.select { |score| score >= 60 }\nwith_bonus = passed.map { |score| score + 5 }),
             %(scores = [72, 45, 88, 91, 30, 60]\npassed = scores.select { _1 >= 60 }\nwith_bonus = passed.map { |s| s + 5 }\np with_bonus)]
  },
  "sortieren" => {
    "de" => ["punkte = { \"Chunky\" => 42, \"Kaz\" => 17, \"Isi\" => 42, \"Bo\" => 8, \"Mo\" => 23 }\n\nrangliste = punkte.sort_by { |name, p| [-p, name] }.map { |name, p| name }\nletzter = punkte.min_by { |name, p| p }.first",
             "punkte = { \"Chunky\" => 42, \"Kaz\" => 17, \"Isi\" => 42, \"Bo\" => 8, \"Mo\" => 23 }\nrangliste = punkte.sort { |(n1, p1), (n2, p2)| [p2, n1] <=> [p1, n2] }.map(&:first)\nletzter = punkte.min_by { |_, pkt| pkt }[0]\np rangliste"],
    "en" => ["scores = { \"Chunky\" => 42, \"Kaz\" => 17, \"Isi\" => 42, \"Bo\" => 8, \"Mo\" => 23 }\n\nranking = scores.sort_by { |name, points| [-points, name] }.map { |name, points| name }\nlast_place = scores.min_by { |name, points| points }.first",
             "scores = { \"Chunky\" => 42, \"Kaz\" => 17, \"Isi\" => 42, \"Bo\" => 8, \"Mo\" => 23 }\nranking = scores.sort { |(n1, p1), (n2, p2)| [p2, n1] <=> [p1, n2] }.map(&:first)\nlast_place = scores.min_by { |_, pts| pts }[0]\np ranking"]
  },
  "zeit" => {
    "de" => ["require \"date\"\nveroeffentlicht = Date.new(1995, 12, 21)\n\nwochentag = %w[Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag][veroeffentlicht.wday]\ntage_bis = (Date.new(2026, 12, 24) - Date.new(2026, 11, 2)).to_i",
             "require \"date\"\nveroeffentlicht = Date.new(1995, 12, 21)\nnamen = %w[Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag]\nwochentag = namen[veroeffentlicht.wday]\ntage_bis = Integer(Date.new(2026, 12, 24) - Date.new(2026, 11, 2))\np wochentag"],
    "en" => ["require \"date\"\nrelease = Date.new(1995, 12, 21)\n\nweekday = release.strftime(\"%A\")\ndays_until = (Date.new(2026, 12, 24) - Date.new(2026, 11, 2)).to_i",
             "require \"date\"\nrelease = Date.new(1995, 12, 21)\nweekday = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday][release.wday]\ndays_until = (Date.new(2026, 12, 24) - Date.new(2026, 11, 2)).to_i\np days_until"]
  },
  "rekursion" => {
    "de" => ["def hoch(basis, exponent)\n  return 1 if exponent == 0\n  basis * hoch(basis, exponent - 1)\nend\n\nhoch(2, 10)",
             "def hoch(basis, exponent)\n  if exponent.zero?\n    1\n  else\n    basis * hoch(basis, exponent - 1)\n  end\nend\np hoch(2, 10)"],
    "en" => ["def power(base, exponent)\n  return 1 if exponent == 0\n  base * power(base, exponent - 1)\nend\n\npower(2, 10)",
             "def power(base, exponent)\n  if exponent.zero?\n    1\n  else\n    base * power(base, exponent - 1)\n  end\nend\np power(2, 10)"]
  },
  "muster" => {
    "de" => ["5.downto(1) do |zeile|\n  puts \"#\" * zeile\nend",
             "puts (1..5).to_a.reverse.map { |n| \"#\" * n }"],
    "en" => ["5.downto(1) do |row|\n  puts \"#\" * row\nend",
             "puts (1..5).to_a.reverse.map { |n| \"#\" * n }"]
  },
  "geheimschrift" => {
    "de" => ["def caesar(text, schluessel)\n  text.chars.map { |z| verschieben(z, schluessel) }.join\nend\n\ncaesar(\"hallo, fuchs!\", 1)",
             "def caesar(text, schluessel)\n  text.gsub(/[a-z]/) { |z| ((z.ord - 97 + schluessel) % 26 + 97).chr }\nend\np caesar(\"hallo, fuchs!\", 1)"],
    "en" => ["def caesar(text, key)\n  text.chars.map { |c| shift_letter(c, key) }.join\nend\n\ncaesar(\"hello, fox!\", 1)",
             "def caesar(text, key)\n  text.gsub(/[a-z]/) { |c| ((c.ord - 97 + key) % 26 + 97).chr }\nend\np caesar(\"hello, fox!\", 1)"]
  },
  "knobeln" => {
    "de" => ["def vollkommen?(n)\n  teiler = (1...n).select { |t| n % t == 0 }\n  teiler.sum == n\nend\n\n(1..500).select { |n| vollkommen?(n) }",
             "def vollkommen?(n)\n  (1..n / 2).select { |t| (n % t).zero? }.sum == n\nend\np (1..500).select { |n| vollkommen?(n) }"],
    "en" => ["def perfect?(n)\n  divisors = (1...n).select { |d| n % d == 0 }\n  divisors.sum == n\nend\n\n(1..500).select { |n| perfect?(n) }",
             "def perfect?(n)\n  (1..n / 2).select { |d| (n % d).zero? }.sum == n\nend\np (1..500).select { |n| perfect?(n) }"]
  },
  "symbole" => {
    "de" => ["karte = { speck: 4.5, ei: 1.2 }\nbestellung = [\"speck\", \"toast\", \"ei\"]\n\nsumme = bestellung.sum { |gericht| karte[gericht.to_sym] || 0 }\nfehlt = bestellung.select { |gericht| karte[gericht.to_sym].nil? }",
             "karte = { speck: 4.5, ei: 1.2 }\nbestellung = [\"speck\", \"toast\", \"ei\"]\npreise = bestellung.map { |g| karte.fetch(g.to_sym, nil) }\nsumme = preise.compact.sum\nfehlt = bestellung.reject { |g| karte.key?(g.to_sym) }\np summe"],
    "en" => ["menu = { bacon: 4.5, egg: 1.2 }\norder = [\"bacon\", \"toast\", \"egg\"]\n\ntotal = order.sum { |dish| menu[dish.to_sym] || 0 }\nmissing = order.select { |dish| menu[dish.to_sym].nil? }",
             "menu = { bacon: 4.5, egg: 1.2 }\norder = [\"bacon\", \"toast\", \"egg\"]\nprices = order.map { |d| menu.fetch(d.to_sym, nil) }\ntotal = prices.compact.sum\nmissing = order.reject { |d| menu.key?(d.to_sym) }\np total"]
  },
  "struct" => {
    "de" => ["Buch = Struct.new(:titel, :autor, :seiten) do\n  def kurz?\n    seiten < 200\n  end\nend\n\nBuch.new(\"Why's (Poignant) Guide\", \"why\", 176).kurz?",
             "Buch = Struct.new(:titel, :autor, :seiten) do\n  def kurz? = seiten < 200\nend\np Buch.new(\"Why's (Poignant) Guide\", \"why\", 176).kurz?"],
    "en" => ["Book = Struct.new(:title, :author, :pages) do\n  def short?\n    pages < 200\n  end\nend\n\nBook.new(\"Why's (Poignant) Guide\", \"why\", 176).short?",
             "Book = Struct.new(:title, :author, :pages) do\n  def short? = pages < 200\nend\np Book.new(\"Why's (Poignant) Guide\", \"why\", 176).short?"]
  },
  "regex" => {
    "de" => [%(notizen = ["Frühstück um 07:45: Speck", "Znüni um 10:15: Apfel", "Mittag um 12:30: speck und Ei", "Abend: kein Hunger"]\nzeiten = notizen.join(" ").scan(/\\d\\d:\\d\\d/)\nspeck_tage = notizen.count { |notiz| notiz.match?(/speck/i) }),
             %(notizen = ["Frühstück um 07:45: Speck", "Znüni um 10:15: Apfel", "Mittag um 12:30: speck und Ei", "Abend: kein Hunger"]\nzeiten = notizen.flat_map { |notiz| notiz.scan(/\\d{2}:\\d{2}/) }\nspeck_tage = notizen.select { |notiz| notiz =~ /[Ss]peck/ }.length\np speck_tage)],
    "en" => [%(notes = ["Breakfast at 07:45: Bacon", "Snack at 10:15: apple", "Lunch at 12:30: bacon and egg", "Evening: not hungry"]\ntimes = notes.join(" ").scan(/\\d\\d:\\d\\d/)\nbacon_days = notes.count { |note| note.match?(/bacon/i) }),
             %(notes = ["Breakfast at 07:45: Bacon", "Snack at 10:15: apple", "Lunch at 12:30: bacon and egg", "Evening: not hungry"]\ntimes = notes.flat_map { |note| note.scan(/\\d{2}:\\d{2}/) }\nbacon_days = notes.select { |note| note =~ /[Bb]acon/ }.length\np bacon_days)]
  },
  "zufall" => {
    "de" => [%(summen = 100.times.map { rand(1..6) + rand(1..6) }
siebener = summen.count(7)),
             %(summen = Array.new(100) { rand(1..6) + rand(1..6) }
siebener = summen.count { |s| s == 7 }
p siebener)],
    "en" => [%(totals = 100.times.map { rand(1..6) + rand(1..6) }
sevens = totals.count(7)),
             %(totals = Array.new(100) { rand(1..6) + rand(1..6) }
sevens = totals.count { |t| t == 7 }
p sevens)]
  },
  "formatieren" => {
    "de" => [%(einkauf = { "Speck" => 4.5, "Brot" => 2, "Honig" => 6.8 }
zettel = einkauf.map { |artikel, preis| artikel.ljust(10) + format("%7.2f", preis) }.join("\\n")),
             %(einkauf = { "Speck" => 4.5, "Brot" => 2, "Honig" => 6.8 }
zettel = einkauf.map { |a, p| format("%-10s%7.2f", a, p) }.join("\\n")
puts zettel)],
    "en" => [%(shopping = { "Bacon" => 4.5, "Bread" => 2, "Honey" => 6.8 }
list = shopping.map { |item, price| item.ljust(10) + format("%7.2f", price) }.join("\\n")),
             %(shopping = { "Bacon" => 4.5, "Bread" => 2, "Honey" => 6.8 }
list = shopping.map { |i, p| format("%-10s%7.2f", i, p) }.join("\\n")
puts list)]
  },
  "dateien" => {
    "de" => [%(File.write("einkauf.txt", "Speck\\nEier\\nBrot\\n")
artikel = File.read("einkauf.txt").lines(chomp: true)),
             %(File.write("einkauf.txt", ["Speck", "Eier", "Brot"].join("\\n"))
artikel = File.read("einkauf.txt").split("\\n")
p artikel)],
    "en" => [%(File.write("shopping.txt", "bacon\\neggs\\nbread\\n")
items = File.read("shopping.txt").lines(chomp: true)),
             %(File.write("shopping.txt", ["bacon", "eggs", "bread"].join("\\n"))
items = File.read("shopping.txt").split("\\n")
p items)]
  },
  "bereiche" => {
    "de" => ["temperaturen = [14, 19, 23, 31, 22, 17, 26]\n\nwochenende = temperaturen[-2..]\nangenehm = 0\ntemperaturen.each do |t|\n  angenehm += 1 if (18..24).include?(t)\nend",
             "temperaturen = [14, 19, 23, 31, 22, 17, 26]\nwochenende = temperaturen[5..6]\nangenehm = 0\ntemperaturen.each do |t|\n  case t\n  when 18..24 then angenehm += 1\n  end\nend\np wochenende, angenehm"],
    "en" => ["temperatures = [14, 19, 23, 31, 22, 17, 26]\n\nweekend = temperatures[-2..]\ncomfy = 0\ntemperatures.each do |t|\n  comfy += 1 if (18..24).include?(t)\nend",
             "temperatures = [14, 19, 23, 31, 22, 17, 26]\nweekend = temperatures[5..6]\ncomfy = 0\ntemperatures.each do |t|\n  case t\n  when 18..24 then comfy += 1\n  end\nend\np weekend, comfy"]
  },
  "mengen" => {
    "de" => ["chunky_sticker = %w[Fuchs Eule B\u00E4r Fuchs Frosch Eule]\nkaz_sticker = %w[Eule Igel Frosch Frosch Reh]\n\nbeide = chunky_sticker.to_set & kaz_sticker.to_set\nfuer_kaz = chunky_sticker.to_set - kaz_sticker.to_set\nsorten = (chunky_sticker.to_set | kaz_sticker.to_set).size",
             "chunky_sticker = %w[Fuchs Eule B\u00E4r Fuchs Frosch Eule]\nkaz_sticker = %w[Eule Igel Frosch Frosch Reh]\nseine = Set.new(chunky_sticker)\nihre = kaz_sticker.to_set\nbeide = seine.intersection(ihre)\nfuer_kaz = seine - ihre\nsorten = (seine + ihre).size\np beide, fuer_kaz, sorten"],
    "en" => ["chunky_stickers = %w[fox owl bear fox frog owl]\nkaz_stickers = %w[owl hedgehog frog frog deer]\n\nboth = chunky_stickers.to_set & kaz_stickers.to_set\nfor_kaz = chunky_stickers.to_set - kaz_stickers.to_set\nkinds = (chunky_stickers.to_set | kaz_stickers.to_set).size",
             "chunky_stickers = %w[fox owl bear fox frog owl]\nkaz_stickers = %w[owl hedgehog frog frog deer]\nhis = Set.new(chunky_stickers)\nhers = kaz_stickers.to_set\nboth = his.intersection(hers)\nfor_kaz = his - hers\nkinds = (his + hers).size\np both, for_kaz, kinds"]
  },
  "reduce" => {
    "de" => ["ereignisse = [30, 40, -90, 20, 25]\n\nenergie = ereignisse.reduce(50) do |e, aenderung|\n  (e + aenderung).clamp(0..100)\nend",
             "ereignisse = [30, 40, -90, 20, 25]\nenergie = ereignisse.inject(50) { |jetzt, a| (jetzt + a).clamp(0, 100) }\np energie"],
    "en" => ["events = [30, 40, -90, 20, 25]\n\nenergy = events.reduce(50) do |e, change|\n  (e + change).clamp(0..100)\nend",
             "events = [30, 40, -90, 20, 25]\nenergy = events.inject(50) { |now, c| (now + c).clamp(0, 100) }\np energy"]
  },
  "listen" => {
    "de" => ["tage = %w[Mo Di Mi Do Fr Sa So]\nschritte = [4200, 6100, 5800, 9000, 3500, 12000, 7400]\n\npro_tag = tage.zip(schritte).to_h\naenderungen = schritte.each_cons(2).map { |vor, nach| nach - vor }\ntop_zwei = schritte.max(2)",
             "tage = %w[Mo Di Mi Do Fr Sa So]\nschritte = [4200, 6100, 5800, 9000, 3500, 12000, 7400]\npro_tag = {}\ntage.zip(schritte) { |tag, n| pro_tag[tag] = n }\naenderungen = []\nschritte.each_cons(2) { |a, b| aenderungen << b - a }\ntop_zwei = schritte.sort.last(2).reverse\np pro_tag, aenderungen, top_zwei"],
    "en" => ["days = %w[Mon Tue Wed Thu Fri Sat Sun]\nsteps = [4200, 6100, 5800, 9000, 3500, 12000, 7400]\n\nper_day = days.zip(steps).to_h\nchanges = steps.each_cons(2).map { |before, after| after - before }\ntop_two = steps.max(2)",
             "days = %w[Mon Tue Wed Thu Fri Sat Sun]\nsteps = [4200, 6100, 5800, 9000, 3500, 12000, 7400]\nper_day = {}\ndays.zip(steps) { |day, n| per_day[day] = n }\nchanges = []\nsteps.each_cons(2) { |a, b| changes << b - a }\ntop_two = steps.sort.last(2).reverse\np per_day, changes, top_two"]
  },
  "unicode" => {
    "de" => ["nachrichten = [\"Grüezi!\", \"ルビー\", \"🦊❤️🥓\", \"Hopp 🇨🇭!\", \"👨‍👩‍👧\"]\n\ngroessen = nachrichten.map do |text|\n  [text.bytesize, text.length, text.grapheme_clusters.length]\nend\nrueckwaerts = nachrichten.map { |text| text.grapheme_clusters.reverse.join }",
             "nachrichten = [\"Grüezi!\", \"ルビー\", \"🦊❤️🥓\", \"Hopp 🇨🇭!\", \"👨‍👩‍👧\"]\ngroessen = []\nrueckwaerts = []\nnachrichten.each do |t|\n  groessen << [t.bytes.size, t.chars.size, t.each_grapheme_cluster.count]\n  rueckwaerts << t.grapheme_clusters.reverse.join\nend\np groessen"],
    "en" => ["posts = [\"Grüezi!\", \"ルビー\", \"🦊❤️🥓\", \"Hopp 🇨🇭!\", \"👨‍👩‍👧\"]\n\nsizes = posts.map do |post|\n  [post.bytesize, post.length, post.grapheme_clusters.length]\nend\nbackwards = posts.map { |post| post.grapheme_clusters.reverse.join }",
             "posts = [\"Grüezi!\", \"ルビー\", \"🦊❤️🥓\", \"Hopp 🇨🇭!\", \"👨‍👩‍👧\"]\nsizes = []\nbackwards = []\nposts.each do |t|\n  sizes << [t.bytes.size, t.chars.size, t.each_grapheme_cluster.count]\n  backwards << t.grapheme_clusters.reverse.join\nend\np sizes"]
  },
  "bloecke" => {
    "de" => ["def wiederhole(n)\n  ergebnisse = []\n  (1..n).each { |i| ergebnisse << yield(i) }\n  ergebnisse\nend\n\nwiederhole(4) { |i| i * i }",
             "def wiederhole(n, &block)\n  (1..n).map(&block)\nend\n\np wiederhole(4) { |i| i * i }"],
    "en" => ["def repeat(n)\n  results = []\n  (1..n).each { |i| results << yield(i) }\n  results\nend\n\nrepeat(4) { |i| i * i }",
             "def repeat(n, &block)\n  (1..n).map(&block)\nend\n\np repeat(4) { |i| i * i }"]
  },
  "gitter" => {
    "de" => ["def sieger(brett)\n  reihen = brett + brett.transpose\n  reihen << 3.times.map { |i| brett[i][i] }\n  reihen << 3.times.map { |i| brett[i][2 - i] }\n  reihe = reihen.find { |r| r.uniq.size == 1 && r[0] != \".\" }\n  reihe&.first\nend\n\nsieger([%w[X O .],\n        %w[O X .],\n        %w[O . X]])",
             "def sieger(brett)\n  diagonalen = [[brett[0][0], brett[1][1], brett[2][2]],\n                [brett[0][2], brett[1][1], brett[2][0]]]\n  (brett + brett.transpose + diagonalen).each do |reihe|\n    return reihe[0] if reihe[0] != \".\" && reihe.all?(reihe[0])\n  end\n  nil\nend\np sieger([%w[X O .], %w[O X .], %w[O . X]])"],
    "en" => ["def winner(board)\n  lines = board + board.transpose\n  lines << 3.times.map { |i| board[i][i] }\n  lines << 3.times.map { |i| board[i][2 - i] }\n  line = lines.find { |l| l.uniq.size == 1 && l[0] != \".\" }\n  line&.first\nend\n\nwinner([%w[X O .],\n        %w[O X .],\n        %w[O . X]])",
             "def winner(board)\n  diagonals = [[board[0][0], board[1][1], board[2][2]],\n               [board[0][2], board[1][1], board[2][0]]]\n  (board + board.transpose + diagonals).each do |line|\n    return line[0] if line[0] != \".\" && line.all?(line[0])\n  end\n  nil\nend\np winner([%w[X O .], %w[O X .], %w[O . X]])"]
  },
  "zahlensysteme" => {
    "de" => ["def hex_zu_rgb(farbe)\n  paare = [farbe[1, 2], farbe[3, 2], farbe[5, 2]]\n  paare.map { |paar| paar.to_i(16) }\nend\n\nhex_zu_rgb(\"#ff8800\")",
             "def hex_zu_rgb(farbe)\n  farbe.delete(\"#\").scan(/../).map { |h| h.hex }\nend\np hex_zu_rgb(\"#ff8800\")"],
    "en" => ["def hex_to_rgb(colour)\n  pairs = [colour[1, 2], colour[3, 2], colour[5, 2]]\n  pairs.map { |pair| pair.to_i(16) }\nend\n\nhex_to_rgb(\"#ff8800\")",
             "def hex_to_rgb(colour)\n  colour.delete(\"#\").scan(/../).map { |h| h.hex }\nend\np hex_to_rgb(\"#ff8800\")"]
  },
  "brueche" => {
    "de" => ["pfannkuchen = { milch: 3/4r, mehl: 1/2r, eier: 3 }\n\ndef rezept_umrechnen(rezept, von, auf)\n  rezept.transform_values { |menge| menge * Rational(auf, von) }\nend\n\nrezept_umrechnen(pfannkuchen, 4, 6)",
             "pfannkuchen = { milch: 3/4r, mehl: 1/2r, eier: 3 }\ndef rezept_umrechnen(rezept, von, auf)\n  neu = {}\n  rezept.each { |zutat, menge| neu[zutat] = menge.to_r / von * auf }\n  neu\nend\np rezept_umrechnen(pfannkuchen, 4, 6)"],
    "en" => ["pancakes = { milk: 3/4r, flour: 1/2r, eggs: 3 }\n\ndef scale_recipe(recipe, from, to)\n  recipe.transform_values { |amount| amount * Rational(to, from) }\nend\n\nscale_recipe(pancakes, 4, 6)",
             "pancakes = { milk: 3/4r, flour: 1/2r, eggs: 3 }\ndef scale_recipe(recipe, from, to)\n  scaled = {}\n  recipe.each { |item, amount| scaled[item] = amount.to_r / from * to }\n  scaled\nend\np scale_recipe(pancakes, 4, 6)"]
  },
  "ausnahmen" => {
    "de" => ["zettel = [\"3\", \"drei\", \"4\", \"\", \"2\"]\n\ndef zahl_oder_nil(text)\n  Integer(text)\nrescue ArgumentError\n  nil\nend\n\nsumme = zettel.sum { |z| zahl_oder_nil(z) || 0 }",
             "zettel = [\"3\", \"drei\", \"4\", \"\", \"2\"]\n\ndef zahl_oder_nil(text)\n  begin\n    Integer(text)\n  rescue ArgumentError => e\n    nil\n  end\nend\n\nsumme = zettel.map { |z| zahl_oder_nil(z) }.compact.sum\np summe"],
    "en" => ["notes = [\"3\", \"three\", \"4\", \"\", \"2\"]\n\ndef number_or_nil(text)\n  Integer(text)\nrescue ArgumentError\n  nil\nend\n\ntotal = notes.sum { |n| number_or_nil(n) || 0 }",
             "notes = [\"3\", \"three\", \"4\", \"\", \"2\"]\n\ndef number_or_nil(text)\n  begin\n    Integer(text)\n  rescue ArgumentError => e\n    nil\n  end\nend\n\ntotal = notes.map { |n| number_or_nil(n) }.compact.sum\np total"]
  },
  "enumeratoren" => {
    "de" => ["dreieckszahlen = Enumerator.new do |y|\n  summe = 0\n  reihe = 1\n  loop do\n    summe += reihe\n    y << summe\n    reihe += 1\n  end\nend\n\ndreieckszahlen.first(6)",
             "dreieckszahlen = Enumerator.new do |y|\n  (1..).each { |n| y << n * (n + 1) / 2 }\nend\np dreieckszahlen.first(6)"],
    "en" => ["triangles = Enumerator.new do |y|\n  total = 0\n  row = 1\n  loop do\n    total += row\n    y << total\n    row += 1\n  end\nend\n\ntriangles.first(6)",
             "triangles = Enumerator.new do |y|\n  (1..).each { |n| y << n * (n + 1) / 2 }\nend\np triangles.first(6)"]
  },
  "sortierverfahren" => {
    "de" => ["def einsortieren(liste)\n  hand = []\n  liste.each do |karte|\n    stelle = hand.index { |k| k > karte } || hand.size\n    hand.insert(stelle, karte)\n  end\n  hand\nend\n\neinsortieren([5, 2, 8, 1, 9, 3])",
             "def einsortieren(liste)\n  karten = liste.dup\n  (1...karten.size).each do |i|\n    j = i\n    while j > 0 && karten[j - 1] > karten[j]\n      karten[j - 1], karten[j] = karten[j], karten[j - 1]\n      j -= 1\n    end\n  end\n  karten\nend\np einsortieren([5, 2, 8, 1, 9, 3])"],
    "en" => ["def insertion_sort(list)\n  hand = []\n  list.each do |card|\n    place = hand.index { |c| c > card } || hand.size\n    hand.insert(place, card)\n  end\n  hand\nend\n\ninsertion_sort([5, 2, 8, 1, 9, 3])",
             "def insertion_sort(list)\n  cards = list.dup\n  (1...cards.size).each do |i|\n    j = i\n    while j > 0 && cards[j - 1] > cards[j]\n      cards[j - 1], cards[j] = cards[j], cards[j - 1]\n      j -= 1\n    end\n  end\n  cards\nend\np insertion_sort([5, 2, 8, 1, 9, 3])"]
  },
  "kombinatorik" => {
    "de" => ["belaege = { \"Speck\" => 3, \"Pilze\" => 2, \"Ananas\" => 2,\n            \"Oliven\" => 1, \"Salami\" => 3, \"Käse\" => 1 }\n\ndef pizzen(belaege, budget)\n  belaege.keys.combination(3).select do |pizza|\n    pizza.sum { |b| belaege[b] } <= budget\n  end\nend\n\npizzen(belaege, 5)",
             "belaege = { \"Speck\" => 3, \"Pilze\" => 2, \"Ananas\" => 2,\n            \"Oliven\" => 1, \"Salami\" => 3, \"Käse\" => 1 }\n\ndef pizzen(belaege, budget)\n  belaege.to_a.combination(3).filter_map do |drei|\n    drei.map(&:first) if drei.sum(&:last) <= budget\n  end\nend\np pizzen(belaege, 5).size"],
    "en" => ["toppings = { \"bacon\" => 3, \"mushrooms\" => 2, \"pineapple\" => 2,\n             \"olives\" => 1, \"salami\" => 3, \"cheese\" => 1 }\n\ndef pizzas(toppings, budget)\n  toppings.keys.combination(3).select do |pizza|\n    pizza.sum { |t| toppings[t] } <= budget\n  end\nend\n\npizzas(toppings, 5)",
             "toppings = { \"bacon\" => 3, \"mushrooms\" => 2, \"pineapple\" => 2,\n             \"olives\" => 1, \"salami\" => 3, \"cheese\" => 1 }\n\ndef pizzas(toppings, budget)\n  toppings.to_a.combination(3).filter_map do |three|\n    three.map(&:first) if three.sum(&:last) <= budget\n  end\nend\np pizzas(toppings, 5).size"]
  },
  "backtracking" => {
    "de" => ["def korb_fuellen(pakete, ziel)\n  return [] if ziel == 0\n  return nil if ziel < 0 || pakete.empty?\n  erstes = pakete.first\n  rest = pakete.drop(1)\n  mit = korb_fuellen(rest, ziel - erstes)\n  return [erstes] + mit if mit\n  korb_fuellen(rest, ziel)\nend\n\nkorb_fuellen([8, 6, 7, 5, 3], 16)",
             "def korb_fuellen(pakete, ziel, korb = [], i = 0)\n  return korb.dup if korb.sum == ziel\n  return nil if korb.sum > ziel || i == pakete.size\n  korb << pakete[i]\n  loesung = korb_fuellen(pakete, ziel, korb, i + 1)\n  korb.pop\n  loesung || korb_fuellen(pakete, ziel, korb, i + 1)\nend\np korb_fuellen([8, 6, 7, 5, 3], 16)"],
    "en" => ["def fill_basket(packets, target)\n  return [] if target == 0\n  return nil if target < 0 || packets.empty?\n  first = packets.first\n  rest = packets.drop(1)\n  with = fill_basket(rest, target - first)\n  return [first] + with if with\n  fill_basket(rest, target)\nend\n\nfill_basket([8, 6, 7, 5, 3], 16)",
             "def fill_basket(packets, target, basket = [], i = 0)\n  return basket.dup if basket.sum == target\n  return nil if basket.sum > target || i == packets.size\n  basket << packets[i]\n  found = fill_basket(packets, target, basket, i + 1)\n  basket.pop\n  found || fill_basket(packets, target, basket, i + 1)\nend\np fill_basket([8, 6, 7, 5, 3], 16)"]
  },
  "stapel" => {
    "de" => ["def ausgeglichen?(text)\n  partner = { \")\" => \"(\", \"]\" => \"[\", \"}\" => \"{\" }\n  stapel = []\n  text.each_char do |z|\n    if \"([{\".include?(z)\n      stapel.push(z)\n    elsif partner[z]\n      return false if stapel.pop != partner[z]\n    end\n  end\n  stapel.empty?\nend\n\nausgeglichen?(\"{Speck [mit (Ei)]}\")",
             "def ausgeglichen?(text)\n  stapel = []\n  text.chars.each do |z|\n    case z\n    when \"(\", \"[\", \"{\" then stapel.push(z)\n    when \")\" then return false unless stapel.pop == \"(\"\n    when \"]\" then return false unless stapel.pop == \"[\"\n    when \"}\" then return false unless stapel.pop == \"{\"\n    end\n  end\n  stapel.empty?\nend\np ausgeglichen?(\"{Speck [mit (Ei)]}\")"],
    "en" => ["def balanced?(text)\n  partner = { \")\" => \"(\", \"]\" => \"[\", \"}\" => \"{\" }\n  stack = []\n  text.each_char do |ch|\n    if \"([{\".include?(ch)\n      stack.push(ch)\n    elsif partner[ch]\n      return false if stack.pop != partner[ch]\n    end\n  end\n  stack.empty?\nend\n\nbalanced?(\"{bacon [and (egg)]}\")",
             "def balanced?(text)\n  stack = []\n  text.chars.each do |ch|\n    case ch\n    when \"(\", \"[\", \"{\" then stack.push(ch)\n    when \")\" then return false unless stack.pop == \"(\"\n    when \"]\" then return false unless stack.pop == \"[\"\n    when \"}\" then return false unless stack.pop == \"{\"\n    end\n  end\n  stack.empty?\nend\np balanced?(\"{bacon [and (egg)]}\")"]
  },
  "labyrinth" => {
    "de" => ["def schritte_zum_speck(labyrinth)\n  start = finde(labyrinth, \"S\")\n  abstand = { start => 0 }\n  schlange = [start]\n  until schlange.empty?\n    zelle = schlange.shift\n    freie_nachbarn(labyrinth, zelle).each do |n|\n      next if abstand.key?(n)\n      abstand[n] = abstand[zelle] + 1\n      schlange.push(n)\n    end\n  end\n  abstand[finde(labyrinth, \"Z\")]\nend\n\np schritte_zum_speck(labyrinth)\nschritte_zum_speck([\"S.#.Z\"])",
             "def schritte_zum_speck(labyrinth)\n  zeile = labyrinth.index { |text| text.include?(\"S\") }\n  start = [zeile, labyrinth[zeile].index(\"S\")]\n  gesehen = { start => 0 }\n  schlange = [start]\n  while (zelle = schlange.shift)\n    z, s = zelle\n    return gesehen[zelle] if labyrinth[z][s] == \"Z\"\n    [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dz, ds|\n      nz = z + dz\n      ns = s + ds\n      next if nz < 0 || ns < 0 || nz >= labyrinth.size\n      next if ns >= labyrinth[nz].size || labyrinth[nz][ns] == \"#\"\n      next if gesehen.key?([nz, ns])\n      gesehen[[nz, ns]] = gesehen[zelle] + 1\n      schlange << [nz, ns]\n    end\n  end\n  nil\nend\np schritte_zum_speck([\"S..\", \"#.#\", \"..Z\"])"],
    "en" => ["def steps_to_bacon(maze)\n  start = locate(maze, \"S\")\n  dist = { start => 0 }\n  queue = [start]\n  until queue.empty?\n    cell = queue.shift\n    open_neighbours(maze, cell).each do |n|\n      next if dist.key?(n)\n      dist[n] = dist[cell] + 1\n      queue.push(n)\n    end\n  end\n  dist[locate(maze, \"G\")]\nend\n\np steps_to_bacon(maze)\nsteps_to_bacon([\"S.#.G\"])",
             "def steps_to_bacon(maze)\n  row = maze.index { |line| line.include?(\"S\") }\n  start = [row, maze[row].index(\"S\")]\n  seen = { start => 0 }\n  queue = [start]\n  while (cell = queue.shift)\n    r, c = cell\n    return seen[cell] if maze[r][c] == \"G\"\n    [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dr, dc|\n      nr = r + dr\n      nc = c + dc\n      next if nr < 0 || nc < 0 || nr >= maze.size\n      next if nc >= maze[nr].size || maze[nr][nc] == \"#\"\n      next if seen.key?([nr, nc])\n      seen[[nr, nc]] = seen[cell] + 1\n      queue << [nr, nc]\n    end\n  end\n  nil\nend\np steps_to_bacon([\"S..\", \"#.#\", \"..G\"])"]
  },
  "aehnlich" => {
    "de" => ["def vorschlag(wort, woerter)\n  bestes = woerter.min_by { |w| levenshtein_memo(wort, w) }\n  bestes if levenshtein_memo(wort, bestes) <= 2\nend\n\np vorschlag(\"Spek\", %w[Speck Ei Toast])\nvorschlag(\"Xylofon\", %w[Speck Ei Toast])",
             "def vorschlag(wort, woerter)\n  nahe = woerter.select { |w| levenshtein_memo(wort, w) <= 2 }\n  nahe.min_by { |w| levenshtein_memo(wort, w) }\nend\np vorschlag(\"Tost\", %w[Speck Ei Toast])"],
    "en" => ["def suggest(word, words)\n  best = words.min_by { |w| levenshtein_memo(word, w) }\n  best if levenshtein_memo(word, best) <= 2\nend\n\np suggest(\"bacn\", %w[bacon egg toast])\nsuggest(\"xylophone\", %w[bacon egg toast])",
             "def suggest(word, words)\n  near = words.select { |w| levenshtein_memo(word, w) <= 2 }\n  near.min_by { |w| levenshtein_memo(word, w) }\nend\np suggest(\"tost\", %w[bacon egg toast])"]
  },
  "lebensspiel" => {
    "de" => ["def naechste_generation(gitter)\n  gitter.length.times.map do |z|\n    gitter[z].length.times.map do |s|\n      n = lebende_nachbarn(gitter, z, s)\n      lebt = gitter[z][s] == \"#\"\n      n == 3 || (lebt && n == 2) ? \"#\" : \".\"\n    end.join\n  end\nend\n\nputs naechste_generation(blinker)",
             "def naechste_generation(gitter)\n  gitter.each_with_index.map do |text, z|\n    text.chars.each_with_index.map do |zelle, s|\n      n = 0\n      (z - 1..z + 1).each do |y|\n        (s - 1..s + 1).each do |x|\n          next if [y, x] == [z, s] || y < 0 || x < 0\n          n += 1 if gitter[y] && gitter[y][x] == \"#\"\n        end\n      end\n      if zelle == \"#\"\n        n == 2 || n == 3 ? \"#\" : \".\"\n      else\n        n == 3 ? \"#\" : \".\"\n      end\n    end.join\n  end\nend\np naechste_generation([\"...\", \"###\", \"...\"])"],
    "en" => ["def next_generation(grid)\n  grid.length.times.map do |r|\n    grid[r].length.times.map do |c|\n      n = live_neighbours(grid, r, c)\n      alive = grid[r][c] == \"#\"\n      n == 3 || (alive && n == 2) ? \"#\" : \".\"\n    end.join\n  end\nend\n\nputs next_generation(blinker)",
             "def next_generation(grid)\n  grid.each_with_index.map do |line, r|\n    line.chars.each_with_index.map do |cell, c|\n      n = 0\n      (r - 1..r + 1).each do |y|\n        (c - 1..c + 1).each do |x|\n          next if [y, x] == [r, c] || y < 0 || x < 0\n          n += 1 if grid[y] && grid[y][x] == \"#\"\n        end\n      end\n      if cell == \"#\"\n        n == 2 || n == 3 ? \"#\" : \".\"\n      else\n        n == 3 ? \"#\" : \".\"\n      end\n    end.join\n  end\nend\np next_generation([\"...\", \"###\", \"...\"])"]
  },
  "markov" => {
    "de" => ["def zaehle_nachfolger(text)\n  tabelle = Hash.new { |hash, key| hash[key] = [] }\n  text.split.each_cons(2) { |a, b| tabelle[a] << b }\n  tabelle.transform_values(&:tally)\nend\n\nzaehle_nachfolger(\"der fuchs und der fuchs schnarcht\")",
             "def zaehle_nachfolger(text)\n  zaehler = Hash.new { |hash, key| hash[key] = Hash.new(0) }\n  text.split.each_cons(2) { |a, b| zaehler[a][b] += 1 }\n  zaehler\nend\np zaehle_nachfolger(text)"],
    "en" => ["def follower_counts(text)\n  table = Hash.new { |hash, key| hash[key] = [] }\n  text.split.each_cons(2) { |a, b| table[a] << b }\n  table.transform_values(&:tally)\nend\n\nfollower_counts(\"the fox and the fox naps\")",
             "def follower_counts(text)\n  counts = Hash.new { |hash, key| hash[key] = Hash.new(0) }\n  text.split.each_cons(2) { |a, b| counts[a][b] += 1 }\n  counts\nend\np follower_counts(text)"]
  },
  "operatoren" => {
    "de" => ["class Geld\n  attr_reader :rappen\n\n  def initialize(rappen)\n    @rappen = rappen\n  end\n\n  def +(other)\n    Geld.new(rappen + other.rappen)\n  end\n\n  def to_s\n    format(\"%.2f CHF\", rappen / 100.0)\n  end\n\n  def ==(other)\n    other.is_a?(Geld) && rappen == other.rappen\n  end\nend\n\neinkauf = [Geld.new(450), Geld.new(120), Geld.new(230)]\nputs einkauf.sum(Geld.new(0))",
             "class Geld\n  attr_reader :rappen\n\n  def initialize(rappen)\n    @rappen = rappen\n  end\n\n  def +(anderes)\n    Geld.new(@rappen + anderes.rappen)\n  end\n\n  def to_s\n    \"\#{rappen / 100}.\#{(rappen % 100).to_s.rjust(2, \"0\")} CHF\"\n  end\n\n  def ==(anderes)\n    anderes.class == Geld && anderes.rappen == rappen\n  end\nend\n\np Geld.new(450) + Geld.new(120) == Geld.new(570)"],
    "en" => ["class Money\n  attr_reader :cents\n\n  def initialize(cents)\n    @cents = cents\n  end\n\n  def +(other)\n    Money.new(cents + other.cents)\n  end\n\n  def to_s\n    format(\"%.2f CHF\", cents / 100.0)\n  end\n\n  def ==(other)\n    other.is_a?(Money) && cents == other.cents\n  end\nend\n\nshopping = [Money.new(450), Money.new(120), Money.new(230)]\nputs shopping.sum(Money.new(0))",
             "class Money\n  attr_reader :cents\n\n  def initialize(cents)\n    @cents = cents\n  end\n\n  def +(another)\n    Money.new(@cents + another.cents)\n  end\n\n  def to_s\n    \"\#{cents / 100}.\#{(cents % 100).to_s.rjust(2, \"0\")} CHF\"\n  end\n\n  def ==(another)\n    another.class == Money && another.cents == cents\n  end\nend\n\np Money.new(450) + Money.new(120) == Money.new(570)"]
  },
  "arrays#bonus" => {
    "de" => [%(einkauf = ["Speck", "Ei", "Toast", "Speck", "Kaffee", "Ei", "Speck"]
ohne_doppelte = einkauf.uniq.sort
anzahl_speck = einkauf.count("Speck")
erster_letzter = [einkauf.first, einkauf.last]),
             %(einkauf = ["Speck", "Ei", "Toast", "Speck", "Kaffee", "Ei", "Speck"]
ohne_doppelte = einkauf.sort.uniq
anzahl_speck = einkauf.count("Speck")
erster_letzter = [einkauf[0], einkauf[-1]]
p erster_letzter)],
    "en" => [%(shopping = ["bacon", "egg", "toast", "bacon", "coffee", "egg", "bacon"]
no_duplicates = shopping.uniq.sort
bacon_count = shopping.count("bacon")
first_last = [shopping.first, shopping.last]),
             %(shopping = ["bacon", "egg", "toast", "bacon", "coffee", "egg", "bacon"]
no_duplicates = shopping.sort.uniq
bacon_count = shopping.count("bacon")
first_last = [shopping[0], shopping[-1]]
p first_last)]
  },
  "methoden#bonus" => {
    "de" => [%(def tagesgruss(name, stunde = 12)
  if stunde < 12
    "Guten Morgen, \#{name}!"
  elsif stunde < 18
    "Guten Tag, \#{name}!"
  else
    "Guten Abend, \#{name}!"
  end
end

tagesgruss("Kaz", 9)),
             %(def tagesgruss(name, stunde = 12)
  zeit = stunde < 12 ? "Morgen" : (stunde < 18 ? "Tag" : "Abend")
  "Guten \#{zeit}, \#{name}!"
end

puts tagesgruss("Kaz", 9))],
    "en" => [%(def greeting_for(name, hour = 12)
  if hour < 12
    "Good morning, \#{name}!"
  elsif hour < 18
    "Good afternoon, \#{name}!"
  else
    "Good evening, \#{name}!"
  end
end

greeting_for("Kaz", 9)),
             %(def greeting_for(name, hour = 12)
  time = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
  "Good \#{time}, \#{name}!"
end

puts greeting_for("Kaz", 9))]
  },
  "strings#bonus" => {
    "de" => [%(wort = "Lagerregal"
rueckwaerts = wort.reverse
palindrom = wort.downcase == wort.downcase.reverse
laenge = wort.length),
             %(wort = "Lagerregal"
rueckwaerts = wort.reverse
klein = wort.downcase
palindrom = klein == klein.reverse
laenge = wort.size
p palindrom)],
    "en" => [%(word = "Racecar"
backwards = word.reverse
palindrome = word.downcase == word.downcase.reverse
length = word.length),
             %(word = "Racecar"
backwards = word.reverse
lower = word.downcase
palindrome = lower == lower.reverse
length = word.size
p palindrome)]
  },
  "wenn#bonus" => {
    "de" => [%(punkte = 83
note = case punkte
       when 90..100 then "A"
       when 80..89 then "B"
       when 70..79 then "C"
       else "D"
       end),
             %(punkte = 83
case punkte
when 90..100
  note = "A"
when 80..89
  note = "B"
when 70..79
  note = "C"
else
  note = "D"
end
puts note)],
    "en" => [%(points = 83
grade = case points
        when 90..100 then "A"
        when 80..89 then "B"
        when 70..79 then "C"
        else "D"
        end),
             %(points = 83
case points
when 90..100
  grade = "A"
when 80..89
  grade = "B"
when 70..79
  grade = "C"
else
  grade = "D"
end
puts grade)]
  },
  "schleifen#bonus" => {
    "de" => [%((1..15).each do |i|
  if i % 15 == 0
    puts "Speck-Ei"
  elsif i % 3 == 0
    puts "Speck"
  elsif i % 5 == 0
    puts "Ei"
  else
    puts i
  end
end),
             %(1.upto(15) do |i|
  wort = ""
  wort += "Speck" if i % 3 == 0
  wort += "-" if i % 15 == 0
  wort += "Ei" if i % 5 == 0
  puts(wort == "" ? i : wort)
end)],
    "en" => [%((1..15).each do |i|
  if i % 15 == 0
    puts "bacon-egg"
  elsif i % 3 == 0
    puts "bacon"
  elsif i % 5 == 0
    puts "egg"
  else
    puts i
  end
end),
             %(1.upto(15) do |i|
  word = ""
  word += "bacon" if i % 3 == 0
  word += "-" if i % 15 == 0
  word += "egg" if i % 5 == 0
  puts(word == "" ? i : word)
end)]
  },
  "hashes#bonus" => {
    "de" => [%(woerter = %w[speck ei speck toast ei speck]
zaehlung = Hash.new(0)
woerter.each { |wort| zaehlung[wort] += 1 }
haeufigstes = zaehlung.key(zaehlung.values.max)),
             %(woerter = %w[speck ei speck toast ei speck]
zaehlung = {}
woerter.each do |wort|
  zaehlung[wort] = zaehlung.fetch(wort, 0) + 1
end
haeufigstes = zaehlung.max_by { |wort, anzahl| anzahl }[0]
p haeufigstes)],
    "en" => [%(words = %w[bacon egg bacon toast egg bacon]
tally = Hash.new(0)
words.each { |word| tally[word] += 1 }
most_common = tally.key(tally.values.max)),
             %(words = %w[bacon egg bacon toast egg bacon]
tally = {}
words.each do |word|
  tally[word] = tally.fetch(word, 0) + 1
end
most_common = tally.max_by { |word, count| count }[0]
p most_common)]
  },
  "sortieren#bonus" => {
    "de" => ["karte = %w[Speck Ei Toast Brot Kaffee Tee]\npreise = [1, 3, 4, 7, 12, 18, 25, 40]\n\nnach_laenge = karte.sort_by { |w| [w.length, w] }\nerste_grosse = preise.bsearch { |preis| preis >= 10 }",
             "karte = %w[Speck Ei Toast Brot Kaffee Tee]\npreise = [1, 3, 4, 7, 12, 18, 25, 40]\nnach_laenge = karte.sort { |a, b| [a.size, a] <=> [b.size, b] }\nerste_grosse = preise.bsearch { _1 >= 10 }\np nach_laenge"],
    "en" => ["menu = %w[bacon egg toast jam coffee tea]\nprices = [1, 3, 4, 7, 12, 18, 25, 40]\n\nsorted_words = menu.sort_by { |w| [w.length, w] }\nfirst_big = prices.bsearch { |price| price >= 10 }",
             "menu = %w[bacon egg toast jam coffee tea]\nprices = [1, 3, 4, 7, 12, 18, 25, 40]\nsorted_words = menu.sort { |a, b| [a.size, a] <=> [b.size, b] }\nfirst_big = prices.bsearch { _1 >= 10 }\np sorted_words"]
  },
  "zeit#bonus" => {
    "de" => ["require \"date\"\n\npechmonate = (1..12).select { |monat| Date.new(2026, monat, 13).friday? }",
             "require \"date\"\npechmonate = (1..12).filter_map { |m| m if Date.new(2026, m, 13).friday? }\np pechmonate"],
    "en" => ["require \"date\"\n\nunlucky = (1..12).select { |month| Date.new(2026, month, 13).friday? }",
             "require \"date\"\nunlucky = (1..12).filter_map { |m| m if Date.new(2026, m, 13).friday? }\np unlucky"]
  },
  "rekursion#bonus" => {
    "de" => ["def auspacken(ding)\n  if ding.is_a?(Array)\n    ding.flat_map { |inneres| auspacken(inneres) }\n  else\n    [ding]\n  end\nend\n\nauspacken([1, [2, [3, [4]]], 5])",
             "def auspacken(ding)\n  return [ding] unless ding.is_a?(Array)\n  ergebnis = []\n  ding.each { |inneres| ergebnis += auspacken(inneres) }\n  ergebnis\nend\np auspacken([1, [2, [3, [4]]], 5])"],
    "en" => ["def unbox(thing)\n  if thing.is_a?(Array)\n    thing.flat_map { |inner| unbox(inner) }\n  else\n    [thing]\n  end\nend\n\nunbox([1, [2, [3, [4]]], 5])",
             "def unbox(thing)\n  return [thing] unless thing.is_a?(Array)\n  result = []\n  thing.each { |inner| result += unbox(inner) }\n  result\nend\np unbox([1, [2, [3, [4]]], 5])"]
  },
  "turtle#bonus" => {
    "de" => ["turtle do\n  color \"#d4a017\"\n  7.times do\n    forward 150\n    right 3 * 360 / 7.0\n  end\nend",
             "angle = 1080.0 / 7\nturtle do\n  7.times { forward 150; left angle }\nend"],
    "en" => ["turtle do\n  color \"#d4a017\"\n  7.times do\n    forward 150\n    right 3 * 360 / 7.0\n  end\nend",
             "angle = 1080.0 / 7\nturtle do\n  7.times { forward 150; left angle }\nend"]
  },
  "fehler#bonus" => {
    "de" => ["streifen = [3, 5, 2, 7]\nsumme = 0\nstreifen.each do |s|\n  summe += s\nend\nschnitt = summe / streifen.length.to_f",
             "streifen = [3, 5, 2, 7]\nschnitt = streifen.sum.fdiv(streifen.length)\np schnitt"],
    "en" => ["strips = [3, 5, 2, 7]\ntotal = 0\nstrips.each do |s|\n  total += s\nend\naverage = total / strips.length.to_f",
             "strips = [3, 5, 2, 7]\naverage = strips.sum.fdiv(strips.length)\np average"]
  },
  "muster#bonus" => {
    "de" => ["[1, 3, 5, 7, 5, 3, 1].each do |n|\n  sterne = \"*\" * n\n  puts sterne.center(7)\nend",
             "((1..4).to_a + [3, 2, 1]).map { |z| (\"*\" * (2 * z - 1)).center(7).rstrip }.join(\"\\n\")"],
    "en" => ["[1, 3, 5, 7, 5, 3, 1].each do |n|\n  stars = \"*\" * n\n  puts stars.center(7)\nend",
             "((1..4).to_a + [3, 2, 1]).map { |r| (\"*\" * (2 * r - 1)).center(7).rstrip }.join(\"\\n\")"]
  },
  "geheimschrift#bonus" => {
    "de" => ["abgefangen = \"opc qfnsd tdde dapnv\"\n\nschluessel = (1..25).find { |s| abgefangen.chars.map { |z| verschieben(z, -s) }.join.include?(\"speck\") }\nklartext = abgefangen.chars.map { |z| verschieben(z, -schluessel) }.join",
             "abgefangen = \"opc qfnsd tdde dapnv\"\nschluessel = 1\nschluessel += 1 until abgefangen.chars.map { |z| verschieben(z, -schluessel) }.join.include?(\"speck\")\nklartext = abgefangen.chars.map { |z| verschieben(z, -schluessel) }.join\np klartext"],
    "en" => ["intercepted = \"esp qzi pled mlnzy\"\n\nkey = (1..25).find { |k| intercepted.chars.map { |c| shift_letter(c, -k) }.join.include?(\"bacon\") }\nplain = intercepted.chars.map { |c| shift_letter(c, -key) }.join",
             "intercepted = \"esp qzi pled mlnzy\"\nkey = 1\nkey += 1 until intercepted.chars.map { |c| shift_letter(c, -key) }.join.include?(\"bacon\")\nplain = intercepted.chars.map { |c| shift_letter(c, -key) }.join\np plain"]
  },
  "knobeln#bonus" => {
    "de" => ["def goldbach(n)\n  a = (2..n / 2).find { |x| primzahl?(x) && primzahl?(n - x) }\n  [a, n - a]\nend\n\ngoldbach(28)",
             "def goldbach(n)\n  2.upto(n) do |a|\n    return [a, n - a] if primzahl?(a) && primzahl?(n - a)\n  end\nend\np goldbach(100)"],
    "en" => ["def goldbach(n)\n  a = (2..n / 2).find { |x| prime?(x) && prime?(n - x) }\n  [a, n - a]\nend\n\ngoldbach(28)",
             "def goldbach(n)\n  2.upto(n) do |a|\n    return [a, n - a] if prime?(a) && prime?(n - a)\n  end\nend\np goldbach(100)"]
  },
  "symbole#bonus" => {
    "de" => ["woerter = %w[Speck Ei Senf Essig Apfel]\ngruppen = {}\n\nwoerter.each do |wort|\n  gruppen[wort[0]] ||= []\n  gruppen[wort[0]] << wort\nend",
             "woerter = %w[Speck Ei Senf Essig Apfel]\ngruppen = {}\nwoerter.each { |w| (gruppen[w[0]] ||= []) << w }\np gruppen"],
    "en" => ["words = %w[bacon egg banana eel apple]\ngroups = {}\n\nwords.each do |word|\n  groups[word[0]] ||= []\n  groups[word[0]] << word\nend",
             "words = %w[bacon egg banana eel apple]\ngroups = {}\nwords.each { |w| (groups[w[0]] ||= []) << w }\np groups"]
  },
  "struct#bonus" => {
    "de" => ["Temperatur = Data.define(:grad) do\n  def fahrenheit\n    grad * 9 / 5.0 + 32\n  end\n\n  def waermer(um)\n    with(grad: grad + um)\n  end\nend\n\nTemperatur.new(grad: 20).waermer(5)",
             "Temperatur = Data.define(:grad) do\n  def fahrenheit = grad * 1.8 + 32\n  def waermer(um) = with(grad: grad + um)\nend\np Temperatur.new(grad: 20).fahrenheit"],
    "en" => ["Temperature = Data.define(:degrees) do\n  def fahrenheit\n    degrees * 9 / 5.0 + 32\n  end\n\n  def warmer(by)\n    with(degrees: degrees + by)\n  end\nend\n\nTemperature.new(degrees: 20).warmer(5)",
             "Temperature = Data.define(:degrees) do\n  def fahrenheit = degrees * 1.8 + 32\n  def warmer(by) = with(degrees: degrees + by)\nend\np Temperature.new(degrees: 20).fahrenheit"]
  },
  "iteratoren#bonus" => {
    "de" => [%(woerter = ["Speck", "Ei", "Kaffee", "Brot", "Honigbrot"]
initialen = woerter.map { |wort| wort[0] }.join
laengstes = woerter.max_by { |wort| wort.length }
nach_laenge = woerter.sort_by { |wort| wort.length }),
             %(woerter = ["Speck", "Ei", "Kaffee", "Brot", "Honigbrot"]
initialen = woerter.map { _1[0] }.join
laengstes = woerter.max_by(&:length)
nach_laenge = woerter.sort_by(&:length)
p nach_laenge)],
    "en" => [%(words = ["bacon", "egg", "coffee", "milk", "pancakes"]
initials = words.map { |word| word[0] }.join
longest = words.max_by { |word| word.length }
by_length = words.sort_by { |word| word.length }),
             %(words = ["bacon", "egg", "coffee", "milk", "pancakes"]
initials = words.map { _1[0] }.join
longest = words.max_by(&:length)
by_length = words.sort_by(&:length)
p by_length)]
  },
  "rechnen#bonus" => {
    "de" => [%(fahrenheit = 25 * 9 / 5 + 32
celsius = ((100 - 32) * 5 / 9.0).round(1)),
             %(fahrenheit = 25 * 9 / 5 + 32
celsius = (100 - 32).fdiv(9).*(5).round(1)
puts celsius)],
    "en" => [%(fahrenheit = 25 * 9 / 5 + 32
celsius = ((100 - 32) * 5 / 9.0).round(1)),
             %(fahrenheit = 25 * 9 / 5 + 32
celsius = (100 - 32).fdiv(9).*(5).round(1)
puts celsius)]
  },
  "variablen#bonus" => {
    "de" => [%(a = 1
b = 2
merker = a
a = b
b = merker
summe = a + b),
             %(a = 1
b = 2
alt = a
a = b
b = alt
summe = a + b
puts summe)],
    "en" => [%(a = 1
b = 2
helper = a
a = b
b = helper
total = a + b),
             %(a = 1
b = 2
old = a
a = b
b = old
total = a + b
puts total)]
  },
  "zufall#bonus" => {
    "de" => [%(zahlen = (1..10).to_a.sample(3).sort
muenzen = 10.times.map { ["Kopf", "Zahl"].sample }),
             %(zahlen = [*1..10].shuffle.first(3).sort
muenzen = Array.new(10) { %w[Kopf Zahl].sample }
p muenzen.count("Kopf"))],
    "en" => [%(numbers = (1..10).to_a.sample(3).sort
coins = 10.times.map { ["heads", "tails"].sample }),
             %(numbers = [*1..10].shuffle.first(3).sort
coins = Array.new(10) { %w[heads tails].sample }
p coins.count("heads"))]
  },
  "regex#bonus" => {
    "de" => [%(bericht = "Chunky: 3 Streifen, Kaz: 12 Streifen, Isi: 7 Streifen"
paare = bericht.scan(/(\\w+): (\\d+)/)
gesamt = paare.sum { |name, zahl| zahl.to_i }),
             %(bericht = "Chunky: 3 Streifen, Kaz: 12 Streifen, Isi: 7 Streifen"
paare = bericht.scan(/([A-Za-z]+): (\\d+)/)
gesamt = paare.map { |p| p[1].to_i }.sum
p gesamt)],
    "en" => [%(report = "Chunky: 3 strips, Kaz: 12 strips, Isi: 7 strips"
pairs = report.scan(/(\\w+): (\\d+)/)
total = pairs.sum { |name, number| number.to_i }),
             %(report = "Chunky: 3 strips, Kaz: 12 strips, Isi: 7 strips"
pairs = report.scan(/([A-Za-z]+): (\\d+)/)
total = pairs.map { |p| p[1].to_i }.sum
p total)]
  },
  "formatieren#bonus" => {
    "de" => [%(einkauf = { "Speck" => 4.5, "Brot" => 2, "Honig" => 6.8 }
zeilen = einkauf.map { |artikel, preis| artikel.ljust(12) + format("%6.2f", preis) }
tabelle = "Artikel".ljust(12) + "Preis".rjust(6) + "\\n" + "-" * 18 + "\\n" + zeilen.join("\\n")),
             %(einkauf = { "Speck" => 4.5, "Brot" => 2, "Honig" => 6.8 }
teile = ["Artikel".ljust(12) + "Preis".rjust(6), "-" * 18]
einkauf.each { |a, p| teile << format("%-12s%6.2f", a, p) }
tabelle = teile.join("\\n")
puts tabelle)],
    "en" => [%(shopping = { "Bacon" => 4.5, "Bread" => 2, "Honey" => 6.8 }
lines = shopping.map { |item, price| item.ljust(12) + format("%6.2f", price) }
table = "Item".ljust(12) + "Price".rjust(6) + "\\n" + "-" * 18 + "\\n" + lines.join("\\n")),
             %(shopping = { "Bacon" => 4.5, "Bread" => 2, "Honey" => 6.8 }
parts = ["Item".ljust(12) + "Price".rjust(6), "-" * 18]
shopping.each { |i, p| parts << format("%-12s%6.2f", i, p) }
table = parts.join("\\n")
puts table)]
  },
  "klassen#bonus" => {
    "de" => [%(class Sparschwein
  def initialize
    @rappen = 0
  end

  def einwerfen(rappen)
    @rappen += rappen
  end

  def stand
    @rappen
  end
end

schwein = Sparschwein.new
schwein.einwerfen(50)
schwein.einwerfen(20)
schwein.stand),
             %(class Sparschwein
  attr_reader :stand

  def initialize
    @stand = 0
  end

  def einwerfen(rappen)
    @stand = @stand + rappen
    self
  end
end

puts Sparschwein.new.einwerfen(50).einwerfen(20).stand)],
    "en" => [%(class PiggyBank
  def initialize
    @cents = 0
  end

  def add(cents)
    @cents += cents
  end

  def total
    @cents
  end
end

bank = PiggyBank.new
bank.add(50)
bank.add(20)
bank.total),
             %(class PiggyBank
  attr_reader :total

  def initialize
    @total = 0
  end

  def add(cents)
    @total = @total + cents
    self
  end
end

puts PiggyBank.new.add(50).add(20).total)]
  },
  "vererbung#bonus" => {
    "de" => [%(class Nutztier
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def laut
    "..."
  end

  def vorstellen
    "Ich bin \#{name} und sage \#{laut}"
  end
end

class Huhn < Nutztier
  def laut
    "Gack!"
  end

  def vorstellen
    super + " – und ich lege Eier"
  end
end

Huhn.new("Berta").vorstellen),
             %(class Nutztier
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def laut
    "..."
  end

  def vorstellen
    "Ich bin \#{name} und sage \#{laut}"
  end
end

class Huhn < Nutztier
  def laut = "Gack!"

  def vorstellen
    "\#{super} – und ich lege Eier"
  end
end

puts Huhn.new("Berta").vorstellen)],
    "en" => [%(class FarmAnimal
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def sound
    "..."
  end

  def introduce
    "I am \#{name} and I say \#{sound}"
  end
end

class Hen < FarmAnimal
  def sound
    "Cluck!"
  end

  def introduce
    super + " - and I lay eggs"
  end
end

Hen.new("Berta").introduce),
             %(class FarmAnimal
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def sound
    "..."
  end

  def introduce
    "I am \#{name} and I say \#{sound}"
  end
end

class Hen < FarmAnimal
  def sound = "Cluck!"

  def introduce
    "\#{super} - and I lay eggs"
  end
end

puts Hen.new("Berta").introduce)]
  },
  "module#bonus" => {
    "de" => [%(class Rucksack
  include Comparable
  attr_reader :gewicht

  def initialize(gewicht)
    @gewicht = gewicht
  end

  def <=>(anderer)
    gewicht <=> anderer.gewicht
  end
end

[Rucksack.new(7), Rucksack.new(3), Rucksack.new(5)].min.gewicht),
             %(class Rucksack
  include Comparable
  attr_reader :gewicht

  def initialize(gewicht) = @gewicht = gewicht
  def <=>(anderer) = gewicht <=> anderer.gewicht
end

puts [Rucksack.new(7), Rucksack.new(3), Rucksack.new(5)].min.gewicht)],
    "en" => [%(class Backpack
  include Comparable
  attr_reader :weight

  def initialize(weight)
    @weight = weight
  end

  def <=>(other)
    weight <=> other.weight
  end
end

[Backpack.new(7), Backpack.new(3), Backpack.new(5)].min.weight),
             %(class Backpack
  include Comparable
  attr_reader :weight

  def initialize(weight) = @weight = weight
  def <=>(other) = weight <=> other.weight
end

puts [Backpack.new(7), Backpack.new(3), Backpack.new(5)].min.weight)]
  },
  "dateien#bonus" => {
    "de" => [%(File.write("punkte.txt", "Kaz,12\\nIsi,7\\nChunky,3\\n")
zeilen = File.read("punkte.txt").lines(chomp: true).map { |zeile| zeile.split(",") }
total = zeilen.sum { |name, punkte| punkte.to_i }
bester = zeilen.max_by { |name, punkte| punkte.to_i }[0]),
             %(File.write("punkte.txt", "Kaz,12\\nIsi,7\\nChunky,3\\n")
total = 0
bester = nil
meiste = -1
File.read("punkte.txt").split("\\n").each do |zeile|
  name, punkte = zeile.split(",")
  total += punkte.to_i
  if punkte.to_i > meiste
    meiste = punkte.to_i
    bester = name
  end
end
puts bester)],
    "en" => [%(File.write("points.txt", "Kaz,12\\nIsi,7\\nChunky,3\\n")
rows = File.read("points.txt").lines(chomp: true).map { |line| line.split(",") }
total = rows.sum { |name, points| points.to_i }
best = rows.max_by { |name, points| points.to_i }[0]),
             %(File.write("points.txt", "Kaz,12\\nIsi,7\\nChunky,3\\n")
total = 0
best = nil
most = -1
File.read("points.txt").split("\\n").each do |line|
  name, points = line.split(",")
  total += points.to_i
  if points.to_i > most
    most = points.to_i
    best = name
  end
end
puts best)]
  },
  "bereiche#bonus" => {
    "de" => ["erster_tag = nil\n(1..).each do |tag|\n  if (1..tag).sum >= 100\n    erster_tag = tag\n    break\n  end\nend",
             "erspart = 0\nerster_tag = (1..).each do |tag|\n  erspart += tag\n  break tag if erspart >= 100\nend\np erster_tag"],
    "en" => ["first_day = nil\n(1..).each do |day|\n  if (1..day).sum >= 100\n    first_day = day\n    break\n  end\nend",
             "savings = 0\nfirst_day = (1..).each do |day|\n  savings += day\n  break day if savings >= 100\nend\np first_day"]
  },
  "mengen#bonus" => {
    "de" => ["satz = \"Franz jagt im komplett verwahrlosten Taxi quer durch Bayern\"\nanderer = \"Der Fuchs Chunky jagt im Taxi quer durch Bayern\"\n\nalphabet = (\"a\"..\"z\").to_set\npangramm = alphabet.subset?(satz.downcase.chars.to_set)\nfehlen = (alphabet - anderer.downcase.chars.to_set).sort.join",
             "satz = \"Franz jagt im komplett verwahrlosten Taxi quer durch Bayern\"\nanderer = \"Der Fuchs Chunky jagt im Taxi quer durch Bayern\"\nbuchstaben = satz.downcase.chars.to_set\npangramm = buchstaben.superset?((\"a\"..\"z\").to_set)\nfehlen = ((\"a\"..\"z\").to_a - anderer.downcase.chars).join\np pangramm, fehlen"],
    "en" => ["sentence = \"The quick brown fox jumps over the lazy dog\"\nother = \"Chunky the fox jumps over the lazy dog\"\n\nalphabet = (\"a\"..\"z\").to_set\npangram = alphabet.subset?(sentence.downcase.chars.to_set)\nmissing = (alphabet - other.downcase.chars.to_set).sort.join",
             "sentence = \"The quick brown fox jumps over the lazy dog\"\nother = \"Chunky the fox jumps over the lazy dog\"\nletters = sentence.downcase.chars.to_set\npangram = letters.superset?((\"a\"..\"z\").to_set)\nmissing = ((\"a\"..\"z\").to_a - other.downcase.chars).join\np pangram, missing"]
  },
  "reduce#bonus" => {
    "de" => ["rezepte = {\n  \"Pfannkuchen\" => { \"Ei\" => 2, \"Milch\" => 3, \"Mehl\" => 2 },\n  \"Omelett\" => { \"Ei\" => 3, \"K\u00E4se\" => 1 }\n}\nwoche = [\"Pfannkuchen\", \"Omelett\", \"Pfannkuchen\"]\n\neinkauf = woche.each_with_object(Hash.new(0)) do |gericht, liste|\n  rezepte[gericht].each { |zutat, menge| liste[zutat] += menge }\nend",
             "rezepte = {\n  \"Pfannkuchen\" => { \"Ei\" => 2, \"Milch\" => 3, \"Mehl\" => 2 },\n  \"Omelett\" => { \"Ei\" => 3, \"K\u00E4se\" => 1 }\n}\nwoche = [\"Pfannkuchen\", \"Omelett\", \"Pfannkuchen\"]\neinkauf = {}\nwoche.each_with_object(einkauf) do |gericht, liste|\n  rezepte[gericht].each { |z, m| liste[z] = liste.fetch(z, 0) + m }\nend\np einkauf"],
    "en" => ["recipes = {\n  \"pancakes\" => { \"egg\" => 2, \"milk\" => 3, \"flour\" => 2 },\n  \"omelette\" => { \"egg\" => 3, \"cheese\" => 1 }\n}\nweek = [\"pancakes\", \"omelette\", \"pancakes\"]\n\nshopping = week.each_with_object(Hash.new(0)) do |dish, list|\n  recipes[dish].each { |item, amount| list[item] += amount }\nend",
             "recipes = {\n  \"pancakes\" => { \"egg\" => 2, \"milk\" => 3, \"flour\" => 2 },\n  \"omelette\" => { \"egg\" => 3, \"cheese\" => 1 }\n}\nweek = [\"pancakes\", \"omelette\", \"pancakes\"]\nshopping = {}\nweek.each_with_object(shopping) do |dish, list|\n  recipes[dish].each { |item, n| list[item] = list.fetch(item, 0) + n }\nend\np shopping"]
  },
  "listen#bonus" => {
    "de" => ["zischen = \"zzzzischhhh\"\ngeheim = \"1c1h3u1n1k1y\"\n\nfolgen = zischen.chars.chunk_while { |a, b| a == b }\ngepackt = folgen.map { |folge| \"\#{folge.size}\#{folge.first}\" }.join\npaare = geheim.chars.each_slice(2)\nentpackt = paare.map { |anzahl, zeichen| zeichen * anzahl.to_i }.join",
             "zischen = \"zzzzischhhh\"\ngeheim = \"1c1h3u1n1k1y\"\ngruppen = zischen.chars.chunk { |z| z }\ngepackt = gruppen.map { |z, folge| \"\#{folge.size}\#{z}\" }.join\nentpackt = geheim.chars.each_slice(2).sum(\"\") { |n, z| z * n.to_i }\np gepackt, entpackt"],
    "en" => ["sizzle = \"ssssizzzzle\"\nsecret = \"1c1h3u1n1k1y\"\n\nruns = sizzle.chars.chunk_while { |a, b| a == b }\npacked = runs.map { |run| \"\#{run.size}\#{run.first}\" }.join\npairs = secret.chars.each_slice(2)\nunpacked = pairs.map { |count, letter| letter * count.to_i }.join",
             "sizzle = \"ssssizzzzle\"\nsecret = \"1c1h3u1n1k1y\"\ngroups = sizzle.chars.chunk { |ch| ch }\npacked = groups.map { |ch, run| \"\#{run.size}\#{ch}\" }.join\nunpacked = secret.chars.each_slice(2).sum(\"\") { |n, ch| ch * n.to_i }\np packed, unpacked"]
  },
  "unicode#bonus" => {
    "de" => ["gerichte = [\"Crème brûlée\", \"Café au lait\", \"Éclair\",\n            \"Crêpe mit Speck\", \"Jalapeño-Pizza\"]\n\nslugs = gerichte.map do |gericht|\n  gericht.unicode_normalize(:nfd).gsub(/\\p{Mn}/, \"\").downcase.gsub(\" \", \"-\")\nend",
             "gerichte = [\"Crème brûlée\", \"Café au lait\", \"Éclair\",\n            \"Crêpe mit Speck\", \"Jalapeño-Pizza\"]\nslugs = gerichte.map { |g| g.unicode_normalize(:nfd).downcase.scan(/[a-z -]/).join.tr(\" \", \"-\") }\np slugs"],
    "en" => ["dishes = [\"Crème brûlée\", \"Café au lait\", \"Éclair\",\n          \"Crêpe with bacon\", \"Jalapeño pizza\"]\n\nslugs = dishes.map do |dish|\n  dish.unicode_normalize(:nfd).gsub(/\\p{Mn}/, \"\").downcase.gsub(\" \", \"-\")\nend",
             "dishes = [\"Crème brûlée\", \"Café au lait\", \"Éclair\",\n          \"Crêpe with bacon\", \"Jalapeño pizza\"]\nslugs = dishes.map { |d| d.unicode_normalize(:nfd).downcase.scan(/[a-z ]/).join.tr(\" \", \"-\") }\np slugs"]
  },
  "bloecke#bonus" => {
    "de" => ["def aussieben(liste)\n  return liste unless block_given?\n\n  behalten = []\n  liste.each { |x| behalten << x if yield(x) }\n  behalten\nend\n\naussieben([3, 8, 12, 5]) { |n| n.even? }",
             "def aussieben(liste)\n  return liste.dup unless block_given?\n\n  neu = []\n  i = 0\n  while i < liste.length\n    neu << liste[i] if yield(liste[i])\n    i += 1\n  end\n  neu\nend\n\np aussieben([3, 8, 12, 5]) { |n| n.even? }"],
    "en" => ["def sift(list)\n  return list unless block_given?\n\n  kept = []\n  list.each { |x| kept << x if yield(x) }\n  kept\nend\n\nsift([3, 8, 12, 5]) { |n| n.even? }",
             "def sift(list)\n  return list.dup unless block_given?\n\n  result = []\n  i = 0\n  while i < list.length\n    result << list[i] if yield(list[i])\n    i += 1\n  end\n  result\nend\n\np sift([3, 8, 12, 5]) { |n| n.even? }"]
  },
  "gitter#bonus" => {
    "de" => ["feld = [\n  \"*...\",\n  \"..*.\",\n  \"....\"\n].map(&:chars)\n\ndef minen_zaehlen(feld)\n  feld.map.with_index do |reihe, z|\n    reihe.map.with_index do |zelle, s|\n      zelle == \"*\" ? \"*\" : ringsum(feld, z, s).count(\"*\")\n    end\n  end\nend\n\nputs minen_zaehlen(feld).map(&:join)",
             "def minen_zaehlen(feld)\n  feld.each_index.map do |z|\n    feld[z].each_index.map do |s|\n      next \"*\" if feld[z][s] == \"*\"\n      [-1, 0, 1].product([-1, 0, 1]).count do |dz, ds|\n        y, x = z + dz, s + ds\n        y >= 0 && x >= 0 && feld[y] && feld[y][x] == \"*\"\n      end\n    end\n  end\nend\np minen_zaehlen([\"*...\", \"..*.\", \"....\"].map(&:chars))"],
    "en" => ["field = [\n  \"*...\",\n  \"..*.\",\n  \"....\"\n].map(&:chars)\n\ndef mine_counts(field)\n  field.map.with_index do |line, r|\n    line.map.with_index do |cell, c|\n      cell == \"*\" ? \"*\" : around(field, r, c).count(\"*\")\n    end\n  end\nend\n\nputs mine_counts(field).map(&:join)",
             "def mine_counts(field)\n  field.each_index.map do |r|\n    field[r].each_index.map do |c|\n      next \"*\" if field[r][c] == \"*\"\n      [-1, 0, 1].product([-1, 0, 1]).count do |dr, dc|\n        y, x = r + dr, c + dc\n        y >= 0 && x >= 0 && field[y] && field[y][x] == \"*\"\n      end\n    end\n  end\nend\np mine_counts([\"*...\", \"..*.\", \"....\"].map(&:chars))"]
  },
  "zahlensysteme#bonus" => {
    "de" => ["def rechte(modus)\n  8.downto(0).map { |i| modus[i] == 1 ? \"rwx\"[(8 - i) % 3] : \"-\" }.join\nend\n\nrechte(0o754)",
             "def rechte(modus)\n  [6, 3, 0].map do |schieb|\n    bits = (modus >> schieb) & 7\n    (bits & 4 > 0 ? \"r\" : \"-\") + (bits & 2 > 0 ? \"w\" : \"-\") + (bits & 1 > 0 ? \"x\" : \"-\")\n  end.join\nend\np rechte(0o754)"],
    "en" => ["def permissions(mode)\n  8.downto(0).map { |i| mode[i] == 1 ? \"rwx\"[(8 - i) % 3] : \"-\" }.join\nend\n\npermissions(0o754)",
             "def permissions(mode)\n  [6, 3, 0].map do |shift|\n    bits = (mode >> shift) & 7\n    (bits & 4 > 0 ? \"r\" : \"-\") + (bits & 2 > 0 ? \"w\" : \"-\") + (bits & 1 > 0 ? \"x\" : \"-\")\n  end.join\nend\np permissions(0o754)"]
  },
  "brueche#bonus" => {
    "de" => ["def gemischte_zahl(q)\n  ganz, rest = q.numerator.divmod(q.denominator)\n  return ganz.to_s if rest == 0\n  bruch = \"\#{rest}/\#{q.denominator}\"\n  return bruch if ganz == 0\n  \"\#{ganz} \#{bruch}\"\nend\n\ngemischte_zahl(9/8r)",
             "def gemischte_zahl(q)\n  ganz = q.floor\n  rest = q - ganz\n  teile = []\n  teile << ganz.to_s if ganz > 0 || rest == 0\n  teile << rest.to_s if rest > 0\n  teile.join(\" \")\nend\np gemischte_zahl(9/8r)"],
    "en" => ["def mixed_number(q)\n  whole, rest = q.numerator.divmod(q.denominator)\n  return whole.to_s if rest == 0\n  fraction = \"\#{rest}/\#{q.denominator}\"\n  return fraction if whole == 0\n  \"\#{whole} \#{fraction}\"\nend\n\nmixed_number(9/8r)",
             "def mixed_number(q)\n  whole = q.floor\n  rest = q - whole\n  parts = []\n  parts << whole.to_s if whole > 0 || rest == 0\n  parts << rest.to_s if rest > 0\n  parts.join(\" \")\nend\np mixed_number(9/8r)"]
  },
  "ausnahmen#bonus" => {
    "de" => ["def streifen_lesen(text)\n  anzahl = Integer(text)\n  raise ArgumentError, \"zu viel Speck: \#{anzahl}\" if anzahl > 10\n\n  anzahl\nend\n\ndef bestellungen(texte)\n  texte.map do |text|\n    begin\n      streifen_lesen(text)\n    rescue ArgumentError => e\n      e.message\n    end\n  end\nend\n\nbestellungen([\"3\", \"50\", \"Speck\"])",
             "def streifen_lesen(text)\n  anzahl = Integer(text)\n  if anzahl > 10\n    raise ArgumentError, \"zu viel Speck: \#{anzahl}\"\n  end\n  anzahl\nend\n\ndef bestellungen(texte)\n  texte.map do |text|\n    streifen_lesen(text)\n  rescue ArgumentError => e\n    e.message\n  end\nend\n\np bestellungen([\"3\", \"50\", \"Speck\"])"],
    "en" => ["def read_strips(text)\n  count = Integer(text)\n  raise ArgumentError, \"too much bacon: \#{count}\" if count > 10\n\n  count\nend\n\ndef take_orders(texts)\n  texts.map do |text|\n    begin\n      read_strips(text)\n    rescue ArgumentError => e\n      e.message\n    end\n  end\nend\n\ntake_orders([\"3\", \"50\", \"bacon\"])",
             "def read_strips(text)\n  count = Integer(text)\n  if count > 10\n    raise ArgumentError, \"too much bacon: \#{count}\"\n  end\n  count\nend\n\ndef take_orders(texts)\n  texts.map do |text|\n    read_strips(text)\n  rescue ArgumentError => e\n    e.message\n  end\nend\n\np take_orders([\"3\", \"50\", \"bacon\"])"]
  },
  "enumeratoren#bonus" => {
    "de" => ["def reise_laenge(n)\n  schritte = 0\n  while n != 1\n    n = n.even? ? n / 2 : 3 * n + 1\n    schritte += 1\n  end\n  schritte\nend\n\ndef lange_reisen(anzahl, schritte)\n  (1..).lazy.select { |n| reise_laenge(n) > schritte }.first(anzahl)\nend\n\nlange_reisen(3, 100)",
             "def reise(n)\n  n == 1 ? 0 : 1 + reise(n.even? ? n / 2 : 3 * n + 1)\nend\n\ndef lange_reisen(anzahl, schritte)\n  (1..).lazy.reject { |n| reise(n) <= schritte }.first(anzahl)\nend\n\np lange_reisen(3, 100)"],
    "en" => ["def journey_length(n)\n  steps = 0\n  while n != 1\n    n = n.even? ? n / 2 : 3 * n + 1\n    steps += 1\n  end\n  steps\nend\n\ndef long_journeys(count, steps)\n  (1..).lazy.select { |n| journey_length(n) > steps }.first(count)\nend\n\nlong_journeys(3, 100)",
             "def journey(n)\n  n == 1 ? 0 : 1 + journey(n.even? ? n / 2 : 3 * n + 1)\nend\n\ndef long_journeys(count, steps)\n  (1..).lazy.reject { |n| journey(n) <= steps }.first(count)\nend\n\np long_journeys(3, 100)"]
  },
  "sortierverfahren#bonus" => {
    "de" => ["def quicksort(liste)\n  return liste if liste.size <= 1\n  pivot = liste.first\n  kleine, grosse = liste.drop(1).partition { |k| k < pivot }\n  quicksort(kleine) + [pivot] + quicksort(grosse)\nend\n\nquicksort([5, 2, 8, 1, 9, 3, 7, 4])",
             "def quicksort(liste)\n  return liste if liste.size <= 1\n  pivot = liste[0]\n  rest = liste[1..]\n  kleiner = rest.select { |k| k < pivot }\n  sonst = rest.reject { |k| k < pivot }\n  quicksort(kleiner) + [pivot] + quicksort(sonst)\nend\np quicksort([5, 2, 8, 1, 9, 3, 7, 4])"],
    "en" => ["def quicksort(list)\n  return list if list.size <= 1\n  pivot = list.first\n  small, big = list.drop(1).partition { |c| c < pivot }\n  quicksort(small) + [pivot] + quicksort(big)\nend\n\nquicksort([5, 2, 8, 1, 9, 3, 7, 4])",
             "def quicksort(list)\n  return list if list.size <= 1\n  pivot = list[0]\n  rest = list[1..]\n  smaller = rest.select { |c| c < pivot }\n  others = rest.reject { |c| c < pivot }\n  quicksort(smaller) + [pivot] + quicksort(others)\nend\np quicksort([5, 2, 8, 1, 9, 3, 7, 4])"]
  },
  "kombinatorik#bonus" => {
    "de" => ["staerken = { \"Chunky\" => 7, \"Kaz\" => 3, \"Isi\" => 5,\n             \"Bo\" => 8, \"Mo\" => 2, \"Lu\" => 4 }\n\ndef faire_teams(staerken)\n  namen = staerken.keys\n  paare = namen.combination(namen.size / 2).map { |team| [team, namen - team] }\n  paare.min_by do |eins, zwei|\n    (eins.sum { |n| staerken[n] } - zwei.sum { |n| staerken[n] }).abs\n  end\nend\n\nfaire_teams(staerken)",
             "staerken = { \"Chunky\" => 7, \"Kaz\" => 3, \"Isi\" => 5,\n             \"Bo\" => 8, \"Mo\" => 2, \"Lu\" => 4 }\n\ndef faire_teams(staerken)\n  namen = staerken.keys\n  gesamt = staerken.values.sum\n  bestes = nil\n  namen.combination(namen.size / 2) do |team|\n    abstand = (2 * team.sum { |n| staerken[n] } - gesamt).abs\n    bestes = [abstand, team] if bestes.nil? || abstand < bestes[0]\n  end\n  [bestes[1], namen - bestes[1]]\nend\np faire_teams(staerken)"],
    "en" => ["strengths = { \"Chunky\" => 7, \"Kaz\" => 3, \"Isi\" => 5,\n              \"Bo\" => 8, \"Mo\" => 2, \"Lu\" => 4 }\n\ndef fair_teams(strengths)\n  names = strengths.keys\n  pairs = names.combination(names.size / 2).map { |team| [team, names - team] }\n  pairs.min_by do |one, two|\n    (one.sum { |n| strengths[n] } - two.sum { |n| strengths[n] }).abs\n  end\nend\n\nfair_teams(strengths)",
             "strengths = { \"Chunky\" => 7, \"Kaz\" => 3, \"Isi\" => 5,\n              \"Bo\" => 8, \"Mo\" => 2, \"Lu\" => 4 }\n\ndef fair_teams(strengths)\n  names = strengths.keys\n  total = strengths.values.sum\n  best = nil\n  names.combination(names.size / 2) do |team|\n    gap = (2 * team.sum { |n| strengths[n] } - total).abs\n    best = [gap, team] if best.nil? || gap < best[0]\n  end\n  [best[1], names - best[1]]\nend\np fair_teams(strengths)"]
  },
  "backtracking#bonus" => {
    "de" => ["raetsel = [\n  [0, 0, 0, 3],\n  [0, 4, 0, 0],\n  [0, 0, 3, 0],\n  [2, 0, 0, 0]\n]\n\ndef erlaubt?(gitter, z, s, zahl)\n  return false if gitter[z].include?(zahl)                  # die Zeile\n  return false if gitter.any? { |zeile| zeile[s] == zahl }  # die Spalte\n  z0 = z / 2 * 2                                            # das Kästchen\n  s0 = s / 2 * 2\n  kaestchen = [gitter[z0][s0], gitter[z0][s0 + 1],\n               gitter[z0 + 1][s0], gitter[z0 + 1][s0 + 1]]\n  !kaestchen.include?(zahl)\nend\n\ndef sudoku_loesen(gitter)\n  z = gitter.index { |zeile| zeile.include?(0) }\n  return gitter unless z\n  s = gitter[z].index(0)\n  (1..4).each do |zahl|\n    next unless erlaubt?(gitter, z, s, zahl)\n    gitter[z][s] = zahl\n    return gitter if sudoku_loesen(gitter)\n    gitter[z][s] = 0\n  end\n  nil\nend\n\nsudoku_loesen(raetsel)",
             "raetsel = [\n  [0, 0, 0, 3],\n  [0, 4, 0, 0],\n  [0, 0, 3, 0],\n  [2, 0, 0, 0]\n]\n\ndef erlaubt?(gitter, z, s, zahl)\n  return false if gitter[z].include?(zahl)                  # die Zeile\n  return false if gitter.any? { |zeile| zeile[s] == zahl }  # die Spalte\n  z0 = z / 2 * 2                                            # das Kästchen\n  s0 = s / 2 * 2\n  kaestchen = [gitter[z0][s0], gitter[z0][s0 + 1],\n               gitter[z0 + 1][s0], gitter[z0 + 1][s0 + 1]]\n  !kaestchen.include?(zahl)\nend\n\ndef sudoku_loesen(gitter)\n  (0..3).each do |z|\n    (0..3).each do |s|\n      next unless gitter[z][s] == 0\n      (1..4).each do |zahl|\n        next unless erlaubt?(gitter, z, s, zahl)\n        gitter[z][s] = zahl\n        return gitter if sudoku_loesen(gitter)\n      end\n      gitter[z][s] = 0\n      return nil\n    end\n  end\n  gitter\nend\nsudoku_loesen(raetsel).each { |zeile| puts zeile.join(\" \") }"],
    "en" => ["puzzle = [\n  [0, 0, 0, 3],\n  [0, 4, 0, 0],\n  [0, 0, 3, 0],\n  [2, 0, 0, 0]\n]\n\ndef allowed?(grid, r, c, n)\n  return false if grid[r].include?(n)                # the row\n  return false if grid.any? { |row| row[c] == n }    # the column\n  r0 = r / 2 * 2                                     # the 2×2 box\n  c0 = c / 2 * 2\n  box = [grid[r0][c0], grid[r0][c0 + 1],\n         grid[r0 + 1][c0], grid[r0 + 1][c0 + 1]]\n  !box.include?(n)\nend\n\ndef solve_sudoku(grid)\n  r = grid.index { |row| row.include?(0) }\n  return grid unless r\n  c = grid[r].index(0)\n  (1..4).each do |n|\n    next unless allowed?(grid, r, c, n)\n    grid[r][c] = n\n    return grid if solve_sudoku(grid)\n    grid[r][c] = 0\n  end\n  nil\nend\n\nsolve_sudoku(puzzle)",
             "puzzle = [\n  [0, 0, 0, 3],\n  [0, 4, 0, 0],\n  [0, 0, 3, 0],\n  [2, 0, 0, 0]\n]\n\ndef allowed?(grid, r, c, n)\n  return false if grid[r].include?(n)                # the row\n  return false if grid.any? { |row| row[c] == n }    # the column\n  r0 = r / 2 * 2                                     # the 2×2 box\n  c0 = c / 2 * 2\n  box = [grid[r0][c0], grid[r0][c0 + 1],\n         grid[r0 + 1][c0], grid[r0 + 1][c0 + 1]]\n  !box.include?(n)\nend\n\ndef solve_sudoku(grid)\n  (0..3).each do |r|\n    (0..3).each do |c|\n      next unless grid[r][c] == 0\n      (1..4).each do |n|\n        next unless allowed?(grid, r, c, n)\n        grid[r][c] = n\n        return grid if solve_sudoku(grid)\n      end\n      grid[r][c] = 0\n      return nil\n    end\n  end\n  grid\nend\nsolve_sudoku(puzzle).each { |row| puts row.join(\" \") }"]
  },
  "stapel#bonus" => {
    "de" => ["def upn(text)\n  stapel = []\n  text.split.each do |teil|\n    if %w[+ - * /].include?(teil)\n      rechts = stapel.pop\n      links = stapel.pop\n      stapel.push(case teil\n                  when \"+\" then links + rechts\n                  when \"-\" then links - rechts\n                  when \"*\" then links * rechts\n                  else links / rechts\n                  end)\n    else\n      stapel.push(teil.to_i)\n    end\n  end\n  stapel.last\nend\n\nupn(\"3 4 + 2 *\")",
             "def upn(text)\n  stapel = []\n  text.split.each do |teil|\n    if teil.match?(/\\A\\d+\\z/)\n      stapel.push(teil.to_i)\n    else\n      rechts, links = stapel.pop, stapel.pop\n      stapel.push(links.send(teil, rechts))\n    end\n  end\n  stapel.pop\nend\np upn(\"3 4 + 2 *\")"],
    "en" => ["def rpn(text)\n  stack = []\n  text.split.each do |part|\n    if %w[+ - * /].include?(part)\n      right = stack.pop\n      left = stack.pop\n      stack.push(case part\n                 when \"+\" then left + right\n                 when \"-\" then left - right\n                 when \"*\" then left * right\n                 else left / right\n                 end)\n    else\n      stack.push(part.to_i)\n    end\n  end\n  stack.last\nend\n\nrpn(\"3 4 + 2 *\")",
             "def rpn(text)\n  stack = []\n  text.split.each do |part|\n    if part.match?(/\\A\\d+\\z/)\n      stack.push(part.to_i)\n    else\n      right, left = stack.pop, stack.pop\n      stack.push(left.send(part, right))\n    end\n  end\n  stack.pop\nend\np rpn(\"3 4 + 2 *\")"]
  },
  "labyrinth#bonus" => {
    "de" => ["def speckspur(labyrinth)\n  start = finde(labyrinth, \"S\")\n  abstand = { start => 0 }\n  schlange = [start]\n  until schlange.empty?\n    zelle = schlange.shift\n    freie_nachbarn(labyrinth, zelle).each do |n|\n      next if abstand.key?(n)\n      abstand[n] = abstand[zelle] + 1\n      schlange.push(n)\n    end\n  end\n  zelle = finde(labyrinth, \"Z\")\n  return nil unless abstand[zelle]\n  bild = labyrinth.map(&:dup)\n  while abstand[zelle] > 0\n    ring = abstand[zelle] - 1\n    zelle = freie_nachbarn(labyrinth, zelle).find { |n| abstand[n] == ring }\n    z, s = zelle\n    bild[z][s] = \"*\" if bild[z][s] == \".\"\n  end\n  bild\nend\n\nputs speckspur(labyrinth)",
             "def speckspur(labyrinth)\n  start = finde(labyrinth, \"S\")\n  kam_von = { start => nil }\n  schlange = [start]\n  until schlange.empty?\n    zelle = schlange.shift\n    freie_nachbarn(labyrinth, zelle).each do |n|\n      next if kam_von.key?(n)\n      kam_von[n] = zelle\n      schlange << n\n    end\n  end\n  ziel = finde(labyrinth, \"Z\")\n  return nil unless kam_von.key?(ziel)\n  bild = labyrinth.map(&:dup)\n  zelle = kam_von[ziel]\n  while zelle != start\n    bild[zelle[0]][zelle[1]] = \"*\"\n    zelle = kam_von[zelle]\n  end\n  bild\nend\np speckspur([\"S..\", \"#.#\", \"..Z\"])"],
    "en" => ["def bacon_trail(maze)\n  start = locate(maze, \"S\")\n  dist = { start => 0 }\n  queue = [start]\n  until queue.empty?\n    cell = queue.shift\n    open_neighbours(maze, cell).each do |n|\n      next if dist.key?(n)\n      dist[n] = dist[cell] + 1\n      queue.push(n)\n    end\n  end\n  cell = locate(maze, \"G\")\n  return nil unless dist[cell]\n  picture = maze.map(&:dup)\n  while dist[cell] > 0\n    ring = dist[cell] - 1\n    cell = open_neighbours(maze, cell).find { |n| dist[n] == ring }\n    r, c = cell\n    picture[r][c] = \"*\" if picture[r][c] == \".\"\n  end\n  picture\nend\n\nputs bacon_trail(maze)",
             "def bacon_trail(maze)\n  start = locate(maze, \"S\")\n  came_from = { start => nil }\n  queue = [start]\n  until queue.empty?\n    cell = queue.shift\n    open_neighbours(maze, cell).each do |n|\n      next if came_from.key?(n)\n      came_from[n] = cell\n      queue << n\n    end\n  end\n  goal = locate(maze, \"G\")\n  return nil unless came_from.key?(goal)\n  picture = maze.map(&:dup)\n  cell = came_from[goal]\n  while cell != start\n    picture[cell[0]][cell[1]] = \"*\"\n    cell = came_from[cell]\n  end\n  picture\nend\np bacon_trail([\"S..\", \"#.#\", \"..G\"])"]
  },
  "aehnlich#bonus" => {
    "de" => ["def tippfehler_abstand(a, b)\n  tabelle = [(0..b.length).to_a]\n  1.upto(a.length) do |i|\n    zeile = [i]\n    1.upto(b.length) do |j|\n      kosten = a[i - 1] == b[j - 1] ? 0 : 1\n      oben = tabelle[i - 1][j] + 1\n      links = zeile[j - 1] + 1\n      schraeg = tabelle[i - 1][j - 1] + kosten\n      bestes = [oben, links, schraeg].min\n      tausch = i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]\n      bestes = [bestes, tabelle[i - 2][j - 2] + 1].min if tausch\n      zeile << bestes\n    end\n    tabelle << zeile\n  end\n  tabelle.last.last\nend\n\ntippfehler_abstand(\"Sepck\", \"Speck\")",
             "def tippfehler_abstand(a, b, memo = {})\n  return b.length if a.empty?\n  return a.length if b.empty?\n  memo[[a, b]] ||=\n    if a[0] == b[0]\n      tippfehler_abstand(a[1..], b[1..], memo)\n    else\n      moeglich = [tippfehler_abstand(a[1..], b, memo),\n                  tippfehler_abstand(a, b[1..], memo),\n                  tippfehler_abstand(a[1..], b[1..], memo)]\n      if a[0] == b[1] && a[1] == b[0]\n        moeglich << tippfehler_abstand(a[2..], b[2..], memo)\n      end\n      1 + moeglich.min\n    end\nend\np tippfehler_abstand(\"Fcuhs\", \"Fuchs\")"],
    "en" => ["def typo_distance(a, b)\n  table = [(0..b.length).to_a]\n  1.upto(a.length) do |i|\n    row = [i]\n    1.upto(b.length) do |j|\n      cost = a[i - 1] == b[j - 1] ? 0 : 1\n      above = table[i - 1][j] + 1\n      left = row[j - 1] + 1\n      diagonal = table[i - 1][j - 1] + cost\n      best = [above, left, diagonal].min\n      swap = i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]\n      best = [best, table[i - 2][j - 2] + 1].min if swap\n      row << best\n    end\n    table << row\n  end\n  table.last.last\nend\n\ntypo_distance(\"bcaon\", \"bacon\")",
             "def typo_distance(a, b, memo = {})\n  return b.length if a.empty?\n  return a.length if b.empty?\n  memo[[a, b]] ||=\n    if a[0] == b[0]\n      typo_distance(a[1..], b[1..], memo)\n    else\n      options = [typo_distance(a[1..], b, memo),\n                 typo_distance(a, b[1..], memo),\n                 typo_distance(a[1..], b[1..], memo)]\n      if a[0] == b[1] && a[1] == b[0]\n        options << typo_distance(a[2..], b[2..], memo)\n      end\n      1 + options.min\n    end\nend\np typo_distance(\"chnuky\", \"chunky\")"]
  },
  "lebensspiel#bonus" => {
    "de" => ["def naechste_generation_rund(gitter)\n  zeilen = gitter.length\n  spalten = gitter[0].length\n  versatz = [-1, 0, 1].product([-1, 0, 1]) - [[0, 0]]\n  zeilen.times.map do |z|\n    spalten.times.map do |s|\n      n = versatz.count do |dz, ds|\n        gitter[(z + dz) % zeilen][(s + ds) % spalten] == \"#\"\n      end\n      lebt = gitter[z][s] == \"#\"\n      n == 3 || (lebt && n == 2) ? \"#\" : \".\"\n    end.join\n  end\nend\n\nputs naechste_generation_rund(%w[....# ....# ....# ..... .....])",
             "def naechste_generation_rund(gitter)\n  h = gitter.size\n  b = gitter.first.size\n  gitter.each_index.map do |z|\n    (0...b).map do |s|\n      n = 0\n      [-1, 0, 1].each do |dz|\n        [-1, 0, 1].each do |ds|\n          next if dz.zero? && ds.zero?\n          n += 1 if gitter[(z + dz) % h][(s + ds) % b] == \"#\"\n        end\n      end\n      n == 3 || (n == 2 && gitter[z][s] == \"#\") ? \"#\" : \".\"\n    end.join\n  end\nend\np naechste_generation_rund([\"#...#\", \".....\", \".....\", \".....\", \"#...#\"])"],
    "en" => ["def next_generation_wrapped(grid)\n  rows = grid.length\n  cols = grid[0].length\n  offsets = [-1, 0, 1].product([-1, 0, 1]) - [[0, 0]]\n  rows.times.map do |r|\n    cols.times.map do |c|\n      n = offsets.count do |dr, dc|\n        grid[(r + dr) % rows][(c + dc) % cols] == \"#\"\n      end\n      alive = grid[r][c] == \"#\"\n      n == 3 || (alive && n == 2) ? \"#\" : \".\"\n    end.join\n  end\nend\n\nputs next_generation_wrapped(%w[....# ....# ....# ..... .....])",
             "def next_generation_wrapped(grid)\n  h = grid.size\n  w = grid.first.size\n  grid.each_index.map do |r|\n    (0...w).map do |c|\n      n = 0\n      [-1, 0, 1].each do |dr|\n        [-1, 0, 1].each do |dc|\n          next if dr.zero? && dc.zero?\n          n += 1 if grid[(r + dr) % h][(c + dc) % w] == \"#\"\n        end\n      end\n      n == 3 || (n == 2 && grid[r][c] == \"#\") ? \"#\" : \".\"\n    end.join\n  end\nend\np next_generation_wrapped([\"#...#\", \".....\", \".....\", \".....\", \"#...#\"])"]
  },
  "markov#bonus" => {
    "de" => ["def plappern(tabelle, start, n, wuerfel)\n  woerter = [start]\n  while woerter.length < n\n    nachfolger = tabelle.fetch(woerter.last, [])\n    break if nachfolger.empty?\n    woerter << nachfolger.sample(random: wuerfel)\n  end\n  woerter.join(\" \")\nend\n\nplappern(tabelle, \"der\", 12, Random.new(24))",
             "def plappern(tabelle, start, n, wuerfel)\n  wort = start\n  text = [wort]\n  (n - 1).times do\n    wort = (tabelle[wort] || []).sample(random: wuerfel)\n    break unless wort\n    text << wort\n  end\n  text.join(\" \")\nend\np plappern({ \"knuspriger\" => [\"speck\"], \"speck\" => [\"knuspriger\"] }, \"knuspriger\", 4, Random.new(1))"],
    "en" => ["def babble(table, start, n, random)\n  words = [start]\n  while words.length < n\n    followers = table.fetch(words.last, [])\n    break if followers.empty?\n    words << followers.sample(random: random)\n  end\n  words.join(\" \")\nend\n\nbabble(table, \"the\", 12, Random.new(24))",
             "def babble(table, start, n, random)\n  word = start\n  out = [word]\n  (n - 1).times do\n    word = (table[word] || []).sample(random: random)\n    break unless word\n    out << word\n  end\n  out.join(\" \")\nend\np babble({ \"chunky\" => [\"bacon\"], \"bacon\" => [\"chunky\"] }, \"chunky\", 4, Random.new(1))"]
  },
  "operatoren#bonus" => {
    "de" => ["class Versionsnummer\n  include Comparable\n\n  def initialize(text)\n    @text = text\n  end\n\n  def to_s\n    @text\n  end\n\n  def teile\n    @text.split(\".\").map(&:to_i)\n  end\n\n  def <=>(other)\n    teile <=> other.teile\n  end\nend\n\nVersionsnummer.new(\"1.10.0\") > Versionsnummer.new(\"1.9.2\")",
             "class Versionsnummer\n  include Comparable\n  attr_reader :teile\n\n  def initialize(text)\n    @text = text\n    @teile = text.split(\".\").map { |t| Integer(t) }\n  end\n\n  def to_s = @text\n\n  def <=>(andere)\n    teile <=> andere.teile\n  end\nend\n\np [Versionsnummer.new(\"1.10.0\"), Versionsnummer.new(\"1.9.2\")].max.to_s"],
    "en" => ["class VersionNumber\n  include Comparable\n\n  def initialize(text)\n    @text = text\n  end\n\n  def to_s\n    @text\n  end\n\n  def parts\n    @text.split(\".\").map(&:to_i)\n  end\n\n  def <=>(other)\n    parts <=> other.parts\n  end\nend\n\nVersionNumber.new(\"1.10.0\") > VersionNumber.new(\"1.9.2\")",
             "class VersionNumber\n  include Comparable\n  attr_reader :parts\n\n  def initialize(text)\n    @text = text\n    @parts = text.split(\".\").map { |t| Integer(t) }\n  end\n\n  def to_s = @text\n\n  def <=>(another)\n    parts <=> another.parts\n  end\nend\n\np [VersionNumber.new(\"1.10.0\"), VersionNumber.new(\"1.9.2\")].max.to_s"]
  },
  "fehler" => {
    "de" => [%(fuchs = { name: "Chunky", streifen: 3 }\n\ndef satz(tier)\n  "\#{tier[:name]} isst \#{tier[:streifen]} Streifen Speck."\nend\n\nsatz(fuchs)),
             %(fuchs = { name: "Chunky", streifen: 3 }\n\ndef satz(tier)\n  "\#{tier[:name]} isst " + tier[:streifen].to_s + " Streifen Speck."\nend\n\nputs satz(fuchs))],
    "en" => [%(fox = { name: "Chunky", strips: 3 }\n\ndef sentence(animal)\n  "\#{animal[:name]} eats \#{animal[:strips]} strips of bacon."\nend\n\nsentence(fox)),
             %(fox = { name: "Chunky", strips: 3 }\n\ndef sentence(animal)\n  "\#{animal[:name]} eats " + animal[:strips].to_s + " strips of bacon."\nend\n\nputs sentence(fox))]
  },
  "vererbung" => {
    "de" => [%(class Waldtier\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def laut\n    "..."\n  end\n  def vorstellen\n    "Ich bin \#{name} und sage \#{laut}"\n  end\nend\n\nclass Rotfuchs < Waldtier\n  def laut\n    "Chunky Bacon!"\n  end\nend\n\nRotfuchs.new("Chunky").vorstellen)],
    "en" => [%(class ForestAnimal\n  attr_reader :name\n  def initialize(name)\n    @name = name\n  end\n  def sound\n    "..."\n  end\n  def introduce\n    "I am \#{name} and I say \#{sound}"\n  end\nend\n\nclass RedFox < ForestAnimal\n  def sound\n    "Chunky Bacon!"\n  end\nend\n\nRedFox.new("Chunky").introduce)]
  },
  "doku" => {
    "de" => [%(quersumme = 2026.digits.sum\npaare = [1, 2, 3, 4, 5, 6].each_slice(2).to_a)],
    "en" => [%(digit_sum = 2026.digits.sum\npairs = [1, 2, 3, 4, 5, 6].each_slice(2).to_a)]
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
  "spinel" => {
    "de" => [
      %(def collatz(n)
  schritte = 0
  while n != 1
    n = n.even? ? n / 2 : 3 * n + 1
    schritte += 1
  end
  schritte
end

puts collatz(27)),
      %(def collatz(n)
  return 0 if n == 1

  1 + collatz(n.even? ? n / 2 : 3 * n + 1)
end

puts collatz(27))
    ],
    "en" => [
      %(def collatz(n)
  steps = 0
  until n == 1
    n = n.even? ? n / 2 : 3 * n + 1
    steps += 1
  end
  steps
end

puts collatz(27))
    ]
  },
  "qr-rechnung" => {
    "de" => [%(install_gem "qr-bills"
install_gem "swiss_qr"
install_gem "qr_reader"
require "qr-bills"
require "swiss_qr"

fuchs = QRBills.get_qr_params
fuchs[:bill_type] = QRBills.get_qrbill_without_reference_type
fuchs[:output_params][:format] = "qrcode"
fuchs[:qrcode_format] = "png"
glace = fuchs[:bill_params]
glace[:amount] = 12.30
glace[:reference_type] = "NON"
glace[:creditor][:iban] = "CH58 0079 1123 0008 8901 2"
glace[:creditor][:address].merge!(name: "Glace Fuchs", street_name: "Seeweg", building_number: "3",
                                  postal_code: "8000", town: "Seldwyla", country: "CH")
glace[:debtor][:address].merge!(name: "Kaz Muster", street_name: "Bahnhofstrasse", building_number: "2",
                                postal_code: "8000", town: "Seldwyla", country: "CH")
bild = QRBills.generate(fuchs)[:output]
show_image bild
SwissQr.read(bild))],
    "en" => [%(install_gem "qr-bills"
install_gem "swiss_qr"
install_gem "qr_reader"
require "qr-bills"
require "swiss_qr"

fox = QRBills.get_qr_params
fox[:bill_type] = QRBills.get_qrbill_without_reference_type
fox[:output_params][:format] = "qrcode"
fox[:qrcode_format] = "png"
ice = fox[:bill_params]
ice[:amount] = 12.30
ice[:reference_type] = "NON"
ice[:creditor][:iban] = "CH58 0079 1123 0008 8901 2"
ice[:creditor][:address].merge!(name: "Glace Fuchs", street_name: "Seeweg", building_number: "3",
                                postal_code: "8000", town: "Seldwyla", country: "CH")
ice[:debtor][:address].merge!(name: "Kaz Muster", street_name: "Bahnhofstrasse", building_number: "2",
                              postal_code: "8000", town: "Seldwyla", country: "CH")
png = QRBills.generate(fox)[:output]
show_image png
read = SwissQr.read(StringIO.new(png.to_blob))
puts read.formatted_iban
puts read.amount)]
  },
  # the ruby2d window (ruby2d.rb): the check replays the cell and holds the
  # arrow keys on that copy until Chunky reaches both edges
  # the Pico lessons (test/pico_harness.rb runs them on the simulator)
  "pico-blink" => {
    "de" => [
      <<~'SOL',
      require "gpio"

      blinklicht = GPIO.new(15, GPIO::OUT)
      5.times do
        blinklicht.write(1)
        sleep_ms 200
        blinklicht.write(0)
        sleep_ms 300
      end
      SOL
      <<~'SOL'
      require "gpio"

      blinklicht = GPIO.new(15, GPIO::OUT)
      zaehler = 0
      while zaehler < 5
        blinklicht.write(1)
        sleep_ms 200
        blinklicht.write(0)
        sleep_ms 300
        zaehler += 1
      end
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "gpio"

      signal = GPIO.new(15, GPIO::OUT)
      5.times do
        signal.write(1)
        sleep_ms 200
        signal.write(0)
        sleep_ms 300
      end
      SOL
      <<~'SOL'
      require "gpio"

      signal = GPIO.new(15, GPIO::OUT)
      count = 0
      while count < 5
        signal.write(1)
        sleep_ms 200
        signal.write(0)
        sleep_ms 300
        count += 1
      end
      SOL
    ]
  },
  "pico-sensors" => {
    "de" => [
      <<~'SOL',
      require "gpio"
      require "adc"

      nachtlicht = GPIO.new(15, GPIO::OUT)
      fuehler = ADC.new(26)
      20.times do
        if fuehler.read_voltage < 1.0
          nachtlicht.write(1)
        else
          nachtlicht.write(0)
        end
        sleep_ms 100
      end
      SOL
      <<~'SOL'
      require "gpio"
      require "adc"

      nachtlicht = GPIO.new(15, GPIO::OUT)
      fuehler = ADC.new(26)
      20.times do
        nachtlicht.write(fuehler.read < 1.0 ? 1 : 0)
        sleep_ms 100
      end
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "gpio"
      require "adc"

      night_light = GPIO.new(15, GPIO::OUT)
      sensor = ADC.new(26)
      20.times do
        if sensor.read_voltage < 1.0
          night_light.write(1)
        else
          night_light.write(0)
        end
        sleep_ms 100
      end
      SOL
      <<~'SOL'
      require "gpio"
      require "adc"

      night_light = GPIO.new(15, GPIO::OUT)
      sensor = ADC.new(26)
      20.times do
        night_light.write(sensor.read < 1.0 ? 1 : 0)
        sleep_ms 100
      end
      SOL
    ]
  },
  "pico-robot" => {
    "de" => [
      <<~'SOL',
      require "gpio"
      require "picogo"

      flitzer = PicoGo.new
      ir_links = GPIO.new(3, GPIO::IN)
      ir_rechts = GPIO.new(2, GPIO::IN)
      flitzer.forward(40)
      sleep_ms 10 until ir_links.low? || ir_rechts.low?
      flitzer.stop
      SOL
      <<~'SOL'
      require "gpio"
      require "picogo"

      flitzer = PicoGo.new
      ir_links = GPIO.new(3, GPIO::IN)
      ir_rechts = GPIO.new(2, GPIO::IN)
      flitzer.forward(40)
      while ir_links.read == 1 && ir_rechts.read == 1
        sleep_ms 5
      end
      flitzer.stop
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "gpio"
      require "picogo"

      rover = PicoGo.new
      ir_left = GPIO.new(3, GPIO::IN)
      ir_right = GPIO.new(2, GPIO::IN)
      rover.forward(40)
      sleep_ms 10 until ir_left.low? || ir_right.low?
      rover.stop
      SOL
      <<~'SOL'
      require "gpio"
      require "picogo"

      rover = PicoGo.new
      ir_left = GPIO.new(3, GPIO::IN)
      ir_right = GPIO.new(2, GPIO::IN)
      rover.forward(40)
      while ir_left.read == 1 && ir_right.read == 1
        sleep_ms 5
      end
      rover.stop
      SOL
    ]
  },
  "pico-epaper" => {
    "de" => [
      <<~'SOL',
      require "spi"
      require "epd2in13"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      schild = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                            rst_pin: 12, busy_pin: 13)
      schild.clear
      schild.rect(0, 0, 250, 122)
      schild.text(20, 45, "Chunky Bacon", scale: 3)
      schild.refresh
      SOL
      <<~'SOL'
      require "spi"
      require "epd2in13"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      schild = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                            rst_pin: 12, busy_pin: 13)
      schild.clear
      4.times { |i| schild.rect(i, i, 250 - 2 * i, 122 - 2 * i) }
      schild.text(30, 50, "Fuchs", scale: 2)
      schild.refresh(partial: false)
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "spi"
      require "epd2in13"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      badge = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                           rst_pin: 12, busy_pin: 13)
      badge.clear
      badge.rect(0, 0, 250, 122)
      badge.text(20, 45, "Chunky Bacon", scale: 3)
      badge.refresh
      SOL
      <<~'SOL'
      require "spi"
      require "epd2in13"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      badge = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                           rst_pin: 12, busy_pin: 13)
      badge.clear
      badge.line(0, 0, 249, 0)
      badge.line(0, 121, 249, 121)
      badge.line(0, 0, 0, 121)
      badge.line(249, 0, 249, 121)
      badge.text(80, 40, "Why", scale: 4)
      badge.refresh
      SOL
    ]
  },
  "pico-lcd" => {
    "de" => [
      <<~'SOL',
      require "spi"
      require "gpio"
      require "st7789"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000,
                    sck_pin: 10, copi_pin: 11)
      lcd = ST7789.new(spi: spi)
      lcd.fill(ST7789::BLACK)
      taste_a = GPIO.new(15, GPIO::IN | GPIO::PULL_UP)
      zaehler = 0
      vorher = false
      lcd.text("0", 100, 50, ST7789::YELLOW, scale: 4)
      100.times do
        jetzt = taste_a.low?
        if jetzt && !vorher
          zaehler += 1
          lcd.text(zaehler.to_s, 100, 50, ST7789::YELLOW, scale: 4)
        end
        vorher = jetzt
        sleep_ms 20
      end
      SOL
      <<~'SOL'
      require "spi"
      require "gpio"
      require "st7789"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000,
                    sck_pin: 10, copi_pin: 11)
      lcd = ST7789.new(spi: spi)
      lcd.fill(ST7789::BLACK)
      taste_a = GPIO.new(15, GPIO::IN | GPIO::PULL_UP)
      zaehler = 0
      oben = true
      100.times do
        if taste_a.low? && oben
          zaehler += 1
          lcd.fill(ST7789::BLACK)
          lcd.text("Zahl: #{zaehler}", 20, 50, ST7789::GREEN, scale: 3)
        end
        oben = taste_a.high?
        sleep_ms 20
      end
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "spi"
      require "gpio"
      require "st7789"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000,
                    sck_pin: 10, copi_pin: 11)
      lcd = ST7789.new(spi: spi)
      lcd.fill(ST7789::BLACK)
      key_a = GPIO.new(15, GPIO::IN | GPIO::PULL_UP)
      count = 0
      was = false
      lcd.text("0", 100, 50, ST7789::YELLOW, scale: 4)
      100.times do
        now = key_a.low?
        if now && !was
          count += 1
          lcd.text(count.to_s, 100, 50, ST7789::YELLOW, scale: 4)
        end
        was = now
        sleep_ms 20
      end
      SOL
      <<~'SOL'
      require "spi"
      require "gpio"
      require "st7789"

      spi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000,
                    sck_pin: 10, copi_pin: 11)
      lcd = ST7789.new(spi: spi)
      lcd.fill(ST7789::BLACK)
      key_a = GPIO.new(15, GPIO::IN | GPIO::PULL_UP)
      count = 0
      up = true
      100.times do
        if key_a.low? && up
          count += 1
          lcd.fill(ST7789::BLACK)
          lcd.text("Count: #{count}", 20, 50, ST7789::GREEN, scale: 3)
        end
        up = key_a.high?
        sleep_ms 20
      end
      SOL
    ],
  },
  "pico-wifi" => {
    "de" => [
      <<~'SOL',
      require "cyw43"
      require "net/http"
      require "json"
      require "spi"
      require "epd2in13"

      CYW43.init("CH")
      CYW43.enable_sta_mode
      CYW43.connect_timeout("chunkynet", "chunkybacon",
                            CYW43::Auth::WPA2_AES_PSK, 10)
      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      papier = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                            rst_pin: 12, busy_pin: 13)
      papier.clear
      antwort = Net::HTTP.get("https://rubygems.org", "/api/v1/gems/rake.json")
      version = JSON.parse(antwort)["version"]
      papier.text(10, 50, "rake #{version}", scale: 2)
      papier.refresh
      SOL
      <<~'SOL'
      require "cyw43"
      require "net/http"
      require "json"
      require "spi"
      require "epd2in13"

      CYW43.init("CH")
      CYW43.enable_sta_mode
      CYW43.connect_timeout("chunkynet", "chunkybacon",
                            CYW43::Auth::WPA2_AES_PSK, 10)
      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      papier = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                            rst_pin: 12, busy_pin: 13)
      papier.clear
      http = Net::HTTP.new("rubygems.org", 443)
      http.use_ssl = true
      antwort = http.get("/api/v1/gems/rake.json")
      http.finish
      gem_info = JSON.parse(antwort.body)
      papier.text(8, 40, "rake " + gem_info["version"], scale: 3)
      papier.refresh
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "cyw43"
      require "net/http"
      require "json"
      require "spi"
      require "epd2in13"

      CYW43.init("CH")
      CYW43.enable_sta_mode
      CYW43.connect_timeout("chunkynet", "chunkybacon",
                            CYW43::Auth::WPA2_AES_PSK, 10)
      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      paper = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                           rst_pin: 12, busy_pin: 13)
      paper.clear
      body = Net::HTTP.get("https://rubygems.org", "/api/v1/gems/rake.json")
      version = JSON.parse(body)["version"]
      paper.text(10, 50, "rake #{version}", scale: 2)
      paper.refresh
      SOL
      <<~'SOL'
      require "cyw43"
      require "net/http"
      require "json"
      require "spi"
      require "epd2in13"

      CYW43.init("CH")
      CYW43.enable_sta_mode
      CYW43.connect_timeout("chunkynet", "chunkybacon",
                            CYW43::Auth::WPA2_AES_PSK, 10)
      spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000,
                    sck_pin: 10, copi_pin: 11)
      paper = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8,
                           rst_pin: 12, busy_pin: 13)
      paper.clear
      http = Net::HTTP.new("rubygems.org", 443)
      http.use_ssl = true
      res = http.get("/api/v1/gems/rake.json")
      http.finish
      info = JSON.parse(res.body)
      paper.rect(0, 0, 250, 122)
      paper.text(8, 8, "Gem watcher")
      paper.text(8, 40, "#{info["name"]} #{info["version"]}", scale: 3)
      paper.refresh
      SOL
    ]
  },
  "pico-ble" => {
    "de" => [
      <<~'SOL',
      require "ble"
      require "adc"

      verbindung = BLE::UART.new(name: "ChunkyPico")
      chip = ADC.new(:temperature)
      verbindung.start(1500) do
        nachricht = verbindung.gets_nonblock
        if nachricht
          case nachricht.chomp
          when "PING" then verbindung.puts "PONG"
          when "TEMP"
            grad = 27 - (chip.read - 0.706) / 0.001721
            verbindung.puts "#{(grad * 10).to_i / 10.0} °C"
          end
        end
      end
      SOL
      <<~'SOL'
      require "ble"
      require "adc"

      verbindung = BLE::UART.new(name: "ChunkyPico")
      chip = ADC.new(:temperature)
      verbindung.start(1500) do
        nachricht = verbindung.gets_nonblock
        next unless nachricht

        if nachricht.chomp == "PING"
          verbindung.puts "PONG"
        elsif nachricht.chomp == "TEMP"
          verbindung.puts((27 - (chip.read - 0.706) / 0.001721).to_s)
        end
      end
      SOL
    ],
    "en" => [
      <<~'SOL',
      require "ble"
      require "adc"

      link = BLE::UART.new(name: "ChunkyPico")
      chip = ADC.new(:temperature)
      link.start(1500) do
        message = link.gets_nonblock
        if message
          case message.chomp
          when "PING" then link.puts "PONG"
          when "TEMP"
            celsius = 27 - (chip.read - 0.706) / 0.001721
            link.puts "#{(celsius * 10).to_i / 10.0} °C"
          end
        end
      end
      SOL
      <<~'SOL'
      require "ble"
      require "adc"

      link = BLE::UART.new(name: "ChunkyPico")
      chip = ADC.new(:temperature)
      link.start(1500) do
        message = link.gets_nonblock
        next unless message

        if message.chomp == "PING"
          link.puts "PONG"
        elsif message.chomp == "TEMP"
          link.puts((27 - (chip.read - 0.706) / 0.001721).to_s)
        end
      end
      SOL
    ]
  },
  "pico-deploy" => {
    "de" => [
      <<~'SOL',
      def lauf_status(zeilen)
        stand = :waiting
        zeilen.each do |zeile|
          if zeile == "DONE"
            stand = :done
          elsif zeile.start_with?("ERROR ")
            stand = "error: #{zeile[6..-1]}"
          elsif zeile == "RUNNING"
            stand = :running
          end
        end
        stand
      end

      bereit = "READY prremote-runtime/0.4.2 board=picow"
      [lauf_status([bereit, "RUNNING", "hello", "DONE"]),
       lauf_status([bereit, "RUNNING", "ERROR NoMethodError"]),
       lauf_status([bereit, "RUNNING", "tick"]),
       lauf_status([bereit])]
      SOL
      <<~'SOL'
      def lauf_status(zeilen)
        return :done if zeilen.include?("DONE")

        fehler = zeilen.find { |zeile| zeile.start_with?("ERROR") }
        return "error: " + fehler.split(" ", 2)[1] if fehler
        return :running if zeilen.include?("RUNNING")

        :waiting
      end

      bereit = "READY prremote-runtime/0.4.2 board=picow"
      [lauf_status([bereit, "RUNNING", "hello", "DONE"]),
       lauf_status([bereit, "RUNNING", "ERROR NoMethodError"]),
       lauf_status([bereit, "RUNNING", "tick"]),
       lauf_status([bereit])]
      SOL
    ],
    "en" => [
      <<~'SOL',
      def run_status(lines)
        status = :waiting
        lines.each do |line|
          if line == "DONE"
            status = :done
          elsif line.start_with?("ERROR ")
            status = "error: #{line[6..-1]}"
          elsif line == "RUNNING"
            status = :running
          end
        end
        status
      end

      ready = "READY prremote-runtime/0.4.2 board=picow"
      [run_status([ready, "RUNNING", "hello", "DONE"]),
       run_status([ready, "RUNNING", "ERROR NoMethodError"]),
       run_status([ready, "RUNNING", "tick"]),
       run_status([ready])]
      SOL
      <<~'SOL'
      def run_status(lines)
        return :done if lines.include?("DONE")

        error = lines.find { |line| line.start_with?("ERROR") }
        return "error: " + error.split(" ", 2)[1] if error
        return :running if lines.include?("RUNNING")

        :waiting
      end

      ready = "READY prremote-runtime/0.4.2 board=picow"
      [run_status([ready, "RUNNING", "hello", "DONE"]),
       run_status([ready, "RUNNING", "ERROR NoMethodError"]),
       run_status([ready, "RUNNING", "tick"]),
       run_status([ready])]
      SOL
    ]
  },
  # (end of the Pico lessons)
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
  # the JRuby lesson: count, select.size, and by hand with each
  "jruby" => {
    "de" => [%(require "json"

def staerke_beben(beben, staerke)
  beben.count { |q| q["properties"]["mag"].to_f >= staerke }
end

beben = JSON.parse(File.read("data/all_month.geojson"))["features"]
staerke_beben(beben, 5)),
             %(require "json"

def staerke_beben(beben, staerke)
  anzahl = 0
  beben.each do |q|
    mag = q["properties"]["mag"]
    anzahl += 1 if mag && mag >= staerke
  end
  anzahl
end

beben = JSON.parse(File.read("data/all_month.geojson"))["features"]
puts staerke_beben(beben, 5))],
    "en" => [%(require "json"

def strong_quakes(quakes, magnitude)
  quakes.count { |q| q["properties"]["mag"].to_f >= magnitude }
end

quakes = JSON.parse(File.read("data/all_month.geojson"))["features"]
strong_quakes(quakes, 5)),
             %(require "json"

def strong_quakes(quakes, magnitude)
  quakes.select { |q| q.dig("properties", "mag").to_f >= magnitude }.size
end

quakes = JSON.parse(File.read("data/all_month.geojson"))["features"]
puts strong_quakes(quakes, 5))]
  },
  # the IronRuby lesson: the same code in de and en (IRONRUBY_SOLUTIONS)
  "ironruby" => {
    "de" => IRONRUBY_SOLUTIONS,
    "en" => IRONRUBY_SOLUTIONS
  },
  # the Ruboto lesson: the count in the Bundle (getInt, or a String), or in
  # SharedPreferences, which outlive the activity too
  "ruboto" => {
    "de" => [ruboto_counter("@zahl", "hochzaehlen", "@anzeige", "Zähler",
                            read: "bundle ? bundle.getInt('zahl') : 0",
                            save: "out_state.putInt('zahl', @zahl)"),
             ruboto_counter("@zahl", "hochzaehlen", "@anzeige", "Zähler",
                            read: "bundle&.containsKey('zahl') ? bundle.getString('zahl').to_i : 0",
                            save: "out_state.putString('zahl', @zahl.to_s)"),
             ruboto_counter("@zahl", "hochzaehlen", "@anzeige", "Zähler",
                            read: "getPreferences(0).getInt('zahl', 0)",
                            save: "getPreferences(0).edit.putInt('zahl', @zahl).apply")],
    "en" => [ruboto_counter("@count", "count_up", "@label", "Counter",
                            read: "bundle ? bundle.getInt('count') : 0",
                            save: "out_state.putInt('count', @count)"),
             ruboto_counter("@count", "count_up", "@label", "Counter",
                            read: "bundle&.containsKey('count') ? bundle.getString('count').to_i : 0",
                            save: "out_state.putString('count', @count.to_s)"),
             ruboto_counter("@count", "count_up", "@label", "Counter",
                            read: "getPreferences(0).getInt('count', 0)",
                            save: "getPreferences(0).edit.putInt('count', @count).apply")]
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
  "tl-time" => {
    "de" => [%(require "time"

def dauer_in_stunden(datum, von, bis)
  anfang = Time.strptime("\#{datum} \#{von}", "%Y-%m-%d %H:%M")
  ende = Time.strptime("\#{datum} \#{bis}", "%Y-%m-%d %H:%M")
  ende += 24 * 3600 if ende < anfang
  (ende - anfang) / 3600
end

dauer_in_stunden("2026-09-15", "22:00", "01:30"))],
    "en" => [%(require "time"

def duration_in_hours(date, from, to)
  begins = Time.strptime("\#{date} \#{from}", "%Y-%m-%d %H:%M")
  ends = Time.strptime("\#{date} \#{to}", "%Y-%m-%d %H:%M")
  ends += 24 * 3600 if ends < begins
  (ends - begins) / 3600
end

duration_in_hours("2026-09-15", "22:00", "01:30"))]
  },
  "tl-objects" => {
    "de" => [%(class Stundenblatt
  def initialize
    @eintraege = []
  end

  def add(projekt, stunden)
    @eintraege << { projekt: projekt, stunden: stunden }
    self
  end

  def eintraege
    @eintraege.dup.freeze
  end
end

blatt = Stundenblatt.new.add("ProjectX", 3.5)
blatt.eintraege.frozen?), %(class Stundenblatt
  def initialize
    @eintraege = []
  end

  def add(projekt, stunden)
    @eintraege << { projekt: projekt, stunden: stunden }
    self
  end

  def eintraege
    @eintraege.map(&:dup).freeze
  end
end)],
    "en" => [%(class Logbook
  def initialize
    @entries = []
  end

  def add(project, hours)
    @entries << { project: project, hours: hours }
    self
  end

  def entries
    @entries.dup.freeze
  end
end

log = Logbook.new.add("ProjectX", 3.5)
log.entries.frozen?), %(class Logbook
  def initialize
    @entries = []
  end

  def add(project, hours)
    @entries << { project: project, hours: hours }
    self
  end

  def entries
    @entries.map(&:dup).freeze
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
  "daru" => {
    "de" => [%(install_gem "daru"\nrequire "daru"\nsnacks = Daru::DataFrame.new({ tag: ["Mo", "Mo", "Di", "Mi", "Mi", "Mi"], snack: ["Speck", "Beeren", "Speck", "Ei", "Speck", "Beeren"], gramm: [120, 80, 150, 60, 90, 40] })\npro_snack = snacks.group_by(:snack).sum[:gramm].to_h),
             %(require "daru"\nsnacks = Daru::DataFrame.new({ tag: ["Mo", "Mo", "Di", "Mi", "Mi", "Mi"], snack: ["Speck", "Beeren", "Speck", "Ei", "Speck", "Beeren"], gramm: [120, 80, 150, 60, 90, 40] })\npro_snack = snacks[:snack].to_a.zip(snacks[:gramm].to_a).group_by(&:first).transform_values { |paare| paare.sum(&:last) }\nputs pro_snack)],
    "en" => [%(install_gem "daru"\nrequire "daru"\nsnacks = Daru::DataFrame.new({ day: ["Mon", "Mon", "Tue", "Wed", "Wed", "Wed"], snack: ["bacon", "berries", "bacon", "egg", "bacon", "berries"], grams: [120, 80, 150, 60, 90, 40] })\nper_snack = snacks.group_by(:snack).sum[:grams].to_h),
             %(require "daru"\nsnacks = Daru::DataFrame.new({ day: ["Mon", "Mon", "Tue", "Wed", "Wed", "Wed"], snack: ["bacon", "berries", "bacon", "egg", "bacon", "berries"], grams: [120, 80, 150, 60, 90, 40] })\nper_snack = snacks.group_by(:snack).sum[:grams].to_h\nputs per_snack)]
  },
  "statistik" => {
    "de" => [%(install_gem "distribution"\nrequire "distribution"\nchance = 1 - Distribution::Binomial.cdf(4, 20, 1 / 6.0)),
             %(require "distribution"\nchance = (5..20).sum { |sechsen| Distribution::Binomial.pdf(sechsen, 20, 1 / 6.0) }\nputs chance)],
    "en" => [%(install_gem "distribution"\nrequire "distribution"\nchance = 1 - Distribution::Binomial.cdf(4, 20, 1 / 6.0)),
             %(require "distribution"\nchance = (5..20).sum { |sixes| Distribution::Binomial.pdf(sixes, 20, 1 / 6.0) }\nputs chance)]
  },
  "networkx" => {
    "de" => [%(install_gem "networkx"\nrequire "networkx"\nwald = NetworkX::Graph.new\n[["Fuchsbau", "Bach", 4], ["Fuchsbau", "Lichtung", 7], ["Bach", "Lichtung", 2], ["Bach", "Hühnerstall", 9], ["Lichtung", "Hühnerstall", 5]].each { |a, b, m| wald.add_edge(a, b, weight: m) }\nweg = NetworkX.dijkstra_path(wald, "Fuchsbau", "Hühnerstall")\nminuten = NetworkX.dijkstra_path_length(wald, "Fuchsbau", "Hühnerstall")),
             %(require "networkx"\nwald = NetworkX::Graph.new\nwald.add_edge("Fuchsbau", "Bach", weight: 4)\nwald.add_edge("Fuchsbau", "Lichtung", weight: 7)\nwald.add_edge("Bach", "Lichtung", weight: 2)\nwald.add_edge("Bach", "Hühnerstall", weight: 9)\nwald.add_edge("Lichtung", "Hühnerstall", weight: 5)\nweg = NetworkX.dijkstra_path(wald, "Fuchsbau", "Hühnerstall")\nminuten = NetworkX.dijkstra_path_length(wald, "Fuchsbau", "Hühnerstall")\nputs weg.join(" -> "))],
    "en" => [%(install_gem "networkx"\nrequire "networkx"\nwood = NetworkX::Graph.new\n[["den", "stream", 4], ["den", "clearing", 7], ["stream", "clearing", 2], ["stream", "henhouse", 9], ["clearing", "henhouse", 5]].each { |a, b, m| wood.add_edge(a, b, weight: m) }\npath = NetworkX.dijkstra_path(wood, "den", "henhouse")\nminutes = NetworkX.dijkstra_path_length(wood, "den", "henhouse")),
             %(require "networkx"\nwood = NetworkX::Graph.new\nwood.add_edge("den", "stream", weight: 4)\nwood.add_edge("den", "clearing", weight: 7)\nwood.add_edge("stream", "clearing", weight: 2)\nwood.add_edge("stream", "henhouse", weight: 9)\nwood.add_edge("clearing", "henhouse", weight: 5)\npath = NetworkX.dijkstra_path(wood, "den", "henhouse")\nminutes = NetworkX.dijkstra_path_length(wood, "den", "henhouse")\nputs path.join(" -> "))]
  },
  "ocran" => {
    "de" => [%(def rechnungspfad\n  File.join(programmordner, "rechnung.txt")\nend),
             %(def rechnungspfad\n  ordner = ENV["OCRAN_EXECUTABLE"] ? File.dirname(ENV["OCRAN_EXECUTABLE"]) : __dir__\n  File.join(ordner, "rechnung.txt")\nend\nputs rechnungspfad)],
    "en" => [%(def receipt_path\n  File.join(app_folder, "receipt.txt")\nend),
             %(def receipt_path\n  folder = ENV["OCRAN_EXECUTABLE"] ? File.dirname(ENV["OCRAN_EXECUTABLE"]) : __dir__\n  File.join(folder, "receipt.txt")\nend\nputs receipt_path)]
  },
  "roda" => {
    "de" => [%(install_gem "roda"\nrequire "roda"\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      "<h1>Kiosk</h1>"\n    end\n    r.get "bestellung", Integer do |anzahl|\n      "\#{anzahl} Streifen Speck, kommt sofort!"\n    end\n  end\nend\nshow_browser Kiosk, "/bestellung/5")],
    "en" => [%(install_gem "roda"\nrequire "roda"\nclass Kiosk < Roda\n  route do |r|\n    r.root do\n      "<h1>Kiosk</h1>"\n    end\n    r.get "order", Integer do |amount|\n      "\#{amount} strips of bacon, coming right up!"\n    end\n  end\nend\nshow_browser Kiosk, "/order/5")]
  },
  # the Rails app (Diner / Imbiss) boots in the lesson's first cell and is
  # one per process, like Rails.application: the exercise redraws its routes
  "rails" => {
    "de" => [%(Rails.root.join("config/routes.rb").write(<<~RUBY)
  Rails.application.routes.draw do
    root "imbiss#start"
    get "/speisekarte" => "imbiss#speisekarte", as: :speisekarte
    get "/hallo/:name" => "imbiss#hallo"
    get "/speck" => "kueche#speck"
  end
RUBY
ImbissApp.reload_routes!

class KuecheController < ActionController::Base
  def speck
    render plain: "CHUNKY BACON!"
  end
end

show_browser ImbissApp, "/speck")],
    "en" => [%(Rails.root.join("config/routes.rb").write(<<~RUBY)
  Rails.application.routes.draw do
    root "diner#home"
    get "/menu" => "diner#menu", as: :menu
    get "/hello/:name" => "diner#hello"
    get "/bacon" => "kitchen#bacon"
  end
RUBY
DinerApp.reload_routes!

class KitchenController < ActionController::Base
  def bacon
    render plain: "CHUNKY BACON!"
  end
end

show_browser DinerApp, "/bacon")]
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

# The IronRuby lesson ("engine": "ironruby") on IronRuby itself: the bundle
# the page loads (html/assets/ironruby/, tools/vendor_ironruby.rb) under Node,
# one process per language - every cell above the exercise, in order (what ▶
# on the exercise runs first on a fresh page), then the starter and the
# solutions, each followed by the exercise's "probe". The check is CRuby, as
# on the page: output (the picture lines taken out), result and probe as
# PicoRubyCells::Values, code. Returns the number of failures.
IRONRUBY_NODE = File.expand_path("ironruby_node.mjs", __dir__)

# The Ruboto lesson ("engine": "jruby", "android": true) on JRuby with the
# simulated phone: the JRuby the page loads (html/assets/jruby/), under Node
# (test/ruboto_node.mjs), one process per language - every code cell above
# the exercise, in order (each must run, and each that defines an activity
# must start it), then the starter, RUBOTO_WRONG and the solutions, each
# followed by the exercise's "probe". The check is CRuby, as on the page.
# Returns the number of failures.
RUBOTO_NODE = File.expand_path("ruboto_node.mjs", __dir__)

def ruboto_available?
  File.file?(File.expand_path("../html/assets/jruby/jruby.js", __dir__)) &&
    system("node", "--version", out: File::NULL, err: File::NULL)
end

def check_ruboto(lesson, lang, cells, exercise_at)
  where = "#{lesson["id"]}/#{lang}"
  exercise = cells[exercise_at]
  solutions = SOLUTIONS.fetch(lesson["id"]).fetch(SOLUTION_LANG.fetch(lang, lang))
  demos = (0...exercise_at).select { |i| cells[i]["t"] == "c" }
  variants = [["starter", exercise["code"]]] + RUBOTO_WRONG.each_with_index.map { |s, i| ["wrong#{i + 1}", s] } +
             solutions.each_with_index.map { |s, i| ["solution#{i + 1}", s] }
  # with idle gaps, as a learner runs cells: a garbage collection between
  # runs is what broke JRuby's proxy cache once (HANDOVER §6u)
  runs = demos.map { |i| { "code" => cells[i]["code"], "delay" => 300 } } +
         variants.map { |_, code| { "code" => code, "probe" => exercise["probe"], "delay" => 300 } }
  out, err, status = Open3.capture3("node", RUBOTO_NODE, stdin_data: JSON.generate("runs" => runs))
  unless status.success?
    puts "FAIL #{where}: test/ruboto_node.mjs exited #{status.exitstatus}: #{err.lines.last(3).join.strip}"
    return 1
  end
  answers = JSON.parse(out)
  failures = 0
  demos.each_with_index do |idx, i|
    answer = answers[i]
    if !answer["ok"]
      puts "FAIL #{where}: demo cell #{idx} raised #{answer.dig("error", "class")}: #{answer.dig("error", "message")}"
      failures += 1
    elsif cells[idx]["code"].match?(/def onCreate/) && !answer["phone"]
      puts "FAIL #{where}: demo cell #{idx} defines an activity, but no app started"
      failures += 1
    elsif answer["phone"] && JSON.parse(answer["phone"]).dig("device", "crash")
      puts "FAIL #{where}: demo cell #{idx}'s app crashed: #{JSON.parse(answer["phone"]).dig("device", "log").last.inspect}"
      failures += 1
    end
  end
  variants.each_with_index do |(label, candidate), i|
    answer = answers[demos.size + i]
    starter_like = label == "starter" || label.start_with?("wrong")
    if !answer["ok"]
      puts "FAIL #{where} (#{label}): raised #{answer.dig("error", "class")}: #{answer.dig("error", "message")}"
      failures += 1
      next
    end
    bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval
    bind.local_variable_set(:output, answer["stdout"].to_s)
    bind.local_variable_set(:result, PicoRubyCells.value(answer["result"].to_s))
    bind.local_variable_set(:probe, answer["probe"] ? PicoRubyCells.value(answer["probe"].to_s) : nil)
    bind.local_variable_set(:code, candidate)
    %i[images scenes downloads audios games shoes_types].each { |name| bind.local_variable_set(name, []) }
    passed = begin
      !!eval(exercise["check"], bind, "check.rb")
    rescue Exception
      false
    end
    if starter_like && passed
      puts "FAIL #{where}: #{label} code passes check! (probe #{answer["probe"].inspect})"
      failures += 1
    elsif !starter_like && !passed
      puts "FAIL #{where} (#{label}): does not pass check (probe #{answer["probe"].inspect})"
      failures += 1
    end
  end
  failures
end

def ironruby_available?
  File.file?(File.expand_path("../html/assets/ironruby/_framework/dotnet.js", __dir__)) &&
    system("node", "--version", out: File::NULL, err: File::NULL)
end

def check_ironruby(lesson, lang, cells, exercise_at)
  where = "#{lesson["id"]}/#{lang}"
  exercise = cells[exercise_at]
  solutions = SOLUTIONS.fetch(lesson["id"]).fetch(SOLUTION_LANG.fetch(lang, lang))
  earlier = EarlierCells.before(exercise_at, cells, {}) { |i| cells[i]["code"] }
  variants = [["starter", exercise["code"]]] + IRONRUBY_WRONG.each_with_index.map { |s, i| ["wrong#{i + 1}", s] } +
             solutions.each_with_index.map { |s, i| ["solution#{i + 1}", s] }
  runs = earlier.map { |_, code| { "code" => code } } +
         variants.map { |_, code| { "code" => code, "probe" => exercise["probe"] } }
  out, err, status = Open3.capture3("node", IRONRUBY_NODE, stdin_data: JSON.generate("runs" => runs))
  unless status.success?
    puts "FAIL #{where}: test/ironruby_node.mjs exited #{status.exitstatus}: #{err.lines.last(3).join.strip}"
    return 1
  end
  answers = JSON.parse(out)
  failures = 0
  earlier.each_with_index do |(idx, _), i|
    answer = answers[i]
    next if answer["ok"]

    puts "FAIL #{where}: demo cell #{idx} raised #{answer.dig("error", "class")}: #{answer.dig("error", "message")}"
    failures += 1
  end
  variants.each_with_index do |(label, candidate), i|
    answer = answers[earlier.size + i]
    starter_like = label == "starter" || label.start_with?("wrong")
    if !answer["ok"] && !starter_like
      puts "FAIL #{where} (#{label}): raised #{answer.dig("error", "class")}: #{answer.dig("error", "message")}"
      failures += 1
      next
    end
    bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval
    output, = IronRubyCells.split(answer["stdout"].to_s)
    bind.local_variable_set(:output, output)
    bind.local_variable_set(:result, answer["ok"] ? PicoRubyCells.value(answer["result"].to_s) : nil)
    bind.local_variable_set(:probe, answer["probe"] ? PicoRubyCells.value(answer["probe"].to_s) : nil)
    bind.local_variable_set(:code, candidate)
    %i[images scenes downloads audios games shoes_types].each { |name| bind.local_variable_set(name, []) }
    passed = begin
      !!eval(exercise["check"], bind, "check.rb")
    rescue Exception
      false
    end
    if starter_like && passed
      puts "FAIL #{where}: #{label} code passes check! (probe #{answer["probe"].inspect})"
      failures += 1
    elsif !starter_like && !passed
      puts "FAIL #{where} (#{label}): does not pass check (probe #{answer["probe"].inspect})"
      failures += 1
    end
  end
  failures
end

# While working on a few lessons: HARNESS_JSON=other/lessons.json runs another
# build of the course, HARNESS_ONLY=id,id only those lessons, and
# HARNESS_SOLUTIONS=file.rb (a file whose last expression is a Hash like
# SOLUTIONS) adds or replaces solutions - for a changed exercise.
def run_harness(langs)
  data = JSON.parse(File.read(ENV.fetch("HARNESS_JSON", File.expand_path("lessons.json", __dir__))))
  only = ENV["HARNESS_ONLY"].to_s.split(",").map(&:strip)
  if (extra = ENV["HARNESS_SOLUTIONS"])
    SOLUTIONS.merge!(eval(File.read(extra), TOPLEVEL_BINDING, extra))
  end
  # the lessons to check: all but the browser-only ones, or those named - a
  # name that is no such lesson, or a browser-only one, is a mistake that
  # would otherwise end in "ALL CHECKS OK" with nothing checked
  selected = data["lessons"].reject { |lesson| BROWSER_ONLY.include?(lesson["id"]) }
  unless only.empty?
    unknown = only - selected.map { |lesson| lesson["id"] }
    abort "HARNESS_ONLY: #{unknown.join(", ")} - no such lesson, or one only the browser tests run (BROWSER_ONLY)" if unknown.any?
    selected = selected.select { |lesson| only.include?(lesson["id"]) }
  end
  failures = 0
  checked = 0   # exercises run: the main one of every lesson, and the bonus ones
  # The solution a cell offers behind 💡 (its "solution", shell/app.rb
  # reveal_hint) must be one this harness verifies: one of SOLUTIONS[id]
  # for the language (ja shows en's). The browser-only lessons' solutions
  # (no SOLUTIONS entry) are checked by the browser tests.
  data["lessons"].each do |lesson|
    next if BROWSER_ONLY.include?(lesson["id"]) # browser_test.mjs runs their solutions
    langs.each do |lang|
      lesson.fetch(lang)["cells"].select { |c| c["t"] == "x" && c["solution"] }.each do |cell|
        key = cell["bonus"] ? "#{lesson["id"]}#bonus" : lesson["id"]
        known = SOLUTIONS.dig(key, SOLUTION_LANG.fetch(lang, lang)) || []
        next if known.include?(cell["solution"])
        puts "FAIL #{key}/#{lang}: the cell's solution is not one of SOLUTIONS[#{key.inspect}] - 💡 would show unverified code"
        failures += 1
      end
    end
  end
  # the Pico lessons ("pico") run on the Pico simulator, in a process of
  # their own (test/pico_harness.rb): a clean top level for GPIO, no
  # CRuby net/http
  pico, selected = selected.partition { |lesson| lesson["pico"] }
  failures += 1 unless pico.empty? || pico_harness(pico, langs)
  Dir.chdir(WORKDIR)

  # the JRuby lesson's data is vendored, not in git (tools/vendor_jruby.rb)
  if selected.any? { |lesson| lesson["engine"] == "jruby" } && !JRubyCells.fetch_text.call(JRubyCells::DATA.values.first)
    puts "SKIP jruby: no html/assets/jruby/data/ - run tools/vendor_jruby.rb"
    selected = selected.reject { |lesson| lesson["engine"] == "jruby" }
  end
  # the Ruboto lesson's JRuby is vendored, not in git (tools/vendor_jruby.rb)
  if selected.any? { |lesson| lesson["android"] } && !ruboto_available?
    puts "SKIP ruboto: no html/assets/jruby/jruby.js (run tools/vendor_jruby.rb) or no node"
    selected = selected.reject { |lesson| lesson["android"] }
  end
  # the IronRuby lesson's runtime is vendored, not in git (tools/vendor_ironruby.rb)
  if selected.any? { |lesson| lesson["engine"] == "ironruby" } && !ironruby_available?
    puts "SKIP ironruby: no html/assets/ironruby/ (run tools/vendor_ironruby.rb) or no node"
    selected = selected.reject { |lesson| lesson["engine"] == "ironruby" }
  end

  selected.each do |lesson|

  langs.each do |lang|
    l = lesson.fetch(lang)
    cells = l["cells"]
    exercise_at = cells.index { |c| c["t"] == "x" }
    exercise = cells[exercise_at]
    # the Ruboto lesson runs on JRuby with the simulated phone, under Node
    if lesson["android"]
      failures += check_ruboto(lesson, lang, cells, exercise_at)
      next
    end
    # the IronRuby lesson runs on IronRuby, under Node (check_ironruby)
    if lesson["engine"] == "ironruby"
      failures += check_ironruby(lesson, lang, cells, exercise_at)
      next
    end
    # A fresh page, where the learner's first ▶ is the exercise's: the cells
    # above it that the page runs first, in order (html/earlier_cells.rb).
    # The cells above any demo cell are the first of these, so every demo
    # cell is a first run here too - a cell that needs what one above it
    # makes, a local above all (top-level methods and constants outlive a
    # binding in this process), finds it.
    # A cell that shows an error on purpose is not among them; it runs here
    # in its place too, to check it raises what it says.
    # a demo cell below the exercise (none yet) runs first on a fresh page
    # without it: the exercise is left out while it holds its starter
    last = cells.rindex { |c| c["t"] == "c" }
    if last && last > exercise_at && !%w[picoruby jruby].include?(lesson["engine"])
      bind = RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval
      unmix_ruby2d
      load_lesson_files(lesson)
      above = EarlierCells.before(last, cells, {}) { |i| cells[i]["code"] }.map(&:last)
      (above + [cells[last]["code"]]).each do |code|
        _, _, err = run_in(bind, lesson["spinel"] ? ChunkySpinel.cell_source(code) : code)
        next unless err

        puts "FAIL #{lesson["id"]}/#{lang}: cell #{last}, run first on a fresh page, raised #{err.class}: #{err.message}"
        failures += 1
        break
      end
    end
    # every exercise: the main one (SOLUTIONS[id]) and the bonus ones
    # ("bonus": true, SOLUTIONS["id#bonus"]); the starter must fail, every
    # solution pass, with the demo cells above run first (EarlierCells: the
    # other exercises are left out while they hold their starter)
    xs = cells.each_index.select { |i| cells[i]["t"] == "x" }
    xs.each do |exercise_at|
    checked += 1
    exercise = cells[exercise_at]
    key = exercise["bonus"] ? "#{lesson["id"]}#bonus" : lesson["id"]
    earlier = EarlierCells.before(exercise_at, cells, {}) { |i| cells[i]["code"] }.to_h
    demos = (0...exercise_at).select { |i| earlier.key?(i) || cells[i]["raises"] }
                             .map { |i| { "code" => cells[i]["code"], "raises" => cells[i]["raises"] } }
    solutions = SOLUTIONS.fetch(key).fetch(SOLUTION_LANG.fetch(lang, lang))
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
      # the JRuby lesson's demos call Java (java_import, AtomicLong):
      # test/jruby_test.mjs runs them; its CRuby side reads the USGS data
      demos = [] if lesson["engine"] == "jruby"
      demos.each do |demo|
        _, _, err = run_in(bind, lesson["spinel"] ? ChunkySpinel.cell_source(demo["code"]) : demo["code"])
        # a cell that shows an error on purpose names it ("raises"), and
        # must raise exactly that one
        expected = demo["raises"]
        if expected && err&.class&.name != expected
          puts "FAIL #{lesson["id"]}/#{lang}: demo cell should raise #{expected}, " \
               "#{err ? "raised #{err.class}: #{err.message}" : "ran without error"}"
          failures += 1
          demo_failed = true
        elsif err && !expected
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
      JRubyCells.load_data if lesson["engine"] == "jruby"
      watch = FileWatch.snapshot
      # a lesson with "spinel": true runs each cell's code as a program for Spinel (main.rb)
      result, output, error = run_in(bind, lesson["spinel"] ? ChunkySpinel.cell_source(candidate) : candidate)
      downloads = FileWatch.changes_since(watch).map(&:first) | $explicit_downloads
      if error && label != "starter"
        puts "FAIL #{lesson["id"]}/#{lang} (#{label}): raised #{error.class}: #{error.message}"
        failures += 1
        next
      end

      bind.local_variable_set(:output, output)
      # the page hands a PicoRuby lesson's check the value's inspect text
      result = PicoRubyCells.value(result.inspect) if %w[picoruby jruby].include?(lesson["engine"])
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
        puts "FAIL #{key}/#{lang}: starter code already passes check!"
        failures += 1
      elsif label != "starter" && !passed
        puts "FAIL #{key}/#{lang} (#{label}): does not pass check"
        failures += 1
      end
    end
    end
  end
end

  puts failures.zero? ? "ALL CHECKS OK (#{selected.size} lessons, #{checked} exercises x #{langs.join("+")}, puts + no-puts variants)" : "#{failures} failures (#{langs.join("+")})"
  failures.zero?
end

def pico_harness(lessons, langs)
  ids = lessons.map { |lesson| lesson["id"] }
  args = [RbConfig.ruby, File.expand_path("pico_harness.rb", __dir__), "--stdin", "--lang=#{langs.join(",")}", "--only=#{ids.join(",")}"]
  IO.popen(args, "w") { |io| io.write(JSON.generate(SOLUTIONS.slice(*ids))) }
  $?.success?
end

# test/pico_harness.rb asks for the solutions of the lessons it checks on
# its own (ruby test/pico_harness.rb, without check_harness.rb)
if ARGV[0] == "--dump-solutions"
  puts JSON.generate(SOLUTIONS.slice(*ARGV[1].to_s.split(",")))
  exit
end

# One process per language: lesson code defines methods and classes at the
# top level, which outlive the binding, and ja runs the same code as en - an
# en solution's `def square` would let the ja starter pass.
if (lang = ENV["HARNESS_LANG"])
  exit(run_harness([lang]) ? 0 : 1)
else
  results = LANGS.map { |l| system({ "HARNESS_LANG" => l }, RbConfig.ruby, __FILE__) }
  exit(results.all? ? 0 : 1)
end
