// Fakes for html/pico_real.js, for test/pico_real_test.mjs (node) and
// test/pico_real_ui_test.mjs (a browser: injected with addInitScript):
//
//   FakeR2P2      R2P2's shell as its sources describe it (the citations
//                 are in html/pico_real.js): the "$> " prompt, irb, Ctrl-B
//                 + one PicoModem session per file, Ctrl-C / Ctrl-D, a file
//                 path typed at the prompt runs that file (here: its
//                 `puts "..."` lines are printed), the terminal queries
//   FakeSerialPort a Web Serial port in front of a FakeR2P2
//   FakeBluetooth  navigator.bluetooth with one Pico 2 W running a
//                 BLE::UART that answers PING with PONG
//
// Not a copy of R2P2 - a model of what the page relies on. The real device
// side of PicoModem is checked separately (test/vendor/picomodem.rb, run
// by test/pico_real_device.rb).
(function (root) {
  "use strict";

  var STX = 2, ACK = 6;
  var enc = function (s) { return new TextEncoder().encode(s); };
  var dec = function (u8) { return new TextDecoder().decode(u8); };

  function crc16(b) {
    var crc = 0xFFFF;
    for (var i = 0; i < b.length; i++) {
      crc ^= b[i] << 8;
      for (var j = 0; j < 8; j++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
    return crc;
  }
  function crc32(b) {
    var c = 0xFFFFFFFF;
    for (var i = 0; i < b.length; i++) {
      c ^= b[i];
      for (var j = 0; j < 8; j++) c = c & 1 ? (c >>> 1) ^ 0xEDB88320 : c >>> 1;
    }
    return ~c >>> 0;
  }
  function frame(cmd, payload) {
    var body = [cmd].concat(Array.from(payload || []));
    var crc = crc16(body);
    return new Uint8Array([STX, body.length >> 8, body.length & 255].concat(body, [crc >> 8, crc & 255]));
  }

  // +opts+: { failPath: path the device refuses (ERROR "No space left"),
  //           badCrc: true -> the DONE_ACK carries a wrong CRC-32,
  //           mute: true -> no prompt ever (a Pico without R2P2) }
  function FakeR2P2(opts) {
    this.opts = opts || {};
    this.mode = "shell";
    this.line = "";
    this.files = {};
    this.out = function () {};
    this.writes = [];          // every write the host made: [length, ...]
    this.runs = [];
    this.replies = "";         // what the host answered to the terminal queries
    this.rx = [];              // session bytes not yet parsed
    this.session = null;
    this.timers = [];
  }
  FakeR2P2.prototype.emit = function (s) { if (!this.opts.mute) this.out(typeof s === "string" ? enc(s) : s); };
  FakeR2P2.prototype.later = function (ms, f) { var self = this; this.timers.push(setTimeout(function () { f.call(self); }, ms)); };
  // as Editor::Line#refresh: the prompt, the line, erase to the end - and
  // a cursor-position query (it asks on every redraw)
  FakeR2P2.prototype.prompt = function () {
    var p = this.mode === "irb" ? "irb" : "$";
    this.emit("\x1b[?25l\x1b[1G" + p + "> " + this.line + "\x1b[0K\x1b[0J\x1b[6n\x1b[?25h");
  };
  FakeR2P2.prototype.boot = function () { this.emit("\x1b[5n"); this.later(5, function () { this.prompt(); }); };
  FakeR2P2.prototype.input = function (u8) {
    this.writes.push(u8.length);
    for (var i = 0; i < u8.length; i++) this.byte(u8[i]);
  };
  FakeR2P2.prototype.byte = function (b) {
    // a terminal's answer to a query ends up in stdin too
    if (this.inReply || b === 27) {
      this.inReply = b !== 0x52 && b !== 0x6E;   // ...R or ...n ends it
      this.replies += String.fromCharCode(b);
      return;
    }
    if (this.mode === "session") { this.rx.push(b); this.parse(); return; }
    if (this.mode === "running") {
      if (b === 3) { this.emit("^C\n"); this.mode = "shell"; this.prompt(); }
      return;
    }
    if (b === 2 && this.mode === "shell") {
      this.line = "";
      this.emit("\n^B\n");
      this.emit(new Uint8Array([ACK]));
      this.mode = "session";
      this.session = { total: null, written: 0, data: [], path: "" };
      return;
    }
    if (b === 3) { this.line = ""; this.emit("\n^C\x1b[0J\n"); this.prompt(); return; }
    if (b === 4) {
      if (this.mode === "irb" && this.line === "") { this.mode = "shell"; this.emit("\n"); this.prompt(); return; }
      if (this.line === "") { this.emit("\n^D\n"); this.prompt(); }
      return;
    }
    if (b === 13 || b === 10) { this.enter(); return; }
    if (b === 8 || b === 127) { this.line = this.line.slice(0, -1); this.prompt(); return; }
    if (b >= 32) { this.line += String.fromCharCode(b); this.prompt(); }
  };
  FakeR2P2.prototype.enter = function () {
    var cmd = this.line.trim();
    this.line = "";
    this.emit("\n");
    if (this.mode === "irb") { if (cmd) this.emit("=> nil\n"); this.prompt(); return; }
    if (cmd === "") { this.prompt(); return; }
    if (cmd === "irb") { this.mode = "irb"; this.prompt(); return; }
    if (cmd.charAt(0) === "/" && this.files[cmd]) { this.run(cmd); return; }
    this.emit(cmd.split(" ")[0] + ": command not found\n");
    this.prompt();
  };
  // a "program": its requires must be in /lib, its puts lines are printed;
  // one with "loop" keeps running until Ctrl-C
  FakeR2P2.prototype.run = function (path) {
    var text = dec(this.files[path]);
    this.runs.push(path);
    var req = /require ["']([\w\/]+)["']/g, m;
    while ((m = req.exec(text))) {
      if (!this.files["/lib/" + m[1] + ".rb"] && ["gpio", "adc", "pwm", "i2c", "spi", "ble", "pio", "cyw43", "net/http"].indexOf(m[1]) < 0) {
        this.emit("cannot load such file -- " + m[1] + " (LoadError)\n");
        this.prompt();
        return;
      }
    }
    var out = /puts\s+"([^"]*)"/g;
    while ((m = out.exec(text))) this.emit(m[1] + "\n");
    if (/\bloop\b/.test(text)) { this.mode = "running"; return; }
    this.prompt();
  };
  // PicoModem's device side (picomodem.rb), byte by byte
  FakeR2P2.prototype.parse = function () {
    while (true) {
      while (this.rx.length && this.rx[0] !== STX) this.rx.shift();
      if (this.rx.length < 3) return;
      var n = (this.rx[1] << 8) | this.rx[2];
      if (this.rx.length < 3 + n + 2) return;
      var all = this.rx.splice(0, 3 + n + 2);
      var body = all.slice(3, 3 + n);
      var want = (all[3 + n] << 8) | all[4 + n];
      if (crc16(body) !== want) { this.end("timeout"); return; }
      this.command(body[0], new Uint8Array(body.slice(1)));
      if (this.mode !== "session") return;
    }
  };
  FakeR2P2.prototype.command = function (cmd, payload) {
    var s = this.session;
    if (cmd === 0xFF) { this.end(s.total === null ? "abort" : "write " + s.path); return; }
    if (s.total === null) {
      if (cmd !== 2) { this.emit(frame(0xFE, enc("Unknown command"))); this.end("?"); return; }
      s.total = ((payload[0] << 24) | (payload[1] << 16) | (payload[2] << 8) | payload[3]) >>> 0;
      s.path = dec(payload.slice(4));
      if (this.opts.failPath === s.path) { this.emit(frame(0xFE, enc("No space left"))); this.end("write " + s.path); return; }
      this.emit(frame(0x82, [1]));
      if (s.total === 0) this.finish();
      return;
    }
    if (cmd !== 4) { this.emit(frame(0xFE, enc("Unexpected command during transfer"))); this.end("write " + s.path); return; }
    for (var i = 0; i < payload.length; i++) s.data.push(payload[i]);
    s.written += payload.length;
    this.emit(frame(0x84, [0]));
    if (s.written >= s.total) this.finish();
  };
  FakeR2P2.prototype.finish = function () {
    var s = this.session;
    var data = new Uint8Array(s.data);
    this.files[s.path] = data;
    var c = crc32(data);
    if (this.opts.badCrc) c = (c ^ 1) >>> 0;
    this.emit(frame(0x8F, [0, (c >>> 24) & 255, (c >>> 16) & 255, (c >>> 8) & 255, c & 255]));
    this.end("write " + s.path);
  };
  // the session returns to the shell: 200 ms, the note, the prompt
  FakeR2P2.prototype.end = function (info) {
    this.mode = "shell";
    this.session = null;
    this.rx = [];
    this.later(200, function () { this.emit("[PicoModem] " + info + "\n"); this.prompt(); });
  };
  FakeR2P2.prototype.text = function (path) { return this.files[path] ? dec(this.files[path]) : null; };
  FakeR2P2.prototype.stop = function () { this.timers.forEach(clearTimeout); };

  // a Web Serial port: open(), readable, writable, getInfo(), close()
  function FakeSerialPort(device) {
    var self = this;
    this.device = device;
    this.opened = null;
    this.readable = null;
    this.writable = null;
    device.out = function (u8) { if (self.ctl) try { self.ctl.enqueue(u8); } catch (e) { /* closed */ } };
  }
  FakeSerialPort.prototype.open = function (opts) {
    var self = this;
    this.opened = opts;
    this.readable = new ReadableStream({ start: function (c) { self.ctl = c; } });
    this.writable = new WritableStream({ write: function (chunk) { self.device.input(new Uint8Array(chunk)); } });
    this.device.boot();
    return Promise.resolve();
  };
  FakeSerialPort.prototype.getInfo = function () { return { usbVendorId: 0x16C0, usbProductId: 0x4001 }; };
  FakeSerialPort.prototype.close = function () { this.closedByLink = true; try { this.ctl.close(); } catch (e) { /* closed */ } this.device.stop(); return Promise.resolve(); };
  // the cable comes out
  FakeSerialPort.prototype.unplug = function () { try { this.ctl.error(new Error("The device has been lost.")); } catch (e) { /* closed */ } };

  // navigator.bluetooth with one Pico 2 W
  function FakeBluetooth(name) {
    var self = this;
    this.name = name || "ChunkyPico";
    this.asked = null;
    this.rx = "";
    this.writes = [];
    var listeners = {};
    this.tx = {
      uuid: "6e400003-b5a3-f393-e0a9-e50e24dcca9e",
      notifying: false,
      startNotifications: function () { if (self.failNotify) return Promise.reject(new Error("NotSupportedError")); this.notifying = true; return Promise.resolve(this); },
      addEventListener: function (type, f) { (listeners[type] = listeners[type] || []).push(f); },
      value: null
    };
    this.rxChar = {
      uuid: "6e400002-b5a3-f393-e0a9-e50e24dcca9e",
      writeValueWithoutResponse: function (buf) {
        var u8 = new Uint8Array(buf.buffer ? buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) : buf);
        self.writes.push(u8.length);
        self.rx += dec(u8);
        var at;
        while ((at = self.rx.indexOf("\n")) >= 0) {
          var line = self.rx.slice(0, at);
          self.rx = self.rx.slice(at + 1);
          self.got = (self.got || []).concat([line]);
          if (line === "PING") self.notify("PONG\n");
        }
        return Promise.resolve();
      }
    };
    // the Pico sends: TX notifications of at most 20 bytes
    this.notify = function (text) {
      var bytes = enc(text);
      for (var i = 0; i < bytes.length; i += 20) {
        var piece = bytes.slice(i, i + 20);
        self.tx.value = new DataView(piece.buffer);
        (listeners.characteristicvaluechanged || []).forEach(function (f) { f({ target: self.tx }); });
      }
    };
    var devListeners = {};
    var service = {
      getCharacteristic: function (uuid) {
        if (uuid === self.rxChar.uuid) return Promise.resolve(self.rxChar);
        if (uuid === self.tx.uuid) return Promise.resolve(self.tx);
        return Promise.reject(new Error("NotFoundError"));
      }
    };
    this.device = {
      name: this.name,
      addEventListener: function (type, f) { (devListeners[type] = devListeners[type] || []).push(f); },
      gatt: {
        connected: false,
        connect: function () { this.connected = true; return Promise.resolve({ getPrimaryService: function (uuid) { return uuid === "6e400001-b5a3-f393-e0a9-e50e24dcca9e" ? Promise.resolve(service) : Promise.reject(new Error("no service")); } }); },
        disconnect: function () { this.connected = false; (devListeners.gattserverdisconnected || []).forEach(function (f) { f({}); }); }
      }
    };
  }
  FakeBluetooth.prototype.requestDevice = function (opts) { this.asked = opts; return Promise.resolve(this.device); };
  FakeBluetooth.prototype.getAvailability = function () { return Promise.resolve(true); };

  var api = { FakeR2P2: FakeR2P2, FakeSerialPort: FakeSerialPort, FakeBluetooth: FakeBluetooth, frame: frame, crc16: crc16, crc32: crc32 };
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.PicoRealFakes = api;
})(typeof window !== "undefined" ? window : this);
