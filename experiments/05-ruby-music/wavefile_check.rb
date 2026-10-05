# Does the wavefile gem install under the course's gem installer rules, and
# do our hand-packed WAVs agree with it? Installs wavefile-1.1.2.gem from
# vendor/ through html/browser_gems.rb (the browser's installer, run under
# CRuby like test/check_harness.rb does), then:
#   1. reads every examples/*.wav with WaveFile::Reader
#   2. writes the same samples with WaveFile::Writer and compares the bytes
#   3. times both writers
# Run: ruby experiments/05-ruby-music/wavefile_check.rb
require "json"
require "fileutils"
require "stringio"
require_relative "../../html/browser_gems"
require_relative "music"

HERE = __dir__
VENDOR = File.join(HERE, "vendor")
GEM_ROOT = File.join(HERE, "tmp_gems")   # the wasm filesystem's stand-in
FileUtils.rm_rf(GEM_ROOT)
at_exit { FileUtils.rm_rf(GEM_ROOT) }

File.write(File.join(VENDOR, "manifest.json"),
           JSON.pretty_generate("wavefile" => { "version" => "1.1.2", "file" => "wavefile-1.1.2.gem", "deps" => [] }))
BrowserGems.root = GEM_ROOT
BrowserGems.cache_base = "cache"
BrowserGems.proxy_base = "remote"
BrowserGems.fetch_binary = ->(url) { (p = url.sub("cache/", "#{VENDOR}/")) && File.exist?(p) ? File.binread(p) : nil }
BrowserGems.fetch_text = ->(url) { (p = url.sub("cache/", "#{VENDOR}/")) && File.exist?(p) ? File.read(p) : nil }

puts "install: wavefile #{BrowserGems.install("wavefile")}"
require "wavefile"
puts "loaded from: #{$LOADED_FEATURES.grep(/wavefile\.rb\z/).first.sub(HERE, ".")}"

Dir[File.join(HERE, "examples", "*.wav")].sort.each do |path|
  reader = WaveFile::Reader.new(path)
  ours = Music.wav_info(File.binread(path))
  printf("%-22s %s  %.2f s  (wav_info: %d Hz, %.2f s)\n", File.basename(path),
         (f = reader.native_format; "#{f.channels} ch, #{f.bits_per_sample} bit, #{f.sample_rate} Hz"),
         reader.total_duration.seconds + reader.total_duration.milliseconds / 1000.0, ours[:rate], ours[:seconds])
  reader.close
end

samples = Music.notes("C4 D4 E4 F4 E4 D4 C4*2", length: 0.3)
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

t0 = clock.call
ours = Music.wav(samples)
t1 = clock.call
io = StringIO.new("".b)
WaveFile::Writer.new(io, WaveFile::Format.new(:mono, :pcm_16, Music::RATE)) do |writer|
  writer.write(WaveFile::Buffer.new(samples, WaveFile::Format.new(:mono, :float, Music::RATE)))
end
t2 = clock.call
theirs = io.string

printf("pack:     %6.1f ms, %d bytes\nwavefile: %6.1f ms, %d bytes\n", (t1 - t0) * 1000, ours.bytesize, (t2 - t1) * 1000, theirs.bytesize)
same_header = ours.byteslice(0, 44) == theirs.byteslice(0, 44)
a = ours.byteslice(44..).unpack("s<*")
b = theirs.byteslice(44..).unpack("s<*")
diff = a.zip(b).map { |x, y| (x - y).abs }.max
puts "header identical: #{same_header}; largest sample difference: #{diff} (of 32767)"
exit(ours == theirs ? 0 : 1)   # the claim is byte-identical files: a nonzero status if not
