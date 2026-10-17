# Puts the jars of the JRuby lesson's bonus - Swing windows from Ruby with
# Glimmer, on JRuby 9.4 inside CheerpJ (html/jruby_swing.html,
# docs/HANDOVER.md §6t) - into html/assets/jruby-swing/. About 38 MB on
# disk, not in git (.gitignore); a learner's browser fetches only the byte
# ranges it needs (about 20 MB), and only after a click on the bonus.
#
#   ruby tools/vendor_jruby_swing.rb --from ~/jruby-cheerpj
#        a Largo/jruby-cheerpj checkout after ./run.sh prepare: its two
#        built jars (tools/jruby_swing.json "built") are also kept in
#        .cache/jruby-swing/ (not in git), for the runs without --from
#   ruby tools/vendor_jruby_swing.rb      the same from .cache/jruby-swing/
#        (or $CHUNKY_JRUBY_CHEERPJ, a jruby-cheerpj checkout): what
#        tools/after_deploy.sh runs - a no-op while the jars are current
#   ruby tools/vendor_jruby_swing.rb --check
#
# The Maven Central jars (JRuby, FlatLaf, JFreeChart) are downloaded when
# neither place has them. Every jar is checked against tools/jruby_swing.json's
# SHA-256 before it is copied. nginx serves them as they are - no gzip,
# with Range requests (nginx/default.conf).
#
# Never on the 1-core server behind chunkybacon.idogawa.com: the deploy hook
# on the Hetzner box runs this and copies html/assets/jruby-swing/ over.
require "json"
require "digest"
require "fileutils"
require "net/http"
require "uri"

ROOT = File.expand_path("..", __dir__)
PIN = JSON.parse(File.read(File.join(__dir__, "jruby_swing.json")))
TARGET = File.join(ROOT, "html/assets/jruby-swing")
CACHE = File.join(ROOT, ".cache/jruby-swing")
RECORD = File.join(TARGET, "VERSION.txt")
MAVEN = "https://repo1.maven.org/maven2/"

def sha256(path) = Digest::SHA256.file(path).hexdigest

PINNED = PIN["maven"].transform_values { |m| m["sha256"] }
                     .merge(PIN["built"]["files"].transform_values { |m| m["sha256"] })

def good?(path, name) = File.file?(path) && sha256(path) == PINNED.fetch(name)
def current? = PINNED.keys.all? { |name| good?(File.join(TARGET, name), name) } && File.file?(RECORD)

if ARGV.include?("--check")
  PINNED.each_key { |name| puts "MISSING/CHANGED html/assets/jruby-swing/#{name}" unless good?(File.join(TARGET, name), name) }
  puts "current html/assets/jruby-swing/ (#{PINNED.size} jars)" if current?
  exit(current? ? 0 : 1)
end

from = ARGV[ARGV.index("--from") + 1] if ARGV.include?("--from")
if from.nil? && current?
  puts "current html/assets/jruby-swing/ (#{PINNED.size} jars)"
  exit 0
end
checkout = from || ENV["CHUNKY_JRUBY_CHEERPJ"]

def download(url, path)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 120) do |http|
    http.request(Net::HTTP::Get.new(uri)) do |response|
      abort "#{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      File.open(path, "wb") { |f| response.read_body { |chunk| f.write(chunk) } }
    end
  end
end

FileUtils.mkdir_p(CACHE)
FileUtils.mkdir_p(TARGET)
PINNED.each_key do |name|
  target = File.join(TARGET, name)
  cached = File.join(CACHE, name)
  candidates = [target, cached, checkout && File.join(checkout, "jars", name)].compact
  found = candidates.find { |path| good?(path, name) }
  if found.nil? && PIN["maven"][name]
    url = MAVEN + PIN["maven"][name]["path"]
    puts "  download #{url}"
    download(url, "#{cached}.part")
    abort "#{url}: SHA-256 #{sha256("#{cached}.part")} is not tools/jruby_swing.json's #{PINNED[name]}" unless good?("#{cached}.part", name)
    File.rename("#{cached}.part", cached)
    found = cached
  end
  unless found
    abort "#{name}: not found (or another build) - run ./run.sh prepare in a #{PIN["built"]["repo"]} checkout " \
          "(#{PIN["built"]["commit"]}) and ruby tools/vendor_jruby_swing.rb --from <that checkout> once on this machine"
  end
  FileUtils.cp(found, cached) unless found == cached
  FileUtils.cp(found, "#{target}.part") unless found == target
  File.rename("#{target}.part", target) unless found == target
  puts format("  %-30s %6.2f MB", name, File.size(target) / 1e6)
end
File.write(RECORD, <<~TEXT)
  installed_by=tools/vendor_jruby_swing.rb
  built_from=#{PIN["built"]["repo"]} #{PIN["built"]["commit"]}
  #{PINNED.map { |name, digest| "file=#{name} #{File.size(File.join(TARGET, name))} #{digest}" }.join("\n")}
TEXT
puts "wrote   html/assets/jruby-swing/ (#{RECORD.delete_prefix("#{ROOT}/")})"
