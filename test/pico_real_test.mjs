// html/pico_real.js without a browser (docs/HANDOVER.md §6r, a real Pico):
//
//   node test/pico_real_test.mjs
//
// - the checksums against their catalogue check values, frames against
//   PicoModem's layout;
// - Term, the terminal R2P2's line editor needs: LF, CR, backspace, the
//   cursor moves and erases the editor prints, the answers to its cursor
//   and status queries, the wrap at 80 columns, scrolling;
// - Link against test/pico_real_fakes.js's FakeR2P2: back to the prompt
//   from a running program and from irb, a cell's tabs and code written
//   with PicoModem in 32-byte writes, its path typed to run it, a device
//   that refuses a file, a CRC-32 that does not match, no R2P2 at all;
// - Link against PicoModem's own device code (test/vendor/picomodem.rb,
//   picoruby 4.0.3, run by test/pico_real_device.rb under CRuby): a file
//   of several chunks with UTF-8 arrives byte for byte;
// - BleLink against FakeBluetooth: the Nordic UART Service asked for,
//   20-byte writes, notifications put together into lines.
import { createRequire } from "module";
import { spawn } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import crypto from "crypto";

const require = createRequire(import.meta.url);
const here = path.dirname(new URL(import.meta.url).pathname);
const lib = require(path.join(here, "../html/pico_real.js"));
const fakes = require(path.join(here, "pico_real_fakes.js"));

let passes = 0, failures = 0;
const check = (name, cond, extra = "") => {
  console.log(`${cond ? "PASS" : "FAIL"} ${name}${!cond && extra !== "" ? ` - ${String(extra).slice(0, 400)}` : ""}`);
  if (cond) passes++; else failures++;
};
const bytes = s => new TextEncoder().encode(s);

// ---------- the strings ----------
{
  globalThis.window = {};
  require(path.join(here, "../html/lessons.js"));
  const ui = JSON.parse(globalThis.window.LESSONS_JSON).ui;
  delete globalThis.window;
  const src = fs.readFileSync(path.join(here, "../html/pico_real.js"), "utf8");
  const used = [...new Set([...src.matchAll(/"(boardReal\w+)"/g)].map(m => m[1]))];
  for (const lang of ["de", "en", "ja"]) {
    const missing = used.filter(k => !ui[lang][k]);
    check(`strings: every boardReal* key the panels use is in ui.${lang}`, used.length > 30 && missing.length === 0, missing.join());
  }
  const stale = Object.keys(lib.EN).filter(k => lib.EN[k] !== ui.en[k]);
  check("strings: pico_real.js's English fallback is ui.en's", stale.length === 0 && used.every(k => k in lib.EN), stale.join());
}

// ---------- checksums and frames ----------
check("crc16 CCITT-FALSE check value", lib.crc16(bytes("123456789")) === 0x29B1, lib.crc16(bytes("123456789")).toString(16));
check("crc32 zlib check value", lib.crc32(bytes("123456789")) === 0xCBF43926, lib.crc32(bytes("123456789")).toString(16));
check("crc32 of nothing", lib.crc32(new Uint8Array(0)) === 0);
check("crc32 runs on (incremental, as picoruby-crc)", lib.crc32(bytes("6789"), lib.crc32(bytes("12345"))) === 0xCBF43926);
{
  const f = lib.frame(0x84, new Uint8Array([0]));
  check("frame: STX, length of cmd+payload, cmd, payload, CRC-16", f.length === 7 && f[0] === 2 && f[1] === 0 && f[2] === 2 && f[3] === 0x84 && f[4] === 0);
  const crc = lib.crc16(new Uint8Array([0x84, 0]));
  check("frame: CRC big-endian at the end", f[5] === crc >> 8 && f[6] === (crc & 255));
  check("frame equals the fake device's", Buffer.from(f).equals(Buffer.from(fakes.frame(0x84, [0]))));
  const big = lib.frame(4, new Uint8Array(480));
  check("a full chunk's frame is 486 bytes, length 481", big.length === 486 && big[1] === 1 && big[2] === 0xE1);
}

// ---------- Term ----------
{
  const t = new lib.Term(24, 80);
  t.write("hello\nworld");
  check("Term: LF is a new line (convertEol)", t.text() === "hello\nworld", JSON.stringify(t.text()));
  t.write("\r\x1b[0K$> ");
  check("Term: CR + erase line", t.cursorLine() === "$>", JSON.stringify(t.cursorLine()));
  t.write("abc\b\bX");
  check("Term: backspace moves left", t.cursorLine() === "$> aXc");
  check("Term: cursor position report", t.write("\x1b[6n") === "\x1b[2;6R", JSON.stringify(t.write("\x1b[6n")));
  check("Term: status report", t.write("\x1b[5n") === "\x1b[0n");
  t.write("\x1b[999B\x1b[999C");
  check("Term: 999B 999C stop at the corner (the editor's screen size)", t.write("\x1b[6n") === "\x1b[24;80R");
  t.write("\x1b[2;1H");
  check("Term: CUP", t.write("\x1b[6n") === "\x1b[2;1R");
  t.write("\x1b[?25l\x1b[1G$> ls\x1b[0K\x1b[0J\x1b[?25h");
  check("Term: the editor's redraw sequence", t.cursorLine() === "$> ls", JSON.stringify(t.cursorLine()));
  t.write("\x1b[1F");
  check("Term: CPL to the line above", t.cursorLine() === "hello");
  t.write("\x1b[1E\x1b[3C\x1b[1D\x1b[K");
  check("Term: CNL, CUF, CUB, EL", t.cursorLine() === "$>");
  t.write("\x1b[31mred\x1b[0m");
  check("Term: colours ignored", t.cursorLine() === "$>red", JSON.stringify(t.cursorLine()));
  check("Term: an OSC title is skipped", (t.write("\x1b]0;R2P2\x07!"), t.cursorLine() === "$>red!"), JSON.stringify(t.cursorLine()));

  const w = new lib.Term(3, 10);
  w.write("0123456789AB");
  check("Term: wraps at the last column", w.text() === "0123456789\nAB", JSON.stringify(w.text()));
  w.write("\n1\n2\n3");
  check("Term: lines scrolled off the top stay above", w.text() === "0123456789\nAB\n1\n2\n3", JSON.stringify(w.text()));
  check("Term: the screen itself keeps the last rows", w.screen.map(r => r.join("").trim()).join("|") === "1|2|3");
  const u = new lib.Term(4, 20);
  const smile = bytes("° ✓ 日本");
  u.write(smile.subarray(0, 3));
  u.write(smile.subarray(3));
  check("Term: UTF-8 split across reads", u.cursorLine() === "° ✓ 日本", JSON.stringify(u.cursorLine()));
  u.write("\x1b[2J");
  check("Term: ED 2 clears the screen", u.screen.every(r => r.join("").trim() === ""));
  const j = new lib.Term(4, 10);
  j.write("$> 日本a");
  check("Term: a wide character takes two columns (the cursor report too)", j.cursorLine() === "$> 日本a" && j.write("\x1b[6n") === "\x1b[1;9R", JSON.stringify([j.cursorLine(), j.write("\x1b[6n")]));
  j.write("\r\n123456789日");
  check("Term: a wide character that does not fit in the last column wraps whole", j.text().split("\n").slice(-2).join("|") === "123456789|日", JSON.stringify(j.text()));
  j.write("\r\n🎉x");
  check("Term: an emoji outside the BMP is one character, two columns", j.cursorLine() === "🎉x" && j.write("\x1b[6n") === "\x1b[4;4R", JSON.stringify([j.cursorLine(), j.write("\x1b[6n")]));
}

{
  const files = lib.cellFiles('require "gpio"\nled = GPIO.new(15, GPIO::OUT)\nshow_irb\n', [], false);
  check("cellFiles: show_irb (the page's) becomes a comment, same line", files.length === 1 && files[0].text.split("\n")[2] === "# show_irb: on R2P2, type irb at the $> prompt", JSON.stringify(files));
  const two = lib.cellFiles("x\n", [{ name: "a.rb", code: "A" }, { name: "font5x7.rb", code: "F" }], true);
  const eq = lib.cellFiles("=begin\nx\n=end\n", [{ name: "a.rb", code: "A" }], false);
  check("cellFiles: =begin on the first line keeps its column (the statement gets a line of its own)", eq[1].text.split("\n")[1] === "=begin", JSON.stringify(eq[1].text));
  check("cellFiles: tabs first, in order, the main file last", two.map(f => f.path).join() === "/lib/a.rb,/lib/font5x7.rb,/home/app.rb" && two[2].text.startsWith('["/lib/a.rb", "/lib/font5x7.rb"].each'));
}

// ---------- Link against the fake R2P2 ----------
async function fakeLink(opts) {
  const dev = new fakes.FakeR2P2(opts);
  const port = new fakes.FakeSerialPort(dev);
  await port.open({ baudRate: 115200 });
  const link = new lib.Link(port);
  return { dev, port, link };
}
const until = async (f, ms = 3000) => { const end = Date.now() + ms; while (!f() && Date.now() < end) await new Promise(r => setTimeout(r, 10)); return f(); };

{
  const { dev, link, port } = await fakeLink();
  await until(() => link.atPrompt());
  check("Link: answers the shell's terminal check (ESC[5n -> ESC[0n)", dev.replies.includes("\x1b[0n"), JSON.stringify(dev.replies));
  check("Link: answers the cursor query", /\x1b\[\d+;\d+R/.test(dev.replies));
  check("Link: sees the prompt", link.atPrompt(), link.term.cursorLine());

  // a program that runs for ever, then the cell
  dev.files["/home/old.rb"] = bytes("loop do\nend\n");
  await link.send("/home/old.rb\r");
  await until(() => dev.mode === "running");
  check("fake: the old program runs", dev.mode === "running");
  const tabs = [{ name: "blinker.rb", code: "class Blinker\n  # ° comments in UTF-8\nend\n" }];
  const code = 'require "blinker"\nputs "hello from the Pico"\n';
  const steps = [];
  const r = await link.sendCell(code, tabs, false, (what, p) => steps.push(`${what} ${p || ""}`.trim()));
  check("sendCell: ok", r.ok, JSON.stringify(r));
  check("sendCell: Ctrl-C stopped the old program", dev.runs[0] === "/home/old.rb" && dev.mode !== "running");
  check("sendCell: the tab went to /lib/blinker.rb unchanged", dev.text("/lib/blinker.rb") === tabs[0].code, dev.text("/lib/blinker.rb"));
  const main = dev.text("/home/chunky.rb") || "";
  check("sendCell: the code to /home/chunky.rb, behind a statement on its first line that forgets the tab's last load",
        main === '["/lib/blinker.rb"].each { |f| $LOADED_FEATURES.delete(f) }; ' + code, JSON.stringify(main));
  check("sendCell: the main file has as many lines as the cell (R2P2's line numbers are the editor's)",
        main.split("\n").length === code.split("\n").length);
  check("sendCell: then its path typed at the prompt (it ran)", dev.runs[dev.runs.length - 1] === "/home/chunky.rb", JSON.stringify(dev.runs));
  await until(() => link.term.text().includes("hello from the Pico"));
  check("sendCell: the program's output in the terminal", link.term.text().includes("hello from the Pico"), link.term.text().slice(-300));
  check("sendCell: the steps in order", steps.join(",") === "prompt,put /lib/blinker.rb,putOk /lib/blinker.rb,put /home/chunky.rb,putOk /home/chunky.rb,run /home/chunky.rb", steps.join(","));
  check("sendCell: the shell's notes show", link.term.text().includes("[PicoModem] write /lib/blinker.rb") && link.term.text().includes("[PicoModem] write /home/chunky.rb"));
  check("Link: no write longer than 32 bytes", Math.max(...dev.writes) <= 32, Math.max(...dev.writes));
  check("Link: no session bytes in the terminal", !/[\x02\x06]/.test(link.term.text()));

  // without tabs, as app.rb
  const r2 = await link.sendCell('puts "autostart"\n', [], true);
  check("sendCell as app.rb: /home/app.rb, no extra first line", r2.ok && dev.text("/home/app.rb") === 'puts "autostart"\n', dev.text("/home/app.rb"));

  // from irb
  await link.send("irb\r");
  await until(() => dev.mode === "irb");
  const r3 = await link.sendCell('puts "x"\n', [], false);
  check("sendCell: from irb back to the shell (Ctrl-D) first", r3.ok && dev.mode === "shell", JSON.stringify(r3) + " " + dev.mode);

  // a big file, several chunks
  const long = "# " + "chunky bacon ".repeat(200) + "\n";
  const r4 = await link.putFile("/lib/long.rb", bytes(long));
  check("putFile: 2.6 kB in 480-byte chunks", r4.ok && dev.text("/lib/long.rb") === long, JSON.stringify(r4));
  check("putFile: answers the CRC-32 it checked", r4.crc === lib.crc32(bytes(long)));

  // busy
  const p1 = link.sendCell('puts "a"\n', [], false);
  const p2 = await link.sendCell('puts "b"\n', [], false);
  check("sendCell: a second one while busy is refused", p2.ok === false && p2.error === "busy");
  await p1;

  // unplugged
  port.unplug();
  await until(() => link.closed);
  check("Link: the cable out closes it", link.closed);
  check("Link: and lets go of the port (no lock left, closed: a new Connect can open it)", !port.readable.locked && !port.writable.locked && port.closedByLink === true, JSON.stringify([port.readable.locked, port.writable.locked, port.closedByLink]));
}
{
  const { dev, link } = await fakeLink({ failPath: "/lib/x.rb" });
  await until(() => link.atPrompt());
  const r = await link.sendCell("puts 1\n", [{ name: "x.rb", code: "1\n" }], false);
  check("device ERROR: the message, the file named, nothing run", !r.ok && r.error === "No space left" && r.path === "/lib/x.rb" && dev.runs.length === 0, JSON.stringify(r));
  check("device ERROR: back at the prompt afterwards", await until(() => link.atPrompt()));
}
{
  const { dev, link } = await fakeLink({ badCrc: true });
  await until(() => link.atPrompt());
  const r = await link.putFile("/home/a.rb", bytes("puts 1\n"));
  check("a CRC-32 that does not match is an error", !r.ok && r.error === "crc", JSON.stringify(r));
}
{
  const { link } = await fakeLink({ mute: true });
  const t0 = Date.now();
  const r = await link.sendCell("puts 1\n", [], false);
  check("no R2P2 (no prompt): says so, in seconds", !r.ok && r.error === "noPrompt" && Date.now() - t0 < 9000, JSON.stringify(r) + ` ${Date.now() - t0} ms`);
}

// ---------- Link against PicoModem's own device code ----------
{
  const vendored = fs.readFileSync(path.join(here, "vendor/picomodem.rb"));
  check("test/vendor/picomodem.rb is picoruby 4.0.3's, unchanged",
        crypto.createHash("sha256").update(vendored).digest("hex") === "01d4f2fcbf19789ba4f5a5c265afb111d3ee3d4fe994a9441ea75e69c12f7d62");
  const rootDir = fs.mkdtempSync(path.join(os.tmpdir(), "picomodem-"));
  const ruby = spawn("ruby", [path.join(here, "pico_real_device.rb"), rootDir], { stdio: ["pipe", "pipe", "inherit"] });
  let ctl;
  const port = {
    readable: new ReadableStream({ start(c) { ctl = c; ruby.stdout.on("data", d => c.enqueue(new Uint8Array(d))); ruby.stdout.on("end", () => { try { c.close(); } catch (e) {} }); } }),
    writable: new WritableStream({ write(chunk) { return new Promise(ok => ruby.stdin.write(Buffer.from(chunk), ok)); } }),
    close() { ruby.stdin.end(); return Promise.resolve(); }
  };
  const link = new lib.Link(port);
  const ok = await link.waitFor(() => link.atPrompt(), 5000);
  check("real PicoModem: the stand-in shell's prompt", ok, link.term.text());
  const text = "# Grüezi – こんにちは\n" + "puts 'chunky bacon'\n".repeat(60);
  const r = await link.putFile("/lib/hello.rb", bytes(text));
  check("real PicoModem: FILE_WRITE, 3 CHUNKs, DONE_ACK with a matching CRC-32", r.ok, JSON.stringify(r));
  const got = fs.existsSync(path.join(rootDir, "lib/hello.rb")) ? fs.readFileSync(path.join(rootDir, "lib/hello.rb"), "utf8") : null;
  check("real PicoModem: the file arrived byte for byte", got === text, got && got.slice(0, 80));
  check("real PicoModem: the shell's note after the session", await link.waitFor(t => t.text().includes("[PicoModem] write /lib/hello.rb"), 2000), link.term.text().slice(-200));
  const r2 = await link.putFile("/home/empty.rb", new Uint8Array(0));
  check("real PicoModem: an empty file (no CHUNK, the size alone)", r2.ok === true && fs.readFileSync(path.join(rootDir, "home/empty.rb")).length === 0, JSON.stringify(r2));
  await link.close();
  ruby.kill();
  fs.rmSync(rootDir, { recursive: true, force: true });
}

// ---------- BleLink ----------
{
  const bt = new fakes.FakeBluetooth("ChunkyPico");
  const lines = [];
  let gone = 0;
  const link = await lib.connectBle(bt, l => lines.push(l), () => gone++);
  check("BLE: asks for the Nordic UART Service only", JSON.stringify(bt.asked) === JSON.stringify({ filters: [{ services: [lib.NUS] }], optionalServices: [lib.NUS] }), JSON.stringify(bt.asked));
  check("BLE: notifications on", bt.tx.notifying);
  check("BLE: the device's name", link.name === "ChunkyPico");
  await link.write("PING");
  check("BLE: a line gets its newline, the Pico answers", bt.got && bt.got[0] === "PING" && lines[0] === "PONG\n", JSON.stringify([bt.got, lines]));
  await link.write("SHOW " + "x".repeat(50) + "\n");
  check("BLE: writes of at most 20 bytes", Math.max(...bt.writes) <= 20 && bt.got[1] === "SHOW " + "x".repeat(50), JSON.stringify(bt.writes));
  bt.notify("T 21.5\nT 2");
  bt.notify("2.0\n");
  check("BLE: pieces become whole lines", lines[1] === "T 21.5\n" && lines[2] === "T 22.0\n", JSON.stringify(lines));
  bt.notify("Grüe");
  bt.notify("zi\n");
  check("BLE: UTF-8 across notifications", lines[3] === "Grüezi\n", JSON.stringify(lines));
  link.close();
  check("BLE: close disconnects, and it is not reported as the Pico going away", gone === 0 && !bt.device.gatt.connected, String(gone));
  const again = await lib.connectBle(bt, () => {}, l => { gone++; check("BLE: going away names its own link", l === again); });
  bt.device.gatt.disconnect();          // the Pico's side hangs up (out of range, reset)
  check("BLE: the Pico going away is reported once", gone === 1 && !again.connected, String(gone));
}
{
  const bt = new fakes.FakeBluetooth("ChunkyPico");
  bt.failNotify = true;
  let err = null;
  await lib.connectBle(bt, () => {}, () => {}).catch(e => { err = e; });
  check("BLE: a failed setup is an error and hangs up the GATT connection", err && !bt.device.gatt.connected, String(err));
}

console.log(`\n${passes} passed, ${failures} failed`);
process.exit(failures ? 1 : 0);
