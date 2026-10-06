// Runs one program Spinel built (spinel.js starts a worker per run and
// stops it when the time is up: an endless loop cannot be interrupted any
// other way). What the program prints arrives as it is printed.
//
//   -> { wasm, stdin }   <- { type: "out", fd, text } ..., { type: "done", code, stderr, ms } | { type: "crashed", error }
import { runProgram } from './spinel-build.js';

self.onmessage = ({ data }) => {
  const decoder = { 1: new TextDecoder(), 2: new TextDecoder() };
  const send = (fd) => (bytes) => self.postMessage({ type: 'out', fd, text: decoder[fd].decode(bytes, { stream: true }) });
  try {
    const stdin = new TextEncoder().encode(data.stdin || '');
    const result = runProgram(new Uint8Array(data.wasm), { stdin, stdout: send(1), stderr: send(2) });
    self.postMessage({ type: 'done', code: result.code, ms: result.ms });
  } catch (error) {
    // a trap: out of memory, the stack, unreachable code
    self.postMessage({ type: 'crashed', error: String((error && error.message) || error) });
  }
};
