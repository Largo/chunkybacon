# The Spinel lesson's kernel side (lesson 45). Spinel, Matz's ahead-of-time
# compiler for Ruby, runs in the page as WebAssembly (shell/spinel.rb and its
# workers, html/spinel/; tools/build_spinel.rb builds it on deploy). A cell
# hands it a program as a String:
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
end

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
