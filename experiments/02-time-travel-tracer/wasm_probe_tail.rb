
# --- appended after step_recorder.rb by wasm_probe.mjs: runs in a lesson
# cell on ruby.wasm (the cell's own eval is "chunky.rb"; the stepped runs use
# "stepped.rb" with a fresh binding, so they do not see this cell's locals)
def __clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

__programs = {
  "3.times" => "3.times do |i|\n  puts \"Streifen Nummer \#{i + 1}\"\nend\n",
  "map+def" => "def quadrat(zahl)\n  ergebnis = zahl * zahl\n  ergebnis\nend\nzahlen = [1, 2, 3]\nquadrate = zahlen.map { |z| quadrat(z) }\n",
  "while200" => "summe = 0\nzahl = 1\nwhile zahl <= 200\n  summe += zahl\n  zahl += 1\nend\nsumme\n",
  "fib15" => "def fib(n)\n  n < 2 ? n : fib(n - 1) + fib(n - 2)\nend\nfib(15)\n",
  "100k" => "s = 0\n1.upto(100_000) do |i|\n  s += i\nend\ns\n",
  "error" => "preise = [3, 5, nil, 2]\ntotal = 0\npreise.each do |p|\n  total += p\nend\n"
}
__report = []
__programs.each do |__name, __code|
  __b = eval("proc { binding }.call", TOPLEVEL_BINDING)
  __t = __clock
  begin
    __saved = $stdout
    $stdout = StringIO.new
    eval(__code, __b, "stepped.rb")
  rescue StandardError
    nil
  ensure
    $stdout = __saved
  end
  __plain = (__clock - __t) * 1000
  __b = eval("proc { binding }.call", TOPLEVEL_BINDING)
  __rec = StepRecorder.new(__code, file: "stepped.rb", hide: TOPLEVEL_BINDING.local_variables)
  __t = __clock
  begin
    __saved = $stdout
    $stdout = StringIO.new
    __rec.run { eval(__code, __b, "stepped.rb") }
  rescue StandardError
    nil
  ensure
    $stdout = __saved
  end
  __ms = (__clock - __t) * 1000
  __t = __clock
  __tr = __rec.trace
  __tms = (__clock - __t) * 1000
  __t = __clock
  __json = JSON.generate(__tr)
  __jms = (__clock - __t) * 1000
  __report << format("%-8s plain %7.2f ms  recorded %7.2f ms  steps %4d  trace %6.2f ms  json %6.1f KB in %6.2f ms  traced=%s truncated=%s err=%s last=%s",
                     __name, __plain, __ms, __tr[:steps].length, __tms, __json.bytesize / 1024.0, __jms,
                     __tr[:traced], __tr[:truncated], __tr[:error].inspect, __tr[:steps].last&.slice(:event, :line, :value).inspect)
end
puts "RUBY_PLATFORM=#{RUBY_PLATFORM} #{RUBY_VERSION}"
puts __report
