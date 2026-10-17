# The Pico lessons' canned data (docs/HANDOVER.md §6r):
#
# - html/assets/data/pico/http/<host>__<path>.json: {status, headers, body}
#   of the web APIs the lessons call, for when the browser cannot reach
#   them (offline, CORS) and for the check harness, which never goes online.
#   The name is the URL's host, "__", and its path and query with every run
#   of other characters than letters, digits and dots made one "_"
#   (picoruby_worker.js's slug).
# - html/assets/data/pico/camera/{chunky,bacon}.pgm: 160 x 120 grey
#   pictures for the simulated camera, drawn here from circles and boxes -
#   our own drawings (not the why-foxes, whose licence needs attribution).
#
#   ruby tools/make_pico_fixtures.rb          # the pictures (the same bytes again)
#   ruby tools/make_pico_fixtures.rb --http   # also fetch the APIs' answers anew
require "json"
require "net/http"
require "uri"
require "fileutils"

ROOT = File.expand_path("../html/assets/data/pico", __dir__)
URLS = [
  "https://rubygems.org/api/v1/gems/rake.json",
  "https://api.open-meteo.com/v1/forecast?latitude=47.37&longitude=8.54&current=temperature_2m,weather_code,wind_speed_10m"
].freeze

def slug(url)
  uri = URI(url)
  path = "#{uri.path}#{uri.query ? "?#{uri.query}" : ''}".sub(%r{\A/}, "")
  "#{uri.host}__#{path.gsub(/[^A-Za-z0-9.]+/, '_')}"
end

def fetch_http
  FileUtils.mkdir_p(File.join(ROOT, "http"))
  URLS.each do |url|
    uri = URI(url)
    res = Net::HTTP.get_response(uri)
    keep = %w[content-type]
    headers = res.to_hash.select { |k, _| keep.include?(k) }.transform_values(&:first)
    body = res.body.force_encoding("UTF-8")
    data = { "url" => url, "fetched" => Time.now.utc.strftime("%Y-%m-%d"), "status" => res.code.to_i,
             "headers" => headers, "body" => body }
    file = File.join(ROOT, "http", "#{slug(url)}.json")
    File.write(file, JSON.pretty_generate(data) + "\n")
    puts "#{file} (#{res.code}, #{body.bytesize} bytes)"
  end
end

W = 160
H = 120

def picture
  px = Array.new(W * H, 235)
  yield ->(x, y, v) { px[y * W + x] = v if x >= 0 && y >= 0 && x < W && y < H }
  px
end

def disc(set, cx, cy, r, v)
  (cy - r..cy + r).each { |y| (cx - r..cx + r).each { |x| set.(x, y, v) if (x - cx)**2 + (y - cy)**2 <= r * r } }
end

def box(set, x0, y0, w, h, v)
  (y0...(y0 + h)).each { |y| (x0...(x0 + w)).each { |x| set.(x, y, v) } }
end

# a round face with ears, eyes and a grin: "chunky"
def chunky
  picture do |set|
    disc(set, 50, 30, 18, 120)
    disc(set, 110, 30, 18, 120)
    disc(set, 80, 64, 44, 150)
    disc(set, 64, 54, 7, 20)
    disc(set, 96, 54, 7, 20)
    disc(set, 80, 72, 6, 60)
    box(set, 60, 86, 40, 5, 30)
  end
end

# three wavy strips of bacon on a plate
def bacon
  picture do |set|
    disc(set, 80, 60, 56, 205)
    3.times do |i|
      y0 = 34 + i * 20
      (30..130).each do |x|
        wave = (Math.sin(x / 9.0 + i) * 4).round
        (0...12).each { |dy| set.(x, y0 + wave + dy, dy < 4 || dy > 8 ? 70 : 165) }
      end
    end
  end
end

def write_pgm(name, px)
  FileUtils.mkdir_p(File.join(ROOT, "camera"))
  file = File.join(ROOT, "camera", "#{name}.pgm")
  File.binwrite(file, "P5\n#{W} #{H}\n255\n".b + px.pack("C*"))
  puts file
end

fetch_http if ARGV.include?("--http")
write_pgm("chunky", chunky)
write_pgm("bacon", bacon)
