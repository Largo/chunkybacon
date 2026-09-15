# Offline harness for BrowserGems: installs the cached gems through the
# exact code the browser runs (fetch lambdas backed by File.read) and
# exercises them: chunky_png draws a PNG, gammo parses HTML with CSS
# selectors. Also verifies the native-gem guard and unknown-gem error.
require_relative "../html/browser_gems"

CACHE = File.expand_path("../html/gems/cache", __dir__)

BrowserGems.cache_base = "cache"
BrowserGems.proxy_base = "remote"
BrowserGems.fetch_binary = lambda do |url|
  path = url.sub("cache/", "#{CACHE}/")
  File.exist?(path) ? File.binread(path) : nil
end
BrowserGems.fetch_text = lambda do |url|
  path = url.sub("cache/", "#{CACHE}/")
  File.exist?(path) ? File.read(path) : nil
end

failures = 0
check = lambda do |name, cond|
  puts "#{cond ? 'PASS' : 'FAIL'} #{name}"
  failures += 1 unless cond
end

check.call "manifest lists cached gems", BrowserGems.manifest.keys.sort == %w[chunky_png gammo racc]

version = BrowserGems.install("chunky_png")
check.call "chunky_png installs from cache", version == BrowserGems.manifest["chunky_png"]["version"]

require "chunky_png"
image = ChunkyPNG::Image.new(8, 8, ChunkyPNG::Color::TRANSPARENT)
8.times { |i| image[i, i] = ChunkyPNG::Color.rgb(232, 114, 42) }
png = image.to_blob
check.call "chunky_png draws a real PNG", png.start_with?("\x89PNG".b)
check.call "chunky_png data url works", image.to_data_url.start_with?("data:image/png;base64,")

BrowserGems.install("gammo")
require "gammo"
require "gammo/css_selector"
html = '<html><body><h1>Menu</h1><a href="/speck">Speck</a><a href="/ei">Ei</a></body></html>'
doc = Gammo.new(html).parse
texts = doc.css("a").map(&:inner_text)
check.call "gammo parses and css-selects", texts == %w[Speck Ei]
check.call "gammo reads attributes", doc.css("a").first.attributes.to_h["href"] == "/speck"

begin
  BrowserGems.install("nokogiri")
  check.call "nokogiri raises NativeGemError", false
rescue BrowserGems::NativeGemError
  check.call "nokogiri raises NativeGemError", true
end

begin
  BrowserGems.install("definitely-not-a-gem-#{rand(1000)}")
  check.call "unknown gem raises NotFoundError", false
rescue BrowserGems::NotFoundError
  check.call "unknown gem raises NotFoundError", true
end

check.call "second install is a no-op returning version",
           BrowserGems.install("chunky_png") == version

puts failures.zero? ? "ALL GEM CHECKS OK" : "#{failures} failures"
exit(failures.zero? ? 0 : 1)
