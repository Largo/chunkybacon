# Runs one program Spinel built (spinel/boot.js?role=run; shell/spinel.rb
# starts a worker per run and stops it when the time is up: an endless loop
# cannot be interrupted any other way). What the program prints is sent as
# it is printed.
#
#   <- up
#   -> {wasm, stdin}   <- {type: "out", fd, text} ..., {type: "done", code, ms} | {type: "crashed", error}
module SpinelRunWorker
  def self.post(fields)
    message = JS.global[:Object].new
    fields.each { |key, value| message[key] = value }
    JS.global.postMessage(message)
  end

  def self.run(data)
    stream = JS.global[:Object].new
    stream[:stream] = true
    decoders = { 1 => JS.global[:TextDecoder].new, 2 => JS.global[:TextDecoder].new }
    worker = SpinelRunWorker
    sender = ->(fd) { ->(bytes) { worker.post("type" => "out", "fd" => fd, "text" => decoders[fd].decode(bytes, stream)) } }
    stdin = JS.global[:TextEncoder].new.encode(data[:stdin].to_s)
    started = JS.global[:performance].now
    begin
      wasm = JS.global[:WebAssembly][:Module].new(data[:wasm])
      result = SpinelWasi.run(wasm, args: ["main"], stdin: stdin, out: sender.call(1), err: sender.call(2))
      post("type" => "done", "code" => result["code"], "ms" => JS.global[:performance].now - started)
    rescue StandardError => e
      # a trap: out of memory, the stack, unreachable code
      post("type" => "crashed", "error" => e.message.to_s)
    end
  end
end

JS.global.addEventListener("message", sync: true) { |event| SpinelRunWorker.run(event[:data]) }
SpinelRunWorker.post("type" => "up")
