# 05 - Ruby macht Musik (proof of concept)

**Integrated.** The lesson is lesson 37 (`musik`), right after
`rubykaigi`, the last of the side trips (the timelog track moved to
38-53, references with it); its DSL reference now names lesson 50
(`tl-dsl` after the insert), its task blocks start with the course's
`<strong>Aufgabe:</strong>`, and the Japanese one is in です・ます.
`show_audio` is in `html/main.rb` (step 1 below, without the prepend):
`ChunkyAudio.pcm`/`waveform_svg`/`wav`, `add_audio`/`audios_html`,
`@run_audios` in `widgets_present`, `audios` for checks, `.wav` as
`audio/wav`, `Kernel#show_audio` (it raises for bytes that are not a
WAV). Deviations: the wave is an SVG in an `<img class="cell-wave"
alt="">` (inline attributes, fox palette) instead of an inline `<svg>`, so
its "2.00 s" stays out of the status line; the `<audio>` is named "Ein
Klang, 2,0 Sekunden" (`audioLabel`), which `#runStatus` reads; layout CSS
in `app.css` (the page has no dark mode). The workshop keeps, previews
and plays WAVs (`workshop.rb`, `storage.js`, `shell/workspace.rb`). Live
runs: option 1, `"live": false` on the lesson - the shell asks for none
there and its switch stays, off and `aria-disabled` with the reason as
its title (a click has Chunky say it), and the kernel skips one too.
Tests: `check_harness.rb` (`show_audio` stub, `SOLUTIONS["musik"]`, an
`audios` local), `browser_test.mjs` (players with `duration` > 0, the
exercise), `live_test.mjs` and `test/shell` (the flag, the announcement,
the workshop player), the gem's `show_audio` (`chunky-sound-N.wav`).
`lesson_check.rb` now reads the lesson from `html/lessons.js` and keeps
its wrong-answer checks, which the harness does not have. Left out:
`wavefile` in the gem cache (step 7), the pictures → sound cross-link,
the `C4*2`/sharps syntax of `music.rb`. `lesson.json`, `build_lesson.rb`,
`show_audio.rb` and `measure_in_page.mjs` are the experiment's record.

A side-trip lesson where learners synthesize sound in pure Ruby: samples as
an Array of Floats, a WAV file built by hand with `pack`, waveforms as
lambdas, note names to frequencies, chords with `zip`/`sum`, a drum kit from
a string like `"x.h.x.h."`. Plus a `show_audio` widget: an `<audio controls>`
on a Blob URL below the cell, with a small waveform SVG (the whole sound plus
a 12 ms "magnifier" that shows the shape of the wave).

**Verdict: it works, in the real page, end to end.** The one real snag is
live runs (see "Performance"): every music cell is cut off by the live-run
time limit, so the lesson should be ▶-only.

## Files

| file | what |
|---|---|
| `music.rb` | the DSL in one file, English names: `wav`, `wav_info`, `tone`/`sine`/`square`/`saw`, `envelope`, `frequency` ("F#3", "Bb2", German "H"), `notes("C4 E4 G4 C5*2 -")`, `mix`, `chord`, `kick`/`snare`/`hihat`, `drums("x.h.s.h.")`. No gems. |
| `generate_examples.rb` | writes `examples/*.wav` with CRuby timings |
| `examples/` | 9 WAVs, 22,050 Hz 16-bit mono: A440 as sine, square, saw; the frog song (sine, square); a C major chord; the fanfare (the exercise's solution); a beat; frog song with beat (8 s) |
| `show_audio.rb` | the widget, written as a run-time patch of `ChunkyApp` (prepends `pdfs_html`) so it can be pasted into a cell of the real page; the proper `main.rb` edit is below |
| `build_lesson.rb` → `lesson.json` | the lesson draft, de/en/ja, in the shape of one `lessons.js` entry |
| `lesson_check.rb` | offline harness like `test/check_harness.rb`: demo cells in one binding, starter fails, 2 solutions pass, 4 wrong answers fail; times every cell plain and under a live-run TracePoint. `ruby lesson_check.rb de` / `en` / `ja` - all three ALL OK |
| `wavefile_check.rb` | installs the `wavefile` gem through `html/browser_gems.rb` from `vendor/`, reads every example with it, compares its writer with ours |
| `measure_in_page.mjs` | Playwright against the real page (dev server, port 18105): pastes `show_audio.rb` into a cell, runs every demo cell with ▶ and live, runs the exercise check, benchmarks; writes `page_results_de.json` and the screenshots |
| `screenshot_melody.png`, `screenshot_song.png` | the widget in the page |
| `vendor/` | `wavefile-1.1.2.gem` (fetched with `gem fetch`) + a one-entry manifest for the check |

## What works

- **Synthesis in plain Ruby**, ruby.wasm included. The WAVs open in any
  player; Chromium decodes them (`<audio>` reports `duration: 1`, no error,
  for the 1 s A440).
- **`show_audio`** takes WAV bytes, a file name (virtual store or real file),
  or an Array of samples (`rate:`), and renders player + SVG. Blob URLs, the
  previous run's released - the same pattern as `show_pdf`.
- **The exercise check** (`tusch.wav` / `fanfare.wav`: C4 E4 G4 C5 one after
  another, 0.25 s each, then all four together for 1 s) parses the WAV
  header, checks ~2 s of 22,050 Hz 16-bit mono, and finds each note with a
  tiny Fourier transform over 0.1 s windows (`amp.(t, f) > 1000`): every
  note in its quarter second (the other notes under a quarter of it), all
  four in the chord. Any wave shape passes; notes without a chord, the
  wrong order, a three-note chord, only the chord for 2 s, the wrong file
  name all fail. It reads with `File.read(name, mode: "rb")`, so both
  `File.binwrite` (real file) and `File.write` (virtual store) work. 50-80 ms
  in wasm.
- **wavefile gem**: pure Ruby, no dependencies, MIT, 57 KB `.gem` (mostly
  test fixtures). It installs under the course's installer rules (no
  `extconf.rb`; tested through `BrowserGems.install` under CRuby from a local
  file) and loads. Its reader agrees with all 9 examples, and its writer
  produces **byte-identical** files to our 10-line `wav` (same header, max
  sample difference 0). Not needed by the lesson - writing the header by
  hand is the lesson's best part - so it only gets a mention in the
  "on your machine" box. Online it should install through the rubygems
  proxy like any pure gem (not tried in the browser); for offline, add it to
  the cache (`tools/build_gem_cache.rb` `GEMS`, + THIRD_PARTY_NOTICES).

## Performance

CRuby 4.0.1 native (this machine) vs ruby.wasm 4.0 in headless Chromium
(Playwright 1.62.1, same machine), ms:

| | CRuby | wasm (▶) |
|---|---:|---:|
| 1 s of sine samples (`Array.new` + `Math.sin`) | 5-8 | 48-72 |
| 5 s of sine samples | ~35 | 257-311 |
| `wav()` (clamp, round, `pack("s<*")`) per second of audio | ~5 | 35-50 |
| waveform SVG per second of audio | - | ~30 |
| base64 for the Blob URL, 5 s (220 KB) | - | 1-9 |
| `noten(...)` frog song, 4.8 s (tone + envelope per note) | 40-65 | 520-730 |

Rule of thumb: **ruby.wasm renders roughly 5-10 s of 22 kHz audio per
second of computing for a plain tone, ~3-5 s once envelopes and mixing are
added** - about 8-10x slower than native CRuby. A few seconds of music is
fine with ▶.

The lesson's six demo cells, whole runs as the kernel reports them
(`chunky:ran` elapsed, incl. rendering the widget): 0.06-0.10, 0.06-0.15,
0.18-0.30, 1.0-1.2, 0.76-1.2, 0.75-1.6 s. The solution 0.75-0.85 s.

**Live runs do not work for this lesson.** Every demo cell, even the first
(0.1 s with ▶), is stopped after the 1 s limit when run live. The reason is
the TracePoint `autorun.rb` uses (`:line, :b_call, :c_call`): in wasm it
costs **~36x** (1 s of sine: 61 ms plain, 2,224 ms traced, 176k events),
against ~5x in native CRuby. A sample loop makes ~8 events per sample.
The page copes (the "Nach einer Sekunde angehalten" hint, and after one
slow run `LIVE_SLOW` = 0.3 s pauses live runs in that cell), but each cell
freezes the page for a second first. This is a general finding: **any
cell with a loop over ~10^5 elements is stopped in a live run**, not just
music.

Options (pick one):
1. A per-lesson switch: `"live": false` in the lesson entry, honoured by
   the shell's `live?` (`html/shell/app.rb`) - the cleanest for this lesson.
2. `AutoRun.runnable?` returns false for code containing `show_audio`, like
   `show_irb` today (one-line change in `html/autorun.rb`); cell 1 and the
   exercise would still be stopped once each.
3. Cheaper tracing: only `:line` events filtered by path in a TracePoint
   targeted with `enable(target_thread:)`, or a `c_call` sample every N - a
   wider change to live runs, measure first.

Faster sound code would not rescue live runs (36x overhead), but if wanted:
`RATE = 11_025` halves everything, and `huelle`'s per-sample
`[1.0, a, b].min` array (≈ as costly as the tone itself) could be replaced
by fading only the first/last few hundred samples.

## The lesson draft (`lesson.json`)

Id `musik`, "31. Ruby macht Musik" / "31. Ruby makes music" /
"31. Rubyで音楽を作る", 14 cells per language: 7 prose, 6 demos, 1 exercise.
German has its own code (German names, note "H"); Japanese runs the English
code with comments translated, `check` byte-identical to `en`. Swiss
spelling in German (gross, gleichmässig), です・ます in Japanese prose,
casual Chunky in the ja hint.

| # | demo (de names / en names) | Ruby it teaches |
|---|---|---|
| 1 | `RATE = 22_050`; one second of 440 Hz as `Array.new(RATE) { ... Math.sin ... }` | `Array.new` with a block, `fdiv`, `Math` |
| 2 | `def wav(samples)`: header + `pack("s<*")`, `show_audio datei` | `pack` directives, binary formats, `clamp` |
| 3 | `WELLEN`/`WAVES` = Hash of lambdas (sine, square, saw); `ton`/`tone`; all three played | lambdas in a Hash, `.()`, `%` for the phase, `fetch` |
| 4 | `frequenz`, `huelle`/`envelope`, `noten`/`notes("C4 D4 ... -")`: the frog song (Froschgesang = かえるの歌) | `split`, `flat_map`, `**`, keyword args, `each_with_index.map` |
| 5 | `zusammen`/`mix(*spuren)`: C major with `zip(*...).map(&:sum)`; `mix([1,2,3],[10,20],[100])` → `[111, 22, 3]` | splat, `zip`, `map(&:sum)`, padding |
| 6 | `kick`, `hihat`, `schlagzeug`/`drums("x.h.x.h.x.h.xxh." * 2)`; melody + beat, `File.binwrite("froschgesang.wav", ...)` | `chars`, `case`, `rand`, `Math.exp`, a DSL from strings (→ lesson 44, "Eine eigene DSL"), downloads |
| x | `tusch.wav` / `fanfare.wav`: arpeggio C4 E4 G4 C5, then the four-note chord | puts it all together |

Prose covers: sound as vibrating air, sample rate, the WAV header field by
field, overtones (why square/saw buzz), semitones and 2^(1/12), MIDI 69 =
A4, clicks without an envelope, clipping when the mix exceeds 1, the
"on your machine" box (`File.binwrite` + any player; the `wavefile` gem).

The exercise check, as it stands in `lesson.json` (one line there):

```ruby
downloads.include?("tusch.wav") && File.read("tusch.wav", mode: "rb").b.then { |bytes|
  head = bytes.unpack("a4Va4a4VvvVVvva4V"); s = bytes.byteslice(44..).unpack("s<*")
  amp = ->(from, f) { part = s[(from * 22050).round, 2205] || []; re = im = 0.0
    part.each_with_index { |x, n| w = 2 * Math::PI * f * n / 22050; re += x * Math.cos(w); im += x * Math.sin(w) }
    Math.hypot(re, im) * 2 / [part.size, 1].max }
  c4, e4, g4, c5 = 261.63, 329.63, 392.0, 523.25
  arpeggio = [[0.07, c4, [e4, g4]], [0.32, e4, [c4, g4, c5]], [0.57, g4, [c4, e4, c5]], [0.82, c5, [c4, e4, g4]]]
  head.values_at(0, 2, 6, 7, 10) == ["RIFF", "WAVE", 1, 22050, 16] && (1.9..2.1).cover?(s.size / 22050.0) &&
  arpeggio.all? { |t, f, others| (a = amp.(t, f)) > 1000 && others.all? { |o| amp.(t, o) < a / 4 } } &&
  [[1.3, c4], [1.3, e4], [1.3, g4], [1.3, c5]].all? { |t, f| amp.(t, f) > 1000 } }
```

Not done in the draft: a German "lesson 13/22" cross-link in the intro
(pictures → sound) would fit; the `C4*2` duration syntax and sharps exist in
`music.rb` but were left out of the lesson to keep `frequenz` two lines.

## Integration steps

1. **`html/main.rb`** - the widget, from `show_audio.rb` without the prepend:
   - `ChunkyApp`: add `add_audio`, `audios_html(idx)`, `pcm`, `waveform_svg`
     (and `ChunkyAudio.wav` as a private helper for sample Arrays).
   - `run_cell`:
     ```diff
          @run_pdfs = []
     +    @run_audios = []
     ...
          widgets_present = @run_images.any? || @run_browsers.any? || @run_irbs.any? || @run_three.any? ||
     -                      @run_shoes.any? || @run_downloads.any? || @run_pdfs.any? || @run_letters.any?
     +                      @run_shoes.any? || @run_downloads.any? || @run_pdfs.any? || @run_letters.any? ||
     +                      @run_audios.any?
     ...
          out_html += pdfs_html(idx)
     +    out_html += audios_html(idx)
     ```
     (without the `widgets_present` line a cell ending in `show_audio` shows `=> nil`).
   - `check_exercise`: `@bind.local_variable_set(:audios, (@run_audios || []).dup)`
     - lets a check look at what was played without a file.
   - `DOWNLOAD_TYPES`: `".wav" => "audio/wav"` (today a `.wav` download is
     `application/octet-stream`; it still downloads fine).
   - `Kernel#show_audio(sound, rate: 22_050)` next to `show_pdf`.
   - Workshop: `Workshop.previews` knows images and PDFs; add `.wav` to
     `PREVIEW_TYPES` (`html/workshop.rb`) and route it to `@run_audios` in
     `run_cell`'s workshop branch, so a program that writes a WAV gets a player.
2. **`html/assets/app.css`**: move the inline styles of `.cell-audio`, its
   `svg` and `audio` there (colours from the fox palette; a dark-mode
   variant if the page has one).
3. **Live runs**: one of the three options above; recommended a lesson flag
   `"live": false`.
4. **`html/lessons.js`**: insert `lesson.json` after `rubykaigi` (as 31) with
   the node parse/insert/renumber pattern (HANDOVER §3): the timelog track
   becomes 32-47, every "Lektion N"/"lesson N"/「レッスンN」 ≥ 31 shifts, and
   the lesson's own DSL reference (computed in `build_lesson.rb`) already
   says 44. Or insert after `jpeg` (pictures → sound) as 23 - more prose
   references to shift.
5. **Tests**: `test/check_harness.rb` gets a `show_audio` stub (as in
   `lesson_check.rb`) and `SOLUTIONS["musik"]` (the two de/en solutions from
   `lesson_check.rb`); `test/browser_test.mjs` `'46 lessons in nav'` → 47;
   a Playwright check that `#cell-out-N audio` appears and its
   `duration` > 0 (pattern in `measure_in_page.mjs`). The social card's
   lesson count (`tools/render_social_cards.mjs`), README "46 lessons".
6. **Companion gem** (`gem/chunky_bacon/lib/chunky_bacon/helpers.rb`): a
   `show_audio` shaped like its `show_pdf` - a path goes to
   `ChunkyBacon::Opener.open`, bytes or samples are written to a temp `.wav`
   and opened - so lesson code runs on a computer unchanged.
7. Optional: `wavefile` into the gem cache for offline installs.

Nothing here needs a new asset or a change to the offline file list.
