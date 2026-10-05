# Writes lesson.json: the draft of the side trip "Ruby macht Musik" in the
# shape one entry of html/lessons.js has ({ id, de: {title, cells}, en, ja }).
# Japanese runs the English code with the comments translated (HANDOVER §3),
# so ja's code is made from en's by replacing comments, and its check is
# en's, byte for byte.
# Run: ruby experiments/05-ruby-music/build_lesson.rb
require "json"

NUMBER = 31   # after "30. RubyKaigi"; see NOTES.md for the renumbering
DSL_LESSON = NUMBER <= 43 ? 44 : 43   # "Eine eigene DSL", 43 today, one later once this is in front of it

# ---------------------------------------------------------------- German

DE = {
  title: "#{NUMBER}. Ruby macht Musik",
  cells: [
    { "t" => "h", "html" => <<~HTML.strip },
      <h2>Ruby macht Musik</h2><p>Ton ist Luft, die schwingt. Ein Lautsprecher schiebt seine Membran vor und zurück, und wie schnell er das tut, hörst du als Tonhöhe: <strong>440 Mal pro Sekunde</strong> ist der Kammerton A, nach dem ein Orchester stimmt.</p><p>Ein Computer beschreibt diese Bewegung mit Zahlen: Er misst sie <strong>22 050 Mal pro Sekunde</strong> (die <em>Abtastrate</em>) und schreibt jedes Mal auf, wo die Membran gerade ist – eine Zahl zwischen -1 und 1. Eine Sekunde Ton ist also einfach ein Array mit 22 050 Floats. In dieser Lektion rechnest du dieses Array selbst aus, ganz ohne Gem: erst einen Ton, dann eine Melodie, Akkorde und ein Schlagzeug.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      RATE = 22_050                       # Zahlen pro Sekunde

      kammerton = Array.new(RATE) do |i|  # eine Sekunde
        zeit = i.fdiv(RATE)               # in Sekunden
        0.5 * Math.sin(2 * Math::PI * 440 * zeit)
      end
      kammerton.first(8).map { |s| s.round(3) }
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p><code>Array.new(RATE) { |i| … }</code> ruft den Block 22 050 Mal auf und sammelt, was er liefert. <code>i.fdiv(RATE)</code> macht aus der Nummer der Zahl die Zeit in Sekunden, und <code>Math.sin(2 * Math::PI * 440 * zeit)</code> ist eine <strong>Sinuswelle</strong>, die 440 Mal pro Sekunde einmal hoch und wieder herunter geht. Mal <code>0.5</code> macht sie halb so laut.</p><p>Hören kannst du ein Array aber nicht – der Browser will eine <strong>WAV-Datei</strong>. Die ist erstaunlich einfach: 44 Bytes Kopf, danach jede Zahl als ganze Zahl von -32 768 bis 32 767.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      def wav(samples)
        daten = samples.map { |s| (s.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
        kopf = ["RIFF", 36 + daten.bytesize, "WAVE",
                "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16,   # PCM, 1 Kanal, 16 Bit
                "data", daten.bytesize].pack("a4Va4a4VvvVVvva4V")
        kopf + daten
      end

      datei = wav(kammerton)
      show_audio datei
      [datei.bytesize, datei[0, 4], datei[8, 4]]
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p><code>pack</code> verwandelt ein Array in <strong>Bytes</strong>, und der Text in Klammern sagt, wie: <code>s&lt;*</code> heisst «jede Zahl als 16-Bit-Zahl mit Vorzeichen, kleines Byte zuerst». Für den Kopf steht jeder Buchstabe für ein Feld: <code>a4</code> sind 4 Zeichen Text, <code>V</code> eine 32-Bit-Zahl, <code>v</code> eine 16-Bit-Zahl. Darin stehen die Länge der Datei, das Format (1 = PCM, rohe Zahlen), 1 Kanal, die Abtastrate und 16 Bit pro Zahl. 44 Bytes Kopf plus 2 Bytes pro Zahl: 44 144 Bytes für eine Sekunde.</p><p>Mit <code>pack</code> und <code>unpack</code> liest und schreibt Ruby fast jedes Binärformat – PNG, ZIP und MIDI funktionieren genauso. <code>show_audio</code> spielt die Datei unter der Zelle ab und zeigt die Welle: links den ganzen Ton, rechts mit der Lupe 12 Millisekunden.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      WELLEN = {
        sinus:    ->(phase) { Math.sin(2 * Math::PI * phase) },
        rechteck: ->(phase) { phase < 0.5 ? 1.0 : -1.0 },
        saege:    ->(phase) { 2 * phase - 1 }
      }

      def ton(frequenz, sekunden, welle = :sinus, laut = 0.3)
        form = WELLEN.fetch(welle)
        Array.new((sekunden * RATE).round) do |i|
          laut * form.((frequenz * i).fdiv(RATE) % 1.0)   # wo in der Schwingung?
        end
      end

      WELLEN.each_key { |welle| show_audio wav(ton(220, 0.6, welle)) }
      WELLEN.keys
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>Die <strong>Phase</strong> sagt, wo in einer Schwingung du gerade bist: 0.0 am Anfang, 0.5 in der Mitte, kurz vor 1.0 am Ende. <code>(frequenz * i).fdiv(RATE) % 1.0</code> rechnet sie aus – <code>%</code> wirft die ganzen Schwingungen weg und lässt den Rest. Jede Welle ist ein <strong>Lambda</strong>, das aus der Phase eine Höhe macht, und alle drei stehen in einem Hash. Eine neue Klangfarbe ist eine Zeile mehr.</p><p>Schau in der Lupe: Der Sinus ist rund und klingt weich, Rechteck und Säge haben Ecken und klingen schnarrend wie ein Gameboy – Ecken bestehen aus vielen höheren Tönen, den <em>Obertönen</em>. Darum sind sie auch leiser gerechnet.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      STUFEN = { "C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "H" => 11 }

      def frequenz(name)                  # "A4" → 440.0
        halbton = 12 * (name[1].to_i + 1) + STUFEN.fetch(name[0])
        440 * 2**((halbton - 69) / 12.0)
      end

      def huelle(samples)                 # ein- und ausblenden: kein Knacksen
        n = samples.size
        samples.each_with_index.map { |s, i| s * [1.0, i / 200.0, (n - i) / 800.0].min }
      end

      def noten(text, laenge: 0.25, welle: :sinus)
        text.split.flat_map do |name|
          if name == "-"
            Array.new((laenge * RATE).round, 0.0)   # eine Pause
          else
            huelle(ton(frequenz(name), laenge, welle))
          end
        end
      end

      froschgesang = noten("C4 D4 E4 F4 E4 D4 C4 - E4 F4 G4 A4 G4 F4 E4 -", laenge: 0.3)
      show_audio wav(froschgesang)
      [frequenz("A4"), frequenz("C4").round(1), frequenz("C5").round(1)]
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>Das ist der <strong>Froschgesang</strong> – in Japan kennt jedes Kind das Lied als 「かえるの歌」. Eine Melodie ist hier ein String: <code>split</code> zerlegt ihn in Notennamen, und <code>flat_map</code> hängt die Töne aller Noten zu einem einzigen langen Array zusammen.</p><p>Eine Oktave hat 12 <strong>Halbtöne</strong>, und jeder Halbton ist 2<sup>1/12</sup> ≈ 1.059 Mal höher als der vorige – nach 12 Schritten ist die Frequenz genau doppelt so hoch: C5 schwingt doppelt so schnell wie C4. <code>frequenz</code> zählt die Halbtöne ab dem A4 (Nummer 69, wie bei MIDI) und rechnet so die Frequenz aus. Und <code>huelle</code> blendet jeden Ton kurz ein und aus: Springt eine Welle mitten in der Schwingung auf null, hörst du ein Knacksen. Lösch <code>huelle(…)</code> einmal und hör hin.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      def zusammen(*spuren)
        laengste = spuren.map(&:size).max
        spuren = spuren.map { |spur| spur + [0] * (laengste - spur.size) }
        spuren.first.zip(*spuren.drop(1)).map(&:sum)
      end

      c_dur = zusammen(*%w[C4 E4 G4].map { |name| huelle(ton(frequenz(name), 1.5, :sinus, 0.2)) })
      show_audio wav(c_dur)
      zusammen([1, 2, 3], [10, 20], [100])
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>Klingen mehrere Töne gleichzeitig, <strong>addiert</strong> sich der Luftdruck einfach. <code>zip</code> legt die Arrays nebeneinander – <code>[1, 2].zip([10, 20])</code> ergibt <code>[[1, 10], [2, 20]]</code> – und <code>map(&amp;:sum)</code> zählt jedes Paar zusammen. Kürzere Spuren füllt <code>zusammen</code> vorher mit Stille auf. Der Akkord C-E-G ist <strong>C-Dur</strong>.</p><p>Darum spielt jeder Ton hier nur mit <code>0.2</code>: Drei Töne mit 0.5 ergäben bis zu 1.5, und alles über 1 schneidet <code>clamp</code> ab – das klingt kratzig (<em>Clipping</em>). Probier es aus.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      def kick                            # Sinus, der von 120 auf 40 Hz fällt
        phase = 0.0
        Array.new(3000) do |i|
          zeit = i.fdiv(RATE)
          phase += (40 + 80 * Math.exp(-zeit * 30)) / RATE
          0.8 * Math.sin(2 * Math::PI * phase) * Math.exp(-zeit * 15)
        end
      end

      def hihat                           # Rauschen, das schnell verklingt
        Array.new(1200) { |i| 0.2 * (rand * 2 - 1) * Math.exp(-i / 150.0) }
      end

      def schlagzeug(muster, schritt: 0.125)
        platz = (schritt * RATE).round
        muster.chars.flat_map do |zeichen|
          klang = case zeichen
                  when "x" then kick
                  when "h" then hihat
                  else []
                  end
          klang.first(platz) + [0.0] * [platz - klang.size, 0].max
        end
      end

      takt = schlagzeug("x.h.x.h.x.h.xxh." * 2)
      melodie = noten("C4 D4 E4 F4 E4 D4 C4 - E4 F4 G4 A4 G4 F4 E4 -", welle: :rechteck)
      lied = zusammen(melodie, takt)
      File.binwrite("froschgesang.wav", wav(lied))
      show_audio "froschgesang.wav"
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>Ein Schlagzeug ist hier wieder ein String: Jedes Zeichen ist ein Achtel, <code>x</code> die grosse Trommel, <code>h</code> die Hi-Hat, ein Punkt Pause. Die <strong>Kick</strong> ist ein Sinus, dessen Frequenz schnell fällt und der dabei verklingt (<code>Math.exp(-zeit * 15)</code> wird rasch kleiner), die <strong>Hi-Hat</strong> ist Rauschen aus <code>rand</code>. Jeder Klang wird auf seinen Platz zurechtgeschnitten oder mit Stille aufgefüllt, damit der Takt gleichmässig bleibt.</p><p><code>noten</code>, <code>schlagzeug</code>, <code>zusammen</code> – das sind schon die Wörter einer kleinen Sprache für Musik, gebaut aus Arrays, Strings und Blöcken (mehr dazu in Lektion #{DSL_LESSON}, «Eine eigene DSL»). <code>File.binwrite</code> schreibt die Bytes als Datei; sie erscheint unter der Zelle als Download, und <code>show_audio</code> nimmt auch ihren Namen.</p><div class='offweb' data-title='Auf deinem Computer'><p>Dort läuft derselbe Code: <code>File.binwrite("lied.wav", wav(lied))</code> und dann die Datei mit einem beliebigen Player öffnen. Wer WAV-Dateien auch lesen oder in Stereo und 24 Bit schreiben will, nimmt das Gem <code>wavefile</code> (reines Ruby, läuft auch hier mit <code>install_gem "wavefile"</code>) – es schreibt für dieses Lied Byte für Byte dieselbe Datei.</p></div><div class='task'><p><strong>Deine Aufgabe:</strong> Ein Tusch! Schreib die Datei <code>tusch.wav</code>: zuerst die Töne C4, E4, G4 und C5 nacheinander, je 0.25 Sekunden, danach alle vier <strong>zusammen</strong> eine Sekunde lang – insgesamt also 2 Sekunden.</p></div>
    HTML
    { "t" => "x",
      "code" => "# tusch.wav: C4 E4 G4 C5 nacheinander (je 0.25 s), dann alle vier zusammen (1 s)\n",
      "check" => nil,   # filled in below
      "hint" => "<code>noten(\"C4 E4 G4 C5\")</code> gibt dir die vier Töne. Für den Akkord <code>zusammen(*%w[C4 E4 G4 C5].map { |name| huelle(ton(frequenz(name), 1.0, :sinus, 0.2)) })</code> – beides mit <code>+</code> hintereinanderhängen und <code>File.binwrite(\"tusch.wav\", wav(…))</code>." }
  ]
}

# ---------------------------------------------------------------- English

EN = {
  title: "#{NUMBER}. Ruby makes music",
  cells: [
    { "t" => "h", "html" => <<~HTML.strip },
      <h2>Ruby makes music</h2><p>Sound is air that vibrates. A loudspeaker pushes its cone back and forth, and how fast it does so is what you hear as pitch: <strong>440 times a second</strong> is the concert A an orchestra tunes to.</p><p>A computer describes that movement with numbers: it measures it <strong>22,050 times a second</strong> (the <em>sample rate</em>) and writes down where the cone is each time – a number between -1 and 1. One second of sound is simply an Array of 22,050 Floats. In this lesson you compute that Array yourself, without any gem: first a tone, then a melody, chords and a drum kit.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      RATE = 22_050                       # numbers per second

      concert_a = Array.new(RATE) do |i|  # one second
        time = i.fdiv(RATE)               # in seconds
        0.5 * Math.sin(2 * Math::PI * 440 * time)
      end
      concert_a.first(8).map { |s| s.round(3) }
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p><code>Array.new(RATE) { |i| … }</code> calls the block 22,050 times and collects what it returns. <code>i.fdiv(RATE)</code> turns the number's position into the time in seconds, and <code>Math.sin(2 * Math::PI * 440 * time)</code> is a <strong>sine wave</strong> that goes up and down once, 440 times a second. Times <code>0.5</code> makes it half as loud.</p><p>But you cannot listen to an Array – the browser wants a <strong>WAV file</strong>. That is surprisingly simple: a 44-byte header, then every number as a whole number from -32,768 to 32,767.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      def wav(samples)
        data = samples.map { |s| (s.clamp(-1.0, 1.0) * 32_767).round }.pack("s<*")
        header = ["RIFF", 36 + data.bytesize, "WAVE",
                  "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16,   # PCM, 1 channel, 16 bits
                  "data", data.bytesize].pack("a4Va4a4VvvVVvva4V")
        header + data
      end

      file = wav(concert_a)
      show_audio file
      [file.bytesize, file[0, 4], file[8, 4]]
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p><code>pack</code> turns an Array into <strong>bytes</strong>, and the text in brackets says how: <code>s&lt;*</code> means "every number as a signed 16-bit number, low byte first". For the header each letter stands for one field: <code>a4</code> is 4 characters of text, <code>V</code> a 32-bit number, <code>v</code> a 16-bit number. They hold the length of the file, the format (1 = PCM, raw numbers), 1 channel, the sample rate and 16 bits per number. 44 bytes of header plus 2 bytes per number: 44,144 bytes for one second.</p><p>With <code>pack</code> and <code>unpack</code> Ruby reads and writes almost any binary format – PNG, ZIP and MIDI work the same way. <code>show_audio</code> plays the file below the cell and shows the wave: the whole sound on the left, 12 milliseconds under the magnifier on the right.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      WAVES = {
        sine:   ->(phase) { Math.sin(2 * Math::PI * phase) },
        square: ->(phase) { phase < 0.5 ? 1.0 : -1.0 },
        saw:    ->(phase) { 2 * phase - 1 }
      }

      def tone(frequency, seconds, wave = :sine, volume = 0.3)
        shape = WAVES.fetch(wave)
        Array.new((seconds * RATE).round) do |i|
          volume * shape.((frequency * i).fdiv(RATE) % 1.0)   # where in the vibration?
        end
      end

      WAVES.each_key { |wave| show_audio wav(tone(220, 0.6, wave)) }
      WAVES.keys
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>The <strong>phase</strong> says where in one vibration you are: 0.0 at the start, 0.5 halfway, just under 1.0 at the end. <code>(frequency * i).fdiv(RATE) % 1.0</code> works it out – <code>%</code> throws away the whole vibrations and keeps the rest. Every wave is a <strong>lambda</strong> that turns the phase into a height, and all three live in a Hash. A new sound colour is one more line.</p><p>Look through the magnifier: the sine is round and sounds soft, square and saw have corners and buzz like a Game Boy – corners are made of many higher tones, the <em>overtones</em>. That is also why they are computed quieter.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      STEPS = { "C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11 }

      def frequency(name)                 # "A4" → 440.0
        semitone = 12 * (name[1].to_i + 1) + STEPS.fetch(name[0])
        440 * 2**((semitone - 69) / 12.0)
      end

      def envelope(samples)               # fade in and out: no clicks
        n = samples.size
        samples.each_with_index.map { |s, i| s * [1.0, i / 200.0, (n - i) / 800.0].min }
      end

      def notes(text, length: 0.25, wave: :sine)
        text.split.flat_map do |name|
          if name == "-"
            Array.new((length * RATE).round, 0.0)   # a rest
          else
            envelope(tone(frequency(name), length, wave))
          end
        end
      end

      frog_song = notes("C4 D4 E4 F4 E4 D4 C4 - E4 F4 G4 A4 G4 F4 E4 -", length: 0.3)
      show_audio wav(frog_song)
      [frequency("A4"), frequency("C4").round(1), frequency("C5").round(1)]
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>That is the <strong>frog song</strong>, a German children's song that every child in Japan knows as 「かえるの歌」. A melody is a String here: <code>split</code> cuts it into note names, and <code>flat_map</code> joins the tones of all the notes into one long Array.</p><p>An octave has 12 <strong>semitones</strong>, and each semitone is 2<sup>1/12</sup> ≈ 1.059 times higher than the one before – after 12 steps the frequency has exactly doubled: C5 vibrates twice as fast as C4. <code>frequency</code> counts the semitones from A4 (number 69, as in MIDI) and works out the frequency from that. And <code>envelope</code> fades each tone in and out briefly: when a wave jumps to zero in the middle of a vibration, you hear a click. Delete the <code>envelope(…)</code> once and listen.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      def mix(*tracks)
        longest = tracks.map(&:size).max
        tracks = tracks.map { |track| track + [0] * (longest - track.size) }
        tracks.first.zip(*tracks.drop(1)).map(&:sum)
      end

      c_major = mix(*%w[C4 E4 G4].map { |name| envelope(tone(frequency(name), 1.5, :sine, 0.2)) })
      show_audio wav(c_major)
      mix([1, 2, 3], [10, 20], [100])
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>When several tones sound at once, the air pressure simply <strong>adds up</strong>. <code>zip</code> lays the Arrays side by side – <code>[1, 2].zip([10, 20])</code> gives <code>[[1, 10], [2, 20]]</code> – and <code>map(&amp;:sum)</code> adds up each pair. Before that, <code>mix</code> pads shorter tracks with silence. The chord C-E-G is <strong>C major</strong>.</p><p>That is why every tone here plays at only <code>0.2</code>: three tones at 0.5 would reach 1.5, and <code>clamp</code> cuts off everything above 1 – it sounds harsh (<em>clipping</em>). Try it.</p>
    HTML
    { "t" => "c", "code" => <<~RUBY.strip },
      def kick                            # a sine falling from 120 to 40 Hz
        phase = 0.0
        Array.new(3000) do |i|
          time = i.fdiv(RATE)
          phase += (40 + 80 * Math.exp(-time * 30)) / RATE
          0.8 * Math.sin(2 * Math::PI * phase) * Math.exp(-time * 15)
        end
      end

      def hihat                           # noise that dies away fast
        Array.new(1200) { |i| 0.2 * (rand * 2 - 1) * Math.exp(-i / 150.0) }
      end

      def drums(pattern, step: 0.125)
        slot = (step * RATE).round
        pattern.chars.flat_map do |char|
          sound = case char
                  when "x" then kick
                  when "h" then hihat
                  else []
                  end
          sound.first(slot) + [0.0] * [slot - sound.size, 0].max
        end
      end

      beat = drums("x.h.x.h.x.h.xxh." * 2)
      melody = notes("C4 D4 E4 F4 E4 D4 C4 - E4 F4 G4 A4 G4 F4 E4 -", wave: :square)
      song = mix(melody, beat)
      File.binwrite("frog_song.wav", wav(song))
      show_audio "frog_song.wav"
    RUBY
    { "t" => "h", "html" => <<~HTML.strip },
      <p>A drum kit is a String again: every character is an eighth note, <code>x</code> the bass drum, <code>h</code> the hi-hat, a dot a rest. The <strong>kick</strong> is a sine whose frequency falls fast while it dies away (<code>Math.exp(-time * 15)</code> shrinks quickly), the <strong>hi-hat</strong> is noise from <code>rand</code>. Every sound is cut to its slot or padded with silence, so the beat stays even.</p><p><code>notes</code>, <code>drums</code>, <code>mix</code> – those are already the words of a small language for music, built from Arrays, Strings and blocks (more in lesson #{DSL_LESSON}, "Your own DSL"). <code>File.binwrite</code> writes the bytes as a file; it appears below the cell as a download, and <code>show_audio</code> takes its name too.</p><div class='offweb' data-title='On your machine'><p>The same code runs there: <code>File.binwrite("song.wav", wav(song))</code>, then open the file in any player. To read WAV files as well, or write stereo and 24 bits, use the <code>wavefile</code> gem (pure Ruby, it runs here too with <code>install_gem "wavefile"</code>) – for this song it writes the very same file, byte for byte.</p></div><div class='task'><p><strong>Your task:</strong> a fanfare! Write the file <code>fanfare.wav</code>: first the notes C4, E4, G4 and C5 one after another, 0.25 seconds each, then all four <strong>together</strong> for one second – 2 seconds in all.</p></div>
    HTML
    { "t" => "x",
      "code" => "# fanfare.wav: C4 E4 G4 C5 one after another (0.25 s each), then all four together (1 s)\n",
      "check" => nil,
      "hint" => "<code>notes(\"C4 E4 G4 C5\")</code> gives you the four tones. For the chord, <code>mix(*%w[C4 E4 G4 C5].map { |name| envelope(tone(frequency(name), 1.0, :sine, 0.2)) })</code> – join both with <code>+</code> and <code>File.binwrite(\"fanfare.wav\", wav(…))</code>." }
  ]
}

# ---------------------------------------------------------------- the check
#
# The file must exist and be a 16-bit mono 22,050 Hz WAV of about 2 s. The
# notes are found with a tiny Fourier transform: amp.(t, f) is how strongly
# frequency f sounds in the 0.1 s from t on, in sample units. Each of the
# four notes must be there in its quarter second, and all four at once in
# the chord - a plain C5 there, or a missing note, fails. In each quarter
# second the other notes must be under a quarter of the expected one, so a
# chord held for 2 s fails too (a relative limit: a loud note leaks ~4% into
# its neighbours' bins; C5 is not tested during C4, a saw's overtone). Any
# wave shape passes (a square or saw C4 still has its fundamental at 261.6 Hz).
# File.read with mode "rb" reads a file from File.write (the virtual store)
# as well as one from File.binwrite (the real working directory).
def check_for(name)
  <<~RUBY.gsub(/\n\s*/, " ").strip
    downloads.include?("#{name}") && File.read("#{name}", mode: "rb").b.then { |bytes|
    head = bytes.unpack("a4Va4a4VvvVVvva4V");
    s = bytes.byteslice(44..).unpack("s<*");
    amp = ->(from, f) { part = s[(from * 22050).round, 2205] || []; re = im = 0.0;
    part.each_with_index { |x, n| w = 2 * Math::PI * f * n / 22050; re += x * Math.cos(w); im += x * Math.sin(w) };
    Math.hypot(re, im) * 2 / [part.size, 1].max };
    c4, e4, g4, c5 = 261.63, 329.63, 392.0, 523.25;
    arpeggio = [[0.07, c4, [e4, g4]], [0.32, e4, [c4, g4, c5]], [0.57, g4, [c4, e4, c5]], [0.82, c5, [c4, e4, g4]]];
    head.values_at(0, 2, 6, 7, 10) == ["RIFF", "WAVE", 1, 22050, 16] && (1.9..2.1).cover?(s.size / 22050.0) &&
    arpeggio.all? { |t, f, others| (a = amp.(t, f)) > 1000 && others.all? { |o| amp.(t, o) < a / 4 } } &&
    [[1.3, c4], [1.3, e4], [1.3, g4], [1.3, c5]].all? { |t, f| amp.(t, f) > 1000 } }
  RUBY
end

DE[:cells].last["check"] = check_for("tusch.wav")
EN[:cells].last["check"] = check_for("fanfare.wav")

# ---------------------------------------------------------------- Japanese

JA_COMMENTS = {
  "# numbers per second" => "# 1秒あたりの数",
  "# one second" => "# 1秒ぶん",
  "# in seconds" => "# 秒単位",
  "# PCM, 1 channel, 16 bits" => "# PCM、1チャンネル、16ビット",
  "# where in the vibration?" => "# 振動のどのあたり？",
  "# fade in and out: no clicks" => "# フェードイン・アウト：プチッと鳴らない",
  "# a rest" => "# 休符",
  "# a sine falling from 120 to 40 Hz" => "# 120 Hzから40 Hzへ下がるサイン波",
  "# noise that dies away fast" => "# すぐに消えるノイズ",
  "# fanfare.wav: C4 E4 G4 C5 one after another (0.25 s each), then all four together (1 s)" =>
    "# fanfare.wav：C4 E4 G4 C5を順に（各0.25秒）、そのあと4つ同時に（1秒）"
}.freeze

def ja_code(code)
  JA_COMMENTS.reduce(code) { |c, (en, ja)| c.gsub(en, ja) }
end

JA_HTML = [
  <<~HTML.strip,
    <h2>Rubyで音楽を作る</h2><p>音とは、振動する空気です。スピーカーは振動板を前後に動かしていて、その速さが音の高さとして聞こえます。<strong>1秒に440回</strong>なら、オーケストラが音合わせに使う「ラ」の音（基準音A）です。</p><p>コンピューターはこの動きを数で表します。<strong>1秒に22,050回</strong>（<em>サンプリングレート</em>）振動板の位置を測り、そのたびに-1から1までの数を書き留めます。つまり1秒の音は、22,050個のFloatが入った配列にすぎません。このレッスンでは、gemを使わずにこの配列を自分で計算します。まず1つの音、次にメロディー、和音、そしてドラムです。</p>
  HTML
  <<~HTML.strip,
    <p><code>Array.new(RATE) { |i| … }</code>はブロックを22,050回呼び出し、返された値を集めます。<code>i.fdiv(RATE)</code>は何番目の数かを秒単位の時間に変え、<code>Math.sin(2 * Math::PI * 440 * time)</code>は1秒に440回上がって下がる<strong>サイン波</strong>です。<code>0.5</code>を掛けると音量が半分になります。</p><p>でも配列のままでは聞けません。ブラウザーが欲しいのは<strong>WAVファイル</strong>です。これは意外と簡単で、44バイトのヘッダーのあとに、それぞれの数を-32,768から32,767までの整数として並べるだけです。</p>
  HTML
  <<~HTML.strip,
    <p><code>pack</code>は配列を<strong>バイト列</strong>に変えます。かっこの中の文字列が変え方を指定します。<code>s&lt;*</code>は「すべての数を符号付き16ビット、下位バイトが先」という意味です。ヘッダーでは1文字が1つの項目を表します。<code>a4</code>は4文字のテキスト、<code>V</code>は32ビットの数、<code>v</code>は16ビットの数です。中身はファイルの長さ、形式（1 = PCM、生の数）、1チャンネル、サンプリングレート、1つの数あたり16ビットです。ヘッダー44バイトと、1つの数につき2バイトで、1秒なら44,144バイトになります。</p><p><code>pack</code>と<code>unpack</code>を使えば、Rubyはほとんどのバイナリ形式を読み書きできます。PNGもZIPもMIDIも同じ考え方です。<code>show_audio</code>はセルの下でファイルを再生し、波形を表示します。左は音全体、右は虫めがねで見た12ミリ秒です。</p>
  HTML
  <<~HTML.strip,
    <p><strong>位相</strong>は、1回の振動のどこにいるかを表します。始まりが0.0、半分で0.5、終わりの直前が1.0に近い値です。<code>(frequency * i).fdiv(RATE) % 1.0</code>がそれを計算します。<code>%</code>で振動の回数ぶんを捨て、余りだけを残します。それぞれの波形は位相を高さに変える<strong>ラムダ</strong>で、3つともHashに入っています。新しい音色は1行足すだけです。</p><p>虫めがねで見てみましょう。サイン波は丸く、やわらかく聞こえます。矩形波とのこぎり波には角があり、ゲームボーイのようにビーッと聞こえます。角はたくさんの高い音、つまり<em>倍音</em>でできているからです。そのため、この2つは小さめの音量で計算しています。</p>
  HTML
  <<~HTML.strip,
    <p>これは<strong>「かえるの歌」</strong>です。もとはドイツの童謡で、日本ではだれもが知っている歌ですね。ここではメロディーは文字列です。<code>split</code>で音名に分け、<code>flat_map</code>ですべての音を1本の長い配列につなげます。</p><p>1オクターブには12の<strong>半音</strong>があり、半音1つごとに周波数は2<sup>1/12</sup> ≈ 1.059倍になります。12段上がるとちょうど2倍で、C5はC4の2倍の速さで振動します。<code>frequency</code>はA4（MIDIと同じく69番）から半音をいくつ数えるかで周波数を求めます。そして<code>envelope</code>は、それぞれの音を短くフェードイン・フェードアウトさせます。振動の途中で波がいきなり0になると、プチッという音が聞こえるからです。一度<code>envelope(…)</code>を消して聞いてみてください。</p>
  HTML
  <<~HTML.strip,
    <p>いくつかの音が同時に鳴るとき、空気の圧力はそのまま<strong>足し算</strong>されます。<code>zip</code>は配列を横に並べます。<code>[1, 2].zip([10, 20])</code>は<code>[[1, 10], [2, 20]]</code>になり、<code>map(&amp;:sum)</code>で組ごとに足します。その前に<code>mix</code>は、短いトラックを無音で埋めて長さをそろえます。C・E・Gの和音は<strong>ハ長調（Cメジャー）</strong>です。</p><p>だからここでは、どの音も<code>0.2</code>の音量で鳴らしています。0.5の音を3つ足すと最大1.5になり、1を超えた部分は<code>clamp</code>で切り落とされて、ガリガリした音になります（<em>クリッピング</em>）。試してみてください。</p>
  HTML
  <<~HTML.strip
    <p>ドラムもまた文字列です。1文字が8分音符1つ分で、<code>x</code>はバスドラム、<code>h</code>はハイハット、点は休符です。<strong>キック</strong>は、周波数がすばやく下がりながら消えていくサイン波です（<code>Math.exp(-time * 15)</code>はすぐに小さくなります）。<strong>ハイハット</strong>は<code>rand</code>で作ったノイズです。それぞれの音は自分の枠に合わせて切るか無音で埋めるので、リズムがずれません。</p><p><code>notes</code>、<code>drums</code>、<code>mix</code>――これはもう、配列と文字列とブロックでできた、音楽のための小さな言語の単語です（くわしくはレッスン#{DSL_LESSON}「自分だけのDSL」で）。<code>File.binwrite</code>はバイト列をファイルに書き出します。ファイルはセルの下にダウンロードとして現れ、<code>show_audio</code>にはファイル名を渡すこともできます。</p><div class='offweb' data-title='自分のコンピューターでは'><p>同じコードがそのまま動きます。<code>File.binwrite("song.wav", wav(song))</code>で書き出し、好きなプレーヤーで開いてください。WAVファイルを読んだり、ステレオや24ビットで書いたりしたいなら、<code>wavefile</code> gemを使います（純粋なRubyなので、ここでも<code>install_gem "wavefile"</code>で動きます）。この曲なら、1バイトも違わない同じファイルを書き出します。</p></div><div class='task'><p><strong>課題：</strong>ファンファーレを作ろう！ <code>fanfare.wav</code>というファイルを書き出してください。まずC4、E4、G4、C5を順に各0.25秒、そのあと4つを<strong>同時に</strong>1秒鳴らします。全部で2秒です。</p></div>
  HTML
].freeze

ja_cells = EN[:cells].map(&:dup)
html_cells = ja_cells.select { |c| c["t"] == "h" }
raise "#{html_cells.size} prose cells, #{JA_HTML.size} translations" unless html_cells.size == JA_HTML.size

html_cells.zip(JA_HTML).each { |cell, html| cell["html"] = html }
ja_cells.each { |cell| cell["code"] = ja_code(cell["code"]) if cell["code"] }
ja_cells.last["hint"] = "<code>notes(\"C4 E4 G4 C5\")</code>で4つの音ができるよ。和音は<code>mix(*%w[C4 E4 G4 C5].map { |name| envelope(tone(frequency(name), 1.0, :sine, 0.2)) })</code>。2つを<code>+</code>でつないで、<code>File.binwrite(\"fanfare.wav\", wav(…))</code>で保存しよう。"
JA = { title: "#{NUMBER}. Rubyで音楽を作る", cells: ja_cells }

# every English comment got its Japanese one
en_comments = EN[:cells].filter_map { |c| c["code"] }.join("\n").scan(/# [a-z][^\n]*/i)
ja_code_all = ja_cells.filter_map { |c| c["code"] }.join("\n")
leftover = en_comments.select { |comment| ja_code_all.include?(comment) }
raise "untranslated comments: #{leftover.inspect}" unless leftover.empty?

lesson = {
  "id" => "musik",
  "de" => { "title" => DE[:title], "cells" => DE[:cells] },
  "en" => { "title" => EN[:title], "cells" => EN[:cells] },
  "ja" => { "title" => JA[:title], "cells" => JA[:cells] }
}
File.write(File.join(__dir__, "lesson.json"), JSON.pretty_generate(lesson) + "\n")
puts "lesson.json: #{lesson["de"]["cells"].size} cells per language " \
     "(#{lesson["de"]["cells"].count { |c| c["t"] == "c" }} demo, 1 exercise)"
