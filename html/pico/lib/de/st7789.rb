# Ein Treiber für das Waveshare Pico-LCD-1.14: 240 x 135 Pixel in Farbe,
# ein ST7789-Controller an SPI1. Reines PicoRuby: Er läuft im Simulator
# und, nach /lib eines R2P2-Picos gelegt, auf dem Board. Die Befehle
# folgen Waveshares Demo Pico-LCD-1.14.py.
#
#   spi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000, sck_pin: 10, copi_pin: 11)
#   lcd = ST7789.new(spi: spi)
#   lcd.fill(ST7789::BLACK)
#   lcd.text("Hello", 10, 10, ST7789::YELLOW, scale: 2)
#
# Kein Puffer: Jeder Aufruf geht sofort ans Display. Eine Farbe ist eine
# Zahl in RGB565 - 5 Bit Rot, 6 Grün, 5 Blau: ST7789.rgb(255, 128, 0).
# x läuft 0..239 von links nach rechts, y 0..134 von oben nach unten.
require "gpio"
require "pwm"
require "font5x7"

class ST7789
  WIDTH = 240
  HEIGHT = 135
  # das Glas zeigt nur einen Teil des Controller-RAMs: diesen
  X_OFFSET = 40
  Y_OFFSET = 53

  BLACK = 0x0000
  WHITE = 0xFFFF
  RED = 0xF800
  GREEN = 0x07E0
  BLUE = 0x001F
  YELLOW = 0xFFE0
  CYAN = 0x07FF
  MAGENTA = 0xF81F

  # je 8 Bit Rot, Grün und Blau -> eine RGB565-Zahl
  def self.rgb(r, g, b)
    ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
  end

  def initialize(spi:, dc_pin: 8, cs_pin: 9, rst_pin: 12, bl_pin: 13)
    @spi = spi
    @dc = GPIO.new(dc_pin, GPIO::OUT)
    @cs = GPIO.new(cs_pin, GPIO::OUT)
    @rst = GPIO.new(rst_pin, GPIO::OUT)
    @cs.write(1)
    @bl = PWM.new(bl_pin, frequency: 1000, duty: 0)
    init
    backlight(90)
  end

  # die Helligkeit der Hintergrundbeleuchtung in Prozent (0 = dunkel)
  def backlight(percent)
    @bl.duty(percent)
  end

  def fill(color)
    fill_rect(0, 0, WIDTH, HEIGHT, color)
  end

  # ein gefülltes Rechteck; was über den Rand geht, fällt weg
  def fill_rect(x, y, w, h, color)
    x0 = x < 0 ? 0 : x
    y0 = y < 0 ? 0 : y
    x1 = x + w > WIDTH ? WIDTH : x + w
    y1 = y + h > HEIGHT ? HEIGHT : y + h
    return if x1 <= x0 || y1 <= y0
    window(x0, y0, x1 - 1, y1 - 1)
    data(bytes(color) * ((x1 - x0) * (y1 - y0)))
  end

  def pixel(x, y, color)
    fill_rect(x, y, 1, 1, color)
  end

  # ein Rahmen, ein Pixel breit
  def rect(x, y, w, h, color)
    fill_rect(x, y, w, 1, color)
    fill_rect(x, y + h - 1, w, 1, color)
    fill_rect(x, y, 1, h, color)
    fill_rect(x + w - 1, y, 1, h, color)
  end

  # Text in der 5x7-Schrift (font5x7.rb), jedes Pixel scale x scale, auf bg;
  # ein Zeichen, das nicht aufs Display passt, fällt weg
  def text(str, x, y, color, bg: BLACK, scale: 1)
    on = bytes(color)
    off = bytes(bg)
    w = FONT5X7_ADVANCE * scale
    h = 7 * scale
    str.to_s.each_char do |c|
      code = c.ord
      code = 63 if code < 32 || code > 126   # "?"
      if x >= 0 && y >= 0 && x + w <= WIDTH && y + h <= HEIGHT
        block = ""
        FONT5X7[code - 32].each do |row|
          line = ""
          FONT5X7_ADVANCE.times { |col| line << ((row & (0x10 >> col)) != 0 ? on : off) * scale }
          scale.times { block << line }
        end
        window(x, y, x + w - 1, y + h - 1)
        data(block)
      end
      x += w
    end
  end

  private

  # der Reset und die Init-Folge aus Waveshares Demo
  def init
    @rst.write(1)
    sleep_ms 5
    @rst.write(0)
    sleep_ms 5
    @rst.write(1)
    sleep_ms 120
    command(0x36, 0x70)        # MADCTL: quer
    command(0x3A, 0x05)        # 16 Bit pro Pixel: RGB565
    command(0xB2, 0x0C, 0x0C, 0x00, 0x33, 0x33)
    command(0xB7, 0x35)
    command(0xBB, 0x19)
    command(0xC0, 0x2C)
    command(0xC2, 0x01)
    command(0xC3, 0x12)
    command(0xC4, 0x20)
    command(0xC6, 0x0F)
    command(0xD0, 0xA4, 0xA1)
    command(0xE0, 0xD0, 0x04, 0x0D, 0x11, 0x13, 0x2B, 0x3F, 0x54, 0x4C, 0x18, 0x0D, 0x0B, 0x1F, 0x23)
    command(0xE1, 0xD0, 0x04, 0x0C, 0x11, 0x13, 0x2C, 0x3F, 0x44, 0x51, 0x2F, 0x1F, 0x1F, 0x20, 0x23)
    command(0x21)              # Inversion an: dieses Glas braucht sie für echte Farben
    command(0x11)              # aus dem Schlaf
    sleep_ms 120
    command(0x29)              # Display an
  end

  # eine Farbe als die zwei Bytes, die der Controller will, das hohe zuerst
  def bytes(color)
    ((color >> 8) & 0xFF).chr + (color & 0xFF).chr
  end

  # wohin die nächsten Pixel gehen: Spalten x0..x1, Zeilen y0..y1 (CASET,
  # RASET), dann RAMWR - die Pixel folgen als Daten
  def window(x0, y0, x1, y1)
    x0 += X_OFFSET
    x1 += X_OFFSET
    y0 += Y_OFFSET
    y1 += Y_OFFSET
    command(0x2A, x0 >> 8, x0 & 0xFF, x1 >> 8, x1 & 0xFF)
    command(0x2B, y0 >> 8, y0 & 0xFF, y1 >> 8, y1 & 0xFF)
    command(0x2C)
  end

  # ein Befehlsbyte (DC low), dann seine Daten (DC high)
  def command(cmd, *args)
    @dc.write(0)
    @cs.write(0)
    @spi.write(cmd)
    @cs.write(1)
    data(*args) unless args.empty?
  end

  def data(*args)
    @dc.write(1)
    @cs.write(0)
    @spi.write(*args)
    @cs.write(1)
  end
end
