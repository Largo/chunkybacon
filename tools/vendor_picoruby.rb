# Puts PicoRuby.wasm - the npm package @picoruby/wasm-wasi - into
# html/assets/picoruby/. One runtime, two uses: the page's shell runs on it
# (html/shell/, docs/PICORUBY_SHELL.md), and the PicoRuby lesson runs its
# cells and IRBs on a second instance of it in a Web Worker
# (html/picoruby_worker.js, docs/HANDOVER.md §6m). Nothing else is
# downloaded for that lesson.
#
#   ruby tools/vendor_picoruby.rb            # the pinned VERSION, again (same bytes)
#   ruby tools/vendor_picoruby.rb 4.0.5      # another version
#   ruby tools/vendor_picoruby.rb latest     # npm's latest
#   ruby tools/vendor_picoruby.rb --check    # offline: are the files the ones
#                                            # PICORUBY_VERSION.txt records?
#
# The tarball is checked against the registry's SHA-512 integrity before
# anything is unpacked. Then: the loader is patched to text/picoruby
# (tools/patch_picoruby_loader.rb), the .gz copies nginx serves are written
# (tools/compress_assets.rb), and PICORUBY_VERSION.txt and NOTICE.md record
# what is there, with each file's SHA-256 - which is what --check compares.
# After a new version: bump VERSION below, run the shell's and the lesson's
# tests (test/shell/run.rb, node test/browser_test.mjs, node
# test/picoruby_test.mjs) and update THIRD_PARTY_NOTICES.md.
require "json"
require "net/http"
require "uri"
require "digest"
require "base64"
require "fileutils"
require "tmpdir"
require "rbconfig"

PACKAGE = "@picoruby/wasm-wasi"
VERSION = "4.0.3"
FILES = %w[init.iife.js picoruby.js picoruby.wasm].freeze
TARGET = File.expand_path("../html/assets/picoruby", __dir__)
RECORD = File.join(TARGET, "PICORUBY_VERSION.txt")

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def sha256(name) = Digest::SHA256.file(File.join(TARGET, name)).hexdigest

# --check: the recorded files, byte for byte (no network)
if ARGV.include?("--check")
  abort "no #{RECORD} - run ruby tools/vendor_picoruby.rb" unless File.file?(RECORD)
  recorded = File.read(RECORD).scan(/^file=(\S+) (\d+) (\h{64})$/)
  abort "#{RECORD} lists no files" if recorded.empty?
  bad = recorded.reject do |name, bytes, digest|
    path = File.join(TARGET, name)
    File.file?(path) && File.size(path) == bytes.to_i && sha256(name) == digest
  end
  bad.each { |name, *| puts "CHANGED html/assets/picoruby/#{name}" }
  version = File.read(RECORD)[/^version=(.+)$/, 1]
  puts "current html/assets/picoruby/ (#{PACKAGE} #{version}, #{recorded.size} files)" if bad.empty?
  exit(bad.empty? ? 0 : 1)
end

wanted = ARGV.first || VERSION
escaped = PACKAGE.sub("/", "%2F")
meta = JSON.parse(get("https://registry.npmjs.org/#{escaped}"))
version = wanted == "latest" ? meta.dig("dist-tags", "latest") : wanted
dist = meta.dig("versions", version, "dist") or abort "#{PACKAGE} has no version #{version}"
algorithm, expected = dist["integrity"].split("-", 2)
abort "unexpected integrity algorithm #{algorithm}" unless algorithm == "sha512"

print "#{PACKAGE} #{version} ... "
tarball = get(dist["tarball"])
actual = Base64.strict_encode64(Digest::SHA512.digest(tarball))
abort "SHA-512 #{actual} is not the registry's #{expected}" unless actual == expected
puts "#{tarball.bytesize / 1024} KB, SHA-512 ok"

FileUtils.mkdir_p(TARGET)
Dir.mktmpdir do |tmp|
  File.binwrite(File.join(tmp, "picoruby.tgz"), tarball)
  # relative paths: GNU tar (Git for Windows) takes "C:..." for a remote host
  system("tar", "-xzf", "picoruby.tgz", *FILES.map { |f| "package/dist/#{f}" }, chdir: tmp, exception: true)
  FILES.each do |name|
    FileUtils.cp(File.join(tmp, "package/dist", name), File.join(TARGET, name))
    puts "  #{name} (#{File.size(File.join(TARGET, name)) / 1024} KB)"
  end
end

# the shell's script tags are text/picoruby, so CRuby's main.rb is left alone
system(RbConfig.ruby, File.join(__dir__, "patch_picoruby_loader.rb"), exception: true)
# nginx serves picoruby.js and picoruby.wasm from the .gz next to them
system(RbConfig.ruby, File.join(__dir__, "compress_assets.rb"), exception: true)

files = FILES.map { |name| [name, File.size(File.join(TARGET, name)), sha256(name)] }
# LF even from a Windows checkout (whose copy of this file may have CRLF):
# html/assets/picoruby/ is -text in .gitattributes, committed byte for byte
def write_lf(path, text) = File.binwrite(path, text.delete("\r"))

write_lf(RECORD, <<~TEXT)
  package=#{PACKAGE}
  version=#{version}
  source=#{dist["tarball"]}
  integrity=#{dist["integrity"]}
  installed_by=tools/vendor_picoruby.rb (init.iife.js patched by tools/patch_picoruby_loader.rb)
  #{files.map { |name, bytes, digest| "file=#{name} #{bytes} #{digest}" }.join("\n")}
TEXT

rows = files.map { |name, bytes, digest| "| `#{name}` | #{bytes} | `#{digest}` |" }
write_lf(File.join(TARGET, "NOTICE.md"), <<~MARKDOWN)
  # PicoRuby.wasm runtime

  Written by `tools/vendor_picoruby.rb` - rerun it rather than editing these files.
  The page's shell runs on this runtime (`html/shell/`, docs/PICORUBY_SHELL.md), and the
  PicoRuby lesson runs a second instance of it in a Web Worker (`html/picoruby_worker.js`).

  | | |
  |---|---|
  | Package | `#{PACKAGE}` #{version} (npm registry) |
  | Source | #{dist["tarball"]} |
  | Tarball integrity | `#{dist["integrity"]}` |
  | Project | https://github.com/picoruby/picoruby |
  | License | MIT, text below |

  Files from `package/dist/` of that tarball; `init.iife.js` is patched to run
  `<script type="text/picoruby">` instead of `text/ruby` (`tools/patch_picoruby_loader.rb`).
  The `.gz` copies next to `picoruby.js` and `picoruby.wasm` are written by
  `tools/compress_assets.rb` (nginx serves them, `gzip_static`).

  | File | Bytes | SHA-256 |
  |---|---|---|
  #{rows.join("\n")}

  ## License

  ```
  Copyright © 2020 HASUMI Hitoshi

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation
  the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the
  Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.
  ```
MARKDOWN
puts "wrote   html/assets/picoruby/PICORUBY_VERSION.txt and NOTICE.md (#{PACKAGE} #{version})"
puts "next: ruby tools/offline_files.rb --check; the tests above; THIRD_PARTY_NOTICES.md" if version != VERSION
