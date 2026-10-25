# The page's HTML, as strings: one innerHTML write per part is the fastest
# way through the bridge. Everything here is a plain function of its
# arguments, which is what the unit tests look at. The markup (ids, classes)
# is the one app.css, workspace.rb, the kernel and the tests rely on.
module ChunkyShell
  module View
    extend Support

    # The index: one group per section, each with a head that folds it and
    # says how much of it is done. A group is named by the id of the lesson
    # that opens it, the same in every language.
    # +prefix+: what goes before a lesson id in its link (Router#prefix)
    # +closed+: the groups folded away (App keeps them)
    # +query+: what the search field holds; only the lessons it matches show,
    #   in open groups, or +none+ when there are none
    # +done_text+: "%d of %d done", for the head's count
    def self.nav_html(course, lang, active_id, done, prefix = "#", closed = [], query = "", none = "", done_text = "%d/%d")
      needle = query.to_s.strip.downcase
      html = "".dup
      nav_groups(course, lang).each do |group|
        key, name, indexes = group
        shown = needle == "" ? indexes : indexes.select { |idx| nav_match?(course, idx, lang, name, needle) }
        next if shown.empty?

        finished = indexes.select { |idx| done.include?(course.id(idx)) }.length
        open = needle != "" || !closed.include?(key)
        css = "nav-group"
        css += " closed" unless open
        css += " complete" if finished == indexes.length
        html << %(<section class="#{css}" data-group="#{key}">)
        if name
          count = format(done_text, finished, indexes.length)
          html << %(<button type="button" class="nav-group-head" data-group="#{key}" aria-expanded="#{open}" aria-controls="nav-#{key}">)
          html << %(<span class="nav-group-name">#{escape_html(name)}</span>)
          html << %(<span class="nav-group-count" title="#{escape_html(count)}" aria-label="#{escape_html(count)}">#{finished}/#{indexes.length}</span>)
          html << %(<svg class="nav-chevron" viewBox="0 0 12 12" aria-hidden="true"><path d="M3 4.5 6 7.5 9 4.5"/></svg></button>)
        end
        html << %(<div class="nav-group-items" id="nav-#{key}">)
        shown.each { |idx| html << nav_link(course, idx, lang, active_id, done, prefix) }
        html << "</div></section>"
      end
      html << %(<p class="nav-none">#{escape_html(none)}</p>) if html == ""
      html
    end

    # [[key, section name or nil, [lesson indexes]], ...] in course order
    def self.nav_groups(course, lang)
      groups = []
      course.ids.each_with_index do |id, idx|
        section = course.section(idx, lang)
        groups << [id, section, []] if section || groups.empty?
        groups.last[2] << idx
      end
      groups
    end

    def self.nav_match?(course, idx, lang, section, needle)
      course.numbered_title(idx, lang).downcase.include?(needle) || section.to_s.downcase.include?(needle)
    end

    # "Gems installieren" as row 13: the number in a badge,
    # which turns into a tick once the lesson is done
    def self.nav_link(course, idx, lang, active_id, done, prefix)
      id = course.id(idx)
      number = (idx + 1).to_s
      name = course.title(idx, lang)
      classes = ["lesson"]
      classes << "active" if id == active_id
      classes << "done" if done.include?(id)
      current = id == active_id ? ' aria-current="page"' : ""
      %(<a class="#{classes.join(' ')}" href="#{prefix}#{id}" data-id="#{id}"#{current}>) +
        %(<span class="num">#{number}</span><span class="name">#{escape_html(name)}</span></a>)
    end

    # +live+: the Live switch for every toolbar (live_html), or "" - not
    # beside an IRB, which never runs live (main.rb's AutoRun)
    # +run_name+: "Run cell %d", the Run buttons' names for a screen reader,
    #   which counts code cells only, as the editors' names do
    # +step+: [label, name] of ⏯ in a lesson with "stepper": true ("⏯
    #   Schritt für Schritt", "Schritt für Schritt durch Zelle %d"), or nil.
    #   Not beside an IRB either: what it runs is typed later, in the widget.
    # +tab_labels+: [the tab list's name ("Dateien"), "read-only"] for a
    #   Pico lesson's cells with tabs (several files, design §2.2)
    # +hint+: [the 💡 button's label ("💡 Tipp"), its name ("Tipp zu Zelle
    #   %d"), the hint panel's name ("Tipps zur Aufgabe")] for the exercise
    #   cell (App#reveal_hint), or nil
    def self.lesson_html(cells, task_label, run_label, live = "", run_name = "", step = nil, tab_labels = nil, hint = nil)
      html = "".dup
      number = 0
      cells.each_with_index do |cell, idx|
        if code_cell?(cell)
          number += 1
          irb = cell.code.to_s.include?("show_irb")
          switch = irb ? "" : live
          name = run_name == "" ? "" : format(run_name, number)
          stepper = step.nil? || irb ? "" : step_html(idx, step[0], format(step[1], number))
          exercise = cell.t == "x"
          hint_btn = hint.nil? || !exercise ? "" : hint_html(idx, hint[0], format(hint[1], number))
          html << cell_html(idx, exercise, task_label, run_label, switch, name, stepper,
                            tab_list(cell), !cell[:board].nil?, tab_labels || ["Files", "read-only"],
                            hint_btn, hint.nil? || !exercise ? nil : hint[2])
        else
          html << %(<div class="lessonText">#{cell.html}</div>)
        end
      end
      html
    end

    # +name+: "Run cell 2" - a lesson has up to eight buttons that all read
    # "▶ Run"; the name keeps the visible word (WCAG 2.5.3, Label in Name).
    # The exercise's button says that Alt+R presses it.
    # +step+: step_html's ⏯, left of ▶
    # +tabs+: [[name, readonly], ...], the main file first - more than one
    #   and the cell gets a tab list (WAI-ARIA tabs), one editor per file
    #   (#cell-code-<idx> for the main file, #cell-code-<idx>-<k> for tab k)
    # +board+: a Pico lesson's cell with a board: the slot the bench is
    #   moved into when the cell runs (pico_board.js)
    # +hint_btn+: hint_html's 💡, at the left of the toolbar; +hint_region+:
    #   the name of the panel the hints appear in (nil: no panel)
    def self.cell_html(idx, exercise, task_label, run_label, live = "", name = "", step = "", tabs = [], board = false,
                       tab_labels = ["Files", "read-only"], hint_btn = "", hint_region = nil)
      label = name == "" ? "" : %( aria-label="#{escape_html(name)}")
      keys = exercise ? ' aria-keyshortcuts="Alt+R"' : ""
      editors = tabs.length > 1 ? tabs_html(idx, tabs, tab_labels) : %(<textarea title="code" id="cell-code-#{idx}"></textarea>)
      slot = board ? %(<div class="pico-slot" id="pico-slot-#{idx}" hidden></div>) : ""
      hints = hint_region.nil? ? "" : %(<div class="cell-hints" id="cell-hints-#{idx}" role="region" aria-label="#{escape_html(hint_region)}" aria-live="polite" hidden></div>)
      <<~HTML
        <div class="cell#{exercise ? ' exercise' : ''}" data-label="#{task_label}">
          #{editors}
          <div class="cell-toolbar">#{hint_btn}#{live}#{step}<button type="button" class="run-cell" data-idx="#{idx}"#{label}#{keys}>#{run_label}</button></div>
          #{hints}
          <div class="cell-out" id="cell-out-#{idx}" style="display:none"></div>
          #{slot}
        </div>
      HTML
    end

    # 💡 Tipp beside the exercise's ▶: one hint per click (App#reveal_hint)
    def self.hint_html(idx, label, name)
      %(<button type="button" class="hint-cell" data-idx="#{idx}" aria-label="#{escape_html(name)}">#{escape_html(label)}</button>)
    end

    # the hint panel's entries (App#reveal_hint): a hint, or the solution
    # with a button that puts it into the cell
    def self.hint_step_html(text) = %(<p class="hint-step">💡 #{text}</p>)

    def self.solution_html(idx, title, code, apply_label)
      %(<div class="hint-solution"><p class="hint-step">#{title}</p><pre>#{escape_html(code)}</pre>) +
        %(<button type="button" class="hint-apply" data-idx="#{idx}">#{escape_html(apply_label)}</button></div>)
    end

    # [[name, readonly], ...] of a cell: [] without tabs, else the main
    # file ("main", app.rb) and the cell's "tabs" - a src tab is always
    # read-only, an inline one unless it says "readonly": false. Optional
    # fields with brackets (docs/PICORUBY_SHELL.md §5 #5).
    def self.tab_list(cell)
      tabs = cell[:tabs]
      return [] if tabs.nil?

      list = [[(cell[:main] || "app.rb").to_s, false]]
      tabs.to_a.each { |tab| list << [tab[:name].to_s, !tab[:src].nil? || tab[:readonly] != false] }
      list
    end

    # the tab list and one panel per file; index.html's chunkyTabs switches
    def self.tabs_html(idx, tabs, labels)
      html = %(<div class="cell-tabs" role="tablist" aria-label="#{escape_html(labels[0])}">).dup
      tabs.each_with_index do |tab, k|
        file = tab[0]
        readonly = tab[1]
        tab_id = "cell-tab-#{idx}-#{k}"
        lock = readonly ? %(<span class="cell-tab-lock" aria-hidden="true">🔒</span>) : ""
        aria = readonly ? %( aria-label="#{escape_html("#{file}, #{labels[1]}")}") : ""
        html << %(<button type="button" role="tab" class="cell-tab" id="#{tab_id}" data-idx="#{idx}" data-k="#{k}") +
                %( data-name="#{escape_html(file)}" data-readonly="#{readonly}" aria-selected="#{k.zero?}") +
                %( aria-controls="cell-panel-#{idx}-#{k}" tabindex="#{k.zero? ? 0 : -1}"#{aria}>#{lock}#{escape_html(file)}</button>)
      end
      html << "</div>"
      tabs.each_with_index do |tab, k|
        file = tab[0]
        area = k.zero? ? "cell-code-#{idx}" : "cell-code-#{idx}-#{k}"
        hidden = k.zero? ? "" : " hidden"
        html << %(<div class="cell-panel" role="tabpanel" id="cell-panel-#{idx}-#{k}" aria-labelledby="cell-tab-#{idx}-#{k}"#{hidden}>) +
                %(<textarea title="#{escape_html(file)}" id="#{area}"></textarea></div>)
      end
      html
    end

    # ⏯: runs the cell recorded, and the stepper below it walks through the
    # run (stepper.js). +name+ ("Schritt für Schritt durch Zelle 2") keeps
    # the visible words, like the Run button's.
    def self.step_html(idx, label, name)
      %(<button type="button" class="step-cell" data-idx="#{idx}" aria-label="#{escape_html(name)}">#{escape_html(label)}</button>)
    end

    # Live runs on or off - one switch for the page, drawn in every toolbar.
    # +off_here+: a lesson without live runs - the switch is off for good,
    # aria-disabled (still focusable, so its title, the reason, is read)
    def self.live_html(on, label, title, off_here = false)
      extra = off_here ? ' aria-disabled="true"' : ""
      css = off_here ? "live-toggle is-off-here" : "live-toggle"
      %(<button type="button" class="#{css}" aria-pressed="#{on}"#{extra} title="#{escape_html(title)}">#{escape_html(label)}</button>)
    end

    # The workshop's frame: workspace.rb fills the file panel (#wsFiles),
    # the stdin box and the preview of a picture or PDF (#wsPreview); the
    # editor is cell 0 like in a lesson.
    def self.workshop_html(title, intro, run_label, live = "")
      <<~HTML
        <div class="lessonText"><h2>#{title}</h2><p>#{intro}</p></div>
        <div class="workshop">
          <aside class="ws-files" id="wsFiles"></aside>
          <div class="cell ws-editor">
            <div class="ws-tab" id="wsTab"></div>
            <textarea title="code" id="cell-code-0"></textarea>
            <div class="ws-preview" id="wsPreview" hidden></div>
            <div class="ws-stdin" id="wsStdinBox"></div>
            <div class="cell-toolbar">#{live}<button type="button" class="run-cell" data-idx="0">#{run_label}</button></div>
            <div class="cell-out" id="cell-out-0" style="display:none"></div>
          </div>
        </div>
      HTML
    end

    # cached gems wear a ⚡, installed ones a ✓ and their version
    def self.gems_html(names, installed, cached_tip)
      html = "".dup
      names.each do |name|
        version = installed[name]
        css = version ? "gem-chip installed" : "gem-chip"
        label = version ? "#{name} ✓" : "#{name} ⚡"
        html << %(<button type="button" class="#{css}" data-gem="#{escape_html(name)}" title="#{escape_html(version || cached_tip)}">#{escape_html(label)}</button>)
      end
      html
    end

    def self.running_label(text)
      %(<img class="run-fox" src="assets/why-foxes/fox-head.svg" alt="">#{text})
    end

    # "1.4 s"; German writes "1,4 s"
    def self.run_time(seconds, lang)
      text = seconds < 0.1 ? "< 0.1 s" : format("%.1f s", seconds)
      lang == "de" ? text.tr(".", ",") : text
    end

    # Chunky after a passed exercise: praise, then where to go next
    def self.passed_html(praise, ui, idx, total, next_id, all_done, prefix = "#")
      return "#{praise}<br><br>#{ui.allDone}" if all_done
      return praise unless next_id

      progress = format(ui.progress, idx + 1, total)
      %(#{praise}<br><small>#{progress}</small><br><a href="#{prefix}#{next_id}" id="nextLessonLink">#{ui.nextLesson}</a>)
    end

    def self.failed_html(ui, hint)
      "#{ui.failIntro}<br>💡 #{hint}"
    end
  end
end
