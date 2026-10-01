# Where the learner is, in the address bar. On a static host a lesson is
# /#methoden (its language is the stored choice). Served by server/app.rb a
# lesson has a permalink, /de/methoden: the server says so with
# <meta name="chunky-permalinks" content="/">, which shell/bridge.js hands
# over as ChunkyBridge.permalinks - the base path, nil on a static host.
module ChunkyShell
  class Router
    def initialize(base)
      @base = base.nil? || base == "" ? nil : base.to_s
    end

    def permalinks? = !@base.nil?

    # what goes in front of a lesson id in a link: "#" or "/de/"
    def prefix(lang) = permalinks? ? "#{@base}#{lang}/" : "#"

    def href(lang, id) = "#{prefix(lang)}#{id}"

    # The lesson id (or WORKSHOP_ID) the address names, "" for none: the
    # path's second part - or the hash, which is also how an old /#methoden
    # link arrives at a server with permalinks.
    def place
      hash = JSG.w.location.hash.to_s.delete_prefix("#")
      return hash unless permalinks? && hash == ""

      path = JSG.w.location.pathname.to_s
      return "" unless path.start_with?(@base)

      parts = path.delete_prefix(@base).split("/")
      parts.length > 1 ? parts[1].to_s : ""
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

    def here?(url, id)
      location = JSG.w.location
      return location.hash.to_s.delete_prefix("#") == id unless permalinks?

      location.pathname.to_s == url && location.hash.to_s == ""
    end
  end
end
