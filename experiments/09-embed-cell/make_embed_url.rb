# The address of an embedded Chunky Bacon cell for a piece of Ruby code -
# for an <iframe> in a blog post or a slide, or a "Run it" link in a README
# (GitHub drops iframes, a link opens the cell as a page of its own).
#
#   ruby make_embed_url.rb example.rb [--gems chunky_png] [--lang en]
#        [--load visible|click|eager] [--base https://chunkybacon.idogawa.com/]
#
# Prints the address, an <iframe> and a Markdown link. The code is
# deflate-raw (zlib window bits -15, as the browser's CompressionStream
# "deflate-raw") and base64url without padding - the same as embed.js.
require "zlib"
require "base64"
require "uri"
require "optparse"

options = { base: "https://chunkybacon.idogawa.com/" }
OptionParser.new do |o|
  o.banner = "usage: ruby make_embed_url.rb FILE [options]   (FILE - for stdin)"
  o.on("--gems LIST") { |v| options[:gems] = v }
  o.on("--lang LANG") { |v| options[:lang] = v }
  o.on("--load WHEN") { |v| options[:load] = v }
  o.on("--run") { options[:run] = "1" }
  o.on("--base URL") { |v| options[:base] = v.end_with?("/") ? v : "#{v}/" }
end.parse!

source = ARGV.first.nil? || ARGV.first == "-" ? $stdin.read : File.read(ARGV.first, encoding: "UTF-8")
code = source.encode("UTF-8").gsub("\r\n", "\n").chomp

def deflate_raw(text)
  z = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS)
  out = z.deflate(text, Zlib::FINISH)
  z.close
  out
end

fragment = [["code", Base64.urlsafe_encode64(deflate_raw(code), padding: false)]]
%i[gems lang load run].each { |key| fragment << [key.to_s, options[key]] if options[key] }
url = "#{options[:base]}embed.html##{URI.encode_www_form(fragment)}"
height = (code.lines.count * 23.25 + 60).round

puts url
puts
puts %(<iframe src="#{url}" title="Ruby code you can run" loading="lazy" ) +
     %(sandbox="allow-scripts allow-popups allow-popups-to-escape-sandbox allow-downloads" ) +
     %(style="width:100%;border:0;height:#{height}px"></iframe>)
puts
puts "[▶ Run this in Chunky Bacon](#{url})"
warn "#{code.bytesize} bytes of code -> #{url.bytesize} bytes of address"
