# Waveshare Pico-Environment-Sensor on I2C0 (SDA GP20, SCL GP21): a BME280
# at 0x76 that measures what the bench's sliders say (inputs "bme.t" in °C,
# "bme.rh" in %, "bme.p" in hPa), and four chips that only answer - the
# TSL25911 (0x29), ICM20948 (0x68), LTR390 (0x53) and SGP40 (0x59) - which
# is enough for I2C#scan.
#
# The BME280 is register-exact where a driver looks (Bosch BST-BME280-DS002):
# 0xD0 id 0x60, 0xE0 reset (0xB6), 0xF2 ctrl_hum, 0xF3 status, 0xF4
# ctrl_meas, 0xF5 config, the calibration words at 0x88..0xA1 and
# 0xE1..0xE7, and the raw ADC values in 0xF7..0xFE. Those raw values are
# found by binary search over the datasheet's compensation formulas (the
# floating-point ones, §8.1), so a driver that compensates them reads the
# sliders' values back. The calibration words are fixed: T and P are the
# worked example of Bosch's BMP280 datasheet (§3.12), the humidity words a
# plausible set (sim choice: no real dump at hand).

module PicoSim
  class Bme280
    DIG_T = [27504, 26435, -1000]
    DIG_P = [36477, -10685, 3024, 2855, 140, -7, 15500, -14600, 6000]
    DIG_H1 = 75
    DIG_H = [362, 0, 313, 50, 30]   # H2 (s16), H3 (u8), H4, H5 (s12), H6 (s8)

    def initialize
      @regs = Array.new(256, 0)
      @ptr = 0
      calibration
      reset
    end

    def reset
      @regs[0xD0] = 0x60
      @regs[0xF2] = 0
      @regs[0xF3] = 0
      @regs[0xF4] = 0
      @regs[0xF5] = 0
      @measured = false
    end

    def put16(addr, value)
      value += 65536 if value < 0
      @regs[addr] = value & 0xFF
      @regs[addr + 1] = (value >> 8) & 0xFF
    end

    def calibration
      DIG_T.each_with_index { |v, i| put16(0x88 + i * 2, v) }
      DIG_P.each_with_index { |v, i| put16(0x8E + i * 2, v) }
      @regs[0xA1] = DIG_H1
      put16(0xE1, DIG_H[0])
      @regs[0xE3] = DIG_H[1]
      h4 = DIG_H[2]
      h5 = DIG_H[3]
      @regs[0xE4] = (h4 >> 4) & 0xFF
      @regs[0xE5] = (h4 & 0x0F) | ((h5 & 0x0F) << 4)
      @regs[0xE6] = (h5 >> 4) & 0xFF
      @regs[0xE7] = DIG_H[4] & 0xFF
    end

    # [register, value, register, value, ...]; a single byte sets the pointer
    def i2c_write(world, bytes)
      return if bytes.empty?
      @ptr = bytes[0]
      i = 1
      while i + 0 < bytes.size
        write_reg(world, @ptr, bytes[i])
        @ptr = bytes[i + 1] if i + 1 < bytes.size
        i += 2
      end
    end

    def write_reg(world, reg, value)
      if reg == 0xE0
        reset if value == 0xB6
      elsif reg == 0xF2 || reg == 0xF4 || reg == 0xF5
        @regs[reg] = value
        # a measurement starts with a write to ctrl_meas: forced or normal
        @measured = true if reg == 0xF4 && (value & 0x03) != 0
      end
    end

    def i2c_read(world, len)
      fill(world) if @ptr <= 0xFE && @ptr + len > 0xF7
      out = []
      len.times do |i|
        reg = @ptr + i
        out << (reg < 256 ? @regs[reg] : 0)
      end
      out
    end

    # the raw values for the sliders; before any measurement, the reset
    # values (0x80000, 0x8000)
    def fill(world)
      ctrl = @regs[0xF4]
      raw_t = 0x80000
      raw_p = 0x80000
      raw_h = 0x8000
      if @measured
        t = world.input_f("bme.t", 21.0)
        rh = world.input_f("bme.rh", 45.0)
        p = world.input_f("bme.p", 1013.25)
        raw_t = Bme280.find(0, 0xFFFFF) { |adc| Bme280.temperature(adc)[0] >= t } if (ctrl >> 5) != 0
        fine = Bme280.temperature(raw_t)[1]
        raw_p = Bme280.find(0, 0xFFFFF) { |adc| Bme280.pressure(adc, fine) <= p * 100 } if ((ctrl >> 2) & 7) != 0
        raw_h = Bme280.find(0, 0xFFFF) { |adc| Bme280.humidity(adc, fine) >= rh } if (@regs[0xF2] & 7) != 0
      end
      @regs[0xF7] = (raw_p >> 12) & 0xFF
      @regs[0xF8] = (raw_p >> 4) & 0xFF
      @regs[0xF9] = (raw_p & 0x0F) << 4
      @regs[0xFA] = (raw_t >> 12) & 0xFF
      @regs[0xFB] = (raw_t >> 4) & 0xFF
      @regs[0xFC] = (raw_t & 0x0F) << 4
      @regs[0xFD] = (raw_h >> 8) & 0xFF
      @regs[0xFE] = raw_h & 0xFF
    end

    # the smallest value in lo..hi for which the block is true (it must be
    # monotonic: false, ..., false, true, ..., true)
    def self.find(lo, hi)
      while lo < hi
        mid = (lo + hi) / 2
        if yield(mid)
          hi = mid
        else
          lo = mid + 1
        end
      end
      lo
    end

    # datasheet §8.1: [°C, t_fine]
    def self.temperature(adc)
      t1, t2, t3 = DIG_T
      var1 = (adc / 16384.0 - t1 / 1024.0) * t2
      var2 = (adc / 131072.0 - t1 / 8192.0) * (adc / 131072.0 - t1 / 8192.0) * t3
      fine = var1 + var2
      [fine / 5120.0, fine]
    end

    # Pa
    def self.pressure(adc, fine)
      p1, p2, p3, p4, p5, p6, p7, p8, p9 = DIG_P
      var1 = fine / 2.0 - 64000.0
      var2 = var1 * var1 * p6 / 32768.0
      var2 += var1 * p5 * 2.0
      var2 = var2 / 4.0 + p4 * 65536.0
      var1 = (p3 * var1 * var1 / 524288.0 + p2 * var1) / 524288.0
      var1 = (1.0 + var1 / 32768.0) * p1
      return 0.0 if var1 == 0.0
      p = 1048576.0 - adc
      p = (p - var2 / 4096.0) * 6250.0 / var1
      var1 = p9 * p * p / 2147483648.0
      var2 = p * p8 / 32768.0
      p + (var1 + var2 + p7) / 16.0
    end

    # %RH
    def self.humidity(adc, fine)
      h2, h3, h4, h5, h6 = DIG_H
      h = fine - 76800.0
      h = (adc - (h4 * 64.0 + h5 / 16384.0 * h)) *
          (h2 / 65536.0 * (1.0 + h6 / 67108864.0 * h * (1.0 + h3 / 67108864.0 * h)))
      h *= 1.0 - DIG_H1 * h / 524288.0
      h = 100.0 if h > 100.0
      h = 0.0 if h < 0.0
      h
    end
  end

  # the other chips on the board: they acknowledge and read 0
  class QuietChip
    def i2c_write(world, bytes) = nil
    def i2c_read(world, len) = Array.new(len, 0)
  end

  class EnvSensor < Part
    def pins = [20, 21]

    def attach(world)
      @bme = Bme280.new
      world.i2c_device(0, 0x76, @bme)
      [0x29, 0x68, 0x53, 0x59].each { |addr| world.i2c_device(0, addr, QuietChip.new) }
    end

    def state(world)
      { "t" => world.input_f("bme.t", 21.0), "rh" => world.input_f("bme.rh", 45.0),
        "p" => world.input_f("bme.p", 1013.25) }
    end
  end
  PARTS["envsensor"] = EnvSensor
end
