# Waveshare Pico-LCD-1.14 用のドライバ。240 x 135 ピクセルのカラー、
# SPI1 につながる ST7789 コントローラ。ふつうの PicoRuby なので、
# シミュレータでも、R2P2 の Pico の /lib に置けば実機でも動きます。
# コマンドは Waveshare のデモ Pico-LCD-1.14.py にならっています。
#
#   spi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000, sck_pin: 10, copi_pin: 11)
#   lcd = ST7789.new(spi: spi)
#   lcd.fill(ST7789::BLACK)
#   lcd.text("Hello", 10, 10, ST7789::YELLOW, scale: 2)
#
# バッファはありません。呼ぶたびにすぐディスプレイへ送ります。色は
# RGB565 の数(赤 5 ビット、緑 6、青 5): ST7789.rgb(255, 128, 0)。
# x は 0..239 で左から右、y は 0..134 で上から下。
require "gpio"
require "pwm"
require "font5x7"

class ST7789
  WIDTH = 240
  HEIGHT = 135
  # 画面に見えるのはコントローラの RAM の一部だけ: この部分
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

  # 赤・緑・青それぞれ 8 ビット -> RGB565 の数ひとつ
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

  # バックライトの明るさ(パーセント、0 = 消灯)
  def backlight(percent)
    @bl.duty(percent)
  end

  def fill(color)
    fill_rect(0, 0, WIDTH, HEIGHT, color)
  end

  # 塗りつぶした四角形。画面の外にはみ出た部分は切り落とす
  def fill_rect(x, y, w, h, color)
    x0 = x < 0 ? 0 : x
    y0 = y < 0 ? 0 : y
    x1 = x + w > WIDTH ? WIDTH : x + w
    y1 = y + h > HEIGHT ? HEIGHT : y + h
    return if x1 <= x0 || y1 <= y0
    window(x0, y0, x1 - 1, y1 - 1)
    data(bytes(color) * ((x1 - x0) * (y1 - y0)))
    nil
  end

  def pixel(x, y, color)
    fill_rect(x, y, 1, 1, color)
  end

  # 幅 1 ピクセルの枠
  def rect(x, y, w, h, color)
    fill_rect(x, y, w, 1, color)
    fill_rect(x, y + h - 1, w, 1, color)
    fill_rect(x, y, 1, h, color)
    fill_rect(x + w - 1, y, 1, h, color)
  end

  # 5x7 フォント(font5x7.rb)の文字。1 ピクセルを scale x scale で、背景 bg の上に。
  # 画面に収まらない文字は描かない
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
    nil
  end

  private

  # Waveshare のデモと同じリセットと初期化の手順
  def init
    @rst.write(1)
    sleep_ms 5
    @rst.write(0)
    sleep_ms 5
    @rst.write(1)
    sleep_ms 120
    command(0x36, 0x70)        # MADCTL: 横向き
    command(0x3A, 0x05)        # 1 ピクセル 16 ビット: RGB565
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
    command(0x21)              # 反転オン: この液晶は正しい色にこれが必要
    command(0x11)              # スリープ解除
    sleep_ms 120
    command(0x29)              # 表示オン
  end

  # 色をコントローラが受け取る 2 バイトに(上位バイトが先)
  def bytes(color)
    ((color >> 8) & 0xFF).chr + (color & 0xFF).chr
  end

  # 次のピクセルの行き先: 列 x0..x1、行 y0..y1(CASET、RASET)、
  # そのあと RAMWR。ピクセルはデータとして続く
  def window(x0, y0, x1, y1)
    x0 += X_OFFSET
    x1 += X_OFFSET
    y0 += Y_OFFSET
    y1 += Y_OFFSET
    command(0x2A, x0 >> 8, x0 & 0xFF, x1 >> 8, x1 & 0xFF)
    command(0x2B, y0 >> 8, y0 & 0xFF, y1 >> 8, y1 & 0xFF)
    command(0x2C)
  end

  # コマンドバイト(DC が low)、続いてそのデータ(DC が high)
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
