# Spinel in the browser: Ruby -> C -> WebAssembly, the steps `spinel app.rb`
# takes on a computer, each one WebAssembly here (html/assets/spinel/, built
# by tools/build_spinel.mjs on deploy). Ruby on PicoRuby.wasm in the
# compiler's worker (spinel/compiler_worker.rb):
#
#   1. spinel.wasm, the compiler, reads /work/main.rb and writes /work/main.c
#      (-c --print-build: the C, and the ingredients cc would get)
#   2. clang (@yowasp/clang) compiles and links that C with Spinel's runtime
#      archive into a module for wasm32-wasi
#
# The module runs in a worker of its own (spinel/run_worker.rb), so that an
# endless loop can be stopped. The parts that are plain Ruby - what
# --print-build says, the clang command line, the messages - are SpinelBuild's
# and tested under CRuby (test/spinel_build_test.rb).
module SpinelBuild
  ARGV0 = "/spinel/bin/spinel"
  KINDS = %w[cflag include define lib link].freeze

  module_function

  # a path with its "dir/.." pairs taken out (YoWASP's filesystem has no "..")
  def normalize(path)
    loop do
      at = path.index("/../")
      at = path.length - 3 if at.nil? && path.end_with?("/..")
      return path if at.nil?

      start = at - 1
      start -= 1 while start >= 0 && path[start] != "/"
      return path if start < 0

      path = path[0, start] + path[at + 3, path.length]
      path = "/" if path.empty?
    end
  end

  # what --print-build said, one "kind value" a line
  def parse_build(text)
    build = { "source" => nil, "runtime" => nil }
    KINDS.each { |kind| build[kind] = [] }
    text.split("\n").each do |line|
      at = line.index(" ")
      next if at.nil?

      kind = line[0, at]
      value = normalize(line[at + 1, line.length])
      if kind == "source" || kind == "runtime"
        build[kind] = value
      elsif build[kind]
        build[kind] << value
      end
    end
    build
  end

  # the clang command line: Spinel's own flags (src/main.c), the page's
  # header (lib/wasi/sp_page.h) first, warnings off - they are about the
  # generated C - and a link that fails on a signature mismatch
  def clang_args(build, output)
    args = ["clang", "--target=wasm32-wasip1", "-O2", "-w", "-include", "/spinel/lib/wasi/sp_page.h"]
    args.concat(build["cflag"])
    build["include"].each { |dir| args << "-I#{dir}" }
    args.concat(build["define"])
    args << build["source"]
    args.concat(build["link"])
    args << build["runtime"]
    args.concat(build["lib"])
    args.concat(["-Wl,--fatal-warnings", "-o", output])
  end

  # "spinel: /work/main.rb:3: ..." -> "main.rb:3: ..." (the learner's names)
  def tidy(text)
    lines = text.to_s.gsub("/work/", "").split("\n").map { |line| line.start_with?("spinel: ") ? line[8, line.length] : line }
    lines.join("\n").strip
  end

  # Spinel's parser on an IRB input (spinel --dump-ast): "ok", "more" (it
  # ends inside a def, a string, a bracket - IRB waits for the next line)
  # or "error <the first message>"
  def verdict(code, stderr)
    return "ok" if code == 0
    return "more" if stderr.include?("unexpected end-of-input") || stderr.include?("meets end of file")

    first = stderr.split("\n").map(&:strip).find { |line| line.start_with?("/work/main.rb:") }
    "error #{first ? first.sub("/work/main.rb:", "(irb):") : tidy(stderr)}"
  end

  # the elapsed milliseconds since +started+ (performance.now)
  def since(started) = JS.global[:performance].now - started
end

class SpinelToolchain
  attr_reader :version

  # base: where html/assets/spinel/ is (a URL)
  def initialize(base)
    @base = base
    @version = nil
    @compiler = nil
    @files = nil
    @clang = nil
    @clang_output = nil
  end

  def url(path) = JS.global[:URL].new(path, @base)[:href]

  # A file of the build, as JavaScript has it (the bytes never become a Ruby
  # String). A worker may wait for a request: XMLHttpRequest synchronously,
  # because PicoRuby's own fetch answers Ruby strings. type: "arraybuffer" | "json"
  def get(path, type)
    request = JS.global[:XMLHttpRequest].new
    request.open("GET", url(path), false)
    request[:responseType] = type
    request.send
    raise "#{path}: HTTP #{request[:status]}" unless request[:status] == 200

    request[:response]
  end

  # Everything fetched and compiled once; in a Task (it awaits).
  # progress.call(part, done, total) while clang (75 MB) comes in.
  def load(progress)
    manifest = get("manifest.json", "json")
    @base = url("#{manifest[:dir]}/")
    spinel = manifest[:spinel]
    @version = "#{spinel[:date]} (#{spinel[:commit].to_s[0, 7]})"
    @compiler = JS.global[:WebAssembly].compile(get("spinel.wasm", "arraybuffer")).await
    progress.call("spinel", 0, 0)
    @files = SpinelWasi::MemFS.new
    @files.add_tar(JS.global[:Uint8Array].new(get("spinel-files.tar", "arraybuffer")), "/spinel/")
    @files.write_text(SpinelBuild::ARGV0, "")   # resolve_lib_dir looks beside argv[0]
    @clang = JS.global.importModule(url("clang/bundle.js")).await
    JS::Object.register_callback("spinelClangProgress") do |status|
      progress.call("clang", status[:doneLength], status[:totalLength])
      nil
    end
    # what clang says while it compiles (link): one callback, registered once
    toolchain = self
    JS::Object.register_callback("spinelClangOutput") do |bytes|
      toolchain.clang_said(bytes)
      nil
    end
    options = JS.global[:Object].new
    options[:fetchProgress] = JS.generic_callbacks[:spinelClangProgress]
    # fetches and compiles clang with its sysroot (runLLVM(null): nothing to run yet)
    @clang.runLLVM(nil, JS.global[:Object].new, options).await
    self
  end

  def clang_said(bytes)
    @clang_output << JS.global[:TextDecoder].new.decode(bytes) unless bytes.nil? || @clang_output.nil?
  end

  def spinel(fs, args)
    SpinelWasi.run(@compiler, args: [SpinelBuild::ARGV0] + args, fs: fs)
  end

  # Spinel's parser alone (IRB: is the input complete?)
  def parse(source)
    fs = @files.clone
    fs.write_text("/work/main.rb", source)
    result = spinel(fs, ["--dump-ast", "/work/main.rb"])
    SpinelBuild.verdict(result["code"], result["stderr"])
  end

  # 1. Ruby -> C: {"ok", "c", "build", "messages", "ms", "fs"}
  def compile(source)
    fs = @files.clone
    fs.write_text("/work/main.rb", source)
    started = JS.global[:performance].now
    result = spinel(fs, ["--target=wasm32-wasi", "--cc=clang", "-c", "--print-build", "/work/main.rb", "-o", "/work/main.c"])
    ms = SpinelBuild.since(started)
    messages = SpinelBuild.tidy(result["stderr"].sub("Wrote /work/main.c\n", "").sub("Wrote /work/main.c", ""))
    return { "ok" => false, "messages" => messages, "ms" => ms } unless result["code"] == 0

    { "ok" => true, "c" => fs.read_text("/work/main.c"), "build" => SpinelBuild.parse_build(result["stdout"]),
      "messages" => messages, "ms" => ms, "fs" => fs }
  end

  # 2. C -> a WebAssembly module (a Uint8Array); in a Task (clang is a promise)
  def link(compiled)
    started = JS.global[:performance].now
    chunks = @clang_output = []
    args = JS.global[:Array].new
    SpinelBuild.clang_args(compiled["build"], "/work/main.wasm").each { |arg| args.push(arg) }
    tree = JS.global[:Object].new
    tree[:spinel] = SpinelWasi::MemFS.js_tree(compiled["fs"].lookup("/spinel"))
    tree[:work] = SpinelWasi::MemFS.js_tree(compiled["fs"].lookup("/work"))
    options = JS.global[:Object].new
    options[:stdout] = JS.generic_callbacks[:spinelClangOutput]
    options[:stderr] = JS.generic_callbacks[:spinelClangOutput]
    begin
      result = @clang.runClang(args, tree, options).await
      { "ok" => true, "wasm" => result[:work]["main.wasm"], "messages" => SpinelBuild.tidy(chunks.join),
        "ms" => SpinelBuild.since(started) }
    rescue StandardError => e
      text = chunks.join
      { "ok" => false, "messages" => SpinelBuild.tidy(text.empty? ? e.message : text), "ms" => SpinelBuild.since(started) }
    end
  end

  # both: {"ok", "stage" ("spinel" | "clang"), "c", "wasm", "messages", "ms_spinel", "ms_clang"}
  def build(source)
    compiled = compile(source)
    return { "ok" => false, "stage" => "spinel", "messages" => compiled["messages"], "ms_spinel" => compiled["ms"] } unless compiled["ok"]

    linked = link(compiled)
    answer = { "ok" => linked["ok"], "stage" => linked["ok"] ? nil : "clang", "c" => compiled["c"],
               "ms_spinel" => compiled["ms"], "ms_clang" => linked["ms"] }
    answer["wasm"] = linked["wasm"] if linked["ok"]
    answer["messages"] = linked["ok"] ? compiled["messages"] : linked["messages"]
    answer
  end
end
