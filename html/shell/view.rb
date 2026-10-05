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
      course.title(idx, lang).downcase.include?(needle) || section.to_s.downcase.include?(needle)
    end

    # "13. Gems installieren" as a numbered row: the number in a badge,
    # which turns into a tick once the lesson is done
    def self.nav_link(course, idx, lang, active_id, done, prefix)
      id = course.id(idx)
      title = course.title(idx, lang)
      number = (idx + 1).to_s
      name = title.start_with?("#{number}. ") ? title[number.length + 2, title.length] : title
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
    def self.lesson_html(cells, task_label, run_label, live = "", run_name = "")
      html = "".dup
      number = 0
      cells.each_with_index do |cell, idx|
        if code_cell?(cell)
          number += 1
          switch = cell.code.to_s.include?("show_irb") ? "" : live
          name = run_name == "" ? "" : format(run_name, number)
          html << cell_html(idx, cell.t == "x", task_label, run_label, switch, name)
        else
          html << %(<div class="lessonText">#{cell.html}</div>)
        end
      end
      html
    end

    # +name+: "Run cell 2" - a lesson has up to eight buttons that all read
    # "▶ Run"; the name keeps the visible word (WCAG 2.5.3, Label in Name).
    # The exercise's button says that Alt+R presses it.
    def self.cell_html(idx, exercise, task_label, run_label, live = "", name = "")
      label = name == "" ? "" : %( aria-label="#{escape_html(name)}")
      keys = exercise ? ' aria-keyshortcuts="Alt+R"' : ""
      <<~HTML
        <div class="cell#{exercise ? ' exercise' : ''}" data-label="#{task_label}">
          <textarea title="code" id="cell-code-#{idx}"></textarea>
          <div class="cell-toolbar">#{live}<button type="button" class="run-cell" data-idx="#{idx}"#{label}#{keys}>#{run_label}</button></div>
          <div class="cell-out" id="cell-out-#{idx}" style="display:none"></div>
        </div>
      HTML
    end

    # Live runs on or off - one switch for the page, drawn in every toolbar
    def self.live_html(on, label, title)
      %(<button type="button" class="live-toggle" aria-pressed="#{on}" title="#{escape_html(title)}">#{escape_html(label)}</button>)
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
      %(<img class="run-fox" src="assets/chunky.svg" alt="">#{text})
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
