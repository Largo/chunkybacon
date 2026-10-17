# picoruby-hcsr04's HCSR04, simulated: its mrblib times the echo pulse with
# Time.now.usec in a busy loop, which a simulation cannot feed; this one
# asks the robot's ray (devices/picogo.rb) and takes as long as a real
# measurement would. The gem is in the PicoRuby repository but in no
# default R2P2 build (the lesson says so).
require "gpio"

class HCSR04
  class TimeoutError < StandardError; end
  class WraparoundError < StandardError; end

  TIMEOUT_USEC = 30_000

  def initialize(trig:, echo:)
    @trig = GPIO.new(trig, GPIO::OUT)
    @echo = GPIO.new(echo, GPIO::IN)
  end

  def distance_cm
    @trig.write 1
    sleep_ms 1
    @trig.write 0
    robot = PicoSim.world.part("picogo")
    raise TimeoutError.new("Echo signal not received within #{TIMEOUT_USEC} us") unless robot
    d = robot.sonar(PicoSim.world)
    # the echo's way there and back at 343 m/s
    sleep_ms((d * 2 / 34.3).round + 1)
    (d * 2 / 0.0343 * 1_715 / 100_000).to_i
  end
end
