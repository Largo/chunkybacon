# Puts Pyodide - CPython compiled to WebAssembly - and the Python packages the
# PyCall lessons use into html/assets/pyodide/, so the page loads Python from
# its own server (index.html: window.ensurePython; html/pycall.rb).
#
#   ruby tools/vendor_pyodide.rb
#   PYODIDE_MIRROR=https://fastly.jsdelivr.net ruby tools/vendor_pyodide.rb
#
# The core (runtime, standard library, lockfile) comes from the official
# release on GitHub; the packages' wheels from jsDelivr's copy of the full
# distribution, each checked against the SHA-256 in the release's lockfile.
# The lockfile is cut down to the vendored packages, so asking for any other
# package fails with "no known package" instead of a 404 for a missing file.
# Afterwards: ruby tools/compress_assets.rb (the .gz copies nginx serves).
require "json"
require "net/http"
require "uri"
require "digest"
require "fileutils"
require "tmpdir"

VERSION = "314.0.7"
PACKAGES = %w[pandas sympy scikit-learn].freeze   # and what they depend on
CORE_FILES = %w[pyodide.mjs pyodide.asm.mjs pyodide.asm.wasm python_stdlib.zip package.json].freeze
CORE = "https://github.com/pyodide/pyodide/releases/download/#{VERSION}/pyodide-core-#{VERSION}.tar.bz2"
WHEELS = "#{ENV.fetch('PYODIDE_MIRROR', 'https://cdn.jsdelivr.net')}/pyodide/v#{VERSION}/full"
TARGET = File.expand_path("../html/assets/pyodide", __dir__)

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 300) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

FileUtils.mkdir_p(TARGET)
Dir.mktmpdir do |tmp|
  archive = File.join(tmp, "core.tar.bz2")
  print "core #{VERSION} ... "
  File.binwrite(archive, get(CORE))
  # relative paths: GNU tar (Git for Windows) takes "C:..." for a remote host
  system("tar", "-xjf", "core.tar.bz2", chdir: tmp, exception: true)
  CORE_FILES.each { |name| FileUtils.cp(File.join(tmp, "pyodide", name), File.join(TARGET, name)) }
  lock = JSON.parse(File.read(File.join(tmp, "pyodide", "pyodide-lock.json")))
  puts "ok"

  # the packages and their dependencies, from the release's lockfile
  wanted = []
  queue = PACKAGES.dup
  until queue.empty?
    name = queue.shift
    next if wanted.include?(name)

    wanted << name
    queue.concat(lock.fetch("packages").fetch(name).fetch("depends"))
  end

  wanted.each do |name|
    package = lock["packages"][name]
    path = File.join(TARGET, package["file_name"])
    unless File.exist?(path) && Digest::SHA256.file(path).hexdigest == package["sha256"]
      print "#{package['file_name']} ... "
      body = get("#{WHEELS}/#{package['file_name']}")
      digest = Digest::SHA256.hexdigest(body)
      raise "#{package['file_name']}: SHA-256 #{digest} is not the lockfile's #{package['sha256']}" unless digest == package["sha256"]

      File.binwrite(path, body)
      puts "#{body.bytesize / 1024} KB, SHA-256 ok"
    end
  end

  lock["packages"] = lock["packages"].slice(*wanted)
  File.write(File.join(TARGET, "pyodide-lock.json"), JSON.generate(lock))
  # wheels of packages no longer vendored
  keep = wanted.map { |name| lock["packages"][name]["file_name"] }
  (Dir[File.join(TARGET, "*.whl")].map { |f| File.basename(f) } - keep).each { |stale| File.delete(File.join(TARGET, stale)) }
  puts "packages: #{wanted.join(', ')}"
end
