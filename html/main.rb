app_path = __FILE__
$0 = File::basename(app_path, ".rb") if app_path

require 'js'
require 'js/require_remote'
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

Net::HTTP.transport = lambda do |_method, uri|
  prefix = NET_HTTP_HOSTS[uri.host.to_s.downcase]
  unless prefix
    raise SocketError, "#{uri.host} is not reachable from this browser playground " \
                       "(allowed: #{NET_HTTP_HOSTS.keys.join(', ')}) - on your own " \
                       "computer net/http can reach any URL"
  end
  data = JSON.parse(JS.global.fetchHttpSync(prefix + uri.request_uri.to_s).to_s)
  raise SocketError, "connection to #{uri.host} failed" if data["status"].to_i.zero?
  [data["status"].to_i, { "content-type" => data["contentType"].to_s }, data["body"].to_s]
end

# "Ruby lernen mit Chunky Bacon" - a notebook-style browser Ruby course built
# on the same ruby.wasm setup as BrowserRubyKoans (koans.idogawa.com).
# Lessons are sequences of text blocks and runnable code cells; all cells of
# a lesson share one binding (like a notebook kernel) and each cell shows the
# value of its last expression as "=> ..." so puts is never required.
class ChunkyApp
  include Singleton

  EVAL_FILE = "chunky.rb"

  def initialize
    $window = JS.global
    $d = JS.global[:document]
    @data = JSON.parse(JS.global[:LESSONS_JSON].to_s)
    @lessons = @data["lessons"]
    @lang = stored("chunky_lang", "de")
    @lang = "de" unless @data["ui"].key?(@lang)
    @browser_apps = []
    @irb_sessions = []
    @three_renderers = {}
    @three_seq = 0
    @shoes_apps = {}
    @workshop = workshop_hash?
    setup_elements
    # show the app BEFORE building cells: CodeMirror measures its container
    # at init, and inside a display:none #app it measures zero and renders
    # blank until something forces a re-measure (the Ctrl+Shift+R bug)
    $d.getElementById("spinner")[:style][:display] = "none"
    $d.getElementById("app")[:style][:display] = "block"
    render_all
    # A bare URL still names its lesson afterwards, without a history entry.
    unless hash_lesson_id || workshop?
      $window[:history].replaceState(nil, "", "##{current_lesson["id"]}")
    end
    show_bubble(workshop? ? ui["workshopWelcome"] : ui["welcome"], nil)
    $window.refreshAllCells
  end

  # ---------- helpers ----------

  def ui
    @data["ui"][@lang]
  end

  def stored(key, default = "")
    value = $window[:localStorage].getItem(key).to_s
    (value.empty? || value == "null") ? default : value
  end

  def store(key, value)
    $window[:localStorage].setItem(key, value)
  end

  def done_ids
    JSON.parse(stored("chunky_done", "[]"))
  rescue
    []
  end

  def mark_done(id)
    ids = done_ids
    unless ids.include?(id)
      ids << id
      store("chunky_done", JSON.generate(ids))
    end
  end

  # The URL names the lesson (/#scarpe), so a lesson can be linked, opened
  # in a new tab, bookmarked, and reached with back/forward. localStorage is
  # only the fallback for a bare URL: it brings you back where you left off.
  def current_index
    id = hash_lesson_id || stored("chunky_current", @lessons[0]["id"])
    idx = @lessons.index { |l| l["id"] == id }
    idx || 0
  end

  # The lesson id in location.hash, or nil when it names no lesson.
  def hash_lesson_id
    raw = $window[:location][:hash].to_s.delete_prefix("#")
    @lessons.any? { |l| l["id"] == raw } ? raw : nil
  end

  # Assigning location.hash adds a history entry, so back returns to the
  # previous lesson. The hashchange it causes finds that lesson already
  # rendered and does nothing.
  def set_lesson_hash(id)
    $window[:location][:hash] = id unless hash_lesson_id == id
  end

  def route_from_hash
    return open_workshop if workshop_hash? && !workshop?
    return if workshop_hash?

    id = hash_lesson_id
    if id.nil?
      # a hash naming no lesson: keep the page, correct the address bar
      current = workshop? ? WORKSHOP_ID : @rendered_lesson_id
      $window[:history].replaceState(nil, "", "##{current}") if current
    elsif workshop? || id != @rendered_lesson_id
      select_lesson(id)
    end
  end

  # The workshop is a page of its own beside the lessons, at #werkstatt.
  WORKSHOP_ID = "werkstatt"

  def workshop?
    @workshop
  end

  def workshop_hash?
    $window[:location][:hash].to_s.delete_prefix("#") == WORKSHOP_ID
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

  def exercise_index
    cells.index { |c| c["t"] == "x" }
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

  def setup_elements
    $d.getElementById("reset-code").addEventListener("click") do
      reset_lesson if $window.confirm(ui["resetConfirm"]).to_s == "true"
    end

    $d.getElementById("langSelect").addEventListener("change") do
      switch_lang($d.getElementById("langSelect")[:value].to_s)
    end

    # Nav entries are real links (#lesson-id). A plain click is handled here;
    # ctrl/cmd/shift/middle clicks are left to the browser, so "open in new
    # tab" and "copy link" behave as they do on any link.
    $d.getElementById("lessonNav").addEventListener("click") do |event|
      modified = %i[ctrlKey metaKey shiftKey altKey].any? { |k| event[k].to_s == "true" }
      next if modified || event[:button].to_i != 0

      id = event[:target].getAttribute("data-id").to_s
      next if id.empty? || id == "null"

      event.preventDefault
      select_lesson(id)
    end

    # back/forward, and a lesson id typed or pasted into the address bar
    $window.addEventListener("hashchange") { route_from_hash }

    # a progress file was loaded or a folder reconnected (storage.js): show
    # what localStorage holds now
    $window.addEventListener("chunky-progress-loaded") do
      lang = stored("chunky_lang", @lang)
      @lang = lang if @data["ui"].key?(lang)
      render_all
    end

    # one delegated listener for cell run buttons and mini-browser widgets
    $d.getElementById("lessonBody").addEventListener("click") do |event|
      target = event[:target]
      css_class = target[:className].to_s
      if css_class.include?("run-cell")
        idx = target.getAttribute("data-idx").to_s
        start_cell_run(idx.to_i) unless idx.empty? || idx == "null"
      elsif css_class.include?("mb-go")
        widget = target.closest(".mini-browser")
        navigate_browser(widget) unless js_null?(widget)
      elsif css_class.include?("fe-refresh")
        widget = target.closest(".file-explorer")
        refresh_file_widget(widget) unless js_null?(widget)
      elsif !js_null?(target.closest(".fe-file"))
        row = target.closest(".fe-file")
        widget = row.closest(".file-explorer")
        preview_file(widget, row.getAttribute("data-path").to_s) unless js_null?(widget)
      elsif target[:tagName].to_s == "A" && !js_null?(target.closest(".mb-view"))
        # links inside the fake browser navigate the fake browser
        event.preventDefault
        widget = target.closest(".mini-browser")
        unless js_null?(widget)
          widget.querySelector(".mb-url")[:value] = target.getAttribute("href").to_s
          navigate_browser(widget)
        end
      end
    end

    # Enter in a mini-browser URL bar navigates; Enter in an IRB input evals
    $d.getElementById("lessonBody").addEventListener("keydown") do |event|
      target_class = event[:target][:className].to_s
      if target_class.include?("mb-url") && event[:key].to_s == "Enter"
        event.preventDefault
        widget = event[:target].closest(".mini-browser")
        navigate_browser(widget) unless js_null?(widget)
      elsif target_class.include?("irb-input") && event[:key].to_s == "Enter"
        event.preventDefault
        term = event[:target].closest(".irb-term")
        irb_submit(term) unless js_null?(term)
      end
    end

    # delegated listener for the "next lesson" link inside the chat bubble
    $d.getElementById("chunkyChat").addEventListener("click") do |event|
      if event[:target][:id].to_s == "nextLessonLink"
        event.preventDefault
        go_to_next_lesson
      end
    end

    $window.addEventListener("keydown") do |event|
      if event[:altKey].to_s == "true" && event[:key].to_s == "r"
        event.preventDefault
        idx = exercise_index
        run_cell(idx) if idx
      end
    end

    # gems panel: chip click installs that gem, button installs typed name
    $d.getElementById("gemsList").addEventListener("click") do |event|
      name = event[:target].getAttribute("data-gem").to_s
      panel_install(name) unless name.empty? || name == "null"
    end
    $d.getElementById("gemInstallBtn").addEventListener("click") do
      name = $d.getElementById("gemNameInput")[:value].to_s.strip
      panel_install(name) unless name.empty?
    end
  end

  # ---------- rendering ----------

  def render_all
    $d[:documentElement].setAttribute("lang", @lang)
    $d[:title] = ui["title"]
    $d.getElementById("siteTitle")[:innerText] = ui["title"]
    $d.getElementById("siteSubtitle")[:innerText] = ui["subtitle"]
    $d.getElementById("reset-code")[:innerText] = ui["reset"]
    $d.getElementById("footerCredit")[:innerHTML] = ui["footerCredit"]
    $d.getElementById("footerLicense")[:innerHTML] = ui["footerLicense"]
    $d.getElementById("langSelect")[:value] = @lang
    render_gems_panel
    render_nav
    render_lesson
  end

  def render_gems_panel
    $d.getElementById("gemsTitle")[:innerText] = ui["gemsTitle"]
    $d.getElementById("gemInstallBtn")[:innerText] = ui["gemsInstallBtn"]
    $d.getElementById("gemsNote")[:innerHTML] = ui["gemsNote"]
    names = (BrowserGems.manifest.keys + BrowserGems.installed.keys).uniq
    html = names.map do |name|
      version = BrowserGems.installed[name]
      css_class = version ? "gem-chip installed" : "gem-chip"
      label = version ? "#{name} ✓" : "#{name} ⚡"
      "<button type=\"button\" class=\"#{css_class}\" data-gem=\"#{name}\" title=\"#{version || ui["gemsCachedTip"]}\">#{label}</button>"
    end.join
    $d.getElementById("gemsList")[:innerHTML] = html
  end

  def render_nav
    done = done_ids
    active_id = current_lesson["id"]
    html = @lessons.map do |lesson|
      classes = []
      classes << "active" if lesson["id"] == active_id && !workshop?
      classes << "done" if done.include?(lesson["id"])
      section = lesson["section"] ? "<div class=\"nav-section\">#{lesson["section"][@lang] || lesson["section"]["de"]}</div>" : ""
      "#{section}<a class=\"#{classes.join(' ')}\" href=\"##{lesson["id"]}\" data-id=\"#{lesson["id"]}\">#{l10n(lesson)["title"]}</a>"
    end.join
    $d.getElementById("lessonNav")[:innerHTML] = html
    link = $d.getElementById("workshopLink")
    link[:textContent] = ui["workshopNav"]
    link[:className] = workshop? ? "workshop-link active" : "workshop-link"
  end

  def render_lesson
    fresh_binding
    dispose_three
    dispose_shoes
    $d[:body][:classList].toggle("in-workshop", workshop?)
    $d.getElementById("reset-code")[:hidden] = workshop?
    return render_workshop if workshop?

    lesson_id = current_lesson["id"]
    preload_three if cells.any? { |c| code_cell?(c) && c["code"].to_s.include?("show_three") }
    @rendered_lesson_id = lesson_id
    # the lesson in the tab title makes bookmarks and history entries legible
    $d[:title] = "#{l10n(current_lesson)["title"]} – #{ui["title"]}"
    html = cells.each_with_index.map do |cell, idx|
      if code_cell?(cell)
        exercise = cell["t"] == "x"
        <<~HTML
          <div class="cell#{exercise ? ' exercise' : ''}" data-label="#{ui["taskLabel"]}">
            <textarea title="code" id="cell-code-#{idx}"></textarea>
            <div class="cell-toolbar"><button type="button" class="run-cell" data-idx="#{idx}">#{ui["runCell"]}</button></div>
            <div class="cell-out" id="cell-out-#{idx}" style="display:none"></div>
          </div>
        HTML
      else
        "<div class=\"lessonText\">#{cell["html"]}</div>"
      end
    end.join
    $d.getElementById("lessonBody")[:innerHTML] = html
    cells.each_with_index do |cell, idx|
      next unless code_cell?(cell)
      $window.initCell(idx)
      $window.setCellCode(idx, stored(code_key(lesson_id, idx), cell["code"]))
    end
  end

  # The workshop's frame: the file panel (#wsFiles) and the stdin box are
  # filled by workspace_ui.js, the editor is cell 0 like in a lesson.
  def render_workshop
    @rendered_lesson_id = nil
    $d[:title] = "#{ui["workshopTitle"]} – #{ui["title"]}"
    $d.getElementById("lessonBody")[:innerHTML] = <<~HTML
      <div class="lessonText"><h2>#{ui["workshopTitle"]}</h2><p>#{ui["workshopIntro"]}</p></div>
      <div class="workshop">
        <aside class="ws-files" id="wsFiles"></aside>
        <div class="cell ws-editor">
          <div class="ws-tab" id="wsTab"></div>
          <textarea title="code" id="cell-code-0"></textarea>
          <div class="ws-stdin" id="wsStdinBox"></div>
          <div class="cell-toolbar"><button type="button" class="run-cell" data-idx="0">#{ui["runCell"]}</button></div>
          <div class="cell-out" id="cell-out-0" style="display:none"></div>
        </div>
      </div>
    HTML
    $window.initCell(0)
    $window.workshopMount
  end

  def open_workshop
    @workshop = true
    $window[:location][:hash] = WORKSHOP_ID unless workshop_hash?
    render_nav
    render_lesson
    show_bubble(ui["workshopWelcome"], nil)
    $window.scrollTo(0, 0)
  end

  def show_bubble(html, state)
    chat = $d.getElementById("chunkyChat")
    chat[:className] = state.to_s
    $d.getElementById("chunkyText")[:innerHTML] = html
    chat[:style][:display] = "flex"
  end

  # ---------- actions ----------

  def select_lesson(id)
    return open_workshop if id == WORKSHOP_ID

    @workshop = false
    store("chunky_current", id)
    set_lesson_hash(id)
    render_nav
    render_lesson
    show_bubble(ui["welcome"], nil)
    # a new lesson starts at its top, wherever the old one was scrolled to
    # (on phones the index sits below the lesson)
    $window.scrollTo(0, 0)
  end

  def go_to_next_lesson
    idx = current_index
    select_lesson(@lessons[idx + 1]["id"]) if idx + 1 < @lessons.length
  end

  def switch_lang(lang)
    return unless @data["ui"].key?(lang)
    @lang = lang
    store("chunky_lang", lang)
    render_all
    show_bubble(ui["welcome"], nil)
  end

  def reset_lesson
    lesson_id = current_lesson["id"]
    cells.each_with_index do |cell, idx|
      next unless code_cell?(cell)
      $window[:localStorage].removeItem(code_key(lesson_id, idx))
      $window.setCellCode(idx, cell["code"])
      $d.getElementById("cell-out-#{idx}")[:style][:display] = "none"
    end
    dispose_three
    dispose_shoes
    fresh_binding
    show_bubble(ui["welcome"], nil)
  end

  # ---------- gems ----------

  def install_gem_ui(name)
    version = BrowserGems.install(name)
    render_gems_panel
    "#{name} #{version}"
  rescue BrowserGems::NativeGemError => e
    # the gem with C code may be a dependency of the one asked for
    message = e.message == name ? format(ui["nativeGem"], name) : format(ui["nativeDep"], name, e.message)
    raise BrowserGems::NativeGemError, message
  rescue BrowserGems::NotFoundError
    raise BrowserGems::NotFoundError, format(ui["gemNotFound"], name)
  end

  def panel_install(name)
    result = install_gem_ui(name)
    show_bubble(format(ui["gemInstalled"], result), "pass")
  rescue StandardError => e
    show_bubble(escape_html(e.message), "fail")
  end

  def add_image(data_url)
    @run_images << data_url if @run_images
  end

  def add_pdf(bytes)
    @run_pdfs << bytes.to_s.b if @run_pdfs
  end

  # The browser's own PDF viewer, on a Blob URL; the previous run's URLs of
  # this cell are released first.
  def pdfs_html(idx)
    @pdf_urls ||= {}
    (@pdf_urls[idx] || []).each { |url| $window[:URL].revokeObjectURL(url) }
    @pdf_urls[idx] = @run_pdfs.map { |bytes| $window.makeDownloadUrl([bytes].pack("m0"), "application/pdf").to_s }
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
    (@download_urls[idx] || []).each { |url| $window[:URL].revokeObjectURL(url) }
    @download_urls[idx] = []
    links = @run_downloads.map do |name, bytes|
      type = DOWNLOAD_TYPES.fetch(File.extname(name).downcase, "application/octet-stream")
      url = $window.makeDownloadUrl([bytes].pack("m0"), type).to_s
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
    widget.querySelector(".fe-list")[:innerHTML] = files_list_html
    widget.querySelector(".fe-preview")[:style][:display] = "none"
  end

  def preview_file(widget, path)
    preview = widget.querySelector(".fe-preview")
    content = begin
      SandboxFS.read(path)
    rescue StandardError
      "?"
    end
    preview[:textContent] = content
    preview[:style][:display] = "block"
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

    source = $window.fetchTextSync("shoes_dom.rb").to_s
    raise LoadError, "could not fetch shoes_dom.rb" if source.start_with?("ERROR ")

    eval(source, TOPLEVEL_BINDING, "shoes_dom.rb")
    true
  rescue StandardError, ScriptError => e
    $window[:console].call(:log, "shoes_dom load failed: #{e.class}: #{e.message}")
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
    node = $d.call(:createElement, "div")
    node[:className] = "cell-error"
    node[:textContent] = "#{e.class}: #{e.message}"
    node
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
    $window[:threeReady].to_s == "true"
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
          renderer.handle.call(:setAnimationLoop, JS::Null)
          controls&.dispose
          renderer.handle.call(:dispose)
        rescue StandardError
          nil
        end
      end
    end
  end

  def mount_three(idx, tid, spec)
    canvas = $d.getElementById("three-canvas-#{tid}")
    return if js_null?(canvas)

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

  def js_null?(obj)
    obj.nil? || obj.to_s == "null" || obj.to_s == "undefined"
  end

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
    bid = widget.getAttribute("data-bid").to_s.to_i
    app = @browser_apps[bid]
    return unless app
    input = widget.querySelector(".mb-url")
    path = input[:value].to_s
    path = "/" + path unless path.start_with?("/")
    input[:value] = path
    status_el = widget.querySelector(".mb-status")
    view = widget.querySelector(".mb-view")
    begin
      status, headers, body = RackPlayground.get(app, path)
      content_type = (headers["content-type"] || headers["Content-Type"]).to_s
      status_el[:innerText] = status.to_s
      status_el[:className] = "mb-status #{status < 400 ? 'ok' : 'err'}"
      if content_type.empty? || content_type.include?("html")
        view[:innerHTML] = body
      else
        view[:innerHTML] = "<pre>#{escape_html(body)}</pre>"
      end
    rescue Exception => e
      status_el[:innerText] = "ERR"
      status_el[:className] = "mb-status err"
      view[:innerHTML] = "<pre class=\"mb-error\">#{escape_html("#{e.class}: #{e.message}")}</pre>"
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
    sid = term.getAttribute("data-sid").to_s.to_i
    session = @irb_sessions[sid]
    return unless session
    input_el = term.querySelector(".irb-input")
    history = term.querySelector(".irb-history")
    line = input_el[:value].to_s
    input_el[:value] = ""

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

    history[:innerHTML] = history[:innerHTML].to_s + append
    term.querySelector(".irb-prompt")[:innerText] = irb_prompt(session)
    history[:scrollTop] = history[:scrollHeight]
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
  # repaint -- a gem install used to be seconds of frozen page. The running
  # state is therefore put on screen *before* the run: afterPaint (index.html)
  # waits until that frame has been drawn, and only then does Ruby block.
  # What moves during the run is limited to transform and opacity, which the
  # browser animates off the main thread, so it keeps moving while Ruby works.
  def start_cell_run(idx)
    @running ||= {}
    return if @running[idx]

    cell_el, button = cell_parts(idx)
    return if js_null?(button)

    @running[idx] = true
    begin
      unless js_null?(cell_el)
        cell_el[:classList].remove("shake", "celebrate")
        cell_el[:classList].add("running")
      end
      button[:disabled] = true
      button[:innerHTML] = %(<img class="run-fox" src="assets/chunky.svg" alt="">#{ui["running"]})
      $window.afterPaint(proc { finish_cell_run(idx) })
    rescue StandardError => e
      # the running look is decoration: if it fails, still run the cell
      $window[:console].call(:error, "running state #{idx}: #{e.class}: #{e.message}")
      finish_cell_run(idx)
    end
  end

  def finish_cell_run(idx)
    started = $window[:performance].now.to_f
    outcome = begin
      run_cell(idx)
    rescue Exception => e
      $window[:console].call(:error, "run_cell #{idx}: #{e.class}: #{e.message}")
      :error
    end
    elapsed = ($window[:performance].now.to_f - started) / 1000.0
  ensure
    @running&.delete(idx)
    settle_cell(idx, outcome, elapsed)
  end

  def settle_cell(idx, outcome, elapsed)
    cell_el, button = cell_parts(idx)
    unless js_null?(button)
      button[:disabled] = false
      button[:textContent] = ui["runCell"]
    end
    return if js_null?(cell_el)

    cell_el[:classList].remove("running")
    replay(cell_el, "shake") if outcome == :error
    replay(cell_el, "celebrate") if outcome == :pass
    out_el = $d.getElementById("cell-out-#{idx}")
    replay(out_el, "reveal") unless js_null?(out_el)
    show_run_time(cell_el, elapsed) if elapsed
  end

  # Re-adding a class does not restart its animation; reading a layout
  # property in between forces the browser to see the removal first.
  def replay(el, css_class)
    el[:classList].remove(css_class)
    el[:offsetWidth]
    el[:classList].add(css_class)
  end

  def show_run_time(cell_el, seconds)
    toolbar = cell_el.querySelector(".cell-toolbar")
    return if js_null?(toolbar)

    stamp = toolbar.querySelector(".run-time")
    if js_null?(stamp)
      stamp = $d.createElement("span")
      stamp[:className] = "run-time"
      toolbar.insertBefore(stamp, toolbar[:firstChild])
    end
    text = seconds < 0.1 ? "< 0.1 s" : format("%.1f s", seconds)
    stamp[:textContent] = @lang == "de" ? text.tr(".", ",") : text
    replay(stamp, "fresh")
  end

  def cell_parts(idx)
    button = $d.querySelector(".run-cell[data-idx='#{idx}']")
    cell_el = js_null?(button) ? nil : button.closest(".cell")
    [cell_el, button]
  end

  def run_cell(idx)
    # the workshop's editor holds a whole program: one plain code cell
    cell = workshop? ? { "t" => "c" } : cells[idx]
    return unless cell && code_cell?(cell)
    code = $window.getCellCode(idx).to_s
    if workshop?
      file = $window.workshopOpenPath.to_s
      Workshop.prepare(JSON.parse($window.workspaceSnapshot.to_s), file, code)
      fresh_binding   # each run of a program starts from scratch
    else
      file = EVAL_FILE
      store(code_key(current_lesson["id"], idx), code)
    end
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
    begin
      result = if workshop?
        Workshop.with_io(file, $window.workshopStdin.to_s) { eval(code, @bind, file) }
      else
        eval(code, @bind, file)
      end
    rescue Exception => e
      error = e
    ensure
      $stdout = old_stdout
    end
    output = buffer.string
    # files the code wrote come first; an explicit download_file of the same
    # name replaces its entry
    explicit = @run_downloads
    @run_downloads = []
    FileWatch.changes_since(watch).each { |path, bytes| add_download(path, bytes) }
    explicit.each { |name, bytes| add_download(name, bytes) }
    if workshop?
      where = error && Workshop.location(error, file)
      # what the program wrote goes into its project, next to the downloads
      Workshop.finish.each do |path, text|
        text ? $window.workspaceWrite(path, text) : $window.workspaceDelete(path)
      end
      $window.workshopAfterRun
    end

    out_html = ""
    out_html += "<pre class=\"cell-stdout\">#{escape_html(output)}</pre>" unless output.empty?
    widgets_present = @run_images.any? || @run_browsers.any? || @run_irbs.any? || @run_three.any? ||
                      @run_shoes.any? || @run_downloads.any? || @run_pdfs.any?
    if error
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
    out_el[:innerHTML] = out_html
    out_el[:style][:display] = "block"
    new_widgets.each do |bid|
      widget = out_el.querySelector(".mini-browser[data-bid='#{bid}']")
      navigate_browser(widget) unless js_null?(widget)
    end
    new_stages.each { |tid, spec| mount_three(idx, tid, spec) }
    # Shoes apps are built as detached DOM and appended, rather than written
    # into out_html, because the display service creates real elements with
    # real event handlers as the app's block runs.
    @run_shoes.each do |spec|
      out_el.call(:appendChild, build_shoes_stage(idx, spec))
    end

    if error
      line = error_line(error, file)
      $window.markCellLine(idx, line) if line
      show_bubble(ui["errorIntro"], "fail") if cell["t"] == "x"
      return :error
    end

    return :ok unless cell["t"] == "x"

    check_exercise(cell, code, output, result) ? :pass : :fail
  end

  def check_exercise(cell, code, output, result)
    @bind.local_variable_set(:output, output)
    @bind.local_variable_set(:result, result)
    @bind.local_variable_set(:code, code)
    @bind.local_variable_set(:images, (@run_images || []).dup)
    @bind.local_variable_set(:downloads, (@run_downloads || []).map(&:first))
    @bind.local_variable_set(:scenes, (@run_three || []).map { |spec| spec[:scene] })
    @bind.local_variable_set(:apps, (@run_shoes || []).length)
    @bind.local_variable_set(:shoes_types, (@last_shoes_types || []).dup)
    passed = begin
      !!eval(cell["check"], @bind, "check.rb")
    rescue Exception
      false
    end

    if passed
      mark_done(current_lesson["id"])
      render_nav
      praise = ui["praise"][rand(ui["praise"].length)]
      idx = current_index
      if done_ids.length >= @lessons.length
        show_bubble("#{praise}<br><br>#{ui["allDone"]}", "pass")
      elsif idx + 1 < @lessons.length
        progress = format(ui["progress"], idx + 1, @lessons.length)
        next_id = @lessons[idx + 1]["id"]
        show_bubble("#{praise}<br><small>#{progress}</small><br><a href=\"##{next_id}\" id=\"nextLessonLink\">#{ui["nextLesson"]}</a>", "pass")
      else
        show_bubble(praise, "pass")
      end
    else
      show_bubble("#{ui["failIntro"]}<br>💡 #{cell["hint"]}", "fail")
    end
    passed
  end
end

# helpers available inside notebook cells
module Kernel
  def install_gem(name)
    ChunkyApp.instance.install_gem_ui(name)
  end

  def show_image(image)
    data_url = if image.respond_to?(:to_data_url)
                 image.to_data_url
               else
                 "data:image/png;base64," + [image.to_s].pack("m0")
               end
    ChunkyApp.instance.add_image(data_url)
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
