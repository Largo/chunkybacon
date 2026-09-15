# Downloads the latest .gem files (plus runtime deps, recursively) for the
# curated gem list into html/gems/cache/ and writes manifest.json so the
# in-browser installer can install them instantly without hitting rubygems.
# Refuses gems with native extensions - the browser can only load pure Ruby.
# Usage: ruby tools/build_gem_cache.rb
require 'json'
require 'net/http'
require 'rubygems/package'
require 'fileutils'

GEMS = %w[chunky_png gammo racc sinatra roda]

# gems pinned below their latest version, when the latest pulls in native
# dependencies (e.g. minitest 6 depends on prism, a C extension)
PINNED = {}

# gems whose C extension is optional (pure-Ruby fallback in lib/)
ALLOW_EXTENSIONS = %w[racc]

# dependencies not declared in the gemspec but needed at runtime in the
# browser (racc is a default gem locally, absent from the wasm stdlib)
EXTRA_DEPS = { "gammo" => %w[racc] }
CACHE_DIR = File.expand_path("../html/gems/cache", __dir__)
FileUtils.mkdir_p(CACHE_DIR)

manifest = {}
queue = GEMS.dup

until queue.empty?
  name = queue.shift
  next if manifest.key?(name)

  if PINNED.key?(name)
    version = PINNED[name]
    info = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json")))
  else
    info = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/#{name}.json")))
    version = info["version"]
  end
  file = "#{name}-#{version}.gem"
  path = File.join(CACHE_DIR, file)

  unless File.exist?(path)
    print "downloading #{file} ... "
    File.binwrite(path, Net::HTTP.get(URI("https://rubygems.org/gems/#{file}")))
    puts "#{File.size(path) / 1024} KB"
  end

  # verify it is pure Ruby
  spec = Gem::Package.new(path).spec
  unless spec.extensions.empty? || ALLOW_EXTENSIONS.include?(name)
    abort "#{name} has native extensions (#{spec.extensions}) - not browser-installable"
  end

  deps = (info.dig("dependencies", "runtime") || []).map { |d| d["name"] } | EXTRA_DEPS.fetch(name, [])
  queue.concat(deps)
  manifest[name] = { "version" => version, "file" => file, "deps" => deps }
end

File.write(File.join(CACHE_DIR, "manifest.json"), JSON.pretty_generate(manifest))
puts "manifest: #{manifest.keys.join(', ')}"
