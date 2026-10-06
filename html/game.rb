# show_game: a little grid game below a cell, driven by the page.
#
#   show_game(width: 20, height: 15) do |g|
#     x = 0
#     g.on_key(:right) { x += 1 }
#     g.every(0.2) do
#       g.clear
#       g.cell(x, 7, :chunky)
#     end
#   end
#
# CRuby runs on the page's main thread, so a game cannot loop or sleep: the
# page (game.js) runs the loop on requestAnimationFrame and calls #step only
# when something is due - a timer from #every, or keys and clicks that came
# in since the last frame. One call per frame at most, one JS->Ruby crossing:
# the events come in as one string, the changed cells go back as one JSON
# string. The grid itself lives here; game.js only draws what changed.
#
# Pure Ruby (no JS in this file), so the same game runs headless under CRuby
# (#advance, #press, #click) - for exercise checks (the `games` local, each a
# #fresh copy) and the harness. Under the page's time limit (main.rb,
# GameGuard) every Ruby block here costs TracePoint events, so the internals
# avoid per-cell blocks: #clear walks only the filled cells.
# From experiments/08-game-loop; the lesson is "Chunkys Snake".
class ChunkyGame
  # what a cell can show: a sprite name, a colour, or any String (an emoji)
  SPRITES = {
    chunky: "🦊", fox: "🦊", bacon: "🥓", egg: "🥚",
    apple: "🍎", cheese: "🧀", star: "⭐", heart: "❤️", coin: "🪙",
    wall: "🧱", rock: "🪨", tree: "🌳", fire: "🔥", water: "🌊",
    ghost: "👻", cat: "🐱", mouse: "🐭", snake: "🐍", bug: "🐛", trophy: "🏆"
  }.freeze
  COLORS = {
    red: "#e0453a", orange: "#f08a24", yellow: "#f4c430", green: "#3fa34d",
    blue: "#2f6fd6", purple: "#8a4fd0", pink: "#ef7fb0", brown: "#8a5a3c",
    black: "#1f1b16", white: "#ffffff", gray: "#9a948c", grey: "#9a948c",
    body: "#f2a65a"   # Chunky's orange, for a snake's body
  }.freeze
  KEYS = %i[left right up down space enter escape].freeze

  attr_reader :width, :height, :ticks, :message, :status_text

  def initialize(width: 20, height: 15, &setup)
    raise ArgumentError, "show_game needs a block: show_game { |g| ... }" unless setup
    @width = width.to_i
    @height = height.to_i
    raise ArgumentError, "a game is 1..60 cells wide and high" unless (1..60).cover?(@width) && (1..60).cover?(@height)

    @setup = setup
    @now = 0.0
    @output = +""
    restart
  end

  # ---------- for the learner ----------

  # g.cell(3, 4, :bacon) puts bacon there; g.cell(3, 4) says what is there
  # (nil when nothing); g.cell(3, 4, nil) empties it. Outside the grid,
  # setting does nothing and reading gives :outside - so a wall check is
  # `g.cell(x, y) == :outside`, or `!g.inside?(x, y)`.
  def cell(x, y, *what)
    return (inside?(x, y) ? @cells[index(x, y)] : :outside) if what.empty?

    set(x, y, what.first)
  end
  alias [] cell

  def []=(x, y, what)
    set(x, y, what)
  end

  def inside?(x, y)
    x.is_a?(Integer) && y.is_a?(Integer) && x >= 0 && y >= 0 && x < @width && y < @height
  end

  # empties the whole grid (g.clear) or one cell (g.clear(3, 4))
  def clear(x = nil, y = nil)
    return set(x, y, nil) if x

    @filled.keys.each { |i| mark(i, nil) }   # only the filled ones: cheap under the time limit
    self
  end

  # every free cell as [x, y] - `g.free_cells.sample` is a random place for the bacon
  def free_cells
    @cells.each_index.filter_map { |i| [i % @width, i / @width] unless @cells[i] }
  end

  # g.on_key(:left) { ... }, g.on_key(:a, :left) { ... }, or for any key:
  # g.on_key { |key| ... } - keys are :left :right :up :down :space :enter
  # :escape, letters :a..:z and digits :"0"..:"9"
  def on_key(*keys, &block)
    raise ArgumentError, "on_key needs a block" unless block
    @key_handlers << [keys.map(&:to_sym), block]
    self
  end

  # g.on_click { |x, y| ... } - a click or a tap on a cell
  def on_click(&block)
    raise ArgumentError, "on_click needs a block" unless block
    @click_handlers << block
    self
  end

  # g.every(0.15) { ... } runs the block every 0.15 seconds while the game
  # runs. Not faster than 0.02 s (50 times a second).
  def every(seconds, &block)
    raise ArgumentError, "every needs a block: every(0.5) { ... }" unless block
    seconds = seconds.to_f
    raise ArgumentError, "every(seconds): at least 0.02" if seconds < 0.02

    @timers << [seconds, @now + seconds, block]
    self
  end

  # a line of text under the grid: g.status("Score: 3")
  def status(text)
    @status_text = text.to_s
    @dirty_text = true
    self
  end

  # stops the game with a message over the grid; a click plays again
  def game_over(text = "Game over")
    @over = true
    @message = text.to_s
    self
  end

  def stop = game_over("")
  def over? = @over

  def inspect = "#<ChunkyGame #{@width}x#{@height}#{over? ? ' over' : ''}>"
  alias to_s inspect

  # ---------- headless, for checks and tests ----------

  # the same game once more, from its setup block: a check plays this copy,
  # so the game below the cell still starts from the beginning
  def fresh = ChunkyGame.new(width: @width, height: @height, &@setup)

  # @now is in seconds, #step takes the page's milliseconds
  def press(key) = step(@now * 1000.0, "k:#{key}")
  def click(x, y) = step(@now * 1000.0, "c:#{x},#{y}")

  # runs the timers for +seconds+ of game time, in steps of the shortest
  # timer (one #step catches up at most 3 runs per timer)
  def advance(seconds)
    now_ms = @now * 1000.0
    target_ms = now_ms + seconds.to_f * 1000.0
    slice_ms = (@timers.map(&:first).min || seconds.to_f) * 1000.0
    step(now_ms, "") unless @started   # starts the clock here, not at the first slice
    while now_ms < target_ms && !@over
      now_ms = [now_ms + slice_ms, target_ms].min
      step(now_ms, "")
    end
    self
  end

  # ---------- for the page (main.rb, game.js) ----------

  # The page's one call per frame. +now_ms+: the page's clock;
  # +events+: "k:left|k:space|c:3,4" since the last call. Returns JSON:
  #   {"d":[[index, look], ...], "next": ms, "status": "...", "over": "...",
  #    "log": "...", "error": "..."}
  # where look is "" (empty), an emoji, "img:url" or "bg:#rrggbb".
  def step(now_ms, events)
    now = now_ms.to_f / 1000.0
    # the first call starts the clock: timers count from then, not from 0
    @timers.each { |t| t[1] = now + t[0] } unless @started
    @started = true
    @now = now
    capture do
      events.to_s.split("|").each { |event| dispatch(event) }
      run_timers unless @over
    end
    frame_json
  rescue StandardError, ScriptError => e
    @over = true
    @message = ""
    frame_json("#{e.class}: #{e.message}#{where(e)}")
  end

  # stops the game with an error the page found (main.rb: the time limit)
  def error_json(text)
    @over = true
    @message = ""
    frame_json(text)
  end

  # the whole grid, for the first frame
  def full_json
    @dirty = @filled.keys
    @dirty_text = true
    frame_json
  end

  # back to the start: the setup block runs again with an empty grid
  def restart
    # what the page still shows of the last round goes, unless the setup
    # draws it again
    @dirty = @filled ? @filled.keys : []
    @cells = Array.new(@width * @height)
    @filled = {}   # index => true, for the cells that are not empty
    @key_handlers = []
    @click_handlers = []
    @timers = []
    @over = false
    @message = nil
    @status_text = ""
    @dirty_text = true
    @ticks = 0
    @setup.arity.zero? ? instance_exec(&@setup) : @setup.call(self)
    @timers.each { |t| t[1] = @now + t[0] }
    self
  end

  private

  def index(x, y) = y * @width + x

  def set(x, y, what)
    mark(index(x, y), what) if inside?(x, y)
    what
  end

  def mark(i, what)
    return if @cells[i] == what

    @cells[i] = what
    what.nil? || what == false ? @filled.delete(i) : @filled[i] = true
    @dirty << i
  end

  def look(what)
    case what
    when nil, false then ""
    when Symbol then COLORS[what] ? "bg:#{COLORS[what]}" : (SPRITES[what] || what.to_s[0, 2])
    when /\A#\h{3}(\h{3})?\z/ then "bg:#{what}"
    else what.to_s[0, 8]
    end
  end

  def dispatch(event)
    kind, value = event.split(":", 2)
    case kind
    when "k"
      key = value.to_sym
      @key_handlers.each do |keys, block|
        next unless keys.empty? || keys.include?(key)
        keys.empty? ? block.call(key) : block.call
      end
    when "c"
      x, y = value.split(",").map(&:to_i)
      @click_handlers.each { |block| block.call(x, y) }
    when "r"
      restart
    end
  end

  # each timer as often as it was due, but never more than 3 at once (a tab
  # that slept does not fast-forward the game)
  def run_timers
    @timers.each do |timer|
      seconds, due, block = timer
      runs = 0
      while due <= @now && runs < 3 && !@over
        @ticks += 1
        block.arity.zero? ? block.call : block.call(@ticks)
        due += seconds
        runs += 1
      end
      due = @now + seconds if due <= @now
      timer[1] = due
    end
  end

  def capture
    old = $stdout
    $stdout = StringIO.new(@output)
    @output.clear
    yield
  ensure
    $stdout = old
  end

  def where(error)
    line = error.backtrace_locations&.find { |loc| loc.path == "chunky.rb" }&.lineno
    line ? " (line #{line})" : ""
  end

  def frame_json(error = nil)
    frame = { "d" => @dirty.uniq.map { |i| [i, look(@cells[i])] } }
    @dirty.clear
    frame["next"] = (@timers.map { |t| t[1] }.min.to_f * 1000).round if @timers.any? && !@over
    if @dirty_text
      frame["status"] = @status_text
      @dirty_text = false
    end
    frame["over"] = @message if @over
    frame["log"] = @output.dup unless @output.empty?
    frame["error"] = error if error
    JSON.generate(frame)
  end
end

module Kernel
  # A grid game below the cell; see ChunkyGame above. Without the page
  # (CRuby, a test) it returns the game, to drive it headless.
  def show_game(width: 20, height: 15, &setup)
    game = ChunkyGame.new(width: width, height: height, &setup)
    return game unless defined?(ChunkyApp) && ChunkyApp.respond_to?(:instance)

    ChunkyApp.instance.add_game(game)
    nil
  end
end
