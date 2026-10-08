# Writes the pre-compressed copies nginx serves with gzip_static (nginx/default.conf):
# <file>.gz next to each large file that only changes through a tool.
# Everything else - lessons.js, main.rb, the CSS - nginx gzips on the fly,
# so an edit can never be shadowed by a stale .gz.
#
#   ruby tools/compress_assets.rb           # (re)write every .gz that is missing or stale
#   ruby tools/compress_assets.rb --check   # exit 1 if a .gz is missing or stale
#
# tools/update_ruby_wasm.rb runs this after installing a new wasm.
require "zlib"
require "digest"

HTML = File.expand_path("../html", __dir__)
# The PicoRuby runtime (the page shell) arrives with its .gz files from the
# npm package's bundle (level 6); they count as current as long as they
# unpack to the file next to them, so they are kept as they are.
FILES = %w[ruby+stdlib.wasm assets/picoruby/picoruby.wasm assets/picoruby/picoruby.js
           assets/pyodide/pyodide.asm.wasm assets/pyodide/pyodide.asm.mjs assets/sqljs/sql-wasm.wasm
           assets/herb/herb-browser.esm.js].freeze

# A .gz is current when it unpacks to exactly the file next to it.
def current?(path, gz)
  File.exist?(gz) && Digest::SHA256.digest(Zlib::GzipReader.open(gz, &:read)) == Digest::SHA256.file(path).digest
rescue Zlib::Error
  false
end

def compress(path, gz)
  Zlib::GzipWriter.open("#{gz}.tmp", Zlib::BEST_COMPRESSION) do |out|
    out.mtime = File.mtime(path)
    File.open(path, "rb") { |src| IO.copy_stream(src, out) }
  end
  File.rename("#{gz}.tmp", gz)
end

check = ARGV.include?("--check")
stale = FILES.reject do |name|
  path = File.join(HTML, name)
  gz = "#{path}.gz"
  ok = current?(path, gz)
  if !ok && !check
    compress(path, gz)
    ok = true
    print "wrote   "
  else
    print ok ? "current " : "STALE   "
  end
  puts format("html/%-24s %6.1f MB -> %5.1f MB", "#{name}.gz", File.size(path) / 1e6, File.exist?(gz) ? File.size(gz) / 1e6 : 0)
  ok
end
exit(stale.empty? ? 0 : 1)
