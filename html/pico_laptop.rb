# The laptop's side of lesson pico-ble (docs/HANDOVER.md §6r): a cell with
# "engine": "cruby" in a Pico lesson runs on CRuby, and require "ble" gives
# it this file - the blockless subset of the `ble` gem 1.0.0 (BlueZ over
# D-Bus on Linux) that the lesson uses, talking to the simulated Pico 2 W
# through the page's bench (pico_board.js) instead of a radio.
#
#   adapter = BLE::Adapter.new("hci0")
#   adapter.start_discovery; sleep 2; adapter.stop_discovery
#   pico = adapter[adapter.devices.first]
#   pico.connect
#   pico.subscribe(NUS, TX, raw: true) { |bytes| print bytes }
#   pico.[]=(NUS, RX, "PING\n", raw: true)
#   DBus::Main.new.tap { |m| m << DBus::SystemBus.instance }.run
#
# The Pico is "there" while a cell of the lesson runs BLE::UART#start (the
# bench reports its advertising name). A notification block is kept; the
# page calls it for each line the Pico sends (main.rb: chunky:pico-ble), and
# what it prints is appended to the output of the cell that subscribed. On
# a real Linux box DBus::Main#run is the loop that delivers them; here it
# returns at once. Loaded by main.rb's "ble.rb" shim; runs under plain
# CRuby too (test/pico_laptop_test.rb sets a host of its own).
module PicoLaptop
  # The Nordic UART Service: what PicoRuby's BLE::UART offers
  NUS = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
  RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"   # the laptop writes here
  TX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"   # the Pico notifies here
  # a made-up address for the simulated Pico (Raspberry Pi's prefix 28:CD:C1)
  MAC = "28:CD:C1:0B:AC:01"

  # The bench, as main.rb sees it: state (a Hash with "adv", "connected",
  # "running"), connect(on), send_line(text)
  class PageHost
    def state
      board = $window[:chunkyPicoBoard]
      return {} unless board.typeof == "object" && board[:ble].typeof == "function"

      JSON.parse(board.ble.to_s)
    rescue JSON::ParserError
      {}
    end

    def connect(on)
      $window.chunkyPicoBoard.input("ble.connected", on ? "1" : "0")
    end

    def send_line(text)
      $window.chunkyPicoBoard.sendLine(text)
    end
  end

  class << self
    attr_writer :host
    # the cell that runs now (main.rb sets it around a cruby cell's run)
    attr_accessor :cell

    def host = (@host ||= PageHost.new)

    # [[cell, block], ...]: the notification blocks, newest last
    def subscriptions = (@subscriptions ||= [])

    def subscribe(block)
      subscriptions << [cell, block]
    end

    # a cell runs again (or the lesson changes): its blocks go
    def forget(cell = nil)
      cell.nil? ? subscriptions.clear : subscriptions.reject! { |c, _| c == cell }
    end

    # The Pico sent +data+: each block once. Yields [cell, what it printed]
    # so the page can append it to that cell's output.
    def deliver(data)
      subscriptions.map do |c, block|
        old = $stdout
        buffer = StringIO.new
        $stdout = buffer
        begin
          block.call(data.dup)
        rescue StandardError => e
          buffer.puts "#{e.class}: #{e.message}"
        ensure
          $stdout = old
        end
        yield c, buffer.string if block_given?
        [c, buffer.string]
      end
    end

    def advertising
      s = host.state
      s["running"] && s["adv"].to_s != "" ? s["adv"].to_s : nil
    end
  end
end

module BLE
  class Error < StandardError; end
  class NotFound < Error; end
  class NotSupported < Error; end

  class Adapter
    # what BlueZ lists; the simulated laptop has one
    def self.list = ["hci0"]

    attr_reader :iface

    def initialize(iface)
      raise NotFound, "no adapter #{iface}" unless Adapter.list.include?(iface.to_s)

      @iface = iface.to_s
      @discovering = false
    end

    def start_discovery
      @discovering = true
      true
    end

    def stop_discovery
      @discovering = false
      true
    end

    def discovering? = @discovering

    # the addresses BlueZ has seen: the Pico's while it advertises
    def devices
      PicoLaptop.advertising ? [PicoLaptop::MAC] : []
    end

    def [](address)
      raise NotFound, "no device #{address}" unless devices.include?(address.to_s.upcase)

      Device.new(address.to_s.upcase)
    end
  end

  class Device
    attr_reader :address

    def initialize(address)
      @address = address
      @connected = false
    end

    def name = PicoLaptop.advertising

    def alias = name

    def services = [PicoLaptop::NUS]

    def characteristics(service)
      check(service, PicoLaptop::RX)
      [PicoLaptop::RX, PicoLaptop::TX]
    end

    def connect
      raise NotFound, "#{@address} is gone (the Pico stopped advertising)" unless PicoLaptop.advertising

      PicoLaptop.host.connect(true)
      @connected = true
    end

    def disconnect
      PicoLaptop.host.connect(false)
      @connected = false
      true
    end

    def is_connected?
      @connected && PicoLaptop.host.state["connected"] == true
    end
    alias connected? is_connected?

    # the gem's write: device[service, characteristic, raw: true] = value
    # (an index assignment with a keyword no longer parses since Ruby 3.4,
    # so the lesson calls it as pico.[]=(svc, char, value, raw: true))
    def []=(service, characteristic, value, raw: false)
      check(service, characteristic)
      raise NotSupported, "the Pico only notifies on #{characteristic}" unless same?(characteristic, PicoLaptop::RX)
      raise Error, "not connected" unless @connected

      PicoLaptop.host.send_line(value.to_s)
    end

    def [](service, characteristic, raw: false)
      check(service, characteristic)
      raise NotSupported, "the Pico's UART characteristics cannot be read, only notified"
    end

    # each notification on +characteristic+ calls the block with the bytes
    def subscribe(service, characteristic, raw: false, &block)
      check(service, characteristic)
      raise NotSupported, "the laptop writes #{characteristic}, the Pico notifies on TX" unless same?(characteristic, PicoLaptop::TX)
      raise ArgumentError, "subscribe needs a block" unless block

      PicoLaptop.subscribe(block)
      true
    end

    private

    def same?(a, b) = a.to_s.downcase == b

    def check(service, characteristic)
      raise NotFound, "no service #{service}" unless same?(service, PicoLaptop::NUS)
      raise NotFound, "no characteristic #{characteristic}" unless [PicoLaptop::RX, PicoLaptop::TX].include?(characteristic.to_s.downcase)
    end
  end
end

# ruby-dbus, as far as the `ble` gem's users touch it
module DBus
  class SystemBus
    def self.instance = (@instance ||= new)
  end

  class SessionBus
    def self.instance = (@instance ||= new)
  end

  class Main
    def initialize
      @buses = []
    end

    def <<(bus)
      @buses << bus
      self
    end

    # On Linux: the loop that delivers the notifications, until you quit.
    # On this page the bench delivers them, so it returns at once.
    def run = nil

    def quit = nil
  end
end
