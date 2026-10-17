# The IronRuby side of the IronRuby lesson ("engine": "ironruby",
# docs/HANDOVER.md §6s). ironruby_worker.js writes this file to
# /ironruby/lib/lab_display.rb, inside IronRuby on .NET in WebAssembly, and
# requires it once after the boot, before the first cell - so a cell's
# line numbers are its own.
#
# show_png, show_svg and show_html print one line each: a \u0001, "LAB:",
# the kind and the picture in base64. The page (ironruby_cells.rb) takes
# these lines out of the output and shows the pictures below it.
module Lab
  MARK = "\u0001LAB:"

  def self.emit(kind, b64)
    $stdout.write("#{MARK}#{kind}:#{b64}\n")
    nil
  end
end

# an SVG document (a String)
def show_svg(svg) = Lab.emit("svg", [svg.to_s].pack("m0"))

# PNG bytes: a Ruby String or .NET's System::Byte[]
def show_png(bytes)
  b64 = bytes.is_a?(String) ? [bytes].pack("m0") : System::Convert.ToBase64String(bytes).to_s
  Lab.emit("png", b64)
end

# an HTML fragment, shown in a sandboxed frame (no scripts)
def show_html(html) = Lab.emit("html", [html.to_s].pack("m0"))

# System.Numerics (BigInteger, Complex) is part of .NET but not loaded until asked for
load_assembly "System.Runtime.Numerics"
