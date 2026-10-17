# Writes html/pico/lib/font5x7.rb, the 5 x 7 pixel font of the Pico lessons'
# e-paper driver (html/pico/lib/*/epd2in13.rb) and of the checks'
# Frame#text? (html/picoruby_cells.rb): ASCII 0x20..0x7E from the X11
# misc-fixed font 5x7.bdf, which is public domain ("Public domain font.
# Share and enjoy."; https://gitlab.freedesktop.org/xorg/font/misc-misc).
#
#   ruby tools/build_font5x7.rb path/to/5x7.bdf
OUT = File.expand_path("../html/pico/lib/font5x7.rb", __dir__)

bdf = File.read(ARGV.fetch(0) { abort "usage: ruby tools/build_font5x7.rb 5x7.bdf" })
glyphs = {}
bdf.scan(/^ENCODING (\d+)\n.*?^BBX (\d+) (\d+) (-?\d+) (-?\d+)\nBITMAP\n(.*?)^ENDCHAR/m) do |enc, w, h, xo, yo, bitmap|
  code = enc.to_i
  next unless (0x20..0x7E).cover?(code)

  rows = bitmap.split.map { |hex| hex.to_i(16) }
  # the cell: 7 rows, baseline at row 6 (FONT_ASCENT 6, DESCENT 1)
  cell = Array.new(7, 0)
  top = 6 - (h.to_i + yo.to_i)
  rows.each_with_index do |bits, i|
    y = top + i
    next unless (0...7).cover?(y)

    cell[y] = (bits >> 3) >> xo.to_i   # 8-bit row, the 5 leftmost pixels
  end
  glyphs[code] = cell
end
abort "only #{glyphs.size} glyphs" unless glyphs.size == 95

lines = (0x20..0x7E).map do |code|
  hex = glyphs[code].map { |r| format("%02x", r) }.join
  "  #{hex} #{code == 0x5C ? 'backslash' : code.chr}"
end
# A heredoc of hex, decoded when the file loads: PicoRuby 4.0.3's compiler
# runs out of memory (and worse) on an Array literal of 95 Arrays.
File.write(OUT, <<~RUBY)
  # A 5 x 7 pixel font for the Pico lessons: ASCII 0x20 (space) to 0x7E (~).
  # Derived from the X11 misc-fixed font 5x7.bdf, which is public domain
  # ("Public domain font. Share and enjoy."); made by tools/build_font5x7.rb.
  #
  # FONT5X7[char.ord - 32] is the character's 7 rows, top to bottom; in each
  # row, bit 4 (0x10) is the leftmost of its 5 pixels. A character takes 5
  # pixels across (FONT5X7_ADVANCE, the font's own width: most glyphs are
  # 4 wide, with the gap built in).
  FONT5X7_ADVANCE = 5

  # one line per character: its 7 rows as two hex digits each, then the
  # character itself
  FONT5X7_HEX = <<~HEX
  #{lines.join("\n")}
  HEX

  FONT5X7 = []
  FONT5X7_HEX.split("\\n").each do |line|
    glyph = []
    7.times { |row| glyph << line[row * 2, 2].to_i(16) }
    FONT5X7 << glyph
  end
RUBY
puts "#{OUT}: #{glyphs.size} glyphs"
