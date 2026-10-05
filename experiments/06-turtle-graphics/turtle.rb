# frozen_string_literal: true

# Turtle graphics with Chunky the fox as the turtle.
#
#   turtle { 4.times { forward 100; right 90 } }   # a square, shown below the cell
#
# Chunky starts at (0, 0) looking up. Headings are compass degrees: 0 is up,
# 90 is to the right; +right+ turns clockwise. y grows upwards, like in maths.
#
# Every step is recorded, so an exercise's check can look at what was drawn
# instead of at pixels:
#
#   t = Turtle.from(images).last          # the turtles the cell showed
#   t.regular_polygon?(4, 100)            # => true for the square above
#
# The picture is an SVG (Turtle#to_svg) that draws itself in the order it was
# walked, with Chunky running along the path. show_image takes it as it is
# (it answers to_data_url). Pure Ruby, no gem.
class Turtle
  # one step, drawn (pen down) or not: from (x1, y1) to (x2, y2)
  Step = Struct.new(:x1, :y1, :x2, :y2, :pen, :color, :width) do
    def length = Math.hypot(x2 - x1, y2 - y1)
    def from = [x1, y1]
    def to = [x2, y2]
    # the compass direction of the step: 0 up, 90 right
    def heading = Turtle.normalize(Math.atan2(x2 - x1, y2 - y1) * 180 / Math::PI)

    def inspect
      "#<line (#{Turtle.fmt(x1)}, #{Turtle.fmt(y1)}) -> (#{Turtle.fmt(x2)}, #{Turtle.fmt(y2)}) " \
        "#{color} #{Turtle.fmt(width)}px>"
    end
    alias_method :to_s, :inspect
  end

  # an infinite loop or a recursion without a base case ends here, with a
  # message, rather than when the browser gives up
  class TooFar < StandardError; end

  MAX_STEPS = 100_000
  EPS = 1e-6
  INK = "#1a1208"
  BACON = "#c14a2e"
  COLOR = /\A(#\h{3,8}|[a-zA-Z]{3,20}|(rgb|hsl)a?\([\d\s.,%+-]+\))\z/

  attr_reader :x, :y, :heading, :steps, :turns
  attr_accessor :animate, :duration

  def initialize(animate: true, duration: nil)
    @x = 0.0
    @y = 0.0
    @heading = 0.0
    @pen = true
    @color = BACON
    @pen_width = 3.0
    @visible = true
    @steps = []
    @turns = []
    @animate = animate
    @duration = duration
  end

  # ---------- moving ----------

  def forward(distance)
    rad = @heading * Math::PI / 180
    walk_to(@x + distance.to_f * Math.sin(rad), @y + distance.to_f * Math.cos(rad))
  end

  def back(distance) = forward(-distance.to_f)

  def right(angle)
    @turns << angle.to_f
    @heading = Turtle.normalize(@heading + angle.to_f)
    self
  end

  def left(angle) = right(-angle.to_f)

  # walks straight to a point (drawing, if the pen is down); the heading stays
  def goto(x, y) = walk_to(x.to_f, y.to_f)

  # back to the start, looking up
  def home
    goto(0, 0)
    @heading = 0.0
    self
  end

  # forward without drawing
  def jump(distance)
    was = @pen
    @pen = false
    forward(distance)
  ensure
    @pen = was
  end

  # looks into a compass direction: 0 up, 90 right, 180 down, 270 left
  def face(heading)
    @heading = Turtle.normalize(heading.to_f)
    self
  end

  # a circle (a polygon of +steps+ sides), turning right: its centre is
  # +radius+ to Chunky's right
  def circle(radius, steps: 36)
    side = 2 * Math::PI * radius.to_f / steps
    steps.times do
      right(180.0 / steps)
      forward(side)
      right(180.0 / steps)
    end
    self
  end

  # ---------- the pen ----------

  def pen_up = (@pen = false) || self
  def pen_down = (@pen = true) && self
  def pen_down? = @pen

  # pen colour: "red", :orange, "#c14a2e", "hsl(120, 80%, 40%)"
  def color(name = nil)
    return @color if name.nil?

    name = name.to_s
    raise ArgumentError, "#{name.inspect} is not a colour - try \"red\" or \"#c14a2e\"" unless name.match?(COLOR)

    @color = name
    self
  end

  # pen width in pixels
  def pen_width(width = nil)
    return @pen_width if width.nil?

    @pen_width = width.to_f.clamp(0.1, 50)
    self
  end

  def hide = (@visible = false) || self
  def show = (@visible = true) && self
  def visible? = @visible

  alias_method :fd, :forward
  alias_method :bk, :back
  alias_method :backward, :back
  alias_method :rt, :right
  alias_method :lt, :left
  alias_method :pu, :pen_up
  alias_method :penup, :pen_up
  alias_method :pd, :pen_down
  alias_method :pendown, :pen_down
  alias_method :pen_color, :color
  alias_method :go_to, :goto

  def position = [Turtle.round(@x), Turtle.round(@y)]

  # ---------- what was drawn: for checks ----------

  # the drawn steps (pen down, longer than nothing)
  def lines = @steps.select { |s| s.pen && s.length > EPS }

  # the lines, with straight runs joined: a side drawn as forward 50;
  # forward 50 is one edge of 100
  def edges
    lines.each_with_object([]) do |line, out|
      last = out.last
      if last && same_point?(last.to, line.from) && (last.heading - line.heading).abs < 1e-4 &&
         last.color == line.color && last.width == line.width
        out[-1] = Step.new(last.x1, last.y1, line.x2, line.y2, true, line.color, line.width)
      else
        out << line
      end
    end
  end

  # true when the drawing ends where it started
  def closed?
    drawn = lines
    drawn.any? && same_point?(drawn.first.from, drawn.last.to)
  end

  def total_length = lines.sum(&:length)

  # the turns between one edge and the next, in degrees (right positive),
  # closing the loop when the drawing is closed
  def corners
    e = edges
    pairs = e.each_cons(2).to_a
    pairs << [e.last, e.first] if closed? && e.size > 1
    pairs.map { |a, b| Turtle.signed(b.heading - a.heading) }
  end

  # how many times the drawing goes around: 1 for a square, 2 for a
  # five-pointed star drawn with right 144
  def winding = (corners.sum / 360.0).round

  # a closed shape of +sides+ equal edges and equal corners - and of edge
  # length +side+, if given. A pentagram counts too: winding tells them apart
  def regular_polygon?(sides, side = nil)
    e = edges
    return false unless closed? && e.size == sides

    len = side ? side.to_f : e.first.length
    turns = corners
    e.all? { |edge| (edge.length - len).abs < 0.01 } &&
      turns.all? { |turn| (turn - turns.first).abs < 0.01 }
  end

  # the area inside a closed drawing (shoelace formula over its edges)
  def area
    return 0.0 unless closed?

    edges.sum { |e| e.x1 * e.y2 - e.x2 * e.y1 }.abs / 2.0
  end

  def colors = lines.map(&:color).uniq

  # [min_x, min_y, max_x, max_y] of everything walked, the start included
  def bounds
    xs = [0.0] + @steps.flat_map { |s| [s.x1, s.x2] }
    ys = [0.0] + @steps.flat_map { |s| [s.y1, s.y2] }
    [xs.min, ys.min, xs.max, ys.max].map { |v| Turtle.round(v) }
  end

  # the same edges and corners as +other+ - in size too, unless scale: true
  def same_shape?(other, scale: false)
    mine = edges
    theirs = other.edges
    return false unless mine.size == theirs.size && mine.any?

    factor = scale ? theirs.first.length / mine.first.length : 1.0
    mine.zip(theirs).all? { |a, b| (a.length * factor - b.length).abs < 0.01 } &&
      corners.zip(other.corners).all? { |a, b| a && b && (a - b).abs < 0.01 }
  end

  def inspect
    "#<Turtle #{lines.size} lines, Chunky at (#{Turtle.fmt(@x)}, #{Turtle.fmt(@y)}) looking #{Turtle.fmt(@heading)}°>"
  end
  alias_method :to_s, :inspect

  # ---------- the picture ----------

  # An SVG of the drawing, scaled to fit +max_width+ x +max_height+ pixels
  # (never enlarged more than 1.5 times). Animated, it draws itself in the
  # order it was walked - in +duration+ seconds, or as long as the walk is
  # (300 px a second, between 0.6 and 4 seconds) - with Chunky running along.
  def to_svg(animate: @animate, duration: @duration, max_width: 460, max_height: 400)
    min_x, min_y, max_x, max_y = bounds
    extent = [max_x - min_x, max_y - min_y, 60.0].max
    pad = extent * 0.08 + 14
    vb_x = min_x - pad
    vb_y = -max_y - pad            # SVG's y grows downwards: y is flipped
    vb_w = max_x - min_x + 2 * pad
    vb_h = max_y - min_y + 2 * pad
    scale = [max_width / vb_w, max_height / vb_h, 1.5].min
    px = 1.0 / scale                # one screen pixel, in drawing units

    walked = @steps.select { |s| s.length > EPS }
    total = walked.sum(&:length)
    animate &&= total > EPS
    secs = (duration || (total * scale / 300.0).clamp(0.6, 4.0)).to_f

    out = +""
    out << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{(vb_w * scale).round}" height="#{(vb_h * scale).round}" )
    out << %(viewBox="#{f(vb_x)} #{f(vb_y)} #{f(vb_w)} #{f(vb_h)}">)
    out << "<title>#{lines.size} lines drawn by Chunky</title>"
    if animate
      out << "<style>@keyframes d{to{stroke-dashoffset:0}}@keyframes h{to{opacity:0}}@keyframes s{to{opacity:1}}" \
             ".end{opacity:0;animation:s .001s #{f(secs)}s forwards}.run{animation:h .001s #{f(secs)}s forwards}" \
             "@media (prefers-reduced-motion:reduce){path{animation:none!important;stroke-dashoffset:0!important}" \
             ".run{display:none}.end{opacity:1!important;animation:none!important}}</style>"
    end
    out << %(<defs>#{fox_svg(px)}</defs>)
    out << %(<rect x="#{f(vb_x)}" y="#{f(vb_y)}" width="#{f(vb_w)}" height="#{f(vb_h)}" fill="#fffaf2"/>)
    out << %(<g fill="none" stroke-linecap="round" stroke-linejoin="round">)
    strokes.each do |stroke, start_at|
      length = stroke.sum(&:length)
      d = "M#{f(stroke.first.x1)} #{f(-stroke.first.y1)}" + stroke.map { |s| "L#{f(s.x2)} #{f(-s.y2)}" }.join
      attrs = %(d="#{d}" stroke="#{stroke.first.color}" stroke-width="#{f(stroke.first.width * px)}")
      if animate
        start = start_at / total * secs
        dash = f(length + px)
        attrs << %( style="stroke-dasharray:#{dash};stroke-dashoffset:#{dash};) +
                 %(animation:d #{f(length / total * secs)}s linear #{f(start)}s forwards")
      end
      out << "<path #{attrs}/>"
    end
    out << "</g>"
    if @visible
      if animate
        # steps join end to start, so Chunky's whole walk is one path
        motion = "M0 0" + walked.map { |s| "L#{f(s.x2)} #{f(-s.y2)}" }.join
        out << %(<g class="run"><use href="#fox"><animateMotion dur="#{f(secs)}s" fill="freeze" ) +
               %(rotate="auto" calcMode="paced" path="#{motion}"/></use></g>)
      end
      klass = animate ? %( class="end") : ""
      out << %(<g#{klass} transform="translate(#{f(@x)} #{f(-@y)}) rotate(#{f(@heading - 90)})"><use href="#fox"/></g>)
    end
    out << "</svg>"
  end

  def to_data_url
    url = "data:image/svg+xml;base64,#{[to_svg].pack('m0')}"
    Turtle.remember(url, snapshot)
    url
  end

  # writes the SVG to a file (a cell's files are offered as downloads)
  def save(path)
    File.write(path, to_svg(animate: false))
    path
  end

  # ---------- class side ----------

  class << self
    # the turtles behind some of show_image's data: URLs - in a check,
    # Turtle.from(images) is what this run of the cell showed
    def from(images)
      Array(images).filter_map { |url| shown[url] }
    end

    def remember(url, turtle)
      shown.delete(url)
      shown[url] = turtle
      shown.delete(shown.keys.first) while shown.size > 30
    end

    def shown = (@shown ||= {})

    def normalize(degrees)
      d = degrees.to_f % 360
      d = 0.0 if (d - 360).abs < 1e-9
      round(d)
    end

    # an angle as a turn, between -180 and 180
    def signed(degrees)
      d = normalize(degrees)
      d > 180 ? d - 360 : d
    end

    def round(value) = (value.to_f.round(9) + 0.0)

    def fmt(value)
      v = value.to_f.round(2)
      v == v.to_i ? v.to_i.to_s : v.to_s
    end
  end

  protected

  attr_writer :steps, :turns

  private

  def walk_to(x, y)
    if @steps.size >= MAX_STEPS
      raise TooFar, "Chunky is tired: more than #{MAX_STEPS} steps. Is there a loop that never ends, " \
                    "or a recursion without a base case?"
    end
    x = Turtle.round(x)
    y = Turtle.round(y)
    @steps << Step.new(@x, @y, x, y, @pen, @color, @pen_width)
    @x = x
    @y = y
    self
  end

  def same_point?(a, b) = (a[0] - b[0]).abs < 1e-4 && (a[1] - b[1]).abs < 1e-4

  # the drawn lines in runs that can be one SVG path - joined end to start,
  # one colour and width, no pen-up step in between - each with how far
  # Chunky had walked (drawing or not) when it began
  def strokes
    runs = []
    previous = nil
    walked = 0.0
    @steps.each do |step|
      next if step.length <= EPS

      if step.pen
        same = previous&.pen && same_point?(previous.to, step.from) &&
               previous.color == step.color && previous.width == step.width
        same ? runs.last[0] << step : runs << [[step], walked]
      end
      walked += step.length
      previous = step
    end
    runs
  end

  # a copy that later steps do not change: what the picture showed
  def snapshot
    copy = dup
    copy.steps = @steps.dup
    copy.turns = @turns.dup
    copy
  end

  def f(value) = Turtle.fmt(value)

  # Chunky from above, nose along +x, about 45 screen pixels long; in the
  # course's ink-and-white style with an orange tail tip and nose
  def fox_svg(px)
    %(<g id="fox" transform="scale(#{f(px * 1.3)})" stroke="#{INK}" stroke-width="1.6" stroke-linejoin="round">) +
      %(<path d="M-6 0 Q-13 -7 -20 -1 Q-14 1 -20 1 Q-13 7 -6 0Z" fill="#fff"/>) +
      %(<path d="M-20 -1 Q-17 0 -20 1 Q-23 0 -20 -1Z" fill="#e8722a" stroke-width="1"/>) +
      %(<ellipse cx="-1" cy="0" rx="8" ry="5.5" fill="#fff"/>) +
      %(<path d="M3 -6 L6 -11 L9 -5Z M3 6 L6 11 L9 5Z" fill="#fff"/>) +
      %(<path d="M3 -5.5 Q8 -6 14 0 Q8 6 3 5.5 Q1 0 3 -5.5Z" fill="#fff"/>) +
      %(<circle cx="14" cy="0" r="1.6" fill="#{INK}"/>) +
      %(<path d="M8 -2.6 l1 0 M8 2.6 l1 0" stroke-width="1.8" stroke-linecap="round"/>) +
      "</g>"
  end
end

module Kernel
  private

  # Draws with Chunky and shows the picture below the cell:
  #   turtle { 4.times { forward 100; right 90 } }
  #   turtle(animate: false) { |t| t.forward 50 }
  # Methods you define yourself work inside the block too (def polygon ...).
  # Returns the Turtle, for a closer look: t = turtle { ... }; t.lines
  def turtle(animate: true, duration: nil, &block)
    t = Turtle.new(animate: animate, duration: duration)
    if block
      block.arity == 1 ? block.call(t) : t.instance_eval(&block)
    end
    show_image(t) if respond_to?(:show_image, true)
    t
  end
end
