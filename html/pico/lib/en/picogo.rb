# The Waveshare PicoGo's two motors, through its TB6612 driver chip: one
# PWM pin for the speed and two pins for the direction per motor (the pins
# and the direction table are Waveshare's Motor.py). Plain PicoRuby: it
# runs in the simulator and, put into /lib on an R2P2 Pico, on the robot.
#
#   robot = PicoGo.new
#   robot.forward(50)    # speed 0..100 (% duty)
#   sleep_ms 1000
#   robot.stop
require "gpio"
require "pwm"

class PicoGo
  def initialize(frequency: 1000)
    @pwma = PWM.new(16, frequency: frequency, duty: 0)   # left motor
    @ain2 = GPIO.new(17, GPIO::OUT)
    @ain1 = GPIO.new(18, GPIO::OUT)
    @bin1 = GPIO.new(19, GPIO::OUT)                      # right motor
    @bin2 = GPIO.new(20, GPIO::OUT)
    @pwmb = PWM.new(21, frequency: frequency, duty: 0)
  end

  def forward(speed)
    set_motor(speed, speed)
  end

  def backward(speed)
    set_motor(-speed, -speed)
  end

  # on the spot: the left wheel back, the right one forward
  def left(speed)
    set_motor(-speed, speed)
  end

  def right(speed)
    set_motor(speed, -speed)
  end

  def stop
    set_motor(0, 0)
  end

  # each wheel -100..100: + forward, - backward, 0 stop
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
