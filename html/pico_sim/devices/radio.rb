# The Bluetooth LE link between the Pico 2 W (stand_ins/ble.rb's BLE::UART,
# a peripheral) and a laptop (the bench's laptop panel, the bench script,
# or the lesson's CRuby cell through the page) - world state, so a check
# sees what was said (docs/HANDOVER.md §6r).
#
# Lines reach the Pico's RX from the bench ({"ble": "PING"}) and from the
# page: input "ble.line" = "<n>|<text>", where a new <n> queues <text> once.
# A line from the laptop connects it first (a central that writes is
# connected); {"ble": "connect"} / "disconnect" and input "ble.connected"
# do it explicitly. What the Pico sends goes to the page ("ble" messages).

module PicoSim
  class Radio
    attr_reader :adv, :rx_log, :tx

    def initialize
      @adv = nil          # the name while BLE::UART#start advertises
      @connected = false
      @queue = []         # lines on their way to the Pico
      @rx_log = []        # every line that reached it
      @tx = ""
      @page_seen = nil
      @page_connected = nil
    end

    def advertising? = !@adv.nil?

    # the Pico's side starts advertising (BLE::UART#start)
    def advertise(name)
      @adv = name
    end

    def connected? = @connected && advertising?

    def connect(world, on)
      return if @connected == on
      @connected = on
      world.event("ble", on ? "connected" : "disconnected")
    end

    def bench(world, what)
      case what
      when "connect" then connect(world, true)
      when "disconnect" then connect(world, false)
      else send_line(world, what)
      end
    end

    def send_line(world, text)
      connect(world, true)
      line = text.end_with?("\n") ? text : "#{text}\n"
      @queue << line
      # the bench's laptop shows what it sent, wherever it came from
      world.event("ble", "rx|#{line.chomp}")
    end

    # the page's laptop panel (or the CRuby cell through it)
    def poll_page(world)
      wanted = PicoSim.host.input("ble.connected").to_s
      if wanted != "" && wanted != @page_connected
        @page_connected = wanted
        connect(world, wanted == "1")
      end
      value = PicoSim.host.input("ble.line").to_s
      return if value == "" || value == @page_seen
      @page_seen = value
      bar = value.index("|")
      send_line(world, bar ? value[(bar + 1)..-1] : value)
    end

    # what has arrived for the Pico since the last call ("" for nothing)
    def take
      return "" unless connected?
      text = @queue.join
      @queue.each { |line| @rx_log << line.chomp }
      @queue = []
      text
    end

    # the Pico notifies: the laptop gets it
    def send_out(world, data)
      @tx << data
      @tx = @tx[(@tx.size - 8192)..-1] if @tx.size > 8192
      world.event("ble", "tx|#{data}")
    end

    def state
      { "adv" => @adv, "connected" => connected? }
    end

    def summary
      { "adv" => @adv, "connected" => connected?, "rx" => @rx_log, "tx" => @tx }
    end
  end
end
