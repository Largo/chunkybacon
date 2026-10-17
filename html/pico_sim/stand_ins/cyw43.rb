# The C side of picoruby-cyw43 (src/mruby/cyw43.c), against the simulated
# access point: one network, "chunkynet" with the password "chunkybacon"
# (docs/HANDOVER.md §6r). The Ruby side is PicoRuby's (vendor/cyw43.rb).
#
# As 4.0.3's C has it: connect_timeout's fourth argument is in SECONDS
# (the C multiplies it by 1000; R2P2's wifi_connect passes 10), a failed
# connect raises CYW43::ConnectTimeout instead of answering false, and it
# answers false when STA mode is off or the link is up already. Sim
# choices: a wrong password or no access point fails after
# min(timeout, 1.5 s); the address is 192.168.4.23.

class CYW43
  class ConnectTimeout < RuntimeError; end

  LINK_DOWN = 0
  LINK_JOIN = 1
  LINK_NOIP = 2
  LINK_UP = 3
  LINK_FAIL = -1
  LINK_NONET = -2
  LINK_BADAUTH = -3

  SSID__ = "chunkynet"
  PASSWORD__ = "chunkybacon"

  def self.wifi__ = PicoSim.world.wifi

  def self.check_init__
    raise RuntimeError.new("CYW43 not initialized") unless wifi__.init
  end

  def self._init(country, force)
    wifi__.init = true
    true
  end

  def self.initialized?
    wifi__.init
  end

  def self.enable_sta_mode
    check_init__
    return false if wifi__.sta
    wifi__.sta = true
    true
  end

  def self.disable_sta_mode
    check_init__
    return false unless wifi__.sta
    wifi__.sta = false
    true
  end

  def self.ap_up__
    part = PicoSim.world.part("wifi")
    part.nil? || part.up?(PicoSim.world)
  end

  def self.connect_timeout(ssid, password, auth, timeout = nil)
    check_init__
    raise ArgumentError.new("SSID too long (max 32 bytes)") if ssid.to_s.bytesize > 32
    raise ArgumentError.new("PSK too long (max 63 bytes)") if password.to_s.bytesize > 63
    return false unless wifi__.sta && !wifi__.connected
    timeout_ms = (timeout.nil? ? 60 : timeout) * 1000
    if ssid == SSID__ && password == PASSWORD__ && ap_up__
      sleep_ms 800
      wifi__.connected = true
      wifi__.ssid = ssid
      PicoSim.world.event("log", "wifi connected")
      return true
    end
    sleep_ms(timeout_ms < 1500 ? timeout_ms : 1500)
    raise ConnectTimeout.new("CYW43_wifi_connect_with_dhcp() failed")
  end

  def self.disconnect
    check_init__
    return false unless wifi__.connected
    wifi__.connected = false
    wifi__.sta = false
    true
  end

  def self.link_up__
    wifi__.connected && ap_up__
  end

  def self.tcpip_link_status
    check_init__
    return LINK_UP if link_up__
    return LINK_NONET if wifi__.connected
    LINK_DOWN
  end

  def self.dhcp_supplied?
    check_init__
    link_up__
  end

  def self.ipv4_address
    check_init__
    link_up__ ? "192.168.4.23" : "0.0.0.0"
  end

  def self.ipv4_netmask
    check_init__
    link_up__ ? "255.255.255.0" : "0.0.0.0"
  end

  def self.ipv4_gateway
    check_init__
    link_up__ ? "192.168.4.1" : "0.0.0.0"
  end

  # the board's LED, on the wireless chip (WL_GPIO0)
  class GPIO
    def write(value)
      CYW43.check_init__
      raise ArgumentError.new("Wrong value. 0 and 1 are only valid") if value != 0 && value != 1
      PicoSim.world.onboard_led(value) if @pin == LED_PIN
      0
    end

    def read
      CYW43.check_init__
      @pin == 0 ? PicoSim.world.onboard : 0
    end
  end
end
