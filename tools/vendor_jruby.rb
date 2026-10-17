# Puts JRuby for the browser - JRuby 10.1 compiled to JavaScript by TeaVM
# (github.com/Largo/jruby-teavm) - and the lesson's earthquake data into
# html/assets/jruby/, for the JRuby lesson ("engine": "jruby",
# html/jruby_lab.js, html/jruby_worker.js; docs/HANDOVER.md §6t). About
# 31 MB on disk, not in git (.gitignore), like Spinel's html/assets/spinel/.
#
#   ruby tools/vendor_jruby.rb --from ~/jruby-teavm
#        a jruby-teavm checkout whose dist/ was built from the commit and
#        patch (tools/jruby-teavm-lesson.patch) tools/jruby.json names; its jruby.js and stdlib.zip are
#        also kept in .cache/jruby/ (not in git), for the runs without --from
#   ruby tools/vendor_jruby.rb            the same from .cache/jruby/ (or
#        $CHUNKY_JRUBY_FROM, a folder with jruby.js and stdlib.zip): what
#        tools/after_deploy.sh runs - a no-op while html/assets/jruby/ is current
#   ruby tools/vendor_jruby.rb --check    are the files the pinned ones?
#
# The USGS snapshot the lesson's text quotes is in git (tools/jruby-data/:
# the feed changes every minute, so it could not be fetched again).
# Every file is checked against tools/jruby.json's SHA-256 before it is
# copied, so a different build or another day's data is refused. Then:
# data/quakes.zip (both GeoJSON files and SOURCE.txt, for JRuby's
# mountZip), the .gz copies nginx serves (jruby.js, all_month.geojson;
# gzip_static), JRUBY_VERSION.txt and NOTICE.md.
#
# Never on the 1-core server behind chunkybacon.idogawa.com: the deploy hook
# on the Hetzner box runs this and copies html/assets/jruby/ over.
require "json"
require "digest"
require "fileutils"
require "zlib"

ROOT = File.expand_path("..", __dir__)
PIN = JSON.parse(File.read(File.join(__dir__, "jruby.json")))
TARGET = File.join(ROOT, "html/assets/jruby")
RECORD = File.join(TARGET, "JRUBY_VERSION.txt")
DATA = File.join(__dir__, "jruby-data")
CACHE = File.join(ROOT, ".cache/jruby")
# the source of the lesson build on top of the public base commit, in git
# here and served next to jruby.js (JRuby's GPL/EPL: the source goes along)
PATCH = File.join(ROOT, PIN["jruby"]["patch"]["file"])
PATCH_NAME = File.basename(PATCH)
DERIVED = (%w[data/quakes.zip data/SOURCE.txt jruby.js.gz data/all_month.geojson.gz COPYING.jruby NOTICE.md] +
           [PATCH_NAME]).freeze

def sha256(path) = Digest::SHA256.file(path).hexdigest

def pinned
  PIN["files"].to_a + PIN["data"]["files"].map { |name, digest| ["data/#{name}", digest] }
end

def current?
  pinned.all? { |name, digest| File.file?(File.join(TARGET, name)) && sha256(File.join(TARGET, name)) == digest } &&
    DERIVED.all? { |name| File.file?(File.join(TARGET, name)) } &&
    File.file?(RECORD) && File.read(RECORD).include?("base=#{PIN["jruby"]["base"]}\n") &&
    File.read(RECORD).include?("patch=#{PATCH_NAME} #{PIN["jruby"]["patch"]["sha256"]}\n")
end

if ARGV.include?("--check")
  unless current?
    pinned.each do |name, digest|
      path = File.join(TARGET, name)
      puts "MISSING/CHANGED html/assets/jruby/#{name}" unless File.file?(path) && sha256(path) == digest
    end
    DERIVED.each { |name| puts "MISSING html/assets/jruby/#{name}" unless File.file?(File.join(TARGET, name)) }
    exit 1
  end
  puts "current html/assets/jruby/ (#{pinned.size} pinned files)"
  exit 0
end

from = ARGV[ARGV.index("--from") + 1] if ARGV.include?("--from")
if from.nil? && current?
  puts "current html/assets/jruby/ (#{pinned.size} pinned files)"
  exit 0
end
# where jruby.js and stdlib.zip come from: a build (--from), else the cache
dist = from ? File.join(from, "dist") : (ENV["CHUNKY_JRUBY_FROM"] || CACHE)
copying = [from && File.join(from, "COPYING.jruby"), File.join(dist, "COPYING.jruby")].compact.find { |path| File.file?(path) }

sources = PIN["files"].keys.to_h { |name| [name, File.join(dist, name)] }
          .merge(PIN["data"]["files"].keys.to_h { |name| ["data/#{name}", File.join(DATA, name)] })
sources.each do |name, path|
  unless File.file?(path)
    abort "#{path}: missing - build jruby-teavm (tools/jruby.json: #{PIN["jruby"]["build"]}) and run " \
          "ruby tools/vendor_jruby.rb --from <that checkout> once on this machine"
  end
  digest = sha256(path)
  expected = PIN["files"][name] || PIN["data"]["files"][name.delete_prefix("data/")]
  abort "#{path}: SHA-256 #{digest} is not tools/jruby.json's #{expected}" unless digest == expected
end
abort "COPYING.jruby: missing next to #{dist} (JRuby's license, it ships with jruby.js)" unless copying
unless File.file?(PATCH) && sha256(PATCH) == PIN["jruby"]["patch"]["sha256"]
  abort "#{PATCH}: missing or not tools/jruby.json's patch - the source of jruby.js has to ship with it"
end

# a build given with --from: keep its files for the deploy's runs
if from
  FileUtils.mkdir_p(CACHE)
  PIN["files"].each_key { |name| FileUtils.cp(sources[name], File.join(CACHE, name)) }
  FileUtils.cp(copying, File.join(CACHE, "COPYING.jruby"))
end

FileUtils.mkdir_p(File.join(TARGET, "data"))
sources.each do |name, path|
  FileUtils.cp(path, File.join(TARGET, name))
  puts format("  %-26s %6.2f MB", name, File.size(path) / 1e6)
end
FileUtils.cp(File.join(DATA, "SOURCE.txt"), File.join(TARGET, "data/SOURCE.txt"))
FileUtils.cp(copying, File.join(TARGET, "COPYING.jruby"))
FileUtils.cp(PATCH, File.join(TARGET, PATCH_NAME))

# A zip as java.util.zip reads it (TeaVM JRuby's mountZip): deflated
# entries, no extras, no data descriptors
def write_zip(path, entries)
  out = "".b
  central = "".b
  entries.each do |name, bytes|
    bytes = bytes.b
    deflated = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS).then { |z| z.deflate(bytes, Zlib::FINISH).tap { z.close } }
    crc = Zlib.crc32(bytes)
    offset = out.bytesize
    # version 20, no flags, deflate, a fixed DOS time (2026-10-17 00:00)
    header = [20, 0, 8, 0, ((2026 - 1980) << 9) | (10 << 5) | 17, crc, deflated.bytesize, bytes.bytesize, name.bytesize, 0]
    out << [0x04034b50, *header].pack("VvvvvvVVVvv") << name << deflated
    central << [0x02014b50, 20, *header, 0, 0, 0, 0, offset].pack("VvvvvvvVVVvvvvvVV") << name
  end
  central_at = out.bytesize
  out << central << [0x06054b50, 0, 0, entries.size, entries.size, central.bytesize, central_at, 0].pack("VvvvvVVv")
  File.binwrite(path, out)
end

zip_entries = (PIN["data"]["files"].keys + ["SOURCE.txt"]).map do |name|
  [name, File.binread(File.join(TARGET, "data", name))]
end
write_zip(File.join(TARGET, "data/quakes.zip"), zip_entries)
puts format("  %-26s %6.2f MB", "data/quakes.zip", File.size(File.join(TARGET, "data/quakes.zip")) / 1e6)

%w[jruby.js data/all_month.geojson].each do |name|
  path = File.join(TARGET, name)
  Zlib::GzipWriter.open("#{path}.gz", Zlib::BEST_COMPRESSION) do |gz|
    gz.mtime = File.mtime(path)
    File.open(path, "rb") { |src| IO.copy_stream(src, gz) }
  end
  puts format("  %-26s %6.2f MB", "#{name}.gz", File.size("#{path}.gz") / 1e6)
end

File.write(File.join(TARGET, "NOTICE.md"), <<~MARKDOWN)
  # JRuby for the browser (TeaVM) and the lesson's data

  Written by `tools/vendor_jruby.rb` - rerun it rather than editing these files.
  Licenses: THIRD_PARTY_NOTICES.md ("The JRuby lesson").

  - `jruby.js`, `stdlib.zip`: JRuby 10.1.2.0 (EPL-2.0 / GPL-2.0 / LGPL-2.1, `COPYING.jruby`),
    compiled to JavaScript by TeaVM 0.16.0 (Apache-2.0) from https://github.com/#{PIN["jruby"]["repo"]}
    at commit #{PIN["jruby"]["base"]} plus `#{PATCH_NAME}` (in this folder, and in the course's
    repository as #{PIN["jruby"]["patch"]["file"]}): #{PIN["jruby"]["changes"]}. Inside: jackson-core 2.18.2
    (Apache-2.0), ZXing core 3.5.4 (Apache-2.0), the json gem 2.21.2 (Ruby license / BSD-2-Clause).
    To rebuild: #{PIN["jruby"]["build"]}.
  - `data/`: #{PIN["data"]["license"]}. Source: #{PIN["data"]["source"]}, fetched #{PIN["data"]["fetched"]}.
MARKDOWN
# last: --check and the next run see a complete install only
File.write(RECORD, <<~TEXT)
  repo=#{PIN["jruby"]["repo"]}
  base=#{PIN["jruby"]["base"]}
  patch=#{PATCH_NAME} #{PIN["jruby"]["patch"]["sha256"]}
  data=#{PIN["data"]["source"]} (#{PIN["data"]["fetched"]})
  installed_by=tools/vendor_jruby.rb
  #{pinned.map { |name, digest| "file=#{name} #{File.size(File.join(TARGET, name))} #{digest}" }.join("\n")}
TEXT
puts "wrote   html/assets/jruby/ (#{RECORD.delete_prefix("#{ROOT}/")})"
