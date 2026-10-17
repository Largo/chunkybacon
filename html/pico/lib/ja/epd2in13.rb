# Waveshare Pico-ePaper-2.13 (V4) 用のドライバ。250 x 122 ピクセル、
# 白黒、SPI でつながる SSD16xx 系のコントローラ。ふつうの PicoRuby なので、
# シミュレータでも、R2P2 の Pico の /lib に置けば実機でも動きます。
# コマンドの順番は Waveshare のデモコード EPD_2in13_V4 にならっています。
#
#   epd = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8, rst_pin: 12, busy_pin: 13)
#   epd.clear
#   epd.text(10, 10, "Hello", scale: 2)
#   epd.refresh
#
# 絵はまずバッファに描きます(x 0..249 は左から右、y 0..121 は上から下)。
# refresh でディスプレイに送られます。
require "gpio"
require "font5x7"

class EPD2in13
  WIDTH = 250
  HEIGHT = 122
  BLACK = 0
  WHITE = 1
  ROW_BYTES = 16          # パネルは 1 行の 122 ピクセルを 16 バイトに入れる
  SIZE = WIDTH * ROW_BYTES  # 4000 バイト、1 ピクセル 1 ビット、1 = 白

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

  # 画面全体を 1 色で塗る
  def clear(color = WHITE)
    @buffer = (color == WHITE ? "\xFF" : "\x00") * SIZE
  end

  # パネルの中身は縦向き: 行 x の、ピクセル 121 - y。1 バイトに
  # 8 ピクセル、いちばん左が最上位ビット。
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

  # 5 x 7 フォント(font5x7.rb)の文字。1 ピクセルを scale x scale で描く
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

  # バッファをディスプレイへ: 全体リフレッシュ(2 秒、点滅する)か
  # 部分リフレッシュ(0.3 秒、点滅しない。ときどき全体もすること)
  def refresh(partial: false)
    init if @asleep
    if partial
      @rst.write(0)
      sleep_ms 1
      @rst.write(1)
      command(0x3C, 0x80)        # 枠
      command(0x01, 0xF9, 0x00, 0x00)
      command(0x11, 0x03)
      window
      command(0x24, @buffer)     # 新しい絵
      command(0x22, 0xFF)        # 部分更新
    else
      window
      command(0x24, @buffer)
      window
      command(0x26, @buffer)     # 部分更新が比べる元の絵
      command(0x22, 0xF7)        # 全体更新
    end
    command(0x20)                # 開始
    busy_wait
  end

  # ディープスリープ: 絵は残り、パネルは電気を使わない
  def sleep
    command(0x10, 0x01)
    sleep_ms 100
    @asleep = true
  end

  private

  def init
    reset
    busy_wait
    command(0x12)                # ソフトウェアリセット
    busy_wait
    command(0x01, 0xF9, 0x00, 0x00)  # ゲート線 250 本
    command(0x11, 0x03)          # データ入力: x のあと y、どちらも増える向き
    window
    command(0x3C, 0x05)
    command(0x21, 0x00, 0x80)
    command(0x18, 0x80)          # 内蔵の温度センサ
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

  # RAM 全体、アドレスカウンタは先頭に
  def window
    command(0x44, 0x00, ROW_BYTES - 1)
    command(0x45, 0x00, 0x00, WIDTH - 1, 0x00)
    command(0x4E, 0x00)
    command(0x4F, 0x00, 0x00)
  end

  # コマンドバイト(DC が low)、続いてそのデータ(DC が high)
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

  # パネルが動いている間 BUSY は 1
  def busy_wait
    sleep_ms 10 while @busy.high?
    sleep_ms 10
  end
end
