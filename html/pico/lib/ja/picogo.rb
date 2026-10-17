# Waveshare PicoGo の 2 つのモーターを、ドライバ IC TB6612 で動かします。
# モーター 1 つにつき、速さの PWM ピン 1 本と向きのピン 2 本(ピンと向きの表は
# Waveshare の Motor.py のもの)。ふつうの PicoRuby なので、シミュレータでも、
# R2P2 の Pico の /lib に置けばロボットでも動きます。
#
#   robot = PicoGo.new
#   robot.forward(50)    # 速さ 0..100(デューティ比 %)
#   sleep_ms 1000
#   robot.stop
require "gpio"
require "pwm"

class PicoGo
  def initialize(frequency: 1000)
    @pwma = PWM.new(16, frequency: frequency, duty: 0)   # 左モーター
    @ain2 = GPIO.new(17, GPIO::OUT)
    @ain1 = GPIO.new(18, GPIO::OUT)
    @bin1 = GPIO.new(19, GPIO::OUT)                      # 右モーター
    @bin2 = GPIO.new(20, GPIO::OUT)
    @pwmb = PWM.new(21, frequency: frequency, duty: 0)
  end

  def forward(speed)
    set_motor(speed, speed)
  end

  def backward(speed)
    set_motor(-speed, -speed)
  end

  # その場で: 左の車輪は後ろへ、右は前へ
  def left(speed)
    set_motor(-speed, speed)
  end

  def right(speed)
    set_motor(speed, -speed)
  end

  def stop
    set_motor(0, 0)
  end

  # 車輪ごとに -100..100: + 前、- 後ろ、0 停止
  def set_motor(left, right)
    wheel(@pwma, @ain1, @ain2, left)
    wheel(@pwmb, @bin1, @bin2, right)
  end

  private

  def wheel(pwm, in1, in2, speed)
    speed = 100 if speed > 100
    speed = -100 if speed < -100
    if speed > 0
      in1.write(0)
      in2.write(1)
    elsif speed < 0
      in1.write(1)
      in2.write(0)
    else
      in1.write(0)
      in2.write(0)
    end
    pwm.duty(speed.abs)
  end
end
