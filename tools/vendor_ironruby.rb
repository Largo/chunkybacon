# Puts IronRuby for the browser - IronRuby 4.0 on .NET 10's browser-wasm
# runtime, from the `wasm` branch of github.com/Largo/ironruby - and the
# NuGet packages its lesson loads (QRCoder, Markdig) into html/assets/ironruby/,
# for the IronRuby lesson ("engine": "ironruby", html/ironruby_lab.js,
# html/ironruby_worker.js; docs/HANDOVER.md §6s). About 90 MB on disk with
# the .gz copies (20 MB go over the wire), not in git (.gitignore), like
# Spinel's html/assets/spinel/.
#
#   ruby tools/vendor_ironruby.rb --from ~/ironruby-wasm/wasm/dist
#        a dist/ that wasm/build.sh built from the commit tools/ironruby.json
#        names; its files are also kept in .cache/ironruby/ (not in git), for
#        the runs without --from
#   ruby tools/vendor_ironruby.rb            the same from .cache/ironruby/ (or
#        $CHUNKY_IRONRUBY_FROM, a dist/ folder): what tools/after_deploy.sh
#        runs - a no-op while html/assets/ironruby/ is current
#   ruby tools/vendor_ironruby.rb --check    are the files the pinned ones?
#   ruby tools/vendor_ironruby.rb --pin --from DIR
#        a new build: writes its SHA-256s into tools/ironruby.json (then
#        update "commit" there by hand, and rerun with --from)
#
# Every runtime file is checked against tools/ironruby.json's SHA-256 before
# it is copied, so a different build is refused. The NuGet packages come
# from nuget.org (kept in .cache/ironruby/nuget/), checked against the
# package's pinned SHA-256 before the DLL is taken out of it. Then the .gz
# copies nginx serves (gzip_static; the official nginx image has no
# brotli), IRONRUBY_VERSION.txt, MANIFEST.json (the sizes the worker's
# progress bar counts), NOTICE.md and the license texts (licenses/, from
# tools/ironruby-licenses/, which is in git).
#
# Never on the 1-core server behind chunkybacon.idogawa.com: the deploy hook
# on the Hetzner box runs this and copies html/assets/ironruby/ over.
require "json"
require "digest"
require "fileutils"
require "zlib"
require "open-uri"

ROOT = File.expand_path("..", __dir__)
PIN_FILE = File.join(__dir__, "ironruby.json")
PIN = JSON.parse(File.read(PIN_FILE))
TARGET = File.join(ROOT, "html/assets/ironruby")
RECORD = File.join(TARGET, "IRONRUBY_VERSION.txt")
CACHE = File.join(ROOT, ".cache/ironruby")
LICENSES = File.join(__dir__, "ironruby-licenses")
DERIVED = (%w[MANIFEST.json NOTICE.md] + Dir.children(LICENSES).sort.map { |name| "licenses/#{name}" }).freeze

def sha256(path) = Digest::SHA256.file(path).hexdigest

# name -> SHA-256 of every file the lesson serves (the NuGet DLLs under nuget/)
def pinned
  PIN["files"].merge(PIN["nuget"].to_h { |name, pkg| ["nuget/#{name}.dll", pkg["dll_sha256"]] })
end

# the files that go out compressed: all but the zip (stored entries, but
# 5 MB of mostly text: gzip takes it to 1.3 MB)
def gzipped = pinned.keys

def current?
  pinned.all? { |name, digest| File.file?(File.join(TARGET, name)) && sha256(File.join(TARGET, name)) == digest } &&
    gzipped.all? { |name| File.file?(File.join(TARGET, "#{name}.gz")) } &&
    DERIVED.all? { |name| File.file?(File.join(TARGET, name)) } &&
    File.file?(RECORD) && File.read(RECORD).include?("commit=#{PIN["ironruby"]["commit"]}\n")
end

from = ARGV[ARGV.index("--from") + 1] if ARGV.include?("--from")

if ARGV.include?("--pin")
  abort "--pin needs --from DIR (a wasm/dist folder)" unless from
  files = Dir.chdir(from) do
    (Dir["_framework/*"].reject { |f| f.end_with?(".br", ".gz") } + %w[ironruby.js stdlib.zip]).sort
  end
  PIN["files"] = files.to_h { |name| [name, sha256(File.join(from, name))] }
  File.write(PIN_FILE, "#{JSON.pretty_generate(PIN)}\n")
  puts "pinned #{files.size} files of #{from} in tools/ironruby.json - set \"commit\" there"
  exit 0
end

if ARGV.include?("--check")
  unless current?
    pinned.each do |name, digest|
      path = File.join(TARGET, name)
      puts "MISSING/CHANGED html/assets/ironruby/#{name}" unless File.file?(path) && sha256(path) == digest
    end
    gzipped.each { |name| puts "MISSING html/assets/ironruby/#{name}.gz" unless File.file?(File.join(TARGET, "#{name}.gz")) }
    DERIVED.each { |name| puts "MISSING html/assets/ironruby/#{name}" unless File.file?(File.join(TARGET, name)) }
    exit 1
  end
  puts "current html/assets/ironruby/ (#{pinned.size} pinned files)"
  exit 0
end

if from.nil? && current?
  puts "current html/assets/ironruby/ (#{pinned.size} pinned files)"
  exit 0
end

dist = from || ENV["CHUNKY_IRONRUBY_FROM"] || CACHE
PIN["files"].each do |name, expected|
  path = File.join(dist, name)
  unless File.file?(path)
    abort "#{path}: missing - build IronRuby for wasm (tools/ironruby.json: #{PIN["ironruby"]["build"]}) " \
          "and run ruby tools/vendor_ironruby.rb --from <its wasm/dist> once on this machine"
  end
  digest = sha256(path)
  abort "#{path}: SHA-256 #{digest} is not tools/ironruby.json's #{expected}" unless digest == expected
end

# a build given with --from: keep its files for the deploy's runs
if from
  PIN["files"].each_key do |name|
    FileUtils.mkdir_p(File.dirname(File.join(CACHE, name)))
    FileUtils.cp(File.join(from, name), File.join(CACHE, name))
  end
end

# the NuGet packages: from nuget.org once, then from the cache
def nuget_dll(name, pkg)
  nupkg = File.join(CACHE, "nuget", "#{name.downcase}.#{pkg["version"]}.nupkg")
  unless File.file?(nupkg) && sha256(nupkg) == pkg["nupkg_sha256"]
    url = "https://api.nuget.org/v3-flatcontainer/#{name.downcase}/#{pkg["version"]}/#{name.downcase}.#{pkg["version"]}.nupkg"
    FileUtils.mkdir_p(File.dirname(nupkg))
    File.binwrite(nupkg, URI.open(url, "rb", &:read))
    puts "  fetched #{url}"
  end
  digest = sha256(nupkg)
  abort "#{nupkg}: SHA-256 #{digest} is not tools/ironruby.json's #{pkg["nupkg_sha256"]}" unless digest == pkg["nupkg_sha256"]
  # (a .nupkg is a plain zip: read_zip_entry, no rubyzip needed)
  bytes = read_zip_entry(nupkg, pkg["path"])
  abort "#{nupkg}: no #{pkg["path"]} in it" unless bytes
  digest = Digest::SHA256.hexdigest(bytes)
  abort "#{nupkg}!#{pkg["path"]}: SHA-256 #{digest} is not tools/ironruby.json's #{pkg["dll_sha256"]}" unless digest == pkg["dll_sha256"]
  bytes
end

# one entry of a zip (stored or deflated), by its central directory
def read_zip_entry(path, wanted)
  data = File.binread(path)
  eocd = data.rindex("PK\x05\x06".b) or return nil
  count, _size, offset = data[eocd + 10, 10].unpack("vVV")
  count.times do
    sig = data[offset, 4].unpack1("V")
    nlen, xlen, clen = data[offset + 28, 6].unpack("vvv")
    local = data[offset + 42, 4].unpack1("V")
    method = data[offset + 10, 2].unpack1("v")
    csize = data[offset + 20, 4].unpack1("V")
    return nil unless sig == 0x02014b50

    name = data[offset + 46, nlen]
    if name == wanted
      lnlen, lxlen = data[local + 26, 4].unpack("vv")
      raw = data[local + 30 + lnlen + lxlen, csize]
      return method.zero? ? raw : Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(raw)
    end
    offset += 46 + nlen + xlen + clen
  end
  nil
end

FileUtils.rm_rf(TARGET)
FileUtils.mkdir_p(File.join(TARGET, "_framework"))
FileUtils.mkdir_p(File.join(TARGET, "nuget"))
PIN["files"].each_key { |name| FileUtils.cp(File.join(dist, name), File.join(TARGET, name)) }
PIN["nuget"].each do |name, pkg|
  File.binwrite(File.join(TARGET, "nuget/#{name}.dll"), nuget_dll(name, pkg))
end

FileUtils.cp_r("#{LICENSES}/.", File.join(TARGET, "licenses"))

total = 0
compressed = 0
sizes = {}
gzipped.each do |name|
  path = File.join(TARGET, name)
  Zlib::GzipWriter.open("#{path}.gz", Zlib::BEST_COMPRESSION) do |gz|
    gz.mtime = Time.at(0)
    File.open(path, "rb") { |src| IO.copy_stream(src, gz) }
  end
  sizes[name] = [File.size(path), File.size("#{path}.gz")]
  total += File.size(path)
  compressed += File.size("#{path}.gz")
end
puts format("  %d files, %.1f MB, %.1f MB gzipped", sizes.size, total / 1e6, compressed / 1e6)

# what the worker's progress bar counts: the runtime's files, by the size the
# browser sees after decompressing (PerformanceResourceTiming.decodedBodySize)
File.write(File.join(TARGET, "MANIFEST.json"), "#{JSON.generate(
  "commit" => PIN["ironruby"]["commit"],
  "bytes" => PIN["files"].keys.sum { |name| sizes[name][0] },
  "gzipped" => PIN["files"].keys.sum { |name| sizes[name][1] },
  "files" => PIN["files"].keys.to_h { |name| [name, sizes[name][0]] }
)}\n")

File.write(File.join(TARGET, "NOTICE.md"), <<~MARKDOWN)
  # IronRuby for the browser and the NuGet packages of its lesson

  Written by `tools/vendor_ironruby.rb` - rerun it rather than editing these files.
  Licenses: THIRD_PARTY_NOTICES.md ("The IronRuby lesson"); their texts are in `licenses/`.

  - `ironruby.js`, `stdlib.zip`, `_framework/`: IronRuby #{PIN["ironruby"]["version"]} (Apache-2.0; its
    standard library is Ruby's, Ruby license / BSD-2-Clause) and the Dynamic Language Runtime
    (Apache-2.0) from #{PIN["ironruby"]["repo"]} #{PIN["ironruby"]["commit"]} (branch #{PIN["ironruby"]["branch"]}),
    on the .NET #{PIN["ironruby"]["dotnet"]} runtime for browser-wasm (MIT), with Prism (MIT) compiled to
    WebAssembly and AngleSharp (MIT) behind its Nokogiri.
  #{PIN["nuget"].map { |name, pkg| "- `nuget/#{name}.dll`: #{name} #{pkg["version"]} (#{pkg["license"]}), #{pkg["path"]} of the nuget.org package" }.join("\n")}
MARKDOWN
# last: --check and the next run see a complete install only
File.write(RECORD, <<~TEXT)
  repo=#{PIN["ironruby"]["repo"]}
  commit=#{PIN["ironruby"]["commit"]}
  branch=#{PIN["ironruby"]["branch"]}
  installed_by=tools/vendor_ironruby.rb
  #{pinned.map { |name, digest| "file=#{name} #{File.size(File.join(TARGET, name))} #{digest}" }.join("\n")}
TEXT
puts "wrote   html/assets/ironruby/ (#{RECORD.delete_prefix("#{ROOT}/")})"
