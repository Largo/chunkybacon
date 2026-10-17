# PicoModem's own device code (test/vendor/picomodem.rb, an unchanged copy
# of picoruby 4.0.3's mrbgems/picoruby-picomodem/mrblib/picomodem.rb) run
# under CRuby on stdin/stdout, with a minimal R2P2 shell around it, so
# test/pico_real_test.mjs can drive html/pico_real.js's Link against it:
#
#   ruby test/pico_real_device.rb ROOT
#
# The shell part copies what shell.rb 455-460 does on Ctrl-B (puts "\n^B",
# writes ACK 0x06, runs one session) and prints "$> " as a prompt (the
# Editor::Line's, editor.rb 187-188); Ctrl-C prints "^C" and the prompt.
# Files go under ROOT ("/lib/x.rb" -> ROOT/lib/x.rb). What CRuby lacks of
# PicoRuby is given here: CRC (picoruby-crc's algorithms), sleep_ms,
# STDIN.raw!/cooked!, an IO whose read_nonblock answers nil when empty.
require "fileutils"

ROOT = File.expand_path(ARGV.fetch(0))
FileUtils.mkdir_p(File.join(ROOT, "lib"))
FileUtils.mkdir_p(File.join(ROOT, "home"))

module CRC
  def self.crc16(data, crc = 0xFFFF)
    data.each_byte do |b|
      crc ^= b << 8
      8.times { crc = crc & 0x8000 != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF }
    end
    crc
  end

  def self.crc32(data, crc = 0)
    c = crc ^ 0xFFFFFFFF
    data.each_byte do |b|
      c ^= b
      8.times { c = c & 1 != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1 }
    end
    c ^ 0xFFFFFFFF
  end
end

def sleep_ms(ms) = sleep(ms / 1000.0)

# PicoRuby's require of its own gems: 'crc' and 'pack' are built in here
module Kernel
  alias_method :require_before_pico, :require
  def require(name) = %w[crc pack].include?(name) ? true : require_before_pico(name)
end

$stdin.binmode
$stdout.binmode
$stdout.sync = true
def STDIN.raw! = nil
def STDIN.cooked! = nil

# stdin as PicoRuby's: read_nonblock(n) is the bytes there or nil
class PicoIn
  def read_nonblock(n)
    data = $stdin.read_nonblock(n, exception: false)
    return nil if data == :wait_readable
    raise EOFError if data.nil?
    data
  end
end

# picomodem.rb names File inside `module PicoModem`: this one keeps the
# device's paths under ROOT (the lookup finds PicoModem::File first)
module PicoModem
  class File
    def self.real(path) = ::File.join(ROOT, path)
    def self.exist?(path) = ::File.exist?(real(path))
    def self.unlink(path) = ::File.unlink(real(path))
    def self.open(path, mode, &block) = ::File.open(real(path), "#{mode}b", &block)
    class Stat
      def initialize(path) = (@stat = ::File::Stat.new(PicoModem::File.real(path)))
      def size = @stat.size
    end
  end
end

load File.expand_path("vendor/picomodem.rb", __dir__)

io = PicoIn.new
print "$> "
loop do
  ready = IO.select([$stdin], nil, nil, 30)
  break unless ready
  c = $stdin.read(1) or break
  case c.ord
  when 2
    puts "\n^B"
    $stdout.write("\x06")
    PicoModem.session(io, $stdout)
    print "$> "
  when 3
    puts "\n^C"
    print "$> "
  when 4
    puts "\n^D"
    print "$> "
  end
end
