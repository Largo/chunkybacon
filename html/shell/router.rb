# Where the learner is, in the address bar. On a static host a lesson is
# /#methoden (its language is the stored choice). Served by server/app.rb a
# lesson has a permalink, /de/methoden: the server says so with
# <meta name="chunky-permalinks" content="/">, which shell/bridge.js hands
# over as ChunkyBridge.permalinks - the base path, nil on a static host.
module ChunkyShell
  class Router
    # +course+ gives the lessons' slugs: a permalink names a lesson by its
    # word in the language, /en/variables, not by its id
    def initialize(base, course = nil)
      @base = base.nil? || base == "" ? nil : base.to_s
      @course = course
      @tables = {}   # lang => [{id => slug}, {slug => id}]
    end

    def permalinks? = !@base.nil?

    # what goes in front of a lesson id in a link: "#" or "/de/"
    def prefix(lang) = permalinks? ? "#{@base}#{lang}/" : "#"

    def href(lang, id)
      return "##{id}" unless permalinks?

      "#{prefix(lang)}#{JSG.w.encodeURIComponent(slug(lang, id)).to_s}"
    end

    # a lesson's (or the workshop's) word in +lang+, its id without a course
    def slug(lang, id) = tables(lang)[0][id] || id

    # The lesson id (or WORKSHOP_ID) the address names, "" for none: the
    # path's second part - or the hash, which is also how an old /#methoden
    # link arrives at a server with permalinks.
    def place
      hash = JSG.w.location.hash.to_s.delete_prefix("#")
      return hash unless permalinks? && hash == ""

      path = JSG.w.location.pathname.to_s
      return "" unless path.start_with?(@base)

      parts = path.delete_prefix(@base).split("/")
      return "" unless parts.length > 1

      # its slug in the path's language; an id stays as it is (an old
      # /en/variablen link, which the server sends on to /en/variables)
      named = JSG.w.decodeURIComponent(parts[1].to_s).to_s
      tables(parts[0].to_s)[1][named] || named
    end

    # Puts +id+ in the address: as a new history entry (+push+, so back
    # returns to where the learner was) or in place of the current one.
    def show(lang, id, push)
      url = href(lang, id)
      return if here?(url, id)

      history = JSG.w.history
      if !permalinks? && push
        JSG.w.location.hash = id   # the hashchange finds the page drawn already
      elsif push
        history.pushState(nil, "", url)
      else
        history.replaceState(nil, "", url)
      end
    end

    private

    # the slugs of one language, both ways, read from the course once
    def tables(lang)
      known = @tables[lang]
      return known if known

      to_slug = {}
      to_id = {}
      if @course && permalinks?
        @course.size.times do |idx|
          id = @course.id(idx)
          slug = @course.slug(idx, lang)
          to_slug[id] = slug
          to_id[slug] = id
        end
        slug = @course.workshop_slug(lang)
        to_slug[WORKSHOP_ID] = slug
        to_id[slug] = WORKSHOP_ID
      end
      @tables[lang] = [to_slug, to_id]
    end

    def here?(url, id)
      location = JSG.w.location
      return location.hash.to_s.delete_prefix("#") == id unless permalinks?

      location.pathname.to_s == url && location.hash.to_s == ""
    end
  end
end
