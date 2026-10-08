# Puts Herb's parser, compiled to WebAssembly, into html/assets/herb/, so the
# page loads it from its own server (index.html: window.ensureHerb;
# html/herb_bridge.rb hands Herb.parse to it). The herb gem's C extension is
# that parser; the gem's Ruby part comes from the gem cache, pinned to the
# same version (tools/build_gem_cache.rb).
#
#   ruby tools/vendor_herb.rb
#
# From the npm registry, each tarball checked against the registry's
# sha512: @herb-tools/browser (dist/herb-browser.esm.js, the WebAssembly
# inlined) and the three files of @ruby/prism it imports. They import each
# other by package name, which a browser cannot resolve without a bundler,
# so the import lines are pointed at the copies next to it (./prism/) - the
# only change. Nothing is installed or run.
require "json"
require "net/http"
require "uri"
require "digest"
require "base64"
require "fileutils"
require "zlib"
require "stringio"
require "rubygems/package"

HERB = "0.10.3"     # = the herb gem in the cache
PRISM = "1.9.0"     # what @herb-tools/browser 0.10.3 asks for (^1.9.0)
PRISM_FILES = %w[deserialize.js nodes.js visitor.js].freeze
TARGET = File.expand_path("../html/assets/herb", __dir__)

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

# the files of an npm package's tarball, by path (without "package/")
def package(name, version)
  meta = JSON.parse(get("https://registry.npmjs.org/#{name}/#{version}"))
  tarball = get(meta.dig("dist", "tarball"))
  algorithm, digest = meta.dig("dist", "integrity").split("-", 2)
  raise "#{name}: no sha512 integrity" unless algorithm == "sha512"
  raise "#{name}@#{version}: checksum mismatch" unless Digest::SHA512.base64digest(tarball) == digest

  files = {}
  Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tarball))) do |tar|
    tar.each { |entry| files[entry.full_name.delete_prefix("package/")] = entry.read if entry.file? }
  end
  puts "#{name}@#{version}: #{tarball.bytesize / 1024} KB"
  files
end

herb = package("@herb-tools/browser", HERB)
prism = package("@ruby/prism", PRISM)

source = herb.fetch("dist/herb-browser.esm.js").force_encoding("UTF-8")
PRISM_FILES.each do |file|
  from = "'@ruby/prism/src/#{file}'"
  raise "herb-browser.esm.js does not import #{from}" unless source.include?(from)

  source = source.gsub(from, "'./prism/#{file}'")
end
raise "herb-browser.esm.js imports more of @ruby/prism" if source.include?("@ruby/prism/")

source = source.sub(%r{\n//# sourceMappingURL=\S+\s*\z}, "\n")

# The npm packages carry no license file. Herb's is the gem's (the same
# repository and version, from the gem cache); prism's, LICENSE-prism.md,
# is the prism gem's and stays as it is.
gem_file = File.expand_path("../html/gems/cache/herb-#{HERB}.gem", __dir__)
license = nil
Gem::Package::TarReader.new(File.open(gem_file, "rb")) do |outer|
  outer.each do |entry|
    next unless entry.full_name == "data.tar.gz"

    Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(entry.read))) do |inner|
      inner.each { |file| license = file.read if file.full_name == "LICENSE.txt" }
    end
  end
end
raise "no LICENSE.txt in #{gem_file}" unless license

FileUtils.rm_rf([File.join(TARGET, "herb-browser.esm.js"), File.join(TARGET, "prism")])
FileUtils.mkdir_p(File.join(TARGET, "prism"))
File.binwrite(File.join(TARGET, "herb-browser.esm.js"), source)
File.binwrite(File.join(TARGET, "LICENSE-herb.txt"), license)
PRISM_FILES.each { |file| File.binwrite(File.join(TARGET, "prism", file), prism.fetch("src/#{file}")) }
Dir.glob("**/*", base: TARGET).sort.each do |path|
  full = File.join(TARGET, path)
  puts format("  %-28s %7d KB", path, File.size(full) / 1024) if File.file?(full)
end
puts "Afterwards: ruby tools/offline_files.rb, ruby tools/compress_assets.rb"
