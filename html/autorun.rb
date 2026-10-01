# Live runs: a cell (or the workshop's program) runs by itself a moment after
# the learner stops typing (the shell decides when; shell/app.rb). Such a run
# is a rehearsal, so half-typed code cannot do harm:
#
# - it starts only for code that parses, and not for the loops the time
#   limit cannot see because they make no TracePoint events at all: a
#   while/until whose body is empty or only comments, and a one-line
#   modifier loop (`x += 1 while true`, `begin ... end while`)
# - it keeps nothing: files it writes are taken back, the workshop writes
#   nothing into the project; gems are installed only from the cache and
#   nothing is fetched from the web
# - it stops after LIMIT seconds of the learner's own code; gem code and the
#   page's own code are never cut off (a half-loaded gem would break every
#   later run), and installing a cached gem or loading a library (require)
#   does not count towards the LIMIT
#
# A run with the Run button is the real thing and none of this applies.
module AutoRun
  LIMIT = 1.0

  # Exceptions, not StandardErrors: a `rescue => e` in the learner's code
  # must not swallow them.
  class Stopped < Exception; end
  class NeedsRun < Exception; end

  # "while x < 3\nend", "until done; end", "while true do end",
  # "while x\n  # wait\nend"
  EMPTY_LOOP = /\b(?:while|until)\b[^\n;]*?(?:;|\n|\bdo\b)(?:\s|;|#[^\n]*)*end\b/
  # "x += 1 while true", "end until done" - a loop keyword after something
  # else on its line (not after a `;`, not in a comment)
  MODIFIER_LOOP = /^[^#\n]*[^\s;#][ \t]+(?:while|until)\b/

  class << self
    # +locals+: the binding's local variables - `x /2` parses differently
    # when x is one
    def runnable?(code, locals = [])
      return false if code.strip.empty? || code.include?("show_irb")
      return false if code.match?(EMPTY_LOOP) || code.match?(MODIFIER_LOOP)

      RubyVM::InstructionSequence.compile(locals.map { |name| "#{name} = nil\n" }.join + code)
      true
    rescue SyntaxError
      false
    end

    # Runs the block, raising Stopped once the learner's own code (lines in
    # +paths+) has run longer than +seconds+.
    def with_time_limit(paths, seconds = LIMIT)
      @deadline = clock + seconds
      events = 0
      # c_call too: a one-line `while true do x += 1 end` makes no line
      # events, but its Integer#+ does
      @trace = TracePoint.new(:line, :b_call, :c_call) do |tp|
        events += 1
        raise Stopped if (events & 127).zero? && paths.include?(tp.path) && clock > @deadline
      end
      @trace.enable { yield }
    ensure
      @trace = nil
    end

    # Page code that must not be cut off (installing a gem, loading a
    # library), off the clock: the deadline moves by its time. Live or not,
    # that time adds up in library_time - a cell is not slow because its
    # first run installed and loaded a gem (main.rb, finish_cell_run).
    def untraced
      return yield if @untraced

      @untraced = true
      started = clock
      begin
        @trace ? @trace.disable { yield } : yield
      ensure
        spent = clock - started
        @deadline += spent if @trace
        @library_time = library_time + spent
        @untraced = false
      end
    end

    attr_writer :library_time

    def library_time = @library_time || 0.0

    # Files a rehearsal created on the real filesystem (File.binwrite,
    # ChunkyPNG#save) go again; virtual ones come back with SandboxFS.store.
    def take_back(changes, watch)
      _virtual, real = watch
      changes.each do |path, _bytes|
        full = File.join(Dir.pwd, path)
        File.delete(full) if !real.key?(path) && File.file?(full)
      rescue SystemCallError
        nil
      end
    end

    private

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

# a library loads off the clock, and whole (as in BrowserGems, the hook
# stays public)
module Kernel
  alias_method :autorun_original_require, :require
  def require(path)
    AutoRun.untraced { autorun_original_require(path) }
  end
end
