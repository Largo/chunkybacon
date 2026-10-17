# Waveshare PicoGo, seen from above in a 200 x 120 cm arena (docs/HANDOVER.md
# §6r; the pins from Waveshare's demo code, tmp research
# "waveshare_peripherals" §4):
#
#   TB6612 motor A (left):  PWMA GP16, AIN2 GP17, AIN1 GP18
#   TB6612 motor B (right): BIN1 GP19, BIN2 GP20, PWMB GP21
#   IR obstacle sensors: GP2 right, GP3 left, 0 = an obstacle
#   ultrasonic (stand_ins/hcsr04.rb): trig GP14, echo GP15
#   buzzer (active): GP4      battery: GP26 (ADC0), 3.9 V / 2
#   4 WS2812 LEDs underneath: GP22 (devices/ws2812.rb), 0 front left,
#   then clockwise (sim choice: Waveshare's demo does not say)
#
# Forward is AIN2 = 1, AIN1 = 0 and BIN2 = 1, BIN1 = 0 (Motor.py); both
# low or both high stops a wheel. Sim choices, which the lesson calls "in
# this simulation": a wheel's speed is duty / 100 * 40 cm/s, the wheel base
# 10 cm, the body a circle of 14 cm; an IR sensor sees an obstacle within
# 12 cm of the front in a 60° cone on its side. A collision stops the body
# at the obstacle, the wheels stall.

module PicoSim
  class PicoGo < Part
    SPEED = 40.0      # cm/s at 100 % duty
    BASE = 10.0       # wheel base, cm
    RADIUS = 7.0      # body, cm
    IR_RANGE = 12.0
    W = 200.0
    H = 120.0
    START = [30.0, 60.0, 0.0]
    # name => obstacles [x, y, w, h] (cm; the arena's walls are always there)
    LAYOUTS = {
      "open" => [],
      "wall60" => [[97.0, 0.0, 6.0, 120.0]],
      "box" => [[120.0, 50.0, 20.0, 20.0]]
    }
    DEG = 3.141592653589793 / 180.0

    def pins = [2, 3, 4, 14, 15, 16, 17, 18, 19, 20, 21, 22, 26]

    def attach(world)
      @x, @y, @h = START
      @traveled = 0.0
      @hit = false
      @t = nil
      @layout = "open"
      @box = nil
      @bacon = [170.0, 30.0]
      world.drive(2, self)
      world.drive(3, self)
      world.drive(15, self)
      world.adc_source(0, self)
      world.watch(4, self)
      [16, 17, 18, 19, 20, 21].each { |pin| world.watch(pin, self) }
      @leds = Ws2812Chain.new(22, 4, world.epd_store)
      world.pio_watch(22, self)
    end

    def on_pio(world, sm, words, t) = @leds.on_pio(world, sm, words, t)
    def flush(world, t) = @leds.flush(world, t)

    def layout(world, name)
      @layout = LAYOUTS[name] ? name : "open"
    end

    def obstacles(world)
      list = LAYOUTS[@layout].dup
      box = world.input("arena.box")
      if box
        xy = box.split(",")
        list << [xy[0].to_f - 10, xy[1].to_f - 10, 20.0, 20.0] if xy.size == 2
      end
      list
    end

    # cm/s of one wheel: + forward
    def wheel(world, pwm, in1, in2)
      a = world.out_level(in1) || 0
      b = world.out_level(in2) || 0
      return 0.0 if a == b
      speed = world.pwm_duty(pwm) / 100.0 * SPEED
      b == 1 ? speed : -speed
    end

    def speeds(world)
      [wheel(world, 16, 18, 17), wheel(world, 21, 19, 20)]
    end

    def advance(world, t)
      @leds.advance(world, t)
      @t ||= t
      while @t < t
        dt = t - @t
        dt = 5.0 if dt > 5.0
        step(world, dt / 1000.0)
        @t += dt
      end
    end

    def step(world, dt)
      left, right = speeds(world)
      return if left == 0.0 && right == 0.0
      v = (left + right) / 2.0
      omega = (right - left) / BASE
      h = @h + omega * dt
      nx = @x + Math.cos(@h) * v * dt
      ny = @y + Math.sin(@h) * v * dt
      if blocked?(world, nx, ny)
        @hit = true if v != 0.0
        @h = h
        return
      end
      @traveled += (v * dt).abs
      @x = nx
      @y = ny
      @h = h
    end

    def blocked?(world, x, y)
      return true if x < RADIUS || y < RADIUS || x > W - RADIUS || y > H - RADIUS
      obstacles(world).any? do |r|
        cx = x < r[0] ? r[0] : (x > r[0] + r[2] ? r[0] + r[2] : x)
        cy = y < r[1] ? r[1] : (y > r[1] + r[3] ? r[1] + r[3] : y)
        (cx - x) * (cx - x) + (cy - y) * (cy - y) < RADIUS * RADIUS
      end
    end

    # how far a ray from (x, y) in direction +a+ goes before it meets a wall
    # or an obstacle (cm)
    def ray(world, x, y, a)
      dx = Math.cos(a)
      dy = Math.sin(a)
      best = 1000.0
      best = hit_rect(x, y, dx, dy, [0.0, 0.0, W, H], true, best)
      obstacles(world).each { |r| best = hit_rect(x, y, dx, dy, r, false, best) }
      best
    end

    # the slab method; +inside+: the ray starts inside the rectangle (walls)
    def hit_rect(x, y, dx, dy, r, inside, best)
      if inside
        tx = dx > 0 ? (r[0] + r[2] - x) / dx : (dx < 0 ? (r[0] - x) / dx : 1e9)
        ty = dy > 0 ? (r[1] + r[3] - y) / dy : (dy < 0 ? (r[1] - y) / dy : 1e9)
        t = tx < ty ? tx : ty
        return t < best ? t : best
      end
      t0 = -1e9
      t1 = 1e9
      [[x, dx, r[0], r[0] + r[2]], [y, dy, r[1], r[1] + r[3]]].each do |o, d, lo, hi|
        if d == 0.0
          return best if o < lo || o > hi
        else
          a = (lo - o) / d
          b = (hi - o) / d
          a, b = b, a if a > b
          t0 = a if a > t0
          t1 = b if b < t1
        end
      end
      return best if t0 > t1 || t1 < 0
      t = t0 < 0 ? 0.0 : t0
      t < best ? t : best
    end

    # the distance from the front of the body, straight ahead
    def gap(world)
      d = ray(world, @x, @y, @h) - RADIUS
      d < 0 ? 0.0 : d
    end

    # an IR sensor: the nearest obstacle in its cone, from the front
    def ir_distance(world, side)
      best = 1000.0
      centre = @h + side * 20 * DEG
      [-30, -15, 0, 15, 30].each do |off|
        d = ray(world, @x, @y, centre + off * DEG) - RADIUS
        best = d if d < best
      end
      best
    end

    def drive(world, pin, t)
      advance(world, t)
      if pin == 2
        ir_distance(world, -1) <= IR_RANGE ? 0 : 1
      elsif pin == 3
        ir_distance(world, 1) <= IR_RANGE ? 0 : 1
      else
        0   # echo: the HCSR04 stand-in measures without the pins
      end
    end

    def adc_voltage(world, input, t)
      3.9 / 2
    end

    def on_write(world, pin, level, t)
      advance(world, t)
      world.buzz((world.out_level(4) || 0) == 1 ? 1 : 0) if pin == 4
    end

    def sonar(world)
      d = ray(world, @x, @y, @h) - RADIUS
      d = 2.0 if d < 2.0
      d = 400.0 if d > 400.0
      d
    end

    def moving?(world)
      left, right = speeds(world)
      (left != 0.0 || right != 0.0) && !@hit
    end

    def state(world)
      left, right = speeds(world)
      { "x" => @x.round(1), "y" => @y.round(1), "h" => (@h / DEG).round(1), "l" => left.round(1),
        "r" => right.round(1), "hit" => @hit, "layout" => @layout,
        "ir" => [ir_distance(world, 1) <= IR_RANGE ? 0 : 1, ir_distance(world, -1) <= IR_RANGE ? 0 : 1],
        "sonar" => sonar(world).round(1), "box" => world.input("arena.box"), "bacon" => world.input("arena.bacon"),
        "leds" => @leds.hex }
    end

    def summary(world, out)
      left, right = speeds(world)
      out["robot"] = { "x" => @x.round(1), "y" => @y.round(1), "h" => (@h / DEG).round(1),
                       "traveled" => @traveled.round(1), "gap" => gap(world).round(1), "hit" => @hit,
                       "moving" => moving?(world), "duty" => [world.pwm_duty(16), world.pwm_duty(21)],
                       "speed" => [left.round(1), right.round(1)], "layout" => @layout }
      (out["ws2812"] ||= {})["22"] = @leds.summary
    end
  end
  PARTS["picogo"] = PicoGo
end
