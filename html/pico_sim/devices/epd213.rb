# Waveshare Pico-ePaper-2.13 (V4): 250 x 122, black and white, an
# SSD16xx-compatible controller (the part number is unverified) on SPI1 -
# DC GP8, CS GP9, CLK GP10, DIN GP11, RST GP12, BUSY GP13 (docs/HANDOVER.md
# §6r; the command set and timings: tmp research "waveshare_peripherals"
# §2.2, Waveshare's EPD_2in13_V4.c).
#
# A state machine on the bytes that arrive while CS is low: DC low = a
# command, DC high = its data. The RAM is the panel's portrait layout:
# 250 gate rows of 16 bytes (128 source pixels, 122 of them visible), MSB =
# the lowest source pixel, 1 = white. 0x20 starts a refresh that keeps BUSY
# high for as long as the 0x22 mode says (full 2 s, fast 1.5 s, partial
# 0.3 s); when it ends, the panel shows the black/white RAM (0x24), and the
# page gets it ("epd_frame": "<mode>|<8000 hex digits of the RAM>").
# Writes are ignored while the panel sleeps (0x10), until RST goes low.
#
# The picture survives a reset of the board: e-paper keeps it without power
# (World#epd_store).

module PicoSim
  class Epd213 < Part
    DC = 8
    CS = 9
    RST = 12
    BUSY = 13
    ROWS = 250
    ROW_BYTES = 16
    RAM_SIZE = ROWS * ROW_BYTES
    MODES = { 0xF7 => "full", 0xC7 => "fast", 0xFF => "partial", 0xCF => "full", 0x0F => "partial" }
    BUSY_MS = { "full" => 2000, "fast" => 1500, "partial" => 300 }
    HEX = Array.new(256) { |i| format("%02x", i) }

    def pins = [8, 9, 10, 11, 12, 13]

    def attach(world)
      world.drive(BUSY, self)
      world.watch(RST, self)
      world.spi_device(2, CS, self)
      store = world.epd_store
      store["panel"] ||= white
      @refreshes = []
      @unknown = []
      @busy_until = 0.0
      @pending = nil
      @sleeping = false
      @cmd = nil
      @data = []
      reset_regs
      @ram24 = white
      @ram26 = white
      @mode22 = 0xF7
    end

    def white
      s = "\xFF" * RAM_SIZE
      s = s.b if PicoSim::CRUBY
      s
    end

    def reset_regs
      @entry = 0x03
      @x_lo = 0
      @x_hi = ROW_BYTES - 1
      @y_lo = 0
      @y_hi = ROWS - 1
      @x = 0
      @y = 0
    end

    def busy?(t) = t < @busy_until

    def drive(world, pin, t)
      busy?(t) ? 1 : 0
    end

    # RST low: a hardware reset, which also wakes the panel from deep sleep
    def on_write(world, pin, level, t)
      return unless pin == RST && level == 0
      @sleeping = false
      @cmd = nil
      @data = []
      reset_regs
    end

    def spi_write(world, bytes)
      return if @sleeping
      dc = world.out_level(DC)
      if dc == 0
        bytes.each { |b| command(world, b) }
      elsif @cmd == 0x24 || @cmd == 0x26
        ram_write(bytes)
      else
        bytes.each { |b| data(world, b) }
      end
    end

    def command(world, byte)
      finish_command(world)
      @cmd = byte
      @data = []
      case byte
      when 0x12 then reset_regs                  # SWRESET
      when 0x20 then start_refresh(world)        # master activation
      when 0x24, 0x26, 0x01, 0x11, 0x44, 0x45, 0x4E, 0x4F, 0x3C, 0x21, 0x18, 0x22, 0x10, 0x1A, 0x32, 0x37
        nil
      else
        @unknown << byte if @unknown.size < 50
      end
    end

    def data(world, byte)
      return if @sleeping
      @data << byte
      d = @data
      case @cmd
      when 0x11 then @entry = byte & 0x07
      when 0x44
        if d.size == 2
          @x_lo = d[0] < d[1] ? d[0] : d[1]
          @x_hi = d[0] < d[1] ? d[1] : d[0]
        end
      when 0x45
        if d.size == 4
          a = d[0] + (d[1] << 8)
          b = d[2] + (d[3] << 8)
          @y_lo = a < b ? a : b
          @y_hi = a < b ? b : a
        end
      when 0x4E then @x = byte
      when 0x4F
        @y = d[0] + ((d[1] || 0) << 8) if d.size <= 2
      when 0x22 then @mode22 = byte
      when 0x10 then @sleeping = true if byte & 0x03 != 0
      end
    end

    def finish_command(world)
      nil
    end

    # 0x24/0x26 data: at the address counter, which moves as the data entry
    # mode (0x11) says - bit 0 X up, bit 1 Y up, bit 2 Y first
    def ram_write(bytes)
      ram = @cmd == 0x24 ? @ram24 : @ram26
      full = @x_lo == 0 && @x_hi == ROW_BYTES - 1 && @y_lo == 0 && @y_hi == ROWS - 1
      if @entry == 0x03 && full && @x == 0
        # the common case (Waveshare's Display): row after row, at once
        pos = @y * ROW_BYTES
        n = bytes.size
        n = RAM_SIZE - pos if pos + n > RAM_SIZE
        chunk = PicoSim.byte_string(n == bytes.size ? bytes : bytes[0, n])
        ram = ram.byteslice(0, pos) + chunk + (ram.byteslice(pos + n, RAM_SIZE - pos - n) || "")
        @y = (pos + n) / ROW_BYTES
        @y = 0 if @y >= ROWS
        rest = bytes.size - n
        @cmd == 0x24 ? @ram24 = ram : @ram26 = ram
        ram_write(bytes[n, rest]) if rest > 0
        return
      end
      bytes.each do |b|
        ram.setbyte(@y * ROW_BYTES + @x, b) if @x <= 15 && @y < ROWS
        step_counter
      end
    end

    def step_counter
      dx = (@entry & 1) == 1 ? 1 : -1
      dy = (@entry & 2) == 2 ? 1 : -1
      if (@entry & 4) == 0
        @x += dx
        return if @x >= @x_lo && @x <= @x_hi
        @x = dx > 0 ? @x_lo : @x_hi
        @y += dy
        @y = dy > 0 ? @y_lo : @y_hi if @y < @y_lo || @y > @y_hi
      else
        @y += dy
        return if @y >= @y_lo && @y <= @y_hi
        @y = dy > 0 ? @y_lo : @y_hi
        @x += dx
        @x = dx > 0 ? @x_lo : @x_hi if @x < @x_lo || @x > @x_hi
      end
    end

    def start_refresh(world)
      t = world.now
      mode = MODES[@mode22] || "full"
      # the fast init loads a temperature (0x22 B1/91 + 0x20): a short busy
      if @mode22 == 0xB1 || @mode22 == 0x91
        @busy_until = t + 10
        return
      end
      @busy_until = t + BUSY_MS[mode]
      @pending = mode
    end

    def advance(world, t)
      return unless @pending && !busy?(t)
      mode = @pending
      @pending = nil
      world.epd_store["panel"] = @ram24.dup
      @refreshes << [world.run_t(@busy_until).round, mode]
      world.event("epd_frame", "#{mode}|#{hex(@ram24)}")
    end

    def hex(ram)
      out = []
      ram.each_byte { |b| out << HEX[b] }
      out.join
    end

    def state(world)
      # "mode": the refresh under way, so the bench can flash a full one
      { "busy" => busy?(world.now), "sleeping" => @sleeping, "mode" => @pending }
    end

    def summary(world, out)
      out["epd"] = { "refreshes" => @refreshes, "frame" => world.raw_mark("epd", hex(world.epd_store["panel"])),
                     "sleeping" => @sleeping, "unknown" => @unknown }
    end
  end
  PARTS["epd213"] = Epd213
end
