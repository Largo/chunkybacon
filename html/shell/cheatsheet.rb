# The cheat sheet (lessons.js "cheatsheet"): the course's Ruby on one page,
# topic by topic, each with the lessons that teach it and links into the
# official documentation. A panel beside the lesson, not a page of its own:
# opening it keeps the lesson and its cells' state. On a wide screen it
# stands to the right of the lesson column (app.css), so a learner can read
# it while typing; below OVERLAY it lies over the page like the index's
# drawer and goes away with × or Escape. Open or shut is a view setting,
# restored on wide screens only.
#
# Sections hold the code once and the texts per language. The rows are read
# through the bridge once per language and kept as Ruby values, so typing
# in the search field filters plain Ruby arrays.
module ChunkyShell
  class Cheatsheet
    include Support
    extend Support

    KEY = "chunkyui_cheat"
    OVERLAY = "(max-width: 1279px)"

    def initialize(app, data = JSG.w.LESSONS)
      @app = app
      list = data[:cheatsheet]
      @sections = list ? list.to_a : []
      @cache = {}        # lang => sections as Ruby values
      @query = ""
      @drawn = nil       # what the body shows: [lang, query], to draw only on change
    end

    def start
      el("cheatBtn").hidden = @sections.empty?
      return self if @sections.empty?

      wire
      render
      show(true) if Store.get(KEY, "") == "open" && !overlay?
      self
    end

    def panel = el("cheatsheet")
    def open? = JSG.d.body.classList.contains("cheat-open") == true
    def overlay? = JSG.w.matchMedia(OVERLAY).matches == true

    # a UI string in the page's language, German when missing
    def t(key)
      text = @app.ui[key] || @app.course.ui("de")[key]
      text.nil? ? key : text.to_s
    end

    def wire
      el("cheatBtn").addEventListener("click", sync: true) { guard("cheat sheet") { toggle } }
      el("cheatClose").addEventListener("click", sync: true) { guard("cheat sheet") { hide(true) } }
      el("cheatSearch").addEventListener("input", sync: true) { guard("cheat search") { search(el("cheatSearch").value) } }
      panel.addEventListener("click", sync: true) { |event| guard("cheat sheet") { panel_click(event) } }
    end

    # ---------- opening and closing ----------

    def toggle
      open? ? hide(true) : show
    end

    # +quiet+: brought back at start, without taking the keyboard
    def show(quiet = false)
      return if @sections.empty?

      panel.hidden = false
      JSG.d.body.classList.add("cheat-open")
      el("cheatBtn").setAttribute("aria-expanded", "true")
      draw_body
      Store.set(KEY, "open") unless overlay?
      return if quiet

      # on a phone the search field would pull up the keyboard at once
      overlay? ? el("cheatClose").focus : el("cheatSearch").focus
    end

    # +focus+: the keyboard goes back to the button that opened it
    def hide(focus = false)
      panel.hidden = true
      JSG.d.body.classList.remove("cheat-open")
      el("cheatBtn").setAttribute("aria-expanded", "false")
      Store.remove(KEY)
      el("cheatBtn").focus if focus
    end

    # opened from a lesson (a .cheat-link): at the section it names, if any
    def open_at(id)
      show
      jump(id) unless id.nil? || id == ""
    end

    # Escape: first empties the search, then closes - but a docked sheet only
    # when the keyboard is in it (Escape in a cell is not meant for it).
    # True when it used the key.
    def escape
      return false unless open?

      active = JSG.d[:activeElement]
      inside = !active.nil? && !active.closest("#cheatsheet").nil?
      if inside && @query != ""
        el("cheatSearch").value = ""
        search("")
        return true
      end
      return false unless inside || overlay?

      hide(true)
      true
    end

    def jump(id)
      section = el("cheat-#{id}")
      section.scrollIntoView unless section.nil?
    end

    # a chip jumps to its section; a lesson number opens that lesson
    def panel_click(event)
      target = event.target
      chip = target.closest(".cheat-chip")
      return jump(chip.getAttribute("data-cheat")) unless chip.nil?

      link = target.closest("a.cheat-lesson")
      return if link.nil?
      return if event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button != 0

      event.preventDefault
      hide if overlay?
      @app.select_lesson(link.getAttribute("data-id"))
    end

    def search(text)
      @query = text.to_s
      draw_body
    end

    # ---------- drawing ----------

    # the frame's words, in the page's language (App#render_all)
    def render
      return if @sections.empty?

      label = t("cheatButton")
      button = el("cheatBtn")
      el("cheatLabel").textContent = label
      button.setAttribute("title", t("cheatTitle"))
      el("cheatTitle").textContent = t("cheatTitle")
      el("cheatIntro").textContent = t("cheatIntro")
      close = el("cheatClose")
      close.setAttribute("aria-label", t("cheatClose"))
      close.setAttribute("title", t("cheatClose"))
      search = el("cheatSearch")
      search.setAttribute("placeholder", t("cheatSearch"))
      search.setAttribute("aria-label", t("cheatSearch"))
      draw_body if open?
    end

    # The sections and rows: drawn when the sheet shows, again only when the
    # language or the search changed (the page draws ~190 rows)
    def draw_body
      state = [@app.lang, @query]
      return if @drawn == state

      @drawn = state
      sections = sections_for(@app.lang)
      el("cheatToc").innerHTML = Cheatsheet.toc_html(sections, @query)
      el("cheatBody").innerHTML = Cheatsheet.body_html(sections, @query, t("cheatLessons"), t("cheatDocs"), t("cheatNone"))
    end

    # The sections in one language as Ruby values:
    # {id:, title:, lessons: [[id, number, href]], docs: [[label, url]], rows: [[code, html, haystack]]}
    def sections_for(lang)
      cached = @cache[lang]
      return cached unless cached.nil?

      @cache[lang] = @sections.map { |section| section_data(section, lang) }
    end

    def section_data(section, lang)
      course = @app.course
      lessons = []
      section.lessons.to_a.each do |id|
        idx = course.index(id.to_s)
        lessons << [id.to_s, idx + 1, @app.href(id.to_s)] unless idx.nil?
      end
      docs = section.docs.to_a.map do |doc|
        [(doc[lang] || doc.de).to_s, (lang == "ja" ? doc.urlJa : doc.url).to_s]
      end
      rows = section.rows.to_a.map do |row|
        code = row.c.to_s
        html = (row[lang] || row.de).to_s
        [code, html, "#{code} #{html}".downcase]
      end
      title = section.title
      { id: section.id.to_s, title: (title[lang] || title.de).to_s, lessons: lessons, docs: docs, rows: rows }
    end

    # the rows of +section+ that +needle+ (lowercase) finds - all of them
    # when it finds the section's name
    def self.matches(section, needle)
      return section[:rows] if needle == "" || section[:title].downcase.include?(needle)

      section[:rows].select { |row| row[2].include?(needle) }
    end

    # Code beside its explanation; code over several lines, or too long for
    # half the sheet, above it (app.css: .cheat-wide)
    WIDE = 20

    def self.row_html(row)
      code = escape_html(row[0])
      if row[0].include?("\n") || row[0].length > WIDE
        %(<tr class="cheat-wide"><td colspan="2"><code>#{code}</code><div>#{row[1]}</div></td></tr>)
      else
        %(<tr><td><code>#{code}</code></td><td>#{row[1]}</td></tr>)
      end
    end

    # one chip per section with something to show
    def self.toc_html(sections, query)
      needle = query.to_s.strip.downcase
      html = "".dup
      sections.each do |section|
        next if matches(section, needle).empty?

        html << %(<button type="button" class="cheat-chip" data-cheat="#{section[:id]}">#{escape_html(section[:title])}</button>)
      end
      html
    end

    # +lessons+: "Lektion"; +docs+: "Doku"; +none+: what an empty search says
    def self.body_html(sections, query, lessons, docs, none)
      needle = query.to_s.strip.downcase
      html = "".dup
      sections.each do |section|
        rows = matches(section, needle)
        next if rows.empty?

        html << %(<section class="cheat-section" id="cheat-#{section[:id]}">)
        html << %(<h3><span class="cheat-name">#{escape_html(section[:title])}</span>)
        unless section[:lessons].empty?
          links = section[:lessons].map do |lesson|
            %(<a class="cheat-lesson" href="#{escape_html(lesson[2])}" data-id="#{lesson[0]}">#{lesson[1]}</a>)
          end
          html << %(<span class="cheat-lessons">#{escape_html(lessons)} #{links.join(", ")}</span>)
        end
        html << %(</h3><table class="cheat"><tbody>)
        rows.each { |row| html << row_html(row) }
        html << "</tbody></table>"
        unless section[:docs].empty?
          links = section[:docs].map do |doc|
            %(<a href="#{escape_html(doc[1])}" target="_blank" rel="noopener">#{escape_html(doc[0])}</a>)
          end
          html << %(<p class="cheat-docs"><span>#{escape_html(docs)}:</span> #{links.join(" · ")}</p>)
        end
        html << "</section>"
      end
      html == "" ? %(<p class="cheat-none">#{escape_html(none)}</p>) : html
    end
  end
end
