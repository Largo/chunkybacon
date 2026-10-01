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
BrowserGems.fetch_text = lambda do |url|
  text = JS.global.fetchTextSync(url).to_s
  text.start_with?("ERROR ") ? nil : text
end
BrowserGems.fetch_binary = lambda do |url|
  base64 = JS.global.fetchBinaryBase64(url).to_s
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

# Simulations for the sandbox: virtual filesystem behind File/Dir,
# virtual sleep, cooperative SimThread as Thread.
require_relative "sandbox_sim"
# The workshop: the learner's own multi-file programs.
require_relative "workshop"
# Live runs: rehearsals a moment after the learner stops typing.
require_relative "autorun"

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
  raise SocketError, "connection to #{uri.host} failed" if data["status"].to_i.zero?
  [data["status"].to_i, { "content-type" => data["contentType"].to_s }, data["body"].to_s]
end

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
    @shoes_apps = {}
    @seq = nil
    sync_state(bridge.state)
    setup_elements
    bridge.kernelReady(installed_json)
  end

  # ---------- the shell (shell/bridge.js) ----------

  def bridge
    $window.ChunkyBridge
  end

  # The lesson (or the workshop) the shell shows, in its language. A new seq
  # means a new page or a lesson reset: a fresh binding, old stages gone.
  def sync_state(state)
    @lang = state.lang
    @lang = "de" unless @data["ui"].key?(@lang)
    @lesson_id = state.lesson
    @workshop = state.workshop
    seq = state.seq.to_i
    return if seq == @seq

    @seq = seq
    fresh_binding
    dispose_three
    dispose_shoes
  end

  def installed_json
    JSON.generate(BrowserGems.installed)
  end

  # ---------- helpers ----------

  def ui
    @data["ui"][@lang]
  end

  def store(key, value)
    $window.localStorage.setItem(key, value)
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

  def code_key(id, idx)
    "chunky_cell_#{@lang}_#{id}_#{idx}"
  end

  def fresh_binding
    @bind = eval("proc { binding }.call", TOPLEVEL_BINDING)
  end

  # ---------- setup ----------

  # The shell handles the page (index, language, reset, Run buttons, the
  # bubble, the gems panel); what is left here are the requests it sends
  # and the widgets whose Ruby objects live in this VM.
  def setup_elements
    $window.addEventListener("chunky:run") do |event|
      sync_state(event.detail)
      finish_cell_run(event.detail.idx.to_i, event.detail.auto.to_s == "true")
    end
    $window.addEventListener("chunky:lesson") { |event| sync_state(event.detail) }
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
      elsif target.tagName == "A" && target.closest(".mb-view")
        # links inside the fake browser navigate the fake browser
        event.preventDefault
        widget = target.closest(".mini-browser")
        if widget
          widget.querySelector(".mb-url").value = target.getAttribute("href").to_s
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

    version = AutoRun.untraced { BrowserGems.install(name) }
    "#{name} #{version}"
  rescue BrowserGems::NativeGemError => e
    # the gem with C code may be a dependency of the one asked for
    message = e.message == name ? format(ui["nativeGem"], name) : format(ui["nativeDep"], name, e.message)
    raise BrowserGems::NativeGemError, message
  rescue BrowserGems::NotFoundError
    raise BrowserGems::NotFoundError, format(ui["gemNotFound"], name)
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

  def add_image(data_url)
    @run_images << data_url if @run_images
  end

  # the first bytes of the picture formats a browser shows
  IMAGE_SIGNATURES = {
    "\x89PNG".b => "image/png", "\xFF\xD8\xFF".b => "image/jpeg",
    "GIF8".b => "image/gif", "RIFF".b => "image/webp"
  }.freeze

  # show_image's argument as a data: URL - a picture's bytes, or the name of
  # a file the cell wrote (virtual, or real: File.binwrite, ChunkyPNG#save)
  def image_data_url(image)
    return image.to_data_url if image.respond_to?(:to_data_url)

    bytes = image.respond_to?(:to_bytes) ? image.to_bytes.b : image.to_s.b
    unless IMAGE_SIGNATURES.any? { |magic, _type| bytes.start_with?(magic) }
      name = image.to_s
      bytes = (SandboxFS.virtual?(name) && SandboxFS.exist?(name) ? SandboxFS.read(name) : File.binread(name)).b
    end
    type = IMAGE_SIGNATURES.find { |magic, _type| bytes.start_with?(magic) }&.last || "image/png"
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

  # ---------- downloads ----------

  DOWNLOAD_TYPES = {
    ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".png" => "image/png", ".jpg" => "image/jpeg", ".svg" => "image/svg+xml",
    ".csv" => "text/csv", ".json" => "application/json", ".html" => "text/html",
    ".txt" => "text/plain", ".md" => "text/markdown", ".zip" => "application/zip",
    ".pdf" => "application/pdf"
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
  # the lesson has required Shoes -- which happens inside a cell. Cells run
  # synchronously, and JS::RequireRemote needs an async context, so the
  # source is fetched with the same synchronous XHR the gem installer uses.
  def shoes_dom_loaded?
    return true if defined?(ShoesDom)

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
        <canvas id="three-canvas-#{tid}" width="#{spec[:width]}" height="#{spec[:height]}"></canvas>
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
          <input class="mb-url" value="#{escape_html(path)}" spellcheck="false" title="URL">
          <button type="button" class="mb-go">#{ui["browserGo"]}</button>
          <span class="mb-status"></span>
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
    view = widget.querySelector(".mb-view")
    begin
      status, headers, body = RackPlayground.get(app, path)
      content_type = (headers["content-type"] || headers["Content-Type"]).to_s
      status_el.innerText = status.to_s
      status_el.className = "mb-status #{status < 400 ? 'ok' : 'err'}"
      view.innerHTML = content_type.empty? || content_type.include?("html") ? body : "<pre>#{escape_html(body)}</pre>"
    rescue Exception => e
      status_el.innerText = "ERR"
      status_el.className = "mb-status err"
      view.innerHTML = "<pre class=\"mb-error\">#{escape_html("#{e.class}: #{e.message}")}</pre>"
    end
  end

  # ---------- IRB terminal widget ----------

  def add_irb
    @run_irbs << true if @run_irbs
  end

  def irb_prompt(session)
    depth = session[:buffer].empty? ? 0 : session[:buffer].lines.length
    format("irb(main):%03d:%d%s", session[:line], depth, depth.positive? ? "*" : ">")
  end

  def irb_widget_html(sid)
    <<~HTML
      <div class="irb-term" data-sid="#{sid}">
        <div class="irb-history"></div>
        <div class="irb-line">
          <span class="irb-prompt">irb(main):001:0&gt;</span>
          <input class="irb-input" spellcheck="false" autocomplete="off" title="irb">
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
        append += "<pre class=\"irb-stdout\">#{escape_html(buffer.string)}</pre>" unless buffer.string.empty?
        if error
          append += "<div class=\"irb-error\">#{escape_html("#{error.class}: #{error.message.lines.first.to_s.strip}")}</div>"
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

  # ---------- running cells ----------

  def error_line(error, file = EVAL_FILE)
    source = error.is_a?(SyntaxError) ? error.message.to_s : (error.backtrace || []).join("\n")
    match = source[/(?:\A|[\s(])#{Regexp.escape(file)}:(\d+)/, 1]
    match && match.to_i
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
  def finish_cell_run(idx, auto = false)
    started = $window.performance.now
    AutoRun.library_time = 0.0
    outcome = begin
      run_cell(idx, auto: auto)
    rescue Exception => e
      $window.console.error("run_cell #{idx}: #{e.class}: #{e.message}")
      :error
    ensure
      end_rehearsal
    end
    elapsed = ($window.performance.now - started) / 1000.0
  ensure
    # +own+: without installing and loading gems, for the shell's "too slow
    # for live runs"
    own = elapsed ? [elapsed - AutoRun.library_time, 0.0].max : -1
    bridge.ran(idx, (outcome || :error).to_s, elapsed || -1, auto, own)
    bridge.gems(installed_json)
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

  def run_cell(idx, auto: false)
    # the workshop's editor holds a whole program: one plain code cell
    cell = workshop? ? { "t" => "c" } : cells[idx]
    return unless cell && code_cell?(cell)
    code = $window.getCellCode(idx)
    store(code_key(current_lesson["id"], idx), code) unless workshop?
    # a live run starts only for code that parses - otherwise the output
    # stays as it is (autorun.rb)
    return :skipped if auto && !AutoRun.runnable?(code, workshop? ? [] : @bind.local_variables)

    if workshop?
      # the shell's callbacks (shell/workspace.rb), across the two Rubies
      file = $window.workshopOpenPath.to_s
      Workshop.prepare(JSON.parse($window.workspaceSnapshot.to_s), file, code)
      fresh_binding   # each run of a program starts from scratch
    else
      file = EVAL_FILE
    end
    # a live run keeps no file it writes: the lesson's virtual ones come back
    lesson_files = SandboxFS.store.transform_values(&:dup) if auto && !workshop?
    $window.clearCellMarks(idx)
    @run_images = []
    @run_pdfs = []
    @run_browsers = []
    @run_irbs = []
    @run_files = []
    @run_three = []
    @run_shoes = []
    @last_shoes_types = []
    dispose_shoes(idx)
    @run_downloads = []
    @download_urls ||= {}
    dispose_three(idx)
    watch = FileWatch.snapshot

    error = nil
    result = nil
    old_stdout = $stdout
    buffer = StringIO.new
    $stdout = buffer
    @auto_run = auto
    begin
      result = if auto
        AutoRun.with_time_limit(workshop? ? Workshop.paths : [file]) { evaluate(code, file) }
      else
        evaluate(code, file)
      end
    rescue Exception => e
      error = e
    ensure
      $stdout = old_stdout
      @auto_run = false
    end
    output = buffer.string
    # files the code wrote come first; an explicit download_file of the same
    # name replaces its entry
    explicit = @run_downloads
    @run_downloads = []
    changes = FileWatch.changes_since(watch)
    changes.each { |path, bytes| add_download(path, bytes) }
    explicit.each { |name, bytes| add_download(name, bytes) }
    # a rehearsal keeps nothing (end_rehearsal); what it wrote is still
    # shown and offered
    @rehearsal = [changes, watch, lesson_files] if auto
    if workshop?
      where = error && Workshop.location(error, file)
      # pictures and PDFs the program wrote show up below the editor - unless
      # it showed them itself (show_image, show_pdf)
      Workshop.previews(changes).each do |path, bytes|
        if Workshop.pdf?(path)
          @run_pdfs << bytes.b unless @run_pdfs.include?(bytes.b)
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
    out_html += "<pre class=\"cell-stdout\">#{escape_html(output)}</pre>" unless output.empty?
    widgets_present = @run_images.any? || @run_browsers.any? || @run_irbs.any? || @run_three.any? ||
                      @run_shoes.any? || @run_downloads.any? || @run_pdfs.any?
    if (hint = live_hint(error))
      out_html += "<div class=\"cell-hint\">#{escape_html(hint)}</div>"
    elsif error
      out_html += "<div class=\"cell-error\">#{escape_html(error.class)}: #{escape_html(error.message)}" \
                  "#{where ? " (#{escape_html(where)})" : ""}</div>"
    elsif !(result.nil? && (!output.empty? || widgets_present))
      out_html += "<div class=\"cell-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
    end
    @run_images.each do |data_url|
      out_html += "<img class=\"cell-image\" alt=\"\" src=\"#{data_url}\">"
    end
    out_html += pdfs_html(idx)
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
      @irb_sessions << { bind: eval("proc { binding }.call", TOPLEVEL_BINDING), line: 1, buffer: "" }
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

  def evaluate(code, file)
    if workshop?
      Workshop.with_io(file, $window.workshopStdin.to_s) { eval(code, @bind, file) }
    else
      eval(code, @bind, file)
    end
  end

  # what a live run says instead of an error when it stopped or wants ▶
  def live_hint(error)
    return ui["liveStopped"] if error.is_a?(AutoRun::Stopped)
    return ui["liveNeedsRun"] if error.is_a?(AutoRun::NeedsRun)

    nil
  end

  # true when the exercise's check passes; the shell marks the lesson done
  # and has Chunky say so
  def check_exercise(cell, code, output, result)
    @bind.local_variable_set(:output, output)
    @bind.local_variable_set(:result, result)
    @bind.local_variable_set(:code, code)
    @bind.local_variable_set(:images, (@run_images || []).dup)
    @bind.local_variable_set(:downloads, (@run_downloads || []).map(&:first))
    @bind.local_variable_set(:scenes, (@run_three || []).map { |spec| spec[:scene] })
    @bind.local_variable_set(:apps, (@run_shoes || []).length)
    @bind.local_variable_set(:shoes_types, (@last_shoes_types || []).dup)
    !!eval(cell["check"], @bind, "check.rb")
  rescue Exception
    false
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
  #   show_image "sonne.jpg"    # a file the cell wrote
  def show_image(image)
    app = ChunkyApp.instance
    app.add_image(app.image_data_url(image))
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
