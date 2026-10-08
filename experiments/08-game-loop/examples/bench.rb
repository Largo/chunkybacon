# What one JS->Ruby call costs in the page: paste into a cell, press Run.
# A JS loop calls a Ruby block n times, the way game.js calls the game.
loop_js = JS.eval(<<~JS)
  return function (n, cb) {
    var t = performance.now();
    for (var i = 0; i < n; i++) cb(i * 150, "k:up");
    return (performance.now() - t) / n;
  };
JS
n = 300
def per_call(fn, n, &block) = (fn.call(:call, nil, n, &block).to_f * 1000).round  # microseconds

game = ChunkyGame.new(width: 20, height: 15) do |g|
  s = [[5, 7], [4, 7], [3, 7]]
  d = [1, 0]
  g.every(0.15) do
    h = [(s[0][0] + d[0]) % 20, s[0][1]]
    s.unshift(h); s.pop
    g.clear
    g.cell(12, 7, :bacon)
    s.each { |x, y| g.cell(x, y, :body) }
  end
end
paths = ["chunky.rb"]
{
  "empty block, returns nil" => per_call(loop_js, n) { |_t, _e| nil },
  "block reads both args (to_f, to_s)" => per_call(loop_js, n) { |t, e| t.to_f; e.to_s; nil },
  "returns a 40-char String" => per_call(loop_js, n) { |_t, _e| '{"d":[[1,"x"]],"next":150,"status":"Bacon"}' },
  "game.step (Snake-like tick + JSON)" => per_call(loop_js, n) { |t, e| game.step(t.to_f, e.to_s) },
  "game.step inside AutoRun.with_time_limit" =>
    per_call(loop_js, n) { |t, e| AutoRun.with_time_limit(paths, 1.0) { game.step(t.to_f, e.to_s) } },
  "game.step called from Ruby (no JS)" =>
    begin
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      n.times { |i| game.step(100_000 + i * 150.0, "k:up") }
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / n * 1e6).round
    end
}.each { |what, us| puts format("%-42s %6d us", what, us) }
nil
