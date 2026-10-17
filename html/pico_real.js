// A REAL Pico from the page (DESIGN N6, docs/HANDOVER.md §6r), opt-in and
// beside the simulator, on the page's main thread:
//
// - USB (Web Serial): a Pico running R2P2. Its shell is on the first of the
//   three USB serial ports R2P2 opens. The page shows what it prints in a
//   small terminal, types what the learner types, and "Send this cell"
//   writes the cell's tabs to /lib/<name> and its code to
//   /home/chunky.rb (or /home/app.rb) with PicoModem, R2P2's own transfer
//   protocol, then types the file's path at the prompt, which runs it.
// - Bluetooth (Web Bluetooth): a Pico 2 W running BLE::UART (lesson
//   pico-ble). The bench's laptop then talks to it instead of to the
//   simulated radio, and what it sends reaches the CRuby cell too.
//
// NOT TRIED ON REAL HARDWARE YET. Everything below follows the sources it
// cites (picoruby/picoruby 4.0.3, the same as the course's PicoRuby.wasm,
// and picoruby.org's R2P2 Web Terminal, picoruby/picoruby.github.io
// 932c7ca 2026-10-12); the tests run it against a fake R2P2 and against
// PicoModem's own device code (test/pico_real_test.mjs).
//
//   chunkyPicoReal.attach(figure, bench, t)  a bench was built: add the panels (pico_board.js)
//   chunkyPicoReal.serialSupport()         {ok, why: "insecure" | "api" | ""}
//   chunkyPicoReal.bleSupport()            the same for Web Bluetooth
//   chunkyPicoReal.ble()                   null, or {name} while a real Pico 2 W is connected
//   chunkyPicoReal.bleWrite(text)          a line to it (pico_board.js's sendLine)
//   chunkyPicoReal.state()                 for tests
//   chunkyPicoReal.lib                     the parts without a page (Term, Link, frames, CRCs)
//
// What R2P2 does, from its sources (paths in picoruby/picoruby 4.0.3):
//
// - The shell's prompt is "$> ", irb's "irb> ": Editor::Line prints
//   @prompt and "> " (mrbgems/picoruby-editor/mrblib/editor.rb 109, 187-188;
//   picoruby-shell/mrblib/shell.rb 434 sets "irb").
// - The line editor asks the terminal where its cursor is (ESC[6n, answered
//   ESC[<row>;<col>R) on every redraw and for the screen size, and at boot
//   whether a terminal is there at all (ESC[5n, answered ESC[0n) -
//   picoruby-io-console/mrblib/io-console.rb 43-100, editor.rb 34-44, 177.
//   Unanswered, the shell takes the terminal as "dumb"; so Term answers.
// - At the shell's prompt, Ctrl-C (3) clears the line; a running program
//   is stopped by it (picoruby-machine/ports/rp2040/machine.c 60-75 turns
//   the byte into SIGINT in cooked mode; picoruby-sandbox/mrblib/sandbox.rb
//   50-60 stops the job). In irb, Ctrl-D (4) on an empty line leaves it
//   (shell.rb 505-508); at the shell's prompt it only prints ^D (shell.rb
//   464-467). So "back to the prompt" is Ctrl-C, then Ctrl-D, then the
//   prompt on the cursor's line.
// - A command that starts with "/" is a file, run as a job: Sandbox
//   compiles a .rb (shell.rb 273-276, job.rb 46-60, sandbox.rb 13-35). The
//   shell sets $LOAD_PATH = ["/lib"] and HOME = /home and creates both
//   (shell.rb 129-139); a required file is remembered as its full path in
//   $LOADED_FEATURES (picoruby-require/mrblib/require.rb 62-72, 37-58).
// - PicoModem (RBTP): Ctrl-B (STX, 2) at the shell's prompt prints "\n^B",
//   writes ACK (6) and runs one PicoModem session (shell.rb 455-460). A
//   frame is STX, a big-endian length of cmd + payload, cmd, payload and a
//   big-endian CRC-16/CCITT (poly 0x1021, init 0xFFFF) over cmd + payload
//   (picoruby-picomodem/mrblib/picomodem.rb 5-10, 118-126;
//   picoruby-crc/src/crc.c 21-35). FILE_WRITE (2) carries a 4-byte size and
//   the path; the device answers FILE_ACK (0x82) READY, then CHUNK_ACK
//   (0x84) for each CHUNK (4) of up to 480 bytes, then DONE_ACK (0x8F) with
//   OK and the file's CRC-32 (zlib) - or ERROR (0xFE) and a message
//   (picomodem.rb 17-39, 183-240). One session moves one file; 200 ms after
//   it the shell prints "[PicoModem] write <path>" (picomodem.rb 83-86).
// - The R2P2 Web Terminal (site pages/r2p2/terminal.rb) starts capturing
//   raw bytes before it sends STX and skips everything up to the ACK and
//   up to each frame's STX (539-557, 498-519); it writes in pieces of 32
//   bytes, 20 ms apart, "for USB-CDC stability" (6-7, 448-463). The host
//   tool waits 200 ms after the ACK before its first frame, because over
//   native USB the shell hands the console to the session a beat late
//   (picoruby master, mrbgems/picoruby-picomodem/tools/picomodem.rb
//   179-199). Both wait 5 s for an answer (TIMEOUT_MS).
// - R2P2's USB device: vendor 0x16C0, three CDC ports, the shell on the
//   first (picoruby-r2p2/ports/rp2040/usb_descriptors.c 42-45, 90-95;
//   include/tusb_config.h 116). The baud rate means nothing to a USB CDC
//   port; the Web Terminal opens it at 115200 (terminal.html 44).
// - BLE::UART is the Nordic UART Service: the device advertises its
//   128-bit service UUID, the central writes to RX ...0002 (write without
//   response) and gets notifications on TX ...0003, 20 bytes each until a
//   bigger MTU is agreed (picoruby-ble-uart/mrblib/ble_uart.rb 23-25, 39,
//   65-100). PicoRuby.wasm's JS::BLE::UART asks the browser for exactly
//   those (picoruby-wasm/mrblib/ble_uart.rb 7-10, 34-39); it is not used
//   here because the cells' PicoRuby runs in a worker, which has no Web
//   Bluetooth (MDN), and the shell's has its own job.
(function (root) {
  "use strict";

  // ---------- constants (sources above) ----------

  var STX = 0x02, ACK = 0x06;
  var PM = {
    FILE_READ: 0x01, FILE_WRITE: 0x02, CHUNK: 0x04, ABORT: 0xFF,
    FILE_DATA: 0x81, FILE_ACK: 0x82, CHUNK_ACK: 0x84, DONE_ACK: 0x8F, ERROR: 0xFE,
    OK: 0x00, READY: 0x01, CHUNK_SIZE: 480, TIMEOUT_MS: 5000
  };
  var TX_CHUNK = 32, TX_GAP_MS = 20, ACK_SETTLE_MS = 200;
  var R2P2_VENDOR = 0x16C0;
  var NUS = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  var NUS_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";   // the laptop writes here
  var NUS_TX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";   // the Pico notifies here
  var BLE_CHUNK = 20;
  var PROMPT = /^\$> ?$/, IRB_PROMPT = /^irb> /;

  // ---------- bytes ----------

  function utf8(text) { return new TextEncoder().encode(String(text)); }

  function concat(list) {
    var n = 0;
    list.forEach(function (a) { n += a.length; });
    var out = new Uint8Array(n), at = 0;
    list.forEach(function (a) { out.set(a, at); at += a.length; });
    return out;
  }

  function u32(n) { return new Uint8Array([(n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255]); }

  // CRC-16/CCITT-FALSE, as picoruby-crc's generate_crc16
  function crc16(bytes, crc) {
    crc = crc === undefined ? 0xFFFF : crc;
    for (var i = 0; i < bytes.length; i++) {
      crc ^= bytes[i] << 8;
      for (var j = 0; j < 8; j++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
    return crc & 0xFFFF;
  }

  // CRC-32 (zlib), as picoruby-crc's generate_crc32
  function crc32(bytes, crc) {
    var c = ~(crc || 0) >>> 0;
    for (var i = 0; i < bytes.length; i++) {
      c ^= bytes[i];
      for (var j = 0; j < 8; j++) c = c & 1 ? (c >>> 1) ^ 0xEDB88320 : c >>> 1;
    }
    return ~c >>> 0;
  }

  // one PicoModem frame: STX, length (cmd + payload), cmd, payload, CRC-16
  function frame(cmd, payload) {
    payload = payload || new Uint8Array(0);
    var body = concat([new Uint8Array([cmd]), payload]);
    var crc = crc16(body);
    return concat([new Uint8Array([STX, body.length >> 8, body.length & 255]), body, new Uint8Array([crc >> 8, crc & 255])]);
  }

  function sleep(ms) { return new Promise(function (ok) { setTimeout(ok, ms); }); }

  // ---------- Term: as much of a VT100 as R2P2's line editor uses ----------
  //
  // A screen of rows x cols, the lines scrolled off its top kept above it.
  // write(bytes) takes what the device sent and returns what a terminal
  // answers (the cursor-position and status reports), or "".
  function Term(rows, cols) {
    this.rows = rows || 24;
    this.cols = cols || 80;
    this.decoder = new TextDecoder("utf-8");
    this.state = 0;        // 0 text, 1 after ESC, 2 in CSI, 3 in OSC
    this.params = "";
    this.reset();
  }
  Term.prototype.reset = function () {
    this.screen = [];
    for (var i = 0; i < this.rows; i++) this.screen.push(this.blank());
    this.above = [];
    this.r = 0;
    this.c = 0;
    this.wrap = false;
    this.changed = 0;
  };
  Term.prototype.blank = function () { var a = []; for (var i = 0; i < this.cols; i++) a.push(" "); return a; };
  Term.prototype.scrollUp = function (n) {
    for (var i = 0; i < n; i++) {
      this.above.push(this.screen.shift().join("").replace(/\s+$/, ""));
      this.screen.push(this.blank());
    }
    if (this.above.length > 400) this.above.splice(0, this.above.length - 400);
  };
  Term.prototype.lineFeed = function () {
    if (this.r === this.rows - 1) this.scrollUp(1); else this.r++;
  };
  // East-Asian wide characters (kana, kanji, hangul, full-width forms,
  // most emoji) take two columns, as in xterm.js: R2P2's line editor asks
  // for the cursor's column and redraws by it
  function wide(cp) {
    return (cp >= 0x1100 && cp <= 0x115F) || (cp >= 0x2E80 && cp <= 0x303E) ||
      (cp >= 0x3041 && cp <= 0x33FF) || (cp >= 0x3400 && cp <= 0x4DBF) ||
      (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0xA000 && cp <= 0xA4CF) ||
      (cp >= 0xAC00 && cp <= 0xD7A3) || (cp >= 0xF900 && cp <= 0xFAFF) ||
      (cp >= 0xFE30 && cp <= 0xFE4F) || (cp >= 0xFF00 && cp <= 0xFF60) ||
      (cp >= 0xFFE0 && cp <= 0xFFE6) || (cp >= 0x1F300 && cp <= 0x1F64F) ||
      (cp >= 0x1F900 && cp <= 0x1F9FF) || (cp >= 0x20000 && cp <= 0x3FFFD);
  }
  Term.prototype.put = function (ch) {
    var w = wide(ch.codePointAt(0)) && this.cols > 1 ? 2 : 1;
    if (this.wrap || (w === 2 && this.c === this.cols - 1)) { this.c = 0; this.lineFeed(); this.wrap = false; }
    this.screen[this.r][this.c] = ch;
    if (w === 2) { this.c++; this.screen[this.r][this.c] = ""; }   // its right half
    if (this.c === this.cols - 1) this.wrap = true; else this.c++;
  };
  Term.prototype.write = function (data) {
    var text = typeof data === "string" ? data : this.decoder.decode(data, { stream: true });
    var reply = "";
    for (var i = 0; i < text.length; i++) {
      var code = text.codePointAt(i), ch = String.fromCodePoint(code);
      if (code > 0xFFFF) i++;          // the low surrogate goes with it
      if (this.state === 1) {
        if (ch === "[") { this.state = 2; this.params = ""; }
        else if (ch === "]") this.state = 3;
        else { this.state = 0; if (ch === "c") this.reset(); }
        continue;
      }
      if (this.state === 2) {
        if (code >= 0x40 && code <= 0x7E) { reply += this.csi(ch, this.params); this.state = 0; }
        else this.params += ch;
        continue;
      }
      if (this.state === 3) {           // an OSC (a window title): up to BEL or ST
        if (code === 7 || ch === "\\") this.state = 0;
        continue;
      }
      if (code === 27) { this.state = 1; continue; }
      if (ch === "\r") { this.c = 0; this.wrap = false; }
      // a bare LF is a new line: R2P2 sends LF alone, and the Web Terminal
      // has xterm's convertEol on (terminal.rb 39)
      else if (ch === "\n") { this.c = 0; this.lineFeed(); this.wrap = false; }
      else if (code === 8) { if (this.c > 0) this.c--; this.wrap = false; }
      else if (ch === "\t") { this.c = Math.min(this.cols - 1, (Math.floor(this.c / 8) + 1) * 8); }
      else if (code >= 32 && code !== 127) this.put(ch);
    }
    this.changed++;
    return reply;
  };
  Term.prototype.csi = function (fin, params) {
    var priv = params.charAt(0) === "?";
    var nums = (priv ? params.slice(1) : params).split(";").map(function (s) { return s === "" ? null : parseInt(s, 10); });
    var n = nums[0] === null || nums[0] === undefined || isNaN(nums[0]) ? 1 : nums[0];
    var self = this;
    var clamp = function () {
      self.r = Math.max(0, Math.min(self.rows - 1, self.r));
      self.c = Math.max(0, Math.min(self.cols - 1, self.c));
      self.wrap = false;
    };
    var clear = function (row, from, to) { for (var x = from; x < to; x++) self.screen[row][x] = " "; };
    if (priv) return "";              // ?25l / ?25h: the cursor's visibility
    switch (fin) {
      case "A": this.r -= n; clamp(); break;
      case "B": this.r += n; clamp(); break;
      case "C": this.c += n; clamp(); break;
      case "D": this.c -= n; clamp(); break;
      case "E": this.r += n; this.c = 0; clamp(); break;
      case "F": this.r -= n; this.c = 0; clamp(); break;
      case "G": this.c = n - 1; clamp(); break;
      case "H": case "f":
        this.r = (nums[0] || 1) - 1; this.c = (nums[1] || 1) - 1; clamp(); break;
      case "J": {
        var m = nums[0] || 0;
        if (m === 0) { clear(this.r, this.c, this.cols); for (var y = this.r + 1; y < this.rows; y++) clear(y, 0, this.cols); }
        else if (m === 1) { for (var y1 = 0; y1 < this.r; y1++) clear(y1, 0, this.cols); clear(this.r, 0, this.c + 1); }
        else { for (var y2 = 0; y2 < this.rows; y2++) clear(y2, 0, this.cols); }
        break;
      }
      case "K": {
        var k = nums[0] || 0;
        if (k === 0) clear(this.r, this.c, this.cols);
        else if (k === 1) clear(this.r, 0, this.c + 1);
        else clear(this.r, 0, this.cols);
        break;
      }
      case "S": this.scrollUp(n); break;
      case "T":
        for (var t = 0; t < n; t++) { this.screen.pop(); this.screen.unshift(this.blank()); }
        break;
      case "n":
        if (nums[0] === 5) return "\x1b[0n";
        if (nums[0] === 6) return "\x1b[" + (this.r + 1) + ";" + (this.c + 1) + "R";
        break;
      default: break;                 // m (colours), h / l and the rest: nothing to draw
    }
    return "";
  };
  // the cursor's line, without its trailing blanks
  Term.prototype.cursorLine = function () { return this.screen[this.r].join("").replace(/\s+$/, ""); };
  // what is on the screen and above it, the empty rows below the cursor left out
  Term.prototype.text = function () {
    var last = this.r;
    for (var y = this.rows - 1; y > this.r; y--) if (this.screen[y].join("").trim() !== "") { last = y; break; }
    var lines = this.above.slice();
    for (var i = 0; i <= last; i++) lines.push(this.screen[i].join("").replace(/\s+$/, ""));
    return lines.join("\n");
  };

  // ---------- Link: R2P2's shell over a serial port ----------
  //
  // +port+ is an opened Web Serial port, or anything with a readable and a
  // writable byte stream (the tests' fakes). +onChange+ is called when the
  // terminal changed.
  function Link(port, onChange) {
    this.port = port;
    this.term = new Term(24, 80);
    this.onChange = onChange || function () {};
    this.capture = null;            // raw bytes while a PicoModem session runs
    this.waiters = [];
    this.out = Promise.resolve();
    this.closed = false;
    this.busy = false;
    this.writer = port.writable.getWriter();
    this.reader = port.readable.getReader();
    this.done = this.pump();
  }
  Link.prototype.pump = function () {
    var self = this;
    var step = function () {
      return self.reader.read().then(function (r) {
        if (r.done) { self.gone(); return; }
        self.bytes(r.value instanceof Uint8Array ? r.value : new Uint8Array(r.value));
        return step();
      }, function () { self.gone(); });
    };
    return step();
  };
  // the device went away (unplugged, a read error): let go of the port too,
  // else a later Connect finds it still open and locked
  Link.prototype.gone = function () {
    if (this.closed) return;
    this.closed = true;
    this.wake();
    try { this.reader.releaseLock(); } catch (e) { /* still reading */ }
    try { this.writer.releaseLock(); } catch (e) { /* pending */ }
    try { if (this.port.close) Promise.resolve(this.port.close()).catch(function () {}); } catch (e) { /* closed */ }
    this.onChange("gone");
  };
  Link.prototype.bytes = function (u8) {
    if (this.capture) {
      for (var i = 0; i < u8.length; i++) this.capture.push(u8[i]);
    } else {
      var reply = this.term.write(u8);
      if (reply) this.raw(utf8(reply));
      this.onChange("term");
    }
    this.wake();
  };
  Link.prototype.wake = function () {
    var w = this.waiters;
    this.waiters = [];
    w.forEach(function (f) { f(); });
  };
  // the next change (bytes in, or the port gone), or +ms+ passed
  Link.prototype.next = function (ms) {
    var self = this;
    return new Promise(function (ok) {
      var timer = setTimeout(function () { var i = self.waiters.indexOf(ok); if (i >= 0) self.waiters.splice(i, 1); ok(); }, ms);
      self.waiters.push(function () { clearTimeout(timer); ok(); });
    });
  };
  // a write now, in one piece (a key, a terminal's answer)
  Link.prototype.raw = function (bytes) {
    var self = this;
    this.out = this.out.then(function () { return self.closed ? null : self.writer.write(bytes); }).catch(function () {});
    return this.out;
  };
  // a longer write: 32 bytes at a time, 20 ms apart, as the Web Terminal
  Link.prototype.send = function (bytes) {
    if (typeof bytes === "string") bytes = utf8(bytes);
    var self = this;
    this.out = this.out.then(function () {
      var at = 0;
      var more = function () {
        if (self.closed || at >= bytes.length) return null;
        var piece = bytes.subarray(at, at + TX_CHUNK);
        at += TX_CHUNK;
        return self.writer.write(piece).then(function () { return at < bytes.length ? sleep(TX_GAP_MS).then(more) : null; });
      };
      return more();
    }).catch(function () {});
    return this.out;
  };
  // wait until test(term) holds; false after +ms+
  Link.prototype.waitFor = function (test, ms) {
    var self = this, until = Date.now() + ms;
    var loop = function () {
      if (test(self.term)) return true;
      if (self.closed || Date.now() >= until) return false;
      return self.next(until - Date.now()).then(loop);
    };
    return Promise.resolve().then(loop);
  };
  Link.prototype.atPrompt = function () { return PROMPT.test(this.term.cursorLine()); };
  // back to the shell's empty prompt: Ctrl-C stops a program (or clears
  // the line), Ctrl-D leaves irb; true once "$> " is on the cursor's line
  Link.prototype.toPrompt = function () {
    var self = this;
    return this.raw(new Uint8Array([3])).then(function () { return sleep(250); })
      .then(function () { return self.raw(new Uint8Array([4])); })
      .then(function () { return self.waitFor(function () { return self.atPrompt(); }, 1500); })
      .then(function (ok) {
        if (ok) return true;
        if (IRB_PROMPT.test(self.term.cursorLine())) return self.raw(new Uint8Array([4])).then(function () { return self.waitFor(function () { return self.atPrompt(); }, 1500); });
        // one more Ctrl-C (a program that was still printing), then Enter
        return self.raw(new Uint8Array([3])).then(function () { return self.waitFor(function () { return self.atPrompt(); }, 1500); })
          .then(function (ok2) { return ok2 || self.raw(utf8("\r")).then(function () { return self.waitFor(function () { return self.atPrompt(); }, 1500); }); });
      });
  };
  // n raw bytes of the session, or null after +ms+ without a byte
  Link.prototype.take = function (n, ms) {
    var self = this;
    var loop = function () {
      if (self.capture.length >= n) return self.capture.splice(0, n);
      if (self.closed) return null;
      var before = self.capture.length;
      return self.next(ms).then(function () { return self.capture.length > before || self.closed ? loop() : null; });
    };
    return Promise.resolve().then(loop);
  };
  // one frame from the device: [cmd, payload], or null (a timeout, a bad
  // CRC); bytes before its STX are skipped, as the Web Terminal does
  Link.prototype.recvFrame = function (ms) {
    var self = this;
    ms = ms || PM.TIMEOUT_MS;
    var seek = function () {
      return self.take(1, ms).then(function (b) {
        if (!b) return null;
        return b[0] === STX ? header() : seek();
      });
    };
    var header = function () {
      return self.take(2, ms).then(function (len) {
        if (!len) return null;
        var n = (len[0] << 8) | len[1];
        return self.take(n + 2, ms).then(function (rest) {
          if (!rest || n < 1) return null;
          var body = new Uint8Array(rest.slice(0, n));
          var want = (rest[n] << 8) | rest[n + 1];
          if (crc16(body) !== want) return null;
          return [body[0], body.subarray(1)];
        });
      });
    };
    return seek();
  };
  // write one file with PicoModem; resolves {ok, error, crc}
  Link.prototype.putFile = function (path, data, progress) {
    var self = this;
    if (typeof data === "string") data = utf8(data);
    progress = progress || function () {};
    var inSession = false;
    var fail = function (msg) {
      var abort = inSession ? self.send(frame(PM.ABORT)).then(function () { return sleep(100); }) : Promise.resolve();
      return abort.then(function () { return { ok: false, error: msg }; });
    };
    var text = function (payload) { return new TextDecoder().decode(payload); };
    var notes = function () { return self.term.text().split("[PicoModem]").length; };
    var before = notes();
    // the device's "\n^B" goes into the capture: a new line here instead
    if (this.term.cursorLine() !== "") { this.term.write("\n"); this.onChange("term"); }
    this.capture = [];
    return this.raw(new Uint8Array([STX]))
      .then(function () {
        // the ACK, skipping the shell's "\n^B" before it
        var until = Date.now() + PM.TIMEOUT_MS;
        var seekAck = function () {
          return self.take(1, Math.max(1, until - Date.now())).then(function (b) {
            if (!b) return false;
            return b[0] === ACK ? true : seekAck();
          });
        };
        return seekAck();
      })
      .then(function (acked) {
        if (!acked) return fail("noAck");
        inSession = true;
        return sleep(ACK_SETTLE_MS).then(function () {
          var head = concat([u32(data.length), utf8(path)]);
          return self.send(frame(PM.FILE_WRITE, head));
        }).then(function () { return self.recvFrame(); }).then(function (f) {
          if (!f) return fail("timeout");
          if (f[0] === PM.ERROR) { inSession = false; return fail(text(f[1])); }
          if (f[0] !== PM.FILE_ACK) return fail("unexpected 0x" + f[0].toString(16));
          var at = 0;
          var chunk = function () {
            if (at >= data.length) return done();
            var piece = data.subarray(at, at + PM.CHUNK_SIZE);
            return self.send(frame(PM.CHUNK, piece)).then(function () { return self.recvFrame(); }).then(function (a) {
              if (!a) return fail("timeout");
              if (a[0] === PM.ERROR) { inSession = false; return fail(text(a[1])); }
              if (a[0] !== PM.CHUNK_ACK) return fail("unexpected 0x" + a[0].toString(16));
              at += piece.length;
              progress(at, data.length);
              return chunk();
            });
          };
          var done = function () {
            return self.recvFrame().then(function (d) {
              if (!d) return fail("timeout");
              inSession = false;
              if (d[0] === PM.ERROR) return fail(text(d[1]));
              if (d[0] !== PM.DONE_ACK || d[1].length < 5 || d[1][0] !== PM.OK) return fail("status");
              var remote = ((d[1][1] << 24) | (d[1][2] << 16) | (d[1][3] << 8) | d[1][4]) >>> 0;
              var local = crc32(data);
              if (remote !== local) return fail("crc");
              return { ok: true, crc: local };
            });
          };
          return chunk();
        });
      })
      .then(function (result) {
        // the session is over: what came after its last frame is terminal
        // output again: "[PicoModem] write <path>" 200 ms later, then the
        // prompt - the shell drops what was typed before it (editor.rb
        // 286-290: raw_takeover empties the line read), so wait for both
        var rest = self.capture;
        self.capture = null;
        if (rest && rest.length) self.bytes(new Uint8Array(rest));
        return self.waitFor(function () { return notes() > before && self.atPrompt(); }, 2000)
          .then(function () { return result; });
      }, function (e) {
        self.capture = null;
        return { ok: false, error: String(e && e.message || e) };
      });
  };
  // the plan for a cell: its tabs to /lib, the code to /home/<name>, starting
  // with a statement that forgets the tabs' earlier loads, so a re-sent driver
  // is read anew by require (the simulator does the same per run). It goes in
  // front of the first line, not on a line of its own, so R2P2's error line
  // numbers are the editor's.
  function cellFiles(code, tabs, asApp) {
    var files = (tabs || []).map(function (tab) { return { path: "/lib/" + tab.name, text: String(tab.code) }; });
    var main = asApp ? "/home/app.rb" : "/home/chunky.rb";
    var forget = files.map(function (f) { return JSON.stringify(f.path); });
    // show_irb is this page's IRB under a cell; R2P2's own is the irb
    // command at its prompt (the line stays, so the line numbers do too)
    var body = String(code).replace(/^([ \t]*)show_irb[ \t]*$/mg, "$1# show_irb: on R2P2, type irb at the $> prompt");
    // (=begin must start its line: then the statement gets one of its own)
    var head = !forget.length ? "" : "[" + forget.join(", ") + "].each { |f| $LOADED_FEATURES.delete(f) }" + (/^=begin/.test(body) ? "\n" : "; ");
    files.push({ path: main, text: head + body, main: true });
    return files;
  }
  // a cell to the Pico: back to the prompt, every file, then its path typed
  Link.prototype.sendCell = function (code, tabs, asApp, report) {
    var self = this;
    report = report || function () {};
    if (this.busy) return Promise.resolve({ ok: false, error: "busy" });
    this.busy = true;
    var files = cellFiles(code, tabs, asApp);
    var finish = function (r) { self.busy = false; return r; };
    report("prompt");
    return this.toPrompt().then(function (ok) {
      if (!ok) return finish({ ok: false, error: "noPrompt" });
      var i = 0;
      var nextFile = function () {
        if (i >= files.length) {
          var main = files[files.length - 1].path;
          report("run", main);
          return self.raw(utf8(main + "\r")).then(function () { return finish({ ok: true, files: files.map(function (f) { return f.path; }) }); });
        }
        var f = files[i++];
        var bytes = utf8(f.text);
        report("put", f.path, bytes.length);
        return self.putFile(f.path, bytes).then(function (r) {
          if (!r.ok) return finish({ ok: false, error: r.error, path: f.path });
          report("putOk", f.path, bytes.length);
          return nextFile();
        });
      };
      return nextFile();
    }, function (e) { return finish({ ok: false, error: String(e) }); });
  };
  Link.prototype.close = function () {
    this.closed = true;
    var self = this;
    this.wake();
    try { this.reader.cancel().catch(function () {}); } catch (e) { /* gone */ }
    try { this.reader.releaseLock(); } catch (e) { /* still reading */ }
    try { this.writer.releaseLock(); } catch (e) { /* pending */ }
    return Promise.resolve(this.port.close ? this.port.close() : null).catch(function () {}).then(function () { self.onChange("gone"); });
  };

  // ---------- BleLink: the Nordic UART Service of a real Pico 2 W ----------
  function BleLink(device, rx, tx, onLine, onGone) {
    var self = this;
    this.device = device;
    this.name = device.name || "Pico";
    this.rx = rx;
    this.tx = tx;
    this.buffer = "";
    this.decoder = new TextDecoder("utf-8");
    this.out = Promise.resolve();
    this.connected = true;
    this.onLine = onLine;
    tx.addEventListener("characteristicvaluechanged", function (e) {
      var v = e.target.value;
      self.data(new Uint8Array(v.buffer, v.byteOffset, v.byteLength));
    });
    this.closing = false;
    // a disconnect we asked for (close) is not "the Pico went away"
    device.addEventListener("gattserverdisconnected", function () {
      self.connected = false;
      if (!self.closing) onGone(self);
    });
  }
  // notifications come in pieces of up to 20 bytes: whole lines go on
  BleLink.prototype.data = function (u8) {
    this.buffer += this.decoder.decode(u8, { stream: true });
    var at;
    while ((at = this.buffer.indexOf("\n")) >= 0) {
      var line = this.buffer.slice(0, at + 1);
      this.buffer = this.buffer.slice(at + 1);
      this.onLine(line);
    }
  };
  // a line to the Pico's RX, in pieces it takes before any MTU exchange
  BleLink.prototype.write = function (text) {
    var bytes = utf8(/\n$/.test(text) ? text : text + "\n");
    var rx = this.rx, self = this;
    this.out = this.out.then(function () {
      var at = 0;
      var more = function () {
        if (!self.connected || at >= bytes.length) return null;
        var piece = bytes.slice(at, at + BLE_CHUNK);
        at += BLE_CHUNK;
        var w = rx.writeValueWithoutResponse ? rx.writeValueWithoutResponse(piece) : rx.writeValue(piece);
        return Promise.resolve(w).then(more);
      };
      return more();
    }).catch(function () {});
    return this.out;
  };
  BleLink.prototype.close = function () {
    this.closing = true;
    this.connected = false;
    try { if (this.device.gatt && this.device.gatt.connected) this.device.gatt.disconnect(); } catch (e) { /* gone */ }
  };
  function connectBle(bluetooth, onLine, onGone) {
    var device;
    return bluetooth.requestDevice({ filters: [{ services: [NUS] }], optionalServices: [NUS] })
      .then(function (d) { device = d; return d.gatt.connect(); })
      .then(function (server) { return server.getPrimaryService(NUS); })
      .then(function (svc) { return Promise.all([svc.getCharacteristic(NUS_RX), svc.getCharacteristic(NUS_TX)]); })
      .then(function (ch) {
        var link = new BleLink(device, ch[0], ch[1], onLine, onGone);
        return ch[1].startNotifications().then(function () { return link; }, function (e) { link.close(); throw e; });
      })
      .catch(function (e) {
        // connected but the service, a characteristic or notify failed: hang up
        try { if (device && device.gatt && device.gatt.connected) device.gatt.disconnect(); } catch (x) { /* gone */ }
        throw e;
      });
  }

  // English, for a bench without the course strings
  var EN = {
    boardRealUsb: "A real Pico (USB)",
    boardRealIntro: "Plug in a Pico with R2P2 and connect it: then this cell's tabs go to /lib, its code to /home/chunky.rb, and it runs there; the terminal below is R2P2's shell. The browser asks which device – the page talks to that one only. Not yet tried on real hardware.",
    boardRealConnect: "Connect a real Pico…",
    boardRealAll: "list every serial port",
    boardRealSend: "Send this cell to the Pico and run it",
    boardRealCtrlC: "Ctrl-C",
    boardRealClose: "Disconnect",
    boardRealAsApp: "as /home/app.rb (runs at power-up)",
    boardRealTerm: "R2P2's terminal",
    boardRealType: "Type",
    boardRealChoose: "Choose the device in the browser's list…",
    boardRealOn: "Connected (%1).",
    boardRealNone: "No device chosen.",
    boardRealFail: "Could not connect: %1",
    boardRealOff: "Not connected.",
    boardRealGone: "The connection is gone (unplugged?).",
    boardRealPrompt: "Waiting for R2P2's prompt $> …",
    boardRealPut: "Writing %1 (%2 bytes)…",
    boardRealPutOk: "%1 written and checked (CRC-32).",
    boardRealRun: "%1 runs on the Pico. Ctrl-C stops it.",
    boardRealNoPrompt: "R2P2's prompt $> did not come. Is R2P2 on the Pico, and is this its first serial port? Try Ctrl-C, or unplug it and connect again.",
    boardRealBusy: "Still sending – a moment.",
    boardRealPutFail: "Writing %1 failed: %2",
    boardRealNoAck: "the shell did not answer Ctrl-B (PicoModem is in R2P2 4.0.3; the shell has to be at its $> prompt)",
    boardRealCrc: "the CRC-32 does not match – send it again",
    boardRealTimeout: "the Pico did not answer for 5 seconds",
    boardRealNoSecure: "A real Pico needs a secure page, and this one is plain http. Open the course on https://chunkybacon.idogawa.com or on localhost.",
    boardRealNoSerial: "This browser has no Web Serial: Chrome, Edge and Opera on a computer have it; Firefox, Safari and phones do not. The simulated bench works everywhere.",
    boardRealNoBle: "This browser has no Web Bluetooth: Chrome and Edge on Windows, macOS, ChromeOS and Android have it (on Linux it may have to be switched on in chrome://flags); Firefox and Safari do not.",
    boardRealBle: "A real Pico 2 W (Bluetooth)",
    boardRealBleIntro: "Start a BLE::UART program on a Pico 2 W with R2P2-PICORUBY (like the cells here), then connect: the laptop's lines go to it, and its lines show on the laptop and reach the CRuby cell. The browser lists only devices with the Nordic UART Service, and the page talks to the one you pick. Not yet tried on real hardware.",
    boardRealBleConnect: "Connect a real Pico 2 W…",
    boardRealBleOn: "Connected to %1 over Bluetooth.",
    boardRealBleOff: "Not connected – the laptop talks to the simulated Pico.",
    boardRealBleGone: "The Pico 2 W went away.",
    boardRealTag: "real"
  };

  var lib = { STX: STX, ACK: ACK, PM: PM, NUS: NUS, NUS_RX: NUS_RX, NUS_TX: NUS_TX, R2P2_VENDOR: R2P2_VENDOR,
              crc16: crc16, crc32: crc32, frame: frame, utf8: utf8, Term: Term, Link: Link, cellFiles: cellFiles,
              BleLink: BleLink, connectBle: connectBle, EN: EN };
  if (typeof module === "object" && module.exports) { module.exports = lib; return; }
  if (!root || !root.document) return;

  // ---------- the page ----------

  var doc = root.document;
  var serial = { link: null, status: "", statusKey: "", port: null, opening: false, panels: [], files: [], gen: 0 };
  var ble = { link: null, status: "", panels: [], opening: false };
  var drawPending = 0;

  function support(api) {
    if (!root.isSecureContext) return { ok: false, why: "insecure" };
    if (!(api in root.navigator)) return { ok: false, why: "api" };
    return { ok: true, why: "" };
  }

  function el(tag, cls, text) {
    var e = doc.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }

  function fill(text, a, b) { return String(text).replace("%1", a === undefined ? "" : a).replace("%2", b === undefined ? "" : b); }

  // the panels of benches still there (pico_board.js's drop marks a bench
  // dead; a new one is not in the page yet while it is built)
  function live(list) {
    for (var i = list.length - 1; i >= 0; i--) if (list[i].bench.dead) list.splice(i, 1);
    return list;
  }

  function redraw() {
    if (drawPending) return;
    drawPending = requestAnimationFrame(function () {
      drawPending = 0;
      live(serial.panels).forEach(drawSerial);
      live(ble.panels).forEach(drawBle);
    });
  }

  function setStatus(key, a, b) {
    serial.statusKey = key;
    serial.statusArgs = [a, b];
    redraw();
  }

  function onSerialChange(what) {
    if (what === "gone" && serial.link && serial.link.closed) {
      serial.link = null;
      serial.port = null;
      setStatus("boardRealGone");
    }
    redraw();
  }

  function openSerial(all) {
    if (serial.opening || serial.link) return;
    serial.opening = true;
    setStatus("boardRealChoose");
    var opts = all ? {} : { filters: [{ usbVendorId: R2P2_VENDOR }] };
    root.navigator.serial.requestPort(opts).then(function (port) {
      return port.open({ baudRate: 115200 }).then(function () {
        serial.port = port;
        serial.link = new Link(port, onSerialChange);
        var info = port.getInfo ? port.getInfo() : {};
        serial.name = info.usbVendorId ? "USB " + info.usbVendorId.toString(16).padStart(4, "0") + ":" + (info.usbProductId || 0).toString(16).padStart(4, "0") : "USB";
        setStatus("boardRealOn", serial.name);
        // a terminal is there now: Ctrl-C shows the prompt
        serial.link.raw(new Uint8Array([3]));
      });
    }).catch(function (e) {
      setStatus(e && e.name === "NotFoundError" ? "boardRealNone" : "boardRealFail", e && e.message ? e.message : String(e));
    }).then(function () { serial.opening = false; redraw(); });
  }

  function closeSerial() {
    var link = serial.link;
    serial.link = null;
    serial.port = null;
    if (link) link.close();
    setStatus("boardRealOff");
  }

  function sendCell(panel) {
    var link = serial.link;
    if (!link || link.busy) return;
    var idx = panel.bench.idx;
    var code = root.getCellCode ? root.getCellCode(idx) : "";
    var tabs = [];
    try { tabs = JSON.parse(root.getCellTabs ? root.getCellTabs(idx) : "[]"); } catch (e) { tabs = []; }
    var asApp = panel.asApp.checked;
    link.sendCell(code, tabs, asApp, function (what, path, n) {
      if (what === "prompt") setStatus("boardRealPrompt");
      else if (what === "put") setStatus("boardRealPut", path, n);
      else if (what === "putOk") setStatus("boardRealPutOk", path);
      else if (what === "run") setStatus("boardRealRun", path);
    }).then(function (r) {
      serial.files = r.files || [];
      if (r.ok) return;
      if (r.error === "noPrompt") setStatus("boardRealNoPrompt");
      else if (r.error === "busy") setStatus("boardRealBusy");
      else {
        var why = { noAck: "boardRealNoAck", crc: "boardRealCrc", timeout: "boardRealTimeout" }[r.error];
        setStatus("boardRealPutFail", r.path || "", why ? panel.t(why) : r.error);
      }
      redraw();
    });
  }

  function noteFor(why, t, ble) {
    if (why === "insecure") return t("boardRealNoSecure");
    return t(ble ? "boardRealNoBle" : "boardRealNoSerial");
  }

  function serialPanel(figure, bench, t) {
    var sup = support("serial");
    var details = el("details", "pico-real pico-real-usb");
    var summary = el("summary", null, "🔌 " + t("boardRealUsb"));
    details.appendChild(summary);
    var p = { root: details, bench: bench, t: t, sup: sup };
    details.appendChild(el("p", "pico-real-intro", t("boardRealIntro")));
    if (!sup.ok) {
      var note = el("p", "pico-real-note", noteFor(sup.why, t, false));
      note.setAttribute("data-why", sup.why);
      details.appendChild(note);
      p.note = note;
      figure.appendChild(details);
      return p;
    }
    var row = el("div", "pico-row pico-real-buttons");
    p.connect = el("button", "pico-real-connect", t("boardRealConnect"));
    p.connect.type = "button";
    p.connect.addEventListener("click", function () { openSerial(p.all.checked); });
    var allLab = el("label", "pico-check");
    p.all = el("input");
    p.all.type = "checkbox";
    allLab.appendChild(p.all);
    allLab.appendChild(doc.createTextNode(" " + t("boardRealAll")));
    p.send = el("button", "pico-real-send", "▶ " + t("boardRealSend"));
    p.send.type = "button";
    p.send.addEventListener("click", function () { sendCell(p); });
    p.stop = el("button", "pico-real-ctrlc", t("boardRealCtrlC"));
    p.stop.type = "button";
    // not while a PicoModem frame is on the wire: a byte in it breaks the CRC
    p.stop.addEventListener("click", function () { if (serial.link && !serial.link.busy && !serial.link.capture) serial.link.raw(new Uint8Array([3])); });
    p.close = el("button", "pico-real-close", t("boardRealClose"));
    p.close.type = "button";
    p.close.addEventListener("click", closeSerial);
    var appLab = el("label", "pico-check");
    p.asApp = el("input");
    p.asApp.type = "checkbox";
    appLab.appendChild(p.asApp);
    appLab.appendChild(doc.createTextNode(" " + t("boardRealAsApp")));
    [p.connect, allLab, p.send, p.stop, p.close, appLab].forEach(function (n) { row.appendChild(n); });
    p.allLab = allLab;
    p.appLab = appLab;
    details.appendChild(row);
    p.status = el("p", "pico-real-status");
    p.status.setAttribute("role", "status");
    details.appendChild(p.status);
    p.screen = el("pre", "pico-real-term");
    p.screen.setAttribute("aria-label", t("boardRealTerm"));
    p.screen.tabIndex = 0;
    details.appendChild(p.screen);
    var form = el("form", "pico-row pico-real-type");
    var lab = el("label", "pico-line");
    lab.appendChild(el("span", "pico-slider-name", t("boardRealType")));
    p.line = el("input");
    p.line.type = "text";
    p.line.autocomplete = "off";
    p.line.spellcheck = false;
    lab.appendChild(p.line);
    var go = el("button", "pico-send", t("boardSend"));
    go.type = "submit";
    form.appendChild(lab);
    form.appendChild(go);
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (!serial.link || serial.link.busy || serial.link.capture) return;
      serial.link.send(p.line.value + "\r");
      p.line.value = "";
    });
    p.form = form;
    p.go = go;
    details.appendChild(form);
    details.addEventListener("toggle", redraw);
    figure.appendChild(details);
    drawSerial(p);
    return p;
  }

  function drawSerial(p) {
    if (!p.sup.ok) return;
    var on = !!serial.link, busy = on && serial.link.busy;
    p.connect.hidden = on;
    p.connect.disabled = serial.opening;
    p.allLab.hidden = on;
    p.send.hidden = p.stop.hidden = p.close.hidden = p.appLab.hidden = !on;
    p.send.disabled = p.stop.disabled = p.line.disabled = p.go.disabled = busy;
    p.form.hidden = !on;
    p.screen.hidden = !on;
    var key = serial.statusKey || "boardRealOff";
    var args = serial.statusArgs || [];
    var said = fill(p.t(key), args[0], args[1]);
    if (p.status.textContent !== said) p.status.textContent = said;
    if (on && p.root.open) {
      var text = serial.link.term.text();
      if (p.screen.textContent !== text) {
        var bottom = p.screen.scrollHeight - p.screen.scrollTop - p.screen.clientHeight < 8;
        p.screen.textContent = text;
        if (bottom) p.screen.scrollTop = p.screen.scrollHeight;
      }
    }
  }

  // ---------- Bluetooth (lesson pico-ble: the bench's laptop) ----------

  function bleLine(line) {
    if (root.chunkyPicoBoard && root.chunkyPicoBoard.realBle) root.chunkyPicoBoard.realBle(line);
    redraw();
  }

  function openBle() {
    if (ble.opening || ble.link) return;
    ble.opening = true;
    ble.status = "boardRealChoose";
    redraw();
    connectBle(root.navigator.bluetooth, bleLine, function (gone) {
      // a late event of an older link must not clear a newer one
      if (ble.link !== gone) return;
      ble.link = null;
      ble.status = "boardRealBleGone";
      if (root.chunkyPicoBoard && root.chunkyPicoBoard.realBle) root.chunkyPicoBoard.realBle(null);
      redraw();
    }).then(function (link) {
      ble.link = link;
      ble.status = "boardRealBleOn";
      if (root.chunkyPicoBoard && root.chunkyPicoBoard.realBle) root.chunkyPicoBoard.realBle(null);
    }).catch(function (e) {
      ble.status = e && e.name === "NotFoundError" ? "boardRealNone" : "boardRealFail";
      ble.error = e && e.message ? e.message : String(e);
    }).then(function () { ble.opening = false; redraw(); });
  }

  function closeBle() {
    var link = ble.link;
    ble.link = null;
    ble.status = "boardRealBleOff";
    if (link) link.close();
    if (root.chunkyPicoBoard && root.chunkyPicoBoard.realBle) root.chunkyPicoBoard.realBle(null);
    redraw();
  }

  function blePanel(figure, bench, t) {
    var sup = support("bluetooth");
    var details = el("details", "pico-real pico-real-ble");
    details.appendChild(el("summary", null, "📶 " + t("boardRealBle")));
    details.appendChild(el("p", "pico-real-intro", t("boardRealBleIntro")));
    var p = { root: details, bench: bench, t: t, sup: sup };
    if (!sup.ok) {
      var note = el("p", "pico-real-note", noteFor(sup.why, t, true));
      note.setAttribute("data-why", sup.why);
      details.appendChild(note);
      p.note = note;
      figure.appendChild(details);
      return p;
    }
    var row = el("div", "pico-row pico-real-buttons");
    p.connect = el("button", "pico-real-connect", t("boardRealBleConnect"));
    p.connect.type = "button";
    p.connect.addEventListener("click", openBle);
    p.close = el("button", "pico-real-close", t("boardRealClose"));
    p.close.type = "button";
    p.close.addEventListener("click", closeBle);
    row.appendChild(p.connect);
    row.appendChild(p.close);
    details.appendChild(row);
    p.status = el("p", "pico-real-status");
    p.status.setAttribute("role", "status");
    details.appendChild(p.status);
    figure.appendChild(details);
    drawBle(p);
    return p;
  }

  function drawBle(p) {
    if (!p.sup.ok) return;
    var on = !!ble.link;
    p.connect.hidden = on;
    p.connect.disabled = ble.opening;
    p.close.hidden = !on;
    var key = ble.status || "boardRealBleOff";
    var said = fill(p.t(key), on ? ble.link.name : ble.error || "");
    if (p.status.textContent !== said) p.status.textContent = said;
  }

  root.chunkyPicoReal = {
    lib: lib,
    serialSupport: function () { return support("serial"); },
    bleSupport: function () { return support("bluetooth"); },
    // a bench was built (pico_board.js): its panels, inside the figure
    attach: function (figure, bench, t0) {
      var t = function (key) { var v = t0 ? t0(key) : key; return v === key && EN[key] ? EN[key] : v; };
      serial.panels.push(serialPanel(figure, bench, t));
      if (bench.parts.indexOf("laptop") >= 0) ble.panels.push(blePanel(figure, bench, t));
      live(serial.panels);
      live(ble.panels);
    },
    ble: function () { return ble.link && ble.link.connected ? { name: ble.link.name } : null; },
    bleWrite: function (text) { if (ble.link) ble.link.write(String(text)); },
    state: function () {
      return {
        serial: { on: !!serial.link, busy: !!(serial.link && serial.link.busy), status: serial.statusKey || "",
                  term: serial.link ? serial.link.term.text() : "", files: serial.files.slice(),
                  panels: live(serial.panels).length },
        ble: { on: !!ble.link, name: ble.link ? ble.link.name : "", status: ble.status || "", panels: live(ble.panels).length }
      };
    }
  };

  if (root.navigator.serial && root.navigator.serial.addEventListener) {
    root.navigator.serial.addEventListener("disconnect", function (e) {
      if (serial.port && (e.target === serial.port || e.port === serial.port)) {
        var link = serial.link;
        serial.link = null;
        serial.port = null;
        if (link) link.close();
        setStatus("boardRealGone");
      }
    });
  }
})(typeof window !== "undefined" ? window : this);
