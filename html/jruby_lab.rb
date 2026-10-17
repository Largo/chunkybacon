# The JRuby side of the JRuby lesson ("engine": "jruby", docs/HANDOVER.md
# §6r). jruby_worker.js evaluates this once, inside JRuby 10.1 (TeaVM), right
# after the boot; then every cell is a call of ChunkyLab.run.
#
# TeaVM JRuby evaluates each request in a scope of its own, so a local from
# one cell would be gone in the next: the cells run in one binding of their
# own here, as main.rb's do in CRuby (TopLevel.binding), under the same file
# name, so the line of an error is the cell's line. The answer is one line
# after what the cell printed, behind a \u0001: the worker cuts it off.
require "json"
require "stringio"

module ChunkyLab
  FILE = "chunky.rb"
  MARK = "\u0001"
  INSPECT_MAX = 20_000

  @bind = nil

  # the lesson's files are where CRuby has them: data/ (the zip at /data)
  Dir.chdir("/")

  # a new lesson page, or ↺: no variables left
  def self.fresh
    @bind = TOPLEVEL_BINDING.eval("binding")
    nil
  end

  # +quiet+: one of the cells above, run first - its output goes nowhere
  def self.run(code, quiet = false)
    fresh unless @bind
    old = $stdout
    $stdout = StringIO.new if quiet
    fields = begin
      value = eval(code, @bind, FILE, 1)
      { status: "ok", inspect: inspect_of(value) }
    rescue Exception => e # rubocop:disable Lint/RescueException - the learner's code, all of it
      { status: "error", errorClass: e.class.name.to_s, line: line_of(e), message: e.message.to_s }
    end
    $stdout = old
    answer(fields)
  end

  def self.inspect_of(value)
    text = value.inspect.to_s
    text.length > INSPECT_MAX ? "#{text[0, INSPECT_MAX]}…" : text
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#<#{value.class} (inspect failed: #{e.class})>"
  end

  # the first line of the cell in the backtrace (a Java exception's too)
  def self.line_of(error)
    (error.backtrace || []).each do |entry|
      line = entry.to_s[/\A#{Regexp.escape(FILE)}:(\d+)/o, 1]
      return line.to_i if line
    end
    0
  end

  def self.answer(fields)
    # $stdout, not STDOUT: the worker reads what $stdout got (Main.rubyEval)
    $stdout.print(MARK + JSON.generate(fields))
    $stdout.flush
    nil
  end
end
