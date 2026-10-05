# Offline check of lesson.json, the way test/check_harness.rb checks a lesson:
# the demo cells run in one shared binding, the exercise starter must FAIL
# the check, every solution must PASS, and a few wrong answers must fail.
# Also times every cell under CRuby, and once more under a TracePoint like
# the one live runs use (html/autorun.rb), to see what the 1 s limit means.
#
# One language per process (top-level defs outlive a binding):
#   ruby experiments/05-ruby-music/lesson_check.rb de
#   ruby experiments/05-ruby-music/lesson_check.rb en
#   ruby experiments/05-ruby-music/lesson_check.rb ja
require "json"
require "stringio"
require "fileutils"
require_relative "../../html/browser_gems"
require_relative "../../html/sandbox_sim"

LANG = ARGV.fetch(0, "de")
HERE = __dir__
LESSON = JSON.parse(File.read(File.join(HERE, "lesson.json")))
WORK = File.join(HERE, "tmp_work_#{LANG}")
FileUtils.rm_rf(WORK)
FileUtils.mkdir_p(WORK)
at_exit { Dir.chdir(HERE); FileUtils.rm_rf(WORK) }
Dir.chdir(WORK)
SandboxFS.reset!

$audios = []
module Kernel
  # what main.rb's show_audio gets, recorded: WAV bytes, a file, or samples
  def show_audio(sound, rate: 22_050)
    bytes = if sound.is_a?(Array) then "RIFF(samples)"
            elsif sound.to_s.b.start_with?("RIFF") then sound.to_s
            elsif SandboxFS.virtual?(sound.to_s) && SandboxFS.exist?(sound.to_s) then SandboxFS.read(sound.to_s)
            else File.binread(sound.to_s)
            end
    raise "show_audio: not a WAV" unless bytes.b.start_with?("RIFF")

    $audios << bytes
    nil
  end
end

SOLUTIONS = {
  "de" => [
    "akkord = zusammen(*%w[C4 E4 G4 C5].map { |name| huelle(ton(frequenz(name), 1.0, :sinus, 0.2)) })\n" \
    "File.binwrite(\"tusch.wav\", wav(noten(\"C4 E4 G4 C5\") + akkord))",
    # File.write (the virtual store), square waves, a chord without envelope
    "akkord = zusammen(*%w[C4 E4 G4 C5].map { |n| ton(frequenz(n), 1.0, :rechteck, 0.15) })\n" \
    "File.write(\"tusch.wav\", wav(noten(\"C4 E4 G4 C5\", welle: :rechteck) + akkord))\nshow_audio \"tusch.wav\""
  ],
  "en" => [
    "chord = mix(*%w[C4 E4 G4 C5].map { |name| envelope(tone(frequency(name), 1.0, :sine, 0.2)) })\n" \
    "File.binwrite(\"fanfare.wav\", wav(notes(\"C4 E4 G4 C5\") + chord))",
    "chord = mix(*%w[C4 E4 G4 C5].map { |n| tone(frequency(n), 1.0, :saw, 0.15) })\n" \
    "File.write(\"fanfare.wav\", wav(notes(\"C4 E4 G4 C5\", wave: :saw) + chord))\nshow_audio \"fanfare.wav\""
  ]
}
SOLUTIONS["ja"] = SOLUTIONS["en"]

WRONG = {
  "de" => {
    "nur Töne, kein Akkord" => "File.binwrite(\"tusch.wav\", wav(noten(\"C4 E4 G4 C5 C5*4\")))",
    "falsche Reihenfolge" => "akkord = zusammen(*%w[C4 E4 G4 C5].map { |n| huelle(ton(frequenz(n), 1.0, :sinus, 0.2)) })\n" \
                             "File.binwrite(\"tusch.wav\", wav(noten(\"C5 G4 E4 C4\") + akkord))",
    "falscher Name" => "File.binwrite(\"fanfare.wav\", wav(noten(\"C4 E4 G4 C5 C5*4\")))",
    "nur Akkord, 2 s" => "File.binwrite(\"tusch.wav\", wav(zusammen(*%w[C4 E4 G4 C5].map { |n| huelle(ton(frequenz(n), 2.0, :sinus, 0.2)) })))"
  },
  "en" => {
    "notes only, no chord" => "File.binwrite(\"fanfare.wav\", wav(notes(\"C4 E4 G4 C5 C5*4\")))",
    "wrong order" => "chord = mix(*%w[C4 E4 G4 C5].map { |n| envelope(tone(frequency(n), 1.0, :sine, 0.2)) })\n" \
                     "File.binwrite(\"fanfare.wav\", wav(notes(\"C5 G4 E4 C4\") + chord))",
    "chord of three" => "chord = mix(*%w[C4 E4 G4].map { |n| envelope(tone(frequency(n), 1.0, :sine, 0.2)) })\n" \
                        "File.binwrite(\"fanfare.wav\", wav(notes(\"C4 E4 G4 C5\") + chord))",
    "chord only, 2 s" => "File.binwrite(\"fanfare.wav\", wav(mix(*%w[C4 E4 G4 C5].map { |n| envelope(tone(frequency(n), 2.0, :sine, 0.2)) })))"
  }
}
WRONG["ja"] = WRONG["en"]

def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# the live runs' TracePoint (autorun.rb): line, b_call and c_call events
def traced
  events = 0
  trace = TracePoint.new(:line, :b_call, :c_call) { events += 1 }
  result = trace.enable { yield }
  [result, events]
end

def run(code, bind, trace: false)
  watch = FileWatch.snapshot
  out = StringIO.new
  old = $stdout
  $stdout = out
  t0 = clock
  result, events = trace ? traced { eval(code, bind, "cell.rb") } : [eval(code, bind, "cell.rb"), 0]
  ms = (clock - t0) * 1000
  [result, out.string, FileWatch.changes_since(watch).map(&:first), ms, events]
ensure
  $stdout = old
end

def check(cell, bind, code)
  _result, output, downloads, = run(code, bind)
  bind.local_variable_set(:output, output)
  bind.local_variable_set(:result, nil)
  bind.local_variable_set(:code, code)
  bind.local_variable_set(:downloads, downloads)
  t0 = clock
  ok = !!eval(cell["check"], bind, "check.rb")
  [ok, (clock - t0) * 1000]
rescue Exception => e
  warn "    (#{e.class}: #{e.message[0, 120]})"
  [false, 0]
ensure
  FileUtils.rm_f(Dir.children(WORK))
  SandboxFS.reset!
end

def main
  cells = LESSON.fetch(LANG)["cells"]
  bind = TOPLEVEL_BINDING.eval("proc { binding }.call")
  failures = 0
  puts "#{LESSON[LANG]["title"]}"
  cells.each_with_index do |cell, idx|
    next unless cell["t"] == "c"

    before = $audios.size
    result, output, downloads, ms = run(cell["code"], bind)
    _r, _o, _d, traced_ms, events = run(cell["code"], bind, trace: true)
    printf("  cell %2d  %7.1f ms  (traced %7.1f ms, %8d events)  %d audio  %s\n",
           idx, ms, traced_ms, events, ($audios.size - before) / 2, downloads.any? ? "files: #{downloads.uniq.join(", ")}" : "=> #{result.inspect[0, 60]}")
    puts output unless output.empty?
  end

  exercise = cells.find { |c| c["t"] == "x" }
  ok, = check(exercise, bind, exercise["code"])
  puts "  starter fails:        #{ok ? "NO - FAIL" : "ok"}"
  failures += 1 if ok
  SOLUTIONS.fetch(LANG).each_with_index do |solution, n|
    ok, ms = check(exercise, bind, solution)
    printf("  solution %d passes:    %s  (check %.1f ms)\n", n + 1, ok ? "ok" : "NO - FAIL", ms)
    failures += 1 unless ok
  end
  WRONG.fetch(LANG).each do |name, wrong|
    ok, = check(exercise, bind, wrong)
    puts "  wrong (#{name}) fails: #{ok ? "NO - FAIL" : "ok"}"
    failures += 1 if ok
  end
  puts failures.zero? ? "ALL OK" : "#{failures} FAILURES"
  exit(failures.zero? ? 0 : 1)
end

main
