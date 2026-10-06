# ruby2d on this page: the gem's own Ruby (assets/ruby2d/ruby2d.rb, ruby2d
# 1.0.0, vendored unchanged by tools/vendor_ruby2d.rb) on top of this file,
# which stands in for what the gem writes in C on SDL3 - Ruby2D::Ext - and
# changes what a page must do differently:
#
#   require "ruby2d"
#   set background: "navy"
#   Square.new(x: 270, y: 190, size: 100, color: "yellow")
#   update { ... }
#   show
#
# - Ext: every draw call of a frame becomes a command (an Array); game.js
#   paints them on a <canvas>. Text is measured by the page's canvas font
#   (Ruby2D.measure__), sprites, images, sound and the pixel canvas say they
#   are not here (Ruby2D::Error).
# - show does not block. On a computer it runs the frames until the window
#   closes; here the page owns the loop (main.rb's mount_game, game.js, the
#   same as show_game): show hands the window to the page as a Page::Runner,
#   which runs one frame per call - the keys and clicks since the last one,
#   update, the scene - and answers with the frame as JSON.
# - require "ruby2d" mixes Ruby2D into the top level as the gem's ruby2d.rb
#   does (include Ruby2D, extend Ruby2D::DSL), but so that it can be taken
#   back (mix__, unmix__): every lesson of the page shares one Ruby, and the
#   next lesson must not find `show`, `set` or `Square` there.
#
# Pure Ruby without JS, like game.rb: the same windows run headless under
# CRuby (Runner#press, #tick, #click) for exercise checks and tests.
require "json"
require "stringio"

module Ruby2D
  # the page's hooks: the lesson's language, text width from the canvas, a
  # window that was shown (main.rb mounts it), how a check replays a cell
  class << self
    attr_accessor :lang__, :measure__, :on_show__, :replay__

    def web? = true
  end
  self.lang__ = "en"

  NOT_HERE = {
    "de" => "%s gibt es auf dieser Seite nicht: Der Ersatz für ruby2d hier zeichnet nur Formen und Text. " \
            "Auf deinem Computer, mit dem echten Gem, geht es.",
    "en" => "%s is not available on this page: the stand-in for ruby2d here draws shapes and text only. " \
            "On your computer, with the real gem, it works.",
    "ja" => "%sはこのページでは使えません。ここのruby2dの代わりは図形と文字だけを描きます。" \
            "自分のコンピューターで本物のgemを使えば動きます。"
  }.freeze

  def self.not_here(what)
    Error.new(format(NOT_HERE.fetch(lang__.to_s, NOT_HERE["en"]), what))
  end

  # what the gem has but this page does not draw: they exist, and say so
  %w[Sprite SpriteSheet Tileset Canvas BitmapText Button].each do |name|
    const_set(name, Class.new do
      define_method(:initialize) { |*_args, **_opts, &_block| raise Ruby2D.not_here(name) }
    end)
  end

  # Ruby2D.warn without the gem's String colours (cli/colorize.rb would add
  # #bold, #error, ... to every String of the page); stderr is the console
  @warned_messages = {}
  def self.warn(message)
    return if @warned_messages.key?(message)

    @warned_messages[message] = true
    $stderr.puts "[WARN] #{message}"
  end

  def self.info(message)
    $stderr.puts "[INFO] #{message}" if DSL.window? && DSL.window.diagnostics
  end

  # ---------- the C extension, in Ruby ----------

  # Each draw call appends one command to the frame being drawn (Page.frame);
  # game.js paints them in order. Colours are r, g, b, a in 0..1, as the gem
  # passes them. Commands:
  #   ["q", 4 points, rgba]        a quad, one colour   ["Q", 4 points, [16]] one colour per corner
  #   ["t", 3 points, rgba]        a triangle           ["T", 3 points, [12]]
  #   ["p", [points], [colours]]   a polygon            ["s", [points], width, closed, [colours]] an outline
  #   ["c", x, y, r, sectors, rgba] a circle            ["C", x, y, r, sectors, width, rgba] its outline
  #   ["e", x, y, rx, ry, angle, sectors, rgba] an ellipse, ["E", ..., width, rgba] its outline
  #   ["l", x1, y1, x2, y2, width, dash, gap, start rgba, end rgba] a line
  #   ["x", text, x, y, size, style, angle, rx, ry, rgba] text, top left at x, y
  module Ext
    class << self
      def now = Page.clock

      # what the window asks of SDL: nothing to do on a page
      %i[window_create window_set_title window_set_icon window_set_resizable window_set_size
         window_set_viewport_mode window_set_fps_cap window_set_render_mode window_show_fps
         window_diagnostics window_show_cursor window_hide_cursor window_set_system_cursor
         window_request_render window_load_gamepad_mappings_file window_add_gamepad_mapping
         window_close].each { |name| define_method(name) { |*_args| nil } }

      def window_cursor_visible(_window) = true
      def window_screenshot(_window, _path) = nil

      def window_get_display_dimensions(window)
        %i[@display_width @display_pixel_width].each { |iv| window.instance_variable_set(iv, window.width) }
        %i[@display_height @display_pixel_height].each { |iv| window.instance_variable_set(iv, window.height) }
      end

      def scancode_name(code) = code.to_s

      def draw_quad_uniform(*args) = Page.draw(["q", *args])
      def draw_triangle_uniform(*args) = Page.draw(["t", *args])

      # per-corner colours: x, y, r, g, b, a for each corner
      def draw_quad(*a)
        Page.draw(["Q", a[0], a[1], a[6], a[7], a[12], a[13], a[18], a[19],
                   a[2, 4] + a[8, 4] + a[14, 4] + a[20, 4]])
      end

      def draw_triangle(*a)
        Page.draw(["T", a[0], a[1], a[6], a[7], a[12], a[13], a[2, 4] + a[8, 4] + a[14, 4]])
      end

      def stroke_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, width, r, g, b, a)
        Page.draw(["s", [x1, y1, x2, y2, x3, y3, x4, y4], width, 1, [r, g, b, a]])
      end

      def stroke_quad(x1, y1, x2, y2, x3, y3, x4, y4, width, *colours)
        Page.draw(["s", [x1, y1, x2, y2, x3, y3, x4, y4], width, 1, colours])
      end

      def stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, width, r, g, b, a)
        Page.draw(["s", [x1, y1, x2, y2, x3, y3], width, 1, [r, g, b, a]])
      end

      def stroke_triangle(x1, y1, x2, y2, x3, y3, width, *colours)
        Page.draw(["s", [x1, y1, x2, y2, x3, y3], width, 1, colours])
      end

      def draw_polygon(coords, colours) = Page.draw(["p", coords, colours])
      def stroke_path(coords, width, colours, closed) = Page.draw(["s", coords, width, closed ? 1 : 0, colours])
      def draw_circle(*args) = Page.draw(["c", *args])
      def stroke_circle(*args) = Page.draw(["C", *args])
      def draw_ellipse(*args) = Page.draw(["e", *args])
      def stroke_ellipse(*args) = Page.draw(["E", *args])

      # a line has a colour per corner of its quad: the start's two, the end's two
      def draw_line(x1, y1, x2, y2, width, *c)
        Page.draw(["l", x1, y1, x2, y2, width, 0, 0, c[0, 4], c[8, 4]])
      end

      def draw_dashed_line(x1, y1, x2, y2, width, dash, gap, *c)
        Page.draw(["l", x1, y1, x2, y2, width, dash, gap, c[0, 4], c[8, 4]])
      end

      # SDL_ttf renders the text to a texture and knows its size; here the
      # page's canvas measures it (Ruby2D.measure__), headless a guess
      def text_create(text)
        content = text.content
        size = text.size
        flags = text.instance_variable_get(:@style_flags).to_i
        width = if content.empty? then 0
                elsif Ruby2D.measure__ then Ruby2D.measure__.call(content, size, flags).to_f.ceil
                else (content.length * size * 0.55).ceil
                end
        text.instance_variable_set(:@width, width)
        text.instance_variable_set(:@height, (size * 1.26).round)   # the gem's font, Outfit: 1.26 em
      end

      def text_draw(text, rx, ry)
        c = text.color
        Page.draw(["x", text.content, text.x, text.y, text.size, text.instance_variable_get(:@style_flags).to_i,
                   text.rotate, rx, ry, c.r, c.g, c.b, c.a])
      end

      def image_create(_image) = raise(Ruby2D.not_here("Image"))
      def audio_load(_path) = raise(Ruby2D.not_here("Audio"))

      # the rest of the extension (gamepads, the pixel canvas, ...) is not here
      def method_missing(name, *_args)
        raise Ruby2D.not_here("Ruby2D::Ext.#{name}")
      end

      def respond_to_missing?(_name, _private = false) = true
    end
  end
end

# The gem's own Ruby. In the browser main.rb fetches and evaluates it before
# this file; elsewhere (tests, the harness) it is next to this file.
unless defined?(Ruby2D::Window)
  ENV["HOME"] ||= "/"   # gamepad_events.rb reads ~ when it loads
  load File.expand_path("assets/ruby2d/ruby2d.rb", __dir__)
end

module Ruby2D
  # the default font is the gem's Outfit; the page draws with its own sans
  # serif, so the file need not exist
  class Font
    def self.default = "ruby2d/fonts/outfit/outfit.ttf"
  end

  module PageText
    private

    def normalize_font_path(font)
      font.to_s == Font.default ? Font.default : super
    end
  end
  Text.prepend(PageText)

  class Window
    # On a computer: the frames run until the window closes, then show
    # returns. Here the page runs them: the window goes to the page, show
    # returns at once, and the cell ends.
    def show
      raise Error, 'Window#show called multiple times; Ruby 2D supports a single window per process' if Window.shown?

      Window.shown = true
      @running = true
      @close = false
      Page.shown(self)
      nil
    end

    # ends the window's frames; the page shows that it closed
    def close
      return if @close

      close_callback
      @close = true
    end

    # no file to save from a page (the gem's web build does the same)
    def screenshot(_path = nil) = nil
  end

  # ---------- the page's side ----------
  module Page
    FPS = 60
    @clock = 0.0
    @frame = nil
    @shown = []

    class << self
      # the page's clock in seconds (Ext.now): the game clock of the window
      # whose frame runs
      attr_accessor :clock
      # windows shown without a page (CRuby), newest last
      attr_reader :shown_runners

      def draw(command)
        @frame << command if @frame
        nil
      end

      # collects the draw calls of the block; returns them
      def record
        old = @frame
        @frame = []
        yield
        @frame
      ensure
        @frame = old
      end

      def shown(window)
        runner = Runner.new(window)
        if @capture then @capture.call(runner)
        elsif Ruby2D.on_show__ then Ruby2D.on_show__.call(runner)
        else (@shown_runners ||= []) << runner
        end
        runner
      end

      # a fresh start, as a new program: each cell run is one (main.rb, the
      # harness); windows of other cells go on below them
      def reset
        DSL.window = nil
        Window.shown = false
        @clock = 0.0
        @shown_runners = []
      end

      # A cell once more, without the page: for an exercise's check, which
      # plays this copy, so the window below the cell still starts from its
      # beginning (as ChunkyGame#fresh). The code runs in a binding of its
      # own, its output goes nowhere; returns the Runner of the window it
      # showed, or nil.
      def replay(code)
        saved = [DSL.window? ? DSL.window : nil, Window.shown?, @clock, @capture, $stdout]
        found = nil
        DSL.window = nil
        Window.shown = false
        @capture = ->(runner) { found = runner }
        $stdout = StringIO.new
        (Ruby2D.replay__ || DEFAULT_REPLAY).call(code)
        found&.tap { |runner| runner.source = code }
      ensure
        DSL.window, shown, @clock, @capture, $stdout = saved
        Window.shown = shown
      end

      # Ruby2D as the gem's ruby2d.rb mixes it in (include Ruby2D, extend
      # Ruby2D::DSL), so that it can be taken back: constants set on Object,
      # the DSL as singleton methods of main.
      def mix(main)
        @mixed ||= { consts: [], methods: [] }
        Ruby2D.constants.each do |name|
          next if name == :Page || Object.const_defined?(name, false)

          Object.const_set(name, Ruby2D.const_get(name))
          @mixed[:consts] << name
        end
        DSL.instance_methods(false).each do |name|
          next if main.singleton_class.method_defined?(name, false)

          main.define_singleton_method(name, DSL.instance_method(name))
          @mixed[:methods] << name
        end
        @main = main
      end

      def unmix
        return unless @mixed

        @mixed[:consts].each do |name|
          Object.send(:remove_const, name) if Object.const_defined?(name, false) && Object.const_get(name).equal?(Ruby2D.const_get(name))
        end
        @mixed[:methods].each do |name|
          @main.singleton_class.send(:remove_method, name) if @main.singleton_class.method_defined?(name, false)
        end
        @mixed = nil
      end
    end

    DEFAULT_REPLAY = ->(code) { eval(code, RubyVM::InstructionSequence.compile("proc { binding }.call", "chunky.rb").eval, "chunky.rb") }

    # A shown window, frame by frame. The page (main.rb's mount_game,
    # game.js) calls #step at most once per animation frame with the events
    # since the last call:
    #   k:left (a key went down)  u:left (up)  d:x,y,left (a mouse button
    #   down)  p:x,y,left (up)  m:x,y,dx,dy (moved)  w:dx,dy (wheel)
    #   e / l (the pointer came in, left)
    # and gets the frame as JSON:
    #   {"bg": rgba, "c": [commands], "next": ms, "log": "...", "over": "",
    #    "error": "..."}
    # In each frame as in the gem's tick: the events in order, then a held
    # event for every key and button still down, then update, then the
    # scene in z order and the render block.
    class Runner
      attr_reader :window, :ticks
      attr_accessor :source

      def initialize(window)
        @window = window
        @now = 0.0
        @keys = []
        @buttons = []
        @ticks = 0
        @fps = FPS.to_f
        @output = +""
      end

      def canvas? = true
      def width = @window.width.to_i
      def height = @window.height.to_i
      def title = @window.title.to_s
      def over? = @window.instance_variable_get(:@close) == true
      def objects = @window.instance_variable_get(:@objects).dup
      def inspect = "#<Ruby2D window #{width}x#{height} #{title.inspect}#{over? ? ' closed' : ''}>"
      alias to_s inspect

      # ---------- for the page (main.rb, game.js) ----------

      # the first picture: the scene as the cell left it, no frame run yet
      def full_json
        current { frame_json(scene) }
      rescue StandardError, ScriptError => e
        error_json("#{e.class}: #{e.message}#{where(e)}")
      end

      def step(now_ms, events)
        current do
          @now = now_ms.to_f / 1000.0
          Page.clock = @now
          commands = capture do
            events.to_s.split("|").each { |event| dispatch(event) }
            unless over?
              held
              @ticks += 1
              @window.update_callback
            end
            scene
          end
          frame_json(commands)
        end
      rescue StandardError, ScriptError => e
        error_json("#{e.class}: #{e.message}#{where(e)}")
      end

      # stops the window with an error (main.rb: the time limit)
      def error_json(text)
        @window.instance_variable_set(:@close, true)
        JSON.generate({ "over" => "", "error" => text })
      end

      # the cell again, for a check to play (Page.replay)
      def fresh
        raise Error, "no code to replay this window from" unless @source

        Page.replay(@source) or raise Error, "the replayed code showed no window"
      end

      # ---------- headless, for checks and tests ----------

      # +key+ down for +frames+ frames, then up (the gem's names: "left",
      # "space", "a", "return"; a Symbol works too)
      def press(key, frames: 1)
        key = key.to_s
        step(next_ms, "k:#{key}")
        (frames - 1).times { step(next_ms, "") }
        step(next_ms, "u:#{key}")
        self
      end

      def click(x, y, button: :left)
        step(next_ms, "m:#{x},#{y},0,0|d:#{x},#{y},#{button}")
        step(next_ms, "p:#{x},#{y},#{button}")
        self
      end

      def move_mouse(x, y)
        step(next_ms, "m:#{x},#{y},#{x - mouse_x},#{y - mouse_y}")
        self
      end

      # +n+ frames without input; advance(seconds) as many as 60 a second
      def tick(frames = 1)
        frames.times { break if over?; step(next_ms, "") }
        self
      end

      def advance(seconds) = tick((seconds * FPS).round)

      private

      def next_ms = (@now + 1.0 / FPS) * 1000.0
      def mouse_x = @window.mouse_x.to_i
      def mouse_y = @window.mouse_y.to_i

      # while a frame runs, the DSL (Square.new, Window.width) means this
      # window - other cells' windows may be on the page too
      def current
        saved = [DSL.window? ? DSL.window : nil, Window.shown?, Page.clock]
        DSL.window = @window
        Window.shown = true
        Page.clock = @now
        yield
      ensure
        DSL.window, shown, Page.clock = saved
        Window.shown = shown
      end

      def dispatch(event)
        kind, value = event.split(":", 2)
        case kind
        when "k"
          @keys << value unless @keys.include?(value)
          @window.key_callback(:down, value)
        when "u"
          @keys.delete(value)
          @window.key_callback(:up, value)
        when "d", "p"
          x, y, button = value.split(",")
          button = button.to_sym
          move_to(x.to_i, y.to_i)
          if kind == "d"
            @buttons << button unless @buttons.include?(button)
            @window.mouse_callback(:down, button, nil, x.to_i, y.to_i, nil, nil)
          else
            @buttons.delete(button)
            @window.mouse_callback(:up, button, nil, x.to_i, y.to_i, nil, nil)
          end
        when "m"
          x, y, dx, dy = value.split(",").map(&:to_i)
          move_to(x, y)
          @window.mouse_callback(:move, nil, nil, x, y, dx, dy)
        when "w"
          dx, dy = value.split(",").map(&:to_f)
          @window.mouse_callback(:scroll, nil, :normal, nil, nil, dx, dy)
        when "e" then @window.mouse_callback(:enter, nil, nil, nil, nil, nil, nil)
        when "l" then @window.mouse_callback(:leave, nil, nil, nil, nil, nil, nil)
        end
      end

      # SDL reports every key and button still down once a frame
      def held
        @keys.each { |key| @window.key_callback(:held, key) }
        @buttons.each { |button| @window.mouse_callback(:held, button, nil, mouse_x, mouse_y, nil, nil) }
      end

      def move_to(x, y)
        @window.instance_variable_set(:@mouse_x, x)
        @window.instance_variable_set(:@mouse_y, y)
      end

      # a frame drawn: the gem counts it (Window.frames) and its rate
      def scene
        dt = @window.delta_time.to_f
        @fps = @fps * 0.9 + (1.0 / dt) * 0.1 if dt > 0
        @window.instance_variable_set(:@frames, @window.frames.to_i + 1) if @ticks.positive?
        @window.instance_variable_set(:@fps, @fps.round(1))
        Page.record { @window.render_objects }
      end

      def capture
        old = $stdout
        $stdout = StringIO.new(@output)
        @output.clear
        yield
      ensure
        $stdout = old
      end

      def frame_json(commands)
        bg = @window.background
        frame = { "bg" => [bg.r, bg.g, bg.b, bg.a], "c" => commands }
        frame["next"] = ((@now + interval * 0.75) * 1000).round unless over?
        frame["log"] = @output.dup unless @output.empty?
        frame["over"] = "" if over?
        JSON.generate(frame)
      end

      # a frame every 1/60 s, or less often with set fps_cap: 30
      def interval
        cap = @window.fps_cap
        cap.is_a?(Numeric) && cap.finite? && cap.positive? && cap < FPS ? 1.0 / cap : 1.0 / FPS
      end

      def where(error)
        line = error.backtrace_locations&.find { |loc| loc.path == "chunky.rb" }&.lineno
        line ? " (line #{line})" : ""
      end
    end
  end

  def self.reset__ = Page.reset
  def self.mix__(main = TOPLEVEL_BINDING.receiver) = Page.mix(main)
  def self.unmix__ = Page.unmix
end
