# The kernel's side of a lesson with "engine": "jruby" (the JRuby lesson,
# docs/HANDOVER.md §6r). Its cells run on JRuby 10.1 (TeaVM) in a Web Worker
# (jruby_lab.js, jruby_worker.js, jruby_lab.rb), which answers in text, as
# the PicoRuby lesson's worker does - so the values, errors and syntax
# messages are PicoRubyCells' (picoruby_cells.rb).
#
# What is the JRuby lesson's own: the earthquake data for CRuby. A cell with
# "on": "cruby", and the exercise's check, run here on the page's ruby.wasm
# and read the same USGS snapshot JRuby has mounted, under the same name
# (JRuby's working directory is /, its data/ is the zip at /data): a virtual
# file of the sandbox (sandbox_sim.rb), fetched the first time a CRuby run
# needs it - 0.9 MB over the wire (all_month.geojson.gz), 7.3 MB as text.
#
# Also loaded by test/check_harness.rb, whose fetch reads the checkout.
module JRubyCells
  Value = PicoRubyCells::Value
  DATA = { "data/all_month.geojson" => "assets/jruby/data/all_month.geojson" }.freeze

  class << self
    # url -> text, nil when it cannot be fetched (main.rb: fetchTextSync)
    attr_accessor :fetch_text
  end

  module_function

  def value(text) = PicoRubyCells.value(text)
  def error(name, message, line, file) = PicoRubyCells.error(name, message, line, file)
  def class_name(error) = PicoRubyCells.class_name(error)
  def syntax_error(code, file) = PicoRubyCells.syntax_error(code, file)

  # An output made only of half blocks (█▀▄ and spaces) - the lesson's QR
  # code - as an SVG: each character one pixel wide and two tall, black on
  # white. As text its rows depend on the font (a block glyph taller than
  # half the line squeezes the white rows, and a phone cannot read the
  # code); drawn, every module is square. nil for any other output.
  BLOCK_PX = 5

  def blocks_svg(output, label)
    text = output.to_s.chomp
    return nil if text.empty? || !text.match?(/\A[█▀▄ \n]+\z/) || !text.match?(/[█▀▄]/)

    lines = text.split("\n", -1)
    width = lines.map(&:length).max
    height = lines.size * 2
    path = +""
    lines.each_with_index do |line, row|
      line.each_char.with_index do |char, col|
        y = row * 2
        case char
        when "█" then path << "M#{col} #{y}h1v2h-1z"
        when "▀" then path << "M#{col} #{y}h1v1h-1z"
        when "▄" then path << "M#{col} #{y + 1}h1v1h-1z"
        end
      end
    end
    label = label.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub('"', "&quot;")
    %(<svg class="cell-blocks" role="img" aria-label="#{label}" xmlns="http://www.w3.org/2000/svg" ) +
      %(viewBox="0 0 #{width} #{height}" width="#{width * BLOCK_PX}" height="#{height * BLOCK_PX}" shape-rendering="crispEdges">) +
      %(<rect width="#{width}" height="#{height}" fill="#fff"/><path d="#{path}" fill="#000"/></svg>)
  end

  # the data files for a CRuby run; true when they are there
  def load_data
    DATA.all? do |name, url|
      next true if SandboxFS.exist?(name)

      text = fetch_text&.call(url)
      SandboxFS.write(name, text) if text
      !text.nil?
    end
  end
end
