# Experiment: what would matplotlib add to html/assets/pyodide/?
#
#   ruby experiments/01-matplotlib-charts/vendor_matplotlib.rb          # sizes only
#   ruby experiments/01-matplotlib-charts/vendor_matplotlib.rb --fetch  # + download
#
# Reads the FULL Pyodide lockfile of the vendored version (jsDelivr), walks
# matplotlib's dependency closure, says which wheels are already vendored
# and what is new, with sizes. With --fetch the new wheels go into
# experiments/01-matplotlib-charts/vendor/ (gitignored), SHA-256-checked like
# tools/vendor_pyodide.rb, plus a pyodide-lock.json = the vendored lockfile
# + the new packages - what the experiment's server (serve.rb) answers
# instead of html/assets/pyodide/pyodide-lock.json.
#
# This is the change tools/vendor_pyodide.rb would need: add "matplotlib" to
# PACKAGES. Nothing here touches html/.
require "json"
require "net/http"
require "uri"
require "digest"
require "fileutils"

HERE = __dir__
SITE_PYODIDE = File.expand_path("../../html/assets/pyodide", HERE)
VENDOR = File.join(HERE, "vendor")
VERSION = JSON.parse(File.read(File.join(SITE_PYODIDE, "package.json")))["version"]
FULL = "https://cdn.jsdelivr.net/pyodide/v#{VERSION}/full"
WANT = (ARGV - ["--fetch"]).then { |names| names.empty? ? %w[matplotlib] : names }

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 300) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-experiment"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

FileUtils.mkdir_p(VENDOR)
full_lock_path = File.join(VENDOR, "pyodide-lock.full.json")
File.binwrite(full_lock_path, get("#{FULL}/pyodide-lock.json")) unless File.exist?(full_lock_path)
full = JSON.parse(File.read(full_lock_path))
site = JSON.parse(File.read(File.join(SITE_PYODIDE, "pyodide-lock.json")))

closure = []
queue = WANT.dup
until queue.empty?
  name = queue.shift
  next if closure.include?(name)

  closure << name
  queue.concat(full.fetch("packages").fetch(name).fetch("depends"))
end

puts "Pyodide #{VERSION}: #{WANT.join(', ')} needs #{closure.size} packages"
new_total = 0
closure.each do |name|
  pkg = full["packages"][name]
  vendored = site["packages"].key?(name)
  path = File.join(VENDOR, pkg["file_name"])
  if !vendored && ARGV.include?("--fetch") && !(File.exist?(path) && Digest::SHA256.file(path).hexdigest == pkg["sha256"])
    body = get("#{FULL}/#{pkg['file_name']}")
    raise "#{name}: SHA-256 mismatch" unless Digest::SHA256.hexdigest(body) == pkg["sha256"]

    File.binwrite(path, body)
  end
  size = File.exist?(path) ? File.size(path) : nil
  size ||= File.size(File.join(SITE_PYODIDE, pkg["file_name"])) if vendored
  new_total += size.to_i unless vendored
  printf("  %-26s %-58s %9s  %s\n", name, pkg["file_name"], size ? "#{(size / 1024.0).round} KB" : "?",
         vendored ? "already vendored" : "NEW")
end
puts "new download: #{(new_total / 1024.0 / 1024).round(2)} MB" if ARGV.include?("--fetch")

if ARGV.include?("--fetch")
  site["packages"].merge!(full["packages"].slice(*closure))
  File.write(File.join(VENDOR, "pyodide-lock.json"), JSON.generate(site))
  puts "wrote vendor/pyodide-lock.json (#{site['packages'].size} packages)"
end
