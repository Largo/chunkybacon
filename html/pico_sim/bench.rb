# A cell's bench script ("bench" in lessons.js, docs/HANDOVER.md §6r): what
# a finger, a lamp or a laptop does to the board, at fixed times (ms since
# the run started), the same on the page and in the check harness. An
# exercise that needs inputs has one, so its check is deterministic.
#
#   {"at": 0,   "set": {"adc26": 0.8}}     an input's value from then on
#   {"at": 300, "press": 14}               button on GP14 pressed ("pin14" = 1)
#   {"at": 450, "release": 14}
#   {"at": 0,   "arena": "wall60"}         the robot's arena layout
#   {"at": 0,   "ble": "connect"}          the laptop connects ("disconnect")
#   {"at": 300, "ble": "PING"}             the laptop sends a line
#   {"at": 0,   "wifi": "off"}             the access point goes away ("on")
#
# A scripted value wins over the page's input for that key until the run
# ends; the state the page gets carries them ("scripted"), so the bench can
# show the robot finger.

module PicoSim
  class Bench
    attr_reader :values

    def initialize(events)
      list = []
      events.each_with_index { |e, i| list << [(e["at"] || 0).to_f, i, e] if e.is_a?(Hash) }
      @events = list.sort { |a, b| a[0] == b[0] ? a[1] <=> b[1] : a[0] <=> b[0] }
      @next = 0
      @values = {}
    end

    def value(key)
      @values[key]
    end

    def apply(world, t)
      while @next < @events.size && @events[@next][0] <= t
        run(world, @events[@next][2])
        @next += 1
      end
    end

    def run(world, event)
      if event["set"].is_a?(Hash)
        event["set"].each { |key, value| @values[key.to_s] = value.to_s }
      end
      @values["pin#{event['press']}"] = "1" if event["press"]
      @values["pin#{event['release']}"] = "0" if event["release"]
      @values["wifi.off"] = (event["wifi"].to_s == "off" ? "1" : "0") if event["wifi"]
      if event["arena"]
        robot = world.part("picogo")
        robot.layout(world, event["arena"].to_s) if robot
      end
      world.radio.bench(world, event["ble"].to_s) if event["ble"]
    end
  end
end
