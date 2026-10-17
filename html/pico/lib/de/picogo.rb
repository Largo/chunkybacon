# Die zwei Motoren des Waveshare PicoGo über seinen Treiberchip TB6612: pro
# Motor ein PWM-Pin für die Geschwindigkeit und zwei Pins für die Richtung
# (Pins und Richtungstabelle aus Waveshares Motor.py). Reines PicoRuby: Er
# läuft im Simulator und, nach /lib eines R2P2-Picos gelegt, auf dem Roboter.
#
#   robot = PicoGo.new
#   robot.forward(50)    # Geschwindigkeit 0..100 (% Duty)
#   sleep_ms 1000
#   robot.stop
require "gpio"
require "pwm"

class PicoGo
  def initialize(frequency: 1000)
    @pwma = PWM.new(16, frequency: frequency, duty: 0)   # linker Motor
    @ain2 = GPIO.new(17, GPIO::OUT)
    @ain1 = GPIO.new(18, GPIO::OUT)
    @bin1 = GPIO.new(19, GPIO::OUT)                      # rechter Motor
    @bin2 = GPIO.new(20, GPIO::OUT)
    @pwmb = PWM.new(21, frequency: frequency, duty: 0)
  end

  def forward(speed)
    set_motor(speed, speed)
  end

  def backward(speed)
    set_motor(-speed, -speed)
  end

  # an Ort und Stelle: linkes Rad zurück, rechtes vorwärts
  def left(speed)
    set_motor(-speed, speed)
  end

  def right(speed)
    set_motor(speed, -speed)
  end

  def stop
    set_motor(0, 0)
  end

  # jedes Rad -100..100: + vorwärts, - rückwärts, 0 Halt
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
