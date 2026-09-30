# SandboxSim: teaching simulations for things the wasm sandbox cannot do
# for real - a virtual filesystem behind the File/Dir API and simulated
# time/threads. Environment-agnostic (browser + offline test harness);
# only the Thread replacement is browser-only.

# ---------------------------------------------------------------------------
# Virtual filesystem. Relative paths ("notizen.txt", "projekte/a.csv") live
# in an in-memory store; absolute paths ("/...") pass through to the real
# File/Dir so the host application and gems keep working.
module SandboxFS
  DEMO_FILES = {
    "notizen.txt" => "Speck kaufen! / buy bacon!\nKoans üben / practice koans\n",
    "beispiel.csv" => "projekt,stunden\nProjectX,3.5\nIntern,2.0\n",
    "projekte/readme.txt" => "Ein Ordner! Dateien mit / im Namen liegen in Unterordnern.\nA folder! Files with / in the name live in subfolders.\n"
  }.freeze

  class << self
    def store
      @store ||= {}
    end

    def reset!
      store.clear
      DEMO_FILES.each { |k, v| store[k] = v.dup }
    end

    # "C:/..." counts as absolute too, for the offline harness on Windows
    def virtual?(path)
      !(path.to_s.start_with?("/") || File.absolute_path?(path.to_s))
    end

    def write(path, content)
      store[path.to_s] = content.to_s
      content.to_s.length
    end

    def read(path)
      store.fetch(path.to_s) { raise Errno::ENOENT.new(path.to_s) }
    end

    def exist?(path)
      store.key?(path.to_s)
    end

    def delete(path)
      store.delete(path.to_s) { raise Errno::ENOENT.new(path.to_s) }
      1
    end

    def glob(pattern)
      store.keys.select { |k| File.fnmatch(pattern, k, File::FNM_PATHNAME) }.sort
    end
  end
end

class File
  class << self
    alias_method :sandbox_orig_read, :read
    alias_method :sandbox_orig_write, :write
    alias_method :sandbox_orig_exist?, :exist?
    alias_method :sandbox_orig_delete, :delete

    def read(path, *args, **kw)
      SandboxFS.virtual?(path) ? SandboxFS.read(path) : sandbox_orig_read(path, *args, **kw)
    end

    def write(path, content, *args, **kw)
      SandboxFS.virtual?(path) ? SandboxFS.write(path, content) : sandbox_orig_write(path, content, *args, **kw)
    end

    def exist?(path)
      SandboxFS.virtual?(path) ? SandboxFS.exist?(path) : sandbox_orig_exist?(path)
    end

    def delete(*paths)
      return sandbox_orig_delete(*paths) unless paths.all? { |p| SandboxFS.virtual?(p) }
      paths.each { |p| SandboxFS.delete(p) }
      paths.length
    end
  end
end

class Dir
  class << self
    alias_method :sandbox_orig_glob, :glob

    def glob(pattern, *args, **kw, &block)
      # only bare relative globs are virtual; calls with base:/flags (e.g.
      # rubygems' Dir.glob("*.gemspec", base: dir)) go to the real Dir
      if pattern.is_a?(String) && SandboxFS.virtual?(pattern) && args.empty? && kw.empty? && block.nil?
        SandboxFS.glob(pattern)
      else
        sandbox_orig_glob(pattern, *args, **kw, &block)
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Which files a cell run wrote, so they can be offered as downloads. They end
# up in two places: File.write with a relative path goes to the virtual store
# above, while File.open/File.binwrite - what gems such as rubyzip use -
# reach the real in-memory filesystem under the working directory ("/").
module FileWatch
  class << self
    # [virtual, real] path => content fingerprint, before the run
    def snapshot
      [SandboxFS.store.transform_values(&:hash), real_files.transform_values(&:hash)]
    end

    # [[path, bytes], ...] for every file new or changed since +snapshot+
    def changes_since(snapshot)
      virtual, real = snapshot
      changed = SandboxFS.store.filter_map { |path, data| [path, data] if virtual[path] != data.hash }
      changed + real_files.filter_map { |path, data| [path, data] if real[path] != data.hash }
    end

    private

    # Files under the working directory - gem code (BrowserGems.root) and
    # temp files aside.
    def real_files(dir = Dir.pwd, prefix = "", found = {})
      Dir.children(dir).each do |name|
        full = File.join(dir, name)
        next if defined?(BrowserGems) && full == BrowserGems.root
        next if full == "/tmp"
        if File.directory?(full)
          real_files(full, "#{prefix}#{name}/", found)
        elsif File.file?(full)
          found["#{prefix}#{name}"] = File.binread(full)
        end
      end
      found
    rescue SystemCallError
      found
    end
  end
end

# ---------------------------------------------------------------------------
# Virtual time: sleep advances a clock instead of blocking (real sleep would
# crash the wasm VM - and makes tests slow everywhere else).
module SandboxTime
  class << self
    attr_accessor :clock
  end
  self.clock = 0.0
end

module Kernel
  def sleep(seconds = 0)
    if defined?(SimThread) && SimThread.in_sim_thread?
      Fiber.yield([:sleep, seconds.to_f])
    else
      SandboxTime.clock += seconds.to_f
    end
    seconds
  end
end

# ---------------------------------------------------------------------------
# Simulated threads (browser only - the harness keeps real ones): each
# SimThread is a Fiber; a tiny cooperative scheduler interleaves them at
# their (virtual) sleep points, so "parallel downloads" and interleaved
# output genuinely show up in lesson cells.
if defined?(JS)
  class SimThread
    class << self
      attr_accessor :scheduler_current, :abort_on_exception, :report_on_exception

      def registry
        @registry ||= []
      end

      def run_scheduler(&done)
        until done.call
          runnable = registry.reject(&:finished?)
          break if runnable.empty?
          nxt = runnable.min_by(&:wake_at)
          SandboxTime.clock = nxt.wake_at if nxt.wake_at > SandboxTime.clock
          nxt.resume_once
        end
      end
    end

    MAIN = allocate

    def self.new(*args, &block)
      thread = allocate
      thread.send(:setup, args, block)
      thread
    end

    attr_reader :wake_at

    def setup(args, block)
      @finished = false
      @wake_at = SandboxTime.clock
      @fiber = Fiber.new do
        begin
          @value = block.call(*args)
        rescue Exception => e
          @error = e
        ensure
          @finished = true
        end
      end
      SimThread.registry << self
    end
    private :setup

    def finished? = @finished
    def alive? = !@finished

    def resume_once
      previous = SimThread.scheduler_current
      SimThread.scheduler_current = self
      yielded = @fiber.resume
      @wake_at = SandboxTime.clock + yielded[1] if yielded.is_a?(Array) && yielded[0] == :sleep
    ensure
      SimThread.scheduler_current = previous
    end

    def join(_limit = nil)
      SimThread.run_scheduler { @finished }
      raise @error if @error
      self
    end

    def value
      join
      @value
    end

    # thread-locals, used by some gems via Thread.current[:key]
    def [](key) = (@locals ||= {})[key]
    def []=(key, val)
      (@locals ||= {})[key] = val
    end

    def self.current
      scheduler_current || MAIN
    end

    def self.in_sim_thread?
      !scheduler_current.nil?
    end
  end

  # constants and class methods other code expects to find on Thread
  # (Singleton uses Thread::Mutex; the real Mutex/Queue work fine in wasm -
  # only thread CREATION was broken)
  SimThread::Mutex = ::Mutex if defined?(::Mutex)
  SimThread::Queue = ::Queue if defined?(::Queue)
  SimThread::ConditionVariable = ::ConditionVariable if defined?(::ConditionVariable)
  def SimThread.pass; end
  def SimThread.main = SimThread::MAIN
  def SimThread.handle_interrupt(_config) = yield
  def SimThread.list = registry.select(&:alive?)

  Object.send(:remove_const, :Thread) if defined?(Thread)
  Thread = SimThread
end

SandboxFS.reset!
