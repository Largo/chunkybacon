# Puts the Ruby half of the ruby2d gem into html/assets/ruby2d/, so the page
# can run ruby2d programs unchanged: the gem is Ruby (window, events, shapes,
# colours, text) around a C extension on SDL3, which a browser cannot load.
# html/ruby2d.rb is that extension written in Ruby - each draw call becomes a
# command game.js paints on a canvas - plus what the page changes (show does
# not block, the page runs the frames).
#
#   ruby tools/vendor_ruby2d.rb
#
# The .gem comes from rubygems.org and is checked against the SHA-256
# rubygems.org lists for that version before anything is unpacked. The files
# in LIB_FILES are joined, in the order the gem's own ruby2d/core.rb requires
# them, into one file (one fetch on the first require "ruby2d"), unchanged; the
# licence goes next to it. What is left out (sprites, tilesets, the pixel
# canvas, bitmap text, buttons, the CLI) is stood in for in html/ruby2d.rb.
# Afterwards: ruby tools/offline_files.rb.
require "json"
require "net/http"
require "uri"
require "digest"
require "fileutils"
require "zlib"
require "stringio"
require "rubygems/package"

VERSION = "1.0.0"
TARGET = File.expand_path("../html/assets/ruby2d", __dir__)
LIB_FILES = %w[
  exceptions warnings
  window/class_methods window/key_events window/mouse_events window/gamepad_events window/object_events
  gamepad window interactive renderable color audio
  circle ellipse font image line polygon polyline quad rectangle square text triangle vertices
  dsl
].freeze

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

versions = JSON.parse(get("https://rubygems.org/api/v1/versions/ruby2d.json"))
entry = versions.find { |v| v["number"] == VERSION && v["platform"] == "ruby" } or raise "ruby2d #{VERSION} not on rubygems.org"
print "ruby2d #{VERSION} ... "
gem = get("https://rubygems.org/gems/ruby2d-#{VERSION}.gem")
actual = Digest::SHA256.hexdigest(gem)
raise "SHA-256 #{actual} is not rubygems.org's #{entry["sha"]}" unless actual == entry["sha"]

puts "#{gem.bytesize / 1024} KB, SHA-256 ok"

# a .gem is a tar of metadata.gz and data.tar.gz
files = {}
Gem::Package::TarReader.new(StringIO.new(gem)) do |outer|
  outer.each do |member|
    next unless member.full_name == "data.tar.gz"

    Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(member.read))) do |inner|
      inner.each { |file| files[file.full_name] = file.read if file.file? }
    end
  end
end

FileUtils.mkdir_p(TARGET)
out = +<<~HEAD
  # ruby2d #{VERSION} (https://www.ruby2d.com, MIT, LICENSE.md next to this
  # file): the gem's Ruby files, unchanged, in the order its ruby2d/core.rb
  # requires them. Written by tools/vendor_ruby2d.rb - do not edit; the
  # page's changes are in html/ruby2d.rb, which loads after this.
HEAD
LIB_FILES.each do |name|
  source = files.fetch("lib/ruby2d/#{name}.rb") { raise "lib/ruby2d/#{name}.rb is not in the gem" }
  out << "\n# ---------- lib/ruby2d/#{name}.rb ----------\n\n" << source
  out << "\n" unless source.end_with?("\n")
end
File.write(File.join(TARGET, "ruby2d.rb"), out)
File.write(File.join(TARGET, "LICENSE.md"), files.fetch("LICENSE.md"))
puts "  ruby2d.rb (#{out.bytesize / 1024} KB, #{LIB_FILES.length} files), LICENSE.md"
