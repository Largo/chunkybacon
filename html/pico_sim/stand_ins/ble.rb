# picoruby-ble-uart's BLE::UART (by HASUMI Hitoshi) as a peripheral, over
# the simulated radio (devices/radio.rb): the public methods of 4.0.3's
# mrblib/ble_uart.rb with their return values - start(timeout_ms) { }
# turns every 20 ms (USER_BLOCK_INTERVAL_MS), write answers the bytes
# queued (0 while nobody is connected), the buffers keep their last 1024
# bytes. The BTstack below it is C, so this is a stand-in, not a copy
# (docs/HANDOVER.md §6r). Raw BLE (GATT) and the central role are not
# simulated.

class BLE
  def initialize(*args)
    raise NotImplementedError.new("the simulator knows BLE::UART as peripheral only")
  end

  class UART < BLE
    NUS_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    NUS_RX_CHAR_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    NUS_TX_CHAR_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    USER_BLOCK_INTERVAL_MS = 20
    TX_BUFFER_LIMIT = 1024
    RX_BUFFER_LIMIT = 1024

    def initialize(role: :peripheral, name: "RubyUART", service_uuid: NUS_SERVICE_UUID,
                   rx_uuid: NUS_RX_CHAR_UUID, tx_uuid: NUS_TX_CHAR_UUID)
      raise NotImplementedError.new("the simulator knows BLE::UART as peripheral only") if role != :peripheral
      @role = role
      @name = name
      @rx_buffer = ""
      @tx_buffer = ""
      @connected = false
      @on_connect = nil
      @on_disconnect = nil
    end

    def radio__ = PicoSim.world.radio

    def start(timeout_ms = nil, &block)
      @user_block = block
      started_at = Machine.board_millis
      total = 0
      radio__.advertise(@name)
      PicoSim.world.event("ble", "advertising|#{@name}")
      begin
        while true
          total = Machine.board_millis - started_at
          break if timeout_ms && timeout_ms <= total
          wait = USER_BLOCK_INTERVAL_MS
          if timeout_ms
            remaining = timeout_ms - total
            wait = remaining if remaining < wait
          end
          sleep_ms wait
          PicoSim.world.advance
          poll__
          @user_block&.call
        end
      ensure
        radio__.advertise(nil)
        poll__
      end
      Machine.board_millis - started_at
    end

    # the link's state, what arrived, what goes out
    def poll__
      link = radio__.connected?
      if link && !@connected
        @connected = true
        @on_connect&.call
      elsif !link && @connected
        @connected = false
        @tx_buffer = ""
        @on_disconnect&.call
      end
      data = radio__.take
      unless data.empty?
        @rx_buffer << data
        @rx_buffer = @rx_buffer.byteslice(-RX_BUFFER_LIMIT, RX_BUFFER_LIMIT) || "" if @rx_buffer.bytesize > RX_BUFFER_LIMIT
      end
      flush__
    end

    def flush__
      return if @tx_buffer.empty? || !@connected
      radio__.send_out(PicoSim.world, @tx_buffer)
      @tx_buffer = ""
    end

    def peripheral? = true
    def central? = false

    def on_connect(&block)
      @on_connect = block
    end

    def on_disconnect(&block)
      @on_disconnect = block
    end

    def write(data)
      str = data.to_s
      return 0 unless @connected
      @tx_buffer << str
      accepted = str.bytesize
      if TX_BUFFER_LIMIT < @tx_buffer.bytesize
        accepted = TX_BUFFER_LIMIT if TX_BUFFER_LIMIT < accepted
        @tx_buffer = @tx_buffer.byteslice(-TX_BUFFER_LIMIT, TX_BUFFER_LIMIT) || ""
      end
      accepted
    end

    def puts(data = "")
      str = data.to_s
      write(str)
      write("\n") unless str.end_with?("\n")
      nil
    end

    def read_nonblock(nbytes = 256)
      return nil if @rx_buffer.empty?
      count = nbytes < @rx_buffer.bytesize ? nbytes : @rx_buffer.bytesize
      result = @rx_buffer.byteslice(0, count)
      @rx_buffer = @rx_buffer.byteslice(count, @rx_buffer.bytesize - count) || ""
      result
    end

    def gets_nonblock
      idx = @rx_buffer.index("\n")
      return nil unless idx
      line = @rx_buffer.byteslice(0, idx + 1)
      @rx_buffer = @rx_buffer.byteslice(idx + 1, @rx_buffer.bytesize - idx - 1) || ""
      line
    end

    def available = @rx_buffer.bytesize
    def available? = 0 < @rx_buffer.bytesize
    def connected? = @connected
  end
end
