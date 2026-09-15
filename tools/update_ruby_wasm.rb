# Downloads the latest @ruby/4.0-wasm-wasi npm package and installs its
# browser loader + wasm into html/, patched to fetch the wasm from OUR
# server instead of the hardcoded jsDelivr CDN (the site is self-hosted).
# Usage: ruby tools/update_ruby_wasm.rb
require "json"
require "net/http"
require "fileutils"
require "tmpdir"

PKG = "@ruby/4.0-wasm-wasi"
HTML = File.expand_path("../html", __dir__)

meta = JSON.parse(Net::HTTP.get(URI("https://registry.npmjs.org/#{PKG.sub('/', '%2F')}")))
version = meta["dist-tags"]["latest"]
tarball = meta["versions"][version]["dist"]["tarball"]
puts "#{PKG} #{version}"

dir = File.join(Dir.tmpdir, "rubywasm-update")
FileUtils.rm_rf(dir)
FileUtils.mkdir_p(dir)
tgz = File.join(dir, "pkg.tgz")
File.binwrite(tgz, Net::HTTP.get(URI(tarball)))
system("tar", "xzf", tgz, "-C", dir) or abort "untar failed"

iife = File.read(File.join(dir, "package/dist/browser.script.iife.js"))
cdn_fetch = %r{fetch\(`https://cdn\.jsdelivr\.net/npm/\$\{pkg\.name\}@\$\{pkg\.version\}/dist/ruby\+stdlib\.wasm`\)}
abort "CDN fetch pattern not found - loader layout changed, adjust this script" unless iife =~ cdn_fetch
iife = iife.sub(cdn_fetch, 'fetch("ruby+stdlib.wasm")')

File.write(File.join(HTML, "browser.script.iife.js"), iife)
FileUtils.cp(File.join(dir, "package/dist/ruby+stdlib.wasm"), File.join(HTML, "ruby+stdlib.wasm"))
puts "installed browser.script.iife.js (CDN fetch patched to local) and ruby+stdlib.wasm (#{File.size(File.join(HTML, 'ruby+stdlib.wasm')) / 1024 / 1024} MB)"
puts "NOTE: remove the old ruby-app.wasm if still present"
