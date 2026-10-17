# The simulated Pico and what is wired to it (docs/HANDOVER.md §6r): one
# world per worker (or harness process), PicoSim.world. prims.rb's
# primitives read and write it; the parts (devices/*.rb) are built from the
# cell's "board": {"parts": [...]}; the bench script (bench.rb) moves its
# inputs at fixed times; its summary is what an exercise's check reads
# (PicoRubyCells::Board), and its state is what the bench on the page draws.
#
# Time is in ms since the run started: PicoSim.host.now_ms (the worker's
# clock, or the harness's virtual one). Everything happens in #advance,
# which every primitive calls - and the ticker Task every 33 ms in the
# worker (PicoSim.tick_loop).

module PicoSim
  LOG_CAP = 2000      # pin writes kept per pin (the oldest go)
  PWM_CAP = 500
  HTTP_BODY_CAP = 4096

  class << self
    attr_accessor :host

    def world
      @world ||= World.new
    end

    # a run with a board (picoruby_lab.rb, test/pico_harness.rb): the
    # cell's board JSON, parsed
    def setup(config)
      world.setup(config)
    end

    # the ticker Task's body in the worker
    def tick_loop
      while true
        world.tick
        sleep_ms 33
      end
    end

    # the run ended: the last state for the page, the summary for the check
    def finish
      world.finish
    end

    # a simulated input read in a busy loop gives the worker's event loop a
    # turn now and then (host_js.rb), so inputs and frames still arrive
    def breathe
      host.breathe
    end
  end

  # one GPIO: the SIO direction, the output latch, the pad's pulls
  class Pin
    attr_accessor :mode, :level, :pull, :open_drain, :function

    def initialize
      reset
    end

    # RP2040/RP2350 pads come out of reset with the pull-down on
    def reset
      @mode = nil
      @level = 0
      @pull = :down
      @open_drain = false
      @function = nil
    end

    def name
      case @mode
      when :in then @pull == :up ? "in_pull_up" : (@pull == :down ? "in_pull_down" : "in")
      when nil then "unset"
      else @mode.to_s
      end
    end
  end

  # a seeded generator (a 31-bit LCG): noise that repeats from run to run
  class Rng
    def initialize(seed = 42)
      @s = seed
    end

    def int(n)
      @s = (@s * 1103515245 + 12345) & 0x7fffffff
      (@s >> 8) % n
    end
  end

  class World
    attr_reader :pins, :parts, :rng, :board, :log, :bench, :radio, :wifi, :epd_store

    def initialize
      @pins = Array.new(30) { Pin.new }
      # what survives a reset: the e-paper's picture, the environment
      @epd_store = {}
      @base = 0.0
      @last_t = 0.0
      @parts = []
      @part_ids = []
      @config = {}
      @bench = Bench.new([])
      @radio = Radio.new
      @wifi = WifiState.new
      clear_logs
      @rng = Rng.new(42)
      @drivers = {}
      @watchers = {}
      @i2c = {}
      @spi = []
      @adc = {}
      @adc_on = {}
      @onboard = 0
      @last_state = nil
    end

    # ---------- a run ----------

    # A cell's run resets the board (pins, PWM, motors, the robot, the BLE
    # link) - the e-paper keeps its picture. A line in an IRB below the
    # cell ("reset": false) carries on where the cell left the board.
    def setup(config)
      config = {} unless config.is_a?(Hash)
      ids = config["parts"].is_a?(Array) ? config["parts"].map { |p| p.to_s } : []
      reset = config["reset"] != false || ids != @part_ids || @parts.empty? && !ids.empty?
      @config = config
      @board = (config["board"] || "pico2w").to_s
      if reset
        hard_reset(ids)
        @base = 0.0
        @run_start = 0.0
      else
        # the timeline goes on: the summary's times stay those of the cell
        @base = @last_t
      end
      # the run's clock starts now, not when the worker took the request
      # (the simulator's first load takes a moment)
      @host_t0 = PicoSim.host.now_ms
      @last_t = @base
      @bench = Bench.new(reset && config["bench"].is_a?(Array) ? config["bench"] : [])
      @last_state = nil
      advance(now)
    end

    def hard_reset(ids)
      @pins.each { |pin| pin.reset }
      clear_logs
      @rng = Rng.new(42)
      @drivers = {}
      @watchers = {}
      @i2c = {}
      @spi = []
      @adc = {}
      @adc_on = {}
      @onboard = 0
      @radio = Radio.new
      @wifi = WifiState.new
      @part_ids = ids
      @parts = []
      ids.each do |id|
        part = PicoSim.build_part(id)
        next unless part
        @parts << part
        part.attach(self)
      end
    end

    def clear_logs
      @writes = {}
      @pwm = {}
      @pwm_log = {}
      @buzz = []
      @http = []
      @i2c_count = {}
      @events = []
    end

    def now
      t = @base + PicoSim.host.now_ms - (@host_t0 || 0.0)
      @last_t = t if t > @last_t
      @last_t
    end

    # the time since this run started, for bench scripts and the summary
    def run_t(t = now)
      t - @run_start
    end

    def advance(t = now)
      @bench.apply(self, run_t(t))
      @parts.each { |part| part.advance(self, t) }
      t
    end

    # the ticker in the worker: the bench gets the state when it changed
    def tick
      advance(now)
      state = state_hash
      key = JSON.generate(state)
      return if key == @last_state
      @last_state = key
      state["t"] = run_t.round
      PicoSim.host.post("state", JSON.generate(state))
    end

    def finish
      advance(now)
      @last_state = nil
      tick
      PicoSim.host.summary(summary_json)
    end

    # a page input or the bench's scripted value for +key+ ("pin14",
    # "adc26", "tempC", "bme.t", ...), nil when neither has one
    def input(key)
      scripted = @bench.value(key)
      return scripted unless scripted.nil?
      value = PicoSim.host.input(key).to_s
      value == "" ? nil : value
    end

    def input_f(key, default)
      value = input(key)
      value.nil? ? default : value.to_f
    end

    # a part's event for the bench's log ("E-paper refreshed")
    def event(kind, text)
      @events << [run_t.round, kind, text]
      @events.shift if @events.size > 100
      PicoSim.host.post(kind, text)
    end

    def scripted?(key)
      !@bench.value(key).nil?
    end

    # ---------- wiring: parts register here ----------

    def drive(pin, part)
      @drivers[pin] = part
    end

    def watch(pin, part)
      (@watchers[pin] ||= []) << part
    end

    def i2c_device(unit, addr, device)
      (@i2c[unit] ||= {})[addr] = device
    end

    def spi_device(unit, cs_pin, device)
      @spi << [unit, cs_pin, device]
    end

    def adc_source(input, part)
      @adc[input] = part
    end

    def part(id)
      @parts.find { |part| part.id == id }
    end

    # ---------- GPIO ----------

    def gpio_init(pin)
      p = @pins[pin]
      p.mode = :in
      p.level = 0
      p.function = :sio
      advance
    end

    def gpio_dir(pin, dir)
      p = @pins[pin]
      if dir == GPIO::OUT
        p.mode = :out
        log_write(pin, p.level)
      elsif dir == GPIO::IN
        p.mode = :in
      end
      notify(pin, p.level)
    end

    def gpio_pull(pin, pull)
      @pins[pin].pull = pull
    end

    def gpio_open_drain(pin)
      @pins[pin].open_drain = true
    end

    def gpio_function(pin, function)
      @pins[pin].mode = :alt
      @pins[pin].function = function
    end

    # what the pin reads: its own output, or what a part drives it to, or
    # its pull - a pin nothing drives and nothing pulls reads noise
    def gpio_read(pin)
      PicoSim.breathe
      t = advance
      level_at(pin, t)
    end

    def level_at(pin, t = now)
      p = @pins[pin]
      return 0 unless p
      return p.level if p.mode == :out
      driver = @drivers[pin]
      driven = driver ? driver.drive(self, pin, t) : nil
      return driven unless driven.nil?
      return 1 if p.pull == :up
      return 0 if p.pull == :down
      @rng.int(2)
    end

    def gpio_write(pin, value)
      p = @pins[pin]
      p.level = value
      log_write(pin, value) if p.mode == :out
      advance
      notify(pin, value)
    end

    def notify(pin, value)
      list = @watchers[pin]
      return unless list
      t = now
      list.each { |part| part.on_write(self, pin, value, t) }
    end

    def log_write(pin, value)
      list = (@writes[pin] ||= [])
      list << [run_t, value]
      list.shift if list.size > LOG_CAP
    end

    # the level a part sees on an output pin (CS, DC, RST, motor pins)
    def out_level(pin)
      p = @pins[pin]
      p.mode == :out ? p.level : nil
    end

    # ---------- PWM ----------

    def pwm_init(pin)
      @pins[pin].mode = :pwm
      @pwm[pin] = [0.0, 0.0]
      advance
    end

    def pwm_set(pin, freq, duty)
      t = advance
      @pwm[pin] = [freq, duty]
      list = (@pwm_log[pin] ||= [])
      list << [run_t(t), freq, duty]
      list.shift if list.size > PWM_CAP
      notify(pin, duty)
    end

    # duty in percent while the PWM runs (frequency above 0), else 0
    def pwm_duty(pin)
      p = @pins[pin]
      if p.mode == :pwm
        f, d = @pwm[pin] || [0.0, 0.0]
        f > 0 ? d : 0.0
      elsif p.mode == :out
        p.level == 1 ? 100.0 : 0.0
      else
        0.0
      end
    end

    def pwm_freq(pin)
      @pins[pin].mode == :pwm ? (@pwm[pin] || [0.0, 0.0])[0] : 0.0
    end

    def buzz(freq)
      last = @buzz.last
      return if last && last[1] == freq
      @buzz << [run_t.round, freq]
      @buzz.shift if @buzz.size > PWM_CAP
    end

    # ---------- ADC ----------

    def adc_init(input)
      @adc_on[input] = true
      @pins[26 + input].mode = :adc if input < 4
    end

    # 12 bits; ADC4 is the chip's temperature sensor: 0.706 V at 27 °C,
    # -1.721 mV per degree (RP2040 datasheet §4.9.5), +-2 LSB of noise
    def adc_raw(input)
      PicoSim.breathe
      t = advance
      volts = if input == 4
        temp = input_f("tempC", 21.0)
        0.706 - (temp - 27) * 0.001721
      else
        part = @adc[input]
        part ? part.adc_voltage(self, input, t) : @rng.int(60) / 1000.0
      end
      raw = (volts / 3.3 * 4095).round + @rng.int(5) - 2
      raw = 0 if raw < 0
      raw = 4095 if raw > 4095
      raw
    end

    # ---------- I2C ----------

    def i2c_init(unit, freq, sda, scl)
      @pins[sda].mode = :i2c
      @pins[scl].mode = :i2c
      @i2c_freq = freq
    end

    # bytes written, or -1 when nobody answers at +addr+ (a NACK)
    def i2c_write(unit, addr, bytes, nostop)
      advance
      device = (@i2c[unit] || {})[addr]
      return -1 unless device
      count_i2c(addr)
      device.i2c_write(self, bytes)
      bytes.size
    end

    # an Array of +len+ bytes, nil for a NACK
    def i2c_read(unit, addr, len)
      advance
      device = (@i2c[unit] || {})[addr]
      return nil unless device
      count_i2c(addr)
      device.i2c_read(self, len)
    end

    def count_i2c(addr)
      key = format("0x%02x", addr)
      @i2c_count[key] = (@i2c_count[key] || 0) + 1
    end

    # ---------- SPI ----------

    def spi_init(unit, sck, cipo, copi)
      [sck, cipo, copi].each { |pin| @pins[pin].mode = :spi if pin >= 0 && pin < 30 }
    end

    # the bytes go to the device whose chip select is low at this moment
    def spi_write(unit, bytes)
      advance
      @spi.each do |entry|
        next unless entry[0] == unit && out_level(entry[1]) == 0
        entry[2].spi_write(self, bytes)
      end
    end

    def spi_read(unit, len, fill)
      advance
      Array.new(len, 0)
    end

    def spi_transfer(unit, bytes)
      spi_write(unit, bytes)
      Array.new(bytes.size, 0)
    end

    # ---------- the board's own LED, Wi-Fi, HTTP ----------

    # on a Pico W / 2 W the LED hangs off the wireless chip (CYW43 WL_GPIO0)
    def onboard_led(value)
      @onboard = value
      advance
    end

    def onboard
      if @board == "pico" || @board == "pico2"
        out_level(25) || 0
      else
        @onboard
      end
    end

    def http_log(entry)
      @http << entry
      @http.shift if @http.size > 20
    end

    # ---------- what the page draws, what the check reads ----------

    def state_json
      state = state_hash
      state["t"] = run_t.round
      JSON.generate(state)
    end

    def state_hash
      pins = {}
      @pins.each_with_index do |p, i|
        next if p.mode.nil?
        pins[i.to_s] = p.mode == :out ? "o#{p.level}" : (p.mode == :pwm ? "p#{pwm_duty(i).round}" : p.name)
      end
      parts = {}
      @parts.each do |part|
        s = part.state(self)
        parts[part.id] = s if s
      end
      { "pins" => pins, "onboard" => onboard, "parts" => parts, "scripted" => @bench.values }
    end

    def summary
      writes = {}
      @writes.each { |pin, list| writes[pin.to_s] = list.map { |e| [e[0].round, e[1]] } }
      modes = {}
      @pins.each_with_index { |p, i| modes[i.to_s] = p.name unless p.mode.nil? }
      pwm = {}
      @pwm_log.each { |pin, list| pwm[pin.to_s] = list.map { |e| [e[0].round, e[1], e[2]] } }
      out = { "board" => @board, "t" => run_t.round, "writes" => writes, "modes" => modes,
              "pwm" => pwm, "onboard" => onboard, "i2c" => @i2c_count, "buzz" => @buzz,
              "http" => @http, "wifi" => @wifi.summary, "ble" => @radio.summary, "events" => @events }
      @parts.each { |part| part.summary(self, out) }
      out
    end

    def summary_json
      JSON.generate(summary)
    end
  end

  # the CYW43's Wi-Fi as the stand-in (stand_ins/cyw43.rb) leaves it
  class WifiState
    attr_accessor :init, :sta, :connected, :ssid

    def initialize
      @init = false
      @sta = false
      @connected = false
      @ssid = nil
    end

    def summary
      { "init" => @init, "connected" => @connected, "ssid" => @ssid }
    end
  end
end
