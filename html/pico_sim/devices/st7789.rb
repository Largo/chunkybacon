# Waveshare Pico-LCD-1.14 (V2): a 240 x 135 IPS glass, 65 536 colours, an
# ST7789VW on SPI1 - DC GP8, CS GP9, CLK GP10, DIN GP11, RST GP12, the
# backlight on GP13 (a GPIO or a PWM: its duty is the brightness) - and
# beside it the keys A GP15 and B GP17 and a joystick: up GP2, centre GP3,
# left GP16, down GP18, right GP20. A key connects its pin to GND (0 =
# pressed): it needs GPIO::PULL_UP. Pins from Waveshare's demo
# Pico-LCD-1.14.py (tmp research "waveshare_peripherals" §3.1). It takes
# the same SPI pins as the e-paper: one display at a time.
#
# The controller, as the datasheet has it: commands with DC low, their data
# with DC high, while CS is low. CASET (0x2A) and RASET (0x2B) set a window,
# RAMWR (0x2C) streams pixels into it - RGB565, the high byte first - left
# to right, then down, wrapping at the window's end. MADCTL (0x36) turns the
# picture: MV exchanges rows and columns, then MX mirrors the 240 columns
# and MY the 320 rows; BGR swaps red and blue. The controller's RAM is 240
# x 320; the glass shows columns 52..186 and rows 40..279 of it. In
# Waveshare's landscape mode (MADCTL 0x70: MX, MV and ML) those are x
# 40..279 and y 53..187 - the offsets every driver for this board adds (in
# portrait, 0x00, they are 52 and 40: Waveshare's C demo). Sim choice: the
# glass is drawn so that 0x70 reads upright; which way the real glass sits
# is not verified. Sleep (0x10/0x11) and display
# off/on (0x28/0x29) black the glass; SWRESET (0x01) and RST low bring the
# controller back to sleep with the display off. The IPS glass shows the
# colours inverted unless the controller inverts them (INVON 0x21), as
# Waveshare's and Adafruit's init code do. The RAM keeps its picture across
# a reset of the Pico (the LCD keeps its power); after power-up it holds
# noise.
#
# What the page gets: "lcd" posts of the rectangles that changed, at most
# every 33 ms - "x,y,w,h|<4 hex digits per pixel>", in glass coordinates
# (0..239 left to right, 0..134 top to bottom) - and in the state whether
# the glass is lit, inverted, and the backlight's duty.

module PicoSim
  class Lcd114 < Part
    DC = 8
    CS = 9
    RST = 12
    BL = 13
    KEYS = { 15 => "A", 17 => "B", 2 => "up", 3 => "ctrl", 16 => "left", 18 => "down", 20 => "right" }
    W = 240
    H = 135
    KNOWN = [0x00, 0x13, 0x12, 0x26, 0x38, 0x39, 0xB0, 0xB2, 0xB7, 0xBB, 0xC0, 0xC2, 0xC3, 0xC4, 0xC6,
             0xD0, 0xD6, 0xE0, 0xE1, 0xE4, 0xE7, 0xE9]
    HEX = Array.new(256) { |i| format("%02x", i) }
    POST_MS = 33

    def pins = [2, 3, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 20]

    def takes_string? = true

    def attach(world)
      world.spi_device(2, CS, self)
      world.watch(RST, self)
      KEYS.each_key { |pin| world.drive(pin, self) }
      store = world.epd_store
      store["lcd"] ||= noise
      @ram = store["lcd"]
      @unknown = []
      @pixels = 0
      @frames = 0
      @last_post = nil
      @dirty = [0, 0, W - 1, H - 1]    # the page's copy may be older: all of it
      reset_controller
    end

    # power-up RAM: noise, the same each time (a seeded generator)
    def noise
      rng = Rng.new(7)
      Array.new(W * H) { rng.int(65536) }
    end

    def reset_controller
      @sleeping = true
      @on = false
      @inverted = false
      @madctl = 0
      @colmod = 0x66
      @xs = 0
      @xe = 239
      @ys = 0
      @ye = 319
      @x = 0
      @y = 0
      @cmd = nil
      @data = []
      @part = []
    end

    def pressed?(world, pin) = world.input("pin#{pin}").to_s == "1"

    def drive(world, pin, t)
      KEYS[pin] && pressed?(world, pin) ? 0 : nil
    end

    def on_write(world, pin, level, t)
      reset_controller if pin == RST && level == 0
    end

    def spi_write(world, bytes)
      dc = world.out_level(DC)
      if dc == 0
        if bytes.is_a?(String)
          bytes.each_byte { |b| command(world, b) }
        else
          bytes.each { |b| command(world, b) }
        end
      elsif @cmd == 0x2C || @cmd == 0x3C
        ram_write(bytes)
      elsif bytes.is_a?(String)
        bytes.each_byte { |b| data(b) }
      else
        bytes.each { |b| data(b) }
      end
    end

    def command(world, byte)
      @cmd = byte
      @data = []
      case byte
      when 0x01 then reset_controller
      when 0x10 then @sleeping = true
      when 0x11 then @sleeping = false
      when 0x20 then @inverted = false
      when 0x21 then @inverted = true
      when 0x28 then @on = false
      when 0x29 then @on = true
      when 0x2C
        @x = @xs
        @y = @ys
        @part = []
        @frames += 1
      when 0x3C then @part = []
      when 0x2A, 0x2B, 0x36, 0x3A then nil
      else
        @unknown << byte unless KNOWN.include?(byte) || @unknown.include?(byte) || @unknown.size >= 20
      end
    end

    def data(byte)
      @data << byte
      d = @data
      case @cmd
      when 0x2A
        if d.size == 4
          @xs = (d[0] << 8) | d[1]
          @xe = (d[2] << 8) | d[3]
        end
      when 0x2B
        if d.size == 4
          @ys = (d[0] << 8) | d[1]
          @ye = (d[2] << 8) | d[3]
        end
      when 0x36 then @madctl = byte
      when 0x3A then @colmod = byte
      end
    end

    # RAMWR's data: 2 bytes a pixel (COLMOD x5, RGB565, high byte first),
    # or 3 (x6, RGB666: the top 6 bits of each byte); a pixel split over two
    # writes is put together
    def ram_write(bytes)
      per = (@colmod & 0x07) == 6 ? 3 : 2
      mv = (@madctl & 0x20) != 0
      mx = (@madctl & 0x40) != 0
      my = (@madctl & 0x80) != 0
      bgr = (@madctl & 0x08) != 0
      str = bytes.is_a?(String)
      n = str ? bytes.bytesize : bytes.size
      part = @part
      ram = @ram
      dirty = @dirty
      i = 0
      while i < n
        part << (str ? bytes.getbyte(i) : bytes[i])
        i += 1
        next if part.size < per
        c = per == 2 ? (part[0] << 8) | part[1] : ((part[0] >> 3) << 11) | ((part[1] >> 2) << 5) | (part[2] >> 3)
        part.clear
        c = ((c & 0x1F) << 11) | (c & 0x07E0) | (c >> 11) if bgr
        # the address counter through MADCTL into the RAM (rows and
        # columns exchanged first, then mirrored), then onto the glass
        col = mv ? @y : @x
        row = mv ? @x : @y
        col = 239 - col if mx
        row = 319 - row if my
        dx = row - 40
        dy = 186 - col
        if dx >= 0 && dx < W && dy >= 0 && dy < H
          ram[dy * W + dx] = c
          if dirty
            dirty[0] = dx if dx < dirty[0]
            dirty[1] = dy if dy < dirty[1]
            dirty[2] = dx if dx > dirty[2]
            dirty[3] = dy if dy > dirty[3]
          else
            dirty = @dirty = [dx, dy, dx, dy]
          end
        end
        @pixels += 1
        @x += 1
        if @x > @xe
          @x = @xs
          @y += 1
          @y = @ys if @y > @ye
        end
      end
    end

    def advance(world, t)
      return unless @dirty
      return if @last_post && t - @last_post < POST_MS
      post(world, t)
    end

    def flush(world, t)
      post(world, t) if @dirty
    end

    def post(world, t)
      x0, y0, x1, y1 = @dirty
      @dirty = nil
      @last_post = t
      PicoSim.host.post("lcd", "#{x0},#{y0},#{x1 - x0 + 1},#{y1 - y0 + 1}|#{hex(x0, y0, x1, y1)}")
    end

    def hex(x0 = 0, y0 = 0, x1 = W - 1, y1 = H - 1)
      out = []
      y = y0
      while y <= y1
        i = y * W + x0
        last = y * W + x1
        while i <= last
          c = @ram[i]
          out << HEX[c >> 8] << HEX[c & 0xFF]
          i += 1
        end
        y += 1
      end
      out.join
    end

    def lit?(world) = @on && !@sleeping

    def state(world)
      keys = []
      KEYS.each { |pin, name| keys << name if pressed?(world, pin) }
      { "lit" => lit?(world), "inv" => @inverted, "bl" => world.pwm_duty(BL).round, "keys" => keys,
        "scripted" => KEYS.keys.select { |pin| world.scripted?("pin#{pin}") } }
    end

    def summary(world, out)
      out["lcd"] = { "frame" => world.raw_mark("lcd", hex), "lit" => lit?(world), "on" => @on, "sleeping" => @sleeping,
                     "inverted" => @inverted, "backlight" => world.pwm_duty(BL).round(1), "madctl" => @madctl,
                     "colmod" => @colmod, "pixels" => @pixels, "writes" => @frames, "unknown" => @unknown }
    end
  end
  PARTS["lcd114"] = Lcd114
end
