# The kernel's side of a lesson with "engine": "ironruby" (the IronRuby
# lesson, docs/HANDOVER.md §6s). Its cells run on IronRuby 4.0 (.NET 10 in
# WebAssembly) in a Web Worker (ironruby_lab.js, ironruby_worker.js,
# ironruby_lab.rb), which answers in text, as the PicoRuby lesson's worker
# does - so the values, errors and syntax messages are PicoRubyCells'
# (picoruby_cells.rb).
#
# What is the IronRuby lesson's own: the pictures. show_png, show_svg and
# show_html in IronRuby print a line "\u0001LAB:<kind>:<base64>"
# (ironruby_lab.rb); +split+ takes these lines out of the output and
# +html+ turns them into what the page shows below it.
#
# Also loaded by test/check_harness.rb.
module IronRubyCells
  MARK = /^\u0001LAB:(png|svg|html):([A-Za-z0-9+\/=]*)\n?/

  module_function

  # [the output without the picture lines, [[kind, base64], ...]]
  def split(output)
    shows = []
    text = output.to_s.gsub(MARK) do
      shows << [Regexp.last_match(1), Regexp.last_match(2)]
      ""
    end
    [text, shows]
  end

  # an <img> for a PNG or an SVG, a sandboxed frame (no scripts) for HTML
  def html(kind, b64)
    case kind
    when "png" then %(<img class="cell-image ironruby-png" alt="" src="data:image/png;base64,#{b64}">)
    when "svg" then %(<img class="cell-image ironruby-svg" alt="" src="data:image/svg+xml;base64,#{b64}">)
    when "html"
      doc = "<!doctype html><meta charset='utf-8'><style>body{font-family:sans-serif;margin:0.6rem}" \
            "table{border-collapse:collapse}td,th{border:1px solid #bbb;padding:0.2rem 0.5rem}</style>" +
            b64.unpack1("m0").force_encoding("UTF-8")
      %(<iframe class="ironruby-html" sandbox="" title="HTML" srcdoc="#{escape(doc)}"></iframe>)
    else ""
    end
  end

  def escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;").gsub("'", "&#39;")
  end
end
