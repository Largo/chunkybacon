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
        list.toggle("sidebar-open")
      else
        closed = list.toggle("sidebar-closed") == true
        Store.set(SIDEBAR_KEY, closed ? "closed" : "open")
      end
      sidebar_expanded
    end

    # whether the sidebar is showing: on a wide screen unless put away, on a
    # narrow one only while the drawer is out
    def sidebar_expanded
      showing = narrow? ? body_class?("sidebar-open") : !body_class?("sidebar-closed")
      el("sidebarToggle").setAttribute("aria-expanded", showing.to_s)
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
      return toggle_live if target.className.to_s.include?("live-toggle")
      return unless target.className.to_s.include?("run-cell")

      idx = target.getAttribute("data-idx")
      start_cell_run(idx.to_i) unless idx.nil? || idx == ""
    end

    # the workshop link above the index: a plain click opens it in place
    def workshop_click(event)
      return if event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button != 0

      event.preventDefault
      open_workshop unless workshop?
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
      # scikit-learn ~19 MB)
      python = cells.select { |cell| code_cell?(cell) && cell.code.to_s.include?("PyCall") }
      JSG.w.ensurePython(python.map { |cell| cell.code.to_s }.join("\n")) unless python.empty?
      # SQLite (sql.js, ~650 KB) only for a lesson that uses Sequel or sqlite3
      JSG.w.ensureSqlite if cells.any? { |cell| code_cell?(cell) && cell.code.to_s.match?(/Sequel|SQLite3/) }
      # Herb's parser (WebAssembly, 1.7 MB) only for a lesson that requires herb
      JSG.w.ensureHerb if cells.any? { |cell| code_cell?(cell) && cell.code.to_s.include?('require "herb"') }
      @rendered_lesson_id = id
      # a lesson opened from a link is where the learner left off, too (only
      # a change is written: every write reaches a connected folder)
      Store.set("chunky_current", id) unless Store.get("chunky_current", "") == id
      # the lesson in the tab title makes bookmarks and history legible
      JSG.d.title = "#{@course.title(idx, @lang)} – #{ui.title}"
      el("lessonBody").innerHTML = View.lesson_html(cells, ui.taskLabel, ui.runCell, live_toggle_html)
      number = 0
      cells.each_with_index do |cell, i|
        next unless code_cell?(cell)

        # the editor's name counts code cells only ("Code, cell 2"); all
        # strings, as in set_code
        number += 1
        JSG.w.initCell(i.to_s, format(ui.codeLabel, number), ui.codeHint)
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
      @router.show(@lang, current_place, false)
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
      # code that uses Sequel loads SQLite first, as its lesson does on
      # opening - a workshop program, or a cell changed to use it; the
      # bridge holds the run until it is there
      JSG.w.ensureSqlite if uses_sqlite?(idx)
      @bridge.run(idx)
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
      show_bubble(View.passed_html(praise[rand(praise.length)], ui, idx, total, next_id, all_done, @router.prefix(@lang)), "pass")
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
    # is quick again. +seconds+ leaves out installing and loading gems, which
    # a cell's first run does once. A skipped run tells nothing: its code did
    # not run.
    def note_speed(idx, outcome, seconds)
      return if outcome == "skipped" || seconds.nil? || seconds < 0

      @slow[idx] = seconds > LIVE_SLOW
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
