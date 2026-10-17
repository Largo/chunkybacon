# A driver for the Bosch BME280 (temperature, humidity, air pressure) on
# I2C, as on the Waveshare Pico-Environment-Sensor (address 0x76). Plain
# PicoRuby: it runs in the simulator and, put into /lib on an R2P2 Pico,
# on the board. The formulas are the datasheet's (BST-BME280-DS002, §8.1).
#
#   i2c = I2C.new(unit: :RP2040_I2C0, frequency: 400_000, sda_pin: 20, scl_pin: 21)
#   bme = BME280.new(i2c)
#   bme.temperature   # => 21.0 (°C)
#   bme.humidity      # => 45.0 (%)
#   bme.pressure      # => 1013.2 (hPa)
require "i2c"

class BME280
  ADDRESS = 0x76

  def initialize(i2c, address: ADDRESS)
    @i2c = i2c
    @address = address
    id = @i2c.read(@address, 1, 0xD0).getbyte(0)
    raise "no BME280 at #{format('0x%02x', @address)} (id #{id})" unless id == 0x60
    @i2c.write(@address, 0xE0, 0xB6)    # reset
    sleep_ms 5
    read_calibration
    @i2c.write(@address, 0xF2, 0x01)    # humidity x1
    @i2c.write(@address, 0xF4, 0x27)    # temperature x1, pressure x1, normal mode
    sleep_ms 10
  end

  def temperature
    measure[0]
  end

  def humidity
    measure[1]
  end

  def pressure
    measure[2]
  end

  # [°C, %, hPa], rounded to one decimal
  def measure
    d = @i2c.read(@address, 8, 0xF7)
    adc_p = (d.getbyte(0) << 12) | (d.getbyte(1) << 4) | (d.getbyte(2) >> 4)
    adc_t = (d.getbyte(3) << 12) | (d.getbyte(4) << 4) | (d.getbyte(5) >> 4)
    adc_h = (d.getbyte(6) << 8) | d.getbyte(7)
    t1, t2, t3 = @t
    var1 = (adc_t / 16384.0 - t1 / 1024.0) * t2
    var2 = (adc_t / 131072.0 - t1 / 8192.0) * (adc_t / 131072.0 - t1 / 8192.0) * t3
    fine = var1 + var2
    [(fine / 5120.0).round(1), humidity_from(adc_h, fine).round(1), (pressure_from(adc_p, fine) / 100.0).round(1)]
  end

  private

  def u16(s, i) = s.getbyte(i) | (s.getbyte(i + 1) << 8)

  def s16(s, i)
    v = u16(s, i)
    v >= 32768 ? v - 65536 : v
  end

  def read_calibration
    c = @i2c.read(@address, 26, 0x88)
    @t = [u16(c, 0), s16(c, 2), s16(c, 4)]
    @p = [u16(c, 6)]
    8.times { |i| @p << s16(c, 8 + i * 2) }
    @h1 = c.getbyte(25)
    h = @i2c.read(@address, 7, 0xE1)
    h4 = (h.getbyte(3) << 4) | (h.getbyte(4) & 0x0F)
    h5 = (h.getbyte(5) << 4) | (h.getbyte(4) >> 4)
    h6 = h.getbyte(6)
    h6 -= 256 if h6 > 127
    @h = [s16(h, 0), h.getbyte(2), h4, h5, h6]
  end

  def pressure_from(adc, fine)
    p1, p2, p3, p4, p5, p6, p7, p8, p9 = @p
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

  def humidity_from(adc, fine)
    h2, h3, h4, h5, h6 = @h
    h = fine - 76800.0
    h = (adc - (h4 * 64.0 + h5 / 16384.0 * h)) *
        (h2 / 65536.0 * (1.0 + h6 / 67108864.0 * h * (1.0 + h3 / 67108864.0 * h)))
    h *= 1.0 - @h1 * h / 524288.0
    h = 100.0 if h > 100.0
    h = 0.0 if h < 0.0
    h
  end
end
