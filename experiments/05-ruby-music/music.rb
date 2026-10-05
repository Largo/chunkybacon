# Ruby macht Musik - a tiny synthesizer in pure Ruby.
#
# Everything here is what the lesson builds up cell by cell (lesson.json),
# gathered in one file so it can be benchmarked under CRuby, required in the
# workshop, or used on a computer. No gems: samples are Floats in -1.0..1.0,
# a WAV file is a 44-byte header plus the samples as 16-bit integers,
# packed with Array#pack("s<*").
#
#   require_relative "music"
#   melody = notes "C4 E4 G4 C5", length: 0.25
#   File.binwrite("arpeggio.wav", wav(melody))
#   show_audio wav(melody)            # in the course: a player below the cell
module Music
  RATE = 22_050   # samples per second: half of a CD, plenty for square waves

  module_function

  # ---- the file ---------------------------------------------------------

  # 16-bit mono PCM. The header is twelve fields; pack's directives say how
  # each becomes bytes: a4 = 4 chars, V = 32-bit little-endian, v = 16-bit.
  def wav(samples, rate = RATE)
    data = samples.map { |s| (s.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
    ["RIFF", 36 + data.bytesize, "WAVE",
     "fmt ", 16, 1, 1, rate, rate * 2, 2, 16,   # PCM, 1 channel, rate, bytes/s, block, bits
     "data", data.bytesize].pack("a4Va4a4VvvVVvva4V") + data
  end

  # The other way round: what a check (or the widget) needs to know.
  def wav_info(bytes)
    bytes = bytes.b
    riff, _size, wave = bytes.unpack("a4Va4")
    raise ArgumentError, "not a WAV file" unless riff == "RIFF" && wave == "WAVE"

    pos = 12
    info = {}
    while pos + 8 <= bytes.bytesize
      id, size = bytes.byteslice(pos, 8).unpack("a4V")
      body = bytes.byteslice(pos + 8, size)
      case id
      when "fmt "
        format, channels, rate, _bps, _block, bits = body.unpack("vvVVvv")
        info.merge!(format: format, channels: channels, rate: rate, bits: bits)
      when "data"
        info[:samples] = body.unpack("s<*").map { |s| s / 32_768.0 } if info[:bits] == 16
      end
      pos += 8 + size + (size & 1)
    end
    info[:seconds] = info[:samples].size.fdiv(info[:rate] * info[:channels]) if info[:samples]
    info
  end

  # ---- tones ------------------------------------------------------------

  # one period of each wave, for a phase from 0.0 to 1.0
  WAVES = {
    sine:     ->(t) { Math.sin(2 * Math::PI * t) },
    square:   ->(t) { t < 0.5 ? 1.0 : -1.0 },
    saw:      ->(t) { 2.0 * t - 1.0 },
    triangle: ->(t) { 1.0 - 4.0 * (t - 0.5).abs }
  }.freeze

  def tone(freq, seconds, wave: :sine, volume: 0.5)
    form = WAVES.fetch(wave)
    Array.new((seconds * RATE).round) { |i| volume * form.((freq * i / RATE) % 1.0) }
  end

  def sine(freq, seconds = 1.0)   = tone(freq, seconds, wave: :sine)
  def square(freq, seconds = 1.0) = tone(freq, seconds, wave: :square, volume: 0.25)
  def saw(freq, seconds = 1.0)    = tone(freq, seconds, wave: :saw, volume: 0.3)

  def silence(seconds)
    Array.new((seconds * RATE).round, 0.0)
  end

  # Fade in over +attack+ seconds and out over +release+: without it every
  # note starts and stops with a click.
  def envelope(samples, attack: 0.01, release: 0.05)
    a = attack * RATE
    r = release * RATE
    n = samples.size
    samples.each_with_index.map { |s, i| s * [1.0, i / a, (n - i) / r].min }
  end

  # ---- notes ------------------------------------------------------------

  # semitones above C; H is the German name for B
  STEPS = { "C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11, "H" => 11 }.freeze

  # "A4" -> 440.0, "C4" -> 261.6 (middle C), "F#3", "Bb2"
  def frequency(name)
    letter, sign, octave = name.match(/\A([A-H])([#b]?)(\d)\z/)&.captures
    raise ArgumentError, "no note: #{name.inspect}" unless letter

    midi = 12 * (octave.to_i + 1) + STEPS.fetch(letter) + { "#" => 1, "b" => -1 }.fetch(sign, 0)
    440.0 * 2**((midi - 69) / 12.0)
  end

  # "C4 E4 G4 -" -> samples; "-" is a rest, "C4*2" a note twice as long
  def notes(text, length: 0.25, wave: :sine)
    text.split.flat_map do |word|
      name, times = word.split("*")
      seconds = length * (times || 1).to_f
      name == "-" ? silence(seconds) : envelope(tone(frequency(name), seconds, wave: wave))
    end
  end

  # several tracks at once: zip them sample by sample and add up
  def mix(*tracks)
    longest = tracks.map(&:size).max
    padded = tracks.map { |t| t + [0.0] * (longest - t.size) }
    padded.first.zip(*padded.drop(1)).map(&:sum)
  end

  def chord(names, seconds = 1.0, wave: :sine)
    tracks = names.split.map { |name| tone(frequency(name), seconds, wave: wave, volume: 0.5 / names.split.size) }
    envelope(mix(*tracks), release: 0.3)
  end

  # ---- drums ------------------------------------------------------------

  NOISE = Random.new(42)   # the same "random" hi-hat every run

  # a sine that falls from 120 to 40 Hz and dies away fast
  def kick(seconds = 0.2)
    phase = 0.0
    Array.new((seconds * RATE).round) do |i|
      t = i.fdiv(RATE)
      phase += (40 + 80 * Math.exp(-t * 30)) / RATE
      0.9 * Math.sin(2 * Math::PI * phase) * Math.exp(-t * 15)
    end
  end

  def hihat(seconds = 0.06)
    Array.new((seconds * RATE).round) { |i| 0.25 * (NOISE.rand * 2 - 1) * Math.exp(-i.fdiv(RATE) * 70) }
  end

  def snare(seconds = 0.15)
    Array.new((seconds * RATE).round) do |i|
      t = i.fdiv(RATE)
      (0.4 * (NOISE.rand * 2 - 1) + 0.3 * Math.sin(2 * Math::PI * 185 * t)) * Math.exp(-t * 25)
    end
  end

  DRUMS = { "x" => :kick, "s" => :snare, "h" => :hihat }.freeze

  # "x.h.s.h.x.h.s.h." - one character per step: x kick, s snare, h hi-hat,
  # anything else a rest
  def drums(pattern, step: 0.125)
    slot = (step * RATE).round
    pattern.chars.flat_map do |ch|
      sound = DRUMS[ch] ? send(DRUMS[ch]) : []
      sound.first(slot) + [0.0] * [slot - sound.size, 0].max
    end
  end
end
