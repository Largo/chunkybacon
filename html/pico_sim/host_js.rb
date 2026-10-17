# The simulator's host in the lesson's worker (docs/HANDOVER.md §6r):
# PicoBoard, the JavaScript object picoruby_worker_core.js puts on
# globalThis. Every argument and answer is a String (PicoRuby's bridge
# drops escapes in mixed calls, docs/PICORUBY_SHELL.md §5 #4). The check
# harness has its own host (test/pico_cruby_host.rb).
module PicoSim
  class HostJS
    def initialize
      @board = JS.global[:PicoBoard]
    end

    # ms since the run started (performance.now in the worker)
    def now_ms = @board.now.to_s.to_f

    def input(key) = @board.input(key.to_s).to_s

    def post(kind, text)
      @board.post(kind.to_s, text.to_s)
      nil
    end

    def summary(text)
      @board.summary(text.to_s)
      nil
    end

    def http(method, url, headers, body) = @board.http(method.to_s, url.to_s, headers.to_s, body.to_s).to_s

    def camera_hex(name) = @board.cameraHex(name.to_s).to_s

    # a busy loop that reads inputs gives the worker's event loop a turn
    # every 10 ms (inputs and frames still arrive, the page stays live)
    def breathe
      sleep_ms 1 if @board.busy.to_s.to_f > 10
    end
  end
end
