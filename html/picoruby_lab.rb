# The PicoRuby lesson's Ruby (docs/HANDOVER.md §6m): runs on a PicoRuby.wasm
# of its own, in a Web Worker (picoruby_worker.js) - not the page's shell.
# Each session is a Sandbox (picoruby-sandbox, what PicoRuby's own IRB uses):
# the lesson's cells share one, every IRB below a cell has its own. A
# Sandbox remembers the local variables of its last run for the next
# compile, so `x = 1` in one cell is `x` in the next - a notebook.
#
# This is a Task that never ends: it takes requests from picoruby_worker.js
# (PicoLab.take) and answers them (PicoLab.answer), while JavaScript turns
# PicoRuby's scheduler. Not callbacks: a Sandbox starts a Task, and PicoRuby
# allows no Task API inside a callback JavaScript calls synchronously. No
# time limit here either: a run that never ends never lets this Task look
# again - the page ends the whole worker instead (picoruby_lab.js).
#
#   "run\t<sid>\t<code>"  -> "ok\t<inspect>\t<irbs>"
#                            "error\t<class>\t<line>\t<message>\t<irbs>"
#                            "syntax\t"  (PicoRuby's compiler says no more;
#                                         main.rb has Prism's message first)
#   "drop\t<sid>"         -> "dropped"
#
# Plain strings only: PicoRuby hands JavaScript no Hash or Array.

# what a cell may call besides plain Ruby: an IRB below it (main.rb draws it)
$chunky_irbs = 0
def show_irb
  $chunky_irbs += 1
  nil
end

# no keyboard in a worker: PicoRuby's gets would wait for one until the
# time limit (it asks window.prompt, which a worker does not have)
def gets(*)
  nil
end

class ChunkyLab
  # The cell's code goes in as in PicoRuby's own IRB (picoruby-shell): its
  # value or its exception lands in `_`. The newline keeps a comment on the
  # last line from swallowing the parenthesis; line 1 stays line 1.
  WRAP_HEAD = "begin; _ = ("
  WRAP_TAIL = "\n); rescue Exception => _; end; _"
  END_MARK = "\x01"

  def initialize(pico)
    @pico = pico
    @boxes = {}
  end

  def serve
    while true
      request = @pico.take
      if request.nil?
        sleep_ms 1
      else
        @pico.answer(handle(request.to_s))
      end
    end
  end

  def handle(request)
    kind, sid, code = request.split("\t", 3)
    if kind == "run"
      run(sid, code.to_s)
    else
      drop(sid)
      "dropped"
    end
  rescue Exception => e
    "error\t#{e.class}\t\tthe lab: #{e.message}\t0"
  end

  def run(sid, code)
    $chunky_irbs = 0
    sandbox = (@boxes[sid] ||= Sandbox.new("lab#{sid}"))
    return "syntax\t" unless sandbox.compile(WRAP_HEAD + code + WRAP_TAIL, filename: "picoruby.rb")

    sandbox.execute
    sleep_ms 1 until finished?(sandbox)
    # stdout reaches JavaScript a line at a time: this ends the line a
    # `print` left open, with a mark picoruby_worker.js takes out again
    puts END_MARK
    value = sandbox.result
    sandbox.suspend
    "#{describe(value)}\t#{$chunky_irbs}"
  end

  def finished?(sandbox)
    state = sandbox.state
    state == :DORMANT || state == :SUSPENDED
  end

  def describe(value)
    if value.is_a?(Exception)
      "error\t#{value.class}\t#{line_of(value)}\t#{value.message}"
    else
      shown = value.inspect
      shown = shown[0, 2000] + "…" if shown.length > 2000
      "ok\t#{shown}"
    end
  end

  # the cell's line the error came from, "" when unknown
  def line_of(error)
    trace = error.backtrace
    return "" unless trace
    trace.each do |frame|
      at = frame.index("picoruby.rb:")
      return frame[(at + 12)..-1].to_i.to_s if at
    end
    ""
  end

  def drop(sid)
    sandbox = @boxes.delete(sid)
    sandbox.terminate if sandbox
  end
end

ChunkyLab.new(JS.global[:PicoLab]).serve
