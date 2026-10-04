# Puts sql.js - SQLite compiled to WebAssembly - into html/assets/sqljs/, so
# the page runs SQLite from its own server: html/sqlite3.rb is the sqlite3
# gem's API on top of it (index.html: window.ensureSqlite), which Sequel's
# own SQLite adapter then uses unchanged.
#
#   ruby tools/vendor_sqljs.rb
#
# The package comes from the npm registry and is checked against the
# registry's SHA-512 integrity before anything is unpacked. Only the browser
# build (sql-wasm.js + sql-wasm.wasm) and the licence are kept.
# Afterwards: ruby tools/compress_assets.rb and ruby tools/offline_files.rb.
require "json"
require "net/http"
require "uri"
require "digest"
require "base64"
require "fileutils"
require "tmpdir"

VERSION = "1.14.2"
FILES = { "package/dist/sql-wasm.js" => "sql-wasm.js", "package/dist/sql-wasm.wasm" => "sql-wasm.wasm",
          "package/LICENSE" => "LICENSE" }.freeze
TARGET = File.expand_path("../html/assets/sqljs", __dir__)

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

meta = JSON.parse(get("https://registry.npmjs.org/sql.js/#{VERSION}"))
algorithm, expected = meta.dig("dist", "integrity").split("-", 2)
raise "unexpected integrity algorithm #{algorithm}" unless algorithm == "sha512"

print "sql.js #{VERSION} ... "
tarball = get(meta.dig("dist", "tarball"))
actual = Base64.strict_encode64(Digest::SHA512.digest(tarball))
raise "SHA-512 #{actual} is not the registry's #{expected}" unless actual == expected

puts "#{tarball.bytesize / 1024} KB, SHA-512 ok"

FileUtils.mkdir_p(TARGET)
Dir.mktmpdir do |tmp|
  File.binwrite(File.join(tmp, "sqljs.tgz"), tarball)
  # relative paths: GNU tar (Git for Windows) takes "C:..." for a remote host
  system("tar", "-xzf", "sqljs.tgz", *FILES.keys, chdir: tmp, exception: true)
  FILES.each do |from, to|
    FileUtils.cp(File.join(tmp, from), File.join(TARGET, to))
    puts "  #{to} (#{File.size(File.join(TARGET, to)) / 1024} KB)"
  end
end
