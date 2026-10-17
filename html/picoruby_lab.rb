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
#
# The Pico lessons (§6r): a cell's tabs are files in /lib, written by
# picoruby_worker_core.js before the run, and `require "epd2in13"` finds
# them as on R2P2 ($LOAD_PATH below). A run with a board (PicoBoard.config,
# the cell's "board") first loads the simulator (html/pico_sim/, written to
# /sim) once, sets the world up for the cell's parts, and lets a ticker Task
# hand the bench its state while the cell runs; the world's summary goes
# back with the answer (PicoBoard.summary), for the exercise's check.

# libraries of the cells' tabs (and the require stubs) live here, as on R2P2
$LOAD_PATH = ["/lib"]

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

  def initialize(pico, board)
    @pico = pico
    @board = board
    @boxes = {}
    @sim = false
    @stubs = nil
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

    reload_tabs
    ticker = start_board
    sandbox.execute
    sleep_ms 1 until finished?(sandbox)
    # stdout reaches JavaScript a line at a time: this ends the line a
    # `print` left open, with a mark picoruby_worker.js takes out again
    puts END_MARK
    value = sandbox.result
    sandbox.suspend
    "#{describe(value)}\t#{$chunky_irbs}"
  ensure
    stop_board(ticker) if ticker
  end

  # A tab edited since the last run is loaded again: require loads a file
  # once, so its entry goes - not the stubs' ("require 'gpio'" stays cheap)
  def reload_tabs
    @stubs ||= @board.stubs.to_s.split("\n").map { |name| "/lib/#{name}.rb" }
    stubs = @stubs
    $LOADED_FEATURES.delete_if { |path| path.to_s.start_with?("/lib/") && !stubs.include?(path.to_s) }
  end

  # A run with a board: the simulator once (the files picoruby_worker_core
  # wrote to /sim, in manifest order), the world for this cell's parts, and
  # a Task that hands the bench the world's state every 33 ms. nil without.
  def start_board
    config = @board.config.to_s
    return nil if config == ""

    unless @sim
      @board.simFiles.to_s.split("\n").each { |path| require path }
      @sim = true
    end
    PicoSim.setup(JSON.parse(config))
    Task.new(name: "pico-board", priority: 200) { PicoSim.tick_loop }
  end

  def stop_board(ticker)
    ticker.terminate
    PicoSim.finish
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

  # the cell's line the error came from, "" when unknown; "epd2in13.rb:12"
  # when it came from a tab (/lib/epd2in13.rb) - the first frame in either
  def line_of(error)
    trace = error.backtrace
    return "" unless trace
    trace.each do |frame|
      at = frame.index("picoruby.rb:")
      return frame[(at + 12)..-1].to_i.to_s if at
      at = frame.index("/lib/")
      next unless at
      rest = frame[(at + 5)..-1]
      colon = rest.index(".rb:")
      next unless colon
      name = rest[0, colon + 3]
      next if (@stubs || []).include?("/lib/#{name}")
      return "#{name}:#{rest[(colon + 4)..-1].to_i}"
    end
    ""
  end

  def drop(sid)
    sandbox = @boxes.delete(sid)
    sandbox.terminate if sandbox
  end
end

ChunkyLab.new(JS.global[:PicoLab], JS.global[:PicoBoard]).serve
