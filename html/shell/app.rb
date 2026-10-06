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
    # The sidebar, put away on a wide screen ("closed"), and the index's
    # folded groups (comma-separated group keys, View.nav_groups) - view
    # settings too. Below NARROW (app.css) the sidebar is a drawer instead,
    # out only until a lesson is picked.
    SIDEBAR_KEY = "chunkyui_sidebar"
    NAV_CLOSED_KEY = "chunkyui_nav_closed"
    NARROW = "(max-width: 820px)"

    def initialize(data = JSG.w.LESSONS, bridge = JSG.w.ChunkyBridge)
      @course = Course.new(data)
      @bridge = bridge
      # shell/bridge.js picked it: ?lang=, the last choice, the browser's
      # languages, English; without a bridge's word, the stored choice
      @lang = bridge[:lang] || Store.get("chunky_lang", "de")
      @lang = "de" unless @course.lang?(@lang)
      # /#methoden, or /de/methoden when the server gives lessons permalinks
      @router = Router.new(bridge[:permalinks])
      @workshop = workshop_address?
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
      @nav_closed = Store.get(NAV_CLOSED_KEY, "").split(",")
      @nav_query = ""       # the index's search field
      @cell_numbers = {}    # cell index => its number among the code cells
      @refocus = nil        # the cell whose Run button had the keyboard focus
      @refocus_step = false # ... after ⏯: the focus goes to the stepper
    end

    def start
      wire_events
      # the progress dialog and the workshop's files (storage.js keeps them)
      @workspace = Workspace.new(self).start
      # the page before the editors: CodeMirror measures its container when
      # it is built, and inside a display:none #app it measures zero
      JSG.d.body.classList.toggle("sidebar-closed", Store.get(SIDEBAR_KEY, "") == "closed")
      sidebar_expanded
      el("spinner").style.display = "none"
      el("app").style.display = "block"
      # code saved before keys had fingerprints moves to its cell's key
      # (Store.migrate_code_keys; nothing to do once it has)
      guard("saved code") { Store.migrate_code_keys(@course) }
      render_all
      # a bare URL still names its lesson afterwards, without a history
      # entry; with permalinks an old /#methoden link becomes /de/methoden
      @router.show(@lang, current_place, false)
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
      el("navSearch").addEventListener("input", sync: true) { guard("search") { search(el("navSearch").value) } }
      el("navSearch").addEventListener("keydown", sync: true) { |event| guard("search") { search_key(event) } }
      el("sidebarToggle").addEventListener("click", sync: true) { guard("sidebar") { toggle_sidebar } }
      el("lessonBody").addEventListener("click", sync: true) { |event| guard("run") { body_click(event) } }
      el("chunkyChat").addEventListener("click", sync: true) { |event| guard("next") { chat_click(event) } }
      el("gemsList").addEventListener("click", sync: true) { |event| guard("gem chip") { chip_click(event) } }
      el("gemInstallBtn").addEventListener("click", sync: true) { guard("gem install") { typed_install } }
      window = JSG.w
      window.addEventListener("keydown", sync: true) { |event| guard("hotkey") { hotkey(event) } }
      # a tap beside the drawer puts it away (the scrim is the body's ::after)
      window.addEventListener("click", sync: true) { |event| guard("drawer") { drawer_click(event) } }
      # the drawer button's aria-expanded follows the window across NARROW
      window.matchMedia(NARROW).addEventListener("change", sync: true) { guard("sidebar") { sidebar_expanded } }
      # back/forward, and a lesson id typed or pasted into the address bar
      window.addEventListener("hashchange", sync: true) { guard("route") { route_from_address } }
      # back/forward between permalinks (history.pushState)
      window.addEventListener("popstate", sync: true) { guard("route") { route_from_address } }
      el("workshopLink").addEventListener("click", sync: true) { |event| guard("workshop") { workshop_click(event) } }
      el("skipLink").addEventListener("click", sync: true) { |event| guard("skip") { skip_click(event) } }
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
      # the kernel runs a cell (main.rb's run_cell): its code is kept
      JS::Object.register_callback("chunkySaveCode") { |idx, code| app.save_code(idx.to_i, code) }
      window["chunkySaveCode"] = JS.generic_callbacks[:chunkySaveCode]
    end

    # Nav entries are real links (#lesson-id): a plain click is handled here,
    # ctrl/cmd/shift/middle clicks are the browser's (new tab, copy link).
    # A group's head folds the group.
    def nav_click(event)
      head = event.target.closest(".nav-group-head")
      return toggle_group(head) unless head.nil?
      return if event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button != 0

      link = event.target.closest("a")
      return if link.nil?

      id = link.getAttribute("data-id")
      return if id.nil? || id == ""

      event.preventDefault
      select_lesson(id)
    end

    # Folds or unfolds in place, so the head keeps the keyboard focus; the
    # next render_nav draws it the same from @nav_closed.
    def toggle_group(head)
      key = head.getAttribute("data-group")
      open = @nav_closed.include?(key)
      open ? @nav_closed.delete(key) : @nav_closed << key
      Store.set(NAV_CLOSED_KEY, @nav_closed.join(","))
      head.closest(".nav-group").classList.toggle("closed", !open)
      head.setAttribute("aria-expanded", open.to_s)
    end

    # The search field: the index shows what matches, as you type
    def search(text)
      @nav_query = text.to_s
      render_nav
    end

    # Escape empties the field, Enter opens the first lesson that matches
    def search_key(event)
      key = event.key
      if key == "Escape" && @nav_query != ""
        event.preventDefault
        el("navSearch").value = ""
        search("")
      elsif key == "Enter"
        event.preventDefault
        first = JSG.d.querySelector("#lessonNav a")
        select_lesson(first.getAttribute("data-id")) unless first.nil?
      end
    end

    # ---------- the sidebar ----------

    def narrow? = JSG.w.matchMedia(NARROW).matches == true
    def body_class?(name) = JSG.d.body.classList.contains(name) == true

    # Wide: shows or puts away the sidebar, and remembers it. Narrow: pulls
    # the drawer out or pushes it back, and forgets it.
    def toggle_sidebar
      list = JSG.d.body.classList
      if narrow?
        open = list.toggle("sidebar-open") == true
        sidebar_expanded
        # the keyboard goes into the drawer, as into a dialog
        el("workshopLink").focus if open
        return
      end

      closed = list.toggle("sidebar-closed") == true
      Store.set(SIDEBAR_KEY, closed ? "closed" : "open")
      sidebar_expanded
    end

    # whether the sidebar is showing: on a wide screen unless put away, on a
    # narrow one only while the drawer is out
    def sidebar_expanded
      showing = narrow? ? body_class?("sidebar-open") : !body_class?("sidebar-closed")
      el("sidebarToggle").setAttribute("aria-expanded", showing.to_s)
      # An open drawer is modal: the page behind the scrim leaves the tab
      # order and the screen reader (inert) - and comes back when the
      # drawer goes, or when the window grows past NARROW with it out. The
      # toggle and the skip link sit outside .column and stay reachable.
      JSG.d.querySelector(".column").inert = narrow? && body_class?("sidebar-open")
    end

    # +focus+: hand the keyboard back to the button that opened the drawer
    def close_drawer(focus = false)
      return unless body_class?("sidebar-open")

      JSG.d.body.classList.remove("sidebar-open")
      sidebar_expanded
      el("sidebarToggle").focus if focus
    end

    def drawer_click(event)
      return unless body_class?("sidebar-open")

      target = event.target
      close_drawer if target.closest("#sidebar").nil? && target.closest("#sidebarToggle").nil?
    end

    def body_click(event)
      target = event.target
      css_class = target.className.to_s
      return toggle_live if css_class.include?("live-toggle")
      step = css_class.include?("step-cell")
      return unless step || css_class.include?("run-cell")

      idx = target.getAttribute("data-idx")
      start_cell_run(idx.to_i, step) unless idx.nil? || idx == ""
    end

    # the workshop link above the index: a plain click opens it in place
    def workshop_click(event)
      return if event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button != 0

      event.preventDefault
      open_workshop unless workshop?
    end

    # The skip link, the keyboard's first stop: past the index to the
    # lesson. Its #lessonBody would reach the router as a lesson id.
    def skip_click(event)
      event.preventDefault
      close_drawer
      focus_heading
    end

    # the "next lesson" link inside the bubble
    def chat_click(event)
      return unless event.target.id == "nextLessonLink"

      event.preventDefault
      go_to_next_lesson
    end

    # Alt+R runs the exercise; Escape puts the drawer away
    def hotkey(event)
      return close_drawer(true) if event.key == "Escape"
      return unless event.altKey && event.key == "r"

      event.preventDefault
      idx = exercise_index
      start_cell_run(idx) if idx
    end

    # ---------- where we are ----------

    # The URL names the lesson (/#scarpe, or /de/scarpe with permalinks), so
    # a lesson can be linked, bookmarked and reached with back/forward.
    # localStorage is only the fallback for a bare URL: it brings you back
    # where you left off.
    def current_index
      id = address_lesson_id || Store.get("chunky_current", @course.id(0))
      @course.index(id) || 0
    end

    def current_lesson_id = @course.id(current_index)
    def current_cells = @course.cells(current_index, @lang)

    # what the address names: a lesson id, WORKSHOP_ID or anything else
    def address = @router.place

    # the lesson id in the address, or nil when it names no lesson
    def address_lesson_id
      raw = address
      @course.index(raw) ? raw : nil
    end

    def workshop_address? = address == WORKSHOP_ID

    # what the address should name: the workshop or the lesson on screen
    def current_place = workshop? ? WORKSHOP_ID : current_lesson_id

    def exercise_index
      return nil if workshop?

      current_cells.index { |cell| cell.t == "x" }
    end

    # A new history entry, so back returns to the previous lesson. The
    # hashchange (or popstate) it may cause finds that lesson already
    # rendered and does nothing.
    def set_lesson_address(id)
      @router.show(@lang, id, true) unless address_lesson_id == id
    end

    def route_from_address
      return open_workshop if workshop_address? && !workshop?
      return if workshop_address?

      id = address_lesson_id
      if id.nil?
        # an address naming no lesson: keep the page, correct the address bar
        current = workshop? ? WORKSHOP_ID : @rendered_lesson_id
        @router.show(@lang, current, false) if current
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
      # the select's name (a hidden label) and tooltip, the fox's alt, the
      # skip link: in the page's language
      el("langLabel").textContent = ui.langLabel
      el("langSelect").setAttribute("title", ui.langLabel)
      el("mascot").setAttribute("alt", ui.mascotAlt)
      el("skipLink").textContent = ui.skipLink
      render_gems_panel
      render_nav
      render_lesson
      kernel_status
      @workspace&.language_changed
    end

    def render_nav
      active = workshop? ? nil : current_lesson_id
      done = Store.done_ids
      el("lessonNav").innerHTML = View.nav_html(@course, @lang, active, done, @router.prefix(@lang),
                                                @nav_closed, @nav_query, ui.navNone, ui.navDone)
      # the head: how far the whole course is
      finished = @course.ids.select { |id| done.include?(id) }.length
      el("navTitle").textContent = ui.navTitle
      count = el("navCount")
      count.textContent = "#{finished}/#{@course.size}"
      count.setAttribute("title", format(ui.navDone, finished, @course.size))
      el("navBarFill").style.width = "#{finished * 100 / @course.size}%"
      search = el("navSearch")
      search.setAttribute("placeholder", ui.navSearch)
      search.setAttribute("aria-label", ui.navSearch)
      toggle = el("sidebarToggle")
      toggle.setAttribute("title", ui.navToggle)
      toggle.setAttribute("aria-label", ui.navToggle)
      el("sidebar").setAttribute("aria-label", ui.navTitle)
      link = el("workshopLink")
      link.textContent = ui.workshopNav
      link.setAttribute("href", @router.href(@lang, WORKSHOP_ID))
      link.className = workshop? ? "workshop-link active" : "workshop-link"
    end

    # A new lesson (or language) means a fresh binding in the kernel: the
    # bridge passes the state on and drops runs still waiting for the old one.
    def render_lesson
      @running = {}
      @view_gen += 1
      @slow = {}
      @last_outcome = {}
      @cell_numbers = {}
      @refocus = nil
      JSG.d.body.classList.toggle("in-workshop", workshop?)
      el("reset-code").hidden = workshop?
      @bridge.setState(@lang, workshop? ? "" : current_lesson_id, workshop?)
      return render_workshop if workshop?

      idx = current_index
      id = @course.id(idx)
      cells = @course.cells(idx, @lang)
      # three.js (750 KB) only for the lesson that draws with it
      JSG.w.ensureThree if cells.any? { |cell| code_cell?(cell) && cell.code.to_s.include?("show_three") }
      # Python (Pyodide, ~9 MB) only for a lesson that calls it, with the
      # packages its import_module calls name (pandas ~12 MB, sympy ~5 MB,
      # scikit-learn ~19 MB, matplotlib ~9 MB)
      python = cells.select { |cell| code_cell?(cell) && cell.code.to_s.include?("PyCall") }
      JSG.w.ensurePython(python.map { |cell| cell.code.to_s }.join("\n")) unless python.empty?
      # SQLite (sql.js, ~650 KB) only for a lesson that uses Sequel or sqlite3
      JSG.w.ensureSqlite if cells.any? { |cell| code_cell?(cell) && cell.code.to_s.match?(/Sequel|SQLite3/) }
      # Herb's parser (WebAssembly, 1.7 MB) only for a lesson that requires herb
      JSG.w.ensureHerb if cells.any? { |cell| code_cell?(cell) && cell.code.to_s.include?('require "herb"') }
      # a second PicoRuby (the same 0.9 MB, cached) in a Web Worker, only for
      # a lesson whose cells run on it (html/picoruby_lab.js)
      JSG.w.ensurePicoRuby if @course.picoruby?(idx)
      @rendered_lesson_id = id
      # a lesson opened from a link is where the learner left off, too (only
      # a change is written: every write reaches a connected folder)
      Store.set("chunky_current", id) unless Store.get("chunky_current", "") == id
      # the lesson in the tab title makes bookmarks and history legible
      JSG.d.title = "#{@course.title(idx, @lang)} – #{ui.title}"
      # ⏯ only in the lessons that ask for it ("stepper": true)
      step = @course.stepper?(idx) ? [ui.stepButton, ui.stepCellLabel] : nil
      el("lessonBody").innerHTML = View.lesson_html(cells, ui.taskLabel, ui.runCell, live_toggle_html, ui.runCellLabel, step)
      number = 0
      cells.each_with_index do |cell, i|
        next unless code_cell?(cell)

        # the editor's name counts code cells only ("Code, cell 2"); all
        # strings, as in set_code
        number += 1
        @cell_numbers[i] = number
        JSG.w.initCell(i.to_s, format(ui.codeLabel, number), ui.codeHint)
        # saved code only where it was saved for this cell (Store.code_key)
        set_code(i, Store.get(Store.code_key(@lang, id, i, cell.code), cell.code))
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
      @cell_numbers = { 0 => 1 }
      JSG.w.initCell("0", ui.workshopTitle, ui.codeHint)
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
      set_lesson_address(id)
      unfold_group_of(id)
      close_drawer
      render_nav
      render_lesson
      show_bubble(ui.welcome, nil)
      # a new lesson starts at its top
      JSG.w.scrollTo(0, 0)
      focus_heading
    end

    # The index is drawn anew and the drawer closes, so the link that was
    # used - in the index, the bubble's "next lesson", the search field's
    # Enter - is gone, and with it the keyboard focus: it goes to the
    # lesson's heading, where a screen reader starts reading. Not on the
    # first load, where it stays at the top of the page.
    def focus_heading
      heading = JSG.d.querySelector("#lessonBody h2")
      return if heading.nil?

      heading.setAttribute("tabindex", "-1")
      heading.focus
    end

    # A lesson reached by "next lesson", back or a link shows in the index
    # even when its group was folded away.
    def unfold_group_of(id)
      idx = @course.index(id)
      group = View.nav_groups(@course, @lang).find { |g| g[2].include?(idx) }
      return if group.nil? || !@nav_closed.include?(group[0])

      @nav_closed.delete(group[0])
      Store.set(NAV_CLOSED_KEY, @nav_closed.join(","))
    end

    # The workshop is a page of its own beside the lessons, at #werkstatt.
    def open_workshop
      @workshop = true
      @router.show(@lang, WORKSHOP_ID, true) unless workshop_address?
      close_drawer
      render_nav
      render_lesson
      show_bubble(ui.workshopWelcome, nil)
      JSG.w.scrollTo(0, 0)
      focus_heading
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
      @router.show(@lang, current_place, false)   # /de/methoden -> /en/methoden
      show_bubble(ui.welcome, nil)
    end

    def reset_lesson
      id = current_lesson_id
      current_cells.each_with_index do |cell, i|
        next unless code_cell?(cell)

        Store.remove(Store.code_key(@lang, id, i, cell.code))
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
      # an old progress file or folder may bring keys without fingerprints
      guard("saved code") { Store.migrate_code_keys(@course) }
      render_all
      @router.show(@lang, current_place, false)
    end

    # ---------- running a cell ----------

    # The kernel is running cell idx with this code (main.rb's run_cell,
    # through the chunkySaveCode callback): kept for the next visit, under
    # the fingerprint of the cell on screen. Not the workshop's: its files
    # keep its code.
    def save_code(idx, code)
      return if workshop?

      cell = current_cells[idx]
      return unless cell && code_cell?(cell)

      Store.set(Store.code_key(@lang, current_lesson_id, idx, cell.code), code.to_s)
    end

    # Ruby runs on the page's main thread, so the running look goes on
    # screen first; the bridge hands the run to the kernel after the next
    # paint - or keeps it until the kernel has loaded.
    # +step+: ⏯ - the same run, recorded for the stepper (stepper.js)
    def start_cell_run(idx, step = false)
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
      # a button that turns disabled drops the keyboard focus to <body>, and
      # the next Tab starts at the top of the page: settle_cell gives it back
      # - after ⏯ to the stepper's slider, where the arrow keys walk the run
      @refocus = idx if step || focused_run_button == idx
      @refocus_step = step
      button.disabled = true
      button.innerHTML = View.running_label(ui.running)
      stepper = step_button(cell)
      stepper.disabled = true if stepper
      # code that uses Sequel loads SQLite first, as its lesson does on
      # opening - a workshop program, or a cell changed to use it; the
      # bridge holds the run until it is there
      JSG.w.ensureSqlite if uses_sqlite?(idx)
      step ? @bridge.step(idx) : @bridge.run(idx)
    end

    def step_button(cell) = cell ? cell.querySelector(".step-cell") : nil

    # the cell whose Run button has the keyboard focus, or nil
    def focused_run_button
      active = JSG.d.activeElement
      return nil if active.nil? || !active.className.to_s.include?("run-cell")

      active.getAttribute("data-idx").to_s.to_i
    end

    def uses_sqlite?(idx)
      editor = JSG.w.cellEditors[idx.to_s]
      editor ? editor.getValue.to_s.match?(/Sequel|SQLite3/) : false
    end

    # the kernel ran cell idx: "ok" | "error" | "pass" | "fail"; a live run
    # also "skipped" (its code does not parse yet), "stopped" (time limit)
    # or "needs" (it wanted a download)
    def ran(detail)
      idx = detail.idx
      outcome = detail.outcome
      @running.delete(idx)
      note_speed(idx, outcome, detail.own)
      before = @last_outcome[idx]
      @last_outcome[idx] = outcome unless outcome == "skipped"
      return settle_live(idx, outcome, before) if detail.auto == true

      settle_cell(idx, outcome, detail.elapsed)
      cell = workshop? ? nil : current_cells[idx]
      return announce_run(idx, outcome, "") unless cell && cell.t == "x"

      if outcome == "error"
        show_bubble(ui.errorIntro, "fail")
      elsif outcome == "pass"
        exercise_passed
      elsif outcome == "fail"
        show_bubble(View.failed_html(ui, cell.hint), "fail")
      end
      announce_run(idx, outcome, el("chunkyText").innerText.to_s)
    end

    # What a run did, for a screen reader: one polite status line (#runStatus)
    # per run with ▶, Shift+Enter or Alt+R - the cell's output, shortened,
    # a picture by its alt text (show_objects says what it draws), and for
    # an exercise Chunky's verdict. The output itself is no live region:
    # live runs rewrite it while the learner types. Emptied first, and the
    # text a moment later, so the same result twice is read twice.
    def announce_run(idx, outcome, verdict)
      out = el("cell-out-#{idx}")
      text = out ? "#{brief_output(out)} #{picture_words(out)}".strip : ""
      text = "#{text[0, 280]} …" if text.length > 280
      message = format(outcome == "error" ? ui.ranError : ui.ranOk, @cell_numbers[idx] || idx, text)
      message = "#{message} #{verdict}" if verdict != ""
      announce(message)
    end

    # one line in #runStatus: emptied first, the text a moment later
    def announce(message)
      status = el("runStatus")
      status.textContent = ""
      Task.new do
        sleep_ms 50
        status.textContent = message
      end
    end

    # The output's text, with an explained error (the kernel's
    # .friendly-error) read as its headline: its code snippet with carets
    # makes no sense spoken, and the explanation stays on the page to read.
    # A game (show_game) says its name instead (picture_words): its grid
    # is emoji by the hundred. The stepper (⏯) is left out: its slider
    # gets the focus and speaks for itself.
    def brief_output(out)
      text = out.innerText.to_s
      %w[.game-widget .stepper].each do |selector|
        out.querySelectorAll(selector).each do |widget|
          whole = widget.innerText.to_s
          at = whole.empty? ? nil : text.index(whole)
          text = text[0, at].to_s + text[at + whole.length, text.length].to_s if at
        end
      end
      box = out.querySelector(".friendly-error")
      return text unless box

      title = box.querySelector(".friendly-title")
      headline = title ? title.innerText.to_s : ""
      whole = box.innerText.to_s
      at = text.index(whole)
      return headline unless at

      text[0, at].to_s + headline + text[at + whole.length, text.length].to_s
    end

    # what the pictures below a cell show, in words: their alt texts (a
    # plain picture has alt="" and says nothing) - and its sounds by their
    # players' names ("Ein Klang, 2,0 Sekunden", show_audio) and its games
    # by theirs ("Spiel mit 20 × 15 Feldern", show_game)
    def picture_words(out)
      words = []
      out.querySelectorAll(".game-widget").each do |game|
        name = game.getAttribute("aria-label").to_s
        words << name unless name.empty?
      end
      out.querySelectorAll("img.cell-image").each do |img|
        alt = img.getAttribute("alt").to_s
        words << alt unless alt.empty?
      end
      out.querySelectorAll(".cell-audio audio").each do |audio|
        name = audio.getAttribute("aria-label").to_s
        words << name unless name.empty?
      end
      words.join(" ")
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
      show_bubble(View.passed_html(praise[rand(praise.length)], ui, idx, total, next_id, all_done, @router.prefix(@lang)), "pass")
    end

    def settle_cell(idx, outcome, elapsed)
      cell, button = cell_parts(idx)
      stepper = step_button(cell)
      stepper.disabled = false if stepper
      if button
        button.disabled = false
        button.textContent = ui.runCell
        # back to where the keyboard was, unless it went elsewhere meanwhile;
        # after ⏯ to the stepper's slider (or ⏯, when nothing was recorded)
        if @refocus == idx
          @refocus = nil
          active = JSG.d.activeElement
          if active.nil? || active.tagName.to_s == "BODY"
            slider = @refocus_step ? JSG.d.querySelector("#cell-out-#{idx} .step-slider") : nil
            (slider || (@refocus_step && stepper) || button).focus
          end
        end
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
    # workshop's off unless turned on (a program there may take its time) -
    # and off in a lesson that turns live runs off
    def live?
      return Store.get(LIVE_WORKSHOP_KEY, "off") == "on" if workshop?

      lesson_live? && Store.get(LIVE_KEY, "on") != "off"
    end

    # false in a lesson with "live": false (lessons.js): its cells compute
    # too much to run on every pause in typing - the music lesson's sound
    # loops take a second and more under the time limit's tracing
    def lesson_live? = workshop? || @course.live?(current_index)

    # In such a lesson the switch stays in its place, off, and says why:
    # aria-disabled keeps it focusable, its title is the reason, a click
    # has Chunky say it.
    def live_toggle_html
      return View.live_html(false, ui.liveLabel, ui.liveLesson, true) unless lesson_live?

      View.live_html(live?, ui.liveLabel, live? ? ui.liveOn : ui.liveOff)
    end

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
    # is quick again. +seconds+ leaves out installing and loading gems, which
    # a cell's first run does once. A skipped run tells nothing: its code did
    # not run.
    def note_speed(idx, outcome, seconds)
      return if outcome == "skipped" || seconds.nil? || seconds < 0

      @slow[idx] = seconds > LIVE_SLOW
      refresh_live_toggle(idx)
    end

    def toggle_live
      return explain_no_live unless lesson_live?

      Store.set(workshop? ? LIVE_WORKSHOP_KEY : LIVE_KEY, live? ? "off" : "on")
      JSG.q(".run-cell").each { |button| refresh_live_toggle(button.getAttribute("data-idx").to_i) }
    end

    def refresh_live_toggle(idx)
      cell = cell_parts(idx)[0]
      toggle = cell ? cell.querySelector(".live-toggle") : nil
      # a lesson without live runs keeps its switch as it was drawn
      return unless toggle && lesson_live?

      on = live?
      toggle.setAttribute("aria-pressed", on.to_s)
      toggle.classList.toggle("is-paused", on && @slow[idx] == true)
      toggle.title = !on ? ui.liveOff : (@slow[idx] ? ui.liveSlow : ui.liveOn)
    end

    # the switch of a lesson without live runs, clicked: Chunky says why,
    # and so does the status line
    def explain_no_live
      show_bubble(escape_html(ui.liveLesson), nil)
      announce(ui.liveLesson)
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
