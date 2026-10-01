# The page's HTML, as strings: one innerHTML write per part is the fastest
# way through the bridge. Everything here is a plain function of its
# arguments, which is what the unit tests look at. The markup (ids, classes)
# is the one app.css, workspace.rb, the kernel and the tests rely on.
module ChunkyShell
  module View
    extend Support

    def self.nav_html(course, lang, active_id, done)
      html = "".dup
      course.ids.each_with_index do |id, idx|
        section = course.section(idx, lang)
        html << %(<div class="nav-section">#{section}</div>) if section
        classes = []
        classes << "active" if id == active_id
        classes << "done" if done.include?(id)
        html << %(<a class="#{classes.join(' ')}" href="##{id}" data-id="#{id}">#{course.title(idx, lang)}</a>)
      end
      html
    end

    def self.lesson_html(cells, task_label, run_label)
      html = "".dup
      cells.each_with_index do |cell, idx|
        if code_cell?(cell)
          html << cell_html(idx, cell.t == "x", task_label, run_label)
        else
          html << %(<div class="lessonText">#{cell.html}</div>)
        end
      end
      html
    end

    def self.cell_html(idx, exercise, task_label, run_label)
      <<~HTML
        <div class="cell#{exercise ? ' exercise' : ''}" data-label="#{task_label}">
          <textarea title="code" id="cell-code-#{idx}"></textarea>
          <div class="cell-toolbar"><button type="button" class="run-cell" data-idx="#{idx}">#{run_label}</button></div>
          <div class="cell-out" id="cell-out-#{idx}" style="display:none"></div>
        </div>
      HTML
    end

    # The workshop's frame: workspace.rb fills the file panel (#wsFiles),
    # the stdin box and the preview of a picture or PDF (#wsPreview); the
    # editor is cell 0 like in a lesson.
    def self.workshop_html(title, intro, run_label)
      <<~HTML
        <div class="lessonText"><h2>#{title}</h2><p>#{intro}</p></div>
        <div class="workshop">
          <aside class="ws-files" id="wsFiles"></aside>
          <div class="cell ws-editor">
            <div class="ws-tab" id="wsTab"></div>
            <textarea title="code" id="cell-code-0"></textarea>
            <div class="ws-preview" id="wsPreview" hidden></div>
            <div class="ws-stdin" id="wsStdinBox"></div>
            <div class="cell-toolbar"><button type="button" class="run-cell" data-idx="0">#{run_label}</button></div>
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
    def self.passed_html(praise, ui, idx, total, next_id, all_done)
      return "#{praise}<br><br>#{ui.allDone}" if all_done
      return praise unless next_id

      progress = format(ui.progress, idx + 1, total)
      %(#{praise}<br><small>#{progress}</small><br><a href="##{next_id}" id="nextLessonLink">#{ui.nextLesson}</a>)
    end

    def self.failed_html(ui, hint)
      "#{ui.failIntro}<br>💡 #{hint}"
    end
  end
end
