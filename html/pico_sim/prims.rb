# The C primitives of PicoRuby 4.0.3's peripheral classes, in Ruby, against
# the simulated world (docs/HANDOVER.md §6r). The classes' Ruby half is
# PicoRuby's own (vendor/*.rb, unchanged); this is the other half, written
# from the gems' src/mruby/*.c and ports/rp2040/*.c: the same methods,
# argument order, return values, error classes and messages.
#
# Loaded first (manifest.txt), so the vendored files reopen these classes.
# Runs on PicoRuby (the lesson's worker) and on CRuby (the check harness):
# plain Ruby both have (docs/PICORUBY_SHELL.md §5 #10-12).

module PicoSim
  # true in the check harness: CRuby's strings have encodings to mind
  # (respond_to? is no guide - PicoRuby answers true for some it lacks)
  CRUBY = RUBY_ENGINE == "ruby"

  # the bytes of an I2C/SPI write as the C side collects them: Integers
  # (one byte each), Arrays of Integers, Strings
  def self.flatten_bytes(args, error_class)
    out = []
    args.each do |arg|
      if arg.is_a?(Integer)
        out << (arg & 0xFF)
      elsif arg.is_a?(Array)
        arg.each do |b|
          raise TypeError.new("array element must be Fixnum") unless b.is_a?(Integer)
          out << (b & 0xFF)
        end
      elsif arg.is_a?(String)
        arg.each_byte { |b| out << b }
      elsif error_class == TypeError
        raise TypeError.new("argument must be Integer, Array or String")
      else
        raise ArgumentError.new("argument must be Integer, Array or String")
      end
    end
    out
  end

  # CRuby only (the check harness): bytes as bytes, text as valid UTF-8;
  # PicoRuby's strings are bytes anyway
  def self.binary(s)
    CRUBY ? s.dup.force_encoding("BINARY") : s
  end

  def self.utf8(s)
    CRUBY ? s.dup.force_encoding("UTF-8").scrub("?") : s
  end

  # a String of these bytes (what read/transfer answer)
  def self.byte_string(bytes)
    s = ""
    s = s.b if CRUBY
    bytes.each { |b| s << (b & 0xFF).chr }
    s
  end
end

class GPIO
  IN = 1
  OUT = 2
  HIGH_Z = 4
  PULL_UP = 8
  PULL_DOWN = 16
  OPEN_DRAIN = 32
  ALT = 64

  # ports/rp2040: names ("GP15") are not supported - -1, so ArgumentError
  def self.pin_num__(pin)
    num = pin.is_a?(Integer) ? pin : -1
    raise ArgumentError.new("Wrong GPIO pin name: #{pin.inspect}") if num < 0
    num
  end

  def _init(pin)
    PicoSim.world.gpio_init(GPIO.pin_num__(pin))
    0
  end

  def self.set_function_at(pin, function)
    PicoSim.world.gpio_function(pin_num__(pin), function)
    0
  end

  def self.set_dir_at(pin, dir)
    PicoSim.world.gpio_dir(pin_num__(pin), dir)
    0
  end

  def self.pull_up_at(pin)
    PicoSim.world.gpio_pull(pin_num__(pin), :up)
    0
  end

  def self.pull_down_at(pin)
    PicoSim.world.gpio_pull(pin_num__(pin), :down)
    0
  end

  def self.open_drain_at(pin)
    PicoSim.world.gpio_open_drain(pin_num__(pin))
    0
  end

  def self.high_at?(pin)
    PicoSim.world.gpio_read(pin) != 0
  end

  def self.low_at?(pin)
    PicoSim.world.gpio_read(pin) == 0
  end

  def self.read_at(pin)
    PicoSim.world.gpio_read(pin_num__(pin))
  end

  def self.write_at(pin, value)
    num = pin_num__(pin)
    raise ArgumentError.new("Wrong value. 0 and 1 are only valid") if value != 0 && value != 1
    PicoSim.world.gpio_write(num, value)
    0
  end

  def high?
    PicoSim.world.gpio_read(@pin) != 0
  end

  def low?
    PicoSim.world.gpio_read(@pin) == 0
  end

  def read
    PicoSim.world.gpio_read(@pin)
  end

  def write(value)
    raise TypeError.new("wrong argument type") unless value.is_a?(Integer)
    raise ArgumentError.new("Wrong value. 0 and 1 are only valid") if value != 0 && value != 1
    PicoSim.world.gpio_write(@pin, value)
    0
  end
end

class PWM
  def _init(pin)
    raise TypeError.new("wrong argument type") unless pin.is_a?(Integer)
    PicoSim.world.pwm_init(pin)
    0
  end

  # pwm.c set_freq_and_start: the frequency is kept, the PWM runs while it
  # is above 0
  def set_freq_and_start__(freq)
    @frequency = freq
    PicoSim.world.pwm_set(@pin, freq, @duty.to_f)
  end

  def frequency(freq)
    if freq.is_a?(Float)
      set_freq_and_start__(freq)
      freq
    elsif freq.is_a?(Integer)
      set_freq_and_start__(freq.to_f)
      freq.to_f
    else
      raise TypeError.new("wrong argument type")
    end
  end

  def period_us(period_us)
    raise TypeError.new("wrong argument type") unless period_us.is_a?(Integer)
    freq = 1000000.0 / period_us
    set_freq_and_start__(freq)
    freq
  end

  # clamped to 0..100 (percent)
  def set_duty__(duty)
    duty = 0.0 if duty < 0.0
    duty = 100.0 if duty > 100.0
    @duty = duty
    PicoSim.world.pwm_set(@pin, @frequency.to_f, duty)
  end

  def duty(duty)
    if duty.is_a?(Float)
      set_duty__(duty)
      duty
    elsif duty.is_a?(Integer)
      set_duty__(duty.to_f)
      duty.to_f
    else
      raise TypeError.new("wrong argument type")
    end
  end

  def pulse_width_us(pulse_width)
    raise TypeError.new("wrong argument type") unless pulse_width.is_a?(Integer)
    duty = pulse_width.to_f / 10000.0 * @frequency.to_f
    set_duty__(duty)
    duty
  end
end

class ADC
  # ports/rp2040/adc.c: VOLTAGE_MAX 3.3, RESOLUTION 4095, "temperature" -> 255
  TEMPERATURE__ = 255

  def _init(pin)
    num = if pin.is_a?(Integer)
      pin
    elsif pin.is_a?(String) || pin.is_a?(Symbol)
      pin.to_s == "temperature" ? TEMPERATURE__ : -1
    else
      -1
    end
    raise ArgumentError.new("Wrong ADC pin name: #{pin.inspect}") if num < 0
    input = case num
            when 26 then 0
            when 27 then 1
            when 28 then 2
            when 29 then 3
            when TEMPERATURE__ then 4
            else -1
            end
    raise ArgumentError.new("Wrong ADC pin value") if input < 0
    PicoSim.world.adc_init(input)
    input
  end

  def read_raw
    PicoSim.world.adc_raw(@input)
  end

  # adc.c defines read as read_voltage: raw * 3.3 / 4095
  def read_voltage
    PicoSim.world.adc_raw(@input).to_f * 3.3 / 4095
  end

  def read
    read_voltage
  end
end

class I2C
  # ports/rp2040/i2c.c's function-select table (RP2350 QFN-60 alike)
  SDA_PINS__ = [[0, 4, 8, 12, 16, 20, 24, 28], [2, 6, 10, 14, 18, 22, 26]]
  SCL_PINS__ = [[1, 5, 9, 13, 17, 21, 25, 29], [3, 7, 11, 15, 19, 23, 27]]

  def self.unit_of__(table, pin)
    return 0 if table[0].include?(pin)
    return 1 if table[1].include?(pin)
    -1
  end

  # I2C_unit_num_from_pins: -1 invalid unit, -2 mismatch, -3 undetermined
  def self.resolve_unit__(name, sda, scl)
    candidate = -1
    if sda >= 0
      u = unit_of__(SDA_PINS__, sda)
      return -2 if u < 0
      candidate = u
    end
    if scl >= 0
      u = unit_of__(SCL_PINS__, scl)
      return -2 if u < 0
      return -2 if candidate >= 0 && candidate != u
      candidate = u
    end
    if name != ""
      named = name == "RP2040_I2C0" ? 0 : (name == "RP2040_I2C1" ? 1 : -1)
      return -1 if named < 0
      return -2 if candidate >= 0 && candidate != named
      return named
    end
    return -3 if candidate < 0
    candidate
  end

  def _init(unit, frequency, sda_pin, scl_pin)
    unit_num = I2C.resolve_unit__(unit.to_s, sda_pin, scl_pin)
    if unit_num == -2
      raise ArgumentError.new("I2C: pins conflict with unit or are invalid for I2C")
    elsif unit_num == -3
      raise ArgumentError.new("I2C: cannot determine unit; specify unit or valid pins")
    elsif unit_num < 0
      raise IOError.new("Invalid I2C unit")
    end
    # pico-sdk's defaults when a pin is not given: GP4/GP5 (PICO_DEFAULT_I2C)
    sda_pin = 4 if sda_pin < 0
    scl_pin = 5 if scl_pin < 0
    PicoSim.world.i2c_init(unit_num, frequency, sda_pin, scl_pin)
    unit_num
  end

  def write(i2c_adrs_7, *outputs, timeout: nil)
    bytes = PicoSim.flatten_bytes(outputs, TypeError)
    res = PicoSim.world.i2c_write(@unit_num, i2c_adrs_7, bytes, false)
    raise IOError.new("I2C write failed") if res < 0
    res
  end

  def read(i2c_adrs_7, len, *outputs, timeout: nil)
    unless outputs.empty?
      bytes = PicoSim.flatten_bytes(outputs, TypeError)
      res = PicoSim.world.i2c_write(@unit_num, i2c_adrs_7, bytes, true)
      raise IOError.new("I2C write (for read) failed") if res < 0
    end
    data = PicoSim.world.i2c_read(@unit_num, i2c_adrs_7, len)
    raise IOError.new("I2C read failed") if data.nil? || data.empty?
    PicoSim.byte_string(data)
  end
end

class SPI
  # ports/rp2040/spi.c's function-select table; CS is a plain GPIO
  SCK_PINS__ = [[2, 6, 18, 22], [10, 14, 26]]
  CIPO_PINS__ = [[0, 4, 16, 20], [8, 12, 24, 28]]
  COPI_PINS__ = [[3, 7, 19, 23], [11, 15, 27]]

  def self.unit_of__(table, pin)
    return 1 if table[0].include?(pin)
    return 2 if table[1].include?(pin)
    -1
  end

  # SPI_unit_num_from_pins: 0 BITBANG, 1 SPI0, 2 SPI1; -1 invalid unit,
  # -7 mismatch, -8 undetermined
  def self.resolve_unit__(name, sck, cipo, copi)
    return 0 if name == "BITBANG"
    candidate = -1
    [[SCK_PINS__, sck], [CIPO_PINS__, cipo], [COPI_PINS__, copi]].each do |pair|
      next if pair[1] < 0
      u = unit_of__(pair[0], pair[1])
      return -7 if u < 0
      return -7 if candidate >= 0 && candidate != u
      candidate = u
    end
    if name != ""
      named = name == "RP2040_SPI0" ? 1 : (name == "RP2040_SPI1" ? 2 : -1)
      return -1 if named < 0
      return -7 if candidate >= 0 && candidate != named
      return named
    end
    return -8 if candidate < 0
    candidate
  end

  def self.init(unit_name, frequency, sck_pin, cipo_pin, copi_pin, cs_pin, mode, first_bit, data_bits)
    unit_num = resolve_unit__(unit_name.to_s, sck_pin, cipo_pin, copi_pin)
    if unit_num == -7
      raise ArgumentError.new("SPI: pins conflict with unit or are invalid for SPI")
    elsif unit_num == -8
      raise ArgumentError.new("SPI: cannot determine unit; specify unit or valid pins")
    elsif unit_num < 0
      raise IOError.new("Invalid SPI unit name")
    end
    raise IOError.new("Invalid SPI mode") if mode < 0 || mode > 3
    # pico-sdk's defaults (PICO_DEFAULT_SPI_*: SPI0 on GP18/GP16/GP19)
    sck_pin = 18 if sck_pin < 0
    cipo_pin = 16 if cipo_pin < 0
    copi_pin = 19 if copi_pin < 0
    spi = allocate
    spi.init__(unit_num, frequency, sck_pin, cipo_pin, copi_pin, cs_pin, mode, first_bit, data_bits)
    spi
  end

  def init__(unit_num, frequency, sck, cipo, copi, cs, mode, first_bit, data_bits)
    @unit_num__ = unit_num
    @info__ = [frequency, sck, cipo, copi, cs, mode, first_bit, data_bits]
    PicoSim.world.spi_init(unit_num, sck, cipo, copi)
  end

  def write(*outputs)
    # one String (a display's pixels): handed on as it is, not byte by byte
    if outputs.size == 1 && outputs[0].is_a?(String)
      raise IOError.new("SPI write failed") if outputs[0].empty?
      PicoSim.world.spi_write(@unit_num__, outputs[0])
      return outputs[0].bytesize
    end
    bytes = PicoSim.flatten_bytes(outputs, ArgumentError)
    raise IOError.new("SPI write failed") if bytes.empty?
    PicoSim.world.spi_write(@unit_num__, bytes)
    bytes.size
  end

  def read(len, repeated_tx_data = 0)
    PicoSim.byte_string(PicoSim.world.spi_read(@unit_num__, len, repeated_tx_data))
  end

  def transfer(*outputs, additional_read_bytes: 0)
    bytes = PicoSim.flatten_bytes(outputs, ArgumentError)
    additional_read_bytes.times { bytes << 0 }
    PicoSim.byte_string(PicoSim.world.spi_transfer(@unit_num__, bytes))
  end

  def sck_pin = @info__[1]
  def cipo_pin = @info__[2]
  def copi_pin = @info__[3]
  def cs_pin = @info__[4]
end

# picoruby-pio's C half (src/mruby/pio.c, ports/rp2040/pio.c of 4.0.3) on
# the simulated PIO (devices/pio.rb). PIO::StateMachine.new (vendored
# pio_state_machine.rb) calls init with the program and 21 settings.
module PIO
  class StateMachine
    def self.init(*args)
      raise ArgumentError.new("wrong number of arguments (given #{args.size}, expected 23)") if args.size != 23
      args.each_with_index do |a, i|
        next if i == 2
        raise TypeError.new("wrong argument type #{a.class} (expected Integer)") unless a.is_a?(Integer)
      end
      raise TypeError.new("wrong argument type #{args[2].class} (expected Array)") unless args[2].is_a?(Array)
      # pio_instance knows PIO0 and PIO1; sm_num is a uint8_t
      raise IOError.new("Invalid PIO number") if args[0] != 0 && args[0] != 1
      raise IOError.new("Invalid state machine number") if args[1] < 0 || args[1] > 3
      instructions = []
      i = 0
      while i < args[3]
        instructions << ((args[2][i] || 0) & 0xFFFF)
        i += 1
      end
      config = args.dup
      config[2] = instructions
      sm = PicoSim::PioSm.new(config)
      raise IOError.new("No space in PIO instruction memory") unless PicoSim.world.pio_init(sm)
      obj = allocate
      obj.init__(sm)
      obj
    end

    def init__(sm)
      @sm__ = sm
    end

    def start
      PicoSim.world.pio_enable(@sm__, true)
      nil
    end

    def stop
      PicoSim.world.pio_enable(@sm__, false)
      nil
    end

    def restart
      nil
    end

    def put_buffer(ary)
      raise TypeError.new("wrong argument type #{ary.class} (expected Array)") unless ary.is_a?(Array)
      ary.each { |w| raise TypeError.new("wrong argument type #{w.class} (expected Integer)") unless w.is_a?(Integer) }
      PicoSim.world.pio_put(@sm__, ary)
      nil
    end

    def put_bytes(str)
      raise TypeError.new("wrong argument type #{str.class} (expected String)") unless str.is_a?(String)
      words = []
      str.each_byte { |b| words << b }
      PicoSim.world.pio_put(@sm__, words)
      nil
    end

    def put_nonblocking(value)
      raise TypeError.new("wrong argument type #{value.class} (expected Integer)") unless value.is_a?(Integer)
      return false if PicoSim.world.pio_tx_level(@sm__) >= @sm__.fifo_depth
      PicoSim.world.pio_put(@sm__, [value])
      true
    end

    # nothing in these programs pushes: a blocking get waits for ever
    def get
      PicoSim.world.pio_stall(@sm__, "get")
      0
    end

    def get_nonblocking = nil
    def tx_level = PicoSim.world.pio_tx_level(@sm__)
    def rx_level = 0
    def tx_full = PicoSim.world.pio_tx_level(@sm__) >= @sm__.fifo_depth ? 1 : 0
    def tx_empty = PicoSim.world.pio_tx_level(@sm__) == 0 ? 1 : 0
    def rx_full = 0
    def rx_empty = 1

    def clear_fifos
      PicoSim.world.pio_clear(@sm__)
      nil
    end

    def drain_tx
      PicoSim.world.pio_drain(@sm__)
      nil
    end

    def exec(instr)
      raise TypeError.new("wrong argument type") unless instr.is_a?(Integer)
      nil
    end

    def freq = @sm__.freq

    def freq=(freq)
      raise TypeError.new("wrong argument type") unless freq.is_a?(Integer)
      raise ArgumentError.new("freq must be positive") if freq <= 0
      @sm__.freq = freq
      freq
    end
  end
end
