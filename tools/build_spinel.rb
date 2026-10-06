# Builds Spinel (Matz's Ruby AOT compiler, github.com/matz/spinel) for the
# browser into html/assets/spinel/ - not committed: the deploy runs this, and
# it does nothing when the build there is the one tools/spinel.json pins.
#
#   ruby tools/build_spinel.rb            # build if the pins or this tool changed
#   ruby tools/build_spinel.rb --check    # exit 1 if html/assets/spinel/ is not current
#   ruby tools/build_spinel.rb --force    # build even if it is current
#   ruby tools/build_spinel.rb --update   # pin matz/spinel's newest commit, then build
#   ruby tools/build_spinel.rb --jobs 4   # clang processes (default: cores - 1, at most 8; or SPINEL_JOBS)
#
# What the lesson runs (html/shell/spinel.rb and its workers, html/spinel/:
# Ruby on PicoRuby.wasm), all WebAssembly in the learner's tab:
#
#   Ruby --spinel.wasm--> C --clang (@yowasp/clang)--> app.wasm --> run
#
# spinel.wasm is Spinel's own C (src/, libprism, its regexp engine) compiled
# for wasm32-wasi; spinel-files.tar is what it reads beside itself (builtins/,
# packages/, lib/ with the runtime's headers) plus the runtime archive
# lib/wasm32-wasi/libspinel_rt.a and the bundled packages' *_wasi.o, which
# `make wasm-rt` builds in Spinel's tree. clang/ is YoWASP's Clang/LLD for
# WebAssembly, itself WebAssembly; its sysroot tar is cut down to what a C
# program for wasm32-wasip1 needs.
#
# The build uses the very clang the page does: YoWASP's llvm.core.wasm is a
# WASI command, which Ruby runs here through the wasmtime gem (pinned in
# tools/spinel.json, installed into .cache/spinel/gems when it is missing;
# prebuilt for Linux, macOS and Windows) - no C compiler, no Node. The
# compiled module is kept (.cwasm), and the compiles run in child processes
# of this script (`--worker`): wasmtime holds Ruby's GVL while wasm runs.
#
# Everything is fetched by version and checked: the Spinel commit as a
# GitHub tarball, the prism gem from rubygems.org (Spinel's `make deps`
# takes the same), the npm tarball against the registry's sha512. Downloads,
# the unpacked tree and every compiled object are kept in .cache/spinel/
# (gitignored) for the next run.
require "json"
require "digest"
require "fileutils"
require "net/http"
require "uri"
require "zlib"
require "stringio"
require "etc"
require "rbconfig"
require "time"

module BuildSpinel
  ROOT = File.expand_path("..", __dir__)
  PINS_FILE = File.join(ROOT, "tools", "spinel.json")
  CACHE = File.join(ROOT, ".cache", "spinel")
  TARGET = File.join(ROOT, "html", "assets", "spinel")   # <stamp>/ and manifest.json
  SELF = File.expand_path(__FILE__)
  AGENT = "chunkybacon-build-spinel"

  # the flags Spinel's Makefile and src/main.c give wasm32-wasi (WASI_CFLAGS)
  WASI = %w[--target=wasm32-wasip1 -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS
            -D_WASI_EMULATED_GETPID -D_WASI_EMULATED_MMAN -mllvm -wasm-enable-sjlj
            -mllvm -wasm-use-legacy-eh=false].freeze
  WASI_LIBS = %w[-lsetjmp -lwasi-emulated-signal -lwasi-emulated-process-clocks
                 -lwasi-emulated-getpid -lwasi-emulated-mman].freeze
  FP = %w[-ffp-contract=off].freeze
  CFLAGS = (%w[-O2 -Wno-all -Wno-unknown-warning-option -Wno-format-truncation] + FP).freeze   # common.mk
  SEC = (%w[-ffunction-sections -fdata-sections] + FP).freeze
  PAGE_INCLUDE = %w[-include lib/wasi/sp_page.h].freeze

  # What the compiler needs to link for wasm32-wasi beyond lib/wasi's
  # stand-ins: it calls system() and mkdtemp() only when it drives cc or runs
  # a program (-E), which the page never asks of it (-c --print-build).
  PAGE_HOST_C = <<~C
    #include <errno.h>
    #include <stddef.h>
    int system(const char *command) { (void)command; errno = ENOSYS; return -1; }
    char *mkdtemp(char *template_) { (void)template_; errno = ENOSYS; return NULL; }
  C

  # lib/wasi/sp_page.h, included first into the runtime and into every program
  # (-include; html/spinel/toolchain.rb): wasi-libc declares flockfile and
  # funlockfile only for its threaded build, and the runtime's puts takes the
  # stream lock (spinel_rt.h). A program for wasm32-wasi has one thread, so
  # the lock is nothing. (With the wasi-sdk's own sysroot it builds anyway.)
  PAGE_H = <<~C
    /* tools/build_spinel.rb: what the page's build of Spinel adds for wasm32-wasi */
    #ifndef SP_PAGE_H
    #define SP_PAGE_H
    #include <stdio.h>
    #ifndef _REENTRANT
    #define flockfile(f) ((void)(f))
    #define funlockfile(f) ((void)(f))
    #endif
    #endif
  C

  # Source fixes the wasm target needs, each [file, anchor, text added after it].
  # A native build tolerates a call to an undeclared function (int is assumed);
  # wasm-ld does not, when the definition returns something else: it links a
  # stub that traps (the "function signature mismatch" warning, fatal below).
  PATCHES = [
    ["src/codegen_stmt.c", "#include \"builtin_ops.h\"\n",
     "void emit_int_flt_rel(Buf *b, const char *iv, const char *fv, int int_left, const char *op);\n"]
  ].freeze

  # ------------------------------------------------------------ tar files

  module Tar
    module_function

    def field(header, at, length)
      header.byteslice(at, length).split("\0", 2).first.to_s
    end

    # The entries of a tar archive (ustar, with GNU long names and pax paths,
    # as GitHub's and npm's tarballs have them): [path, bytes] for each file.
    def read(data)
      data = data.b
      files = []
      at = 0
      long_name = pax_path = nil
      while at + 512 <= data.bytesize
        header = data.byteslice(at, 512)
        break if header.getbyte(0).zero?

        size = field(header, 124, 12).strip.to_i(8)
        type = header[156]
        prefix = field(header, 345, 155)
        name = field(header, 0, 100)
        name = "#{prefix}/#{name}" unless prefix.empty?
        body = data.byteslice(at + 512, size)
        at += 512 + ((size + 511) / 512) * 512
        case type
        when "L" then long_name = body.sub(/\0+\z/, "").force_encoding("UTF-8")
        when "x" then pax_path = body.force_encoding("UTF-8")[/^\d+ path=(.*)$/, 1]
        when "g" then nil
        else
          name = (pax_path || long_name || name).dup.force_encoding("UTF-8")
          long_name = pax_path = nil
          files << [name, body] if ["0", "\0", "7"].include?(type)
        end
      end
      files
    end

    # A tar archive of [path, bytes] pairs (ustar, names up to 100 bytes: what
    # YoWASP's unpacker and spinel/wasi.rb read), each directory as an entry
    # of its own before its files - YoWASP's unpacker needs them.
    def write(files)
      entries = []
      dirs = {}
      files.each do |path, data|
        parts = path.split("/")
        (1...parts.length).each do |i|
          dir = parts[0, i].join("/")
          entries << [dir, nil] unless dirs[dir]
          dirs[dir] = true
        end
        entries << [path, data]
      end
      out = StringIO.new("".b)
      entries.each do |path, body|
        raise "tar: path too long: #{path}" if path.bytesize > 100

        data = (body || "").b
        header = "\0".b * 512
        put = ->(text, at) { header[at, text.bytesize] = text.b }
        put.call(path, 0)
        put.call(body ? "0000644\0" : "0000755\0", 100)
        put.call("0000000\0", 108)
        put.call("0000000\0", 116)
        put.call(format("%011o\0", data.bytesize), 124)
        put.call("00000000000\0", 136)
        put.call(" " * 8, 148)
        put.call(body ? "0" : "5", 156)
        put.call("ustar\0" "00", 257)
        # the checksum: the header's bytes with the field itself as spaces
        put.call(format("%06o\0 ", header.bytes.sum), 148)
        out.write(header)
        out.write(data)
        out.write("\0".b * ((512 - data.bytesize % 512) % 512))
      end
      out.write("\0".b * 1024)
      out.string
    end
  end

  # ------------------------------------------------------------- downloading

  module Download
    module_function

    def get(url, limit = 5)
      uri = URI(url)
      response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 600) do |http|
        http.request(::Net::HTTP::Get.new(uri, "User-Agent" => AGENT))
      end
      return get(URI.join(url, response["location"]).to_s, limit - 1) if response.is_a?(::Net::HTTPRedirection) && limit.positive?
      raise "#{url}: #{response.code}" unless response.is_a?(::Net::HTTPSuccess)

      response.body.b
    end

    # a download, kept in .cache/spinel/downloads/ under its name
    def cached(name, url)
      path = File.join(CACHE, "downloads", name)
      return File.binread(path) if File.exist?(path)

      puts "fetching #{url}"
      data = get(url)
      yield data if block_given?
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite("#{path}.tmp", data)
      File.rename("#{path}.tmp", path)
      data
    end
  end

  module_function

  def npm_package(spec)
    base = spec["package"].split("/").last
    tgz = Download.cached("#{base}-#{spec["version"]}.tgz",
                     "https://registry.npmjs.org/#{spec["package"]}/-/#{base}-#{spec["version"]}.tgz") do |data|
      algorithm, digest = spec["integrity"].split("-", 2)
      raise "#{spec["package"]}: no sha512 integrity" unless algorithm == "sha512"
      raise "#{spec["package"]}@#{spec["version"]}: checksum mismatch" unless Digest::SHA512.base64digest(data) == digest
    end
    Tar.read(Zlib.gunzip(tgz)).to_h { |path, body| [path.delete_prefix("package/"), body] }
  end

  # Spinel's tree at the pinned commit, without its first path segment
  def spinel_source(spinel)
    data = Download.cached("spinel-#{spinel["commit"]}.tar.gz", "https://codeload.github.com/#{spinel["repo"]}/tar.gz/#{spinel["commit"]}")
    Tar.read(Zlib.gunzip(data)).to_h { |path, body| [path.sub(%r{\A[^/]+/}, ""), body] }
  end

  # the prism gem's C sources (src/, include/: the generated headers included) and its license
  def prism_source(version)
    gem = Download.cached("prism-#{version}.gem", "https://rubygems.org/gems/prism-#{version}.gem")
    data = Tar.read(gem).find { |path, _| path == "data.tar.gz" } or raise "prism-#{version}.gem has no data.tar.gz"
    Tar.read(Zlib.gunzip(data[1])).select { |path, _| path.match?(%r{\A(src|include)/}) || path == "LICENSE.md" }.to_h
  end

  # the license texts the pins name (tools/spinel.json "notices"), by file name
  def notice_files(notices)
    notices.to_h do |name, url|
      [name, Download.cached("notice-#{Digest::SHA256.hexdigest(url)[0, 12]}-#{name}", url)]
    end
  end

  # ------------------------------------------------------------- wasmtime

  # the wasmtime gem, installed into .cache/spinel/gems if it is not there
  def require_wasmtime(version)
    gems = File.join(CACHE, "gems")
    Gem.paths = { "GEM_HOME" => Gem.paths.home, "GEM_PATH" => ([gems] + Gem.paths.path).join(File::PATH_SEPARATOR) }
    begin
      gem "wasmtime", version
    rescue Gem::LoadError
      puts "installing the wasmtime gem #{version} into .cache/spinel/gems"
      require "rubygems/dependency_installer"
      Gem::DependencyInstaller.new(install_dir: gems, document: []).install("wasmtime", version)
      Gem::Specification.reset
      gem "wasmtime", version
    end
    require "wasmtime"
  end

  # Runs YoWASP's LLVM (one WASI command for every tool: clang, wasm-ld, ar)
  # on a directory of the host mapped as "/".
  class LLVM
    def initialize(cwasm, root)
      @engine = Wasmtime::Engine.new
      @module = Wasmtime::Module.deserialize_file(@engine, cwasm)
      @root = root
      @linker = Wasmtime::Linker.new(@engine)
      Wasmtime::WASI::P1.add_to_linker_sync(@linker)
    end

    # the compiled module, made once and kept: compiling 75 MB of
    # WebAssembly takes the better part of a minute, loading it none
    def self.prepare(wasm, cwasm)
      return if File.exist?(cwasm)

      puts "compiling clang (#{File.size(wasm) / 1_000_000} MB of WebAssembly) - once"
      bytes = Wasmtime::Module.from_file(Wasmtime::Engine.new, wasm).serialize
      File.binwrite("#{cwasm}.tmp", bytes)
      File.rename("#{cwasm}.tmp", cwasm)
    end

    # one tool: [exit code, what it printed]
    def tool(argv)
      out = File.join(@root, "tmp", "out-#{Process.pid}.txt")
      err = File.join(@root, "tmp", "err-#{Process.pid}.txt")
      config = Wasmtime::WasiConfig.new.set_argv(["yowasp-llvm", *argv])
                                    .set_stdout_file(out).set_stderr_file(err)
                                    .set_mapped_directory(@root, "/", :read_write)
      store = Wasmtime::Store.new(@engine, wasi_p1_config: config)
      code = 0
      begin
        @linker.instantiate(store, @module).invoke("_start")
      rescue Wasmtime::WasiExit => e
        code = e.code
      end
      said = [out, err].map { |path| File.exist?(path) ? File.read(path, encoding: "UTF-8") : "" }.join
      [code, said]
    end

    # clang as YoWASP's runClang drives it: the driver's plan (-###), then
    # each step of it as a tool of its own (WASI cannot start processes)
    def clang(args)
      code, plan = tool([args.first, "-###", *args.drop(1)])
      return [code, plan] unless code.zero?

      log = +""
      plan.each_line do |line|
        next unless line.start_with?(' "')

        command = line.scan(/"((?:[^"\\]|\\.)*)"/).flatten.map { |arg| arg.gsub(/\\(["\\$])/, '\1') }
        command.shift if command.first == ""
        code, said = tool(command)
        log << said
        return [code, log] unless code.zero?
      end
      [0, log]
    end
  end

  # A child process: jobs in, one JSON line each on stdin; answers out, one
  # JSON line each on stdout: {"ok", "log"}
  def worker(cwasm, root)
    llvm = LLVM.new(cwasm, root)
    $stdout.sync = true
    $stdin.each_line do |line|
      job = JSON.parse(line)
      code, log = job["tool"] == "clang" ? llvm.clang(job["args"]) : llvm.tool(job["args"])
      $stdout.puts(JSON.generate("ok" => code.zero?, "log" => log))
    end
  end

  # N child processes, each fed the next job as soon as it answered
  class Pool
    def initialize(size, cwasm, root)
      @children = Array.new(size) do
        IO.popen([RbConfig.ruby, SELF, "--worker", cwasm, root], "r+")
      end
    end

    # jobs: [{"label", "tool", "args", "cache"}], answered in place ("ok", "log")
    def run(jobs, &progress)
      queue = Queue.new
      jobs.each { |job| queue << job }
      threads = @children.map do |child|
        Thread.new do
          while (job = (queue.pop(true) rescue nil))
            child.puts(JSON.generate("tool" => job["tool"], "args" => job["args"]))
            line = child.gets or raise "a clang process ended (#{job["label"]})"
            job.merge!(JSON.parse(line))
            progress&.call(job)
          end
        end
      end
      threads.each(&:join)
      jobs
    end

    def close
      @children.each do |child|
        child.close_write
        child.close
      end
    end
  end

  # ------------------------------------------------------------ the build

  # a Makefile variable's words (backslash continuations joined, += too)
  def make_var(makefile, name)
    lines = makefile.gsub("\\\n", " ").scan(/^#{name}\s*\+?=(.*)$/).flatten
    raise "Makefile: no #{name}" if lines.empty?

    lines.flat_map(&:split)
  end

  # build/csrc/sp_rt_names.h: the first segment of every sp_* name the runtime owns
  def rt_names(source)
    names = { "rb" => true }
    source.each do |path, body|
      next unless path.match?(%r{\A(lib|packages/[^/]+)/[^/]+\.[ch]\z})

      body.b.scan(/\bsp_([a-z][a-z0-9_]*)/) { |(name)| names[name.split("_").first] = true }
    end
    "/* generated from the runtime sources; see the Makefile rule */\n" \
      "static const char *const SP_RT_PREFIXES[] = {\n#{names.keys.sort.map { |n| "  \"#{n}\",\n" }.join}  NULL\n};\n"
  end

  def write_file(path, body)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, body)
  end

  def build(pins, jobs_count)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    require_wasmtime(pins["wasmtime"])
    source = spinel_source(pins["spinel"])
    prism = prism_source(pins["prism"])
    clang = npm_package(pins["clang"])
    notices = notice_files(pins["notices"] || {})
    makefile = source.fetch("Makefile")

    # The tree clang sees as "/": Spinel's sources (patched), prism, the
    # generated headers, clang's own resources at /usr. Unpacked afresh.
    root = File.join(CACHE, "fs")
    FileUtils.rm_rf(root)
    files = source.select { |path, _| path.match?(%r{\A(src|lib|packages)/}) }
    prism.each { |path, body| files["vendor/prism/#{path}"] = body unless path == "LICENSE.md" }
    files["build/csrc/spinel_rev.h"] = "#define SPINEL_BUILD_REV \"#{pins["spinel"]["commit"][0, 7]}\"\n" \
                                       "#define SPINEL_RELEASE \"#{pins["spinel"]["date"]}\"\n#define SPINEL_OPENSSL_LIBDIR \"\"\n"
    files["build/csrc/sp_rt_names.h"] = rt_names(source)
    files["build/csrc/sp_page_host.c"] = PAGE_HOST_C
    files["lib/wasi/sp_page.h"] = PAGE_H
    PATCHES.each do |path, anchor, text|
      body = files.fetch(path).dup.force_encoding("UTF-8")
      next if body.include?(text.strip)   # fixed upstream
      raise "patch for #{path} no longer applies: Spinel changed there - look again" unless body.include?(anchor)

      files[path] = body.sub(anchor, anchor + text)
    end
    files.each { |path, body| write_file(File.join(root, path), body) }
    Tar.read(clang.fetch("gen/llvm-resources.tar")).each { |path, body| write_file(File.join(root, "usr", path), body) }
    FileUtils.mkdir_p(File.join(root, "tmp"))

    gems_version = Gem.loaded_specs["wasmtime"].version
    cwasm = File.join(CACHE, "llvm-#{pins["clang"]["version"]}-wasmtime-#{gems_version}.cwasm")
    llvm_wasm = File.join(CACHE, "llvm-#{pins["clang"]["version"]}.wasm")
    File.binwrite(llvm_wasm, clang.fetch("gen/llvm.core.wasm")) unless File.exist?(llvm_wasm)
    LLVM.prepare(llvm_wasm, cwasm)

    # every object: [source, object, flags]
    re_src = make_var(makefile, "RE_SRC")
    re_obj = ->(src) { src.sub(%r{\Alib/regexp/(.*)\.c\z}, 'build/regexp/\1.o') }
    shim_src = files.keys.select { |path| path.match?(%r{\Alib/wasi/[^/]+\.c\z}) }.sort
    shim_obj = ->(src) { src.sub(%r{\Alib/wasi/(.*)\.c\z}, 'build/wasm32-wasi/wasi/\1.o') }
    compiler_objs = make_var(makefile, "SPINEL_OBJ").map { |obj| obj.sub(%r{\Abuild/csrc/(.*)\.o\z}, '\1') }
    rt_members = make_var(makefile, "RT_MEMBERS")
    package_objs = make_var(makefile, "BUNDLED_NATIVE_OBJS")
                   .select { |obj| obj.match?(%r{\Apackages/.*\.o\z}) && !obj.match?(%r{\Apackages/(openssl|ffi)/}) }
    units = []
    files.keys.sort.each do |path|
      match = path.match(%r{\Avendor/prism/src/(.*)\.c\z}) or next
      units << [path, "build/prism/#{match[1]}.o", %w[-O2] + FP + %w[-Ivendor/prism/include -Ivendor/prism/src]]
    end
    # the regexp engine: the compiler checks literals with it, the runtime runs it
    re_src.each { |src| units << [src, re_obj.call(src), %w[-O2] + SEC + %w[-Ilib/regexp -Ilib/regexp/shim]] }
    # the compiler (SPINEL_OBJ), its parser and literal check; the POSIX
    # stand-ins of lib/wasi for the process calls it makes when it drives cc
    # (it never does here: the page asks for C only)
    compiler_objs.each { |name| units << ["src/#{name}.c", "build/csrc/#{name}.o", CFLAGS + %w[-Werror=return-type -Ilib/wasi -Isrc -Ibuild/csrc]] }
    units << ["src/spinel_parse.c", "build/csrc/sp_parse_lib.o", CFLAGS + %w[-Ilib/wasi -Ivendor/prism/include]]
    units << ["src/re_lit_check.c", "build/csrc/re_lit_check.o", CFLAGS + %w[-Ilib/wasi -Ilib/regexp -Ilib/regexp/shim]]
    units << ["build/csrc/sp_page_host.c", "build/csrc/sp_page_host.o", CFLAGS]
    # the runtime (RT_MEMBERS) and the wasi shim, as `make wasm-rt`
    rt_members.each { |name| units << ["lib/#{name}.c", "build/wasm32-wasi/#{name}.o", %w[-O2 -Wno-all] + SEC + PAGE_INCLUDE + %w[-Ilib/wasi -Ilib -Ilib/regexp -Ilib/regexp/shim]] }
    shim_src.each { |src| units << [src, shim_obj.call(src), %w[-O2 -Wno-all] + SEC + PAGE_INCLUDE + %w[-Ilib/wasi -Ilib]] }
    # the bundled packages' carried C (BUNDLED_NATIVE_OBJS but openssl and ffi)
    package_objs.each do |obj|
      src = obj.sub(/\.o\z/, ".c")
      units << [src, obj.sub(/\.o\z/, "_wasi.o"), %w[-O2 -Wno-all] + SEC + PAGE_INCLUDE + ["-Ilib/wasi", "-Ilib", "-I#{File.dirname(src)}"]]
    end

    # an object is kept in .cache/spinel/objects/ under its source and its
    # command line, so a rerun compiles only what changed
    jobs = units.map do |src, obj, flags|
      args = ["clang"] + WASI + flags + ["-c", src, "-o", obj]
      key = (Digest::SHA256.new << JSON.generate([pins["prism"], pins["clang"]["version"], args]) << files.fetch(src)).hexdigest
      { "label" => src, "tool" => "clang", "args" => args, "object" => obj, "cache" => File.join(CACHE, "objects", "#{key[0, 24]}.o") }
    end
    # clang writes into the directories, it does not make them
    jobs.each { |job| FileUtils.mkdir_p(File.join(root, File.dirname(job["object"]))) }
    todo = jobs.reject do |job|
      next false unless File.exist?(job["cache"])

      write_file(File.join(root, job["object"]), File.binread(job["cache"]))
      true
    end
    size = [[jobs_count || Etc.nprocessors - 1, 1].max, 8].min
    size = [size, todo.length].min
    pool = todo.empty? ? nil : Pool.new(size, cwasm, root)
    begin
      if pool
        puts "compiling #{todo.length} of #{jobs.length} files with #{size} clang processes"
        done = 0
        pool.run(todo) do |job|
          done += 1
          print "\r  #{done}/#{todo.length} #{job["label"]}".ljust(80) if $stdout.tty?
          puts "\n#{job["label"]}:\n#{job["log"].strip}" unless job["log"].strip.empty?
        end
        puts if $stdout.tty?
        failed = todo.reject { |job| job["ok"] }
        raise failed.map { |job| "#{job["label"]}:\n#{job["log"]}" }.join("\n") unless failed.empty?

        todo.each { |job| write_file(job["cache"], File.binread(File.join(root, job["object"]))) }
      end
      pool ||= Pool.new(1, cwasm, root)

      # link the compiler: spinel.wasm
      compiler_inputs = compiler_objs.map { |n| "build/csrc/#{n}.o" } +
                        %w[build/csrc/sp_parse_lib.o build/csrc/re_lit_check.o build/csrc/sp_page_host.o] +
                        re_src.map(&re_obj) + shim_src.map(&shim_obj) +
                        units.map { |_, obj, _| obj }.select { |obj| obj.start_with?("build/prism/") }
      puts "linking spinel.wasm"
      link = { "label" => "link spinel.wasm", "tool" => "clang",
               "args" => ["clang"] + WASI + compiler_inputs + %w[-lm] + WASI_LIBS +
                         %w[-Wl,-z,stack-size=8388608 -Wl,--strip-all -Wl,--fatal-warnings -o spinel.wasm] }
      # the runtime archive
      rt_inputs = re_src.map(&re_obj) + shim_src.map(&shim_obj) + rt_members.map { |n| "build/wasm32-wasi/#{n}.o" }
      archive = { "label" => "ar", "tool" => "llvm", "args" => %w[ar rcs libspinel_rt.a] + rt_inputs }
      pool.run([link, archive])
      [link, archive].each { |job| raise "#{job["label"]}:\n#{job["log"]}" unless job["ok"] }
    ensure
      pool&.close
    end

    # what spinel.wasm and clang read in the page: one tar
    entries = source.select do |path, _|
      path.match?(%r{\Abuiltins/[^/]+\.rb\z}) || path.match?(%r{\Apackages/[^/]+/(?!test/).+\.rb\z}) ||
        path.match?(%r{\Alib/(.+/)?[^/]+\.(h|inc)\z})
    end.to_a
    entries << ["lib/wasi/sp_page.h", PAGE_H]
    entries << ["lib/wasm32-wasi/libspinel_rt.a", File.binread(File.join(root, "libspinel_rt.a"))]
    # resolve_lib_dir looks for lib/libspinel_rt.a beside the compiler: the same archive
    entries << ["lib/libspinel_rt.a", ""]
    package_objs.each do |obj|
      wasi_obj = obj.sub(/\.o\z/, "_wasi.o")
      entries << [wasi_obj, File.binread(File.join(root, wasi_obj))]
    end
    entries << ["LICENSE", source.fetch("LICENSE")]
    entries.sort_by!(&:first)

    output = {}
    output["spinel.wasm"] = File.binread(File.join(root, "spinel.wasm"))
    output["spinel-files.tar"] = Tar.write(entries)
    output["LICENSE-spinel.txt"] = source.fetch("LICENSE")
    clang.each do |path, body|
      output["clang/#{path.delete_prefix("gen/")}"] = body if path.match?(%r{\Agen/(bundle\.js|llvm\.core\d*\.wasm)\z})
    end
    output["clang/llvm-resources.tar"] = trim_sysroot(clang.fetch("gen/llvm-resources.tar"))
    output["clang/README.md"] = clang.fetch("README.md")
    output["LICENSE-prism.md"] = prism.fetch("LICENSE.md")
    notices.each { |name, body| output[name] = body }
    output["NOTICE.md"] = notice_text(pins, notices.keys)
    puts format("built in %.0f s", Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
    output
  end

  # clang's resources: its own headers and the wasm32-wasip1 sysroot, without
  # C++, the other WASI targets and other architectures' headers
  OTHER_HEADERS = /cuda|hip|opencl|arm_|riscv|altivec|htm|s390|avx|sse|mmintrin|amx|x86|ia32|immintrin|hexagon|loongson|lasx|lsx|msa|vec|velintrin|ppc/
  OTHER_DIRS = %r{\Ainclude/(cuda_wrappers|openmp_wrappers|ppc_wrappers|llvm_libc_wrappers|llvm_offload_wrappers|orc|fuzzer|profile|sanitizer|xray|zos_wrappers)/}

  def trim_sysroot(tarball)
    keep = Tar.read(tarball).reject do |path, _|
      path.match?(%r{/c\+\+/}) || path.match?(/libc\+\+|libunwind/) ||
        (path.match?(%r{\A(include|lib)/wasm32-wasi(p2|p1-threads|-threads)?/}) && !path.include?("wasm32-wasip1/")) ||
        (path.match?(%r{\Ainclude/[^/]+\.h\z}) && path.match?(OTHER_HEADERS)) ||
        path.match?(OTHER_DIRS)
    end
    Tar.write(keep)
  end

  # NOTICE.md: what html/assets/spinel/<stamp>/ holds, and under which licenses
  def notice_text(pins, names)
    spinel = pins["spinel"]
    clang = pins["clang"]
    <<~MD
      # Spinel for the course (lesson 39)

      Built by tools/build_spinel.rb from tools/spinel.json; not in git. Each
      component keeps its own license; the texts are next to this file.

      | Component | Version | License | Files | License text |
      |---|---|---|---|---|
      | [Spinel](https://github.com/#{spinel["repo"]}) | #{spinel["commit"]} (#{spinel["date"]}) | MIT, (c) Yukihiro Matsumoto | spinel.wasm, spinel-files.tar | LICENSE-spinel.txt |
      | [Prism](https://github.com/ruby/prism), compiled into spinel.wasm | #{pins["prism"]} | MIT | spinel.wasm | LICENSE-prism.md |
      | [YoWASP Clang/LLD](https://yowasp.org) (#{clang["package"]}) | #{clang["version"]} | ISC (the package), LLVM: Apache-2.0 WITH LLVM-exception | clang/ | LICENSE-llvm.txt, clang/README.md |
      | wasi-libc, in clang's sysroot (llvm-resources.tar) and linked into every program | as in #{clang["package"]} #{clang["version"]} | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT; parts musl (MIT), cloudlibc (BSD-2-Clause), dlmalloc (CC0) | clang/llvm-resources.tar | #{names.grep(/wasi-libc|musl|cloudlibc/).join(", ")} |
    MD
  end

  # -------------------------------------------------------------- the stamp

  def stamp(pins)
    Digest::SHA256.hexdigest(JSON.generate(pins) + File.binread(SELF))[0, 16]
  end

  def current_manifest
    JSON.parse(File.read(File.join(TARGET, "manifest.json")))
  rescue StandardError
    nil
  end

  # current: the manifest names this stamp, and its build is there
  def current_stamp
    manifest = current_manifest
    manifest && File.exist?(File.join(TARGET, manifest["dir"].to_s, "spinel.wasm")) ? manifest["stamp"] : nil
  end

  # html/assets/spinel/<stamp>/ holds a build, manifest.json beside it names
  # the current one. nginx lets browsers cache the .wasm and .tar files as
  # they like and revalidates only .js and .json (nginx/default.conf), so a
  # new build gets new addresses instead of new contents under old ones.
  # The build before stays, for a tab still open on it; older ones go.
  def write(output, pins, stamp_value)
    dir = File.join(TARGET, stamp_value)
    staging = "#{dir}.new"
    FileUtils.rm_rf(staging)
    sizes = {}
    output.each do |path, body|
      full = File.join(staging, path)
      write_file(full, body)
      sizes[path] = body.bytesize
      # nginx serves the .gz in its place (gzip_static)
      next unless body.bytesize > 256 * 1024

      Zlib::GzipWriter.open("#{full}.gz", Zlib::BEST_COMPRESSION) { |gz| gz.write(body) }
    end
    FileUtils.rm_rf(dir)
    File.rename(staging, dir)
    previous = current_manifest
    manifest = { "stamp" => stamp_value, "dir" => stamp_value, "spinel" => pins["spinel"], "prism" => pins["prism"],
                 "clang" => pins["clang"]["version"], "built" => Time.now.utc.iso8601, "sizes" => sizes }
    File.write(File.join(TARGET, "manifest.json.tmp"), JSON.pretty_generate(manifest) + "\n")
    File.rename(File.join(TARGET, "manifest.json.tmp"), File.join(TARGET, "manifest.json"))
    keep = [stamp_value, previous && previous["dir"]].compact
    Dir.children(TARGET).each do |name|
      path = File.join(TARGET, name)
      FileUtils.rm_rf(path) if File.directory?(path) && !keep.include?(name)
    end
    sizes.each do |path, size|
      gz = File.join(dir, "#{path}.gz")
      line = format("  html/assets/spinel/%s/%-26s %6.1f MB", stamp_value, path, size / 1e6)
      line += format(" -> %5.1f MB gz", File.size(gz) / 1e6) if File.exist?(gz)
      puts line
    end
  end

  def newest_commit(repo)
    data = JSON.parse(Download.get("https://api.github.com/repos/#{repo}/commits/HEAD"))
    [data["sha"], data.dig("commit", "committer", "date")[0, 10]]
  end

  def main(argv)
    pins = JSON.parse(File.read(PINS_FILE))
    if argv.first == "--worker"
      require_wasmtime(pins["wasmtime"])
      return worker(argv[1], argv[2])
    end

    jobs_at = argv.index("--jobs")
    jobs = jobs_at ? Integer(argv[jobs_at + 1]) : ENV["SPINEL_JOBS"]&.then { |n| Integer(n) }
    if argv.include?("--update")
      sha, date = newest_commit(pins["spinel"]["repo"])
      if sha == pins["spinel"]["commit"]
        puts "spinel: #{sha[0, 7]} is the newest commit already"
      else
        puts "spinel: #{pins["spinel"]["commit"][0, 7]} -> #{sha[0, 7]} (#{date})"
        pins["spinel"] = pins["spinel"].merge("commit" => sha, "date" => date)
        File.write(PINS_FILE, JSON.pretty_generate(pins) + "\n")
      end
    end
    want = stamp(pins)
    have = current_stamp
    if argv.include?("--check")
      puts have == want ? "current html/assets/spinel (#{want})" : "STALE   html/assets/spinel: run ruby tools/build_spinel.rb"
      exit(have == want ? 0 : 1)
    end
    if have == want && !argv.include?("--force")
      puts "current html/assets/spinel (spinel #{pins["spinel"]["commit"][0, 7]}, #{want})"
      return
    end
    puts "building spinel #{pins["spinel"]["commit"][0, 7]} (#{pins["spinel"]["date"]}) for the browser"
    write(build(pins, jobs), pins, want)
  end
end

BuildSpinel.main(ARGV) if $PROGRAM_NAME == __FILE__
