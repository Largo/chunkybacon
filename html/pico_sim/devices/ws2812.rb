# WS2812 ("NeoPixel") LEDs in a chain on one pin (docs/HANDOVER.md §6r):
# the four under Waveshare's PicoGo (GP22, part "picogo") and the 16 x 10
# of Waveshare's Pico-RGB-LED (GP6 in Waveshare's demo, part "rgbled").
#
# A WS2812 reads a pulse per bit: high about 0.4 us is a 0, about 0.8 us a
# 1 (the datasheet's T0H / T1H). Each chip keeps the first 24 bits that
# reach it - green, red, blue, the highest bit first - and passes the rest
# on; a line low for more than 50 us makes them all show what they kept.
# Here the bits come from a PIO state machine (devices/pio.rb) whose
# program's timing was measured: a high time from 150 ns up to 550 ns is
# a 0, from 550 ns up to 5 us a 1 (sim choice: the middle of the
# datasheet's windows). Pulses shorter than 150 ns - a state machine left
# at the default 125 MHz - are too short for the chip, which sees nothing.
#
# The colours are what the chip got (0..255 each); the bench brightens
# them for the screen, as a camera would see a lit LED. They outlast a reset
# of the Pico, as the chips do while they have power (World#epd_store): a
# program that should leave them dark ends with clear.

module PicoSim
  class Ws2812Chain
    SPLIT_NS = 550.0
    SHORT_NS = 150.0
    LONG_NS = 5000.0
    HEX = Array.new(256) { |i| format("%02x", i) }

    attr_reader :pin, :count, :frames, :note

    def initialize(pin, count, store)
      @pin = pin
      @count = count
      key = "ws2812:#{pin}"
      store[key] = Array.new(count, 0) unless store[key] && store[key].size == count
      @colors = store[key]
      @bits = []
      @frames = 0
      @until = nil
      @note = nil
      @timing = nil
    end

    def on_pio(world, sm, words, t)
      latch(world) if @until && t > @until + 0.05
      ns = sm.timing_ns(world.board)
      if ns.nil?
        say(world, "unknown", "ws2812 unknown GP#{@pin}")
        return
      end
      @timing = [ns[0].round, ns[2].round]
      one = decode(ns[0])
      zero = decode(ns[2])
      if one.nil? && zero.nil?
        say(world, "too_fast", "ws2812 too_fast GP#{@pin} #{ns[0].round} #{ns[2].round}")
        return
      end
      if one == zero
        say(world, "one_level", "ws2812 one_level GP#{@pin} #{ns[0].round} #{ns[2].round}")
      else
        @note = nil
      end
      sm.bits(words).each do |b|
        v = b == 1 ? one : zero
        @bits << v unless v.nil?
      end
      start = @until && @until > t ? @until : t
      @until = start + sm.words_ms(words.size, world.board)
    end

    # a pulse's high time as the chip reads it: 0, 1, or nil (not seen)
    def decode(high_ns)
      return nil if high_ns < SHORT_NS
      return 1 if high_ns > LONG_NS
      high_ns >= SPLIT_NS ? 1 : 0
    end

    # the bench's log: "ws2812 <note> GP<pin> [<T1H ns> <T0H ns>]" (the page
    # words it, pico_board.js onLog)
    def say(world, note, text)
      world.event("log", text) unless @note == note
      @note = note
    end

    def advance(world, t)
      latch(world) if @until && t > @until + 0.05
    end

    def flush(world, t)
      latch(world) if @until
    end

    # the line went low: each chip takes its 24 bits, green red blue
    def latch(world)
      @until = nil
      bits = @bits
      @bits = []
      return if bits.size < 24
      i = 0
      while i < @count && (i + 1) * 24 <= bits.size
        v = 0
        j = 0
        while j < 24
          v = (v << 1) | bits[i * 24 + j]
          j += 1
        end
        g = (v >> 16) & 0xFF
        r = (v >> 8) & 0xFF
        b = v & 0xFF
        @colors[i] = (r << 16) | (g << 8) | b
        i += 1
      end
      @frames += 1
    end

    # "rrggbb" per LED, one after the other
    def hex
      out = []
      @colors.each { |c| out << HEX[(c >> 16) & 0xFF] << HEX[(c >> 8) & 0xFF] << HEX[c & 0xFF] }
      out.join
    end

    def state
      { "leds" => hex, "note" => @note }
    end

    def summary
      { "pin" => @pin, "count" => @count, "leds" => hex, "frames" => @frames, "note" => @note, "timing" => @timing }
    end
  end

  # Waveshare Pico-RGB-LED: 160 WS2812-type LEDs, 16 across and 10 down,
  # its data line on GP6 (Waveshare's demo; GP7 and GP22 are solder
  # options). LED 0 is at the top left and they go row by row, left to
  # right - Waveshare's demo pattern reads upright that way.
  class RgbLed < Part
    PIN = 6

    def pins = [PIN]

    def attach(world)
      @chain = Ws2812Chain.new(PIN, 160, world.epd_store)
      world.pio_watch(PIN, self)
    end

    def on_pio(world, sm, words, t) = @chain.on_pio(world, sm, words, t)
    def advance(world, t) = @chain.advance(world, t)
    def flush(world, t) = @chain.flush(world, t)
    def state(world) = @chain.state

    def summary(world, out)
      (out["ws2812"] ||= {})[PIN.to_s] = @chain.summary
    end
  end
  PARTS["rgbled"] = RgbLed
end
