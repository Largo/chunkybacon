# The simple parts on the breadboard (docs/HANDOVER.md §6r, the parts
# table): an LED with its resistor, a push button, a light sensor, the
# chip's temperature sensor, a passive buzzer, the simulated camera. A part
# registers the pins it drives or watches with the world (World#drive,
# #watch, #adc_source) and answers:
#
#   drive(world, pin, t)   the level it pulls the pin to, nil for none
#   on_write(world, pin, level, t)   an output pin it watches changed
#   adc_voltage(world, input, t)     the volts on an ADC input
#   advance(world, t)      time passed
#   state(world)           a Hash for the bench on the page (or nil)
#   summary(world, out)    adds its part of the summary (the check's board)

module PicoSim
  # id in a cell's board.parts => the part
  PARTS = {}

  def self.build_part(id)
    klass = PARTS[id]
    klass ? klass.new(id) : nil
  end

  class Part
    attr_reader :id

    def initialize(id)
      @id = id
    end

    def pins = []
    def attach(world) = nil
    def drive(world, pin, t) = nil
    def on_write(world, pin, level, t) = nil
    def adc_voltage(world, input, t) = 0.0
    def advance(world, t) = nil
    def state(world) = nil
    def summary(world, out) = nil
  end

  # a red LED and 330 ohm from GP15 to GND: lit while the pin is a high
  # output, as bright as the duty when it is a PWM
  class Led < Part
    def initialize(id)
      super
      @pin = 15
    end

    def pins = [@pin]

    def brightness(world)
      (world.pwm_duty(@pin) / 100.0).round(2)
    end

    def state(world)
      { "b" => brightness(world) }
    end
  end
  PARTS["led15"] = Led

  # a push button from GP14 to GND: pulls the pin low while it is pressed
  # (input "pin14" = "1", from the page or the bench)
  class Button < Part
    def initialize(id)
      super
      @pin = 14
    end

    def pins = [@pin]

    def attach(world)
      world.drive(@pin, self)
    end

    def pressed?(world)
      world.input("pin#{@pin}").to_s == "1"
    end

    def drive(world, pin, t)
      pressed?(world) ? 0 : nil
    end

    def state(world)
      { "pressed" => pressed?(world), "scripted" => world.scripted?("pin#{@pin}") }
    end
  end
  PARTS["button14"] = Button

  # an LDR and 10 kohm between 3V3 and GND, the middle on GP26/ADC0: input
  # "adc26" is the light, 0..1 (sim choice: the voltage follows it, 0..3.3 V)
  class LightSensor < Part
    def pins = [26]

    def attach(world)
      world.adc_source(0, self)
    end

    def light(world) = world.input_f("adc26", 0.5)

    def adc_voltage(world, input, t)
      light(world) * 3.3
    end

    def state(world)
      { "light" => light(world), "scripted" => world.scripted?("adc26") }
    end
  end
  PARTS["light26"] = LightSensor

  # inside the chip (ADC4): input "tempC", the room's temperature
  class TempSensor < Part
    def state(world)
      { "c" => world.input_f("tempC", 21.0), "scripted" => world.scripted?("tempC") }
    end
  end
  PARTS["temp"] = TempSensor

  # a passive piezo on GP16: the PWM's frequency is the tone; duty 0 or
  # frequency 0 is silence
  class Buzzer < Part
    def initialize(id)
      super
      @pin = 16
    end

    def pins = [@pin]

    def attach(world)
      world.watch(@pin, self)
    end

    def tone(world)
      world.pwm_duty(@pin) > 0 ? world.pwm_freq(@pin).round : 0
    end

    def on_write(world, pin, level, t)
      world.buzz(tone(world))
    end

    def state(world)
      { "hz" => tone(world) }
    end
  end
  PARTS["buzzer16"] = Buzzer

  # no pins: the picture comes from the bench's chooser (input "camera")
  class CameraPart < Part
    def state(world)
      { "picture" => (world.input("camera") || "chunky") }
    end
  end
  PARTS["camera"] = CameraPart

  # the access point "chunkynet" (stand_ins/cyw43.rb asks it); input
  # "wifi.off" = "1" switches it off
  class WifiAp < Part
    def up?(world) = world.input("wifi.off").to_s != "1"

    def state(world)
      { "up" => up?(world), "connected" => world.wifi.connected }
    end
  end
  PARTS["wifi"] = WifiAp

  # the laptop on the other end of BLE (devices/radio.rb holds the link)
  class Laptop < Part
    def advance(world, t)
      world.radio.poll_page(world)
    end

    def state(world)
      world.radio.state
    end
  end
  PARTS["laptop"] = Laptop
end
