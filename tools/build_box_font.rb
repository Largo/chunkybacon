# Builds html/assets/fonts/chunky-box-drawing.woff: the box-drawing and
# block characters (U+2500-259F) as wide as Atkinson Hyperlegible Mono's
# letters, which the code font itself does not have.
#
# Without it the browser takes them from some other monospace font, whose
# letters are narrower or wider: a table drawn by tty-table or tty-box
# (lesson 35) then has its right edge out of line, and the vertical lines
# have gaps, because the cells' output runs at line-height 1.6. Here every
# glyph is 0.632 em wide, like the code font's, and the vertical strokes
# reach 0.8 em above and below the middle of the line, so they join.
#
# fonts.css maps the range onto the "Atkinson Hyperlegible Mono" family.
# The glyphs are drawn from rectangles below: no source font, so the file is
# part of the course's code (MIT). Plain WOFF (zlib), as WOFF2 would need
# Brotli.
#
#   ruby tools/build_box_font.rb

require "zlib"

OUT = File.expand_path("../html/assets/fonts/chunky-box-drawing.woff", __dir__)

# Atkinson Hyperlegible Mono's metrics, in thousandths of an em (measured in
# the browser: canvas measureText with the font at 1000px)
EM = 1000
ADVANCE = 632
ASCENT = 984
DESCENT = 316
LINE_HEIGHT = 1600 # .cell-stdout's line-height: 1.6

# The middle of the line box (half the leading goes above, half below, so
# it is the same for any line-height), and the box's top and bottom
CX = ADVANCE / 2
CY = (ASCENT - DESCENT) / 2
TOP = CY + LINE_HEIGHT / 2
BOTTOM = CY - LINE_HEIGHT / 2
# strokes reach a little into the neighbour, so no hairline seam shows
OVERLAP = 8

LIGHT = 50    # half the thickness of a light line (~1.4 px at 14.4 px)
HEAVY = 95
GAP = 125     # a double line: two lines this far either side of the middle
THIN = 42     # ...each this half thick
DOUBLE_REACH = GAP + THIN

# The arms of U+2500-257F, read off their Unicode names (BOX DRAWINGS DOWN
# SINGLE AND RIGHT DOUBLE ...): up, right, down, left - l(ight), h(eavy),
# d(ouble) or none. Dashes, arcs and diagonals are drawn on their own.
ARMS = <<~TABLE.split.to_h { |entry| [entry[0, 4].to_i(16), entry[4, 4]] }
  2500-l-l 2501-h-h 2502l-l- 2503h-h- 250C-ll- 250D-hl- 250E-lh- 250F-hh-
  2510--ll 2511--lh 2512--hl 2513--hh 2514ll-- 2515lh-- 2516hl-- 2517hh--
  2518l--l 2519l--h 251Ah--l 251Bh--h 251Clll- 251Dlhl- 251Ehll- 251Fllh-
  2520hlh- 2521hhl- 2522lhh- 2523hhh- 2524l-ll 2525l-lh 2526h-ll 2527l-hl
  2528h-hl 2529h-lh 252Al-hh 252Bh-hh 252C-lll 252D-llh 252E-hll 252F-hlh
  2530-lhl 2531-lhh 2532-hhl 2533-hhh 2534ll-l 2535ll-h 2536lh-l 2537lh-h
  2538hl-l 2539hl-h 253Ahh-l 253Bhh-h 253Cllll 253Dlllh 253Elhll 253Flhlh
  2540hlll 2541llhl 2542hlhl 2543hllh 2544hhll 2545llhh 2546lhhl 2547hhlh
  2548lhhh 2549hlhh 254Ahhhl 254Bhhhh 2550-d-d 2551d-d- 2552-dl- 2553-ld-
  2554-dd- 2555--ld 2556--dl 2557--dd 2558ld-- 2559dl-- 255Add-- 255Bl--d
  255Cd--l 255Dd--d 255Eldl- 255Fdld- 2560ddd- 2561l-ld 2562d-dl 2563d-dd
  2564-dld 2565-ldl 2566-ddd 2567ld-d 2568dl-l 2569dd-d 256Aldld 256Bdldl
  256Cdddd 2574---l 2575l--- 2576-l-- 2577--l- 2578---h 2579h--- 257A-h--
  257B--h- 257C-h-l 257Dl-h- 257E-l-h 257Fh-l-
TABLE

# dashed lines: [horizontal?, half thickness, dashes]
DASHES = {
  0x2504 => [true, LIGHT, 3], 0x2505 => [true, HEAVY, 3], 0x2506 => [false, LIGHT, 3], 0x2507 => [false, HEAVY, 3],
  0x2508 => [true, LIGHT, 4], 0x2509 => [true, HEAVY, 4], 0x250A => [false, LIGHT, 4], 0x250B => [false, HEAVY, 4],
  0x254C => [true, LIGHT, 2], 0x254D => [true, HEAVY, 2], 0x254E => [false, LIGHT, 2], 0x254F => [false, HEAVY, 2]
}.freeze

# rounded corners: the two arms they join
ARCS = { 0x256D => %w[R D], 0x256E => %w[L D], 0x256F => %w[U L], 0x2570 => %w[U R] }.freeze

# A glyph is a list of contours, each a list of [x, y] points, clockwise.
def rect(x0, y0, x1, y1)
  x0, x1 = [x0, x1].minmax
  y0, y1 = [y0, y1].minmax
  [[x0, y0], [x0, y1], [x1, y1], [x1, y0]]
end

def clockwise(points)
  area = points.each_with_index.sum { |(x0, y0), i| x1, y1 = points[(i + 1) % points.size]; (x1 - x0) * (y1 + y0) }
  area.negative? ? points.reverse : points
end

# a straight stroke from one point to another, +half+ thick either side
def segment(x0, y0, x1, y1, half)
  length = Math.hypot(x1 - x0, y1 - y0)
  nx = -(y1 - y0) / length * half
  ny = (x1 - x0) / length * half
  clockwise([[x0 + nx, y0 + ny], [x1 + nx, y1 + ny], [x1 - nx, y1 - ny], [x0 - nx, y0 - ny]].map { |x, y| [x.round, y.round] })
end

HALF = { "l" => LIGHT, "h" => HEAVY, "d" => DOUBLE_REACH }.freeze
# per arm: how far it reaches out from the middle, and its two sides
# (the arm on the + side and on the - side of the stroke)
REACH = { "U" => TOP - CY, "D" => CY - BOTTOM, "R" => ADVANCE - CX, "L" => CX }.freeze
SIDES = { "U" => %w[R L], "D" => %w[R L], "R" => %w[U D], "L" => %w[U D] }.freeze

# Local coordinates of an arm - +along+ outward from the middle, +across+
# towards its + side - turned into the glyph's
def place(dir, along, across)
  case dir
  when "R" then [CX + along, CY + across]
  when "L" then [CX - along, CY + across]
  when "U" then [CX + across, CY + along]
  when "D" then [CX + across, CY - along]
  end
end

def arm_rect(dir, a0, a1, p0, p1)
  x0, y0 = place(dir, a0, p0)
  x1, y1 = place(dir, a1, p1)
  rect(x0, y0, x1, y1)
end

# One arm. A single line starts behind the middle, as far as the widest
# stroke across it reaches, so corners and crossings come out filled. Each
# line of a double one starts where it meets the stroke on its side - or,
# with nothing on that side, the far line of the stroke on the other.
def arm(dir, weight, arms)
  far = REACH[dir] + OVERLAP
  plus, minus = SIDES[dir]
  if weight == "d"
    [[1, plus, minus], [-1, minus, plus]].map do |sign, near, opposite|
      start = if arms[near]
                arms[near] == "d" ? GAP - THIN : -HALF[arms[near]]
              elsif arms[opposite]
                -HALF[arms[opposite]]
              else
                0
              end
      arm_rect(dir, start, far, sign * GAP - THIN, sign * GAP + THIN)
    end
  else
    behind = [arms[plus], arms[minus]].compact.map { |w| HALF[w] }.max || 0
    half = HALF[weight]
    [arm_rect(dir, -behind, far, -half, half)]
  end
end

def box_glyph(code)
  if (spec = ARMS[code])
    arms = %w[U R D L].zip(spec.chars).reject { |_, w| w == "-" }.to_h
    arms.flat_map { |dir, weight| arm(dir, weight, arms) }
  elsif (dash = DASHES[code])
    horizontal, half, count = dash
    from, to = horizontal ? [0, ADVANCE] : [BOTTOM, TOP]
    slot = (to - from) / count.to_f
    count.times.map do |i|
      a = (from + slot * i + slot * 0.2).round
      b = (from + slot * (i + 1) - slot * 0.2).round
      horizontal ? rect(a, CY - half, b, CY + half) : rect(CX - half, a, CX + half, b)
    end
  elsif (pair = ARCS[code])
    arc(*pair)
  elsif code.between?(0x2571, 0x2573)
    rising = segment(-OVERLAP, BOTTOM - OVERLAP, ADVANCE + OVERLAP, TOP + OVERLAP, LIGHT)
    falling = segment(-OVERLAP, TOP + OVERLAP, ADVANCE + OVERLAP, BOTTOM - OVERLAP, LIGHT)
    { 0x2571 => [rising], 0x2572 => [falling], 0x2573 => [rising, falling] }[code]
  else
    block_glyph(code)
  end
end

# A rounded corner: both arms straight up to the radius, a quarter circle
# between them
def arc(first, second)
  radius = 240
  # the corner's centre, +radius+ away from the middle towards both arms
  ox, oy = place(first, radius, 0)
  dx, dy = place(second, radius, 0)
  centre = [ox + dx - CX, oy + dy - CY]
  start = Math.atan2(oy - centre[1], ox - centre[0])
  finish = Math.atan2(dy - centre[1], dx - centre[0])
  finish += 2 * Math::PI while finish - start < -Math::PI
  finish -= 2 * Math::PI while finish - start > Math::PI
  steps = 12
  points = (0..steps).map do |i|
    angle = start + (finish - start) * i / steps
    [centre[0] + radius * Math.cos(angle), centre[1] + radius * Math.sin(angle)]
  end
  curve = points.each_cons(2).map { |(x0, y0), (x1, y1)| segment(x0, y0, x1, y1, LIGHT) }
  straight = [first, second].map { |dir| arm_rect(dir, radius - 4, REACH[dir] + OVERLAP, -LIGHT, LIGHT) }
  curve + straight
end

# U+2580-259F: blocks fill the whole line box, so they stack without gaps
def block_glyph(code)
  left = -OVERLAP / 2
  right = ADVANCE + OVERLAP / 2
  bottom = BOTTOM - OVERLAP / 2
  top = TOP + OVERLAP / 2
  eighth_h = LINE_HEIGHT / 8.0
  eighth_w = ADVANCE / 8.0
  quadrants = { ul: rect(left, CY, CX, top), ur: rect(CX, CY, right, top),
                ll: rect(left, bottom, CX, CY), lr: rect(CX, bottom, right, CY) }
  case code
  when 0x2580 then [rect(left, CY, right, top)]
  when 0x2581..0x2588 then [rect(left, bottom, right, (BOTTOM + eighth_h * (code - 0x2580)).round)]
  when 0x2589..0x258F then [rect(left, bottom, (eighth_w * (0x2590 - code)).round, top)]
  when 0x2590 then [rect(CX, bottom, right, top)]
  when 0x2591..0x2593 then shade(code - 0x2590)
  when 0x2594 then [rect(left, (TOP - eighth_h).round, right, top)]
  when 0x2595 then [rect((ADVANCE - eighth_w).round, bottom, right, top)]
  else
    names = { 0x2596 => %i[ll], 0x2597 => %i[lr], 0x2598 => %i[ul], 0x2599 => %i[ul ll lr],
              0x259A => %i[ul lr], 0x259B => %i[ul ur ll], 0x259C => %i[ul ur lr], 0x259D => %i[ur],
              0x259E => %i[ur ll], 0x259F => %i[ur ll lr] }.fetch(code)
    names.map { |name| quadrants[name] }
  end
end

# light, medium and dark shade: a quarter, half or three quarters of a grid
# of small squares inked
def shade(level)
  columns = 4
  rows = 10
  width = ADVANCE / columns.to_f
  height = LINE_HEIGHT / rows.to_f
  (0...columns).to_a.product((0...rows).to_a).filter_map do |i, j|
    inked = case level
            when 1 then i.even? && j.even?
            when 2 then (i + j).even?
            else !(i.even? && j.even?)
            end
    next unless inked

    rect((width * i).round, (BOTTOM + height * j).round, (width * (i + 1)).round, (BOTTOM + height * (j + 1)).round)
  end
end

# ---------- the TrueType file ----------

CODES = (0x2500..0x259F).to_a
GLYPHS = [[]] + CODES.map { |code| box_glyph(code) } # glyph 0: .notdef, empty

def u16(n) = [n & 0xFFFF].pack("n")
def i16(n) = [n].pack("s>")
def u32(n) = [n & 0xFFFFFFFF].pack("N")

def bounds(contours)
  points = contours.flatten(1)
  return [0, 0, 0, 0] if points.empty?

  xs = points.map(&:first)
  ys = points.map(&:last)
  [xs.min, ys.min, xs.max, ys.max]
end

# simple glyphs, every point on the curve, coordinates as 16-bit deltas
def glyf_entry(contours)
  return "".b if contours.empty?

  x_min, y_min, x_max, y_max = bounds(contours)
  data = i16(contours.size) + i16(x_min) + i16(y_min) + i16(x_max) + i16(y_max)
  last = -1
  contours.each { |c| data << u16(last += c.size) }
  data << u16(0) # no instructions
  points = contours.flatten(1)
  data << ("\x01".b * points.size)
  x = y = 0
  points.each { |px, _| data << i16(px - x); x = px }
  points.each { |_, py| data << i16(py - y); y = py }
  data << ("\0".b * (-data.bytesize % 4))
end

def checksum(data)
  padded = data + ("\0".b * (-data.bytesize % 4))
  padded.unpack("N*").sum & 0xFFFFFFFF
end

def name_table
  records = {
    0 => "Generated by tools/build_box_font.rb (MIT)",
    1 => "Chunky Box Drawing", 2 => "Regular", 3 => "Chunky Box Drawing 1.0",
    4 => "Chunky Box Drawing", 5 => "Version 1.0", 6 => "ChunkyBoxDrawing-Regular"
  }
  strings = "".b
  entries = records.map do |id, text|
    bytes = text.encode("UTF-16BE").b
    entry = u16(3) + u16(1) + u16(0x409) + u16(id) + u16(bytes.bytesize) + u16(strings.bytesize)
    strings << bytes
    entry
  end
  u16(0) + u16(records.size) + u16(6 + 12 * records.size) + entries.join + strings
end

def build_tables
  glyf = "".b
  offsets = [0]
  GLYPHS.each do |contours|
    glyf << glyf_entry(contours)
    offsets << glyf.bytesize
  end
  boxes = GLYPHS.reject(&:empty?).map { |c| bounds(c) }
  x_min = boxes.map { |b| b[0] }.min
  y_min = boxes.map { |b| b[1] }.min
  x_max = boxes.map { |b| b[2] }.max
  y_max = boxes.map { |b| b[3] }.max
  max_points = GLYPHS.map { |c| c.sum(&:size) }.max
  max_contours = GLYPHS.map(&:size).max

  # created and modified: a fixed day (seconds since 1904), so a rebuild
  # gives the same file
  date = [Time.utc(2026, 10, 4).to_i + 2_082_844_800].pack("q>")
  head = u32(0x00010000) + u32(0x00010000) + u32(0) + u32(0x5F0F3CF5) + u16(0x000B) + u16(EM) +
         date + date + i16(x_min) + i16(y_min) + i16(x_max) + i16(y_max) +
         u16(0) + u16(8) + i16(2) + i16(1) + i16(0)
  hhea = u32(0x00010000) + i16(ASCENT) + i16(-DESCENT) + i16(0) + u16(ADVANCE) +
         i16(x_min) + i16(ADVANCE - x_max) + i16(x_max) + i16(1) + i16(0) + i16(0) +
         ("\0".b * 8) + i16(0) + u16(GLYPHS.size)
  maxp = u32(0x00010000) + u16(GLYPHS.size) + u16(max_points) + u16(max_contours) +
         u16(0) + u16(0) + u16(2) + ("\0".b * 16)
  os2 = u16(4) + i16(ADVANCE) + u16(400) + u16(5) + u16(0) +
        ([i16(650), i16(600), i16(0), i16(75)] * 2).join + i16(50) + i16(250) + i16(0) +
        ("\0".b * 10) + ("\0".b * 16) + "NONE".b + u16(0x0040) + u16(CODES.first) + u16(CODES.last) +
        i16(ASCENT) + i16(-DESCENT) + i16(0) + u16(ASCENT) + u16(DESCENT) + u32(0) + u32(0) +
        i16(500) + i16(700) + u16(0) + u16(0x20) + u16(0)
  os2[62, 2] = u16(0x00C0) # fsSelection: REGULAR | USE_TYPO_METRICS
  hmtx = GLYPHS.map { |c| u16(ADVANCE) + i16(c.empty? ? 0 : bounds(c)[0]) }.join
  # cmap: one format 4 segment for the whole range, glyph = code - 0x2500 + 1
  delta = (1 - CODES.first) & 0xFFFF
  seg = u16(4) + u16(0) + u16(0) + u16(4) + u16(4) + u16(1) + u16(0) +
        u16(CODES.last) + u16(0xFFFF) + u16(0) + u16(CODES.first) + u16(0xFFFF) +
        u16(delta) + u16(1) + u16(0) + u16(0)
  seg[2, 2] = u16(seg.bytesize)
  cmap = u16(0) + u16(1) + u16(3) + u16(1) + u32(12) + seg
  post = u32(0x00030000) + ("\0".b * 28)
  post[8, 4] = i16(-100) + i16(LIGHT * 2)
  post[12, 4] = u32(1) # isFixedPitch
  {
    "OS/2" => os2, "cmap" => cmap, "glyf" => glyf, "head" => head, "hhea" => hhea, "hmtx" => hmtx,
    "loca" => offsets.map { |o| u32(o) }.join, "maxp" => maxp, "name" => name_table, "post" => post
  }
end

# The sfnt as one file, so head's checkSumAdjustment can be worked out
def sfnt(tables)
  count = tables.size
  power = 2**Math.log2(count).floor
  dir = u32(0x00010000) + u16(count) + u16(power * 16) + u16(Math.log2(power).to_i) + u16(count * 16 - power * 16)
  offset = 12 + 16 * count
  body = "".b
  tables.sort.each do |tag, data|
    dir << tag.b + u32(checksum(data)) + u32(offset + body.bytesize) + u32(data.bytesize)
    body << data << ("\0".b * (-data.bytesize % 4))
  end
  dir + body
end

def woff(tables)
  tables["head"][8, 4] = u32(0)
  tables["head"][8, 4] = u32((0xB1B0AFBA - checksum(sfnt(tables))) & 0xFFFFFFFF)
  entries = tables.sort.map do |tag, data|
    packed = Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
    packed = data if packed.bytesize >= data.bytesize
    [tag, data, packed]
  end
  offset = 44 + 20 * entries.size
  dir = "".b
  body = "".b
  entries.each do |tag, data, packed|
    dir << tag.b + u32(offset + body.bytesize) + u32(packed.bytesize) + u32(data.bytesize) + u32(checksum(data))
    body << packed << ("\0".b * (-packed.bytesize % 4))
  end
  total_sfnt = 12 + 16 * entries.size + entries.sum { |_, data, _| (data.bytesize + 3) & ~3 }
  header = "wOFF".b + u32(0x00010000) + u32(44 + dir.bytesize + body.bytesize) + u16(entries.size) + u16(0) +
           u32(total_sfnt) + u16(1) + u16(0) + u32(0) * 5
  header + dir + body
end

data = woff(build_tables)
File.binwrite(OUT, data)
puts "#{OUT}: #{GLYPHS.size - 1} glyphs, #{data.bytesize} bytes"
