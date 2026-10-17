# The Pico simulator under CRuby (docs/HANDOVER.md §6r): what PicoRuby's
# worker gives html/pico_sim/ there - a clock, sleep_ms, Task, Machine, the
# HTTP and the camera - for test/pico_harness.rb and test/pico_sim_test.rb.
#
# The clock is virtual: sleep_ms moves it (and the world with it) at once,
# so a 2 s e-paper refresh takes no time and every run is exact. Tasks are
# Fibers: the one whose wake time comes first runs, a Task's sleep_ms
# yields. A busy loop that reads an input moves the clock by 0.05 ms per
# read (PicoSim.breathe), so a scripted button press still arrives. A run
# longer than LIMIT_MS (the page's 60 s) raises PicoCRuby::Timeout.
#
#   require_relative "pico_cruby_host"
#   PicoCRuby.load_sim            # html/pico_sim/manifest.txt, in order
#   PicoCRuby.start               # a fresh clock and Task list for a run
#   PicoSim.setup(JSON.parse(board_json))
#   ... run the cell's code ...
#   summary = PicoCRuby.finish    # the summary JSON
require "json"
require "fiber"
# PicoRuby's strings are mutable; the vendored mrblib appends to literals
Warning[:deprecated] = false
require "fileutils"
require "tmpdir"

module PicoCRuby
  HTML = File.expand_path("../html", __dir__)
  SIM = File.join(HTML, "pico_sim")
  LIMIT_MS = 60_000.0
  # the require stubs the worker writes to /lib (picoruby_worker_core.js)
  STUBS = %w[gpio pwm adc i2c spi cyw43 network ble hcsr04 camera socket net/http env].freeze

  class Timeout < StandardError; end

  class << self
    attr_reader :now, :inputs, :posted, :summary_text
    attr_accessor :http_answers

    def reset_clock
      @now = 0.0
      @run_start = 0.0
      @tasks = []
      @current = nil
      @posted = []
      @summary_text = ""
      @inputs ||= {}
      @http_answers ||= {}
    end

    # a fresh run: its clock starts at 0 (the world keeps what survives)
    def start(inputs = {})
      reset_clock
      @inputs = inputs.transform_keys(&:to_s).transform_values(&:to_s)
    end

    def run_ms = @now - @run_start

    def limit!
      raise Timeout, "the run took longer than #{(LIMIT_MS / 1000).round} s" if run_ms > LIMIT_MS
    end

    def advance_world
      PicoSim.world.advance(PicoSim.world.now) if defined?(PicoSim::World) && PicoSim.instance_variable_get(:@world)
    end

    # ---------- Tasks ----------

    def tasks = @tasks
    def current = @current

    def sleep(ms)
      ms = ms.to_f
      ms = 0.0 if ms.negative?
      if @current
        @current.wake = @now + ms
        Fiber.yield
      else
        run_until(@now + ms)
      end
      limit!
    end

    # the main program waits: the Tasks due before +target+ run, in order
    def run_until(target)
      loop do
        task = next_task
        break if task.nil? || task.wake > target

        @now = task.wake if task.wake > @now
        advance_world
        resume(task)
        limit!
      end
      @now = target if target > @now
      advance_world
    end

    def next_task
      ready = @tasks.select(&:ready?)
      ready.min_by { |t| [t.wake, t.priority, t.serial] }
    end

    def resume(task)
      @current = task
      task.fiber.resume
    ensure
      @current = nil
      @tasks.delete(task) unless task.fiber.alive?
    end

    # the main program waits for +task+
    def join(task)
      if @current
        sleep(1) until task.done?
        return
      end
      until task.done?
        nxt = next_task
        break if nxt.nil?

        @now = nxt.wake if nxt.wake > @now
        advance_world
        resume(nxt)
        limit!
      end
    end

    # ---------- the world's host ----------

    def breathe
      @now += 0.05
      limit!
    end

    def post(kind, text)
      @posted << [kind, text]
      @posted.shift if @posted.size > 500
    end

    def summary(text)
      @summary_text = text
    end

    # canned answers only (html/assets/data/pico/http/<host>__<path>.json),
    # or one a test put into http_answers[url] ("status\nheaders\n\nbody")
    def http(method, url, headers, body)
      return @http_answers[url] if @http_answers.key?(url)

      file = File.join(HTML, "assets/data/pico/http", "#{slug(url)}.json")
      return "0\n\n\n" unless File.exist?(file)

      data = JSON.parse(File.read(file))
      head = (data["headers"] || {}).merge("x-chunky-canned" => "1")
      "#{data['status'] || 200}\n#{head.map { |k, v| "#{k}: #{v}" }.join("\n")}\n\n#{data['body']}".b
    end

    def slug(url)
      uri = URI(url)
      path = "#{uri.path}#{uri.query ? "?#{uri.query}" : ''}".sub(%r{\A/}, "")
      "#{uri.host}__#{path.gsub(/[^A-Za-z0-9.]+/, '_')}"
    end

    def camera_hex(name)
      file = File.join(HTML, "assets/data/pico/camera", "#{name.to_s.gsub(/[^a-z0-9_-]/i, '')}.pgm")
      File.exist?(file) ? File.binread(file).unpack1("H*") : ""
    end

    # ---------- loading ----------

    # html/pico_sim's files in manifest order, minus the worker's host;
    # the vendored Net::HTTP gets the mruby branch's get (CRuby would take
    # the mruby/c one, which calls a method only mruby/c has)
    def load_sim
      return if @loaded

      stubs_dir
      reset_clock
      manifest.each do |name|
        next if %w[host_js.rb boot.rb].include?(name)

        load File.join(SIM, name)
        patch_net_http if name == "vendor/net-http/http_client.rb"
      end
      PicoSim.host = Host.new
      @loaded = true
    end

    def manifest
      File.readlines(File.join(SIM, "manifest.txt")).map { |l| l.sub(/#.*/, "").strip }.reject(&:empty?)
    end

    def patch_net_http
      Net::HTTP.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def get(path, initheader = nil, dest = nil, &block)
          request(Net::Get.new(path, initheader), &block)
        end

        class << self
          alias_method :get, :_get
        end
      RUBY
    end

    # the require stubs, first in $LOAD_PATH, as the worker's /lib
    def stubs_dir
      @stubs_dir ||= begin
        dir = Dir.mktmpdir("pico_stubs")
        at_exit { FileUtils.rm_rf(dir) }
        STUBS.each do |name|
          path = File.join(dir, "#{name}.rb")
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, "# simulated: see html/pico_sim (the classes are loaded already)\n")
        end
        $LOAD_PATH.unshift(dir)
        dir
      end
    end

    # a cell's tabs as files in a fresh directory first in $LOAD_PATH (the
    # worker's /lib); the previous run's tabs go, and are required anew
    def write_tabs(tabs)
      if @tabs_dir
        $LOAD_PATH.delete(@tabs_dir)
        $LOADED_FEATURES.reject! { |f| f.start_with?(@tabs_dir) }
        FileUtils.rm_rf(@tabs_dir)
      end
      @tabs_dir = Dir.mktmpdir("pico_lib")
      (tabs || []).each do |tab|
        path = File.join(@tabs_dir, tab["name"])
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, tab["code"])
      end
      $LOAD_PATH.unshift(@tabs_dir)
      @tabs_dir
    end

    def tabs_dir = @tabs_dir

    def finish
      PicoSim.finish
      @tasks.each(&:terminate)
      @summary_text
    end
  end

  # PicoSim.host for CRuby
  class Host
    def now_ms = PicoCRuby.run_ms
    def input(key) = PicoCRuby.inputs[key.to_s].to_s
    def post(kind, text) = PicoCRuby.post(kind, text)
    def summary(text) = PicoCRuby.summary(text)
    def http(method, url, headers, body) = PicoCRuby.http(method, url, headers, body)
    def camera_hex(name) = PicoCRuby.camera_hex(name)
    def breathe = PicoCRuby.breathe
    def breathe_out = PicoCRuby.limit!
  end
end

# PicoRuby's Task (mruby-task), as far as the lessons use it
class Task
  @serial = 0
  class << self
    attr_accessor :serial

    def current = PicoCRuby.current
    def list = PicoCRuby.tasks.dup
    def pass = PicoCRuby.sleep(0)
    def get(name) = PicoCRuby.tasks.find { |t| t.name == name }
  end

  attr_reader :name, :priority, :fiber, :serial, :value
  attr_accessor :wake

  def initialize(name: nil, priority: 128, &block)
    Task.serial += 1
    @serial = Task.serial
    @name = name
    @priority = priority
    @wake = PicoCRuby.now
    @status = :READY
    @fiber = Fiber.new do
      @value = block.call
      @status = :DORMANT
    rescue StandardError => e
      @status = :DORMANT
      @error = e
      $stdout.puts "Exception in task: #<#{e.class}: #{e.message}>"
    end
    PicoCRuby.tasks << self
  end

  def ready? = @status == :READY && @fiber.alive?
  def done? = @status == :DORMANT || !@fiber.alive?
  def status = done? ? :DORMANT : @status

  def terminate
    @status = :DORMANT
    PicoCRuby.tasks.delete(self)
    self
  end

  def suspend
    @status = :SUSPENDED
    self
  end

  def resume
    @status = :READY if @status == :SUSPENDED
    self
  end

  def join
    PicoCRuby.join(self)
    self
  end

  class Queue
    def initialize
      @items = []
    end

    def push(item)
      @items << item
      self
    end
    alias << push

    def pop(timeout_ms: nil)
      waited = 0
      while @items.empty?
        return nil if timeout_ms && waited >= timeout_ms

        PicoCRuby.sleep(1)
        waited += 1
      end
      @items.shift
    end

    def empty? = @items.empty?
    def size = @items.size
    def clear = @items.clear
  end

  class Error < StandardError; end
end

module Machine
  def self.board_millis = PicoCRuby.run_ms.to_i
  def self.uptime_us = (PicoCRuby.run_ms * 1000).to_i
  def self.delay_ms(ms) = PicoCRuby.sleep(ms)
  def self.busy_wait_ms(ms) = PicoCRuby.sleep(ms)
end

module Kernel
  private

  def sleep_ms(ms)
    PicoCRuby.sleep(ms)
    ms.to_i
  end

  def usleep(us)
    PicoCRuby.sleep(us / 1000.0)
    us.to_i
  end

  # PicoRuby's sleep(sec): the virtual clock too (CRuby's would wait)
  def sleep(sec = nil)
    PicoCRuby.sleep(sec.to_f * 1000)
    sec.to_i
  end
end
