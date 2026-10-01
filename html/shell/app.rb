# The page shell: everything the learner sees before a line of their code
# runs - header, index, lesson text and editors, language, routing, Chunky's
# bubble, the gems panel - rendered by PicoRuby within a fraction of a
# second. Running code is the kernel's job (main.rb on CRuby, 10 MB, loads
# in the background); the two meet in shell/bridge.js.
module ChunkyShell
  class App
    include Support

    attr_reader :lang, :course

    # Live runs (main.rb's AutoRun): a moment after the last key, as long as
    # a cell's runs are quick; one switch for the lessons (on unless turned
    # off), one for the workshop (off unless turned on) - view settings, so
    # "chunkyui_" and not synced
    LIVE_DELAY_MS = 1000
    LIVE_SLOW = 0.3
    LIVE_KEY = "chunkyui_live"
    LIVE_WORKSHOP_KEY = "chunkyui_live_ws"

    def initialize(data = JSG.w.LESSONS, bridge = JSG.w.ChunkyBridge)
      @course = Course.new(data)
      @bridge = bridge
      # shell/bridge.js picked it: ?lang=, the last choice, the browser's
      # languages, English; without a bridge's word, the stored choice
      @lang = bridge[:lang] || Store.get("chunky_lang", "de")
      @lang = "de" unless @course.lang?(@lang)
      @workshop = workshop_hash?
      @running = {}
      @gem_names = []
      @installed = {}
      @kernel_ready = bridge.ready == true
      @kernel_failed = bridge.failed == true
      @rendered_lesson_id = nil
      @view_gen = 0         # a new lesson drops the live runs still waiting
      @live_gen = {}        # per cell: the latest keystroke's live run
      @slow = {}            # cells whose last run took too long to run live
      @last_outcome = {}    # a live pass celebrates only when it is new
    end

    def start
      wire_events
      # the progress dialog and the workshop's files (storage.js keeps them)
      @workspace = Workspace.new(self).start
      # the page before the editors: CodeMirror measures its container when
      # it is built, and inside a display:none #app it measures zero
      el("spinner").style.display = "none"
      el("app").style.display = "block"
      render_all
      # a bare URL still names its lesson afterwards, without a history entry
      JSG.w.history.replaceState(nil, "", "##{current_lesson_id}") unless hash_lesson_id || workshop?
      show_bubble(workshop? ? ui.workshopWelcome : ui.welcome, nil)
      JSG.w.refreshAllCells
      @bridge.shellReady
      load_gem_names
      self
    end

    def ui = @course.ui(@lang)
    def workshop? = @workshop

    # ---------- events ----------

    # sync: true wherever the default must be prevented; also everywhere
    # else, because a PicoRuby listener without it runs some 40 ms later
    def wire_events
      el("reset-code").addEventListener("click", sync: true) { guard("reset") { reset_lesson if JSG.w.confirm(ui.resetConfirm) } }
      el("langSelect").addEventListener("change", sync: true) { guard("language") { switch_lang(el("langSelect").value) } }
      el("lessonNav").addEventListener("click", sync: true) { |event| guard("index") { nav_click(event) } }
      el("lessonBody").addEventListener("click", sync: true) { |event| guard("run") { body_click(event) } }
      el("chunkyChat").addEventListener("click", sync: true) { |event| guard("next") { chat_click(event) } }
      el("gemsList").addEventListener("click", sync: true) { |event| guard("gem chip") { chip_click(event) } }
      el("gemInstallBtn").addEventListener("click", sync: true) { guard("gem install") { typed_install } }
      window = JSG.w
      window.addEventListener("keydown", sync: true) { |event| guard("hotkey") { hotkey(event) } }
      # back/forward, and a lesson id typed or pasted into the address bar
      window.addEventListener("hashchange", sync: true) { guard("route") { route_from_hash } }
      # a progress file was loaded or a folder reconnected (storage.js)
      window.addEventListener("chunky-progress-loaded", sync: true) { guard("progress") { progress_loaded } }
      # the kernel's answers (shell/bridge.js)
      window.addEventListener("chunky:ran", sync: true) { |event| guard("ran") { ran(event.detail) } }
      window.addEventListener("chunky:gems", sync: true) { |event| guard("gems") { gems_changed(event.detail.installed) } }
      window.addEventListener("chunky:installed", sync: true) { |event| guard("installed") { installed(event.detail) } }
      window.addEventListener("chunky:kernel-ready", sync: true) { guard("kernel") { kernel_ready } }
      window.addEventListener("chunky:kernel-failed", sync: true) { guard("kernel failed") { kernel_failed } }
      # typing in a cell (index.html's initCell), for live runs
      app = self
      JS::Object.register_callback("chunkyEdited") { |idx| app.edited(idx.to_i) }
      window["chunkyEdited"] = JS.generic_callbacks[:chunkyEdited]
    end

    # Nav entries are real links (#lesson-id): a plain click is handled here,
    # ctrl/cmd/shift/middle clicks are the browser's (new tab, copy link).
    def nav_click(event)
      return if event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button != 0

      id = event.target.getAttribute("data-id")
      return if id.nil? || id == ""

      event.preventDefault
      select_lesson(id)
    end

    def body_click(event)
      target = event.target
      return toggle_live if target.className.to_s.include?("live-toggle")
      return unless target.className.to_s.include?("run-cell")

      idx = target.getAttribute("data-idx")
      start_cell_run(idx.to_i) unless idx.nil? || idx == ""
    end

    # the "next lesson" link inside the bubble
    def chat_click(event)
      return unless event.target.id == "nextLessonLink"

      event.preventDefault
      go_to_next_lesson
    end

    # Alt+R runs the exercise
    def hotkey(event)
      return unless event.altKey && event.key == "r"

      event.preventDefault
      idx = exercise_index
      start_cell_run(idx) if idx
    end

    # ---------- where we are ----------

    # The URL names the lesson (/#scarpe), so a lesson can be linked,
    # bookmarked and reached with back/forward. localStorage is only the
    # fallback for a bare URL: it brings you back where you left off.
    def current_index
      id = hash_lesson_id || Store.get("chunky_current", @course.id(0))
      @course.index(id) || 0
    end

    def current_lesson_id = @course.id(current_index)
    def current_cells = @course.cells(current_index, @lang)

    def hash_value = JSG.w.location.hash.to_s.delete_prefix("#")

    # the lesson id in location.hash, or nil when it names no lesson
    def hash_lesson_id
      raw = hash_value
      @course.index(raw) ? raw : nil
    end

    def workshop_hash? = hash_value == WORKSHOP_ID

    def exercise_index
      return nil if workshop?

      current_cells.index { |cell| cell.t == "x" }
    end

    # Assigning location.hash adds a history entry, so back returns to the
    # previous lesson. The hashchange it causes finds that lesson already
    # rendered and does nothing.
    def set_lesson_hash(id)
      JSG.w.location.hash = id unless hash_lesson_id == id
    end

    def route_from_hash
      return open_workshop if workshop_hash? && !workshop?
      return if workshop_hash?

      id = hash_lesson_id
      if id.nil?
        # a hash naming no lesson: keep the page, correct the address bar
        current = workshop? ? WORKSHOP_ID : @rendered_lesson_id
        JSG.w.history.replaceState(nil, "", "##{current}") if current
      elsif workshop? || id != @rendered_lesson_id
        select_lesson(id)
      end
    end

    # ---------- rendering ----------

    def render_all
      doc = JSG.d
      doc.documentElement.setAttribute("lang", @lang)
      doc.title = ui.title
      el("siteTitle").innerText = ui.title
      el("siteSubtitle").innerText = ui.subtitle
      el("reset-code").innerText = ui.reset
      el("footerCredit").innerHTML = ui.footerCredit
      el("footerLicense").innerHTML = ui.footerLicense
      el("langSelect").value = @lang
      render_gems_panel
      render_nav
      render_lesson
      kernel_status
      @workspace&.language_changed
    end

    def render_nav
      active = workshop? ? nil : current_lesson_id
      el("lessonNav").innerHTML = View.nav_html(@course, @lang, active, Store.done_ids)
      link = el("workshopLink")
      link.textContent = ui.workshopNav
      link.className = workshop? ? "workshop-link active" : "workshop-link"
    end

    # A new lesson (or language) means a fresh binding in the kernel: the
    # bridge passes the state on and drops runs still waiting for the old one.
    def render_lesson
      @running = {}
      @view_gen += 1
      @slow = {}
      @last_outcome = {}
      JSG.d.body.classList.toggle("in-workshop", workshop?)
      el("reset-code").hidden = workshop?
      @bridge.setState(@lang, workshop? ? "" : current_lesson_id, workshop?)
      return render_workshop if workshop?

      idx = current_index
      id = @course.id(idx)
      cells = @course.cells(idx, @lang)
      # three.js (750 KB) only for the lesson that draws with it
      JSG.w.ensureThree if cells.any? { |cell| code_cell?(cell) && cell.code.to_s.include?("show_three") }
      @rendered_lesson_id = id
      # the lesson in the tab title makes bookmarks and history legible
      JSG.d.title = "#{@course.title(idx, @lang)} – #{ui.title}"
      el("lessonBody").innerHTML = View.lesson_html(cells, ui.taskLabel, ui.runCell, live_toggle_html)
      cells.each_with_index do |cell, i|
        next unless code_cell?(cell)

        JSG.w.initCell(i)
        set_code(i, Store.get(Store.code_key(@lang, id, i), cell.code))
      end
    end

    # The cell number goes over as a string: PicoRuby 4.0.3 leaves "\n" and
    # "\t" unescaped in string arguments next to a number (the call then
    # fails with "Bad control character ... in JSON"); all-string calls work.
    def set_code(idx, code)
      JSG.w.setCellCode(idx.to_s, code)
    end

    def render_workshop
      @rendered_lesson_id = nil
      JSG.d.title = "#{ui.workshopTitle} – #{ui.title}"
      el("lessonBody").innerHTML = View.workshop_html(ui.workshopTitle, ui.workshopIntro, ui.runCell, live_toggle_html)
      JSG.w.initCell(0)
      @workspace&.mount
    end

    def render_gems_panel
      el("gemsTitle").innerText = ui.gemsTitle
      el("gemInstallBtn").innerText = ui.gemsInstallBtn
      el("gemsNote").innerHTML = ui.gemsNote
      names = (@gem_names + @installed.keys).uniq
      el("gemsList").innerHTML = View.gems_html(names, @installed, ui.gemsCachedTip)
    end

    def show_bubble(html, state)
      chat = el("chunkyChat")
      chat.className = state.to_s
      el("chunkyText").innerHTML = html
      chat.style.display = "flex"
    end

    # "Ruby wird geladen ..." in the header until the kernel is up - or
    # that it will not come
    def kernel_status
      status = el("kernelStatus")
      return unless status

      status.textContent = @kernel_failed ? kernel_failed_text : ui.loading
      status.hidden = @kernel_ready
      status.classList.toggle("is-failed", @kernel_failed)
      JSG.d.body.classList.toggle("kernel-loading", !@kernel_ready && !@kernel_failed)
    end

    # what the header and the bubble say when CRuby never came up (shell/bridge.js)
    def kernel_failed_text = ui.kernelFailed

    # ---------- actions ----------

    def select_lesson(id)
      return open_workshop if id == WORKSHOP_ID

      @workshop = false
      Store.set("chunky_current", id)
      set_lesson_hash(id)
      render_nav
      render_lesson
      show_bubble(ui.welcome, nil)
      # a new lesson starts at its top (on phones the index sits below it)
      JSG.w.scrollTo(0, 0)
    end

    # The workshop is a page of its own beside the lessons, at #werkstatt.
    def open_workshop
      @workshop = true
      JSG.w.location.hash = WORKSHOP_ID unless workshop_hash?
      render_nav
      render_lesson
      show_bubble(ui.workshopWelcome, nil)
      JSG.w.scrollTo(0, 0)
    end

    def go_to_next_lesson
      idx = current_index
      select_lesson(@course.id(idx + 1)) if idx + 1 < @course.size
    end

    def switch_lang(lang)
      return unless @course.lang?(lang)

      @lang = lang
      Store.set("chunky_lang", lang)
      render_all
      show_bubble(ui.welcome, nil)
    end

    def reset_lesson
      id = current_lesson_id
      current_cells.each_with_index do |cell, i|
        next unless code_cell?(cell)

        Store.remove(Store.code_key(@lang, id, i))
        set_code(i, cell.code)
        out = el("cell-out-#{i}")
        out.style.display = "none" if out
      end
      @bridge.reset
      show_bubble(ui.welcome, nil)
    end

    # what localStorage holds now, in the language it names
    def progress_loaded
      lang = Store.get("chunky_lang", @lang)
      @lang = lang if @course.lang?(lang)
      render_all
    end

    # ---------- running a cell ----------

    # Ruby runs on the page's main thread, so the running look goes on
    # screen first; the bridge hands the run to the kernel after the next
    # paint - or keeps it until the kernel has loaded.
    def start_cell_run(idx)
      return show_bubble(kernel_failed_text, "fail") if @kernel_failed
      return if @running[idx]

      cell, button = cell_parts(idx)
      return unless button

      @running[idx] = true
      drop_live_run(idx)   # this run replaces the live one still waiting
      if cell
        cell.classList.remove("shake", "celebrate")
        cell.classList.add("running")
      end
      button.disabled = true
      button.innerHTML = View.running_label(ui.running)
      @bridge.run(idx)
    end

    # the kernel ran cell idx: "ok" | "error" | "pass" | "fail"; a live run
    # also "skipped" (its code does not parse yet), "stopped" (time limit)
    # or "needs" (it wanted a download)
    def ran(detail)
      idx = detail.idx
      outcome = detail.outcome
      @running.delete(idx)
      note_speed(idx, outcome, detail.elapsed)
      before = @last_outcome[idx]
      @last_outcome[idx] = outcome unless outcome == "skipped"
      return settle_live(idx, outcome, before) if detail.auto == true

      settle_cell(idx, outcome, detail.elapsed)
      return if workshop?

      cell = current_cells[idx]
      return unless cell && cell.t == "x"

      if outcome == "error"
        show_bubble(ui.errorIntro, "fail")
      elsif outcome == "pass"
        exercise_passed
      elsif outcome == "fail"
        show_bubble(View.failed_html(ui, cell.hint), "fail")
      end
    end

    def exercise_passed
      id = current_lesson_id
      Store.mark_done(id)
      render_nav
      praise = ui.praise.to_a
      idx = current_index
      total = @course.size
      next_id = idx + 1 < total ? @course.id(idx + 1) : nil
      all_done = Store.done_ids.length >= total
      show_bubble(View.passed_html(praise[rand(praise.length)], ui, idx, total, next_id, all_done), "pass")
    end

    def settle_cell(idx, outcome, elapsed)
      cell, button = cell_parts(idx)
      if button
        button.disabled = false
        button.textContent = ui.runCell
      end
      return unless cell

      cell.classList.remove("running")
      replay(cell, "shake") if outcome == "error"
      replay(cell, "celebrate") if outcome == "pass"
      out = el("cell-out-#{idx}")
      replay(out, "reveal") if out
      show_run_time(cell, elapsed) if elapsed && elapsed >= 0
    end

    # Re-adding a class does not restart its animation; reading a layout
    # property in between makes the browser see the removal first.
    def replay(node, css_class)
      node.classList.remove(css_class)
      node.offsetWidth
      node.classList.add(css_class)
    end

    def show_run_time(cell, seconds)
      toolbar = cell.querySelector(".cell-toolbar")
      return unless toolbar

      stamp = toolbar.querySelector(".run-time")
      unless stamp
        stamp = JSG.d.createElement("span")
        stamp.className = "run-time"
        toolbar.insertBefore(stamp, toolbar.firstChild)
      end
      stamp.textContent = View.run_time(seconds, @lang)
      replay(stamp, "fresh")
    end

    def cell_parts(idx)
      button = JSG.d.querySelector(".run-cell[data-idx='#{idx}']")
      cell = button ? button.closest(".cell") : nil
      [cell, button]
    end

    # ---------- live runs ----------

    # the page's switch: the lessons' is on unless turned off, the
    # workshop's off unless turned on (a program there may take its time)
    def live?
      return Store.get(LIVE_WORKSHOP_KEY, "off") == "on" if workshop?

      Store.get(LIVE_KEY, "on") != "off"
    end

    def live_toggle_html = View.live_html(live?, ui.liveLabel, live? ? ui.liveOn : ui.liveOff)

    # A key in cell idx (index.html): its live run a moment later, unless
    # another key, a click on ▶ or another page comes first. A Task's
    # block runs with another self, hence app and the locals.
    def edited(idx)
      guard("live") do
        if live? && !@kernel_failed
          gen = drop_live_run(idx)
          view = @view_gen
          delay = LIVE_DELAY_MS
          app = self
          Task.new do
            sleep_ms delay
            app.live_run(idx, gen, view)
          end
        end
      end
    end

    # the live run of cell idx that is still waiting will not happen; the
    # number the next one goes by
    def drop_live_run(idx)
      @live_gen[idx] = (@live_gen[idx] || 0) + 1
    end

    # Only the latest key's run, on the page it was typed on, while the
    # cell is idle and quick. The kernel does not keep it waiting: while
    # Ruby loads, typing is just typing (bridge.js).
    def live_run(idx, gen, view)
      guard("live run") do
        current = view == @view_gen && gen == @live_gen[idx]
        if current && live? && !@running[idx] && !@slow[idx] && @kernel_ready && !@kernel_failed
          @running[idx] = true
          @running.delete(idx) unless @bridge.autorun(idx)
        end
      end
    end

    # A live run is a rehearsal: no shake, no reveal, no bubble for an
    # error or a wrong answer. Chunky cheers for a pass - once, when it is new.
    def settle_live(idx, outcome, before)
      cell = cell_parts(idx)[0]
      return unless outcome == "pass" && before != "pass"

      replay(cell, "celebrate") if cell
      exercise_passed
    end

    # A cell that took longer than LIVE_SLOW runs only with ▶ until a run
    # is quick again. A skipped run tells nothing: its code did not run.
    def note_speed(idx, outcome, elapsed)
      return if outcome == "skipped" || elapsed.nil? || elapsed < 0

      @slow[idx] = elapsed > LIVE_SLOW
      refresh_live_toggle(idx)
    end

    def toggle_live
      Store.set(workshop? ? LIVE_WORKSHOP_KEY : LIVE_KEY, live? ? "off" : "on")
      JSG.q(".run-cell").each { |button| refresh_live_toggle(button.getAttribute("data-idx").to_i) }
    end

    def refresh_live_toggle(idx)
      cell = cell_parts(idx)[0]
      toggle = cell ? cell.querySelector(".live-toggle") : nil
      return unless toggle

      on = live?
      toggle.setAttribute("aria-pressed", on.to_s)
      toggle.classList.toggle("is-paused", on && @slow[idx] == true)
      toggle.title = !on ? ui.liveOff : (@slow[idx] ? ui.liveSlow : ui.liveOn)
    end

    # ---------- the kernel ----------

    def kernel_ready
      @kernel_ready = true
      kernel_status
    end

    # the runs that were waiting will not happen: their cells go back to idle
    def kernel_failed
      @kernel_failed = true
      @running.keys.each { |idx| settle_cell(idx, nil, -1) }
      @running = {}
      kernel_status
      show_bubble(kernel_failed_text, "fail")
    end

    # ---------- gems ----------

    # The cached gems, as chips; fetched after the first paint, in a Task
    # (fetch suspends, which a sync handler must not). A Task's block does
    # not run with the self it was written in, hence the explicit receiver.
    def load_gem_names
      app = self
      Task.new { app.fetch_gem_names }
    end

    def fetch_gem_names
      guard("gem list") do
        text = nil
        JSG.w.fetch("gems/cache/manifest.json") do |response|
          text = response.to_binary.to_s if response.status == 200
        end
        if text
          @gem_names = JSG.w.Object.keys(JSG.w.JSON.parse(text)).to_a
          render_gems_panel
        end
      end
    end

    # name => version, as JSON from the kernel
    def gems_changed(json)
      parsed = JSG.w.JSON.parse(json)
      @installed = {}
      JSG.w.Object.keys(parsed).to_a.each { |name| @installed[name] = parsed[name] }
      render_gems_panel
    end

    def chip_click(event)
      name = event.target.getAttribute("data-gem")
      install(name) unless name.nil? || name == ""
    end

    def typed_install
      name = el("gemNameInput").value.to_s.strip
      install(name) unless name.empty?
    end

    def install(name)
      show_bubble(ui.loading, nil) unless @bridge.install(name)
    end

    def installed(detail)
      if detail.ok
        show_bubble(format(ui.gemInstalled, detail.message), "pass")
      else
        show_bubble(escape_html(detail.message), "fail")
      end
    end
  end
end
