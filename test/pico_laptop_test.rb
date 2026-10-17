require "minitest/autorun"
require "json"
require "stringio"

# html/pico_laptop.rb, the `ble` gem's API for lesson pico-ble's CRuby cell,
# against a bench of its own (the page's is pico_board.js). The lesson's
# laptop cell runs here as it is, in all three languages.
load File.expand_path("../html/pico_laptop.rb", __dir__)

class PicoLaptopTest < Minitest::Test
  class FakeBench
    attr_accessor :adv, :running, :connected
    attr_reader :sent, :connects

    def initialize(adv: "PicoRuby", running: true)
      @adv = adv
      @running = running
      @connected = false
      @sent = []
      @connects = []
    end

    def state = { "adv" => @adv, "connected" => @connected, "running" => @running }

    def connect(on)
      @connects << on
      @connected = on
    end

    def send_line(text)
      @sent << text
    end
  end

  def setup
    @bench = FakeBench.new
    PicoLaptop.host = @bench
    PicoLaptop.forget
    PicoLaptop.cell = 3
  end

  def test_discovery_sees_the_pico_only_while_its_cell_runs
    adapter = BLE::Adapter.new("hci0")
    assert adapter.start_discovery
    assert_equal [PicoLaptop::MAC], adapter.devices
    assert_equal "PicoRuby", adapter[PicoLaptop::MAC].name
    @bench.running = false
    assert_empty adapter.devices
    assert_raises(BLE::NotFound) { adapter[PicoLaptop::MAC] }
    assert_raises(BLE::NotFound) { BLE::Adapter.new("hci7") }
  end

  def test_write_and_notify
    pico = BLE::Adapter.new("hci0")[PicoLaptop::MAC]
    assert_raises(BLE::Error) { pico.[]=(PicoLaptop::NUS, PicoLaptop::RX, "x", raw: true) }
    pico.connect
    assert_equal [true], @bench.connects
    assert pico.is_connected?
    pico.[]=(PicoLaptop::NUS.upcase, PicoLaptop::RX, "PING\n", raw: true)
    assert_equal ["PING\n"], @bench.sent
    pico.subscribe(PicoLaptop::NUS, PicoLaptop::TX, raw: true) { |bytes| print "got #{bytes}" }
    got = PicoLaptop.deliver("PONG\n")
    assert_equal [[3, "got PONG\n"]], got
    assert_raises(BLE::NotSupported) { pico.subscribe(PicoLaptop::NUS, PicoLaptop::RX) { } }
    assert_raises(BLE::NotFound) { pico.[]=("180f", PicoLaptop::RX, "x") }
    PicoLaptop.forget(3)
    assert_empty PicoLaptop.deliver("again")
  end

  def test_a_failing_block_reports_and_does_not_stop_the_others
    pico = BLE::Adapter.new("hci0")[PicoLaptop::MAC]
    pico.subscribe(PicoLaptop::NUS, PicoLaptop::TX) { |_| raise "boom" }
    pico.subscribe(PicoLaptop::NUS, PicoLaptop::TX) { |b| print b }
    assert_equal [[3, "RuntimeError: boom\n"], [3, "hi"]], PicoLaptop.deliver("hi")
  end

  def test_dbus
    main = DBus::Main.new
    main << DBus::SystemBus.instance
    assert_same DBus::SystemBus.instance, DBus::SystemBus.instance
    assert_nil main.run
  end

  # pico-ble's "On the laptop (CRuby)" cell, unchanged, in each language
  def test_the_lessons_laptop_cell
    text = File.read(File.expand_path("../html/lessons.js", __dir__))
    data = JSON.parse(text[/JSON\.stringify\((.*)\);\s*\z/m, 1])
    lesson = data["lessons"].find { |l| l["id"] == "pico-ble" }
    skip "pico-ble not in lessons.js" unless lesson
    %w[de en ja].each do |lang|
      cell = lesson[lang]["cells"].find { |c| c["engine"] == "cruby" }
      refute_nil cell, lang
      code = cell["code"].sub(/^require "ble"\n/, "").gsub(/^(\s*)sleep (\d+)/, '\1nil')
      [true, false].each do |advertising|
        setup
        @bench.running = advertising
        out = StringIO.new
        old = $stdout
        $stdout = out
        begin
          eval(code, TOPLEVEL_BINDING.dup, "laptop.rb")
        ensure
          $stdout = old
        end
        if advertising
          assert_equal [true], @bench.connects, lang
          assert_equal 1, @bench.sent.size, lang
          assert_match(/CRuby #{Regexp.escape(RUBY_VERSION)}\n\z/, @bench.sent.first, lang)
          assert_equal 1, PicoLaptop.subscriptions.size, lang
        else
          refute_empty out.string, lang
          assert_empty @bench.sent, lang
        end
      end
    end
  end
end
