# Helpers the whole shell uses. PicoRuby lacks parts of Ruby's core that
# CRuby (and so the unit tests) have - see the list in
# test/shell/portability_test.rb, which keeps them out of html/shell/.
module ChunkyShell
  WORKSHOP_ID = "werkstatt"

  module Support
    def escape_html(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end

    def code_cell?(cell)
      type = cell.t
      type == "c" || type == "x"
    end

    def el(id)
      JSG.d.getElementById(id)
    end

    # A handler or Task that raises in PicoRuby leaves one console line at
    # best; this names what failed and keeps the page going.
    def guard(what)
      yield
    rescue StandardError => e
      JSG.w.console.error("shell #{what}: #{e.class}: #{e.message}")
      nil
    end
  end
end
