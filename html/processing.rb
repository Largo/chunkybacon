# Processing in the browser: the API of the processing gem (xord, 1.4.0,
# MIT) in pure Ruby. The real gem draws through rays and reflexion, C++ on
# OpenGL, which a browser does not have; main.rb serves this file for
# require "processing" (lesson 31), so a sketch in a cell is the one that
# runs with the gem on a computer:
#
#   require "processing"
#   using Processing
#
#   setup do
#     size 400, 300
#   end
#
#   draw do
#     background 30
#     ellipse mouseX, mouseY, 40, 40
#   end
#
# What the gem paints into its window is recorded here instead, one list of
# commands per frame, and painted by processing.js on a canvas below the
# cell; the mouse and the keys come back from there. Names, defaults and
# arguments follow the gem's context.rb and graphics_context.rb: the same
# refinement, setup and draw run the way its window runs them, the matrix
# reset before every frame and event, draw wrapped in push/pop. What needs
# OpenGL - images, shaders, 3D, the camera - raises NotImplementedError.
#
# main.rb (and the check harness) start a sketch after its cell has run, as
# the gem does at_exit: Processing.start__ runs setup and the first frame
# and hands over the sketch, and the next cell gets a fresh one.
require "json"
require "set"

module Processing
  EVENT_NAMES__ = %i[
    setup draw
    keyPressed keyReleased keyTyped
    mousePressed mouseReleased mouseMoved mouseDragged
    mouseClicked doubleClicked mouseWheel
    touchStarted touchEnded touchMoved
    windowMoved windowResized motion
  ].freeze

  SUFFIX_PRIVATE = /__[!?]?$/

  def self.context
    $processing_context__
  end

  def self.funcs__(context_class)
    (context_class.instance_methods - Object.instance_methods)
      .reject { _1 =~ SUFFIX_PRIVATE }
  end

  def self.to_snake_case__(camel_case_names)
    camel_case_names.map do |camel|
      snake = camel.to_s.gsub(/([a-z])([A-Z])/) { "#{$1}_#{$2.downcase}" }
      [camel, snake].map(&:to_sym)
    end
  end

  def self.alias_snake_case_methods__(klass, recursive = 1)
    to_snake_case__(klass.instance_methods(false))
      .reject { |camel, _| camel =~ SUFFIX_PRIVATE }
      .reject { |camel, snake| camel == snake }
      .each do |camel, snake|
        klass.remove_method snake if klass.method_defined?(snake, false)
        klass.alias_method snake, camel
      end
    return unless recursive > 0

    klass.constants.map { klass.const_get _1 }
      .flatten
      .select { _1.class == Module || _1.class == Class }
      .each { |inner| alias_snake_case_methods__ inner, recursive - 1 }
  end

  # ---------- the browser's side (main.rb, test/check_harness.rb) ----------

  # Text widths come from the canvas in the browser (main.rb sets this to a
  # call into processing.js); elsewhere an estimate.
  class << self
    attr_accessor :measure__
  end
  self.measure__ = ->(text, size, _font) { text.to_s.length * size * 0.55 }

  # The sketch the last cell wrote, started: setup and the first frame have
  # run. nil if it has no draw block or event block - the gem's window opens
  # only then (hasUserBlocks__). The next cell gets a fresh context.
  def self.start__
    context = $processing_context__
    $processing_context__ = Context.new
    return nil unless context&.hasUserBlocks__

    context.start__
    context
  end

  # a fresh context, as when a new file starts
  def self.reset__
    $processing_context__ = Context.new
  end

  module GraphicsContext
    PI         = Math::PI
    HALF_PI    = PI / 2
    QUARTER_PI = PI / 4
    TWO_PI     = PI * 2
    TAU        = PI * 2

    PROCESSING = :processing
    P5JS       = :p5js
    AUTO       = :auto

    RGBA = :rgba
    RGB  = :rgb
    HSB  = :hsb

    RADIANS = :radians
    DEGREES = :degrees

    CORNER  = :corner
    CORNERS = :corners
    CENTER  = :center
    RADIUS  = :radius

    ROUND   = :round
    SQUARE  = :butt
    PROJECT = :square
    MITER   = :miter
    BEVEL   = :square

    BLEND     = :normal
    ADD       = :add
    SUBTRACT  = :subtract
    LIGHTEST  = :lightest
    DARKEST   = :darkest
    EXCLUSION = :exclusion
    MULTIPLY  = :multiply
    SCREEN    = :screen
    REPLACE   = :replace

    LEFT     = :left
    RIGHT    = :right
    TOP      = :top
    BOTTOM   = :bottom
    BASELINE = :baseline

    IMAGE  = :image
    NORMAL = :normal
    CLAMP  = :clamp
    REPEAT = :repeat

    THRESHOLD = :threshold
    GRAY      = :gray
    INVERT    = :invert
    BLUR      = :blur

    LINE     = :line
    RECT     = :rect
    ELLIPSE  = :ellipse
    ARC      = :arc
    TRIANGLE = :triangle
    QUAD     = :quad
    GROUP    = :group

    POINTS         = :points
    LINES          = :lines
    TRIANGLES      = :triangles
    TRIANGLE_FAN   = :triangle_fan
    TRIANGLE_STRIP = :triangle_strip
    QUADS          = :quads
    QUAD_STRIP     = :quad_strip
    TESS           = :tess

    OPEN  = :open
    CLOSE = :close

    ENTER     = :enter
    SPACE     = :space
    TAB       = :tab
    DELETE    = :delete
    BACKSPACE = :backspace
    ESC       = :escape
    HOME      = :home
    PAGEUP    = :pageup
    PAGEDOWN  = :pagedown
    CLEAR     = :clear
    SHIFT     = :shift
    CONTROL   = :control
    ALT       = :alt
    WIN       = :win
    COMMAND   = :command
    OPTION    = :option
    FUNCTION  = :function
    CAPSLOCK  = :capslock
    SECTION   = :section
    HELP      = :help
    (1..24).each { |n| const_set "F#{n}", :"f#{n}" }
    UP   = :up
    DOWN = :down

    # CSS colour names, for fill "orange" (the gem's table)
    COLOR_CODES = {
      aliceblue:            '#f0f8ff',
      antiquewhite:         '#faebd7',
      aqua:                 '#00ffff',
      aquamarine:           '#7fffd4',
      azure:                '#f0ffff',
      beige:                '#f5f5dc',
      bisque:               '#ffe4c4',
      black:                '#000000',
      blanchedalmond:       '#ffebcd',
      blue:                 '#0000ff',
      blueviolet:           '#8a2be2',
      brown:                '#a52a2a',
      burlywood:            '#deb887',
      cadetblue:            '#5f9ea0',
      chartreuse:           '#7fff00',
      chocolate:            '#d2691e',
      coral:                '#ff7f50',
      cornflowerblue:       '#6495ed',
      cornsilk:             '#fff8dc',
      crimson:              '#dc143c',
      cyan:                 '#00ffff',
      darkblue:             '#00008b',
      darkcyan:             '#008b8b',
      darkgoldenrod:        '#b8860b',
      darkgray:             '#a9a9a9',
      darkgreen:            '#006400',
      darkgrey:             '#a9a9a9',
      darkkhaki:            '#bdb76b',
      darkmagenta:          '#8b008b',
      darkolivegreen:       '#556b2f',
      darkorange:           '#ff8c00',
      darkorchid:           '#9932cc',
      darkred:              '#8b0000',
      darksalmon:           '#e9967a',
      darkseagreen:         '#8fbc8f',
      darkslateblue:        '#483d8b',
      darkslategray:        '#2f4f4f',
      darkslategrey:        '#2f4f4f',
      darkturquoise:        '#00ced1',
      darkviolet:           '#9400d3',
      deeppink:             '#ff1493',
      deepskyblue:          '#00bfff',
      dimgray:              '#696969',
      dimgrey:              '#696969',
      dodgerblue:           '#1e90ff',
      firebrick:            '#b22222',
      floralwhite:          '#fffaf0',
      forestgreen:          '#228b22',
      fuchsia:              '#ff00ff',
      gainsboro:            '#dcdcdc',
      ghostwhite:           '#f8f8ff',
      goldenrod:            '#daa520',
      gold:                 '#ffd700',
      gray:                 '#808080',
      green:                '#008000',
      greenyellow:          '#adff2f',
      grey:                 '#808080',
      honeydew:             '#f0fff0',
      hotpink:              '#ff69b4',
      indianred:            '#cd5c5c',
      indigo:               '#4b0082',
      ivory:                '#fffff0',
      khaki:                '#f0e68c',
      lavenderblush:        '#fff0f5',
      lavender:             '#e6e6fa',
      lawngreen:            '#7cfc00',
      lemonchiffon:         '#fffacd',
      lightblue:            '#add8e6',
      lightcoral:           '#f08080',
      lightcyan:            '#e0ffff',
      lightgoldenrodyellow: '#fafad2',
      lightgray:            '#d3d3d3',
      lightgreen:           '#90ee90',
      lightgrey:            '#d3d3d3',
      lightpink:            '#ffb6c1',
      lightsalmon:          '#ffa07a',
      lightseagreen:        '#20b2aa',
      lightskyblue:         '#87cefa',
      lightslategray:       '#778899',
      lightslategrey:       '#778899',
      lightsteelblue:       '#b0c4de',
      lightyellow:          '#ffffe0',
      lime:                 '#00ff00',
      limegreen:            '#32cd32',
      linen:                '#faf0e6',
      magenta:              '#ff00ff',
      maroon:               '#800000',
      mediumaquamarine:     '#66cdaa',
      mediumblue:           '#0000cd',
      mediumorchid:         '#ba55d3',
      mediumpurple:         '#9370db',
      mediumseagreen:       '#3cb371',
      mediumslateblue:      '#7b68ee',
      mediumspringgreen:    '#00fa9a',
      mediumturquoise:      '#48d1cc',
      mediumvioletred:      '#c71585',
      midnightblue:         '#191970',
      mintcream:            '#f5fffa',
      mistyrose:            '#ffe4e1',
      moccasin:             '#ffe4b5',
      navajowhite:          '#ffdead',
      navy:                 '#000080',
      oldlace:              '#fdf5e6',
      olive:                '#808000',
      olivedrab:            '#6b8e23',
      orange:               '#ffa500',
      orangered:            '#ff4500',
      orchid:               '#da70d6',
      palegoldenrod:        '#eee8aa',
      palegreen:            '#98fb98',
      paleturquoise:        '#afeeee',
      palevioletred:        '#db7093',
      papayawhip:           '#ffefd5',
      peachpuff:            '#ffdab9',
      peru:                 '#cd853f',
      pink:                 '#ffc0cb',
      plum:                 '#dda0dd',
      powderblue:           '#b0e0e6',
      purple:               '#800080',
      rebeccapurple:        '#663399',
      red:                  '#ff0000',
      rosybrown:            '#bc8f8f',
      royalblue:            '#4169e1',
      saddlebrown:          '#8b4513',
      salmon:               '#fa8072',
      sandybrown:           '#f4a460',
      seagreen:             '#2e8b57',
      seashell:             '#fff5ee',
      sienna:               '#a0522d',
      silver:               '#c0c0c0',
      skyblue:              '#87ceeb',
      slateblue:            '#6a5acd',
      slategray:            '#708090',
      slategrey:            '#708090',
      snow:                 '#fffafa',
      springgreen:          '#00ff7f',
      steelblue:            '#4682b4',
      tan:                  '#d2b48c',
      teal:                 '#008080',
      thistle:              '#d8bfd8',
      tomato:               '#ff6347',
      turquoise:            '#40e0d0',
      violet:               '#ee82ee',
      wheat:                '#f5deb3',
      white:                '#ffffff',
      whitesmoke:           '#f5f5f5',
      yellow:               '#ffff00',
      yellowgreen:          '#9acd32',
      none:                 '#00000000',
    }

    DEG2RAD__ = Math::PI / 180.0
    RAD2DEG__ = 180.0 / Math::PI

    FONT_SIZE_DEFAULT__ = 12
    FONT_SIZE_MAX__     = 256
  end

  class Vector
    include Comparable

    def initialize(x = 0, y = 0, z = 0, context: nil)
      @x, @y, @z =
        case x
        when Vector then x.array
        when Array  then [x[0] || 0, x[1] || 0, x[2] || 0]
        else             [x || 0, y || 0, z || 0]
        end.map(&:to_f)
      @context = context || Processing.context
    end

    def initialize_copy(o)
      @x, @y, @z = o.array
    end

    alias copy dup

    def set(*args)
      initialize(*args)
      self
    end

    attr_accessor :x, :y, :z

    def lerp(*args, amount)
      v = toVector__(*args)
      self.x = x + (v.x - x) * amount
      self.y = y + (v.y - y) * amount
      self.z = z + (v.z - z) * amount
      self
    end

    def self.lerp(v1, v2, amount)
      v1.dup.lerp v2, amount
    end

    def array(n = 3)
      [@x, @y, @z].first(n)
    end
    alias to_a array

    def add(*args)
      v = toVector__(*args)
      @x += v.x; @y += v.y; @z += v.z
      self
    end

    def sub(*args)
      v = toVector__(*args)
      @x -= v.x; @y -= v.y; @z -= v.z
      self
    end

    def mult(num)
      @x *= num; @y *= num; @z *= num
      self
    end

    def div(num)
      @x /= num; @y /= num; @z /= num
      self
    end

    def +(v) = dup.add(v)
    def -(v) = dup.sub(v)
    def *(num) = dup.mult(num)
    def /(num) = dup.div(num)
    def -@ = dup.mult(-1)

    %i[add sub mult div].each do |op|
      define_singleton_method op do |v1, arg, target = nil|
        v = v1.dup.__send__(op, arg)
        target.set v if self === target
        v
      end
    end

    def mag = Math.sqrt(magSq)
    def magSq = @x * @x + @y * @y + @z * @z

    def setMag(target = nil, len)
      (target || self).set normal__ * len
    end

    def normalize(target = nil)
      (target || self).set normal__
    end

    def limit(max)
      setMag max if magSq > max**2
      self
    end

    def dist(v) = (self - v).mag
    def self.dist(v1, v2) = v1.dist(v2)

    def dot(*args)
      v = toVector__(*args)
      @x * v.x + @y * v.y + @z * v.z
    end

    def self.dot(v1, v2) = v1.dot(v2)

    def cross(a, *rest)
      target = self.class === rest.last ? rest.pop : nil
      o = toVector__(a, *rest)
      v = self.class.new(@y * o.z - @z * o.y, @z * o.x - @x * o.z, @x * o.y - @y * o.x)
      target.set v if self.class === target
      v
    end

    def self.cross(v1, v2, target = nil) = v1.cross(v2, target)

    def rotate(angle)
      rad = @context ? @context.toRadians__(angle) : angle
      c, s = Math.cos(rad), Math.sin(rad)
      @x, @y = @x * c - @y * s, @x * s + @y * c
      self
    end

    def heading = Math.atan2(y, x)

    def self.fromAngle(angle, target = nil)
      v = new(1, 0, 0).rotate(angle)
      target.set v if target
      v
    end

    def self.angleBetween(v1, v2)
      return 0 if v1.magSq.zero? || v2.magSq.zero?

      x = dot(v1, v2) / (v1.mag * v2.mag)
      return Math::PI if x <= -1
      return 0 if x >= 1

      Math.acos x
    end

    def self.random2D(target = nil)
      angle = rand(0.0...(Math::PI * 2))
      v = new(Math.cos(angle), Math.sin(angle), 0)
      target.set v if target
      v
    end

    def self.random3D(target = nil)
      angle = rand(0.0...(Math::PI * 2))
      z = rand(-1.0..1.0)
      r = Math.sqrt(1.0 - z**2)
      v = new(r * Math.cos(angle), r * Math.sin(angle), z)
      target.set v if target
      v
    end

    def inspect = "#<#{self.class.name}: #{x}, #{y}, #{z}>"

    def <=>(o)
      o.is_a?(Vector) ? array <=> o.array : nil
    end

    private

    def normal__
      len = mag
      len.zero? ? Vector.new(0, 0, 0) : Vector.new(@x / len, @y / len, @z / len)
    end

    def toVector__(*args)
      self.class === args.first ? args.first : self.class.new(*args)
    end
  end

  class WheelEvent
    def initialize(dx, dy)
      @dx, @dy = dx, dy
    end

    def delta = [@dx, @dy]
    def getCount = @dy
  end

  class Touch
    attr_reader :id, :x, :y

    def initialize(id, x, y)
      @id, @x, @y = id, x, y
    end

    def inspect = "#<Processing::Touch: id:#{id} x:#{x} y:#{y}>"
  end

  class Context
    include GraphicsContext

    Vector     = Processing::Vector
    Touch      = Processing::Touch
    WheelEvent = Processing::WheelEvent

    PORTRAIT  = :portrait
    LANDSCAPE = :landscape

    # what processing.js maps blendMode to (canvas composite operations)
    BLENDS__ = {
      normal: "source-over", add: "lighter", subtract: "difference",
      lightest: "lighten", darkest: "darken", exclusion: "exclusion",
      multiply: "multiply", screen: "screen", replace: "copy"
    }.freeze

    # keyCode from the browser's KeyboardEvent#key (reflexion's names)
    KEYS__ = {
      "ArrowLeft" => :left, "ArrowRight" => :right, "ArrowUp" => :up, "ArrowDown" => :down,
      " " => :space, "Enter" => :enter, "Escape" => :escape, "Tab" => :tab,
      "Backspace" => :backspace, "Delete" => :delete, "Home" => :home,
      "PageUp" => :pageup, "PageDown" => :pagedown, "Shift" => :shift,
      "Control" => :control, "Alt" => :alt, "Meta" => :command, "CapsLock" => :capslock
    }.freeze

    MOUSE_BUTTONS__ = { 0 => :left, 1 => :center, 2 => :right }.freeze

    def initialize(width = 500, height = 500)
      @width__, @height__ = width.to_i, height.to_i
      @out__          = []    # the commands since the last frame was taken
      @first__        = nil   # setup and the first frame, for the checks
      @sent__         = {}    # style and matrix as processing.js has them
      @drawing__      = false
      @matrix__       = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
      @matrixStack__  = []
      @styleStack__   = []
      @colorMaxes__   = [1.0] * 4
      @hsbColor__     = false
      @fill__         = nil
      @stroke__       = nil
      @strokeWeight__ = 1
      @strokeCap__    = ROUND
      @strokeJoin__   = MITER
      @fontName__     = nil
      @fontSize__     = FONT_SIZE_DEFAULT__
      @drawingShape__ = nil

      @loop__             = true
      @redraw__           = false
      @frameCount__       = 0
      @frameRate__        = 60.0
      @deltaTime__        = 1000.0 / 60
      @key__              = nil
      @keyCode__          = nil
      @keyRepeat__        = false
      @keysPressed__      = Set.new
      @pointer__          = nil
      @pointerPrev__      = nil
      @pointersPressed__  = []
      @pointersReleased__ = []

      emit__ "size", @width__, @height__
      emit__ "background", "rgba(204,204,204,1)"   # the gem's canvas: background 0.8
      beginDraw__
      renderMode  PROCESSING
      colorMode   RGB, 255
      angleMode   RADIANS
      rectMode    CORNER
      ellipseMode CENTER
      imageMode   CORNER
      shapeMode   CORNER
      blendMode   BLEND
      strokeCap   ROUND
      strokeJoin  MITER
      textAlign   LEFT
      fill         255
      stroke       0
      strokeWeight 1
      curveDetail    20
      curveTightness 0
      bezierDetail   20
      randomSeed     Random.new_seed
      noiseSeed      Random.new_seed
      noiseDetail    4, 0.5
    end

    def inspect = "#<Processing::Context #{@width__}x#{@height__}>"

    # ---------- the lifecycle (Window, Context#initialize) ----------

    def hasUserBlocks__
      @drawBlock__ || @keyPressedBlock__ || @keyReleasedBlock__ || @keyTypedBlock__ ||
        @mousePressedBlock__ || @mouseReleasedBlock__ || @mouseMovedBlock__ ||
        @mouseDraggedBlock__ || @mouseClickedBlock__ || @doubleClickedBlock__ ||
        @mouseOverBlock__ || @mouseOutBlock__ || @mouseWheelBlock__ ||
        @touchStartedBlock__ || @touchEndedBlock__ || @touchMovedBlock__ ||
        @windowMovedBlock__ || @windowResizedBlock__ || @motionBlock__
    end

    # setup, then the first frame (the window's on_setup, then its first
    # draw); what they drew is kept for the exercise checks
    def start__
      endDraw__ if @drawing__
      drawCanvas__ { @setupBlock__&.call }
      frame__
      @first__ = @out__.dup
      self
    end

    # One frame, as processing.js asks for it: the events since the last
    # one, each the way the gem's window hands it on, then draw (unless
    # noLoop). Returns the commands to paint as JSON.
    def step__(json)
      data = JSON.parse(json.to_s)
      dt = data["dt"].to_f
      if dt > 0
        @deltaTime__ = dt
        @frameRate__ = @frameRate__ * 0.9 + (1000.0 / dt) * 0.1
      end
      (data["events"] || []).each { |event| event__(event) }
      frame__
      JSON.generate(takeCommands__)
    end

    # the commands since the last call (and from now on, a fresh list)
    def takeCommands__
      out = @out__
      @out__ = []
      out
    end

    def looping__ = @loop__ || @redraw__

    # For the checks: setup's and the first frame's commands, each
    # [name, *args], styles included as ["style", fill, stroke, weight, ...]
    def commands__ = @first__ || @out__

    # For the checks: the shapes of the first frame (or of +commands+) with
    # the colours they were drawn in, as hashes
    def shapes__(commands = commands__)
      fill = stroke = nil
      commands.filter_map do |name, *args|
        if name == "style"
          fill, stroke = args
          next
        end
        next if %w[size matrix].include?(name)

        { op: name, args: args, fill: fill, stroke: stroke }
      end
    end

    # For the checks: events as processing.js would send them, one frame
    # each - [["move", x, y], ["down", x, y], ["key", "a"], ...]; the
    # shapes they drew. The sketch on the page runs on afterwards: its mouse,
    # keys and frame count are as they were.
    def simulate__(events)
      takeCommands__
      @sent__ = {}   # the first shape says its style again
      inputs = %i[@pointer__ @pointerPrev__ @pointersPressed__ @pointersReleased__ @key__
                  @keyCode__ @keysPressed__ @frameCount__].to_h { [_1, instance_variable_get(_1).dup] }
      commands = events.flat_map do |type, *args|
        list =
          case type.to_s
          when "move" then [{ "t" => "move", "x" => args[0], "y" => args[1], "drag" => !@pointersPressed__.empty? }]
          when "down" then [{ "t" => "move", "x" => args[0], "y" => args[1] }, { "t" => "down", "x" => args[0], "y" => args[1], "b" => 0 }]
          when "up"   then [{ "t" => "up", "x" => args[0], "y" => args[1], "b" => 0 }]
          when "key"  then [{ "t" => "keydown", "key" => args[0] }, { "t" => "keyup", "key" => args[0] }]
          else raise ArgumentError, "unknown event #{type}"
          end
        JSON.parse(step__(JSON.generate("dt" => 1000.0 / 60, "events" => list)))
      end
      shapes__(commands)
    ensure
      inputs&.each { |name, value| instance_variable_set name, value }
      @sent__ = {}
    end

    def frame__
      drawCanvas__ do
        next unless @loop__ || @redraw__

        @redraw__ = false
        begin
          push
          @drawBlock__&.call
        ensure
          pop
          @frameCount__ += 1
        end
      end
    end

    # The refinement calls whatever $processing_context__ is - the gem has
    # only one. Here a page can have several sketches, and the next cell's
    # context is current between their frames, so a sketch is the current
    # one while its own blocks run.
    def drawCanvas__
      previous, $processing_context__ = $processing_context__, self
      drawing = @drawing__
      beginDraw__ unless drawing
      yield
    ensure
      endDraw__ unless drawing
      $processing_context__ = previous
    end

    def beginDraw__
      raise "beginDraw() is already called" if @drawing__

      @matrixStack__.clear
      @styleStack__.clear
      @drawing__ = true
      @matrix__ = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    end

    def endDraw__
      assertDrawing__
      @drawing__ = false
    end

    def event__(event)
      case event["t"]
      when "move"
        drawCanvas__ do
          pointer__(event)
          block = event["drag"] ? @mouseDraggedBlock__ : @mouseMovedBlock__
          block&.call
          @touchMovedBlock__&.call
        end
      when "down"
        drawCanvas__ do
          pointer__(event)
          @pointersPressed__.push MOUSE_BUTTONS__.fetch(event["b"].to_i, :left)
          @mousePressedBlock__&.call
          @touchStartedBlock__&.call
        end
      when "up"
        drawCanvas__ do
          pointer__(event)
          button = MOUSE_BUTTONS__.fetch(event["b"].to_i, :left)
          @pointersReleased__.push button
          if (index = @pointersPressed__.index(button))
            @pointersPressed__.delete_at index
          end
          @mouseReleasedBlock__&.call
          @mouseClickedBlock__&.call
          @doubleClickedBlock__&.call if event["clicks"].to_i == 2
          @touchEndedBlock__&.call
          @pointersReleased__.clear
        end
      when "enter" then drawCanvas__ { @mouseOverBlock__&.call }
      when "leave" then drawCanvas__ { @mouseOutBlock__&.call }
      when "wheel"
        drawCanvas__ { @mouseWheelBlock__&.call WheelEvent.new(event["dx"].to_f, event["dy"].to_f) }
      when "keydown"
        drawCanvas__ do
          key__(event, true)
          @keyPressedBlock__&.call
          @keyTypedBlock__&.call if @key__ && !@key__.empty?
        end
      when "keyup"
        drawCanvas__ do
          key__(event, false)
          @keyReleasedBlock__&.call
        end
      end
    end

    def pointer__(event)
      @pointerPrev__ = @pointer__
      @pointer__ = [event["x"].to_f, event["y"].to_f]
    end

    def key__(event, pressed)
      name = event["key"].to_s
      code = KEYS__[name] || (name =~ /\AF(\d+)\z/ ? :"f#{$1}" : name.downcase.to_sym)
      @key__ = name.length == 1 ? name : ""
      @keyCode__ = code
      @keyRepeat__ = pressed && @keysPressed__.include?(code)
      pressed ? @keysPressed__.add(code) : @keysPressed__.delete(code)
    end

    # ---------- the sketch's blocks (context.rb) ----------

    def setup(&block)
      @setupBlock__ = block if block
      nil
    end

    def draw(&block)
      @drawBlock__ = block if block
      nil
    end

    def keyPressed(&block)
      @keyPressedBlock__ = block if block
      keyIsPressed
    end

    def keyReleased(&block)
      @keyReleasedBlock__ = block if block
      nil
    end

    def keyTyped(&block)
      @keyTypedBlock__ = block if block
      nil
    end

    def mousePressed(&block)
      @mousePressedBlock__ = block if block
      !@pointersPressed__.empty?
    end

    %i[mouseReleased mouseMoved mouseDragged mouseClicked doubleClicked mouseOver mouseOut
       mouseWheel touchStarted touchEnded touchMoved windowMoved windowResized motion].each do |name|
      define_method name do |&block|
        instance_variable_set "@#{name}Block__", block if block
        nil
      end
    end

    def size(width, height, pixelDensity: nil)
      @width__, @height__ = width.to_i, height.to_i
      emit__ "size", @width__, @height__
      nil
    end
    alias createCanvas size

    def setTitle(_title) = nil
    def pixelDensity(_density = nil) = 1
    def fullscreen(_state = true) = nil
    def smooth = nil
    def noSmooth = nil
    def displayWidth = @width__
    def displayHeight = @height__
    def displayDensity = 1
    def windowMove(_x, _y) = nil

    def windowResize(width, height)
      size width, height
    end

    def windowResizable(_resizable) = nil
    def windowOrientation(*_orientations) = nil
    def windowX = 0
    def windowY = 0
    def windowWidth = @width__
    def windowHeight = @height__
    def focused = true
    def frameCount = @frameCount__
    def frameRate = @frameRate__
    def deltaTime = @deltaTime__
    def key = @key__
    def keyCode = @keyCode__
    def keyIsPressed = !@keysPressed__.empty?
    def keyIsDown(keyCode) = @keysPressed__.include?(keyCode)
    def keyIsRepeated = @keyRepeat__
    def mouseX = @pointer__ ? @pointer__[0] : 0
    def mouseY = @pointer__ ? @pointer__[1] : 0
    def pmouseX = @pointerPrev__ ? @pointerPrev__[0] : 0
    def pmouseY = @pointerPrev__ ? @pointerPrev__[1] : 0

    def mouseButton
      ((@pointersPressed__ + @pointersReleased__) & [LEFT, RIGHT, CENTER]).last
    end

    def touches = []
    def motionGravity = createVector(0, 0)

    def loop
      @loop__ = true
    end

    def noLoop
      @loop__ = false
    end

    def redraw
      @redraw__ = true
    end

    # ---------- graphics_context.rb ----------

    def width = @width__
    def height = @height__
    def pixelWidth = @width__
    def pixelHeight = @height__

    def renderMode(mode = nil)
      @renderMode__ = mode if mode
      @renderMode__
    end

    def colorMode(mode = nil, *maxes)
      if mode != nil
        mode = mode.downcase.to_sym
        raise ArgumentError, "invalid color mode: #{mode}" unless [RGB, HSB].include?(mode)
        raise ArgumentError unless [0, 1, 3, 4].include?(maxes.size)

        @colorMode__ = mode
        @hsbColor__  = mode == HSB
        case maxes.size
        when 1    then @colorMaxes__                 = [maxes.first.to_f] * 4
        when 3, 4 then @colorMaxes__[0...maxes.size] = maxes.map(&:to_f)
        end
      end
      @colorMode__
    end

    # a colour as one Integer, 0xAARRGGBB
    def color(*args)
      r, g, b, a = toRGBA__(*args).map { |n| (n * 255).to_i.clamp(0, 255) }
      (r & 0xff) << 16 | (g & 0xff) << 8 | (b & 0xff) | (a & 0xff) << 24
    end

    def red(color) = ((color >> 16) & 0xff) / 255.0 * @colorMaxes__[0]
    def green(color) = ((color >> 8) & 0xff) / 255.0 * @colorMaxes__[1]
    def blue(color) = (color & 0xff) / 255.0 * @colorMaxes__[2]
    def alpha(color) = ((color >> 24) & 0xff) / 255.0 * @colorMaxes__[3]

    def hue(color)
      toHSV__(color)[0] * (@hsbColor__ ? @colorMaxes__[0] : 1)
    end

    def saturation(color)
      toHSV__(color)[1] * (@hsbColor__ ? @colorMaxes__[1] : 1)
    end

    def brightness(color)
      toHSV__(color)[2] * (@hsbColor__ ? @colorMaxes__[2] : 1)
    end

    def angleMode(mode = nil)
      if mode != nil
        @angleMode__ = mode
        @toRad__, @toDeg__, @fromRad__, @fromDeg__ =
          case mode.downcase.to_sym
          when RADIANS then [1.0, RAD2DEG__, 1.0, DEG2RAD__]
          when DEGREES then [DEG2RAD__, 1.0, RAD2DEG__, 1.0]
          else raise ArgumentError, "invalid angle mode: #{mode}"
          end
      end
      @angleMode__
    end

    def toRadians__(angle) = angle * @toRad__
    def toDegrees__(angle) = angle * @toDeg__
    def fromRadians__(radians) = radians * @fromRad__
    def fromDegrees__(degrees) = degrees * @fromDeg__

    def rectMode(mode)
      @rectMode__ = mode
    end

    def ellipseMode(mode)
      @ellipseMode__ = mode
    end

    def imageMode(mode)
      @imageMode__ = mode
    end

    def shapeMode(mode)
      @shapeMode__ = mode
    end

    def blendMode(mode = nil)
      @blendMode__ = mode if mode != nil
      @blendMode__
    end

    def fill(*args)
      @fill__ = toRGBA__(*args)
      nil
    end

    def noFill
      @fill__ = nil
      nil
    end

    def stroke(*args)
      @stroke__ = toRGBA__(*args)
      nil
    end

    def noStroke
      @stroke__ = nil
      nil
    end

    def strokeWeight(weight)
      @strokeWeight__ = weight
      nil
    end

    def strokeCap(cap)
      @strokeCap__ = cap
      nil
    end

    def strokeJoin(join)
      @strokeJoin__ = join
      nil
    end

    def curveDetail(detail)
      @curveDetail__ = detail
      nil
    end

    def curveTightness(tightness)
      @curveTightness__ = tightness
      nil
    end

    def bezierDetail(detail)
      @bezierDetail__ = detail
      nil
    end

    def textFont(font = nil, size = nil)
      if font != nil || size != nil
        if font.is_a?(Array)   # createFont's [name, size]
          @fontName__ = font[0]&.to_s
          size ||= font[1]
        elsif font
          @fontName__ = font.to_s
        end
        size = FONT_SIZE_MAX__ if size && size > FONT_SIZE_MAX__
        @fontSize__ = size if size
      end
      [@fontName__, @fontSize__]
    end

    def textSize(size)
      textFont nil, size
      nil
    end

    def textWidth(str) = Processing.measure__.call(str.to_s, @fontSize__, @fontName__).to_f
    def textAscent = @fontSize__ * 0.8
    def textDescent = @fontSize__ * 0.2

    def textAlign(horizontal, vertical = BASELINE)
      @textAlignH__ = horizontal
      @textAlignV__ = vertical
      nil
    end

    def textLeading(leading = nil)
      @textLeading__ = leading if leading
      @textLeading__ || @fontSize__ * 1.2
    end

    def background(*args)
      assertDrawing__
      emit__ "background", css__(toRGBA__(*args))
      nil
    end

    def clear
      assertDrawing__
      emit__ "clear"
      nil
    end

    def point(x, y)
      assertDrawing__
      shape__ "point", x, y
    end

    def line(x1, y1, x2, y2)
      assertDrawing__
      shape__ "line", x1, y1, x2, y2
    end

    def rect(a, b, c, d, *args)
      assertDrawing__
      x, y, w, h = toXYWH__ @rectMode__, a, b, c, d
      case args.size
      when 0 then shape__ "rect", x, y, w, h
      when 1 then shape__ "rect", x, y, w, h, args[0], args[0], args[0], args[0]
      when 4 then shape__ "rect", x, y, w, h, *args
      else raise ArgumentError
      end
    end

    def ellipse(a, b, c, d = nil)
      assertDrawing__
      x, y, w, h = toXYWH__ @ellipseMode__, a, b, c, (d || c)
      shape__ "ellipse", x, y, w, h
    end

    def circle(x, y, extent)
      ellipse x, y, extent, extent
    end

    def arc(a, b, c, d, start, stop)
      assertDrawing__
      x, y, w, h = toXYWH__ @ellipseMode__, a, b, c, d
      shape__ "arc", x, y, w, h, toRadians__(start), toRadians__(stop)
    end

    def square(x, y, extent)
      rect x, y, extent, extent
    end

    def triangle(x1, y1, x2, y2, x3, y3)
      assertDrawing__
      shape__ "poly", [x1, y1, x2, y2, x3, y3], true
    end

    def quad(x1, y1, x2, y2, x3, y3, x4, y4)
      assertDrawing__
      shape__ "poly", [x1, y1, x2, y2, x3, y3, x4, y4], true
    end

    def curve(cx1, cy1, x1, y1, x2, y2, cx2, cy2)
      assertDrawing__
      points = (0..@curveDetail__).flat_map do |i|
        t = i.to_f / @curveDetail__
        [curvePoint(cx1, x1, x2, cx2, t), curvePoint(cy1, y1, y2, cy2, t)]
      end
      shape__ "poly", points, false
    end

    def bezier(x1, y1, cx1, cy1, cx2, cy2, x2, y2)
      assertDrawing__
      shape__ "poly", bezierPoints__(x1, y1, cx1, cy1, cx2, cy2, x2, y2, @bezierDetail__), false
    end

    # The gem draws text at its top left: text(str, x, y) puts the baseline
    # at y, left aligned whatever textAlign says; only the box form,
    # text(str, x, y, w, h), aligns - processing.js measures it there
    def text(str, x, y, x2 = nil, y2 = nil)
      assertDrawing__
      if x2
        raise ArgumentError, "missing y2 parameter" unless y2

        x, y, w, h = toXYWH__ @rectMode__, x, y, x2, y2
        shape__ "textbox", str.to_s, x, y, w, h, @textAlignH__.to_s, @textAlignV__.to_s
      else
        shape__ "text", str.to_s, x, y
      end
    end

    def beginShape(type = nil)
      raise "beginShape() cannot be called twice" if @drawingShape__

      @drawingShape__ = { type: type, points: [], curve: [], contours: [], contour: nil }
      nil
    end

    def endShape(mode = nil)
      s = @drawingShape__ or raise "endShape() must be called after beginShape()"
      close = mode == CLOSE || s[:contours].any?
      if close && s[:curve].size >= 8
        x, y = s[:curve][0, 2]
        2.times { curveVertex x, y }
      end
      @drawingShape__ = nil
      drawPolygon__ s[:type], s[:points], close, s[:contours]
      nil
    end

    def beginContour
      s = @drawingShape__ or raise "beginContour() must be called after beginShape()"
      s[:contour] = []
      nil
    end

    def endContour
      s = @drawingShape__ or raise "endContour() must be called after beginShape()"
      raise "endContour() must be called after beginContour()" unless s[:contour]

      s[:contours] << s[:contour]
      s[:contour] = nil
      nil
    end

    def vertex(x, y, u = nil, v = nil)
      s = @drawingShape__ or raise "vertex() must be called after beginShape()"
      raise "Either 'u' or 'v' is missing" if (u == nil) != (v == nil)

      (s[:contour] || s[:points]).push x, y
      nil
    end

    def curveVertex(x, y)
      s = @drawingShape__ or raise "curveVertex() must be called after beginShape()"
      s[:curve].push x, y
      if s[:curve].size >= 8
        cx1, cy1, x1, y1, x2, y2, cx2, cy2 = s[:curve][-8, 8]
        (0..@curveDetail__).each do |i|
          next if i.zero? && s[:curve].size > 8

          t = i.to_f / @curveDetail__
          vertex curvePoint(cx1, x1, x2, cx2, t), curvePoint(cy1, y1, y2, cy2, t)
        end
      end
      nil
    end

    def bezierVertex(x2, y2, x3, y3, x4, y4)
      s = @drawingShape__ or raise "bezierVertex() must be called after beginShape()"
      x1, y1 = (s[:contour] || s[:points])[-2, 2]
      raise "vertex() is required before calling bezierVertex()" unless x1 && y1

      bezierPoints__(x1, y1, x2, y2, x3, y3, x4, y4, @bezierDetail__).drop(2).each_slice(2) { |x, y| vertex x, y }
      nil
    end

    def quadraticVertex(cx, cy, x3, y3)
      s = @drawingShape__ or raise "quadraticVertex() must be called after beginShape()"
      x1, y1 = (s[:contour] || s[:points])[-2, 2]
      raise "vertex() is required before calling quadraticVertex()" unless x1 && y1

      bezierVertex(
        x1 + (cx - x1) * 2.0 / 3.0, y1 + (cy - y1) * 2.0 / 3.0,
        x3 + (cx - x3) * 2.0 / 3.0, y3 + (cy - y3) * 2.0 / 3.0,
        x3, y3)
    end

    def translate(x, y, z = 0)
      assertDrawing__
      applyMatrix 1, 0, 0, 1, x, y
    end

    def scale(x, y = nil, z = 1)
      assertDrawing__
      applyMatrix x, 0, 0, (y || x), 0, 0
    end

    def rotate(angle)
      assertDrawing__
      rad = toRadians__(angle)
      c, s = Math.cos(rad), Math.sin(rad)
      applyMatrix c, s, -s, c, 0, 0
    end

    def shearX(angle)
      applyMatrix 1, 0, Math.tan(toRadians__(angle)), 1, 0, 0
    end

    def shearY(angle)
      applyMatrix 1, Math.tan(toRadians__(angle)), 0, 1, 0, 0
    end

    def pushMatrix(&block)
      assertDrawing__
      @matrixStack__.push @matrix__.dup
      block.call if block
    ensure
      popMatrix if block
    end

    def popMatrix
      assertDrawing__
      raise "matrix stack underflow" if @matrixStack__.empty?

      @matrix__ = @matrixStack__.pop
      nil
    end

    # six numbers, a b c d e f: the 2D part of the gem's 4x4 matrix
    def applyMatrix(*args)
      assertDrawing__
      args = args.first if args.first.is_a?(Array)
      raise NotImplementedError, "applyMatrix with 16 numbers is 3D - not in the browser's Processing" unless args.size == 6

      a, b, c, d, e, f = args.map(&:to_f)
      m = @matrix__
      @matrix__ = [
        m[0] * a + m[2] * b, m[1] * a + m[3] * b,
        m[0] * c + m[2] * d, m[1] * c + m[3] * d,
        m[0] * e + m[2] * f + m[4], m[1] * e + m[3] * f + m[5]
      ]
      nil
    end

    def resetMatrix
      assertDrawing__
      @matrix__ = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
      nil
    end

    def printMatrix
      a, b, c, d, e, f = @matrix__
      print format("%f %f %f\n%f %f %f\n", a, c, e, b, d, f)
      nil
    end

    def pushStyle(&block)
      assertDrawing__
      @styleStack__.push styles__
      block.call if block
    ensure
      popStyle if block
    end

    def popStyle
      assertDrawing__
      raise "style stack underflow" if @styleStack__.empty?

      restoreStyles__ @styleStack__.pop
      nil
    end

    def styles__
      [@fill__, @stroke__, @strokeWeight__, @strokeCap__, @strokeJoin__, @blendMode__,
       @fontName__, @fontSize__, @textLeading__, @colorMode__, @hsbColor__, @colorMaxes__.dup,
       @angleMode__, @toRad__, @toDeg__, @fromRad__, @fromDeg__, @rectMode__, @ellipseMode__,
       @imageMode__, @shapeMode__, @curveDetail__, @curveTightness__, @bezierDetail__,
       @textAlignH__, @textAlignV__]
    end

    def restoreStyles__(styles)
      @fill__, @stroke__, @strokeWeight__, @strokeCap__, @strokeJoin__, @blendMode__,
        @fontName__, @fontSize__, @textLeading__, @colorMode__, @hsbColor__, @colorMaxes__,
        @angleMode__, @toRad__, @toDeg__, @fromRad__, @fromDeg__, @rectMode__, @ellipseMode__,
        @imageMode__, @shapeMode__, @curveDetail__, @curveTightness__, @bezierDetail__,
        @textAlignH__, @textAlignV__ = styles
    end

    def push(&block)
      pushMatrix
      pushStyle
      block.call if block
    ensure
      pop if block
    end

    def pop
      popMatrix
      popStyle
    end

    def abs(value) = value.abs
    def ceil(value) = value.ceil
    def floor(value) = value.floor
    def round(value) = value.round
    def log(n) = Math.log(n)
    def exp(n) = Math.exp(n)
    def pow(value, exponent) = value**exponent
    def sq(value) = value * value
    def sqrt(value) = Math.sqrt(value)

    def mag(*args)
      x, y, z = *args
      case args.size
      when 2 then Math.sqrt x * x + y * y
      when 3 then Math.sqrt x * x + y * y + z * z
      else raise ArgumentError
      end
    end

    def dist(*args)
      case args.size
      when 4
        x1, y1, x2, y2 = *args
        xx, yy = x2 - x1, y2 - y1
        Math.sqrt xx * xx + yy * yy
      when 6
        x1, y1, z1, x2, y2, z2 = *args
        xx, yy, zz = x2 - x1, y2 - y1, z2 - z1
        Math.sqrt xx * xx + yy * yy + zz * zz
      else raise ArgumentError
      end
    end

    def norm(value, start, stop) = (value.to_f - start.to_f) / (stop.to_f - start.to_f)
    def lerp(start, stop, amount) = start + (stop - start) * amount

    def lerpColor(color1, color2, amount)
      color(
        lerp(red(color1), red(color2), amount),
        lerp(green(color1), green(color2), amount),
        lerp(blue(color1), blue(color2), amount),
        lerp(alpha(color1), alpha(color2), amount))
    end

    def map(value, start1, stop1, start2, stop2)
      lerp start2, stop2, norm(value, start1, stop1)
    end

    def min(*args) = args.flatten.min
    def max(*args) = args.flatten.max

    def constrain(value, min, max)
      value < min ? min : (value > max ? max : value)
    end

    def radians(degree) = degree * DEG2RAD__
    def degrees(radian) = radian * RAD2DEG__
    def sin(angle) = Math.sin(angle)
    def cos(angle) = Math.cos(angle)
    def tan(angle) = Math.tan(angle)
    def asin(value) = Math.asin(value)
    def acos(value) = Math.acos(value)
    def atan(value) = Math.atan(value)
    def atan2(y, x) = Math.atan2(y, x)

    def curvePoint(a, b, c, d, t)
      s  = @curveTightness__
      t3 = t * t * t
      t2 = t * t
      f1 = (s - 1.0) / 2.0 * t3 + (1.0 - s) * t2 + (s - 1.0) / 2.0 * t
      f2 = (s + 3.0) / 2.0 * t3 + (-5.0 - s) / 2.0 * t2 + 1.0
      f3 = (-3.0 - s) / 2.0 * t3 + (s + 2.0) * t2 + (1.0 - s) / 2.0 * t
      f4 = (1.0 - s) / 2.0 * t3 + (s - 1.0) / 2.0 * t2
      a * f1 + b * f2 + c * f3 + d * f4
    end

    def curveTangent(a, b, c, d, t)
      s   = @curveTightness__
      tt3 = t * t * 3.0
      t2  = t * 2.0
      f1  = (s - 1.0) / 2.0 * tt3 + (1.0 - s) * t2 + (s - 1.0) / 2.0
      f2  = (s + 3.0) / 2.0 * tt3 + (-5.0 - s) / 2.0 * t2
      f3  = (-3.0 - s) / 2.0 * tt3 + (s + 2.0) * t2 + (1.0 - s) / 2.0
      f4  = (1.0 - s) / 2.0 * tt3 + (s - 1.0) / 2.0 * t2
      a * f1 + b * f2 + c * f3 + d * f4
    end

    def bezierPoint(a, b, c, d, t)
      tt = 1.0 - t
      tt**3.0 * a + tt**2.0 * b * 3.0 * t + t**2.0 * c * 3.0 * tt + t**3.0 * d
    end

    def bezierTangent(a, b, c, d, t)
      tt = 1.0 - t
      3.0 * d * t**2.0 - 3.0 * c * t**2.0 + 6.0 * c * tt * t -
        6.0 * b * tt * t + 3.0 * b * tt**2.0 - 3.0 * a * tt**2.0
    end

    # Perlin noise, octaves added up as in the gem (whose single octave is
    # rays' glm::perlin - the same kind of noise, not the same numbers)
    def noise(x, y = 0, z = 0)
      amp = 0.5
      @noiseOctaves__.times.reduce(0) do |sum|
        value = (perlin__(x, y, z) / 2.0 + 0.5) * amp
        x *= 2
        y *= 2
        z *= 2
        amp *= @noiseFallOff__
        sum + value
      end
    end

    def noiseSeed(seed)
      @noisePerm__ = (0..255).to_a.shuffle(random: Random.new(seed)).then { _1 + _1 }
      nil
    end

    def noiseDetail(lod, falloff = nil)
      @noiseOctaves__ = lod if lod && lod > 0
      @noiseFallOff__ = falloff if falloff && falloff > 0
    end

    def random(*args)
      if args.first.is_a?(Array)
        a = args.first
        a.empty? ? nil : a[@random__.rand(a.size)]
      else
        high, low = args.reverse
        @random__.rand((low || 0).to_f...(high || 1).to_f)
      end
    end

    def randomSeed(seed)
      @random__ = Random.new(seed)
      @nextGaussian__ = nil
    end

    def randomGaussian(mean = 0, sd = 1)
      value =
        if @nextGaussian__
          x, @nextGaussian__ = @nextGaussian__, nil
          x
        else
          a, b, w = 0, 0, 1
          until w < 1
            a = random(2) - 1
            b = random(2) - 1
            w = a**2 + b**2
          end
          w = Math.sqrt(-2 * Math.log(w) / w)
          @nextGaussian__ = a * w
          b * w
        end
      value * sd + mean
    end

    def createVector(*args)
      Vector.new(*args, context: self)
    end

    def createFont(name, size, smooth: true)
      [name, size || FONT_SIZE_DEFAULT__]
    end

    # what needs the gem's OpenGL engine (or a camera, or a file)
    %i[tint noTint texture textureMode textureWrap shader resetShader filter clip noClip
       image shape copy blend loadPixels updatePixels pixels save rotateX rotateY rotateZ
       createImage createShape createGraphics createShader createCapture loadFont
       loadImage requestImage loadShape loadShader].each do |name|
      define_method name do |*_args, **_kwargs, &_block|
        raise NotImplementedError,
              "#{name} needs the processing gem's OpenGL engine - it works on your " \
              "computer, not in the browser's Processing"
      end
    end

    private

    def assertDrawing__
      raise "call beginDraw() before drawing" unless @drawing__
    end

    # a shape (and, before it, the style and matrix if they changed)
    def shape__(name, *args)
      style = [css__(@fill__), css__(@stroke__), @strokeWeight__.to_f, @strokeCap__.to_s,
               @strokeJoin__.to_s, BLENDS__.fetch(@blendMode__, "source-over"),
               @fontName__, @fontSize__.to_f]
      emit__ "style", *style unless @sent__[:style] == style
      @sent__[:style] = style
      matrix = @matrix__.map { _1.round(6) }
      emit__ "matrix", *matrix unless @sent__[:matrix] == matrix
      @sent__[:matrix] = matrix
      emit__ name, *args.map { |a| arg__(a) }
      nil
    end

    def arg__(a)
      case a
      when Numeric then num__(a)
      when Array   then a.map { arg__(_1) }
      else a
      end
    end

    def emit__(name, *args)
      @out__ << [name, *args]
    end

    def num__(n)
      n = n.to_f
      n.finite? ? n.round(3) : 0
    end

    def drawPolygon__(type, points, close, contours)
      points = points.map(&:to_f)
      case type
      when POINTS then points.each_slice(2) { |x, y| shape__ "point", x, y }
      when LINES  then points.each_slice(4) { |p| shape__ "line", *p if p.size == 4 }
      when TRIANGLES then points.each_slice(6) { |p| shape__ "poly", p, true if p.size == 6 }
      when QUADS     then points.each_slice(8) { |p| shape__ "poly", p, true if p.size == 8 }
      when TRIANGLE_STRIP
        points.each_slice(2).each_cons(3) { |a, b, c| shape__ "poly", a + b + c, true }
      when TRIANGLE_FAN
        first, *rest = points.each_slice(2).to_a
        rest.each_cons(2) { |b, c| shape__ "poly", first + b + c, true }
      when QUAD_STRIP
        points.each_slice(4).each_cons(2) { |(a, b), (c, d)| shape__ "poly", a + b + d + c, true }
      when TESS, nil
        if contours.any?
          shape__ "poly", points, true, contours
        else
          shape__ "poly", points, close
        end
      else raise ArgumentError, "invalid polygon type '#{type}'"
      end
    end

    def bezierPoints__(x1, y1, cx1, cy1, cx2, cy2, x2, y2, detail)
      (0..detail).flat_map do |i|
        t = i.to_f / detail
        [bezierPoint(x1, cx1, cx2, x2, t), bezierPoint(y1, cy1, cy2, y2, t)]
      end
    end

    def toXYWH__(mode, a, b, c, d)
      case mode
      when CORNER  then [a,           b,           c,     d]
      when CORNERS then [a,           b,           c - a, d - b]
      when CENTER  then [a - c / 2.0, b - d / 2.0, c,     d]
      when RADIUS  then [a - c,       b - d,       c * 2, d * 2]
      else raise ArgumentError
      end
    end

    # [r, g, b, a], each 0..1
    def toRGBA__(*args)
      a, b, c, d = args
      return parseColor__(a, b || alphaMax__) if a.is_a?(String) || a.is_a?(Symbol)

      rgba =
        case args.size
        when 1, 2 then [a, a, a, b || alphaMax__]
        when 3, 4 then [a, b, c, d || alphaMax__]
        else raise ArgumentError
        end
      rgba = rgba.map.with_index { |n, i| n / @colorMaxes__[i] }
      rgba = hsv__(*rgba) if @hsbColor__
      rgba.map { _1.to_f.clamp(0.0, 1.0) }
    end

    def parseColor__(str, alpha)
      str = str.to_s
      str = COLOR_CODES[str.downcase.to_sym] || str if str !~ /^\s*#\d+/
      r, g, b, a =
        case str
        when /^\s*##{'([0-9a-f]{2})' * 3}([0-9a-f]{2})?\s*$/i
          $~[1..4].map { |n| n.to_i(16) / 255.0 if n }
        when /^\s*##{'([0-9a-f]{1})' * 3}([0-9a-f]{1})?\s*$/i
          $~[1..4].map { |n| n.to_i(16) / 15.0 if n }
        else
          raise ArgumentError, "invalid color code: '#{str}'"
        end
      [r, g, b, a || (alpha / alphaMax__)].map { _1.to_f.clamp(0.0, 1.0) }
    end

    def alphaMax__ = @colorMaxes__[3]

    def css__(rgba)
      return nil unless rgba

      r, g, b, a = rgba
      "rgba(#{(r * 255).round},#{(g * 255).round},#{(b * 255).round},#{a.round(3)})"
    end

    # hue, saturation and value 0..1 to red, green and blue
    def hsv__(h, s, v, a)
      h = (h % 1.0) * 6
      i = h.floor
      f = h - i
      p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
      r, g, b = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i % 6]
      [r, g, b, a]
    end

    def toHSV__(color)
      r, g, b = [16, 8, 0].map { ((color >> _1) & 0xff) / 255.0 }
      max, min = [r, g, b].max, [r, g, b].min
      d = max - min
      h =
        if d.zero? then 0.0
        elsif max == r then ((g - b) / d % 6) / 6.0
        elsif max == g then ((b - r) / d + 2) / 6.0
        else ((r - g) / d + 4) / 6.0
        end
      [h, max.zero? ? 0.0 : d / max, max]
    end

    # Ken Perlin's improved noise, -1..1
    def perlin__(x, y, z)
      p = @noisePerm__
      xi, yi, zi = x.floor & 255, y.floor & 255, z.floor & 255
      x -= x.floor
      y -= y.floor
      z -= z.floor
      u, v, w = fade__(x), fade__(y), fade__(z)
      a = p[xi] + yi
      aa = p[a] + zi
      ab = p[a + 1] + zi
      b = p[xi + 1] + yi
      ba = p[b] + zi
      bb = p[b + 1] + zi
      lerp(
        lerp(lerp(grad__(p[aa], x, y, z), grad__(p[ba], x - 1, y, z), u),
             lerp(grad__(p[ab], x, y - 1, z), grad__(p[bb], x - 1, y - 1, z), u), v),
        lerp(lerp(grad__(p[aa + 1], x, y, z - 1), grad__(p[ba + 1], x - 1, y, z - 1), u),
             lerp(grad__(p[ab + 1], x, y - 1, z - 1), grad__(p[bb + 1], x - 1, y - 1, z - 1), u), v),
        w)
    end

    def fade__(t) = t * t * t * (t * (t * 6 - 15) + 10)

    def grad__(hash, x, y, z)
      h = hash & 15
      u = h < 8 ? x : y
      v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
      (h.even? ? u : -u) + ((h & 2).zero? ? v : -v)
    end
  end

  $processing_context__ = Context.new

  refine Object do
    Processing.funcs__(Context).each do |func|
      define_method func do |*args, **kwargs, &block|
        $processing_context__.__send__ func, *args, **kwargs, &block
      end
    end
  end
end

def Processing(snake_case: false)
  return Processing unless snake_case

  $processing_refinements_with_snake_case ||= Module.new do
    Processing.alias_snake_case_methods__ Processing::Context

    refine Object do
      Processing.funcs__(Processing::Context).each do |func|
        define_method func do |*args, **kwargs, &block|
          $processing_context__.__send__ func, *args, **kwargs, &block
        end
      end
    end
  end
end

# the gem's constants at the top level, as its processing.rb sets them
Processing::Context.constants
  .reject { _1 =~ /__$/ }
  .each { Object.const_set _1, Processing::Context.const_get(_1) unless Object.const_defined?(_1, false) }
