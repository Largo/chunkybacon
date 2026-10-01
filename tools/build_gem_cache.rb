# Downloads the latest .gem files (plus runtime deps, recursively) for the
# curated gem list into html/gems/cache/ and writes manifest.json so the
# in-browser installer can install them instantly without hitting rubygems.
# Refuses gems with native extensions - the browser can only load pure Ruby.
# Usage: ruby tools/build_gem_cache.rb             # the whole list, latest versions
#        ruby tools/build_gem_cache.rb pure_jpeg   # adds gems (and their deps) to the
#                                                  # cache, leaving the cached ones as they are
require 'json'
require 'net/http'
require 'rubygems/package'
require 'fileutils'

# chunky_bacon: the course's own gem (gem/chunky_bacon), lesson 13's first
GEMS = %w[chunky_bacon chunky_png gammo racc sinatra roda minitest csv benchmark three-rb ruby_pptx lacci nokogiri
          bigdecimal-pure prawn hexapdf jsg pure_jpeg]

# C extensions compiled into the wasm image: a gem may depend on them (hexapdf
# on openssl and strscan, jsg on js), the browser finds them built in
# (BrowserGems NATIVE_GEMS + builtin?), so they are neither downloaded nor cached
BUILTIN = %w[openssl strscan js]

# a dependency on the C extension resolves to the pure stand-in, as in
# BrowserGems::SUBSTITUTES (ttfunk, under prawn, depends on bigdecimal)
SUBSTITUTES = { "bigdecimal" => "bigdecimal-pure" }

# gems pinned below their latest version, when the latest pulls in native
# dependencies (e.g. minitest 6 depends on prism, a C extension)
PINNED = { "minitest" => "5.27.0" }

# gems whose C extension is optional (pure-Ruby fallback in lib/)
ALLOW_EXTENSIONS = %w[racc]

# dependencies not declared in the gemspec but needed at runtime in the
# browser (racc is a default gem locally, absent from the wasm stdlib)
EXTRA_DEPS = { "gammo" => %w[racc] }

# native dependencies a gem declares but falls back from (ruby_pptx uses
# Nokogiri when it loads, REXML otherwise) - left out of the cache and the
# manifest; keep in sync with BrowserGems::OPTIONAL_NATIVE_DEPS
OPTIONAL_NATIVE_DEPS = { "ruby_pptx" => %w[nokogiri], "jsg" => %w[ruby_wasm] }

# gems built from a local checkout instead of downloaded: nokogiri is
# nokogiri-pure's nokogiri.gemspec (named "nokogiri" so that gems depending
# on nokogiri resolve to it). Set NOKOGIRI_PURE to point elsewhere.
# (bigdecimal-pure, the other stand-in, is on rubygems.org under its own
# name; BrowserGems::SUBSTITUTES maps a dependency on bigdecimal to it.)
WORKSPACE = File.expand_path("../../../..", __dir__)
LOCAL_GEMS = {
  "nokogiri" => File.join(ENV.fetch("NOKOGIRI_PURE", "#{WORKSPACE}/nokogiri-pure"), "nokogiri.gemspec")
}

CACHE_DIR = File.expand_path("../html/gems/cache", __dir__)
FileUtils.mkdir_p(CACHE_DIR)

MANIFEST = File.join(CACHE_DIR, "manifest.json")
manifest = ARGV.empty? ? {} : JSON.parse(File.read(MANIFEST))
queue = ARGV.empty? ? GEMS.dup : ARGV.dup

until queue.empty?
  name = queue.shift
  name = SUBSTITUTES.fetch(name, name)
  next if manifest.key?(name) || BUILTIN.include?(name)

  if LOCAL_GEMS.key?(name)
    gemspec = LOCAL_GEMS[name]
    spec = Gem::Specification.load(gemspec) or abort "#{name}: cannot load #{gemspec}"
    file = "#{name}-#{spec.version}.gem"
    Dir.chdir(File.dirname(gemspec)) do
      Gem::Package.build(spec)
      FileUtils.mv(file, File.join(CACHE_DIR, file))
    end
    puts "built #{file} from #{gemspec}"
    deps = spec.runtime_dependencies.map(&:name)
    queue.concat(deps)
    manifest[name] = { "version" => spec.version.to_s, "file" => file, "deps" => deps }
    next
  end

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

  deps = ((info.dig("dependencies", "runtime") || []).map { |d| d["name"] } | EXTRA_DEPS.fetch(name, [])) -
         OPTIONAL_NATIVE_DEPS.fetch(name, [])
  queue.concat(deps)
  manifest[name] = { "version" => version, "file" => file, "deps" => deps }
end

File.write(MANIFEST, JSON.pretty_generate(manifest))
puts "manifest: #{manifest.keys.join(', ')}"
