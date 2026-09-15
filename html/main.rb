app_path = __FILE__
$0 = File::basename(app_path, ".rb") if app_path

require 'js'
require 'js/require_remote'
require 'json'
require 'stringio'
require 'singleton'

# require_relative bridge (pattern from BrowserRubyKoans): builtin files
# first, gem-space files for code loaded by BrowserGems, remote URL fetch
# for our own source files (browser_gems.rb).
module Kernel
  alias original_require_relative require_relative
  def require_relative(path)
    location = caller_locations(1, 1).first
    caller_path = (location.absolute_path || location.path).to_s
    if caller_path.start_with?("/browser_gems/")
      BrowserGems.load_feature(BrowserGems.relative_key(caller_path, path)) or
        raise LoadError, "cannot load such file -- #{path}"
    else
      begin
        original_require_relative(File.absolute_path(path, File.dirname(caller_path)))
      rescue LoadError
        JS::RequireRemote.instance.load(path)
      end
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
    setup_elements
    # show the app BEFORE building cells: CodeMirror measures its container
    # at init, and inside a display:none #app it measures zero and renders
    # blank until something forces a re-measure (the Ctrl+Shift+R bug)
    $d.getElementById("spinner")[:style][:display] = "none"
    $d.getElementById("app")[:style][:display] = "block"
    render_all
    show_bubble(ui["welcome"], nil)
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

  def current_index
    id = stored("chunky_current", @lessons[0]["id"])
    idx = @lessons.index { |l| l["id"] == id }
    idx || 0
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

    # one delegated listener for the lesson navigation
    $d.getElementById("lessonNav").addEventListener("click") do |event|
      event.preventDefault
      id = event[:target].getAttribute("data-id").to_s
      select_lesson(id) unless id.empty? || id == "null"
    end

    # one delegated listener for cell run buttons and mini-browser widgets
    $d.getElementById("lessonBody").addEventListener("click") do |event|
      target = event[:target]
      css_class = target[:className].to_s
      if css_class.include?("run-cell")
        idx = target.getAttribute("data-idx").to_s
        run_cell(idx.to_i) unless idx.empty? || idx == "null"
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
      classes << "active" if lesson["id"] == active_id
      classes << "done" if done.include?(lesson["id"])
      section = lesson["section"] ? "<div class=\"nav-section\">#{lesson["section"][@lang] || lesson["section"]["de"]}</div>" : ""
      "#{section}<a class=\"#{classes.join(' ')}\" data-id=\"#{lesson["id"]}\">#{l10n(lesson)["title"]}</a>"
    end.join
    $d.getElementById("lessonNav")[:innerHTML] = html
  end

  def render_lesson
    fresh_binding
    lesson_id = current_lesson["id"]
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

  def show_bubble(html, state)
    chat = $d.getElementById("chunkyChat")
    chat[:className] = state.to_s
    $d.getElementById("chunkyText")[:innerHTML] = html
    chat[:style][:display] = "flex"
  end

  # ---------- actions ----------

  def select_lesson(id)
    store("chunky_current", id)
    render_nav
    render_lesson
    show_bubble(ui["welcome"], nil)
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
    fresh_binding
    show_bubble(ui["welcome"], nil)
  end

  # ---------- gems ----------

  def install_gem_ui(name)
    version = BrowserGems.install(name)
    render_gems_panel
    "#{name} #{version}"
  rescue BrowserGems::NativeGemError
    raise BrowserGems::NativeGemError, format(ui["nativeGem"], name)
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

  def error_line(error)
    source = error.is_a?(SyntaxError) ? error.message.to_s : (error.backtrace || []).join("\n")
    match = source[/#{EVAL_FILE}:(\d+)/, 1]
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

  def run_cell(idx)
    cell = cells[idx]
    return unless cell && code_cell?(cell)
    code = $window.getCellCode(idx).to_s
    store(code_key(current_lesson["id"], idx), code)
    $window.clearCellMarks(idx)
    @run_images = []
    @run_browsers = []
    @run_irbs = []
    @run_files = []

    error = nil
    result = nil
    old_stdout = $stdout
    buffer = StringIO.new
    $stdout = buffer
    begin
      result = eval(code, @bind, EVAL_FILE)
    rescue Exception => e
      error = e
    ensure
      $stdout = old_stdout
    end
    output = buffer.string

    out_html = ""
    out_html += "<pre class=\"cell-stdout\">#{escape_html(output)}</pre>" unless output.empty?
    widgets_present = @run_images.any? || @run_browsers.any? || @run_irbs.any?
    if error
      out_html += "<div class=\"cell-error\">#{escape_html(error.class)}: #{escape_html(error.message)}</div>"
    elsif !(result.nil? && (!output.empty? || widgets_present))
      out_html += "<div class=\"cell-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
    end
    @run_images.each do |data_url|
      out_html += "<img class=\"cell-image\" alt=\"\" src=\"#{data_url}\">"
    end
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
    out_el = $d.getElementById("cell-out-#{idx}")
    out_el[:innerHTML] = out_html
    out_el[:style][:display] = "block"
    new_widgets.each do |bid|
      widget = out_el.querySelector(".mini-browser[data-bid='#{bid}']")
      navigate_browser(widget) unless js_null?(widget)
    end

    if error
      line = error_line(error)
      $window.markCellLine(idx, line) if line
      show_bubble(ui["errorIntro"], "fail") if cell["t"] == "x"
      return
    end

    check_exercise(cell, code, output, result) if cell["t"] == "x"
  end

  def check_exercise(cell, code, output, result)
    @bind.local_variable_set(:output, output)
    @bind.local_variable_set(:result, result)
    @bind.local_variable_set(:code, code)
    @bind.local_variable_set(:images, (@run_images || []).dup)
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
        show_bubble("#{praise}<br><small>#{progress}</small><br><a href=\"#\" id=\"nextLessonLink\">#{ui["nextLesson"]}</a>", "pass")
      else
        show_bubble(praise, "pass")
      end
    else
      show_bubble("#{ui["failIntro"]}<br>💡 #{cell["hint"]}", "fail")
    end
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

  # Renders a mini browser widget below the cell, wired to the given Rack
  # app (a Sinatra/Roda class or anything with #call).
  def show_browser(app, path = "/")
    ChunkyApp.instance.add_browser(app, path)
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
