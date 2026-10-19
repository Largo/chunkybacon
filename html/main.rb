app_path = __FILE__
$0 = File::basename(app_path, ".rb") if app_path

require 'js'
require 'js/require_remote'
# our files are where the page's <base> says - under a permalink
# (/de/methoden, server/app.rb) that is not where location.href points;
# without a <base> the two are the same
JS::RequireRemote.instance.base_url = JS.global[:document][:baseURI].to_s
require 'json'
require 'stringio'
require 'singleton'
# did_you_mean comes with Ruby, but ruby.wasm boots without it (no
# gem_prelude). Loaded, a misspelt name in a cell gets a suggestion below
# the error (ChunkyApp#suggestion_html): nmae -> name.
begin
  require 'did_you_mean'
rescue LoadError
  nil
end

# require_relative bridge (pattern from BrowserRubyKoans): files on the
# wasm filesystem first (stdlib, installed gems), remote URL fetch for our
# own source files (browser_gems.rb), which are not on that filesystem.
# Code that is (stdlib's net/https, gems) never falls through to the remote
# fetch - a missing file there is a plain LoadError, which the require hook
# may still answer with a shim.
module Kernel
  alias original_require_relative require_relative
  def require_relative(path)
    location = caller_locations(1, 1).first
    caller_path = (location.absolute_path || location.path).to_s
    begin
      original_require_relative(File.absolute_path(path, File.dirname(caller_path)))
    rescue LoadError
      raise if caller_path.start_with?("/")
      # a workshop program requiring another of its files (workshop.rb)
      loaded = defined?(Workshop) ? Workshop.require_relative(path, caller_path) : nil
      return loaded unless loaded.nil?
      JS::RequireRemote.instance.load(path)
    end
  end
end

# gems (roo, Tempfile users) expect a temp dir; the wasm filesystem starts
# without one, and reports no permission bits, which Dir.tmpdir rejects
Dir.mkdir("/tmp") unless Dir.exist?("/tmp")
require "tmpdir"
def Dir.tmpdir = "/tmp"

# ...nor owners or settable times: gems that set them after writing a file
# (rubyzip extracting, so roo) carry on, as the call can change nothing
class << File
  { chmod: 1, lchmod: 1, chown: 2, lchown: 2, utime: 2, lutime: 2 }.each do |name, leading|
    next unless method_defined?(name)
    alias_method :"wasm_orig_#{name}", name
    define_method(name) do |*args|
      send(:"wasm_orig_#{name}", *args)
    rescue Errno::ENOSYS, Errno::ENOTSUP
      args.size - leading
    end
  end
end

require_relative "browser_gems"
require_relative "rack_playground"

BrowserGems.cache_base = "gems/cache"
BrowserGems.proxy_base = "/rubygems"
# OFFLINE[:miss]: a download failed because the page is offline (index.html's
# helpers say "ERROR offline") - the install message says so
OFFLINE = { miss: false }
BrowserGems.fetch_text = lambda do |url|
  text = JS.global.fetchTextSync(url).to_s
  OFFLINE[:miss] = true if text == "ERROR offline"
  text.start_with?("ERROR ") ? nil : text
end
BrowserGems.fetch_binary = lambda do |url|
  base64 = JS.global.fetchBinaryBase64(url).to_s
  OFFLINE[:miss] = true if base64 == "ERROR offline"
  base64.start_with?("ERROR ") ? nil : base64.unpack1("m0")
end

# jsg (github.com/Largo/jsg) - the js gem with a friendlier syntax:
# el.textContent = "x", input.value, el.closest(".x") is nil when nothing
# matches, results come back as Ruby values. From the gem cache, so the two
# fetchers above are the only code here written without it.
BrowserGems.install("jsg")
require "jsg"

# Net::HTTP in the browser: the stdlib version cannot load (no io/wait, no
# sockets in WASI), so the require hook serves our API-compatible shim and
# we back it with the browser's own HTTP. CORS limits which hosts a page
# may call - these are reachable (proxied same-origin or CORS-open):
require "net/http"
unless Net::HTTP.respond_to?(:transport=)
  # this wasm build managed to load the REAL net/http (io/wait present);
  # it still cannot work without sockets - overlay the shim
  Net.send(:remove_const, :HTTP)
  BrowserGems.loaded.delete("(shims):net/http.rb")
  BrowserGems.load_feature("net/http")
end
NET_HTTP_HOSTS = {
  "www.ruby-lang.org" => "/proxy/ruby-lang",
  "ruby-lang.org" => "/proxy/ruby-lang",
  "rubygems.org" => "/rubygems",
  "api.github.com" => "https://api.github.com"
}.freeze

# Minitest: the ruby.wasm 4.0 build does not bundle it, so install the
# cached pure-Ruby 5.x on demand. Its parallel executor spawns threads on
# Minitest.run - replace it with a serial stub once, at boot.
begin
  require "minitest"
rescue LoadError
  BrowserGems.install("minitest")
  require "minitest"
end
unless Gem.respond_to?(:find_files)
  # minitest's plugin scan needs this; the wasm build ships a stripped Gem
  def Gem.find_files(*_args) = []
end
# ...which also lacks Gem::Deprecate, used by gems at load time
# (addressable, and so premailer)
begin
  require "rubygems/deprecate" unless defined?(Gem::Deprecate)
rescue LoadError
  nil
end
# ...but the stub does not last: a gem that loads full RubyGems (rubyzip
# does, so ruby_pptx does) brings the real Gem.find_files, whose plugin scan
# finds the wasm image's bundled minitest 6 and loads it over this 5.x -
# after which every run_tests dies with an ArgumentError. Minitest's own
# switch skips the scan whatever Gem looks like.
ENV["MT_NO_PLUGINS"] = "1"
Minitest.parallel_executor = Object.new.tap do |stub|
  def stub.start; end
  def stub.shutdown; end
  def stub.<<(_work)
    raise NotImplementedError, "parallelize_me! is unavailable in the browser (no threads in WASI)"
  end
end

# A binding at the top level with a scope of its own, like a file of its
# own. Bindings made from TOPLEVEL_BINDING all share one scope: a `using` in
# a cell (`using Processing`, lesson 36) would switch the refinement on in
# every lesson after it - `loop`, `text`, `size` would be Processing's - and
# in the page's own code. One compiled on its own keeps it to itself.
module TopLevel
  def self.binding(file = "chunky.rb")
    RubyVM::InstructionSequence.compile("proc { binding }.call", file).eval
  end
end

# Simulations for the sandbox: virtual filesystem behind File/Dir,
# virtual sleep, cooperative SimThread as Thread.
require_relative "sandbox_sim"
# The workshop: the learner's own multi-file programs.
require_relative "workshop"
# Live runs: rehearsals a moment after the learner stops typing.
require_relative "autorun"
# The cells above a cell that have not run yet: ▶ runs them first.
require_relative "earlier_cells"
# ⏯ beside ▶ (a lesson with "stepper": true): a run recorded line by line,
# for the page's stepper (stepper.js). At boot: ~14 KB that evaluates in
# about 6 ms.
require_relative "step_recorder"
# Terminal colours (pastel, tty-*) in a cell's output, as HTML.
require_relative "ansi"
# show_objects: names and objects as boxes and arrows, an SVG through
# show_image (lessons 7, 8, 11). At boot, unlike shoes_dom.rb: ~17 KB that
# evaluates in about 10 ms.
require_relative "object_graph"
# turtle { forward 100 }: drawings with Chunky as the turtle, an animated SVG
# through show_image (lesson 10). At boot too: ~15 KB that evaluates in
# about 6 ms. Its texts follow the lesson's language (sync_state).
require_relative "turtle"
# show_game: a grid game the page drives frame by frame (game.rb here, the
# loop in game.js; lesson 41). At boot too: ~10 KB of plain Ruby.
require_relative "game"
# spinel(code), show_spinel_irb: Matz's AOT compiler as WebAssembly in the
# page (the shell's shell/spinel.rb and its workers, html/spinel/); the CRuby
# run of the program beside it is here (lesson 45)
require_relative "spinel"
# A lesson with "engine": "picoruby" runs on PicoRuby.wasm in a Web Worker
# (picoruby_lab.js); this turns its answers into values, errors and CRuby's
# syntax messages. ~3 KB at boot.
require_relative "picoruby_cells"
# A lesson with "engine": "jruby" runs on JRuby 10.1 (TeaVM) in a Web Worker
# (jruby_lab.js); its answers are read as PicoRuby's are, and its CRuby cells
# ("on": "cruby") read the same earthquake data. ~2 KB at boot.
require_relative "jruby_cells"
# (jruby_lab.js fetched it when the lesson opened; otherwise it fetches now)
JRubyCells.fetch_text = lambda do |url|
  text = $window.chunkyJRuby.text(url).to_s
  text.start_with?("ERROR ") ? nil : text
end
# A lesson with "engine": "ironruby" runs on IronRuby (.NET in WebAssembly)
# in a Web Worker (ironruby_lab.js); its answers are read as PicoRuby's are,
# and the pictures its cells show come back in the output. ~2 KB at boot.
require_relative "ironruby_cells"
# require "pycall" is the bridge to Pyodide (pycall.rb): the real gem needs
# libpython, which a browser does not have
require_relative "pycall"
BrowserGems.files["(shims)"]["pycall.rb"] = ""
# require "sqlite3" is the gem's API over sql.js (sqlite3_sqljs.rb): the real
# gem is a C extension. Sequel's SQLite adapter runs on it unchanged, and
# BrowserGems counts sqlite3 as built in, so install_gem "sqlite3" works.
require_relative "sqlite3_sqljs"
BrowserGems.files["(shims)"]["sqlite3.rb"] = ""
# require "numo/narray" (numo-narray-alt's "numo/narray/alt" too): Numo is
# written in C, numo_narray.rb is its API in pure Ruby - what Rumale needs
# (lesson 29). Fetched on the first require, like shoes_dom.rb; BrowserGems
# counts the numo gems as built in once it is there.
numo = <<~'RUBY'
  unless defined?(Numo::NArray)
    source = JSG.w.fetchTextSync("numo_narray.rb").to_s
    raise LoadError, "could not fetch numo_narray.rb" if source.start_with?("ERROR ")

    eval(source, TOPLEVEL_BINDING, "numo_narray.rb")
  end
RUBY
BrowserGems.files["(shims)"]["numo/narray.rb"] = numo
BrowserGems.files["(shims)"]["numo/narray/alt.rb"] = numo
# require "processing": the gem draws through rays and reflexion (C++ on
# OpenGL); processing.rb is its API in pure Ruby, recording each frame for
# processing.js to paint (lesson 36). Fetched on the first require, like
# numo_narray.rb; the gem counts as built in once it is there.
BrowserGems.files["(shims)"]["processing.rb"] = <<~'RUBY'
  unless defined?(Processing::Context)
    source = JSG.w.fetchTextSync("processing.rb").to_s
    raise LoadError, "could not fetch processing.rb" if source.start_with?("ERROR ")

    eval(source, TOPLEVEL_BINDING, "processing.rb")
    Processing.measure__ = lambda do |text, size, font|
      JSG.w.chunkySketchTextWidth(text, size, font.to_s).to_s.to_f
    end
  end
RUBY
# require "ble" in a Pico lesson's CRuby cell (the laptop's side, lesson
# pico-ble): the `ble` gem's API over the bench's simulated radio
# (pico_laptop.rb; the real gem needs BlueZ and D-Bus). Fetched on the first
# require, like processing.rb.
BrowserGems.files["(shims)"]["ble.rb"] = <<~'RUBY'
  unless defined?(PicoLaptop)
    source = JSG.w.fetchTextSync("pico_laptop.rb").to_s
    raise LoadError, "could not fetch pico_laptop.rb" if source.start_with?("ERROR ")

    eval(source, TOPLEVEL_BINDING, "pico_laptop.rb")
  end
  PicoLaptop.cell = ChunkyApp.instance.laptop_cell__
RUBY
# require "ruby2d": the gem is Ruby around a C extension on SDL3. Its Ruby
# comes as it is (assets/ruby2d/ruby2d.rb, tools/vendor_ruby2d.rb), ruby2d.rb
# is the extension in Ruby: draw calls become commands game.js paints, and
# show hands the window to the page, which runs its frames like a show_game
# (mount_game; lesson 42). Fetched on the first require, ~210 KB; the gem
# counts as built in once it is there. The mixing into the top level is taken
# back when the lesson changes (sync_state), so later lessons do not find
# `show` or `Square` there; unmix__ also forgets this shim ran, so the next
# require "ruby2d" mixes again.
RUBY2D_FILES = %w[assets/ruby2d/ruby2d.rb ruby2d.rb].freeze
ruby2d_load = <<~'RUBY'
  unless defined?(Ruby2D::Page)
    AutoRun.untraced do
      ENV["HOME"] ||= "/"   # the gem's gamepad_events.rb reads ~ when it loads
      RUBY2D_FILES.each do |name|
        source = JSG.w.fetchTextSync(name).to_s
        raise LoadError, "could not fetch #{name}" if source.start_with?("ERROR ")

        eval(source, TOPLEVEL_BINDING, name)
      end
    end
    Ruby2D.measure__ = lambda do |text, size, style|
      JSG.w.chunkyCanvasTextWidth(text, size, style.to_i).to_s.to_f
    end
    Ruby2D.on_show__ = ->(runner) { ChunkyApp.instance.add_game(runner) }
    Ruby2D.lang__ = ChunkyApp.instance.lang
    Ruby2D.replay__ = ->(code) { eval(code, TopLevel.binding, ChunkyApp::EVAL_FILE) }
  end
RUBY
BrowserGems.files["(shims)"]["ruby2d.rb"] = ruby2d_load + "Ruby2D.mix__\n"
BrowserGems.files["(shims)"]["ruby2d/core.rb"] = ruby2d_load
# require "herb": the gem is Ruby around one C extension, its parser
# ("herb/herb"); herb_bridge.rb is that extension, handing the source to the
# same parser compiled to WebAssembly (index.html: ensureHerb; lesson 38).
BrowserGems.files["(shims)"]["herb/herb.rb"] = <<~'RUBY'
  unless defined?(Herb::Bridge)
    source = JSG.w.fetchTextSync("herb_bridge.rb").to_s
    raise LoadError, "could not fetch herb_bridge.rb" if source.start_with?("ERROR ")

    eval(source, TOPLEVEL_BINDING, "herb_bridge.rb")
  end
RUBY

Net::HTTP.transport = lambda do |_method, uri|
  # a live run fetches nothing: it would freeze the typing and ask the
  # server once per pause
  raise AutoRun::NeedsRun if ChunkyApp.instance.auto_run?

  prefix = NET_HTTP_HOSTS[uri.host.to_s.downcase]
  unless prefix
    raise SocketError, "#{uri.host} is not reachable from this browser playground " \
                       "(allowed: #{NET_HTTP_HOSTS.keys.join(', ')}) - on your own " \
                       "computer net/http can reach any URL"
  end
  data = JSON.parse(JSG.w.fetchHttpSync(prefix + uri.request_uri.to_s))
  if data["status"].to_i.zero?
    raise SocketError, "connection to #{uri.host} failed#{' - this page is offline' if data['body'] == 'offline'}"
  end
  [data["status"].to_i, { "content-type" => data["contentType"].to_s }, data["body"].to_s]
end

# A live run rehearsing the cells above (ChunkyApp#run_earlier) installs no
# gem for them, not even from the cache: installing and loading one takes
# seconds, which would freeze the typing in a cell further down. The cell
# then runs on its own; ▶ installs. (What the wasm image has built in is
# no install.)
module EarlierCells
  class << self
    attr_accessor :rehearsing
  end

  module NoInstalls
    def install(name, seen = {})
      name = name.to_s.strip
      if EarlierCells.rehearsing && !installed[name] &&
         !BrowserGems::NATIVE_GEMS.include?(name) && !BrowserGems::DEFAULT_GEMS.include?(name)
        raise AutoRun::NeedsRun
      end

      super
    end
  end
end
BrowserGems.singleton_class.prepend(EarlierCells::NoInstalls)

# "Ruby lernen mit Chunky Bacon" - a notebook-style browser Ruby course built
# on the same ruby.wasm setup as BrowserRubyKoans (koans.idogawa.com).
# Lessons are sequences of text blocks and runnable code cells; all cells of
# a lesson share one binding (like a notebook kernel) and each cell shows the
# value of its last expression as "=> ..." so puts is never required.
#
# This is the KERNEL: it runs cells, checks, gems and the widgets. The page
# around it - index, lesson text, editors, language, routing, Chunky's
# bubble - is the shell (shell/*.rb on PicoRuby.wasm), which is on screen
# long before this 10 MB Ruby has loaded. The shell says which lesson is
# open and asks for runs through shell/bridge.js (chunky:* events on
# window); the kernel answers through window.ChunkyBridge.
class ChunkyApp
  include Singleton

  EVAL_FILE = "chunky.rb"

  def initialize
    $window = JSG.w
    $d = JSG.d
    @data = JSON.parse($window.LESSONS_JSON)
    @lessons = @data["lessons"]
    @browser_apps = []
    @irb_sessions = []
    @three_renderers = {}
    @three_seq = 0
    @sketches = {}
    @shoes_apps = {}
    @games = {}
    @seq = nil
    sync_state(bridge.state)
    setup_elements
    bridge.kernelReady(installed_json)
  end

  # ---------- the shell (shell/bridge.js) ----------

  def bridge
    $window.ChunkyBridge
  end

  # The shell keeps the code a cell runs, under the fingerprint of the cell
  # it was written for (shell/store.rb's code_key); a page without the
  # shell keeps nothing.
  def save_code(idx, code)
    return unless $window[:chunkySaveCode].typeof == "function"

    $window.chunkySaveCode(idx.to_s, code)
  end

  # The lesson (or the workshop) the shell shows, in its language. A new seq
  # means a new page or a lesson reset: a fresh binding, old stages gone.
  def sync_state(state)
    @lang = state.lang
    @lang = "de" unless @data["ui"].key?(@lang)
    Turtle.lang = @lang   # its errors and the picture's alt text
    Ruby2D.lang__ = @lang if ruby2d?
    @lesson_id = state.lesson
    @workshop = state.workshop
    seq = state.seq.to_i
    return if seq == @seq

    first = @seq.nil?
    @seq = seq
    fresh_binding
    # (not in the embedded cell: embed.html has no PicoRuby)
    $window.chunkyPicoRuby.reset if $window[:chunkyPicoRuby].typeof == "object"
    $window.chunkyJRuby.reset if $window[:chunkyJRuby].typeof == "object"
    # the Pico's bench belongs to the page that went (pico_board.js). Not on
    # the first sync, when Ruby has just booted: the shell drew the page's
    # previews already and nothing can have run yet - rebuilding them would
    # close a USB panel or stop a webcam the learner opened meanwhile.
    $window.chunkyPicoBoard.unmount if !first && $window[:chunkyPicoBoard].typeof == "object"
    PicoLaptop.forget if defined?(PicoLaptop)
    $window.chunkyIronRuby.reset if $window[:chunkyIronRuby].typeof == "object"
    dispose_three
    dispose_shoes
    dispose_sketches
    dispose_games
    unmix_ruby2d
    load_lesson_files
  end

  # Files a lesson's code reads, next to it as on a computer (lessons.js:
  # "files": { name => path on the site }) - digits.csv for Rumale. Virtual
  # files, so File.read and File.exist? find them.
  def load_lesson_files
    return if workshop?

    (current_lesson["files"] || {}).each do |name, path|
      next if SandboxFS.exist?(name)

      text = $window.fetchTextSync(path).to_s
      SandboxFS.write(name, text) unless text.start_with?("ERROR ")
    end
  end

  def installed_json
    JSON.generate(BrowserGems.installed)
  end

  # ---------- helpers ----------

  def ui
    @data["ui"][@lang]
  end

  # the lesson the shell shows (sync_state)
  def current_index
    @lessons.index { |l| l["id"] == @lesson_id } || 0
  end

  # the workshop (#werkstatt): the learner's own programs
  def workshop?
    @workshop
  end

  def current_lesson
    @lessons[current_index]
  end

  def l10n(lesson)
    lesson[@lang] || lesson["de"]
  end

  def cells
    l10n(current_lesson)["cells"]
  end

  def code_cell?(cell)
    cell["t"] == "c" || cell["t"] == "x"
  end

  def escape_html(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  # a new binding has run none of the lesson's cells (earlier_cells.rb)
  def fresh_binding
    @bind = TopLevel.binding(EVAL_FILE)
    @ran = {}
    # what the JRuby worker's binding has run (the JRuby lesson)
    @jruby_ran = {}
    # what the IronRuby worker's binding has run (the IronRuby lesson)
    @ironruby_ran = {}
  end

  # ---------- setup ----------

  # The shell handles the page (index, language, reset, Run buttons, the
  # bubble, the gems panel); what is left here are the requests it sends
  # and the widgets whose Ruby objects live in this VM.
  def setup_elements
    $window.addEventListener("chunky:run") do |event|
      sync_state(event.detail)
      finish_cell_run(event.detail.idx.to_i, event.detail.auto.to_s == "true", event.detail.step.to_s == "true")
    end
    $window.addEventListener("chunky:lesson") { |event| sync_state(event.detail) }
    # a PicoRuby lesson's cells and IRBs answer later (picoruby_lab.js)
    $window.addEventListener("chunky:picoruby") { |event| picoruby_answer(event.detail) }
    # the JRuby lesson's cells answer later too (jruby_lab.js)
    $window.addEventListener("chunky:jruby") { |event| jruby_answer(event.detail) }
    # a tap past its limit ended JRuby's worker: nothing has run in the new one
    $window.addEventListener("chunky:phone") { |event| @jruby_ran = {} if %w[stopped failed].include?(event.detail.status.to_s) }
    # ... and what they print shows while they run (a Pico lesson's 60 s)
    $window.addEventListener("chunky:picoruby-progress") { |event| picoruby_progress(event.detail) }
    # the simulated Pico notified over BLE: the laptop cell's blocks (pico_laptop.rb)
    $window.addEventListener("chunky:pico-ble") { |event| pico_laptop_notify(event.detail.text.to_s) }
    # the IronRuby lesson's cells answer later too (ironruby_lab.js)
    $window.addEventListener("chunky:ironruby") { |event| ironruby_answer(event.detail) }
    $window.addEventListener("chunky:install") do |event|
      sync_state(event.detail)
      panel_install(event.detail.name)
    end

    # delegated listener for the mini-browser and file-explorer widgets;
    # closest() answers nil when nothing matches
    $d.getElementById("lessonBody").addEventListener("click") do |event|
      target = event.target
      css_class = target.className.to_s   # an SVG's className is an object
      if css_class.include?("mb-go")
        widget = target.closest(".mini-browser")
        navigate_browser(widget) if widget
      elsif css_class.include?("fe-refresh")
        widget = target.closest(".file-explorer")
        refresh_file_widget(widget) if widget
      elsif (row = target.closest(".fe-file"))
        widget = row.closest(".file-explorer")
        preview_file(widget, row.getAttribute("data-path")) if widget
      elsif css_class.include?("mb-view") && (link = event.composedPath.first.closest("a"))
        # links inside the fake browser navigate the fake browser; its page
        # is in a shadow root, so the click arrives with .mb-view as target
        event.preventDefault
        widget = target.closest(".mini-browser")
        if widget
          widget.querySelector(".mb-url").value = link.getAttribute("href").to_s
          navigate_browser(widget)
        end
      end
    end

    # Enter in a mini-browser URL bar navigates; Enter in an IRB input evals
    $d.getElementById("lessonBody").addEventListener("keydown") do |event|
      next unless event.key == "Enter"

      target = event.target
      target_class = target.className.to_s
      if target_class.include?("mb-url")
        event.preventDefault
        widget = target.closest(".mini-browser")
        navigate_browser(widget) if widget
      elsif target_class.include?("irb-input")
        event.preventDefault
        term = target.closest(".irb-term")
        irb_submit(term) if term
      end
    end
  end

  # ---------- gems ----------

  # the shell's gems panel shows the change (after every run, too)
  # A live run installs only from the cache, and outside its time limit: a
  # gem installed halfway would stay broken.
  def install_gem_ui(name)
    raise AutoRun::NeedsRun if auto_run? && !(BrowserGems.installed.key?(name) || BrowserGems.manifest.key?(name))

    OFFLINE[:miss] = false
    version = AutoRun.untraced { BrowserGems.install(name) }
    "#{name} #{version}"
  rescue BrowserGems::NativeGemError => e
    # the gem with C code may be a dependency of the one asked for
    message = e.message == name ? format(ui["nativeGem"], name) : format(ui["nativeDep"], name, e.message)
    raise BrowserGems::NativeGemError, message
  rescue BrowserGems::NotFoundError
    raise BrowserGems::NotFoundError, format(ui[OFFLINE[:miss] ? "gemOffline" : "gemNotFound"], name)
  end

  # the panel's chips and its install button (Chunky's bubble says how it went)
  def panel_install(name)
    result = install_gem_ui(name)
    bridge.installed(name, true, result)
  rescue StandardError => e
    bridge.installed(name, false, e.message)
  ensure
    bridge.gems(installed_json)
  end

  # alt: what the picture shows, in words (show_objects says it); a
  # picture without one is decorative, alt=""
  def add_image(data_url, alt = nil)
    return unless @run_images

    @run_images << data_url
    @run_image_alts[data_url] = alt.to_s if alt
  end

  # the first bytes of the picture formats a browser shows
  IMAGE_SIGNATURES = {
    "\x89PNG".b => "image/png", "\xFF\xD8\xFF".b => "image/jpeg",
    "GIF8".b => "image/gif", "RIFF".b => "image/webp"
  }.freeze

  # an SVG's text: <svg first, perhaps after an XML declaration and comments
  SVG_START = /\A\s*(?:<\?xml[^>]*>\s*)?(?:<!--.*?-->\s*)*<svg[\s>]/m

  # show_image's argument as a data: URL - a picture's bytes, an SVG's text,
  # a chart that writes SVG (a Rubyvis panel: drawn here, so a cell need not
  # call render), or the name of a file the cell wrote (virtual, or real:
  # File.binwrite, ChunkyPNG#save)
  def image_data_url(image)
    return image.to_data_url if image.respond_to?(:to_data_url)

    if image.respond_to?(:to_svg)
      image.render if image.respond_to?(:render)
      image = image.to_svg
    end
    bytes = image.respond_to?(:to_bytes) ? image.to_bytes.b : image.to_s.b
    unless IMAGE_SIGNATURES.any? { |magic, _type| bytes.start_with?(magic) } || bytes.match?(SVG_START)
      name = image.to_s
      bytes = (SandboxFS.virtual?(name) && SandboxFS.exist?(name) ? SandboxFS.read(name) : File.binread(name)).b
    end
    type = IMAGE_SIGNATURES.find { |magic, _type| bytes.start_with?(magic) }&.last
    type ||= bytes.match?(SVG_START) ? "image/svg+xml" : "image/png"
    "data:#{type};base64,#{[bytes].pack('m0')}"
  end

  def add_pdf(bytes)
    @run_pdfs << bytes.to_s.b if @run_pdfs
  end

  # The browser's own PDF viewer, on a Blob URL; the previous run's URLs of
  # this cell are released first.
  def pdfs_html(idx)
    @pdf_urls ||= {}
    (@pdf_urls[idx] || []).each { |url| $window.URL.revokeObjectURL(url) }
    @pdf_urls[idx] = @run_pdfs.map { |bytes| $window.makeDownloadUrl([bytes].pack("m0"), "application/pdf") }
    @pdf_urls[idx].map { |url| "<iframe class=\"cell-pdf\" title=\"PDF\" src=\"#{url}#view=FitH\"></iframe>" }.join
  end

  # ---------- sounds (show_audio) ----------

  def add_audio(bytes)
    @run_audios << bytes.to_s.b if @run_audios
  end

  # A player on a Blob URL, like show_pdf, above it a picture of the wave
  # (ChunkyAudio.waveform_svg). The player is named "Ein Klang, 2,0
  # Sekunden" (audioLabel), which #runStatus reads; the picture says
  # nothing more and is alt="".
  def audios_html(idx)
    @audio_urls ||= {}
    (@audio_urls[idx] || []).each { |url| $window.URL.revokeObjectURL(url) }
    @audio_urls[idx] = @run_audios.map { |bytes| $window.makeDownloadUrl([bytes].pack("m0"), "audio/wav") }
    @run_audios.zip(@audio_urls[idx]).map do |bytes, url|
      samples, rate = ChunkyAudio.pcm(bytes)
      # "1,5" - and "0,25" for a short sound, not "0,3" (or "0,0")
      seconds = format(samples.size >= rate ? "%.1f" : "%.2f", samples.size.fdiv(rate))
      seconds = seconds.tr(".", ",") if @lang == "de"
      label = escape_html(format(ui["audioLabel"], seconds))
      picture = samples.empty? ? "" : "<img class=\"cell-wave\" alt=\"\" src=\"data:image/svg+xml;base64,#{[ChunkyAudio.waveform_svg(samples, rate)].pack('m0')}\">"
      "<div class=\"cell-audio\">#{picture}<audio controls preload=\"auto\" src=\"#{url}\" aria-label=\"#{label}\"></audio></div>"
    end.join
  end

  # ---------- downloads ----------

  DOWNLOAD_TYPES = {
    ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".png" => "image/png", ".jpg" => "image/jpeg", ".svg" => "image/svg+xml",
    ".csv" => "text/csv", ".json" => "application/json", ".html" => "text/html",
    ".txt" => "text/plain", ".md" => "text/markdown", ".zip" => "application/zip",
    ".db" => "application/vnd.sqlite3", ".sqlite" => "application/vnd.sqlite3", ".sqlite3" => "application/vnd.sqlite3",
    ".pdf" => "application/pdf", ".wav" => "audio/wav"
  }.freeze

  # A file to offer below the cell. The same name twice keeps the last.
  def add_download(name, bytes)
    return unless @run_downloads
    @run_downloads.reject! { |existing, _| existing == name }
    @run_downloads << [name, bytes.to_s.b]
  end

  def downloads_html(idx)
    (@download_urls[idx] || []).each { |url| $window.URL.revokeObjectURL(url) }
    @download_urls[idx] = []
    links = @run_downloads.map do |name, bytes|
      type = DOWNLOAD_TYPES.fetch(File.extname(name).downcase, "application/octet-stream")
      url = $window.makeDownloadUrl([bytes].pack("m0"), type)
      @download_urls[idx] << url
      "<a class=\"cell-download\" href=\"#{url}\" download=\"#{escape_html(File.basename(name))}\">" \
        "⬇ #{escape_html(name)} <small>#{format_size(bytes.bytesize)}</small></a>"
    end
    "<div class=\"cell-downloads\" title=\"#{escape_html(ui["downloadTip"])}\">#{links.join}</div>"
  end

  def format_size(bytes)
    bytes < 1024 ? "#{bytes} B" : "#{(bytes / 1024.0).round(1)} KB"
  end

  # ---------- file explorer widget ----------

  def add_files_widget
    @run_files << true if @run_files
  end

  def files_list_html
    keys = SandboxFS.store.keys.sort
    dirs = keys.map { |k| k.include?("/") ? k.split("/").first : nil }.compact.uniq
    html = dirs.map { |d| "<li class=\"fe-dir\">📁 #{escape_html(d)}/</li>" }.join
    html + keys.map do |k|
      size = SandboxFS.store[k].bytesize
      "<li class=\"fe-file\" data-path=\"#{escape_html(k)}\">📄 <span class=\"fe-name\">#{escape_html(k)}</span><span class=\"fe-size\">#{size} B</span></li>"
    end.join
  end

  def files_widget_html
    <<~HTML
      <div class="file-explorer">
        <div class="fe-title"><span class="fe-dots"><span></span><span></span><span></span></span> 📁 timelog #{ui["filesTitle"]} <button type="button" class="fe-refresh" title="refresh">⟳</button></div>
        <ul class="fe-list">#{files_list_html}</ul>
        <pre class="fe-preview" style="display:none"></pre>
      </div>
    HTML
  end

  def refresh_file_widget(widget)
    widget.querySelector(".fe-list").innerHTML = files_list_html
    widget.querySelector(".fe-preview").style.display = "none"
  end

  def preview_file(widget, path)
    preview = widget.querySelector(".fe-preview")
    content = begin
      SandboxFS.read(path)
    rescue StandardError
      "?"
    end
    preview.textContent = content
    preview.style.display = "block"
  end

  # ---------- Shoes app stage (lacci + ShoesDom) ----------

  def add_shoes(options, block)
    return unless @run_shoes
    @run_shoes << {
      block: block,
      width: (options[:width] || 460).to_i,
      height: options[:height]&.to_i
    }
  end

  # ShoesDom subclasses Shoes::DisplayService, so it can only be defined once
  # Shoes is loaded. The lesson's first cell installs lacci and requires it;
  # a later Shoes cell run before it - or its live run while the learner
  # types - loads it here, from the cache. Evaluated without Shoes,
  # shoes_dom.rb stopped half way and left a ShoesDom without its classes,
  # which broke every Shoes cell until a reload: so it counts as loaded only
  # once its last class is there. Cells run synchronously, and
  # JS::RequireRemote needs an async context, so the source is fetched with
  # the same synchronous XHR the gem installer uses.
  def shoes_dom_loaded?
    return true if defined?(ShoesDom::DisplayService)

    unless defined?(Shoes::DisplayService)
      install_gem_ui("lacci")
      require "shoes"
    end
    source = $window.fetchTextSync("shoes_dom.rb")
    raise LoadError, "could not fetch shoes_dom.rb" if source.start_with?("ERROR ")

    eval(source, TOPLEVEL_BINDING, "shoes_dom.rb")
    true
  rescue StandardError, ScriptError => e
    $window.console.log("shoes_dom load failed: #{e.class}: #{e.message}")
    false
  end

  # Builds the app's DOM off-document and hands back the element to append
  # once the cell's own output is in place. Remembers the app per cell so a
  # re-run can take the old one down first.
  def build_shoes_stage(idx, spec)
    mounted = ShoesDom.mount(width: spec[:width], height: spec[:height], &spec[:block])
    (@shoes_apps[idx] ||= []) << mounted
    @last_shoes_types = mounted.types
    mounted.element
  rescue StandardError => e
    $d.createElement("div").tap do |node|
      node.className = "cell-error"
      node.textContent = "#{e.class}: #{e.message}"
    end
  end

  def dispose_shoes(idx = nil)
    @shoes_apps ||= {}
    if idx.nil?
      @shoes_apps.clear
      ShoesDom.reset! if defined?(ShoesDom)
    else
      (@shoes_apps.delete(idx) || []).each(&:dispose)
    end
  end

  # ---------- the letter (show_letter) ----------

  def add_letter(boxes, block)
    @run_letters << { boxes: boxes, block: block } if @run_letters
  end

  LETTER_LABELS = %w[From To Street Value Post Clear Sees Hint].freeze

  # The envelope is letter.js's; when the pen lifts it hands over the boxes'
  # digits (64 numbers each, as JSON) and writes our block's answer on the
  # letter - after the cell has run, so an error goes there too.
  def mount_letter(idx, out_el, spec, number)
    node = $d.createElement("div")
    out_el.appendChild(node)
    labels = LETTER_LABELS.to_h { |key| [key.downcase, ui["letter#{key}"].to_s] }
    key = "#{current_lesson['id']}-#{idx}-#{number}"
    letter = nil
    letter = $window.chunkyLetter(node, spec[:boxes], key, JSON.generate(labels)) do |json|
      next unless letter

      begin
        letter.answer(spec[:block].call(JSON.parse(json.to_s)).to_s, false)
      rescue StandardError, ScriptError => e
        letter.answer("#{e.class}: #{e.message}", true)
      end
    end
  end

  # ---------- Processing sketches (processing.rb + processing.js) ----------

  # The gem opens its window when the file has run (at_exit); here the cell
  # is the file. Its sketch starts - setup and the first frame - while the
  # cell still runs, so an error there is the cell's, and a live run's time
  # limit covers it. Each cell run starts with a fresh context.
  def processing? = defined?(Processing::Context) && Processing.respond_to?(:start__)

  def start_sketch
    sketch = Processing.start__ if processing?
    @run_sketches << sketch if sketch && @run_sketches
  end

  # The canvas is processing.js's; it asks for every further frame with the
  # events since the last one. A frame that fails stops the sketch, its
  # error below the canvas; what a frame prints goes there too.
  def mount_sketch(idx, out_el, sketch)
    node = $d.createElement("div")
    out_el.appendChild(node)
    canvas = nil
    canvas = $window.chunkySketch(node) do |json|
      next unless canvas

      old_stdout = $stdout
      $stdout = StringIO.new
      begin
        frame = sketch.step__(json.to_s)
        canvas.paint(frame, sketch.looping__ ? 1 : 0)
      rescue StandardError, ScriptError => e
        canvas.error("#{e.class}: #{e.message}")
      ensure
        printed = $stdout.string
        $stdout = old_stdout
        canvas.print(printed) unless printed.empty?
      end
    end
    (@sketches[idx] ||= []) << canvas
    canvas.paint(JSON.generate(sketch.takeCommands__), sketch.looping__ ? 1 : 0)
  end

  def dispose_sketches(idx = nil)
    keys = idx.nil? ? @sketches.keys : [idx]
    keys.each { |key| (@sketches.delete(key) || []).each { |canvas| canvas.stop } }
    Processing.reset__ if idx.nil? && processing?
  end

  # ---------- ruby2d (ruby2d.rb: its windows are games, below) ----------

  def ruby2d? = defined?(Ruby2D::Page) && Ruby2D.respond_to?(:reset__)

  def lang = @lang

  # require "ruby2d" mixed Ruby2D into the top level, as the gem does; the
  # next lesson starts without it, and its own require mixes it in again
  def unmix_ruby2d
    return unless ruby2d?

    Ruby2D.unmix__
    BrowserGems.loaded.delete("(shims):ruby2d.rb")
  end

  # ---------- games (show_game: game.rb + game.js) ----------

  def add_game(game)
    @run_games << game if @run_games
  end

  # ---------- Spinel (spinel.rb here, shell/spinel.rb on the page) ----------

  def add_spinel(program)
    @run_spinels << program if @run_spinels
  end

  def add_spinel_irb
    @run_spinels << :irb if @run_spinels
  end

  # The page compiles and runs it: the shell (shell/spinel.rb) draws the
  # widget into the element named here, its workers compile; nothing comes
  # back to Ruby. Plain strings only - the shell is PicoRuby.
  def mount_spinel(out_el, program)
    node = $d.createElement("div")
    @spinel_seq = (@spinel_seq || 0) + 1
    id = "spinel-#{@spinel_seq}"
    node[:id] = id
    out_el.appendChild(node)
    # a page without the shell (the embedded cell, embed.html) says so
    if $window[:chunkySpinelMount].typeof != "function"
      node.className = "cell-error"
      node.textContent = format(ui["spinelFailed"].to_s, "shell/spinel.rb")
    elsif program == :irb
      $window.chunkySpinelIrb(id)
    else
      $window.chunkySpinelMount(id, program.source, program.output, program.error.to_s, program.ms.round(1).to_s)
    end
  end

  # a tick that runs longer than this stops the game (an endless loop in an
  # every block would freeze the page for good: no ▶ is running to blame)
  GAME_TICK_LIMIT = 1.0
  GAME_LABELS = { "play" => "gamePlay", "keys" => "gameKeys", "paused" => "gamePaused",
                  "again" => "gameAgain" }.freeze
  R2D_LABELS = { "play" => "gamePlay", "keys" => "r2dKeys", "paused" => "gamePaused",
                 "over" => "r2dClosed", "again" => "r2dAgain" }.freeze

  # game.js runs the loop and calls the block once per frame at most, when a
  # timer is due or keys came in; the game answers with the cells that
  # changed. A re-run of the cell (or another lesson) stops it here, and
  # game.js stops by itself once its node has left the page.
  #
  # The time limit: enabling a TracePoint costs ~6 ms in the page (CRuby
  # re-instruments every loaded method), far more than a tick (~1 ms). So
  # the guard is switched on when the game starts running ("f:1", game.js:
  # it has the focus and is not paused) and off when it stops ("f:0") -
  # while a game runs nothing else in the kernel does (▶, a live run,
  # another lesson all take the focus away first). Each step only moves
  # the deadline.
  def mount_game(idx, out_el, game)
    node = $d.createElement("div")
    out_el.appendChild(node)
    # a ruby2d window (ruby2d.rb's Page::Runner) is a canvas, not a grid;
    # closed, it does not start again - the cell runs it anew
    canvas = game.respond_to?(:canvas?) && game.canvas?
    labels = (canvas ? R2D_LABELS : GAME_LABELS).transform_values { |key| ui[key].to_s }
    labels["title"] = canvas ? format(ui["r2dTitle"].to_s, game.title, game.width, game.height)
                             : format(ui["gameTitle"].to_s, game.width, game.height)
    opts = { w: game.width, h: game.height, first: game.full_json, labels: labels, canvas: canvas }
    guard = GameGuard.new(workshop? ? Workshop.paths : [EVAL_FILE], GAME_TICK_LIMIT)
    controller = $window.chunkyGame(node, JSON.generate(opts)) do |now, events|
      events = events.to_s
      if events.start_with?("f:")
        events == "f:1" ? guard.on : guard.off
        next nil
      end
      begin
        guard.step { game.step(now.to_f, events) }
      rescue AutoRun::Stopped
        guard.off
        game.error_json(format(ui["gameTooLong"].to_s, GAME_TICK_LIMIT))
      end
    end
    (@games[idx] ||= []) << [controller, guard]
  end

  # The time limit for a game's steps: one TracePoint, on while the game
  # runs; raises AutoRun::Stopped on a line of the learner's own code once a
  # step has run longer than +seconds+ (as AutoRun.with_time_limit does).
  class GameGuard
    def initialize(paths, seconds)
      @paths = paths
      @seconds = seconds
      @deadline = Float::INFINITY
    end

    def on
      return if @trace

      events = 0
      @late = false
      # as in AutoRun.with_time_limit: the clock every 128 events, the stop
      # on the next event of the learner's code (sampling both at once
      # missed `loop { }` forever, depending on how many events came before)
      @trace = TracePoint.new(:line, :b_call, :c_call) do |tp|
        events += 1
        @late = clock > @deadline if (events & 127).zero?
        raise AutoRun::Stopped if @late && @paths.include?(tp.path)
      end
      @trace.enable
    end

    def off
      @trace&.disable
      @trace = nil
    end

    def step
      @deadline = clock + @seconds
      @late = false
      yield
    ensure
      @deadline = Float::INFINITY
      @late = false
    end

    private

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def dispose_games(idx = nil)
    list = idx.nil? ? @games.values.flatten(1).tap { @games.clear } : (@games.delete(idx) || [])
    list.each do |controller, guard|
      guard.off
      controller.stop
    rescue StandardError
      nil
    end
  end

  # ---------- 3D stage (three-rb + three.js) ----------

  # three-rb builds the scene graph in pure Ruby and hands the drawing to
  # three.js, which it picks up as globalThis.THREE. index.html imports that
  # module lazily (window.ensureThree), so a lesson that uses show_three
  # kicks the import off when it opens and we only mount once it is there.
  def three_ready?
    $window.threeReady?
  end

  def preload_three
    $window.ensureThree
  end

  # One backend for the whole page. It caches the three.js objects it built
  # for each Ruby object and then only pushes what changed, so a second
  # backend would start from an empty cache and rebuild a scene that has no
  # pending changes left as bare defaults (camera back at the origin, meshes
  # untransformed) - a blank canvas. Renderers are per canvas, three.js
  # objects are not, so they can all share this one.
  def three_backend
    @three_backend ||= Three::Backends::ThreeJS.new
  end

  def add_three(scene, camera, options, animate)
    return unless @run_three
    @run_three << {
      scene: scene,
      camera: camera,
      animate: animate,
      width: (options[:width] || 460).to_i,
      height: (options[:height] || 320).to_i,
      background: options[:background] || 0x151a20,
      orbit: !!options[:orbit]
    }
  end

  def three_widget_html(tid, spec)
    <<~HTML
      <div class="three-stage" data-tid="#{tid}" style="width:#{spec[:width]}px;height:#{spec[:height]}px">
        <canvas id="three-canvas-#{tid}" width="#{spec[:width]}" height="#{spec[:height]}" role="img" aria-label="#{escape_html(ui["threeLabel"])}"></canvas>
      </div>
    HTML
  end

  # Each WebGL canvas holds a real GPU context and browsers only allow a
  # handful of them, so a cell disposes the stages it created last time
  # (their DOM is replaced anyway) before it mounts new ones.
  def dispose_three(idx = nil)
    keys = idx.nil? ? @three_renderers.keys : [idx]
    keys.each do |key|
      (@three_renderers.delete(key) || []).each do |renderer, controls|
        begin
          renderer.handle.setAnimationLoop(JS::Null)
          controls&.dispose
          renderer.handle.dispose
        rescue StandardError
          nil
        end
      end
    end
  end

  def mount_three(idx, tid, spec)
    canvas = $d.getElementById("three-canvas-#{tid}")
    return unless canvas

    # preserveDrawingBuffer keeps the last frame readable after compositing,
    # which is what lets the smoke test look at the rendered pixels
    renderer = Three::Renderers::ThreeJSRenderer.new(
      canvas: canvas, backend: three_backend,
      antialias: true, preserveDrawingBuffer: true
    )
    renderer.set_clear_color(spec[:background], 1)
    renderer.set_size(spec[:width], spec[:height])

    scene = spec[:scene]
    camera = spec[:camera]
    animate = spec[:animate]
    controls = nil
    if spec[:orbit]
      controls = Three::Controls::OrbitControls.new(
        camera, renderer: renderer, enable_damping: true, damping_factor: 0.08
      )
    end
    (@three_renderers[idx] ||= []) << [renderer, controls]

    # prefers-reduced-motion: an animated scene stands still at its first
    # frame (orbiting by hand still works - controls do not move by themselves)
    animate = nil if animate && $window.matchMedia("(prefers-reduced-motion: reduce)")[:matches].to_s == "true"
    if animate || controls
      frame = 0
      renderer.animation_loop do
        frame += 1
        animate.call(frame) if animate
        controls&.update
        renderer.render(scene, camera)
      end
    else
      renderer.render(scene, camera)
    end
  end

  # ---------- mini browser ----------

  def add_browser(app, path)
    @run_browsers << { app: app, path: path.to_s } if @run_browsers
  end

  def browser_widget_html(bid, path)
    <<~HTML
      <div class="mini-browser" data-bid="#{bid}">
        <div class="mb-chrome">
          <span class="mb-dots"><span></span><span></span><span></span></span>
          <span class="mb-scheme">http://localhost</span>
          <input class="mb-url" value="#{escape_html(path)}" spellcheck="false" title="URL" aria-label="#{escape_html(ui["browserUrl"])}">
          <button type="button" class="mb-go">#{ui["browserGo"]}</button>
          <span class="mb-status" aria-live="polite"></span>
        </div>
        <div class="mb-view"></div>
      </div>
    HTML
  end

  def navigate_browser(widget)
    app = @browser_apps[widget.getAttribute("data-bid").to_i]
    return unless app
    input = widget.querySelector(".mb-url")
    path = input.value
    path = "/" + path unless path.start_with?("/")
    input.value = path
    status_el = widget.querySelector(".mb-status")
    page = begin
      status, headers, body = RackPlayground.get(app, path)
      content_type = (headers["content-type"] || headers["Content-Type"]).to_s
      status_el.innerText = status.to_s
      status_el.className = "mb-status #{status < 400 ? 'ok' : 'err'}"
      content_type.empty? || content_type.include?("html") ? body : "<pre>#{escape_html(body)}</pre>"
    rescue Exception => e
      status_el.innerText = "ERR"
      status_el.className = "mb-status err"
      "<pre class=\"mb-error\">#{escape_html("#{e.class}: #{e.message}")}</pre>"
    end
    browser_page(widget.querySelector(".mb-view")).innerHTML = "#{MB_PAGE_STYLE}<div class=\"mb-page\">#{page_styles_scoped(page)}</div>"
  end

  # In the shadow root there is no <html> or <body> (the fragment parser
  # drops them), so a page's rules for html, :root and body would match
  # nothing. Their selectors are pointed at the fake browser's view (:host)
  # and the page (.mb-page) instead, so Sinatra's 404 page still looks like
  # Sinatra's 404 page - inside the fake browser. Only selectors change: the
  # text before each "{" that is not an @-rule, and in it not what stands in
  # [attribute] brackets or quotes (a[href="body"] stays).
  PAGE_ROOTS = { "html" => ":host", ":root" => ":host", "body" => ".mb-page" }.freeze
  PAGE_ROOT_SELECTOR = /\[[^\]]*\]|"[^"]*"|'[^']*'|(?<![\w.#:-])(?:html|body)(?![\w-])|:root(?![\w-])/i

  def page_styles_scoped(page)
    page.gsub(%r{(<style\b[^>]*>)(.*?)(</style>)}mi) do
      tag, css, close = $1, $2, $3
      css = css.gsub(/(\A|[{}])([^{}@]+)\{/) do
        "#{$1}#{$2.gsub(PAGE_ROOT_SELECTOR) { |part| PAGE_ROOTS.fetch(part.downcase, part) }}{"
      end
      "#{tag}#{css}#{close}"
    end
  end

  # The app's page goes into a shadow root of .mb-view, so a <style> it
  # brings (Sinatra's 404 page sets body { color: #888; text-align: center;
  # font-size: 22px }) stays in the fake browser instead of restyling the
  # whole course, and the course's rules stay out of the page; only inherited
  # properties (font, colour) come in from .mb-view. MB_PAGE_STYLE is the fake
  # browser's own default sheet: the app's CSS comes later and wins.
  MB_PAGE_STYLE = <<~HTML.freeze
    <style>
    * { box-sizing: border-box; }
    h1, h2 { margin: 0.2rem 0 0.5rem; }
    a { color: #1a5dc8; text-decoration: underline; cursor: pointer; }
    pre { margin: 0; white-space: pre-wrap; font-size: 0.88rem; }
    .mb-error { color: var(--err); }
    </style>
  HTML

  def browser_page(view)
    view.shadowRoot || view.attachShadow($window.Object.new.tap { |options| options.mode = "open" })
  end

  # ---------- IRB terminal widget ----------

  def add_irb
    @run_irbs << true if @run_irbs
  end

  def irb_prompt(session)
    # a PicoRuby IRB (the PicoRuby lesson) has a prompt of its own, so it
    # does not pass for CRuby's
    return session[:buffer].empty? ? "irb>" : "irb*" if session[:pico]

    depth = session[:buffer].empty? ? 0 : session[:buffer].lines.length
    format("irb(main):%03d:%d%s", session[:line], depth, depth.positive? ? "*" : ">")
  end

  def irb_widget_html(sid)
    <<~HTML
      <div class="irb-term" data-sid="#{sid}">
        <div class="irb-history" role="log" aria-live="polite"></div>
        <div class="irb-line">
          <span class="irb-prompt" aria-hidden="true">#{escape_html(irb_prompt(@irb_sessions[sid]))}</span>
          <input class="irb-input" spellcheck="false" autocomplete="off" title="irb" aria-label="#{escape_html(ui["irbInput"])}">
        </div>
      </div>
    HTML
  end

  # incomplete expressions (open def/do/string) get a continuation prompt
  INCOMPLETE_RE = /unexpected end-of-input|expected an? `?end`?|unterminated string|unterminated regexp|expects an expression after/i

  def irb_submit(term)
    session = @irb_sessions[term.getAttribute("data-sid").to_i]
    return unless session
    input_el = term.querySelector(".irb-input")
    history = term.querySelector(".irb-history")
    line = input_el.value
    input_el.value = ""

    append = "<div class=\"irb-echo\">#{escape_html(irb_prompt(session))} #{escape_html(line)}</div>"

    if line.strip == "exit" || line.strip == "quit"
      session[:buffer] = ""
      append += "<div class=\"irb-note\">#{ui["irbExitNote"]}</div>"
    elsif session[:pico]
      return picoruby_irb_line(term, session, line, append)
    else
      session[:buffer] = session[:buffer].empty? ? line : session[:buffer] + "\n" + line
      old_stdout = $stdout
      buffer = StringIO.new
      $stdout = buffer
      result = nil
      error = nil
      incomplete = false
      begin
        result = eval(session[:buffer], session[:bind], "irb")
      rescue SyntaxError => e
        if e.message =~ INCOMPLETE_RE
          incomplete = true
        else
          error = e
        end
      rescue Exception => e
        error = e
      ensure
        $stdout = old_stdout
      end

      unless incomplete
        session[:buffer] = ""
        session[:line] += 1
        append += "<pre class=\"irb-stdout\">#{AnsiHtml.to_html(buffer.string)}</pre>" unless buffer.string.empty?
        if error
          append += "<div class=\"irb-error\">#{escape_html("#{error.class}: #{error.message.lines.first.to_s.strip}")}</div>"
          append += suggestion_html(error, "irb-suggest")
        else
          session[:bind].local_variable_set(:_, result)
          append += "<div class=\"irb-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
        end
      end
    end

    history.innerHTML += append
    term.querySelector(".irb-prompt").innerText = irb_prompt(session)
    history.scrollTop = history.scrollHeight
    input_el.focus
  end

  # ---------- PicoRuby (a lesson with "engine": "picoruby") ----------

  # The lesson's cells and IRBs run on PicoRuby.wasm in a Web Worker
  # (picoruby_lab.js): a run goes out and settles when the answer comes
  # back, as a chunky:picoruby event - picoruby_answer shows it, checks an
  # exercise and tells the shell (ran), as finish_cell_run does for CRuby.
  # Code that does not parse never goes out: CRuby's Prism says why, with
  # the line - PicoRuby's compiler would only say no.
  def picoruby? = !workshop? && current_lesson && current_lesson["engine"] == "picoruby"

  # a lesson with "spinel": true (lesson 45): every cell's code is a program
  # for Spinel (spinel.rb's cell_source), no heredoc to write
  def spinel_lesson? = !workshop? && current_lesson && current_lesson["spinel"] == true

  def start_picoruby_run(idx, code, auto)
    $window.clearCellMarks(idx)
    syntax = PicoRubyCells.syntax_error(code, EVAL_FILE)
    return show_picoruby_run(idx, code, auto, error: syntax) if syntax

    @picoruby_codes ||= {}
    @picoruby_codes[idx] = code
    (@pico_live ||= {}).delete(idx)
    cell = cells[idx] || {}
    tabs = cell["tabs"] ? cell_tabs(idx) : "[]"
    board = pico_board_json(cell, true)
    $window.chunkyPicoBoard.mount(idx.to_s, board, pico_bench_ui) if board != "" && $window[:chunkyPicoBoard].typeof == "object"
    $window.chunkyPicoRuby.run(idx.to_s, code, auto, @seq.to_s, tabs, board)
    :pending
  end

  # A Pico lesson's cell (docs/HANDOVER.md §6r): its tabs as the editors
  # hold them ([{name, code, readonly}], index.html's getCellTabs) - the
  # editable ones are kept, as the main file is (the shell's save_tab)
  def cell_tabs(idx)
    json = $window.getCellTabs(idx.to_s).to_s
    unless workshop?
      JSON.parse(json).each do |tab|
        next if tab["readonly"]

        $window.chunkySaveTab(idx.to_s, tab["name"].to_s, tab["code"].to_s) if $window[:chunkySaveTab].typeof == "function"
      end
    end
    json
  rescue JSON::ParserError
    "[]"
  end

  # the board a cell runs on, as the worker's simulator takes it: the
  # lesson's Pico, the cell's parts and bench, and whether the run resets
  # the board (a cell's run does, a line in an IRB below it does not); ""
  # for a cell without one
  # the bench's strings (pico_board.js): the ui keys board*, this language
  def pico_bench_ui
    (@pico_bench_ui ||= {})[@lang] ||= JSON.generate(ui.select { |key, _| key.start_with?("board") })
  end

  def pico_board_json(cell, reset)
    board = cell["board"]
    return "" unless board.is_a?(Hash)

    JSON.generate({ "board" => (current_lesson["pico"] || {})["board"] || "pico2w", "parts" => board["parts"] || [],
                    "bench" => reset ? (cell["bench"] || []) : [], "reset" => reset })
  end

  # the CRuby cell that runs now in a Pico lesson (pico_laptop.rb's shim)
  def laptop_cell__ = @laptop_cell

  # A line the simulated Pico sent over BLE: each notification block of the
  # laptop's cell runs, and what it prints goes below that cell's output
  def pico_laptop_notify(text)
    return unless defined?(PicoLaptop) && picoruby?

    PicoLaptop.deliver(text) do |idx, printed|
      next if idx.nil? || printed.empty?

      out_el = $d.getElementById("cell-out-#{idx}")
      next if out_el.nil? || out_el.to_s == "null"

      pre = out_el.querySelector("pre.pico-notified")
      if pre.nil? || pre.to_s == "null"
        out_el.insertAdjacentHTML("beforeend", "<pre class=\"cell-stdout pico-notified\"></pre>")
        out_el.style.display = "block"
        pre = out_el.querySelector("pre.pico-notified")
      end
      pre.innerHTML = pre.innerHTML.to_s + AnsiHtml.to_html(printed)
    end
  end

  # what a run printed so far, below the cell (picoruby_lab.js's progress)
  def picoruby_progress(detail)
    return unless detail.seq.to_i == @seq

    @pico_live ||= {}
    if detail.kind.to_s == "irb"
      # a board IRB line runs up to 30 s: what it prints shows as it comes
      term = $d.querySelector(".irb-term[data-sid='#{detail.sid.to_i}']")
      return unless term

      history = term.querySelector(".irb-history")
      key = "irb#{detail.sid.to_i}"
      live = history.querySelector("pre.pico-live")
      unless @pico_live[key] && live
        history.insertAdjacentHTML("beforeend", "<pre class=\"irb-stdout pico-live\"></pre>")
        live = history.querySelector("pre.pico-live")
        @pico_live[key] = { style: {}, rest: "" }
      end
      live.insertAdjacentHTML("beforeend", pico_stream_html(@pico_live[key], detail.output.to_s))
      history.scrollTop = history.scrollHeight
      return
    end
    return unless detail.kind.to_s == "cell"

    idx = detail.idx.to_i
    out_el = $d.getElementById("cell-out-#{idx}")
    unless @pico_live[idx]
      # the first output of this run replaces the last run's
      out_el.innerHTML = "<pre class=\"cell-stdout pico-live\"></pre>"
      out_el.style.display = "block"
      @pico_live[idx] = { style: {}, rest: "" }
    end
    live = out_el.querySelector("pre.pico-live")
    # appended, not innerHTML += (that parses the whole output again)
    live.insertAdjacentHTML("beforeend", pico_stream_html(@pico_live[idx], detail.output.to_s))
  end

  # one chunk of a run's output as HTML: the colour state goes on from the
  # last chunk, and an escape code cut at the end waits for the next one
  def pico_stream_html(state, text)
    text = state[:rest] + text
    cut = text =~ /\e(\[[0-9;:?]*)?\z/
    state[:rest] = cut ? text[cut..] : ""
    text = text[0...cut] if cut
    AnsiHtml.to_html(text, state[:style])
  end

  def picoruby_answer(detail)
    return unless detail.seq.to_i == @seq   # another page by now

    return picoruby_irb_answer(detail) if detail.kind == "irb"

    idx = detail.idx.to_i
    auto = detail.auto == true
    (@pico_live ||= {}).delete(idx)
    code = (@picoruby_codes || {}).delete(idx) || $window.getCellCode(idx).to_s
    status = detail.status.to_s
    message = detail.message.to_s
    # an error in a tab (a Pico lesson's driver) is marked there, not in
    # the cell's own code
    file = detail.file.to_s
    line = file.empty? ? detail.line.to_i : 0
    error = case status
            when "error" then PicoRubyCells.error(detail.errorClass.to_s, message, line, EVAL_FILE)
            when "syntax" then SyntaxError.new(ui["picoSyntax"])
            when "stopped" then auto ? AutoRun::Stopped.new : PicoRubyCells::Stopped.new("#{ui['picoStopped']} #{ui['picoRestarted']}")
            when "reset" then PicoRubyCells::Stopped.new("#{ui['boardReset']} #{ui['picoRestarted']}")
            when "failed" then PicoRubyCells::Unavailable.new("#{ui['picoFailed']} (#{message})")
            end
    $window.markCellTabLine(idx.to_s, file, detail.line.to_i.to_s) if status == "error" && !file.empty? && !auto
    outcome = begin
      show_picoruby_run(idx, code, auto, output: detail.output.to_s, error: error, irbs: detail.irbs.to_i,
                        result: status == "ok" ? PicoRubyCells.value(detail.value.to_s) : nil,
                        board: PicoRubyCells.board(detail.board.to_s))
    rescue Exception => e
      $window.console.error("picoruby #{idx}: #{e.class}: #{e.message}")
      :error
    end
    elapsed = detail.elapsed.to_f
    bridge.ran(idx, outcome.to_s, elapsed, auto, elapsed)
  end

  # the cell's output as run_cell writes it for CRuby: what was printed,
  # the error (explained where a rule knows it) or "=> value", IRBs
  def show_picoruby_run(idx, code, auto, output: "", result: nil, error: nil, irbs: 0, board: nil, shown: "", out_class: "")
    # what an exercise's check sees besides output and result: nothing
    @run_images = []
    @run_downloads = []
    @run_three = []
    @run_shoes = []
    @last_shoes_types = []
    @run_sketches = []
    @run_audios = []
    @run_games = []
    out_html = ""
    out_html += "<pre class=\"cell-stdout#{out_class}\">#{AnsiHtml.to_html(output)}</pre>" unless output.empty?
    # the pictures an IronRuby cell showed (ironruby_cells.rb)
    out_html += shown
    hint = live_hint(error)
    # a run past the time limit took the worker, and the variables, with it
    hint = "#{hint} #{ui['picoRestarted']}" if error.is_a?(AutoRun::Stopped)
    hint ||= error.message if error.is_a?(PicoRubyCells::Stopped) || error.is_a?(PicoRubyCells::Unavailable)
    friendly = error && !hint && friendly_error(error, code, EVAL_FILE)
    if hint
      out_html += "<div class=\"cell-hint\">#{escape_html(hint)}</div>"
    elsif friendly
      out_html += friendly.to_html(brief: auto)
    elsif error
      out_html += "<div class=\"cell-error\">#{escape_html(PicoRubyCells.class_name(error))}: " \
                  "#{AnsiHtml.to_html(error.message.to_s)}</div>"
    elsif !(result.nil? && (!output.empty? || irbs.positive? || !shown.empty?))
      out_html += "<div class=\"cell-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
    end
    irbs.times do
      sid = @irb_sessions.length
      # a line in it runs on the cell's board, without resetting it
      @irb_sessions << { pico: true, line: 1, buffer: "", board: pico_board_json(cells[idx] || {}, false) }
      out_html += irb_widget_html(sid)
    end
    out_el = $d.getElementById("cell-out-#{idx}")
    out_el.innerHTML = out_html
    out_el.style.display = "block"
    out_el.classList.toggle("is-rehearsal", auto)
    if error
      return :stopped if error.is_a?(AutoRun::Stopped)

      line = !auto && error_line(error)
      $window.markCellLine(idx, line) if line
      return :error
    end
    cell = cells[idx]
    return :ok unless cell && cell["t"] == "x"

    check_exercise(cell, code, output, result, board: board) ? :pass : :fail
  end

  # A line in a PicoRuby IRB: an unfinished input waits for more (Prism
  # decides, as for CRuby's IRB), a finished one goes to the worker; the
  # answer is added below the echo by picoruby_irb_answer.
  def picoruby_irb_line(term, session, line, append)
    sid = term.getAttribute("data-sid").to_i
    history = term.querySelector(".irb-history")
    session[:buffer] = session[:buffer].empty? ? line : session[:buffer] + "\n" + line
    syntax = PicoRubyCells.syntax_error(session[:buffer], "(irb)")
    if syntax && syntax.message =~ INCOMPLETE_RE
      # the prompt changes below
    elsif syntax
      session[:buffer] = ""
      append += "<div class=\"irb-error\">#{escape_html("SyntaxError: #{syntax.message.lines.first.to_s.strip}")}</div>"
    else
      $window.chunkyPicoRuby.irb(sid.to_s, session[:buffer], @seq.to_s, session[:board] || "")
      session[:buffer] = ""
    end
    history.innerHTML += append
    term.querySelector(".irb-prompt").innerText = irb_prompt(session)
    history.scrollTop = history.scrollHeight
    term.querySelector(".irb-input").focus
  end

  def picoruby_irb_answer(detail)
    term = $d.querySelector(".irb-term[data-sid='#{detail.sid.to_i}']")
    return unless term

    history = term.querySelector(".irb-history")
    # what streamed in while it ran: the answer brings all of it
    (@pico_live ||= {}).delete("irb#{detail.sid.to_i}")
    live = history.querySelector("pre.pico-live")
    live.remove if live
    output = detail.output.to_s
    append = output.empty? ? "" : "<pre class=\"irb-stdout\">#{AnsiHtml.to_html(output)}</pre>"
    append += case detail.status.to_s
              when "ok" then "<div class=\"irb-result\">=&gt; #{escape_html(inspect_result(PicoRubyCells.value(detail.value.to_s)))}</div>"
              when "error" then "<div class=\"irb-error\">#{escape_html("#{detail.errorClass}: #{detail.message}")}</div>"
              when "stopped" then "<div class=\"irb-note\">#{escape_html("#{ui['picoStopped']} #{ui['picoRestarted']}")}</div>"
              when "reset" then "<div class=\"irb-note\">#{escape_html("#{ui['boardReset']} #{ui['picoRestarted']}")}</div>"
              else "<div class=\"irb-error\">#{escape_html(ui['picoFailed'])}</div>"
              end
    history.innerHTML += append
    history.scrollTop = history.scrollHeight
  end

  # ---------- JRuby (a lesson with "engine": "jruby") ----------

  # The lesson's cells run on JRuby 10.1 (TeaVM) in a Web Worker
  # (jruby_lab.js), as the PicoRuby lesson's run on PicoRuby: a run goes out
  # and settles when the answer comes back, as a chunky:jruby event. Unlike
  # PicoRuby's, the cells share one binding in JRuby, so the cells above
  # that have not run there yet go along and run first, quietly (as
  # earlier_cells.rb's do in CRuby). A cell with "on": "cruby" runs on the
  # page's ruby.wasm instead, and the exercise's check is CRuby's too, on the
  # same data - where it passes, CRuby runs the learner's code as well and
  # says whether both Rubies agree. No live runs ("live": false): JRuby can
  # only be stopped by ending its worker, and a new one takes 3 s to start.
  def jruby? = !workshop? && current_lesson && current_lesson["engine"] == "jruby"
  # the Ruboto lesson: JRuby with a simulated phone (docs/HANDOVER.md §6u). A
  # cell that defines an activity starts the app on it (html/ruboto_phone.js
  # draws it below the cell); the exercise's "probe" taps through the app in
  # JRuby, and its check reads the probe's inspect as `probe`, as the
  # IronRuby lesson's does. Nothing here runs on CRuby: Android is JRuby's.
  def android? = jruby? && current_lesson["android"] == true

  def start_jruby_run(idx, code)
    $window.clearCellMarks(idx)
    syntax = JRubyCells.syntax_error(code, EVAL_FILE)
    return show_jruby_run(idx, code, error: syntax) if syntax

    # the cells above that the worker's binding has not run, CRuby's left out
    jruby_only = cells.map { |cell| cell["on"] == "cruby" ? { "t" => "h" } : cell }
    earlier = EarlierCells.before(idx, jruby_only, @jruby_ran) { |i| $window.getCellCode(i).to_s }
    @jruby_pending ||= {}
    @jruby_pending[idx] = { code: code, earlier: earlier.to_h }
    probe = android? ? (cells[idx] || {})["probe"].to_s : ""
    $window.chunkyJRuby.run(idx.to_s, code, JSON.generate(earlier), @seq.to_s, probe, android?)
    :pending
  end

  def jruby_answer(detail)
    return unless detail.seq.to_i == @seq   # another page by now

    idx = detail.idx.to_i
    pending = (@jruby_pending || {}).delete(idx) || { code: $window.getCellCode(idx).to_s, earlier: {} }
    code = pending[:code]
    status = detail.status.to_s
    message = detail.message.to_s
    failed = detail.earlierFailed.to_s.split(",").map(&:to_i)
    ran = detail.earlier.to_s.split(",").map(&:to_i)
    if %w[ok error].include?(status)
      (ran - failed).each { |i| @jruby_ran[i] = pending[:earlier][i] if pending[:earlier][i] }
      @jruby_ran[idx] = code if status == "ok"
    else
      @jruby_ran = {}   # a new worker: nothing has run in it
    end
    error = case status
            when "error" then JRubyCells.error(detail.errorClass.to_s, message, detail.line.to_i, EVAL_FILE)
            when "stopped" then PicoRubyCells::Stopped.new("#{ui['jrubyStopped']} #{ui['jrubyRestarted']}")
            when "failed" then PicoRubyCells::Unavailable.new("#{ui['jrubyFailed']} (#{message})")
            end
    elapsed = detail.elapsed.to_f
    probe = detail.probe.to_s
    # a stopped worker took the phone with it
    $window.chunkyRubotoPhone.stale("stopped") if android? && %w[stopped failed].include?(status)
    outcome = begin
      show_jruby_run(idx, code, output: detail.output.to_s, error: error, elapsed: elapsed,
                                result: status == "ok" ? JRubyCells.value(detail.value.to_s) : nil,
                                probe: probe.empty? ? nil : JRubyCells.value(probe), phone: detail.phone.to_s)
    rescue Exception => e
      $window.console.error("jruby #{idx}: #{e.class}: #{e.message}")
      :error
    end
    bridge.ran(idx, outcome.to_s, elapsed, false, elapsed, ran.join(","), failed.join(","), "")
  end

  def show_jruby_run(idx, code, output: "", result: nil, error: nil, elapsed: nil, probe: nil, phone: "")
    cell = cells[idx]
    # the check reads the data in CRuby (JRubyCells.load_data)
    JRubyCells.load_data if cell && cell["t"] == "x" && !error && !android?
    # what the Ruboto lesson's check reads besides output, result and code
    @bind.local_variable_set(:probe, probe) if android? && cell && cell["t"] == "x"
    outcome = show_picoruby_run(idx, code, false, output: output, result: result, error: error)
    # the app this cell started, on the phone below it
    $window.chunkyRubotoPhone.mount(idx, phone) if android? && !phone.empty?
    out_el = $d.getElementById("cell-out-#{idx}")
    # a QR code of half blocks (█▀▄): drawn as square pixels above the text,
    # which stays (hidden) for copying - as text, its rows depend on the font
    # and a phone may not read it (JRubyCells.blocks_svg); any other output
    # with blocks gets lines with no gaps between them
    if output.match?(/[█▀▄]/)
      drawing = JRubyCells.blocks_svg(output, ui["jrubyBlocksAlt"])
      pre = drawing ? %(#{drawing}<pre class="cell-stdout blocks is-drawn" aria-hidden="true">) : '<pre class="cell-stdout blocks">'
      out_el.innerHTML = out_el.innerHTML.to_s.sub('<pre class="cell-stdout">', pre)
    end
    add_engine_badge(idx, :jruby, elapsed) if elapsed && !error.is_a?(SyntaxError)
    compare_with_cruby(idx, code, result, output) if outcome == :pass && !android?
    outcome
  end

  # which Ruby ran the cell, and how long its own run took
  def add_engine_badge(idx, engine, seconds)
    out_el = $d.getElementById("cell-out-#{idx}")
    return unless out_el

    name = if engine == :jruby
             format(ui["jrubyBadge"], $window.chunkyJRuby.version.to_s[/\d+(\.\d+)+/].to_s)
           else
             format(ui["crubyBadge"], RUBY_VERSION)
           end
    time = engine_time(seconds)
    out_el.insertAdjacentHTML("afterbegin", "<div class=\"cell-engine is-#{engine}\">#{escape_html(name)} · #{time}</div>")
  end

  # 812 ms, 1.07 s (1,07 s in German, as the course writes numbers)
  def engine_time(seconds)
    return "#{(seconds * 1000).round} ms" if seconds < 1

    text = format("%.2f s", seconds)
    @lang == "de" ? text.tr(".", ",") : text
  end

  # the exercise passed on JRuby: the same code on CRuby, in a binding of
  # its own (it ran to the end on JRuby, so it ends here too)
  def compare_with_cruby(idx, code, jruby_result, jruby_output)
    started = $window.performance.now
    old_stdout = $stdout
    $stdout = StringIO.new
    value = eval(code, TopLevel.binding(EVAL_FILE), EVAL_FILE)
    printed = $stdout.string
    $stdout = old_stdout
    seconds = ($window.performance.now - started) / 1000.0
    # what the code answered: its value, or (a puts at the end) its last line
    shown = value.nil? && !printed.strip.empty? ? printed.strip.lines.last.strip : "=> #{inspect_result(value)}"
    same = value.nil? ? printed == jruby_output : jruby_result == value
    text = format(ui[same ? "jrubyCrubySame" : "jrubyCrubyDiffers"], shown, engine_time(seconds))
    $d.getElementById("cell-out-#{idx}").insertAdjacentHTML("beforeend", "<div class=\"cell-engine is-cruby is-compare\">#{escape_html(text)}</div>")
  rescue Exception => e
    $stdout = old_stdout if old_stdout
    if e.is_a?(NameError) && code.match?(JAVA_CODE)
      # Java's classes (java.util..., Java::Lesson::Quakes) are JRuby's own:
      # say so, instead of no line at all
      text = format(ui["jrubyCrubyNoJava"], "#{e.class}: #{e.message[/\A[^\n]*/]}")
      $d.getElementById("cell-out-#{idx}").insertAdjacentHTML("beforeend", "<div class=\"cell-engine is-cruby is-compare\">#{escape_html(text)}</div>")
    else
      $window.console.error("jruby compare #{idx}: #{e.class}: #{e.message}")
    end
  end
  # code that reaches for Java (a NameError on CRuby is then expected)
  JAVA_CODE = /\bjava[._]|\bJava::|\bjavax\.|\bcom\.\w|\bjava_import\b|require\s*\(?\s*["']java["']/

  # the vendored data is not there (tools/vendor_jruby.rb was not run)
  def jruby_data_missing(idx)
    out_el = $d.getElementById("cell-out-#{idx}")
    out_el.innerHTML = "<div class=\"cell-hint\">#{escape_html(ui['jrubyFailed'])}</div>"
    out_el.style.display = "block"
    :error
  end

  # ---------- IronRuby (a lesson with "engine": "ironruby") ----------

  # The lesson's cells run on IronRuby 4.0 - .NET 10 compiled to WebAssembly
  # - in a Web Worker (ironruby_lab.js), as the PicoRuby lesson's run on
  # PicoRuby: a run goes out and settles when the answer comes back, as a
  # chunky:ironruby event. The cells share one binding in IronRuby, so the
  # cells above that have not run there yet go along and run first, quietly
  # (as earlier_cells.rb's do in CRuby). The exercise's check has two
  # halves: the cell's "probe", IronRuby code the worker runs right after
  # the learner's (it calls their method), and the "check", CRuby here,
  # which reads the probe's inspect as `probe` (a PicoRubyCells::Value).
  # No live runs ("live": false): IronRuby can only be stopped by ending
  # its worker, and a new one takes seconds to start.
  def ironruby? = !workshop? && current_lesson && current_lesson["engine"] == "ironruby"

  def start_ironruby_run(idx, code)
    $window.clearCellMarks(idx)
    syntax = PicoRubyCells.syntax_error(code, EVAL_FILE)
    return show_ironruby_run(idx, code, error: syntax) if syntax

    earlier = EarlierCells.before(idx, cells, @ironruby_ran) { |i| $window.getCellCode(i).to_s }
    @ironruby_pending ||= {}
    @ironruby_pending[idx] = { code: code, earlier: earlier.to_h }
    cell = cells[idx] || {}
    $window.chunkyIronRuby.run(idx.to_s, code, JSON.generate(earlier), @seq.to_s, cell["probe"].to_s)
    :pending
  end

  def ironruby_answer(detail)
    return unless detail.seq.to_i == @seq   # another page by now

    idx = detail.idx.to_i
    pending = (@ironruby_pending || {}).delete(idx) || { code: $window.getCellCode(idx).to_s, earlier: {} }
    code = pending[:code]
    status = detail.status.to_s
    message = detail.message.to_s
    failed = detail.earlierFailed.to_s.split(",").map(&:to_i)
    ran = detail.earlier.to_s.split(",").map(&:to_i)
    if %w[ok error].include?(status)
      (ran - failed).each { |i| @ironruby_ran[i] = pending[:earlier][i] if pending[:earlier][i] }
      @ironruby_ran[idx] = code if status == "ok"
    else
      @ironruby_ran = {}   # a new worker: nothing has run in it
    end
    error = case status
            when "error" then PicoRubyCells.error(detail.errorClass.to_s, message, detail.line.to_i, EVAL_FILE)
            when "stopped" then PicoRubyCells::Stopped.new("#{ui['ironStopped']} #{ui['ironRestarted']}")
            when "failed" then PicoRubyCells::Unavailable.new("#{ui['ironFailed']} (#{message})")
            end
    elapsed = detail.elapsed.to_f
    probe = detail.probe.to_s
    outcome = begin
      show_ironruby_run(idx, code, output: detail.output.to_s, error: error,
                                   probe: probe.empty? ? nil : PicoRubyCells.value(probe),
                                   result: status == "ok" ? PicoRubyCells.value(detail.value.to_s) : nil)
    rescue Exception => e
      $window.console.error("ironruby #{idx}: #{e.class}: #{e.message}")
      :error
    end
    bridge.ran(idx, outcome.to_s, elapsed, false, elapsed, ran.join(","), failed.join(","), "")
  end

  def show_ironruby_run(idx, code, output: "", result: nil, error: nil, probe: nil)
    text, shows = IronRubyCells.split(output)
    # a QR code drawn with puts (█) reads as one only with no gaps between the lines
    out_class = text.include?("\u2588") ? " qr-art" : ""
    # what the exercise's check reads besides output, result and code
    @bind.local_variable_set(:probe, probe) if (cells[idx] || {})["t"] == "x"
    show_picoruby_run(idx, code, false, output: text, result: result, error: error,
                                        shown: shows.map { |kind, b64| IronRubyCells.html(kind, b64) }.join,
                                        out_class: out_class)
  end

  # ---------- running cells ----------

  def error_line(error, file = EVAL_FILE)
    source = error.is_a?(SyntaxError) ? error.message.to_s : (error.backtrace || []).join("\n")
    match = source[/(?:\A|[\s(])#{Regexp.escape(file)}:(\d+)/, 1]
    match && match.to_i
  end

  # A Python object as a notebook shows it: pandas' own table for a
  # DataFrame (its HTML escapes the data), Python's repr otherwise - in full,
  # a Series' repr is several lines, so it starts below the arrow, where its
  # first row lines up with the others
  def python_result_html(result)
    html = result.__html__
    return "<div class=\"cell-result py-table\">#{html}</div>" if html.is_a?(String) && !html.empty?

    text = result.inspect.to_s
    text = "#{text[0, 4000]}…" if text.length > 4000
    "<div class=\"cell-result\">=&gt;#{text.include?("\n") ? "\n" : " "}#{escape_html(text)}</div>"
  rescue PyCall::PyError, PyCall::NotReady => e
    "<div class=\"cell-error\">#{escape_html(e.message)}</div>"
  end

  DARU_ROWS = 30

  def daru_table?(result)
    defined?(Daru::DataFrame) && (result.is_a?(Daru::DataFrame) || result.is_a?(Daru::Vector))
  end

  # A Daru::DataFrame or Daru::Vector as a table, like pandas' above: the
  # index down the left, a column per vector, the first DARU_ROWS rows.
  # (Daru's own to_html, for IRuby, leaves the data unescaped.) Its inspect
  # is a text table too wide and too long for the arrow's 200 characters.
  def daru_result_html(result)
    vector = result.is_a?(Daru::Vector)
    names = vector ? [result.name] : result.vectors.to_a
    columns = vector ? [result.to_a] : names.map { |name| result[name].to_a }
    index = result.index.to_a
    label = ->(value) { escape_html(Array(value).join(" ")) }
    cell = lambda do |value|
      value = value.round(6) if value.is_a?(Float) && value.finite?
      escape_html(value.nil? ? "nil" : value)
    end
    rows = index.first(DARU_ROWS).each_with_index.map do |key, i|
      "<tr><th>#{label.(key)}</th>#{columns.map { |column| "<td>#{cell.(column[i])}</td>" }.join}</tr>"
    end
    rows << "<tr><th>…</th>#{"<td>…</td>" * columns.size}</tr>" if index.size > DARU_ROWS
    size = vector ? index.size : "#{index.size}x#{names.size}"
    "<div class=\"cell-result py-table\"><table><caption>#{escape_html(result.class)}(#{size})</caption>" \
      "<thead><tr><th></th>#{names.map { |name| "<th>#{label.(name)}</th>" }.join}</tr></thead>" \
      "<tbody>#{rows.join}</tbody></table></div>"
  rescue StandardError
    "<div class=\"cell-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
  end

  def inspect_result(value)
    text = begin
      value.inspect
    rescue Exception
      begin
        value.to_s
      rescue Exception
        value.class.to_s
      end
    end
    text.length > 200 ? text[0, 200] + "…" : text
  end

  # ---------- running a cell, visibly ----------

  # Ruby runs on the page's main thread, so while a cell runs the page cannot
  # repaint. The shell puts the running state on screen *before* the run and
  # the bridge sends chunky:run only once that frame has been drawn
  # (afterPaint, index.html). What moves during the run is limited to
  # transform and opacity, which the browser animates off the main thread.
  # Afterwards the shell settles the cell: "ok" | "error" | "pass" | "fail",
  # and for a live run (+auto+) also "skipped" (nothing ran, the output
  # stays) | "stopped" (time limit) | "needs" (wants the Run button).
  # +step+: ⏯, the run recorded for the stepper.
  def finish_cell_run(idx, auto = false, step = false)
    started = $window.performance.now
    AutoRun.library_time = 0.0
    @earlier = nil
    outcome = begin
      run_cell(idx, auto: auto, step: step)
    rescue Exception => e
      $window.console.error("run_cell #{idx}: #{e.class}: #{e.message}")
      :error
    ensure
      end_rehearsal
      # matplotlib figures the run drew but did not show (pycall.rb)
      PyCall.end_run
    end
    elapsed = ($window.performance.now - started) / 1000.0
  ensure
    # the cells above that ran first (run_earlier): ▶ shows and measures the
    # cell's own run without them; a live run's time is all of it, as every
    # live run of the cell rehearses them again
    earlier = @earlier || {}
    library = AutoRun.library_time
    if earlier[:seconds] && elapsed && !auto
      elapsed = [elapsed - earlier[:seconds], 0.0].max
      library -= earlier[:library]
    end
    # +own+: without installing and loading gems, for the shell's "too slow
    # for live runs"
    own = elapsed ? [elapsed - library, 0.0].max : -1
    # a PicoRuby lesson's run went to the worker: picoruby_answer settles it
    unless outcome == :pending
      add_engine_badge(idx, :cruby, elapsed) if jruby? && !auto && elapsed && (cells[idx] || {})["on"] == "cruby"
      lists = %i[ran failed waiting].map { |key| (earlier[key] || []).join(",") }
      bridge.ran(idx, (outcome || :error).to_s, elapsed || -1, auto, own, *lists)
      bridge.gems(installed_json)
    end
  end

  # What a cell's run collects for its output, nil while the cells above run
  # quietly: the helpers (show_image, show_browser, show_shoes, ...) collect
  # nothing then.
  RUN_LISTS = %i[@run_images @run_image_alts @run_pdfs @run_audios @run_browsers @run_irbs @run_files
                 @run_three @run_shoes @run_letters @run_sketches @run_games @run_spinels @run_downloads].freeze

  # The cells above +idx+ that have not run in this binding yet, with the
  # code their editors show (earlier_cells.rb). Not in the workshop (one
  # program, run from scratch), a PicoRuby lesson (its cells run in a
  # worker, and stand alone) or the Spinel lesson (each cell a program of
  # its own).
  def earlier_cells(idx)
    # (the JRuby lesson: its CRuby cells, "on": "cruby", stand alone - the
    # cells above them ran on JRuby; the IronRuby lesson: its cells run in the
    # worker, which runs the cells above there - start_ironruby_run)
    return [] if workshop? || picoruby? || spinel_lesson? || jruby? || ironruby?

    EarlierCells.before(idx, cells, @ran) { |i| $window.getCellCode(i).to_s }
  end

  # Runs them, top to bottom, quietly: no output, no widgets, no check -
  # what they leave is the binding (and the files they write). ▶ records
  # each that ran without an error, so the next run skips it; one that
  # failed is named and runs again next time. What ran first goes to the
  # shell with the run (finish_cell_run): @earlier.
  #
  # A live run (+live+) rehearses them inside its own time limit and records
  # nothing. It installs no gem for them (EarlierCells::NoInstalls:
  # installing and loading Rumale takes seconds, and the typing would freeze
  # that long), fetches nothing, imports no new Python module: when one of them
  # wants that, the cell runs on its own, as it did before there were cells
  # above to run, and the shell says which still wait for ▶ (+waiting+). One
  # that takes the second up ends the run with a hint (AutoRun::NeedsEarlier).
  def run_earlier(list, live: false)
    started = $window.performance.now
    library = AutoRun.library_time
    ran = []
    failed = []
    EarlierCells.rehearsing = live
    list.each do |i, code|
      error = run_quietly(code)
      ran << i
      if error
        failed << i
      elsif !live
        @ran[i] = code
      end
    end
  rescue AutoRun::NeedsEarlier
    stopped = true
    raise
  rescue AutoRun::NeedsRun
    ran = []
    failed = []
    waiting = list.map(&:first)
  ensure
    EarlierCells.rehearsing = false
    # a file database they wrote goes back to its file now, not among the
    # downloads of the cell below (a rehearsal throws it away with the rest)
    SQLite3::Database.save_all(close: false) unless live
    unless stopped
      @earlier = { ran: ran, failed: failed, waiting: waiting, seconds: ($window.performance.now - started) / 1000.0,
                   library: AutoRun.library_time - library }
    end
  end

  # one cell above, as a run of its own (a fresh sketch, window and
  # matplotlib board): its error, or nil
  def run_quietly(code)
    lists = RUN_LISTS.map { |name| instance_variable_get(name) }
    RUN_LISTS.each { |name| instance_variable_set(name, nil) }
    Processing.reset__ if processing?
    Ruby2D.reset__ if ruby2d?
    old_stdout = $stdout
    $stdout = StringIO.new
    evaluate(code, EVAL_FILE)
    nil
  rescue AutoRun::Stopped
    raise AutoRun::NeedsEarlier
  rescue AutoRun::NeedsRun
    raise
  rescue Exception => e
    e
  ensure
    $stdout = old_stdout if old_stdout
    RUN_LISTS.zip(lists).each { |name, list| instance_variable_set(name, list) } if lists
    Processing.reset__ if processing?
    Ruby2D.reset__ if ruby2d?
    PyCall.end_run
  end

  # A live run keeps nothing it wrote: its new files on the real filesystem
  # go, the lesson's virtual ones come back - after the run, so that the
  # exercise's check still sees them (a PDF, a JPEG the cell wrote).
  def end_rehearsal
    changes, watch, lesson_files = @rehearsal
    @rehearsal = nil
    return unless changes

    AutoRun.take_back(changes, watch)
    SandboxFS.store.replace(lesson_files) if lesson_files
  end

  def auto_run? = @auto_run == true

  def run_cell(idx, auto: false, step: false)
    # the workshop's editor holds a whole program: one plain code cell
    cell = workshop? ? { "t" => "c" } : cells[idx]
    return unless cell && code_cell?(cell)
    code = $window.getCellCode(idx)
    save_code(idx, code) unless workshop?
    # a lesson whose cells compute too much for live runs says so
    # ("live": false, the shell asks for none there either)
    return :skipped if auto && !workshop? && current_lesson["live"] == false
    # a live run starts only for code that parses - otherwise the output
    # stays as it is (autorun.rb)
    return :skipped if auto && !AutoRun.runnable?(code, workshop? ? [] : @bind.local_variables)
    # a lesson on PicoRuby: the worker runs it, picoruby_answer shows it
    # (a cell with "engine": "cruby" in it runs here, on CRuby: the laptop's side)
    return start_picoruby_run(idx, code, auto) if picoruby? && cell["engine"] != "cruby"
    # the JRuby lesson: JRuby's worker runs it, jruby_answer shows it - but a
    # cell with "on": "cruby" runs here, on the earthquake data JRuby reads
    return start_jruby_run(idx, code) if jruby? && cell["on"] != "cruby"
    return jruby_data_missing(idx) if jruby? && !JRubyCells.load_data
    # the laptop's side (lesson pico-ble): a new run forgets this cell's
    # notification blocks, and what it subscribes belongs to it
    if picoruby?
      @laptop_cell = idx
      PicoLaptop.forget(idx) if defined?(PicoLaptop)
      PicoLaptop.cell = idx if defined?(PicoLaptop)
    end
    # the IronRuby lesson: the worker runs it, ironruby_answer shows it
    return start_ironruby_run(idx, code) if ironruby?

    if workshop?
      # the shell's callbacks (shell/workspace.rb), across the two Rubies
      file = $window.workshopOpenPath.to_s
      Workshop.prepare(JSON.parse($window.workspaceSnapshot.to_s), file, code)
      fresh_binding   # each run of a program starts from scratch
    else
      file = EVAL_FILE
    end
    # what the cells above make, first (earlier_cells.rb): ▶ runs them now,
    # before this cell's files are watched; a live run rehearses them with
    # this cell, below
    earlier = earlier_cells(idx)
    run_earlier(earlier) unless auto || earlier.empty?
    # a live run keeps no file it writes: the lesson's virtual ones come back
    lesson_files = SandboxFS.store.transform_values(&:dup) if auto && !workshop?
    $window.clearCellMarks(idx)
    @run_images = []
    @run_image_alts = {}
    @run_pdfs = []
    @run_audios = []
    @run_browsers = []
    @run_irbs = []
    @run_files = []
    @run_three = []
    @run_shoes = []
    @run_letters = []
    @run_sketches = []
    @run_games = []
    @run_spinels = []
    dispose_games(idx)
    @last_shoes_types = []
    dispose_shoes(idx)
    @run_downloads = []
    @download_urls ||= {}
    dispose_three(idx)
    dispose_sketches(idx)
    Processing.reset__ if processing?
    Ruby2D.reset__ if ruby2d?   # each run a program of its own: a new window
    watch = FileWatch.snapshot
    source = spinel_lesson? ? ChunkySpinel.cell_source(code) : code

    error = nil
    result = nil
    old_stdout = $stdout
    buffer = StringIO.new
    $stdout = buffer
    @auto_run = auto
    # a live run draws stills: an animation would start over at every pause
    Turtle.animations = !auto
    # ⏯: the same run, recorded line by line (step_recorder.rb) - the eval in
    # the lesson's binding as on ▶, so the next cell sees what it left.
    # Never a live run (recording costs up to 0.25 s), never the workshop.
    recorder = StepRecorder.new(code, file: file) if step && !auto && !workshop?
    begin
      result = if auto
        # one time limit for the cells above and this one
        AutoRun.with_time_limit(workshop? ? Workshop.paths : [file]) do
          run_earlier(earlier, live: true) unless earlier.empty?
          evaluate(source, file).tap { start_sketch }
        end
      elsif recorder
        recorder.run { evaluate(source, file) }.tap { start_sketch }
      else
        evaluate(source, file).tap { start_sketch }
      end
    rescue Exception => e
      error = e
    ensure
      $stdout = old_stdout
      @auto_run = false
      Turtle.animations = true
    end
    output = buffer.string
    # this code ran in the binding: a cell below needs not run it again
    # (earlier_cells.rb) - a live run was a rehearsal
    @ran[idx] = code unless auto || workshop? || error
    # a check plays a copy of a ruby2d window: the cell's code once more
    @run_games.each { |game| game.source = code if game.respond_to?(:source=) }
    # files the code wrote come first; an explicit download_file of the same
    # name replaces its entry
    explicit = @run_downloads
    @run_downloads = []
    # SQLite databases with a file name go back to their files now, so the
    # run's files include them (sqlite3_sqljs.rb); a workshop run is a whole
    # program, so its databases close with it
    SQLite3::Database.save_all(close: workshop?)
    changes = FileWatch.changes_since(watch)
    changes.each { |path, bytes| add_download(path, bytes) }
    explicit.each { |name, bytes| add_download(name, bytes) }
    # a rehearsal keeps nothing (end_rehearsal); what it wrote is still
    # shown and offered
    @rehearsal = [changes, watch, lesson_files] if auto
    if workshop?
      where = error && Workshop.location(error, file)
      # pictures, PDFs and sounds the program wrote show up below the editor -
      # unless it showed them itself (show_image, show_pdf, show_audio)
      Workshop.previews(changes).each do |path, bytes|
        if Workshop.pdf?(path)
          @run_pdfs << bytes.b unless @run_pdfs.include?(bytes.b)
        elsif Workshop.audio?(path)
          @run_audios << bytes.b unless @run_audios.include?(bytes.b)
        else
          url = Workshop.data_url(path, bytes)
          @run_images << url unless @run_images.include?(url)
        end
      end
      # what the program wrote goes into its project, next to the downloads -
      # not after a live run (finish gives the lessons their files back either way)
      kept = Workshop.finish(changes)
      unless auto
        kept.each { |path, value| value ? $window.workspaceWrite(path, value) : $window.workspaceDelete(path) }
        $window.workshopAfterRun
      end
    end

    out_html = ""
    out_html += "<pre class=\"cell-stdout\">#{AnsiHtml.to_html(output)}</pre>" unless output.empty?
    widgets_present = @run_images.any? || @run_browsers.any? || @run_irbs.any? || @run_three.any? ||
                      @run_shoes.any? || @run_downloads.any? || @run_pdfs.any? || @run_letters.any? ||
                      @run_sketches.any? || @run_audios.any? || @run_games.any? ||
                      @run_spinels.any?
    # an error inside another workshop file keeps Ruby's message and its
    # "(helper.rb:3)": the explanation only sees the open file's code
    friendly = error && !where && friendly_error(error, code, file)
    hint = live_hint(error)
    out_html += "<div class=\"cell-hint\">#{escape_html(hint)}</div>" if hint
    if friendly
      # a live run while typing shows just the headline (app.css
      # .friendly-brief); one the time limit stopped all of it, below the
      # hint - why the loop would never end
      # a lesson about reading Ruby's messages ("rubyMessage") shows Ruby's own
      # message unfolded under the explanation
      out_html += friendly.to_html(brief: auto && !error.is_a?(AutoRun::Stopped),
                                   original_open: !workshop? && current_lesson["rubyMessage"] == true)
    elsif hint
      # the hint is all there is to say (stopped, or it wants ▶)
    elsif error
      # ansi.rb: ruby.wasm's Prism colours a SyntaxError's code frame
      out_html += "<div class=\"cell-error\">#{escape_html(error.class)}: #{AnsiHtml.to_html(error.message.to_s)}" \
                  "#{where ? " (#{escape_html(where)})" : ""}</div>"
      out_html += suggestion_html(error)
    elsif result.is_a?(PyCall::PyObject)
      out_html += python_result_html(result)
    elsif daru_table?(result)
      out_html += daru_result_html(result)
    # a sketch's file ends in a block, mousePressed's true or false - what
    # it shows is the window
    # spinel(...) answers how CRuby ran the program: the widget shows it
    elsif !((result.nil? || @run_sketches.any? || result.is_a?(ChunkySpinel::Program)) && (!output.empty? || widgets_present))
      out_html += "<div class=\"cell-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
    end
    @run_images.each do |data_url|
      alt = escape_html(@run_image_alts[data_url]).gsub('"', "&quot;")
      out_html += "<img class=\"cell-image\" alt=\"#{alt}\" src=\"#{data_url}\">"
    end
    out_html += pdfs_html(idx)
    out_html += audios_html(idx)
    out_html += downloads_html(idx) if @run_downloads.any?
    new_widgets = []
    @run_browsers.each do |spec|
      bid = @browser_apps.length
      @browser_apps << spec[:app]
      new_widgets << bid
      out_html += browser_widget_html(bid, spec[:path])
    end
    @run_irbs.each do
      sid = @irb_sessions.length
      @irb_sessions << { bind: TopLevel.binding("(irb)"), line: 1, buffer: "" }
      out_html += irb_widget_html(sid)
    end
    @run_files.each { out_html += files_widget_html }
    new_stages = []
    @run_three.each do |spec|
      if three_ready?
        # ids must be unique across the whole page, not just this cell -
        # two stages sharing an id would have the second renderer draw onto
        # the first one's canvas
        tid = (@three_seq += 1)
        new_stages << [tid, spec]
        out_html += three_widget_html(tid, spec)
      else
        preload_three
        out_html += "<div class=\"cell-error\">#{escape_html(ui["threeLoading"])}</div>"
      end
    end
    out_el = $d.getElementById("cell-out-#{idx}")
    out_el.innerHTML = out_html
    out_el.style.display = "block"
    out_el.classList.toggle("is-rehearsal", auto)   # app.css: a live run's errors fainter
    new_widgets.each do |bid|
      widget = out_el.querySelector(".mini-browser[data-bid='#{bid}']")
      navigate_browser(widget) if widget
    end
    new_stages.each { |tid, spec| mount_three(idx, tid, spec) }
    # Shoes apps are built as detached DOM and appended, rather than written
    # into out_html, because the display service creates real elements with
    # real event handlers as the app's block runs.
    @run_shoes.each { |spec| out_el.appendChild(build_shoes_stage(idx, spec)) }
    @run_letters.each_with_index { |spec, n| mount_letter(idx, out_el, spec, n) }
    @run_sketches.each { |sketch| mount_sketch(idx, out_el, sketch) }
    @run_games.each { |game| mount_game(idx, out_el, game) }
    @run_spinels.each { |program| mount_spinel(out_el, program) }
    # the stepper goes on top of the output; the JSON is parsed in JS
    # (bridge.js), PicoRuby would take ages
    show_steps(idx, recorder) if recorder

    if error
      return :stopped if error.is_a?(AutoRun::Stopped)
      return :needs if error.is_a?(AutoRun::NeedsRun)

      # a live run marks no line: the learner is still typing
      line = !auto && error_line(error, file)
      $window.markCellLine(idx, line) if line
      return :error
    end

    return :ok unless cell["t"] == "x"

    check_exercise(cell, code, output, result) ? :pass : :fail
  end

  def show_steps(idx, recorder)
    bridge.steps(idx, recorder.to_json)
  rescue StandardError => e
    $window.console.error("steps #{idx}: #{e.class}: #{e.message}")
  end

  def evaluate(code, file)
    if workshop?
      Workshop.with_io(file, $window.workshopStdin.to_s) { eval(code, @bind, file) }
    else
      eval(code, @bind, file)
    end
  end

  # The kind explanation of a cell's error in the lesson's language
  # (friendly_errors.rb: headline, the line with a caret, what to do, Ruby's
  # own message folded away); nil when no rule knows the error, or loading
  # failed - the cell then shows Ruby's message as before. ~90 KB of rules
  # and texts, so fetched on the first error only, like shoes_dom.rb.
  def friendly_error(error, code, file)
    return nil if error.is_a?(AutoRun::NeedsRun)
    return nil unless friendly_errors_loaded?

    FriendlyErrors.explain(error, source: code, lang: @lang, file: file, binding: @bind)
  rescue StandardError, ScriptError
    nil
  end

  FRIENDLY_ERRORS_FILES = %w[friendly_errors_messages.rb friendly_errors.rb friendly_errors_rules.rb].freeze

  # off the clock: a cell is not slow because its first error loaded this
  def friendly_errors_loaded?
    return true if defined?(FriendlyErrors::RULES) && FriendlyErrors::RULES.any?
    return false if @friendly_errors_failed

    AutoRun.untraced do
      FRIENDLY_ERRORS_FILES.each do |name|
        source = $window.fetchTextSync(name).to_s
        raise LoadError, "could not fetch #{name}" if source.start_with?("ERROR ")

        # friendly_errors.rb leaves the rules to us (they come next)
        FriendlyErrors.const_set(:FETCHED, true) if name == "friendly_errors.rb"
        eval(source, TOPLEVEL_BINDING, name)
      end
    end
    true
  rescue StandardError, ScriptError => e
    # once: offline before the files were cached, it would try on every error
    @friendly_errors_failed = true
    $window.console.log("friendly_errors load failed: #{e.class}: #{e.message}")
    false
  end

  # what a live run says instead of an error when it stopped or wants ▶
  def live_hint(error)
    return ui["liveNeedsEarlier"] if error.is_a?(AutoRun::NeedsEarlier)
    return ui["liveStopped"] if error.is_a?(AutoRun::Stopped)
    return ui["liveNeedsRun"] if error.is_a?(AutoRun::NeedsRun)

    nil
  end

  # Ruby's did_you_mean knows what a misspelt name probably meant (nmae ->
  # name, frist -> first, fetch(:esen) -> :essen); the page says it below
  # the error, in the learner's language. Ruby puts it into
  # detailed_message, not into the message the cell shows.
  def suggestion_html(error, css = "cell-suggest")
    template = ui["didYouMean"]
    words = template && error.respond_to?(:corrections) ? error.corrections.first(3).map(&:to_s) : []
    return "" if words.empty?

    names = words.map { |word| "<code>#{escape_html(word)}</code>" }.join(ui["didYouMeanJoin"] || ", ")
    "<div class=\"#{css}\">#{escape_html(template).sub("%s", names)}</div>"
  rescue StandardError
    ""
  end

  # true when the exercise's check passes; the shell marks the lesson done
  # and has Chunky say so
  # +board+: a Pico lesson's simulated board after the run
  # (PicoRubyCells::Board), the check's `board` - set only in a PicoRuby
  # lesson, where no learner's variable of that name is overwritten by it
  def check_exercise(cell, code, output, result, board: nil)
    @bind.local_variable_set(:board, board) if picoruby?
    @bind.local_variable_set(:output, output)
    @bind.local_variable_set(:result, result)
    @bind.local_variable_set(:code, code)
    @bind.local_variable_set(:images, (@run_images || []).dup)
    @bind.local_variable_set(:downloads, (@run_downloads || []).map(&:first))
    @bind.local_variable_set(:scenes, (@run_three || []).map { |spec| spec[:scene] })
    @bind.local_variable_set(:apps, (@run_shoes || []).length)
    @bind.local_variable_set(:shoes_types, (@last_shoes_types || []).dup)
    @bind.local_variable_set(:sketch, (@run_sketches || []).last)
    @bind.local_variable_set(:audios, (@run_audios || []).dup)
    @bind.local_variable_set(:games, [])
    return !!eval(cell["check"], @bind, "check.rb") if (@run_games || []).empty?

    # A check that plays a game runs the learner's ticks, here and at once:
    # an endless loop in one would freeze the page, so it gets a time limit
    # (a stopped check fails). It plays copies, so the game below the cell
    # still starts from the beginning.
    AutoRun.with_time_limit(workshop? ? Workshop.paths : [EVAL_FILE], GAME_TICK_LIMIT * 2) do
      @bind.local_variable_set(:games, @run_games.map(&:fresh))
      !!eval(cell["check"], @bind, "check.rb")
    end
  rescue Exception
    false
  end
end

# show_audio's side of a WAV file (experiments/05-ruby-music): read its
# samples, draw them, and write sample Arrays as one. An SVG with inline
# attributes, shown as an <img> like show_objects' pictures (an <img> sees
# no page CSS); the colours are app.css's fox palette.
module ChunkyAudio
  WAVE_W = 360    # the whole sound, one column of pixels per bar
  ZOOM_W = 140    # the magnifier: 12 ms around the loudest moment
  WAVE_H = 64

  module_function

  # the first channel's 16-bit samples (-32768..32767) and the sample rate;
  # the chunks are walked, so a header longer than 44 bytes reads as well
  def pcm(bytes)
    bytes = bytes.b
    pos = 12
    channels = 1
    rate = 22_050
    while pos + 8 <= bytes.bytesize
      id, size = bytes.byteslice(pos, 8).unpack("a4V")
      if id == "fmt "
        # a header built by hand (lesson 40 packs its own) may be short or
        # say 0 channels or 0 Hz: fall back rather than fail below the cell
        _format, channels, rate = bytes.byteslice(pos + 8, [size, 8].min).unpack("vvV")
        channels = 1 unless channels.is_a?(Integer) && channels.positive?
        rate = 22_050 unless rate.is_a?(Integer) && rate.positive?
      elsif id == "data"
        all = bytes.byteslice(pos + 8, size).to_s.unpack("s<*")
        all = all.each_slice(channels).map(&:first) if channels > 1
        return [all, rate]
      end
      pos += 8 + size + (size & 1)
    end
    [[], rate]
  end

  # The whole sound as bars (each the lowest and highest sample of its
  # column) and, beside it, 12 ms around the loudest sample as a line - the
  # shape of the wave: round for a sine, steps for a square, teeth for a saw
  def waveform_svg(samples, rate)
    mid = WAVE_H / 2.0
    y = ->(s) { (mid - s * (mid - 2) / 32_768.0).round(1) }
    per = samples.size.fdiv(WAVE_W).ceil
    bars = samples.each_slice(per).with_index.map do |slice, x|
      lo, hi = slice.minmax
      "M#{x}.5 #{y.(hi)}V#{[y.(lo), y.(hi) + 0.5].max}"
    end.join
    width = [(rate * 0.012).round, 2].max
    loudest = samples.each_with_index.max_by { |s, _i| s.abs }.last
    from = (loudest - width / 2).clamp(0, [samples.size - width, 0].max)
    points = samples[from, width].each_with_index.map { |s, i| "#{(i * ZOOM_W.fdiv(width)).round(1)},#{y.(s)}" }.join(" ")
    label = ->(x, text) { "<text x=\"#{x}\" y=\"12\" font-size=\"10\" font-family=\"system-ui, sans-serif\" text-anchor=\"end\" fill=\"#5f5247\">#{text}</text>" }
    <<~SVG.delete("\n")
      <svg xmlns="http://www.w3.org/2000/svg" width="#{WAVE_W + ZOOM_W + 8}" height="#{WAVE_H}" viewBox="0 0 #{WAVE_W + ZOOM_W + 8} #{WAVE_H}">
      <rect width="#{WAVE_W}" height="#{WAVE_H}" rx="4" fill="#fdeee3"/>
      <path d="#{bars}" stroke="#e8722a" stroke-width="1" fill="none"/>
      #{label.(WAVE_W - 4, format('%.2f s', samples.size.fdiv(rate)))}
      <g transform="translate(#{WAVE_W + 8} 0)">
      <rect width="#{ZOOM_W}" height="#{WAVE_H}" rx="4" fill="#fdeee3"/>
      <line x1="0" x2="#{ZOOM_W}" y1="#{mid}" y2="#{mid}" stroke="#e9c3a6"/>
      <polyline points="#{points}" stroke="#b3401f" stroke-width="1.5" fill="none"/>
      #{label.(ZOOM_W - 4, '12 ms')}
      </g></svg>
    SVG
  end

  # an Array of samples (-1.0..1.0) as a WAV file: 16-bit mono PCM
  def wav(samples, rate)
    data = samples.map { |s| (s.to_f.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
    ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16,
     "data", data.bytesize].pack("a4Va4a4VvvVVvva4V") + data
  end
end

# helpers available inside notebook cells
module Kernel
  def install_gem(name)
    ChunkyApp.instance.install_gem_ui(name)
  end

  # Shows a picture below the cell:
  #   show_image png            # a ChunkyPNG::Image
  #   show_image jpeg           # what PureJPEG.encode returns (anything with to_bytes)
  #   show_image bytes          # a PNG, JPEG, GIF or WebP, as a String
  #   show_image svg            # an SVG's text
  #   show_image vis            # a Rubyvis chart (anything with to_svg)
  #   show_image "sonne.jpg"    # a file the cell wrote
  #   show_image vis, alt: "…"  # what a screen reader says for it
  def show_image(image, alt: nil)
    app = ChunkyApp.instance
    app.add_image(app.image_data_url(image), alt || (image.respond_to?(:alt_text) ? image.alt_text : nil))
    nil
  end

  # Shows a PDF below the cell, in the browser's own viewer:
  #   show_pdf "menu.pdf"      # a file the cell wrote
  #   show_pdf pdf             # a Prawn::Document, HexaPDF::Document or HexaPDF::Composer
  #   show_pdf bytes           # the PDF itself, as a String
  def show_pdf(pdf)
    pdf = pdf.document if defined?(HexaPDF::Composer) && pdf.is_a?(HexaPDF::Composer)
    bytes = if pdf.is_a?(String)
              if pdf.start_with?("%PDF")
                pdf
              elsif SandboxFS.virtual?(pdf) && SandboxFS.exist?(pdf)
                SandboxFS.read(pdf)
              else
                File.binread(pdf)
              end
            elsif pdf.respond_to?(:render)
              pdf.render
            else
              StringIO.new("".b).tap { |io| pdf.write(io) }.string
            end
    ChunkyApp.instance.add_pdf(bytes)
    nil
  end

  # Plays a sound below the cell, with a picture of its wave:
  #   show_audio wav(samples)          # a WAV file, as a String
  #   show_audio "melodie.wav"         # a file the cell wrote
  #   show_audio samples               # an Array of Floats in -1..1
  #   show_audio samples, rate: 8000   # (22,050 a second unless said)
  def show_audio(sound, rate: 22_050)
    bytes = if sound.is_a?(Array)
              ChunkyAudio.wav(sound, rate)
            elsif sound.to_s.b.start_with?("RIFF")
              sound.to_s
            elsif SandboxFS.virtual?(sound.to_s) && SandboxFS.exist?(sound.to_s)
              SandboxFS.read(sound.to_s)
            else
              File.binread(sound.to_s)
            end
    raise ArgumentError, "show_audio: not a WAV file (a WAV file starts with RIFF)" unless bytes.to_s.b.start_with?("RIFF")

    ChunkyApp.instance.add_audio(bytes)
    nil
  end

  # Offers a download below the cell. Files a cell writes are offered
  # anyway; this is for data that never went through a file:
  #   download_file praesi.to_blob, "chunky.pptx"
  #   download_file "notizen.txt"            # a file, by its path
  def download_file(data, name = nil)
    if name.nil?
      name = data.to_s
      virtual = SandboxFS.virtual?(name) && SandboxFS.exist?(name)
      data = virtual ? SandboxFS.read(name) : File.binread(name)
    elsif data.respond_to?(:to_blob)
      data = data.to_blob
    end
    ChunkyApp.instance.add_download(name.to_s, data)
    nil
  end

  # Renders a mini browser widget below the cell, wired to the given Rack
  # app (a Sinatra/Roda class or anything with #call).
  def show_browser(app, path = "/")
    ChunkyApp.instance.add_browser(app, path)
    nil
  end

  # Renders a 3D stage below the cell: a WebGL canvas driven by three-rb.
  # With a block the stage animates - the block runs once per frame, right
  # before the scene is drawn again.
  def show_three(scene, camera, width: 460, height: 320, background: 0x151a20, orbit: false, &animate)
    ChunkyApp.instance.add_three(
      scene, camera,
      { width: width, height: height, background: background, orbit: orbit },
      animate
    )
    nil
  end

  # Renders a Shoes app below the cell, drawn into the page by ShoesDom, a
  # Lacci display service. The block is the Shoes app's own body.
  def show_shoes(width: 460, height: nil, &block)
    raise ArgumentError, "show_shoes needs a block: show_shoes { para \"hi\" }" unless block
    unless ChunkyApp.instance.shoes_dom_loaded?
      raise LoadError, "the Shoes renderer could not be loaded"
    end

    ChunkyApp.instance.add_shoes({ width: width, height: height }, block)
    nil
  end

  # Shows a letter below the cell, with +boxes+ red boxes for a postcode to
  # write into, by hand. Whenever the pen lifts, the block gets the digits
  # written so far - one Array of 64 numbers (8x8, 0..16, like digits.csv)
  # per box with ink - and its answer is written on the letter:
  #   show_letter(boxes: 4) { |digits| model.predict(Numo::DFloat[*digits]).to_a.join }
  def show_letter(boxes: 4, &block)
    raise ArgumentError, "show_letter needs a block: show_letter { |digits| ... }" unless block

    ChunkyApp.instance.add_letter(boxes.to_i, block)
    nil
  end

  # Renders an interactive IRB terminal below the cell.
  def show_irb
    ChunkyApp.instance.add_irb
    nil
  end

  # Renders a file-explorer window showing the simulated filesystem.
  def show_files
    ChunkyApp.instance.add_files_widget
    nil
  end

  # Runs all Minitest tests defined so far, prints the familiar report,
  # then clears the registry so the next cell starts fresh. (On a real
  # machine you'd use require "minitest/autorun" and just run the file.)
  def run_tests
    result = Minitest.run([])
    Minitest::Runnable.runnables.clear
    result
  end
end

ChunkyApp.instance
