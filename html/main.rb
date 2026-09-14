app_path = __FILE__
$0 = File::basename(app_path, ".rb") if app_path

require 'js'
require 'json'
require 'stringio'
require 'singleton'

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
    $d = JS.global.document
    @data = JSON.parse(JS.global[:LESSONS_JSON].to_s)
    @lessons = @data["lessons"]
    @lang = stored("chunky_lang", "de")
    @lang = "de" unless @data["ui"].key?(@lang)
    setup_elements
    render_all
    show_bubble(ui["welcome"], nil)
    $d.getElementById("spinner").style.display = "none"
    $d.getElementById("app").style.display = "block"
  end

  # ---------- helpers ----------

  def ui
    @data["ui"][@lang]
  end

  def stored(key, default = "")
    value = $window.localStorage.getItem(key).to_s
    (value.empty? || value == "null") ? default : value
  end

  def store(key, value)
    $window.localStorage.setItem(key, value)
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
      reset_lesson if $window.confirm(ui["resetConfirm"])
    end

    $d.getElementById("langSelect").addEventListener("change") do
      switch_lang($d.getElementById("langSelect").value.to_s)
    end

    # one delegated listener for the lesson navigation
    $d.getElementById("lessonNav").addEventListener("click") do |event|
      event.preventDefault
      id = event.target.getAttribute("data-id").to_s
      select_lesson(id) unless id.empty? || id == "null"
    end

    # one delegated listener for all cell run buttons
    $d.getElementById("lessonBody").addEventListener("click") do |event|
      if event.target[:className].to_s.include?("run-cell")
        idx = event.target.getAttribute("data-idx").to_s
        run_cell(idx.to_i) unless idx.empty? || idx == "null"
      end
    end

    # delegated listener for the "next lesson" link inside the chat bubble
    $d.getElementById("chunkyChat").addEventListener("click") do |event|
      if event.target[:id].to_s == "nextLessonLink"
        event.preventDefault
        go_to_next_lesson
      end
    end

    $window.addEventListener("keydown") do |event|
      if (event.altKey && event.key === 'r')
        event.preventDefault
        idx = exercise_index
        run_cell(idx) if idx
      end
    end
  end

  # ---------- rendering ----------

  def render_all
    $d.documentElement.setAttribute("lang", @lang)
    $d[:title] = ui["title"]
    $d.getElementById("siteTitle").innerText = ui["title"]
    $d.getElementById("siteSubtitle").innerText = ui["subtitle"]
    $d.getElementById("reset-code").innerText = ui["reset"]
    $d.getElementById("footerCredit").innerHTML = ui["footerCredit"]
    $d.getElementById("footerLicense").innerHTML = ui["footerLicense"]
    $d.getElementById("langSelect").value = @lang
    render_nav
    render_lesson
  end

  def render_nav
    done = done_ids
    active_id = current_lesson["id"]
    html = @lessons.map do |lesson|
      classes = []
      classes << "active" if lesson["id"] == active_id
      classes << "done" if done.include?(lesson["id"])
      "<a class=\"#{classes.join(' ')}\" data-id=\"#{lesson["id"]}\">#{l10n(lesson)["title"]}</a>"
    end.join
    $d.getElementById("lessonNav").innerHTML = html
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
    $d.getElementById("lessonBody").innerHTML = html
    cells.each_with_index do |cell, idx|
      next unless code_cell?(cell)
      $window.initCell(idx)
      $window.setCellCode(idx, stored(code_key(lesson_id, idx), cell["code"]))
    end
  end

  def show_bubble(html, state)
    chat = $d.getElementById("chunkyChat")
    chat[:className] = state.to_s
    $d.getElementById("chunkyText").innerHTML = html
    chat.style.display = "flex"
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
      $window.localStorage.removeItem(code_key(lesson_id, idx))
      $window.setCellCode(idx, cell["code"])
      $d.getElementById("cell-out-#{idx}").style.display = "none"
    end
    fresh_binding
    show_bubble(ui["welcome"], nil)
  end

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
    if error
      out_html += "<div class=\"cell-error\">#{escape_html(error.class)}: #{escape_html(error.message)}</div>"
    elsif !(result.nil? && !output.empty?)
      out_html += "<div class=\"cell-result\">=&gt; #{escape_html(inspect_result(result))}</div>"
    end
    out_el = $d.getElementById("cell-out-#{idx}")
    out_el.innerHTML = out_html
    out_el.style.display = "block"

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

ChunkyApp.instance
