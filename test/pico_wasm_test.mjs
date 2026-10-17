// The Pico lessons on PicoRuby.wasm, in node (docs/HANDOVER.md §6r): the
// lesson worker's own core (html/picoruby_worker_core.js) with a fake host,
// so the simulator (html/pico_sim/) runs on the PicoRuby the page runs.
//
// 1. The probes the design asked for first (P1-P5, P7; P6 needs a browser,
//    see tmp research PROGRESS.md): tabs required from /lib across runs and
//    sessions, the simulator's classes in Sandboxes, inputs reaching a
//    running loop, String bytes, URI, Task and Machine in the worker.
// 2. The simulator's parts end to end, each checked with
//    PicoRubyCells::Board under CRuby (ruby test/pico_harness.rb
//    --eval-checks).
// 3. Every demo cell of the Pico lessons (html/lessons.js, and lesson files
//    given as arguments) runs without an error, with its tabs and board;
//    every en solution of a lesson file passes its check, the starter not.
//
//   node test/pico_wasm_test.mjs [tmp/pico-lessons/x.json ...]
import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { bootNode, HTML } from "./pico_wasm_boot.mjs";

const ROOT = path.resolve(HTML, "..");
let failures = 0;
const check = (name, cond, extra = "") => {
  console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra ? ` - ${extra}` : ""}`);
  if (!cond) failures++;
};
const core = await bootNode();
let nextId = 1;
const run = (code, extra = {}) => core.handle(Object.assign({ id: nextId++, kind: "run", sid: "cells", code }, extra));
const boardOf = (parts, bench = [], more = {}) => JSON.stringify(Object.assign({ board: "pico2w", parts, bench, reset: true }, more));
const src = file => fs.readFileSync(path.join(HTML, file), "utf8");
const tab = (name, file) => ({ name, code: src(file) });
const brief = r => `${r.status} ${r.errorClass || ""} ${r.file || ""}:${r.line || ""} ${(r.message || r.inspect || "").slice(0, 160)}`;

// ---------- 1. probes ----------
{
  const r1 = await run('require "blinky"\n[Blinky.new.go, util_x]', { tabs: [{ name: "blinky.rb", code: "class Blinky; def go; :go; end; end\ndef util_x; 42; end" }] });
  check("P1 a cell requires its tab from /lib", r1.inspect === "[:go, 42]", brief(r1));
  const r2 = await run("[Blinky.new.go, util_x]");
  check("P1 ...its class and def live on in the next run", r2.inspect === "[:go, 42]", brief(r2));
  const r3 = await core.handle({ id: nextId++, kind: "run", sid: "irb7", code: "Blinky.new.go" });
  check("P1 ...and in another session (an IRB)", r3.inspect === ":go", brief(r3));
  const r4 = await run('require "blinky"\nBlinky.new.go', { tabs: [{ name: "blinky.rb", code: "class Blinky; def go; :edited; end; end" }] });
  check("P1 an edited tab is loaded again", r4.inspect === ":edited", brief(r4));
  const r5 = await run('require "boom"\nBoom.new.go', { tabs: [{ name: "boom.rb", code: "class Boom\n  def go\n    nil.zork\n  end\nend" }] });
  check("P1 an error in a tab names the tab and its line", r5.status === "error" && r5.file === "boom.rb" && r5.line === 3, brief(r5));
  const r6 = await run('[require("gpio"), GPIO::OUT, PWM.instance_methods.include?(:duty)]', { board: boardOf([]) });
  check("P2 the simulator's classes in a Sandbox; require \"gpio\" is a stub (loaded already: false)", r6.inspect === "[false, 2, true]", brief(r6));
  const r7 = await run('a = Machine.board_millis\nsleep_ms 100\nMachine.board_millis - a');
  check("P7 Machine.board_millis advances in the worker", Math.abs(Number(r7.inspect) - 100) <= 5, brief(r7));
  check("P7 ...and the board's ticker Task ran (state posted)", core.posted.board.some(b => b.kind === "state"));
  // P3: a page input reaches a running loop - one that sleeps, one that
  // only reads (PicoSim.breathe)
  const loop = (body) => run(`require "gpio"\nb = GPIO.new(14, GPIO::IN | GPIO::PULL_UP)\nt0 = Machine.board_millis\n${body}\nMachine.board_millis - t0`,
    { board: boardOf(["button14"]), inputs: { pin14: "0" } });
  let p = loop("sleep_ms 1 until b.low?");
  setTimeout(() => core.input("pin14", "1"), 200);
  let r = await p;
  check("P3 an input arrives in a sleep_ms loop within 20 ms", Number(r.inspect) >= 195 && Number(r.inspect) <= 225, brief(r));
  core.input("pin14", "0");
  p = loop("nil until b.low?");
  setTimeout(() => core.input("pin14", "1"), 200);
  r = await p;
  check("P3 ...and in a busy loop (PicoSim.breathe)", Number(r.inspect) >= 195 && Number(r.inspect) <= 230, brief(r));
  core.input("pin14", "0");
  const before = core.posted.progress.length;
  await run('3.times { |i| puts i; sleep_ms 60 }');
  check("P3 what a run prints streams out while it runs", core.posted.progress.length - before >= 2);
  const r8 = await run('s = "\\xFF" * 4; s.setbyte(0, 0); [s.getbyte(0), 255.to_s(16), "ff".to_i(16), "ab" * 2, 200.chr.bytesize]');
  check("P4 String#setbyte/getbyte, String#*, to_s(16), to_i(16)", r8.inspect === '[0, "ff", 255, "abab", 1]', brief(r8));
  const r9 = await run('[defined?(JSON::Digger), URI.parse("https://a.b/c?d=1").request_uri]');
  check("P5 JSON::Digger and URI#request_uri exist", r9.inspect === '["constant", "/c?d=1"]', brief(r9));
  const r10 = await run('Task.new { 2.times { |i| puts "A#{i}"; sleep_ms 10 } }\n2.times { |i| puts "B#{i}"; sleep_ms 10 }\nsleep_ms 30\n:ok');
  check("Tasks take turns with the async scheduler", r10.output === "B0\nA0\nB1\nA1\n", JSON.stringify(r10.output));
}

// ---------- 2. the parts, checked with PicoRubyCells::Board ----------
const graded = [];
async function scenario(name, code, board, checkSrc, tabs = []) {
  const started = performance.now();
  const r = await run(code, { board, tabs });
  graded.push({ name, check: checkSrc, output: r.output, inspect: r.inspect || "", error: r.status === "error" ? `${r.errorClass}: ${r.message}` : null,
                code, summary: r.board, ms: Math.round(performance.now() - started), brief: brief(r) });
  return r;
}
const epdTabs = [tab("epd2in13.rb", "pico/lib/en/epd2in13.rb"), tab("font5x7.rb", "pico/lib/font5x7.rb")];
const wifi = 'CYW43.init("CH")\nCYW43.enable_sta_mode\nCYW43.connect_timeout("chunkynet", "chunkybacon", CYW43::Auth::WPA2_AES_PSK, 10)\n';
await scenario("blink: 3 pulses of about 100 ms on GP15",
  'require "gpio"\nled = GPIO.new(15, GPIO::OUT)\n3.times { led.write(1); sleep_ms 100; led.write(0); sleep_ms 100 }',
  boardOf(["led15"]), "board.pulses(15).size == 3 && board.pulses(15).all? { |ms| ms.between?(90, 140) } && board.level(15) == 0");
await scenario("a scripted press reaches the loop",
  'require "gpio"\nled = GPIO.new(15, GPIO::OUT)\nb = GPIO.new(14, GPIO::IN | GPIO::PULL_UP)\n60.times { led.write(b.low? ? 1 : 0); sleep_ms 10 }',
  boardOf(["led15", "button14"], [{ at: 200, press: 14 }, { at: 400, release: 14 }]),
  "board.level_at(15, 100) == 0 && board.level_at(15, 300) == 1 && board.level_at(15, 550) == 0");
await scenario("ADC: light slider and the chip's temperature",
  'require "adc"\nl = ADC.new(26)\nt = ADC.new(:temperature)\n[l.read.round(1), (27 - (t.read_voltage - 0.706) / 0.001721).round]',
  boardOf(["light26", "temp"], [{ at: 0, set: { adc26: 0.5, tempC: 30 } }]), 'result == [1.7, 30] || result == [1.6, 30] || result.inspect.start_with?("[1.6") || result.inspect.start_with?("[1.7")');
await scenario("I2C scan lists the Environment Sensor's chips",
  'require "i2c"\ni2c = I2C.new(unit: :RP2040_I2C0, frequency: 400_000, sda_pin: 20, scl_pin: 21)\ni2c.scan',
  boardOf(["envsensor"]), 'output.include?("0x76 (0b1110110) +R") && output.lines.size == 10');
await scenario("BME280 through the driver tab reads the sliders",
  'require "bme280"\ni2c = I2C.new(unit: :RP2040_I2C0, frequency: 400_000, sda_pin: 20, scl_pin: 21)\nBME280.new(i2c).measure',
  boardOf(["envsensor"], [{ at: 0, set: { "bme.t": 23.4, "bme.rh": 61, "bme.p": 987.6 } }]), "result == [23.4, 61.0, 987.6]",
  [tab("bme280.rb", "pico/lib/en/bme280.rb")]);
await scenario("e-paper: a full refresh shows the text and the frame",
  'require "spi"\nrequire "epd2in13"\nspi = SPI.new(unit: :RP2040_SPI1, frequency: 4_000_000, sck_pin: 10, copi_pin: 11)\nepd = EPD2in13.new(spi: spi, cs_pin: 9, dc_pin: 8, rst_pin: 12, busy_pin: 13)\nepd.clear\nepd.rect(0, 0, 250, 122)\nepd.text(10, 10, "Chunky bacon!", scale: 2)\nt = Machine.board_millis\nepd.refresh\nMachine.board_millis - t',
  boardOf(["epd213"]), 'board.epd.refreshes == 1 && board.epd.modes == ["full"] && board.epd.frame.text?("Chunky bacon!") && board.epd.frame.black?(249, 121) && result.inspect.to_i.between?(2000, 2300)', epdTabs);
check("e-paper: the page got the frame", core.posted.board.some(b => b.kind === "epd_frame" && b.text.startsWith("full|") && b.text.length === 8005));
await scenario("Net::HTTP (vendored) with a canned rubygems answer",
  `require "net/http"\n${wifi}JSON.parse(Net::HTTP.get("https://rubygems.org", "/api/v1/gems/rake.json"))["name"]`,
  boardOf(["wifi"]), 'result == "rake" && board.wifi_connected? && board.http.last["canned"] && board.http_json("rubygems")["name"] == "rake"');
await scenario("Net::HTTP: Open-Meteo answers in chunks, which 4.0.3 does not decode",
  `${wifi}http = Net::HTTP.new("api.open-meteo.com", 443)\nhttp.use_ssl = true\nres = http.get("/v1/forecast?latitude=47.37&longitude=8.54&current=temperature_2m,weather_code,wind_speed_10m")\n[res.code, res.body.split("\\r\\n").first]`,
  boardOf(["wifi"]), 'result.inspect.start_with?("[\\"200\\", \\"") && !result.inspect.include?("{")');
await scenario("Net::HTTP without Wi-Fi: Failed to connect",
  'begin\n  Net::HTTP.get("https://rubygems.org", "/x")\nrescue IOError => e\n  e.message\nend',
  boardOf(["wifi"]), 'result.inspect.include?("Failed to connect to rubygems.org:443 - no network")');
await scenario("BLE::UART answers the bench's laptop",
  'require "ble"\nrequire "adc"\nuart = BLE::UART.new(name: "ChunkyPico")\ns = ADC.new(:temperature)\nuart.start(1500) do\n  line = uart.gets_nonblock\n  if line\n    uart.puts "PONG" if line.chomp == "PING"\n    uart.puts((27 - (s.read_voltage - 0.706) / 0.001721).round(1)) if line.chomp == "TEMP"\n  end\nend',
  boardOf(["laptop", "temp"], [{ at: 0, ble: "connect" }, { at: 300, ble: "PING" }, { at: 800, ble: "TEMP" }]),
  'board.ble.lines.include?("PONG") && board.ble.lines.any? { |l| l.to_f.between?(17.0, 25.0) } && board.ble.rx == %w[PING TEMP]');
await scenario("the PicoGo stops before the wall with its IR sensors",
  'require "picogo"\nrobot = PicoGo.new\nl = GPIO.new(3, GPIO::IN)\nr = GPIO.new(2, GPIO::IN)\nrobot.forward(40)\nsleep_ms 10 until l.low? || r.low?\nrobot.stop\nHCSR04.new(trig: 14, echo: 15).distance_cm',
  boardOf(["picogo"], [{ at: 0, arena: "wall60" }]),
  "!board.robot.hit? && board.robot.gap_cm.between?(1, 13) && !board.robot.moving? && board.robot.traveled_cm > 30 && result.inspect.to_i.between?(9, 13)",
  [tab("picogo.rb", "pico/lib/en/picogo.rb")]);
await scenario("the camera stand-in gives grey bytes",
  "c = Camera.new.capture(width: 40, height: 30)\n[c.bytesize, c.getbyte(0)]", boardOf(["camera"]), "result == [1200, 235]");
await scenario("PWM: a melody on the buzzer",
  'require "pwm"\np = PWM.new(16, frequency: 440, duty: 50)\nsleep_ms 100\np.frequency(880)\nsleep_ms 100\np.duty(0)',
  boardOf(["buzzer16"]), "board.buzz.map(&:last) == [440, 880, 0] && board.buzz[1][0].between?(90, 130)");

const lcdTabs = [tab("st7789.rb", "pico/lib/en/st7789.rb"), tab("font5x7.rb", "pico/lib/font5x7.rb")];
const wsTabs = [tab("ws2812.rb", "pico/lib/ws2812.rb")];
await scenario("WS2812: the community gem on PicoRuby's PIO assembler lights the PicoGo",
  'require "ws2812"\nleds = WS2812.new(pin: 22, num: 4)\nleds.brightness = 100\nleds.set_rgb(0, 255, 0, 0)\nleds.set_hex(1, 0x00FF00)\nleds.set_hsb(2, 240, 100, 100)\nleds.show',
  boardOf(["picogo"]), "board.leds(22).colors.first(3) == [[255, 0, 0], [0, 255, 0], [0, 0, 255]] && board.leds.timing == [875, 250] && board.mode(22) == \"pio\"", wsTabs);
await scenario("PIO at the default 125 MHz: the WS2812s see nothing",
  'require "ws2812"\nsm = PIO::StateMachine.new(pio: PIO::PIO0, sm: 0, program: WS2812.pio_program, sideset_pins: 6, out_shift_right: false, out_shift_autopull: true, out_shift_threshold: 24)\nsm.start\nsm.put_buffer([0xFF0000 << 8] * 3)\nsm.freq',
  boardOf(["rgbled"]), "board.leds(6).note == \"too_fast\" && board.leds(6).frames == 0 && result.inspect == \"125000000\"", wsTabs);
await scenario("LCD: the driver tab fills, writes and reads a joystick key",
  'require "spi"\nrequire "st7789"\nspi = SPI.new(unit: :RP2040_SPI1, frequency: 10_000_000, sck_pin: 10, copi_pin: 11)\nlcd = ST7789.new(spi: spi)\nlcd.fill(ST7789::BLUE)\nlcd.text("Hi Pico", 40, 40, ST7789::YELLOW, bg: ST7789::BLUE, scale: 3)\nright = GPIO.new(20, GPIO::IN | GPIO::PULL_UP)\nsleep_ms 200\nright.low?',
  boardOf(["lcd114"], [{ at: 0, press: 20 }]),
  "board.lcd.visible? && board.lcd.inverted? && board.lcd.color(0, 0) == 0x001F && board.lcd.text?(\"Hi Pico\") && result == true", lcdTabs);
check("LCD: the page got the glass as rectangles", core.posted.board.some(b => b.kind === "lcd" && /^0,0,240,135\|/.test(b.text) && b.text.length === 12 + 129600));

// ---------- 3. the lessons' cells ----------
function lessonsFromCourse() {
  global.window = {};
  const code = fs.readFileSync(path.join(HTML, "lessons.js"), "utf8");
  new Function("window", code)(global.window);
  return JSON.parse(global.window.LESSONS_JSON).lessons.filter(l => l.pico).map(l => ({ lesson: l, file: "html/lessons.js" }));
}
const files = process.argv.slice(2);
const lessons = lessonsFromCourse().concat(files.map(f => {
  const data = JSON.parse(fs.readFileSync(f, "utf8"));
  return { lesson: data, file: f, solutions: (data.solutions || {}).en || [] };
}));
const tabsOf = cell => (cell.tabs || []).map(t => ({ name: t.name, code: t.src ? src(t.src) : String(t.code || "") }));
const cellBoard = (lesson, cell) => cell.board
  ? JSON.stringify({ board: (lesson.pico && lesson.pico.board) || "pico2w", parts: cell.board.parts || [], bench: cell.bench || [], reset: true }) : "";
for (const { lesson, file, solutions } of lessons) {
  const cells = lesson.en.cells;
  for (let i = 0; i < cells.length; i++) {
    const cell = cells[i];
    if (cell.t !== "c" || cell.engine === "cruby") continue;
    const r = await run(cell.code, { tabs: tabsOf(cell), board: cellBoard(lesson, cell) });
    const ok = cell.raises ? r.status === "error" && r.errorClass === cell.raises : r.status === "ok";
    check(`${lesson.id}/en cell ${i} runs on PicoRuby (${path.basename(file)})`, ok, brief(r) + " " + r.output.slice(-200));
  }
  const ex = cells.find(c => c.t === "x");
  if (ex && solutions) {
    const variants = [["starter", ex.code, false]].concat(solutions.map((s, k) => [`solution${k + 1}`, typeof s === "string" ? s : s.code, true]));
    for (const [label, code, pass] of variants) {
      const r = await run(code, { tabs: tabsOf(ex), board: cellBoard(lesson, ex) });
      graded.push({ name: `${lesson.id}/en ${label} ${pass ? "passes" : "fails"} its check on PicoRuby`, check: ex.check, expect: pass,
                    output: r.output, inspect: r.inspect || "", error: r.status === "error" ? `${r.errorClass}: ${r.message}` : null,
                    code, summary: r.board, brief: brief(r) });
    }
  }
}

// the checks, under CRuby: PicoRubyCells::Board
const verdicts = JSON.parse(execFileSync("ruby", [path.join(ROOT, "test/pico_harness.rb"), "--eval-checks"],
  { input: JSON.stringify(graded), encoding: "utf8" }));
graded.forEach((g, i) => {
  const want = g.expect === undefined ? true : g.expect;
  check(g.name, verdicts[i] === want, g.brief + (g.ms ? ` (${g.ms} ms)` : ""));
});

console.log(failures ? `${failures} FAILED` : "ALL PICO WASM CHECKS PASSED");
process.exit(failures ? 1 : 0);
