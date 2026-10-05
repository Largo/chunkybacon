# Leaves Ruby blocks on window, for a test to call from the event loop -
# outside any Ruby call, as requestAnimationFrame calls the game. Then:
#   window.benchTop(300)  ->  {"noop": us, "step": us, "limited": us}
keep = JS.eval(<<~JS)
  return function (name, cb) { (window.benchCbs = window.benchCbs || {})[name] = cb; };
JS
game = ChunkyGame.new(width: 20, height: 15) do |g|
  s = [[5, 7], [4, 7], [3, 7]]
  g.every(0.15) do
    s.unshift([(s[0][0] + 1) % 20, 7]); s.pop
    g.clear
    g.cell(12, 7, :bacon)
    s.each { |x, y| g.cell(x, y, :body) }
  end
end
keep.call(:call, nil, "noop") { |_t, _e| nil }
keep.call(:call, nil, "step") { |t, e| game.step(t.to_f, e.to_s) }
keep.call(:call, nil, "limited") { |t, e| AutoRun.with_time_limit(["chunky.rb"], 1.0) { game.step(t.to_f, e.to_s) } }
keep.call(:call, nil, "gc") { |_t, _e| GC.stat(:count) }
JS.eval(<<~JS)
  window.benchTop = function (n) {
    var res = {}, t0 = 1e6;
    ["noop", "step", "limited"].forEach(function (name) {
      var cb = window.benchCbs[name], t = performance.now();
      for (var i = 0; i < n; i++) cb(t0 += 150, "k:up");
      res[name] = Math.round((performance.now() - t) / n * 1000);
    });
    return res;
  };
JS
nil
