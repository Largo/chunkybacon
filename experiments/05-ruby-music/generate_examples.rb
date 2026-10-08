# Writes the example sounds into examples/ and prints how long each took
# under CRuby. Run: ruby experiments/05-ruby-music/generate_examples.rb
require_relative "music"
require "fileutils"

include Music
OUT = File.join(__dir__, "examples")
FileUtils.mkdir_p(OUT)

def timed(name)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  samples = yield
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  bytes = wav(samples)
  t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  File.binwrite(File.join(OUT, name), bytes)
  printf("%-22s %5.2f s audio  %6.1f ms samples  %6.1f ms wav()  %7d bytes\n",
         name, samples.size.fdiv(RATE), (t1 - t0) * 1000, (t2 - t1) * 1000, bytes.bytesize)
end

FROG = "C4 D4 E4 F4 E4 D4 C4*2 E4 F4 G4 A4 G4 F4 E4*2"   # Froschgesang / かえるの歌

timed("a440_sine.wav")   { sine(440, 1.0) }
timed("a440_square.wav") { square(440, 1.0) }
timed("a440_saw.wav")    { saw(440, 1.0) }
timed("frog_song.wav")   { notes(FROG, length: 0.3) }
timed("frog_square.wav") { notes(FROG, length: 0.3, wave: :square) }
timed("c_major_chord.wav") { chord("C4 E4 G4 C5", 2.0) }
timed("fanfare.wav")     { notes("C4 E4 G4 C5", length: 0.25) + chord("C4 E4 G4 C5", 1.0) }
timed("beat.wav")        { drums("x.h.s.h.x.x.s.h." * 2) }
timed("frog_with_beat.wav") do
  melody = notes(FROG, length: 0.25, wave: :triangle)
  beat = drums("x.h.s.h." * 8, step: 0.125).map { |s| s * 0.6 }
  mix(melody, beat)
end
