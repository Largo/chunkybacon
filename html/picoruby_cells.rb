# The kernel's side of a lesson with "engine": "picoruby" (the PicoRuby
# lesson, docs/HANDOVER.md §6m). Its cells and IRBs run on PicoRuby.wasm in
# a Web Worker (picoruby_lab.js, picoruby_worker.js, picoruby_lab.rb); what
# comes back is text - what the run printed, the inspect of its value, an
# error's class, line and message. This turns that text into what main.rb
# shows and checks: a value that compares like the object it describes, an
# exception of CRuby's class of the same name (so the friendly explanations
# and the line marks work as for CRuby), and CRuby's message for code that
# does not parse - PicoRuby parses with Prism too, but its compiler says no
# more than "no".
#
# Also loaded by test/check_harness.rb, which runs the exercise under CRuby
# and hands the check a Value, as the page does.
require "json"

module PicoRubyCells
  # PicoRuby's value as CRuby sees it: its inspect text. Compares with an
  # object by that object's inspect, so a check can say
  # `result == {"chunky" => 2}` - CRuby 3.4+ and PicoRuby inspect a Hash,
  # an Array, a String and a number the same way.
  class Value
    def initialize(text)
      @text = text
    end

    def inspect = @text
    def to_s = @text
    def ==(other) = other.inspect == @text
    alias eql? ==
    def hash = @text.hash
  end

  # an error PicoRuby raised whose class CRuby does not have
  class Error < StandardError
    attr_reader :pico_class

    def initialize(pico_class, message)
      @pico_class = pico_class
      super(message)
    end
  end

  # the time limit ended the run (▶; a live run says AutoRun::Stopped)
  class Stopped < StandardError; end

  # PicoRuby could not be loaded
  class Unavailable < StandardError; end

  # The simulated board after a run (docs/HANDOVER.md §6r): an exercise's
  # check gets it as `board`, from the world's summary JSON that the worker
  # hands over with its answer (html/pico_sim/world.rb) - or that
  # test/pico_harness.rb builds the same way under CRuby. Every method is
  # total: nil, 0 or [] when there is nothing to say, never an exception.
  # Times are ms since the run started.
  class Board
    attr_reader :data

    def initialize(data)
      @data = data.is_a?(Hash) ? data : {}
    end

    def t = @data["t"].to_i
    def name = @data["board"]

    # [[t, level], ...] of an output pin
    def writes(pin)
      list = (@data["writes"] || {})[pin.to_s]
      list.is_a?(Array) ? list : []
    end

    # the level the pin was last written, nil if it never was
    def level(pin)
      last = writes(pin).last
      last && last[1]
    end

    # the level at time +t+ (0 before the first write)
    def level_at(pin, time)
      level = nil
      writes(pin).each do |at, value|
        break if at > time

        level = value
      end
      level || 0
    end

    # [[t, level], ...] with repeated levels folded: the moments it changed
    def changes(pin)
      out = []
      writes(pin).each { |at, value| out << [at, value] unless out.last && out.last[1] == value }
      out
    end

    # the lengths (ms) of the finished periods at +level+ - from a change to
    # it until the next change; one still going at the end does not count
    def pulses(pin, level = 1)
      list = changes(pin)
      out = []
      list.each_with_index do |(at, value), i|
        nxt = list[i + 1]
        out << nxt[0] - at if value == level && nxt
      end
      out
    end

    # the low periods between two highs
    def gaps(pin)
      list = changes(pin)
      out = []
      list.each_with_index do |(at, value), i|
        nxt = list[i + 1]
        out << nxt[0] - at if value == 0 && nxt && i.positive? && list[i - 1][1] == 1
      end
      out
    end

    # "out", "in_pull_up", "pwm", ... ; nil for a pin never set up
    def mode(pin) = (@data["modes"] || {})[pin.to_s]

    # [[t, frequency, duty], ...]
    def pwm(pin)
      list = (@data["pwm"] || {})[pin.to_s]
      list.is_a?(Array) ? list : []
    end

    # [[t, frequency], ...] of the buzzer (0 = silent)
    def buzz = @data["buzz"].is_a?(Array) ? @data["buzz"] : []

    def onboard = @data["onboard"].to_i

    # I2C transfers per address: {"0x76" => 12}
    def i2c = @data["i2c"].is_a?(Hash) ? @data["i2c"] : {}

    def epd = Epd.new(@data["epd"])
    def lcd = Lcd.new(@data["lcd"])

    # the WS2812 chain on +pin+ (22: the PicoGo's four, 6: the Pico-RGB-LED);
    # without a pin the first there is
    def leds(pin = nil)
      all = @data["ws2812"].is_a?(Hash) ? @data["ws2812"] : {}
      Leds.new(pin ? all[pin.to_s] : all.values.first)
    end
    def robot = Robot.new(@data["robot"])
    def ble = Ble.new(@data["ble"])

    # [{"m", "url", "status", "canned", "body"}, ...]
    def http = @data["http"].is_a?(Array) ? @data["http"] : []

    # the last answer from a host whose name contains +host_part+, parsed
    # as JSON; nil when there is none or it is not JSON
    def http_json(host_part)
      entry = http.reverse.find { |e| e["url"].to_s.split("/")[2].to_s.include?(host_part.to_s) }
      entry && JSON.parse(entry["body"].to_s)
    rescue StandardError
      nil
    end

    def wifi_connected? = (@data["wifi"] || {})["connected"] == true

    def events = @data["events"].is_a?(Array) ? @data["events"] : []

    # Text in the 5 x 7 font on a picture: the including class answers
    # blank?, black?(x, y) (ink there?) and black_pixels ([[x, y], ...]).
    module InkText
      # +str+ drawn in the 5 x 7 font (html/pico/lib/font5x7.rb) at one of
      # +scales+ (text_scales), ink on its background, anywhere on the picture
      def text?(str, scales = text_scales)
        str = str.to_s
        return false if str.empty? || blank?

        font = PicoRubyCells.font
        scales.any? { |scale| find_text(str, scale, font) }
      rescue StandardError
        false
      end

      def text_scales = (1..3)

      def find_text(str, scale, font)
        glyphs = str.chars.map { |c| font[0][(c.ord.between?(32, 126) ? c.ord : 63) - 32] }
        advance = font[1]
        # where the first glyph's first black pixel could be
        first = nil
        glyphs.each_with_index do |rows, i|
          rows.each_with_index do |bits, r|
            col = (0..4).find { |cc| bits & (0x10 >> cc) != 0 }
            if col
              first = [i * advance + col, r]
              break
            end
          end
          break if first
        end
        return false unless first

        black_pixels.any? do |bx, by|
          ox = bx - first[0] * scale
          oy = by - first[1] * scale
          glyphs_at?(glyphs, ox, oy, scale, advance)
        end
      end

      def glyphs_at?(glyphs, ox, oy, scale, advance)
        glyphs.each_with_index do |rows, i|
          gx = ox + i * advance * scale
          rows.each_with_index do |bits, r|
            5.times do |c|
              ink = bits & (0x10 >> c) != 0
              # a glyph's last column may be its built-in gap: white is
              # required only where the font has ink in that column somewhere
              next if !ink && c == 4 && rows.none? { |b| b & 1 != 0 }

              px = gx + c * scale
              py = oy + r * scale
              return false if black?(px, py) != ink
            end
          end
        end
        true
      end
    end

    class Epd
      def initialize(data)
        @data = data.is_a?(Hash) ? data : {}
      end

      def list = @data["refreshes"].is_a?(Array) ? @data["refreshes"] : []
      def refreshes = list.size
      def modes = list.map { |entry| entry[1] }
      def sleeping? = @data["sleeping"] == true
      def frame = Frame.new(@data["frame"].to_s)
    end

    # The e-paper's picture: 250 x 122, x left to right, y top to bottom.
    # The hex is the panel's RAM (html/pico_sim/devices/epd213.rb): 250 rows
    # of 16 bytes, row x, pixel 121 - y of that row, the leftmost pixel in a
    # byte's highest bit, 1 = white.
    class Frame
      WIDTH = 250
      HEIGHT = 122

      def initialize(hex)
        @bytes = hex.size >= 8000 ? [hex].pack("H*").bytes : nil
      end

      def blank? = @bytes.nil?

      def black?(x, y)
        return false if @bytes.nil? || x.negative? || y.negative? || x >= WIDTH || y >= HEIGHT

        s = HEIGHT - 1 - y
        (@bytes[x * 16 + s / 8] & (0x80 >> (s % 8))).zero?
      end

      def black_count
        return 0 if @bytes.nil?

        @black_count ||= black_pixels.size
      end

      # [[x, y], ...]
      def black_pixels
        return [] if @bytes.nil?

        @black_pixels ||= begin
          out = []
          WIDTH.times { |x| HEIGHT.times { |y| out << [x, y] if black?(x, y) } }
          out
        end
      end

      include InkText
    end

    # The Pico-LCD-1.14's glass (html/pico_sim/devices/st7789.rb): 240 x
    # 135, x left to right, y top to bottom; the frame is the controller's
    # RAM there, RGB565, 4 hex digits a pixel.
    class Lcd
      include InkText

      WIDTH = 240
      HEIGHT = 135

      def initialize(data)
        @data = data.is_a?(Hash) ? data : {}
        hex = @data["frame"].to_s
        @px = hex.size >= WIDTH * HEIGHT * 4 ? hex.scan(/\h{4}/).map { |h| h.to_i(16) } : nil
      end

      def there? = !@data.empty?
      def blank? = @px.nil?
      # display on and out of sleep
      def on? = @data["lit"] == true
      def inverted? = @data["inverted"] == true
      def backlight = @data["backlight"].to_f
      # something to see: on, and the backlight not dark
      def visible? = on? && backlight.positive?
      def writes = @data["writes"].to_i
      def pixels_written = @data["pixels"].to_i
      def madctl = @data["madctl"].to_i
      def unknown = @data["unknown"].is_a?(Array) ? @data["unknown"] : []

      # the RGB565 number in the RAM at (x, y); nil outside or without a frame
      def color(x, y)
        return nil if @px.nil? || x.negative? || y.negative? || x >= WIDTH || y >= HEIGHT

        @px[y * WIDTH + x]
      end

      # [r, g, b] (0..255) as the glass shows the pixel: dark when the
      # display is off, inverted without INVON (the IPS glass needs it)
      def rgb(x, y)
        c = color(x, y)
        return [0, 0, 0] if c.nil? || !on?

        c ^= 0xFFFF unless inverted?
        [(c >> 11) * 255 / 31, ((c >> 5) & 63) * 255 / 63, (c & 31) * 255 / 31]
      end

      # how many pixels hold +c+ (an RGB565 number)
      def count(c) = @px ? @px.count(c) : 0

      # the colour most of the glass holds
      def background
        return nil if @px.nil?

        @background ||= @px.tally.max_by { |_c, n| n }[0]
      end

      # big digits are common on a colour screen: up to scale 5
      def text_scales = (1..5)

      # ink for text?: every pixel that is not the background
      def black?(x, y)
        c = color(x, y)
        !c.nil? && c != background
      end

      def black_pixels
        return [] if @px.nil?

        @black_pixels ||= begin
          bg = background
          out = []
          @px.each_with_index { |c, i| out << [i % WIDTH, i / WIDTH] if c != bg }
          out
        end
      end
    end

    # A WS2812 chain (html/pico_sim/devices/ws2812.rb): the colours the
    # chips got, [r, g, b] 0..255 each, LED 0 first.
    class Leds
      def initialize(data)
        @data = data.is_a?(Hash) ? data : {}
      end

      def there? = !@data.empty?
      def count = @data["count"].to_i
      def frames = @data["frames"].to_i
      # nil, or why the chips saw nothing ("too_fast", "unknown", "one_level")
      def note = @data["note"]
      # [T1H, T0H] in ns, as the PIO program sent them
      def timing = @data["timing"]

      def colors
        hex = @data["leds"].to_s
        (0...(hex.size / 6)).map { |i| [hex[i * 6, 2].to_i(16), hex[i * 6 + 2, 2].to_i(16), hex[i * 6 + 4, 2].to_i(16)] }
      end

      def rgb(i) = colors[i] || [0, 0, 0]
      def lit?(i) = rgb(i).any?(&:positive?)
      def lit = colors.each_index.select { |i| lit?(i) }
    end

    class Robot
      def initialize(data)
        @data = data.is_a?(Hash) ? data : {}
      end

      def hit? = @data["hit"] == true
      def gap_cm = @data["gap"].to_f
      def traveled_cm = @data["traveled"].to_f
      def moving? = @data["moving"] == true
      def x = @data["x"].to_f
      def y = @data["y"].to_f
      def heading = @data["h"].to_f
      def layout = @data["layout"]
      def there? = !@data.empty?
    end

    class Ble
      def initialize(data)
        @data = data.is_a?(Hash) ? data : {}
      end

      # the lines the laptop sent
      def rx = @data["rx"].is_a?(Array) ? @data["rx"] : []
      # what the Pico sent, as text, and as lines without their newlines
      def tx = @data["tx"].to_s
      def lines = tx.split("\n").map(&:chomp)
      def advertised = @data["adv"]
      def connected? = @data["connected"] == true
    end
  end

  module_function

  # the board for a check: nil for "" (a run without a board)
  def board(json)
    text = json.to_s
    return nil if text.empty?

    Board.new(JSON.parse(text))
  rescue StandardError
    nil
  end

  # [FONT5X7, FONT5X7_ADVANCE] from html/pico/lib/font5x7.rb: the page reads
  # it with fetchTextSync, the harness from the file (font_source=)
  def font
    @font ||= begin
      source = @font_source ? @font_source.call : $window.fetchTextSync("pico/lib/font5x7.rb").to_s
      mod = Module.new
      mod.module_eval(source, "font5x7.rb")
      [mod.const_get(:FONT5X7), mod.const_get(:FONT5X7_ADVANCE)]
    end
  end

  def font_source=(loader)
    @font_source = loader
    @font = nil
  end

  # nil, true and false as themselves (main.rb leaves out "=> nil" after
  # output, as for CRuby), everything else as a Value
  def value(text)
    case text
    when "nil" then nil
    when "true" then true
    when "false" then false
    else Value.new(text)
    end
  end

  # what PicoRuby raised, as CRuby's exception of that name where there is
  # one (NoMethodError, ZeroDivisionError, ...), at the cell's line
  def error(name, message, line, file)
    klass = Object.const_get(name) if name.match?(/\A[A-Z]\w*\z/) && Object.const_defined?(name)
    error = if klass.is_a?(Class) && klass <= StandardError
      klass.new(message)
    else
      Error.new(name, message)
    end
    error.set_backtrace(line.positive? ? ["#{file}:#{line}:in '<main>'"] : [])
    error
  end

  # "NoMethodError" for the cell's error line
  def class_name(error) = error.is_a?(Error) ? error.pico_class : error.class.name

  # CRuby's SyntaxError for code that does not parse (Prism's messages,
  # what eval would say), nil for code that does
  def syntax_error(code, file)
    RubyVM::InstructionSequence.compile(code, file)
    nil
  rescue SyntaxError => e
    e
  end
end
