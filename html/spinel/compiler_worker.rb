# The compiler's worker (spinel/boot.js?role=compiler; the page's
# shell/spinel.rb starts one): spinel.wasm and clang (~27 MB gzipped) are
# fetched and compiled once, then every request is answered here, off the
# page's thread, one after the other.
#
#   <- up                                          (Ruby is running: send load)
#   -> {type: "load"}                <- progress {part, done, total}, ready {version} | failed {error}
#   -> {type: "build", id, source}   <- built {id, ok, stage, c, wasm, messages, ms_spinel, ms_clang}
#   -> {type: "parse", id, source}   <- parsed {id, verdict}   ("ok" | "more" | "error ...": IRB)
module SpinelCompilerWorker
  @queue = []
  @toolchain = nil
  @failed = nil

  def self.post(fields)
    message = JS.global[:Object].new
    fields.each { |key, value| message[key] = value }
    JS.global.postMessage(message)
  end

  # a message from the page, as Ruby values, for the loop below
  def self.take(data)
    @queue << { "type" => data[:type].to_s, "id" => data[:id], "source" => data[:source].to_s }
  end

  def self.progress(part, done, total)
    post("type" => "progress", "part" => part, "done" => done, "total" => total)
  end

  def self.load
    worker = SpinelCompilerWorker
    base = JS.global[:URL].new("../assets/spinel/", JS.global[:location][:href])[:href]
    @toolchain = SpinelToolchain.new(base).load(->(part, done, total) { worker.progress(part, done, total) })
    post("type" => "ready", "version" => @toolchain.version)
  rescue StandardError => e
    @failed = e.message.to_s
    post("type" => "failed", "error" => @failed)
  end

  def self.answer(request)
    if @toolchain.nil?
      fields = { "id" => request["id"], "ok" => false, "stage" => "load", "messages" => @failed || "not loaded" }
      fields["type"] = request["type"] == "parse" ? "parsed" : "built"
      fields["verdict"] = "error #{fields["messages"]}"
      return post(fields)
    end
    if request["type"] == "parse"
      post("type" => "parsed", "id" => request["id"], "verdict" => @toolchain.parse(request["source"]))
    else
      post({ "type" => "built", "id" => request["id"] }.merge(@toolchain.build(request["source"])))
    end
  rescue StandardError => e
    post("type" => request["type"] == "parse" ? "parsed" : "built", "id" => request["id"], "ok" => false,
         "stage" => "load", "messages" => e.message.to_s, "verdict" => "error #{e.message}")
  end

  # one request after the other (a build awaits clang), in one Task
  def self.serve
    loop do
      request = @queue.shift
      if request.nil?
        sleep_ms(5)
      elsif request["type"] == "load"
        SpinelCompilerWorker.load if @toolchain.nil?
      else
        SpinelCompilerWorker.answer(request)
      end
    end
  end
end

JS.global.addEventListener("message", sync: true) { |event| SpinelCompilerWorker.take(event[:data]) }
Task.new { SpinelCompilerWorker.serve }
SpinelCompilerWorker.post("type" => "up")
