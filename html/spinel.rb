# The Spinel lesson's Ruby side (lesson 39). Spinel, Matz's ahead-of-time
# compiler for Ruby, runs in the page as WebAssembly (spinel.js and its
# workers; tools/build_spinel.mjs builds it on deploy). A cell hands it a
# program as a String:
#
#   spinel <<~RUBY
#     def fib(n) = n < 2 ? n : fib(n - 1) + fib(n - 2)
#     puts fib(27)
#   RUBY
#
# The page compiles and runs it below the cell, and CRuby - the Ruby the
# lesson runs on - runs the same program here first, the way `spin test`
# takes CRuby for the oracle: its output is shown beside Spinel's, and it is
# what a check sees (result.output). Plain Ruby, no JS: the check harness
# runs it as it is.
module ChunkySpinel
  # what spinel(...) answers: the program and how CRuby ran it
  Program = Struct.new(:source, :output, :error, :ms) do
    def ok? = error.nil?

    def inspect = "#<Spinel::Program #{source.lines.size} lines>"
    alias_method :to_s, :inspect
  end

  # the texts of the widgets (lessons.js ui), by spinel.js's names
  LABELS = {
    "title" => "spinelTitle", "load" => "spinelLoad", "compile" => "spinelCompile", "link" => "spinelLink",
    "run" => "spinelRun", "showC" => "spinelShowC", "download" => "spinelDownload",
    "downloadTitle" => "spinelDownloadTitle", "same" => "spinelSame", "differs" => "spinelDiffers",
    "crubyError" => "spinelCrubyError", "crubyOnly" => "spinelCrubyOnly", "refused" => "spinelRefused", "ccFailed" => "spinelCcFailed",
    "stopped" => "spinelStopped", "crashed" => "spinelCrashed", "exit" => "spinelExit",
    "failed" => "spinelFailed", "offline" => "spinelOffline",
    "irbTitle" => "spinelIrbTitle", "irbInput" => "spinelIrbInput", "irbNote" => "spinelIrbNote",
    "irbReady" => "spinelIrbReady", "irbBusy" => "spinelIrbBusy", "irbExit" => "irbExitNote"
  }.freeze

  # the end of the input that IRB waits past (main.rb's INCOMPLETE_RE, in Prism's words)
  INCOMPLETE = /unexpected end-of-input|expected an? `?end`?|unterminated (string|regexp|list)|expects an expression after|expected a matching `?\)`?|expected a `?\}`?|expected a `?\]`?/i

  module_function

  # CRuby runs the program in a scope of its own, its output captured
  def oracle(source, file: "(spinel)")
    raise ArgumentError, "spinel takes the program as a String: spinel <<~RUBY ... RUBY" unless source.is_a?(String)

    scope = defined?(TopLevel) ? TopLevel.binding(file) : TOPLEVEL_BINDING.dup
    old_stdout = $stdout
    $stdout = StringIO.new
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = nil
    begin
      eval(source, scope, file, 1)
    rescue Exception => e
      raise if defined?(AutoRun::Stopped) && e.is_a?(AutoRun::Stopped)

      error = "#{e.class}: #{e.message.lines.first.to_s.strip}"
    ensure
      output = $stdout.string
      $stdout = old_stdout
    end
    ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    Program.new(source, output, error, ms)
  end

  # IRB's question about an input: "ok" (compile it), "more" (an open def,
  # string, bracket) or "error <message>" (a syntax error: no compile needed)
  def complete(source)
    return "ok" if source.strip.empty?

    errors = Prism.parse(source).errors
    return "ok" if errors.empty?
    return "more" if errors.any? { |e| e.message.match?(INCOMPLETE) }

    first = errors.first
    "error (irb):#{first.location.start_line}: #{first.message}"
  end

  def labels(ui) = LABELS.transform_values { |key| ui[key].to_s }

  # what spinel.js gets for a program
  def widget_json(program, ui, lang)
    JSON.generate(source: program.source, lang: lang, labels: labels(ui),
                  cruby: { output: program.output, error: program.error, ms: program.ms.round(1) })
  end
end

require "prism"
require "json"
require "stringio"

module Kernel
  # Hands +source+ to Spinel: compiled and run below the cell, and run by
  # CRuby here; answers how CRuby ran it (a ChunkySpinel::Program: output,
  # error, ms). Without the page (a test) it is just that run.
  def spinel(source)
    program = ChunkySpinel.oracle(source)
    ChunkyApp.instance.add_spinel(program) if defined?(ChunkyApp) && ChunkyApp.respond_to?(:instance)
    program
  end

  # IRB on Spinel below the cell: every line compiled with the ones before it
  def show_spinel_irb
    ChunkyApp.instance.add_spinel_irb if defined?(ChunkyApp) && ChunkyApp.respond_to?(:instance)
    nil
  end
end
