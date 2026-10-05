# Renders the example drawings into examples/*.svg (animated) and
# examples/*-still.svg, and checks what the check helpers say about them.
#   ruby examples.rb
require_relative "turtle"

$shown = []
module Kernel
  def show_image(image)
    $shown << image.to_data_url
    nil
  end
end

def polygon(corners, side)
  corners.times do
    forward side
    right 360.0 / corners
  end
end

def koch(length, depth)
  if depth.zero?
    forward length
  else
    koch(length / 3.0, depth - 1)
    left 60
    koch(length / 3.0, depth - 1)
    right 120
    koch(length / 3.0, depth - 1)
    left 60
    koch(length / 3.0, depth - 1)
  end
end

def tree(length, depth)
  return if depth.zero?

  pen_width depth
  color(depth > 2 ? "#6b4226" : "#3a8d3a")
  forward length
  left 25
  tree(length * 0.72, depth - 1)
  right 50
  tree(length * 0.72, depth - 1)
  left 25
  pen_width depth
  color(depth > 2 ? "#6b4226" : "#3a8d3a")
  back length
end

EXAMPLES = {
  "square" => -> { turtle { 4.times { forward 100; right 90 } } },
  "star" => -> { turtle { color "#e8722a"; 5.times { forward 160; right 144 } } },
  "spiral" => lambda {
    turtle do
      90.times do |i|
        color "hsl(#{i * 4}, 75%, 45%)"
        forward i * 2.5
        right 91
      end
    end
  },
  "koch" => -> { turtle { color "#2a6fb0"; 3.times { koch(270, 3); right 120 } } },
  "tree" => -> { turtle { jump(-120); tree(90, 8) } },
  "polygons" => lambda {
    turtle do
      (3..8).each do |n|
        color "hsl(#{n * 45}, 70%, 45%)"
        polygon(n, 60)
      end
    end
  }
}.freeze

Dir.mkdir("examples") unless Dir.exist?("examples")
turtles = {}
EXAMPLES.each do |name, draw|
  t = draw.call
  turtles[name] = t
  File.write("examples/#{name}.svg", t.to_svg)
  File.write("examples/#{name}-still.svg", t.to_svg(animate: false))
  puts format("%-9s %-62s %6d bytes", name, t.inspect, t.to_svg.bytesize)
end

def expect(label, value)
  puts "#{value ? 'ok  ' : 'FAIL'} #{label}"
  $failed = true unless value
end

sq = turtles["square"]
expect "square: regular_polygon?(4, 100)", sq.regular_polygon?(4, 100)
expect "square: closed, winding 1, area 10000", sq.closed? && sq.winding == 1 && (sq.area - 10_000).abs < 1e-6
expect "square: not regular_polygon?(4, 90)", !sq.regular_polygon?(4, 90)
expect "square: Turtle.from(images) finds it", Turtle.from($shown).include?(Turtle.from([$shown[0]]).first) &&
                                              Turtle.from([$shown[0]]).first.regular_polygon?(4, 100)
star = turtles["star"]
expect "star: regular 5 edges, winding 2", star.regular_polygon?(5, 160) && star.winding == 2
koch = turtles["koch"]
expect "koch: 192 lines of 10, closed, winding 1", koch.lines.size == 192 && koch.closed? &&
                                                   koch.lines.all? { |l| (l.length - 10).abs < 0.01 } && koch.winding == 1
expect "koch: area 8/5-ish of the triangle", (koch.area / (Math.sqrt(3) / 4 * 270**2) - 1.547).abs < 0.01
tree = turtles["tree"]
expect "tree: 255 branches, ends at its root", tree.lines.size == 2 * 255 && tree.position == [0.0, -120.0]
split = Turtle.new.tap { |t| 4.times { t.forward 50; t.forward 50; t.right 90 } }
expect "edges join a side drawn in two steps", split.edges.size == 4 && split.regular_polygon?(4, 100)
expect "same_shape? ignores size with scale: true",
       sq.same_shape?(Turtle.new.tap { |t| 4.times { t.forward 30; t.right 90 } }, scale: true)
expect "open L is not closed", !Turtle.new.tap { |t| t.forward 10; t.right 90; t.forward 10 }.closed?
begin
  turtle { loop { forward 1 } }
  expect "endless loop stops", false
rescue Turtle::TooFar => e
  expect "endless loop stops: #{e.message[0, 40]}...", true
end
begin
  turtle { loop { right 90 } }
  expect "endless turning stops", false
rescue Turtle::TooFar => e
  expect "endless turning stops: #{e.message[0, 40]}...", true
end
begin
  Turtle.new.color("red\" onload=\"x")
  expect "bad colour refused", false
rescue ArgumentError
  expect "bad colour refused", true
end
exit 1 if $failed
