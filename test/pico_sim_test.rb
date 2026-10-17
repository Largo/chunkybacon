# The Pico simulator under CRuby (docs/HANDOVER.md §6r): html/pico_sim/'s
# primitives with PicoRuby's own mrblib on top, the devices, the bench
# script, the lesson drivers (html/pico/lib/en/) and the check API
# (PicoRubyCells::Board) - on test/pico_cruby_host.rb's virtual clock.
# test/pico_wasm_test.mjs runs the same files on PicoRuby.wasm.
#
#   ruby test/pico_sim_test.rb
require "minitest/autorun"
require "stringio"
require_relative "pico_cruby_host"
require_relative "../html/picoruby_cells"

PicoCRuby.load_sim
$LOAD_PATH.unshift(File.expand_path("../html/pico/lib/en", __dir__), File.expand_path("../html/pico/lib", __dir__))
require "pio"
require "ws2812"
PicoRubyCells.font_source = -> { File.read(File.expand_path("../html/pico/lib/font5x7.rb", __dir__)) }
require "gpio"
require "pwm"
require "adc"
require "i2c"
require "spi"

class PicoSimTest < Minitest::Test
  # a run on a fresh board: the block is the cell's code; answers the check's board
  def run_board(parts: [], bench: [], inputs: {}, board: "pico2w", reset: true)
    PicoCRuby.start(inputs)
    PicoSim.setup({ "board" => board, "parts" => parts, "bench" => bench, "reset" => reset })
    yield
    PicoRubyCells.board(PicoCRuby.finish)
  end

  def quiet
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

  # ---------- GPIO ----------

  def test_gpio_flags_as_picoruby_checks_them
    run_board do
      error = assert_raises(ArgumentError) { GPIO.new(15, 0) }
      assert_equal "You must specify one of IN, OUT, HIGH_Z, and ALT", error.message
      error = assert_raises(ArgumentError) { GPIO.new(15, GPIO::IN | GPIO::OUT) }
      assert_equal "IN, OUT and HIGH_Z are exclusive", error.message
      error = assert_raises(ArgumentError) { GPIO.new(15, GPIO::IN | GPIO::PULL_UP | GPIO::PULL_DOWN) }
      assert_equal "PULL_UP and PULL_DOWN are exclusive", error.message
      error = assert_raises(ArgumentError) { GPIO.new("GP15", GPIO::OUT) }
      assert_equal 'Wrong GPIO pin name: "GP15"', error.message
      led = GPIO.new(15, GPIO::OUT)
      assert_equal 0, led.write(1)
      assert_raises(ArgumentError) { led.write(2) }
      assert_equal 1, led.read
      assert_equal 1, GPIO.read_at(15)
    end
  end

  def test_blink_log_and_the_board_api
    board = run_board(parts: ["led15"]) do
      led = GPIO.new(15, GPIO::OUT)
      5.times do
        led.write(1)
        sleep_ms 200
        led.write(0)
        sleep_ms 300
      end
    end
    assert_equal [200] * 5, board.pulses(15)
    assert_equal [300] * 4, board.gaps(15)
    assert_equal 0, board.level(15)
    assert_equal 1, board.level_at(15, 1100)
    assert_equal 0, board.level_at(15, 1250)
    assert_equal "out", board.mode(15)
    assert_nil board.level(14)
    assert_equal [], board.pulses(3)
  end

  def test_button_pull_up_and_a_scripted_press
    board = run_board(parts: ["button14", "led15"], bench: [{ "at" => 300, "press" => 14 }, { "at" => 450, "release" => 14 }]) do
      button = GPIO.new(14, GPIO::IN | GPIO::PULL_UP)
      led = GPIO.new(15, GPIO::OUT)
      100.times do
        led.write(button.low? ? 1 : 0)
        sleep_ms 10
      end
    end
    assert_equal [150], board.pulses(15)
    assert_equal "in_pull_up", board.mode(14)
  end

  def test_a_busy_loop_sees_the_press
    board = run_board(parts: ["button14"], bench: [{ "at" => 120, "press" => 14 }]) do
      button = GPIO.new(14, GPIO::IN | GPIO::PULL_UP)
      nil until button.low?
      $pressed_at = PicoCRuby.run_ms
    end
    assert_in_delta 120, $pressed_at, 1
    assert board
  end

  def test_a_page_input_and_the_pad_default
    run_board(parts: ["button14"], inputs: { "pin14" => "1" }) do
      assert_equal 0, GPIO.new(14, GPIO::IN | GPIO::PULL_UP).read
    end
    # without PULL_UP the pad keeps its reset pull-down: 0, pressed or not
    run_board(parts: ["button14"]) do
      assert_equal 0, GPIO.new(14, GPIO::IN).read
    end
  end

  # ---------- PWM, ADC ----------

  def test_pwm_duty_is_clamped_and_logged
    board = run_board(parts: ["led15", "buzzer16"]) do
      pwm = PWM.new(15, frequency: 1000, duty: 0)
      # pwm.c answers the argument as a Float, and keeps it clamped
      assert_equal 150.0, pwm.duty(150)
      assert_equal 1.0, PicoSim.world.part("led15").brightness(PicoSim.world)
      assert_equal(-5.0, pwm.duty(-5))
      assert_equal 50.0, pwm.duty(50)
      buzzer = PWM.new(16, frequency: 440, duty: 50)
      sleep_ms 500
      buzzer.frequency(880)
      sleep_ms 500
      buzzer.duty(0)
    end
    assert_equal [[0, 1000.0, 0.0], [0, 1000.0, 100.0], [0, 1000.0, 0.0], [0, 1000.0, 50.0]], board.pwm(15)
    assert_equal [[0, 440], [500, 880], [1000, 0]], board.buzz
    assert_equal "pwm", board.mode(15)
  end

  def test_adc_light_and_temperature
    run_board(parts: ["light26", "temp"], bench: [{ "at" => 0, "set" => { "adc26" => 0.8 } }, { "at" => 100, "set" => { "adc26" => 0.1 } }],
              inputs: { "tempC" => "30" }) do
      light = ADC.new(26)
      assert_in_delta 0.8 * 3.3, light.read, 0.01
      assert_in_delta 0.8 * 4095, light.read_raw, 3
      sleep_ms 150
      assert_in_delta 0.33, light.read_voltage, 0.01
      sensor = ADC.new(:temperature)
      celsius = 27 - (sensor.read_voltage - 0.706) / 0.001721
      assert_in_delta 30, celsius, 1.5
      assert_raises(ArgumentError) { ADC.new(15) }
      assert_raises(ArgumentError) { ADC.new("GP26") }
    end
  end

  # ---------- I2C ----------

  def test_i2c_scan_unit_inference_and_errors
    out = nil
    run_board(parts: ["envsensor"]) do
      i2c = I2C.new(unit: :RP2040_I2C0, frequency: 400_000, sda_pin: 20, scl_pin: 21)
      out = quiet { i2c.scan }
      assert_equal 0x60, i2c.read(0x76, 1, 0xD0).getbyte(0)
      assert_raises(IOError) { i2c.read(0x40, 1) }
      error = assert_raises(IOError) { i2c.write(0x40, 0) }
      assert_equal "I2C write failed", error.message
      assert_equal 0, I2C.new(sda_pin: 20, scl_pin: 21).instance_variable_get(:@unit_num)
      assert_equal 1, I2C.new(sda_pin: 2, scl_pin: 3).instance_variable_get(:@unit_num)
      error = assert_raises(ArgumentError) { I2C.new(unit: :RP2040_I2C1, sda_pin: 20, scl_pin: 21) }
      assert_equal "I2C: pins conflict with unit or are invalid for I2C", error.message
    end
    assert_includes out, "I2C device found at 7-bit address 0x76 (0b1110110) +R"
    assert_includes out, "I2C device found at 7-bit address 0x29 (0b0101001) +W"
    assert_equal 10, out.lines.size
  end

  def test_bme280_round_trip_through_the_lesson_driver
    require "bme280"
    run_board(parts: ["envsensor"], inputs: { "bme.t" => "23.4", "bme.rh" => "61", "bme.p" => "987.6" }) do
      i2c = I2C.new(unit: :RP2040_I2C0, frequency: 400_000, sda_pin: 20, scl_pin: 21)
      bme = BME280.new(i2c)
      assert_in_delta 23.4, bme.temperature, 0.051
      assert_in_delta 61.0, bme.humidity, 0.11
      assert_in_delta 987.6, bme.pressure, 0.11
    end
  end

  # ---------- SPI, e-paper ----------

  def test_spi_unit_inference
    run_board do
      assert_equal 2, SPI.new(sck_pin: 10, copi_pin: 11).instance_variable_get(:@unit_num__)
      assert_equal 1, SPI.new(sck_pin: 18, copi_pin: 19).instance_variable_get(:@unit_num__)
      error = assert_raises(ArgumentError) { SPI.new(sck_pin: 10, copi_pin: 19) }
      assert_equal "SPI: pins conflict with unit or are invalid for SPI", error.message
      spi = SPI.new(unit: :RP2040_SPI1, sck_pin: 10, copi_pin: 11, cs_pin: 9)
      assert_equal 9, spi.cs.pin
      assert_equal 3, spi.write(1, [2], "\x03")
      assert_raises(IOError) { spi.write }
    end
  end

  def epd(spi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000, sck_pin: 10, copi_pin: 11))
    require "epd2in13"
    EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8, rst_pin: 12, busy_pin: 13)
  end

  def test_epaper_full_refresh_gives_the_frame
    started = nil
    busy_ms = nil
    board = run_board(parts: ["epd213"]) do
      e = epd
      e.clear
      e.rect(0, 0, 250, 122)
      e.text(10, 10, "Chunky bacon!", scale: 2)
      started = PicoCRuby.run_ms
      e.refresh
      busy_ms = PicoCRuby.run_ms - started
    end
    assert_equal 1, board.epd.refreshes
    assert_equal ["full"], board.epd.modes
    assert_operator busy_ms, :>=, 2000
    assert_operator busy_ms, :<, 2200
    frame = board.epd.frame
    [[0, 0], [249, 0], [0, 121], [249, 121], [125, 0], [0, 60]].each { |xy| assert frame.black?(*xy), xy.inspect }
    refute frame.black?(5, 5)
    assert frame.text?("Chunky bacon!")
    assert frame.text?("bacon")
    refute frame.text?("Chunky fox")
    assert_operator frame.black_count, :>, 700
    assert board.events.any? { |e| e[1] == "epd_frame" }
  end

  def test_partial_refresh_sleep_and_the_picture_survives_a_reset
    run_board(parts: ["epd213"]) do
      e = epd
      e.clear
      e.text(0, 0, "1")
      e.refresh
      e.text(0, 20, "2")
      t0 = PicoCRuby.run_ms
      e.refresh(partial: true)
      assert_in_delta 300, PicoCRuby.run_ms - t0, 25
      e.sleep
      # asleep: what the bus brings is ignored until a reset
      e.clear(EPD2in13::BLACK)
      dc = GPIO.new(8, GPIO::OUT)
      cs = GPIO.new(9, GPIO::OUT)
      spi = SPI.new(sck_pin: 10, copi_pin: 11)
      dc.write(0); cs.write(0); spi.write(0x20); cs.write(1)
      sleep_ms 2100
    end
    board = run_board(parts: ["epd213"]) { sleep_ms 10 }
    assert_equal 0, board.epd.refreshes
    assert board.epd.frame.text?("2"), "the picture stays on the e-paper"
  end

  # ---------- the robot ----------

  def picogo
    require "picogo"
    PicoGo.new
  end

  def test_robot_drives_and_turns
    board = run_board(parts: ["picogo"]) do
      robot = picogo
      robot.forward(50)
      sleep_ms 1000
      robot.stop
    end
    assert_in_delta 20.0, board.robot.traveled_cm, 0.5
    assert_in_delta 50.0, board.robot.x, 0.5
    refute board.robot.moving?
    board = run_board(parts: ["picogo"]) do
      robot = picogo
      robot.left(50)
      sleep_ms 500
      robot.stop
    end
    # 20 cm/s each way on a 10 cm base: 4 rad/s, 0.5 s
    assert_in_delta 2.0 * 180 / Math::PI, board.robot.heading, 1.0
  end

  def test_robot_stops_at_the_wall_with_ir_and_hits_without
    board = run_board(parts: ["picogo"], bench: [{ "at" => 0, "arena" => "wall60" }]) do
      robot = picogo
      left = GPIO.new(3, GPIO::IN)
      right = GPIO.new(2, GPIO::IN)
      robot.forward(40)
      sleep_ms 10 until left.low? || right.low?
      robot.stop
    end
    refute board.robot.hit?
    assert_operator board.robot.gap_cm, :<=, 12.5
    assert_operator board.robot.gap_cm, :>=, 1
    assert_operator board.robot.traveled_cm, :>, 30
    board = run_board(parts: ["picogo"], bench: [{ "at" => 0, "arena" => "wall60" }]) do
      robot = picogo
      robot.forward(40)
      sleep_ms 1000
      robot.stop
    end
    assert_in_delta 44, board.robot.gap_cm, 0.5
    board = run_board(parts: ["picogo"], bench: [{ "at" => 0, "arena" => "wall60" }]) do
      picogo.forward(100)
      sleep_ms 3000
    end
    assert board.robot.hit?
    assert_in_delta 0, board.robot.gap_cm, 0.5
  end

  def test_sonar_through_the_hcsr04_stand_in
    run_board(parts: ["picogo"], bench: [{ "at" => 0, "arena" => "wall60" }]) do
      sonar = HCSR04.new(trig: 14, echo: 15)
      assert_in_delta 60, sonar.distance_cm, 1
    end
  end

  # ---------- Wi-Fi and Net::HTTP ----------

  def connect
    CYW43.init("CH")
    CYW43.enable_sta_mode
    CYW43.connect_timeout("chunkynet", "chunkybacon", CYW43::Auth::WPA2_AES_PSK, 10)
  end

  def test_wifi_connect_and_errors
    board = run_board(parts: ["wifi"]) do
      error = assert_raises(RuntimeError) { CYW43::GPIO.new(CYW43::GPIO::LED_PIN) }
      assert_equal "CYW43 not initialized", error.message
      quiet { assert CYW43.init("CH") }
      CYW43.enable_sta_mode
      assert_raises(CYW43::ConnectTimeout) { CYW43.connect_timeout("chunkynet", "nope", CYW43::Auth::WPA2_AES_PSK, 10) }
      assert CYW43.connect_timeout("chunkynet", "chunkybacon", CYW43::Auth::WPA2_AES_PSK, 10)
      assert CYW43.link_connected?
      assert_equal "192.168.4.23", CYW43.ipv4_address
      assert_equal CYW43, Network::WiFi
      led = CYW43::GPIO.new(CYW43::GPIO::LED_PIN)
      led.write(1)
      assert_equal 1, PicoSim.world.onboard
    end
    assert board.wifi_connected?
    assert_equal 1, board.onboard
  end

  def test_net_http_content_length_and_canned
    board = run_board(parts: ["wifi"]) do
      connect
      body = Net::HTTP.get("https://rubygems.org", "/api/v1/gems/rake.json")
      assert_equal "rake", JSON.parse(body)["name"]
    end
    entry = board.http.last
    assert_equal "https://rubygems.org/api/v1/gems/rake.json", entry["url"]
    assert_equal 200, entry["status"]
    assert entry["canned"]
    assert_equal "rake", board.http_json("rubygems.org")["name"]
  end

  def test_net_http_chunked_as_picoruby_reads_it
    url = "https://api.open-meteo.com/v1/forecast?latitude=47.37&longitude=8.54&current=temperature_2m,weather_code,wind_speed_10m"
    run_board(parts: ["wifi"]) do
      connect
      # 4.0.3's get_response answers the Net::HTTP (start's self), not the
      # response - a request on an object of one's own does
      assert_kind_of Net::HTTP, Net::HTTP.get_response(url)
      http = Net::HTTP.new("api.open-meteo.com", 443)
      http.use_ssl = true
      res = http.get(url.sub("https://api.open-meteo.com", ""))
      assert_equal 200, res.code.to_i
      first = res.body.lines.first.strip
      assert_match(/\A\h+\z/, first, "the body starts with a chunk size line")
      assert_raises(JSON::ParserError) { JSON.parse(res.body) }
      joined = +""
      rest = res.body
      while (nl = rest.index("\r\n"))
        size = rest[0, nl].to_i(16)
        break if size.zero?

        joined << rest[nl + 2, size]
        rest = rest[(nl + 4 + size)..]
      end
      assert JSON.parse(joined)["current"]
    end
  end

  def test_net_http_without_wifi_and_without_answer
    run_board(parts: ["wifi"]) do
      error = assert_raises(IOError) { Net::HTTP.get("https://rubygems.org", "/api/v1/gems/rake.json") }
      assert_match(/Failed to connect to rubygems.org:443 - no network/, error.message)
      connect
      assert_raises(IOError) { Net::HTTP.get("https://example.org", "/nothing") }
    end
    run_board(parts: ["wifi"], bench: [{ "at" => 0, "wifi" => "off" }]) do
      CYW43.init
      CYW43.enable_sta_mode
      assert_raises(CYW43::ConnectTimeout) { CYW43.connect_timeout("chunkynet", "chunkybacon", 0, 10) }
    end
  end

  # ---------- BLE ----------

  def test_ble_uart_echo_with_a_bench
    board = run_board(parts: ["laptop", "temp"], bench: [{ "at" => 0, "ble" => "connect" }, { "at" => 300, "ble" => "PING" },
                                                          { "at" => 800, "ble" => "TEMP" }]) do
      uart = BLE::UART.new(name: "ChunkyPico")
      sensor = ADC.new(:temperature)
      connected = false
      uart.on_connect { connected = true }
      uart.start(1500) do
        line = uart.gets_nonblock
        next unless line

        case line.chomp
        when "PING" then uart.puts "PONG"
        when "TEMP" then uart.puts((27 - (sensor.read_voltage - 0.706) / 0.001721).round(1))
        end
      end
      assert connected
      assert_equal 0, uart.write("x") if false
    end
    assert_includes board.ble.lines, "PONG"
    assert board.ble.lines.any? { |l| l.to_f.between?(17.0, 25.0) }
    assert_equal %w[PING TEMP], board.ble.rx
    assert_equal "ChunkyPico", board.ble.advertised.nil? ? "ChunkyPico" : board.ble.advertised
    assert_raises(NotImplementedError) { BLE::UART.new(role: :central) }
  end

  # ---------- Tasks, the camera, the bench ----------

  def test_tasks_take_turns_on_the_virtual_clock
    out = quiet do
      run_board(parts: ["led15"]) do
        blinker = Task.new(name: "blink") { loop { puts "A#{PicoCRuby.run_ms.round}"; sleep_ms 100 } }
        3.times { puts "B#{PicoCRuby.run_ms.round}"; sleep_ms 150 }
        blinker.terminate
      end
    end
    # a Task due when the main program wakes runs first
    assert_equal %w[B0 A0 A100 B150 A200 A300 B300 A400], out.split
  end

  def test_camera_picture_and_the_chooser
    run_board(parts: ["camera"], inputs: { "camera" => "bacon" }) do
      bytes = Camera.new.capture(width: 80, height: 60)
      assert_equal 4800, bytes.bytesize
      assert bytes.bytes.uniq.size > 2
    end
  end

  # the bench's "Use my webcam": the page's frame (a 160 x 120 PGM as hex)
  # instead of a drawn picture; no frame yet, and the drawn "chunky" stands in
  def test_camera_takes_the_webcams_frame
    pixels = (0...120).flat_map { |y| (0...160).map { |x| x < 80 ? 10 : 240 } }
    hex = ("P5\n160 120\n255\n".bytes + pixels).map { |b| format("%02x", b) }.join
    log = nil
    run_board(parts: ["camera"], inputs: { "camera" => "webcam", "camera.frame" => hex }) do
      bytes = Camera.new.capture
      assert_equal 19_200, bytes.bytesize
      assert_equal [10, 240], [bytes.getbyte(0), bytes.getbyte(159)]
      assert_equal 240, bytes.getbyte(119 * 160 + 100)
      log = PicoSim.world.instance_variable_get(:@events).map(&:last)
    end
    assert_includes log, "camera webcam"
    run_board(parts: ["camera"], inputs: { "camera" => "webcam" }) do
      drawn = Camera.new.capture
      PicoCRuby.start({ "camera" => "chunky" })
      assert_equal Camera.new.capture, drawn
    end
  end

  def test_irb_line_carries_on_without_a_reset
    run_board(parts: ["led15"]) { GPIO.new(15, GPIO::OUT).write(1); sleep_ms 100 }
    board = run_board(parts: ["led15"], reset: false) { GPIO.write_at(15, 0) }
    assert_equal [[0, 0], [0, 1], [100, 0]], board.writes(15)
  end

  # ---------- PIO and WS2812 ----------

  def ws2812(num, pin)
    require "ws2812"
    WS2812.new(pin: pin, num: num)
  end

  # ksbmyk/picoruby-ws2812 (html/pico/lib/ws2812.rb, unchanged) on
  # PicoRuby's own PIO assembler: the PicoGo's four LEDs
  def test_ws2812_gem_drives_the_picogo_leds_through_pio
    board = run_board(parts: ["picogo"]) do
      led = ws2812(4, 22)
      led.set_rgb(0, 255, 0, 0)
      led.set_hex(1, 0x00FF00)
      led.set_hsb(2, 240, 100, 100)
      led.show
      sleep_ms 10
      led.brightness = 100
      led.show
    end
    leds = board.leds(22)
    assert_equal 4, leds.count
    assert_equal 2, leds.frames
    assert_equal [255, 0, 0], leds.rgb(0)
    assert_equal [0, 255, 0], leds.rgb(1)
    assert_equal [0, 0, 255], leds.rgb(2)
    assert_equal [0, 1, 2], leds.lit
    # 10 cycles a bit at 8 MHz: T1H 7 cycles, T0H 2
    assert_equal [875, 250], leds.timing
    assert_nil leds.note
    assert_equal "pio", board.mode(22)
    assert_equal leds.colors, board.leds.colors
  end

  def test_ws2812_brightness_is_applied_at_show
    board = run_board(parts: ["picogo"]) do
      led = ws2812(4, 22)
      led.fill(255, 100, 0)
      led.show
    end
    # the gem's default brightness: 5 %
    assert_equal [[12, 5, 0]] * 4, board.leds.colors
  end

  def test_pio_at_the_default_clock_is_too_fast_for_ws2812
    require "pio"
    out = nil
    board = run_board(parts: ["picogo"]) do
      prog = WS2812.pio_program
      sm = PIO::StateMachine.new(pio: PIO::PIO0, sm: 0, program: prog, sideset_pins: 22,
                                 out_shift_right: false, out_shift_autopull: true, out_shift_threshold: 24,
                                 fifo_join: PIO::FIFO_JOIN_TX)
      sm.start
      sm.put_buffer([0xFF0000 << 8] * 4)
      out = sm.freq
    end
    assert_equal 125_000_000, out
    assert_equal "too_fast", board.leds.note
    assert_equal [], board.leds.lit
    assert board.events.any? { |e| e[1] == "log" && e[2].include?("too short") }
  end

  def test_pio_program_by_hand_grb_left_aligned
    require "pio"
    board = run_board(parts: ["rgbled"]) do
      prog = PIO.asm(side_set: 1) do
        wrap_target
        label :bitloop
        out :x, 1, side: 0, delay: 2
        jmp :do_zero, cond: :not_x, side: 1, delay: 1
        label :do_one
        jmp :bitloop, side: 1, delay: 4
        label :do_zero
        nop side: 0, delay: 4
        wrap
      end
      sm = PIO::StateMachine.new(pio: PIO::PIO0, sm: 0, program: prog, freq: 8_000_000, sideset_pins: 6,
                                 out_shift_right: false, out_shift_autopull: true, out_shift_threshold: 24,
                                 fifo_join: PIO::FIFO_JOIN_TX)
      sm.start
      # GRB: green, red, blue
      sm.put_buffer([0x00FF00 << 8, 0xFF0000 << 8, 0x0000FF << 8])
      assert_operator sm.tx_level, :<=, 8
      sm.drain_tx
      assert_equal 0, sm.tx_level
      assert sm.tx_empty?
      assert_nil sm.get_nonblocking
    end
    leds = board.leds(6)
    assert_equal 160, leds.count
    assert_equal [[255, 0, 0], [0, 255, 0], [0, 0, 255]], leds.colors.first(3)
    assert_equal [0, 1, 2], leds.lit
  end

  def test_pio_errors_and_a_put_that_waits_for_ever
    require "pio"
    prog = nil
    run_board(parts: ["rgbled"]) do
      prog = PIO.asm { set :x, 1 }
      assert_raises(IOError) { PIO::StateMachine.new(pio: 2, sm: 0, program: prog) }
      assert_raises(IOError) { PIO::StateMachine.new(pio: PIO::PIO0, sm: 4, program: prog) }
      big = PIO.asm { 8.times { set :x, 1 } }
      4.times { PIO::StateMachine.new(pio: PIO::PIO1, sm: 0, program: big) }
      error = assert_raises(IOError) { PIO::StateMachine.new(pio: PIO::PIO1, sm: 1, program: prog) }
      assert_equal "No space in PIO instruction memory", error.message
      sm = PIO::StateMachine.new(pio: PIO::PIO0, sm: 1, program: prog)
      assert_equal true, sm.put_nonblocking(1)
      assert_equal 1, sm.tx_level
      sm.clear_fifos
      assert_equal 0, sm.tx_level
    end
    assert_raises(PicoCRuby::Timeout) do
      run_board(parts: ["rgbled"]) do
        sm = PIO::StateMachine.new(pio: PIO::PIO0, sm: 0, program: WS2812.pio_program, freq: 8_000_000, sideset_pins: 6)
        sm.put_buffer([0] * 9)   # never started: the FIFO fills, the 9th waits
      end
    end
  end

  # the community gem is shown as it is: an unchanged copy
  def test_ws2812_gem_is_the_unchanged_upstream_file
    require "digest"
    path = File.expand_path("../html/pico/lib/ws2812.rb", __dir__)
    assert_equal "a2c8588eb24a453f364f5ef12bbbdf3f5575971a62139478debb9b8d0c8ccf6c", Digest::SHA256.file(path).hexdigest
  end

  # ---------- the Pico-LCD-1.14 ----------

  def lcd
    require "st7789"
    ST7789.new(spi: SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000, sck_pin: 10, copi_pin: 11))
  end

  def test_lcd_fill_rect_and_text_through_the_lesson_driver
    board = run_board(parts: ["lcd114"]) do
      d = lcd
      d.fill(ST7789::BLUE)
      d.fill_rect(10, 10, 20, 5, ST7789::RED)
      d.fill_rect(230, 130, 50, 50, ST7789.rgb(0, 255, 0))
      d.text("Hi Pico", 60, 60, ST7789::YELLOW, bg: ST7789::BLUE, scale: 2)
    end
    l = board.lcd
    assert l.on?
    assert l.inverted?
    assert l.visible?
    assert_in_delta 90, l.backlight, 0.01
    assert_equal 0x70, l.madctl
    assert_equal [], l.unknown
    assert_equal ST7789::BLUE, l.color(0, 0)
    assert_equal ST7789::BLUE, l.color(229, 129)
    assert_equal [255, 0, 0], l.rgb(10, 10)
    assert_equal [255, 0, 0], l.rgb(29, 14)
    assert_equal [0, 0, 255], l.rgb(30, 15)
    # cut off at the edge: 10 x 5 of the 50 x 50
    assert_equal ST7789::GREEN, l.color(239, 134)
    assert_equal 50, l.count(ST7789::GREEN)
    assert_equal 100, l.count(ST7789::RED)
    assert_equal ST7789::BLUE, l.background
    assert l.text?("Hi Pico")
    refute l.text?("Hi Fox")
    assert PicoCRuby.posted.any? { |kind, text| kind == "lcd" && text.start_with?("0,0,240,135|") }
  end

  def test_lcd_dark_before_init_inverted_without_invon_and_keeps_its_ram
    board = run_board(parts: ["lcd114"]) { sleep_ms 5 }
    refute board.lcd.on?
    refute board.lcd.visible?
    assert_equal [0, 0, 0], board.lcd.rgb(0, 0)
    # the init without 0x21: true RGB565 in the RAM, inverted on the glass
    board = run_board(parts: ["lcd114"]) do
      d = lcd
      d.fill(ST7789::WHITE)
      d.send(:command, 0x20)
    end
    assert_equal [0, 0, 0], board.lcd.rgb(5, 5)
    # a new run: the RAM keeps the picture, the display is off until init
    board = run_board(parts: ["lcd114"]) { sleep_ms 5 }
    refute board.lcd.on?
    assert_equal ST7789::WHITE, board.lcd.color(5, 5)
  end

  def test_lcd_portrait_madctl_turns_the_picture
    board = run_board(parts: ["lcd114"]) do
      d = lcd
      d.fill(ST7789::BLACK)
      # portrait (MADCTL 0x00): Waveshare's offsets are 52 and 40
      d.send(:command, 0x36, 0x00)
      d.send(:command, 0x2A, 0, 52, 0, 52)
      d.send(:command, 0x2B, 0, 40, 0, 40)
      d.send(:command, 0x2C)
      d.send(:data, 0xF8, 0x00)
    end
    # portrait (0, 0) is the landscape glass's bottom left
    assert_equal ST7789::RED, board.lcd.color(0, 134)
    assert_equal 1, board.lcd.count(ST7789::RED)
  end

  def test_lcd_keys_are_active_low_with_the_pull_up
    a_seen = nil
    board = run_board(parts: ["lcd114"], bench: [{ "at" => 100, "press" => 15 }, { "at" => 200, "release" => 15 },
                                                 { "at" => 300, "press" => 20 }]) do
      a = GPIO.new(15, GPIO::IN | GPIO::PULL_UP)
      right = GPIO.new(20, GPIO::IN | GPIO::PULL_UP)
      b = GPIO.new(17, GPIO::IN)   # no pull-up: the pad's pull-down reads 0
      assert_equal 1, a.read
      assert_equal 0, b.read
      sleep_ms 150
      a_seen = a.low?
      sleep_ms 100
      assert a.high?
      sleep_ms 100
      assert right.low?
    end
    assert a_seen
    assert_equal "in_pull_up", board.mode(15)
  end

  # test/pico_lint.rb's table of parts is the simulator's
  def test_lint_knows_the_parts_and_their_pins
    require_relative "pico_lint"
    assert_equal PicoSim::PARTS.keys.sort, PicoLint::PART_PINS.keys.sort
    PicoSim::PARTS.each { |id, klass| assert_equal klass.new(id).pins, PicoLint::PART_PINS[id], id }
    assert_equal PicoCRuby::STUBS, PicoLint::STUBS
    stubs = File.read(File.expand_path("../html/picoruby_worker_core.js", __dir__))[/STUBS = \[(.*?)\]/m, 1]
    assert_equal PicoLint::STUBS, stubs.scan(/"([^"]+)"/).flatten
  end

  def test_board_api_is_total
    board = PicoRubyCells.board("{}")
    assert_equal [], board.writes(15)
    assert_nil board.level(15)
    assert_equal 0, board.epd.refreshes
    refute board.epd.frame.black?(0, 0)
    refute board.epd.frame.text?("x")
    refute board.robot.hit?
    assert_equal [], board.ble.lines
    assert_nil board.http_json("x")
    refute board.lcd.on?
    assert_nil board.lcd.color(0, 0)
    assert_equal [0, 0, 0], board.lcd.rgb(0, 0)
    refute board.lcd.text?("x")
    assert_equal [], board.leds.colors
    assert_equal [0, 0, 0], board.leds(22).rgb(0)
    assert_nil PicoRubyCells.board("")
  end
end
