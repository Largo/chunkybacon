# The course as JavaScript parsed it (window.LESSONS, shell/bridge.js).
# Fields are read through the bridge, about a microsecond each. Parsing the
# lessons.js JSON in PicoRuby itself would take over half a minute.
module ChunkyShell
  class Course
    attr_reader :ids, :langs

    def initialize(data)
      @ui = data.ui
      @lessons = data.lessons.to_a
      @ids = @lessons.map { |lesson| lesson.id }
      @langs = JSG.w.Object.keys(@ui).to_a
    end

    def size = @lessons.length
    def index(id) = @ids.index(id)
    def id(idx) = @ids[idx]
    def lang?(lang) = @langs.include?(lang)
    def ui(lang) = @ui[lang]

    # a lesson in one language; German when a translation is missing
    def l10n(idx, lang)
      lesson = @lessons[idx]
      lesson[lang] || lesson.de
    end

    def title(idx, lang) = l10n(idx, lang).title
    def cells(idx, lang) = l10n(idx, lang).cells.to_a

    # The heading a lesson opens in the index with, if any. An optional
    # field is read with brackets: a dot read of a missing property also
    # answers nil, but PicoRuby logs "Method not found" for it.
    def section(idx, lang)
      section = @lessons[idx][:section]
      section && (section[lang] || section.de)
    end
  end
end
