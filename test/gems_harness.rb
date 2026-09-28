# Offline harness for BrowserGems: installs the cached gems through the
# exact code the browser runs (fetch lambdas backed by File.read) and
# exercises them: chunky_png draws a PNG, gammo parses HTML with CSS
# selectors. Also verifies the native-gem guard and unknown-gem error.
require_relative "../html/browser_gems"
require "tmpdir"

# gem code "lives" under this root; in the browser it is /browser_gems in
# wasm memory, here a temp dir, so gem assets never touch the real root
BrowserGems.root = Dir.mktmpdir("browser_gems")
at_exit { FileUtils.rm_rf(BrowserGems.root) }

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

check.call "manifest lists cached gems",
           (%w[chunky_png gammo racc sinatra roda rack three-rb] - BrowserGems.manifest.keys).empty?

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

# three-rb: the gem is named three-rb but required as "three" - the deep
# require_relative chain inside it is what the gem-space loader has to get
# right. The scene graph itself is pure Ruby and works without a canvas.
BrowserGems.install("three-rb")
require "three"
scene = Three::Scene.new
scene.add(Three::Mesh.new(Three::BoxGeometry.new(1, 1, 1),
                          Three::MeshBasicMaterial.new(color: 0xe8722a)))
check.call "three-rb installs as three-rb and loads as three",
           BrowserGems.installed.key?("three-rb") && defined?(Three::VERSION)
check.call "three-rb builds a scene graph", scene.children.length == 1
check.call "gammo reads attributes", doc.css("a").first.attributes.to_h["href"] == "/speck"

# --- web frameworks through the exact browser code path ---
require_relative "../html/rack_playground"

BrowserGems.install("sinatra")
require "sinatra/base"
class HarnessSinatra < Sinatra::Base
  get "/" do
    "<h1>Imbiss</h1>"
  end
  get "/hallo/:name" do
    "Hallo, #{params[:name]}!"
  end
end
status, body = mock_get(HarnessSinatra, "/")
check.call "sinatra root route", status == 200 && body.include?("Imbiss")
status, body = mock_get(HarnessSinatra, "/hallo/Kaz")
check.call "sinatra param route", status == 200 && body == "Hallo, Kaz!"
status, _ = mock_get(HarnessSinatra, "/nope")
check.call "sinatra 404", status == 404

BrowserGems.install("roda")
require "roda"
class HarnessRoda < Roda
  route do |r|
    r.root { "<h1>Laden</h1>" }
    r.get "speck" do
      "3 Streifen"
    end
    r.get "gruss", String do |name|
      "Hallo, #{name}!"
    end
  end
end
status, body = mock_get(HarnessRoda, "/")
check.call "roda root route", status == 200 && body.include?("Laden")
status, body = mock_get(HarnessRoda, "/gruss/Chunky")
check.call "roda string matcher", status == 200 && body == "Hallo, Chunky!"
status, _ = mock_get(HarnessRoda, "/pizza")
check.call "roda 404", status == 404

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

# --- ruby_pptx: an optional native dependency, and non-Ruby lib files ---
# ruby_pptx declares nokogiri but falls back to REXML without it, and reads
# its templates (default.pptx and friends) relative to __dir__.
begin
  BrowserGems.install("ruby_pptx")
  check.call "ruby_pptx installs without its optional nokogiri",
             BrowserGems.installed.key?("ruby_pptx") && !BrowserGems.installed.key?("nokogiri")
  check.call "ruby_pptx brings its pure-Ruby dependencies",
             %w[rubyzip rexml].all? { |dep| BrowserGems.installed.key?(dep) }
  template = File.join(BrowserGems.root, "ruby_pptx", "ruby_pptx", "templates", "default.pptx")
  check.call "ruby_pptx's templates are written where its code looks for them",
             File.file?(template) && File.binread(template, 2) == "PK"

  # the same gem through the rubygems.org path, whose metadata does list
  # nokogiri: it must be skipped there too, not refused
  entry = BrowserGems.manifest.delete("ruby_pptx")
  BrowserGems.installed.delete("ruby_pptx")
  fetch_text, fetch_binary = BrowserGems.fetch_text, BrowserGems.fetch_binary
  BrowserGems.fetch_text = lambda do |url|
    next fetch_text.call(url) unless url == "remote/api/v1/gems/ruby_pptx.json"
    { "version" => entry["version"],
      "dependencies" => { "runtime" => %w[nokogiri rexml rubyzip].map { |n| { "name" => n } } } }.to_json
  end
  BrowserGems.fetch_binary = lambda do |url|
    url == "remote/gems/#{entry["file"]}" ? fetch_binary.call("cache/#{entry["file"]}") : fetch_binary.call(url)
  end
  begin
    check.call "ruby_pptx from rubygems.org skips nokogiri too",
               BrowserGems.install("ruby_pptx") == entry["version"] && !BrowserGems.installed.key?("nokogiri")
  rescue BrowserGems::NativeGemError
    check.call "ruby_pptx from rubygems.org skips nokogiri too", false
  ensure
    BrowserGems.fetch_text, BrowserGems.fetch_binary = fetch_text, fetch_binary
    BrowserGems.manifest["ruby_pptx"] = entry
  end
end

check.call "second install is a no-op returning version",
           BrowserGems.install("chunky_png") == version

puts failures.zero? ? "ALL GEM CHECKS OK" : "#{failures} failures"
exit(failures.zero? ? 0 : 1)
