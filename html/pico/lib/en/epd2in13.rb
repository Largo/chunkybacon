# A driver for the Waveshare Pico-ePaper-2.13 (V4): 250 x 122 pixels,
# black and white, an SSD16xx-style controller on SPI. Plain PicoRuby: it
# runs in the simulator and, put into /lib on an R2P2 Pico, on the board.
# The command sequence follows Waveshare's EPD_2in13_V4 demo code.
#
#   epd = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8, rst_pin: 12, busy_pin: 13)
#   epd.clear
#   epd.text(10, 10, "Hello", scale: 2)
#   epd.refresh
#
# The picture is drawn into a buffer first (x 0..249 left to right, y
# 0..121 top to bottom) and goes to the display with refresh.
require "gpio"
require "font5x7"

class EPD2in13
  WIDTH = 250
  HEIGHT = 122
  BLACK = 0
  WHITE = 1
  ROW_BYTES = 16          # the panel stores 122 pixels in 16 bytes per row
  SIZE = WIDTH * ROW_BYTES  # 4000 bytes, one bit per pixel, 1 = white

  def initialize(spi:, cs_pin:, dc_pin:, rst_pin:, busy_pin:)
    @spi = spi
    @cs = GPIO.new(cs_pin, GPIO::OUT)
    @dc = GPIO.new(dc_pin, GPIO::OUT)
    @rst = GPIO.new(rst_pin, GPIO::OUT)
    @busy = GPIO.new(busy_pin, GPIO::IN)
    @cs.write(1)
    @buffer = "\xFF" * SIZE
    @asleep = true
  end

  # the whole picture in one colour
  def clear(color = WHITE)
    @buffer = (color == WHITE ? "\xFF" : "\x00") * SIZE
  end

  # The panel is portrait inside: row x, pixel 121 - y of that row. Each
  # byte holds 8 pixels, the leftmost in the highest bit.
  def pixel(x, y, color = BLACK)
    return if x < 0 || y < 0 || x >= WIDTH || y >= HEIGHT
    s = HEIGHT - 1 - y
    i = x * ROW_BYTES + s / 8
    mask = 0x80 >> (s % 8)
    b = @buffer.getbyte(i)
    @buffer.setbyte(i, color == BLACK ? b & ~mask & 0xFF : b | mask)
  end

  def line(x0, y0, x1, y1, color = BLACK)
    dx = (x1 - x0).abs
    dy = -(y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx + dy
    while true
      pixel(x0, y0, color)
      break if x0 == x1 && y0 == y1
      e2 = 2 * err
      if e2 >= dy
        err += dy
        x0 += sx
      end
      if e2 <= dx
        err += dx
        y0 += sy
      end
    end
  end

  def rect(x, y, w, h, color = BLACK, fill: false)
    if fill
      h.times { |i| line(x, y + i, x + w - 1, y + i, color) }
    else
      line(x, y, x + w - 1, y, color)
      line(x, y + h - 1, x + w - 1, y + h - 1, color)
      line(x, y, x, y + h - 1, color)
      line(x + w - 1, y, x + w - 1, y + h - 1, color)
    end
  end

  # text in the 5 x 7 font (font5x7.rb), each pixel scale x scale
  def text(x, y, str, scale: 1, color: BLACK)
    str.to_s.each_char do |c|
      code = c.ord
      code = 63 if code < 32 || code > 126   # "?"
      FONT5X7[code - 32].each_with_index do |row, r|
        5.times do |col|
          next if row & (0x10 >> col) == 0
          scale.times do |dy|
            scale.times { |dx| pixel(x + col * scale + dx, y + r * scale + dy, color) }
          end
        end
      end
      x += FONT5X7_ADVANCE * scale
    end
  end

  # the buffer to the display: a full refresh (2 s, it flashes), or a
  # partial one (0.3 s, no flash; do a full one now and then)
  def refresh(partial: false)
    init if @asleep
    if partial
      @rst.write(0)
      sleep_ms 1
      @rst.write(1)
      command(0x3C, 0x80)        # border
      command(0x01, 0xF9, 0x00, 0x00)
      command(0x11, 0x03)
      window
      command(0x24, @buffer)     # the new picture
      command(0x22, 0xFF)        # partial update
    else
      window
      command(0x24, @buffer)
      window
      command(0x26, @buffer)     # the base a partial refresh compares with
      command(0x22, 0xF7)        # full update
    end
    command(0x20)                # go
    busy_wait
  end

  # deep sleep: the picture stays, the panel draws no power
  def sleep
    command(0x10, 0x01)
    sleep_ms 100
    @asleep = true
  end

  private

  def init
    reset
    busy_wait
    command(0x12)                # software reset
    busy_wait
    command(0x01, 0xF9, 0x00, 0x00)  # 250 gate lines
    command(0x11, 0x03)          # data entry: x then y, both up
    window
    command(0x3C, 0x05)
    command(0x21, 0x00, 0x80)
    command(0x18, 0x80)          # the built-in temperature sensor
    busy_wait
    @asleep = false
  end

  def reset
    @rst.write(1)
    sleep_ms 20
    @rst.write(0)
    sleep_ms 2
    @rst.write(1)
    sleep_ms 20
  end

  # the whole RAM, the address counter at its start
  def window
    command(0x44, 0x00, ROW_BYTES - 1)
    command(0x45, 0x00, 0x00, WIDTH - 1, 0x00)
    command(0x4E, 0x00)
    command(0x4F, 0x00, 0x00)
  end

  # a command byte (DC low), then its data (DC high)
  def command(cmd, *data)
    @dc.write(0)
    @cs.write(0)
    @spi.write(cmd)
    @cs.write(1)
    return if data.empty?
    @dc.write(1)
    @cs.write(0)
    @spi.write(*data)
    @cs.write(1)
  end

  # BUSY reads 1 while the panel works
  def busy_wait
    sleep_ms 10 while @busy.high?
    sleep_ms 10
  end
end
