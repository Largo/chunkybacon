# StepRecorder - "time travel" for a notebook cell.
#
# Runs a cell under a TracePoint and records, for every step, the line about
# to run and the local variables of each frame (inspect, truncated). A widget
# then lets the learner scrub through the run (mock: scrubber.html).
#
#   rec = StepRecorder.new(code, file: "chunky.rb")
#   value = rec.run { eval(code, bind, "chunky.rb") }   # the cell's own eval
#   rec.trace        # => Hash, JSON-ready (rec.to_json)
#
# How it stays cheap and correct with the shared binding of a lesson:
# - The TracePoint is *targeted*: a :script_compiled hook waits for the eval
#   of exactly this code and enables the stepper on that instruction sequence
#   (TracePoint#enable(target:) covers its methods and blocks too). Code from
#   gems, the stdlib, the page - and methods an earlier cell defined, which
#   have the same file name "chunky.rb" - raise no events at all.
# - The run itself is the cell's normal eval in the shared binding, so the
#   recorder changes nothing about what the cell does or leaves behind.
# - Locals that Ruby has already allocated but the code has not assigned yet
#   (eval hoists every local of the cell: `x` is nil on line 1 even if it is
#   set on line 5) are hidden until they are non-nil or a line that assigns
#   them has run.
# - Caps: MAX_STEPS steps (then the tracing switches off and the cell runs on
#   at full speed: "truncated"), values cut to MAX_VALUE characters, big
#   Arrays/Hashes/Strings summarised without inspecting all of them, at most
#   MAX_FRAMES frames per step (recursion: the innermost ones), MAX_VARS
#   variables per frame.
#
# Plain CRuby 4.0 and ruby.wasm; no gems.
require "json"

class StepRecorder
  MAX_STEPS = 600
  MAX_VALUE = 60
  MAX_FRAMES = 5
  MAX_VARS = 16
  MAX_ITEMS = 12

  # what the kernel itself puts into the binding (check_exercise) - never shown
  HIDDEN = %i[output result code images downloads scenes apps shoes_types _].freeze

  Frame = Struct.new(:kind, :name, :line, :binding, :own, :seen, :last_line, :iter, :id, :shot)

  attr_reader :steps, :error, :value

  def initialize(code, file: "chunky.rb", hide: [], max_steps: MAX_STEPS)
    @code = code
    @file = file
    @lines = code.lines
    @hide = HIDDEN + hide
    @max_steps = max_steps
    @steps = []
    @stack = []
    @hits = Hash.new(0)
    @iters = Hash.new(0)
    @frame_seq = 0
    @truncated = false
    @block_locals = {}
    @started = false
  end

  # Runs the block (which must eval +code+ with file name +file+), recording
  # it. Returns what the block returns; re-raises what it raises.
  def run
    out = $stdout
    @out = out.respond_to?(:string) ? out : nil
    @out_start = @out ? @out.string.bytesize : 0
    @tracer = TracePoint.new(:line, :call, :return, :b_call, :b_return) { |tp| on_event(tp) }
    @compiled = TracePoint.new(:script_compiled) do |tp|
      # (tp.path is the file that called eval; the iseq knows the eval's own)
      root = tp.instruction_sequence
      next unless tp.eval_script == @code && root.path == @file

      index_blocks(root)
      @tracer.enable(target: root)
      @started = true
      @compiled.disable
    end
    @compiled.enable
    begin
      @value = yield
    rescue Exception => e
      @error = e
      raise
    ensure
      @compiled.disable
      @tracer.disable
      finish
    end
  end

  # The trace for the widget. Frame snapshots are interned: +frames+ is a
  # table of distinct ones, a step's +f+ lists indices into it (outermost
  # first) - an unchanged outer frame is stored once, not on every step.
  def trace
    table = {}.compare_by_identity
    frames = []
    steps = @steps.map do |step|
      shots = step[:frames]
      next step unless shots

      ids = shots.map { |shot| table[shot] ||= (frames << shot).length - 1 }
      step.reject { |k, _| k == :frames }.merge(f: ids)
    end
    {
      code: @code,
      file: @file,
      frames: frames,
      steps: steps,
      output: output_so_far,
      result: @error ? nil : short(@value),
      error: @error && "#{@error.class}: #{@error.message}",
      truncated: @truncated,
      traced: @started
    }
  end

  def to_json(*args) = JSON.generate(trace, *args)

  private

  # the own locals of every block of this cell, by its first line (exact:
  # from the instruction sequences, not from guessing at bindings)
  def index_blocks(iseq)
    iseq.each_child do |child|
      a = child.to_a
      if a[9] == :block
        (@block_locals[a[8]] ||= []).concat(a[10].grep(Symbol))
      end
      index_blocks(child)
    end
  end

  def on_event(tp)
    case tp.event
    when :call
      # a method this cell defined; its binding holds exactly its own locals
      b = tp.binding
      push(:method, tp.method_id.to_s, tp.lineno, b, b.local_variables,
           params: tp.parameters.map(&:last).compact)
      record(tp, :call)
    when :b_call
      b = tp.binding
      own = @block_locals[tp.lineno] || []
      parent = @stack.last&.id
      iter = (@iters[[parent, tp.lineno]] += 1)
      push(:block, source_line(tp.lineno), tp.lineno, b, own, iter)
    when :line
      ensure_main(tp)
      frame = @stack.last
      note_writes(frame)
      frame.last_line = tp.lineno
      frame.binding = tp.binding if frame.kind == :block
      @hits[tp.lineno] += 1
      record(tp, :line)
    when :return
      note_writes(@stack.last) if @stack.last
      record(tp, :return, value: short(tp.return_value))
      @stack.pop
    when :b_return
      # no step of its own: the next step shows what the pass changed (an
      # each/times body returns nothing worth a step; :raise is not traced
      # either - a targeted TracePoint never sees it, the raise happens in a
      # C frame - the error step comes from the backtrace in #finish)
      note_writes(@stack.last) if @stack.last
      @stack.pop
    end
  rescue StandardError => e
    # the recorder must never break the learner's run
    @steps << { event: "recorder-error", line: tp.lineno, note: e.message[0, 120] }
    stop_tracing
  end

  # the eval's own frame: pushed at its first line event
  def ensure_main(tp)
    return unless @stack.empty?

    b = tp.binding
    @main_known = b.local_variables.reject { |n| nil.equal?(read(b, n)) }
    push(:main, "main", tp.lineno, b, nil)
  end

  def push(kind, name, line, binding, own, iter = nil, params: [])
    seen = kind == :block ? nil : {}
    # parameters of a method count as assigned
    params.each { |n| seen[n] = true }
    @stack << Frame.new(kind, name, line, binding, own, seen, nil, iter, (@frame_seq += 1))
  end

  # the scope a frame's variables live in: a block writes into the nearest
  # method/main frame below it
  def scope_of(frame)
    idx = @stack.rindex(frame) || (@stack.length - 1)
    idx.downto(0) { |i| return @stack[i] if @stack[i].seen }
    frame
  end

  # after a line ran in +frame+: variables it assigns count as assigned even
  # when their value is nil (x = gets, y = puts "...")
  def note_writes(frame)
    return unless frame && frame.last_line
    # a one-line block shares its line with what is around it:
    # `q = xs.map { |x| x * x }` assigns q only after the last pass
    return if frame.kind == :block && frame.last_line == frame.line

    text = source_line(frame.last_line, raw: true)
    text.scan(/(?<![\w.@$:])([a-z_][A-Za-z0-9_]*)\s*(?:[-+*\/%|&^]|\*\*|\|\||&&|<<|>>)?=(?![=~>])/) do |(name)|
      scope_of(frame).seen[name.to_sym] = true
    end
  end

  def record(tp, event, value: nil)
    if @steps.length >= @max_steps
      @truncated = true
      stop_tracing
      return
    end
    @steps << {
      event: event,
      line: tp.lineno,
      hit: @hits[tp.lineno],
      frames: snapshot,
      out: output_offset,
      value: value
    }.compact
  end

  def stop_tracing
    @tracer.disable
  end

  def snapshot
    frames = @stack.last(MAX_FRAMES)
    skipped = @stack.length - frames.length
    shot = frames.map { |f| frame_shot(f) }
    shot.unshift({ kind: "more", name: "… #{skipped}" }) if skipped.positive?
    shot
  end

  def frame_shot(frame)
    b = frame.binding
    names = frame.kind == :main ? b.local_variables - @hide : frame.own
    scope = scope_of(frame)
    vars = []
    names.each do |n|
      v = read(b, n)
      next if UNREADABLE.equal?(v)

      if nil.equal?(v) && frame.kind != :block
        next unless scope.seen[n] || (frame.kind == :main && @main_known.include?(n))
      end
      scope.seen[n] = true if frame.kind != :block
      vars << [n.to_s, short(v), (frame.kind == :main && @main_known.include?(n)) ? 1 : 0]
      break if vars.length >= MAX_VARS
    end
    shot = { kind: frame.kind, name: frame.name, line: frame.line, iter: frame.iter, vars: vars }.compact
    # unchanged since the last step: the same object, stored once (#trace)
    frame.shot = shot unless frame.shot == shot
    frame.shot
  end

  def finish
    return unless @started

    # the state after the last line: the eval's frame as it ended
    if @error
      # the error step: the last line that ran is where it went wrong (only
      # this cell's own lines are traced - an error inside a C method or in
      # an earlier cell's method shows on the line that called it), with the
      # state as that line began - and no "return" steps of the frames the
      # error unwound. After the cap, the backtrace has to do.
      last_line = @steps.rindex { |s| s[:event] == :line }
      @steps.slice!((last_line + 1)..) if last_line
      line = if @truncated || !last_line
               (@error.backtrace_locations || []).find { |l| l.path == @file }&.lineno
             else
               @steps[last_line][:line]
             end
      frames = (!@truncated && last_line && @steps[last_line][:frames]) || []
      @steps << { event: "error", line: line, frames: frames, out: output_offset,
                  value: "#{@error.class}: #{@error.message}"[0, 120] }
      return
    end
    main = @stack.first
    @stack = main ? [main] : []
    note_writes(main) if main
    @steps << { event: "end", line: nil, frames: main ? snapshot : [], out: output_offset, value: short(@value) }
  rescue StandardError
    nil
  end

  def output_offset
    @out ? @out.string.bytesize - @out_start : 0
  end

  def output_so_far
    @out ? @out.string.byteslice(@out_start..).to_s.force_encoding("UTF-8").scrub : ""
  end

  def source_line(lineno, raw: false)
    text = (@lines[lineno - 1] || "").to_s
    raw ? text : text.strip[0, 40]
  end

  # inspect, but cheap for big values and safe for odd ones
  UNREADABLE = Object.new.freeze

  # a numbered block parameter (_1) is in the block's locals but a binding
  # will not give it out (NameError); `it` has no name at all
  def read(binding, name)
    binding.local_variable_get(name)
  rescue NameError
    UNREADABLE
  end

  def short(value)
    # BasicObject: no inspect, no class, no nil? - Module#=== still works
    return "#<BasicObject>" unless Kernel === value

    text = case value
           when Array
             return safe_inspect(value).then { |t| t.length > MAX_VALUE ? cut(value, t) : t } if value.length <= MAX_ITEMS

             return summary("[", value.first(MAX_ITEMS).map { |x| short(x) }, value.length, "]")
           when Hash
             return safe_inspect(value).then { |t| t.length > MAX_VALUE ? cut(value, t) : t } if value.length <= MAX_ITEMS

             return summary("{", value.first(MAX_ITEMS).map { |k, x| "#{short(k)} => #{short(x)}" }, value.length, "}")
           when String
             value.length > MAX_VALUE ? "#{value[0, MAX_VALUE].inspect}…" : value.inspect
           else
             safe_inspect(value)
           end
    text.length > MAX_VALUE ? "#{text[0, MAX_VALUE]}…" : text
  end

  # Kernel#inspect walks every instance variable, all the way down - an
  # object holding a big Array costs that big Array on every step (and the
  # recorder in a binding would inspect its own growing steps). Objects that
  # keep Ruby's default inspect get a shallow one instead.
  KERNEL_METHOD = Kernel.instance_method(:method)

  def default_inspect?(value)
    !value.is_a?(Module) && KERNEL_METHOD.bind_call(value, :inspect).owner == Kernel
  rescue Exception
    false
  end

  # "[1, 2, 3, … (100000)]": as many items as fit, and the size at the end
  def summary(open, items, size, close)
    tail = ", … (#{size})#{close}"
    text = open.dup
    items.each_with_index do |item, i|
      piece = i.zero? ? item : ", #{item}"
      break if text.length + piece.length + tail.length > MAX_VALUE + 8

      text << piece
    end
    text + tail
  end

  def cut(value, text)
    "#{text[0, MAX_VALUE]}… (#{value.length})"
  end

  def safe_inspect(value, depth = 0)
    if default_inspect?(value)
      return "#<#{value.class}>" if depth > 0

      names = value.instance_variables
      ivars = names.first(4).map do |iv|
        v = value.instance_variable_get(iv)
        "#{iv}=#{default_inspect?(v) ? safe_inspect(v, depth + 1) : short(v)}"
      end
      more = names.length > 4 ? ", …" : ""
      return "#<#{value.class}#{ivars.empty? ? '' : ' '}#{ivars.join(', ')}#{more}>"
    end
    value.inspect.to_s
  rescue Exception
    begin
      "#<#{value.class}>"
    rescue Exception
      "#<?>"
    end
  end
end
