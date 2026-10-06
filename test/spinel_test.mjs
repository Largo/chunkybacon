// The Spinel lesson's toolchain under Node, without a browser: the page's
// own modules (html/spinel-build.js, spinel-wasi.js) on the build in
// html/assets/spinel/ (node tools/build_spinel.mjs first).
//
//   node --experimental-wasm-exnref spinel_test.mjs
//
// (The programs Spinel builds raise with WebAssembly's exception handling,
// which Node 22 has behind that flag; Chrome, Firefox and Safari have it on.)
import { readFileSync, existsSync } from 'node:fs';
import { SpinelToolchain, SpinelIrb, runProgram, parseBuild, clangArgs } from '../html/spinel-build.js';

const ASSETS = new URL('../html/assets/spinel/', import.meta.url);
if (!existsSync(new URL('manifest.json', ASSETS))) {
  console.log('SKIP html/assets/spinel/ is not built: node tools/build_spinel.mjs');
  process.exit(0);
}

let failures = 0;
const check = (name, cond, detail = '') => {
  console.log(`${cond ? 'PASS' : 'FAIL'} ${name}${detail && !cond ? ' - ' + detail : ''}`);
  if (!cond) failures++;
};

// fetch on file: URLs, as the page fetches over http
const fileFetch = async (url) => new Response(readFileSync(url), { status: 200 });

const started = performance.now();
const spinel = await new SpinelToolchain(ASSETS, fileFetch).load();
console.log(`loaded in ${((performance.now() - started) / 1000).toFixed(1)} s, spinel ${spinel.version}`);

const run = async (source) => {
  const built = await spinel.build(source);
  if (!built.ok) return { built };
  return { built, ran: runProgram(built.wasm) };
};

// --print-build's lines, and the command line made of them
{
  const build = parseBuild('cflag -O2\ninclude /spinel/bin/../lib\nsource /work/main.c\nruntime /spinel/bin/../lib/wasm32-wasi/libspinel_rt.a\nlib -lm\n');
  check('print-build: paths without ..', build.include[0] === '/spinel/lib' && build.runtime === '/spinel/lib/wasm32-wasi/libspinel_rt.a');
  const args = clangArgs(build, '/work/main.wasm');
  check('clang: source before the archive, libraries after', args.indexOf('/work/main.c') < args.indexOf(build.runtime) && args.indexOf(build.runtime) < args.indexOf('-lm'));
}

// a program, compiled and run
{
  const { built, ran } = await run('def fib(n)\n  n < 2 ? n : fib(n - 1) + fib(n - 2)\nend\nputs fib(25)\np [1, 2, 3].map { |x| x * 2 }\n');
  check('fib: builds', built.ok, built.messages);
  check('fib: the C is C', /int main\s*\(/.test(built.c ?? ''), (built.c ?? '').slice(0, 200));
  check('fib: runs', ran && ran.code === 0 && ran.stdout === '75025\n[2, 4, 6]\n', JSON.stringify(ran));
  console.log(`  spinel ${built.ms.spinel.toFixed(0)} ms, clang ${built.ms.clang.toFixed(0)} ms, run ${ran.ms.toFixed(1)} ms, ${built.wasm.length} bytes`);
}

// classes, strings, hashes, blocks, an exception rescued
{
  const source = `class Fox
  attr_reader :name
  def initialize(name) = @name = name
  def greet = "Hallo, #{name}!"
end
foxes = %w[Chunky Bacon].map { |n| Fox.new(n) }
puts foxes.map(&:greet).join(" ")
count = Hash.new(0)
"chunky bacon".each_char { |c| count[c] += 1 }
p count.max_by { |_, v| v }
begin
  Integer("zwölf")
rescue ArgumentError => e
  puts "rescued: #{e.class}"
end
`;
  const { built, ran } = await run(source);
  check('objects: build', built.ok, built.messages);
  check('objects: run as CRuby would', ran && ran.stdout === 'Hallo, Chunky! Hallo, Bacon!\n["c", 2]\nrescued: ArgumentError\n', JSON.stringify(ran && ran.stdout));
}

// what an AOT compiler cannot do: refused at compile time, with the line
{
  const { built } = await run('code = "1 + 2"\nputs eval(code)\n');
  check('eval: refused', !built.ok && built.stage === 'spinel', JSON.stringify(built));
  check('eval: the message names the line', /main\.rb:2/.test(built.messages), built.messages);
}

// an exception nobody rescues: the program says so and fails
{
  const { built, ran } = await run('puts "before"\nraise ArgumentError, "kaputt"\n');
  check('raise: builds', built.ok, built.messages);
  check('raise: fails at run time', ran.code !== 0 && ran.stdout === 'before\n' && /kaputt/.test(ran.stderr), JSON.stringify(ran));
}

// Integer is 32 bits on wasm32 (docs/wasm.md): past it, RangeError
{
  const { built, ran } = await run('x = 2_000_000_000\nbegin\n  p x + x\nrescue RangeError => e\n  puts "RangeError"\nend\np 2**20\n');
  check('int32: builds', built.ok, built.messages);
  check('int32: overflow raises', ran && ran.stdout === 'RangeError\n1048576\n', JSON.stringify(ran && ran.stdout));
}

// IRB: each line compiled with the ones before it
{
  const irb = new SpinelIrb(spinel);
  const go = (line) => irb.submit(line, async (wasm) => runProgram(wasm));
  let r = await go('x = 6 * 7');
  check('irb: a value', r.ok && r.value === '42' && r.output === '', JSON.stringify(r));
  r = await go('puts "x ist #{x}"');
  check('irb: what a line prints, once', r.ok && r.output === 'x ist 42\n' && r.value === 'nil', JSON.stringify(r));
  r = await go('def double(n) = n * 2');
  check('irb: a method says its name', r.ok && r.value === ':double', JSON.stringify(r));
  r = await go('double(x)');
  check('irb: the earlier lines are there', r.ok && r.value === '84' && r.output === '', JSON.stringify(r));
  r = await go('eval("x")');
  check('irb: a refusal', !r.ok && r.stage === 'spinel' && /\(irb\):1/.test(r.messages), JSON.stringify(r));
  r = await go('[x, double(x)].sum');
  check('irb: a refused line is not kept', r.ok && r.value === '126' && irb.lines.length === 5, JSON.stringify(r));
  r = await go('raise "nein"');
  check('irb: an exception', !r.ok && r.stage === 'run' && /nein/.test(r.messages), JSON.stringify(r));
  check('irb: a failed line is not kept', irb.lines.length === 5);
}

console.log(failures ? `${failures} FAILED` : 'all passed');
process.exit(failures ? 1 : 0);
