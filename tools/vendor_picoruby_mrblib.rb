# Puts PicoRuby's own Ruby for the peripherals into html/pico_sim/vendor/:
# the mrblib/*.rb of picoruby-gpio, -pwm, -adc, -i2c, -spi, -cyw43,
# -net-http and -pio (its assembler is pure Ruby), unchanged, at the tag
# of the PicoRuby.wasm the course runs (html/assets/picoruby/
# PICORUBY_VERSION.txt). The Pico simulator
# (docs/HANDOVER.md §6r) runs them on top of html/pico_sim/prims.rb, its
# Ruby version of their C primitives - so GPIO's flag checks, I2C#scan's
# output and Net::HTTP's reading of a response are PicoRuby's.
#
#   ruby tools/vendor_picoruby_mrblib.rb           # fetch the files again (same bytes)
#   ruby tools/vendor_picoruby_mrblib.rb --from DIR  # from a checkout of picoruby at that tag
#   ruby tools/vendor_picoruby_mrblib.rb --check   # offline: are the files the ones
#                                                  # VENDOR.txt records, for the wasm's version?
#
# After a new PicoRuby.wasm (tools/vendor_picoruby.rb): run this, read the
# diff of the vendored files and of the gems' src/mruby/*.c (prims.rb copies
# their behaviour), then ruby test/pico_sim_test.rb and node
# test/pico_wasm_test.mjs.
require "net/http"
require "uri"
require "digest"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
TARGET = File.join(ROOT, "html/pico_sim/vendor")
RECORD = File.join(TARGET, "VENDOR.txt")
WASM_RECORD = File.join(ROOT, "html/assets/picoruby/PICORUBY_VERSION.txt")
SOURCE = "https://raw.githubusercontent.com/picoruby/picoruby/%<tag>s/mrbgems/%<gem>s/mrblib/%<file>s"

# [gem, file in mrblib/, where it goes under vendor/]
FILES = [
  %w[picoruby-gpio gpio.rb gpio.rb],
  %w[picoruby-pwm pwm.rb pwm.rb],
  %w[picoruby-adc adc.rb adc.rb],
  %w[picoruby-i2c i2c.rb i2c.rb],
  %w[picoruby-spi spi.rb spi.rb],
  %w[picoruby-cyw43 cyw43.rb cyw43.rb],
  %w[picoruby-net-http http_request.rb net-http/http_request.rb],
  %w[picoruby-net-http http_response.rb net-http/http_response.rb],
  %w[picoruby-net-http http_client.rb net-http/http_client.rb],
  %w[picoruby-pio pio.rb pio.rb],
  %w[picoruby-pio pio_state_machine.rb pio_state_machine.rb]
].freeze

def wasm_version
  File.read(WASM_RECORD)[/^version=(.+)$/, 1] or abort "#{WASM_RECORD}: no version="
end

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def check
  record = File.exist?(RECORD) ? File.read(RECORD) : abort("#{RECORD} is missing: run tools/vendor_picoruby_mrblib.rb")
  tag = record[/^tag=(.+)$/, 1]
  problems = []
  problems << "vendored from #{tag}, but the wasm is #{wasm_version} (run tools/vendor_picoruby_mrblib.rb)" if tag != wasm_version
  FILES.each do |_gem, _file, target|
    line = record[/^file=#{Regexp.escape(target)} (\d+) (\h+)$/]
    path = File.join(TARGET, target)
    if line.nil?
      problems << "#{target}: not in VENDOR.txt"
    elsif !File.exist?(path)
      problems << "#{target}: missing"
    elsif Digest::SHA256.file(path).hexdigest != Regexp.last_match(2)
      problems << "#{target}: changed since it was vendored"
    end
  end
  if problems.empty?
    puts "html/pico_sim/vendor: PicoRuby #{tag}'s mrblib, #{FILES.size} files as recorded"
  else
    puts problems
    exit 1
  end
end

def vendor(from)
  tag = wasm_version
  FileUtils.mkdir_p(File.join(TARGET, "net-http"))
  lines = ["source=#{format(SOURCE, tag: tag, gem: '<gem>', file: '<file>')}", "tag=#{tag}",
           "license=MIT, (c) HASUMI Hitoshi and the PicoRuby contributors (see THIRD_PARTY_NOTICES.md)",
           "installed_by=tools/vendor_picoruby_mrblib.rb (unchanged copies; prims.rb is their C side)"]
  FILES.each do |gem, file, target|
    body = if from
      File.binread(File.join(from, "mrbgems", gem, "mrblib", file))
    else
      get(format(SOURCE, tag: tag, gem: gem, file: file))
    end
    File.binwrite(File.join(TARGET, target), body)
    lines << "file=#{target} #{body.bytesize} #{Digest::SHA256.hexdigest(body)}"
    puts "#{target} (#{gem}, #{body.bytesize} bytes)"
  end
  File.write(RECORD, lines.join("\n") + "\n")
end

if ARGV.first == "--check"
  check
else
  from = ARGV[0] == "--from" ? ARGV[1] : nil
  vendor(from)
end
