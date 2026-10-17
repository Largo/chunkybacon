# A camera for the simulated Pico (there is no PicoRuby camera driver; the
# lesson says so, docs/HANDOVER.md §6r): Camera.new.capture answers
# width x height grey bytes (0 black .. 255 white), row after row, from a
# 160 x 120 picture of assets/data/pico/camera/ - the one the bench's
# chooser names (input "camera"), "chunky" by default. With the bench's
# "Use my webcam" on, "camera" is "webcam" and the page hands over its
# latest frame, already a 160 x 120 PGM, as hex (input "camera.frame");
# without a frame yet the drawn picture "chunky" stands in.
class Camera
  def initialize(**options)
    @options = options
  end

  def capture(width: 160, height: 120)
    name = PicoSim.world.input("camera") || "chunky"
    hex = name == "webcam" ? PicoSim.world.input("camera.frame").to_s : ""
    if hex == ""
      name = "chunky" if name == "webcam"
      hex = PicoSim.host.camera_hex(name).to_s
    end
    w, h, pixels = Camera.decode__(hex)
    raise IOError.new("camera: no picture #{name}") if pixels.nil?
    PicoSim.world.event("log", "camera #{name}")
    out = ""
    out = out.b if PicoSim::CRUBY
    y = 0
    while y < height
      sy = y * h / height
      x = 0
      row = []
      while x < width
        row << pixels.getbyte(sy * w + x * w / width)
        x += 1
      end
      out << PicoSim.byte_string(row)
      y += 1
    end
    out
  end

  # a binary PGM ("P5\n160 120\n255\n" + bytes) as hex: [w, h, bytes]
  def self.decode__(hex)
    return [0, 0, nil] if hex.size < 16
    bytes = []
    i = 0
    while i < hex.size
      bytes << hex[i, 2].to_i(16)
      i += 2
    end
    fields = []
    pos = 0
    word = ""
    while fields.size < 4 && pos < bytes.size
      c = bytes[pos]
      if c == 32 || c == 10 || c == 13 || c == 9
        fields << word unless word == ""
        word = ""
      else
        word << c.chr
      end
      pos += 1
    end
    return [0, 0, nil] unless fields[0] == "P5"
    [fields[1].to_i, fields[2].to_i, PicoSim.byte_string(bytes[pos, bytes.size - pos])]
  end
end
