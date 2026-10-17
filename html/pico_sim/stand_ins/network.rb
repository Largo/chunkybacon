# picoruby-network's Network module as on an RP2040/RP2350 board
# (mrblib/network.rb picks CYW43 by RUBY_PLATFORM, which here is
# wasm32/Emscripten or CRuby's): the Wi-Fi is the simulated CYW43.
module Network
  WiFi = CYW43
  ConnectTimeout = CYW43::ConnectTimeout
end
