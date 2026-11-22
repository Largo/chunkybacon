# frozen_string_literal: true

# The expert lessons' microscope (lessons `mikro-parser` to `mikro-gc`):
# tools that show what CRuby does with a program, all of them reading the
# real Ruby of the page (ruby.wasm, CRuby 4.0.0 for wasm32) - never a model
# of it. Pure Ruby: the pictures are SVG strings that go through
# show_image, the step-by-step views are JSON that microscope.js draws.
#
#   show_tokens(code)      Prism's tokens as coloured chips
#   show_ast(code)         Prism's syntax tree, drawn as a tree
#   show_yarv(code)        the compiled YARV instructions run one at a time:
#                          the VM stack with its frames, locals, ep chains
#   show_value(*objects)   the 32-bit VALUE word of each object, its tag bits
#   show_slots(*objects)   heap slots: size pool, embedded or not
#   show_bars(hash)        a bar chart (memsizes and the like)
#   show_lookup(obj, :m)   method lookup along the ancestors, step by step
#   show_gc(roots, heap)   mark and sweep over the real reachability graph
#
# Microscope::Yarv is the simulator behind show_yarv. It runs the
# instruction sequence that RubyVM::InstructionSequence.compile makes (the
# same compiler ▶ uses), instruction by instruction, with the semantics of
# insns.def; a call into a method written in C (Integer#times, puts) is the
# real method, a method or block of the cell's own code is stepped into.
# At the end Ruby runs the same code for real and the result must match:
# the widget says so (or says it does not).
require "json"
require "stringio"

module Microscope
  SOURCE_TAG = "v4.0.0"
  SOURCE_URL = "https://github.com/ruby/ruby/blob/#{SOURCE_TAG}/".freeze

  module_function

  # a ui string of the course (the page's language), or the English default
  # (the tests and the check harness have no page)
  def t(key, default)
    app = defined?(ChunkyApp) && ChunkyApp.respond_to?(:instance) && ChunkyApp.instance
    text = app && app.respond_to?(:ui) ? app.ui[key] : nil
    text.nil? || text.to_s.empty? ? default : text.to_s
  rescue StandardError
    default
  end

  def short(obj, max = 26)
    text = obj.is_a?(Proc) ? "#<Proc>" : obj.inspect
    text = text.dup.force_encoding("UTF-8")
    text.length > max ? "#{text[0, max - 1]}…" : text
  rescue StandardError
    "#<#{obj.class}>"
  end

  def esc(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")

  # ---------------------------------------------------------------------
  # YARV, one instruction at a time
  # ---------------------------------------------------------------------
  class Yarv
    MAX_STEPS = 700
    FILE = "(microscope)"

    class Unsupported < StandardError; end
    class StepLimit < StandardError; end

    # one instruction sequence, from ISeq#to_a: its instructions with labels
    # resolved to indexes and the line each one belongs to
    class Seq
      attr_reader :ref, :name, :kind, :locals, :params, :insns, :lines, :labels

      def initialize(ref, raw)
        @ref = ref
        @name = raw[5].to_s.sub("<compiled>", "<main>")
        @kind = raw[9]
        @locals = raw[10]
        @params = raw[11] || {}
        @insns = []
        @lines = []
        @labels = {}
        line = raw[8].to_i
        raw[13].each do |item|
          case item
          when Integer then line = item
          when Symbol then @labels[item] = @insns.size if item.to_s.start_with?("label_")
          when Array
            @insns << item
            @lines << line
          end
        end
      end

      # getlocal's operand counts from the ep down: the last local is 3 below
      def local_name(index)
        @locals[@locals.size - 1 - (index - 3)]
      end
    end

    # a control frame: what YARV keeps in rb_control_frame_t plus the env
    # its ep points to (the locals); +parent+ is the env a block's ep[-1]
    # leads to
    class Frame
      attr_accessor :pc, :done
      attr_reader :id, :kind, :name, :seq, :self_obj, :locals, :parent, :ops, :block

      def initialize(id, kind, name, seq, self_obj, parent, block)
        @id = id
        @kind = kind
        @name = name
        @seq = seq
        @self_obj = self_obj
        @parent = parent
        @block = block
        @pc = 0
        @ops = []
        @locals = {}
        seq&.locals&.each { |n| @locals[n] = nil }
        @done = false
      end
    end

    # a block of the cell's code, handed to a method: called from C (each,
    # times) through to_proc, or from a stepped method's yield
    class Block
      attr_reader :seq, :frame

      def initialize(sim, seq, frame)
        @sim = sim
        @seq = seq
        @frame = frame
      end

      def call(*args) = @sim.run_block(self, args)

      def to_proc
        block = self
        proc { |*args| block.call(*args) }
      end

      # -> { } is `lambda` with a block: Kernel#lambda wants a literal
      # one, so the lambda is made here, around the stepped block
      def to_lambda
        block = self
        lambda { |*args| block.call(*args) }
      end
    end

    attr_reader :steps, :seqs, :source, :output

    def initialize(source)
      @source = source
      @seqs = []
      @steps = []
      @frames = []
      @next_id = 0
      @out = StringIO.new
      @methods = {}
    end

    def seq_for(raw)
      seq = Seq.new(@seqs.size, raw)
      @seqs << seq
      seq
    end

    # runs it all; answers the JSON the page draws
    def run
      iseq = RubyVM::InstructionSequence.compile(@source, FILE)
      top = seq_for(iseq.to_a)
      outer = $stdout
      $stdout = @out
      result = nil
      error = nil
      begin
        frame = push_frame(:top, "<main>", top, TOPLEVEL_BINDING.receiver, nil, nil)
        result = execute(frame)
      rescue StepLimit
        error = ["limit", MAX_STEPS]
      rescue Unsupported => e
        error = ["unsupported", e.message]
      ensure
        $stdout = outer
      end
      @output = @out.string
      real, real_error = real_run
      record_final(result, error, real, real_error)
      { "source" => @source, "seqs" => @seqs.map { |s| seq_json(s) }, "steps" => @steps,
        "result" => error ? nil : Microscope.short(result, 60),
        "real" => real_error ? "#{real_error.class}: #{real_error.message}" : Microscope.short(real, 60),
        "same" => !error && !real_error && result == real, "error" => error, "output" => @output }
    end

    # the same code, run by Ruby itself (its output kept apart)
    def real_run
      outer = $stdout
      $stdout = StringIO.new
      [RubyVM::InstructionSequence.compile(@source, FILE).eval, nil]
    rescue StandardError => e
      [nil, e]
    ensure
      $stdout = outer
    end

    def seq_json(seq)
      { "name" => seq.name, "kind" => seq.kind.to_s, "lines" => seq.lines,
        "insns" => seq.insns.map { |insn| insn_text(seq, insn) } }
    end

    # an instruction as `disasm` prints it, operands made readable
    def insn_text(seq, insn)
      name, *ops = insn
      shown = ops.map.with_index do |op, i|
        case op
        when Hash
          op.key?(:mid) ? "<calldata!mid:#{op[:mid]}, argc:#{op[:orig_argc]}>" : op.inspect
        when Symbol
          if seq.labels.key?(op) then seq.labels[op].to_s
          elsif name.to_s.match?(/local/) && i.zero? then op.inspect
          else op.inspect
          end
        when Integer
          if name.to_s.match?(/\A(get|set)local/) && i.zero?
            level = name.to_s.end_with?("_WC_1") ? 1 : (name.to_s.end_with?("_WC_0") ? 0 : ops[1].to_i)
            "#{local_owner(seq, level).local_name(op)}@#{level}"
          else op.to_s
          end
        when Array
          if op.first == "YARVInstructionSequence/SimpleDataFormat" then "<#{op[5]}>"
          elsif name == :opt_case_dispatch then "<cdhash>"
          else Microscope.short(op, 30)
          end
        when nil then ""
        else Microscope.short(op, 30)
        end
      end
      shown.pop if name.to_s.match?(/\A(get|set)local\z/) # the level, already in name@level
      ([name.to_s] + shown.reject(&:empty?)).join(" ")
    end

    # the seq whose locals a getlocal of +level+ in +seq+ reads (for names)
    def local_owner(seq, level)
      return seq if level.zero?

      @parents ||= {}
      owner = seq
      level.times { owner = @parents[owner.ref] || owner }
      owner
    end

    # ---------- frames ----------

    def push_frame(kind, name, seq, self_obj, parent, block)
      frame = Frame.new(@next_id += 1, kind, name, seq, self_obj, parent, block)
      @frames << frame
      frame
    end

    def pop_frame(frame)
      frame.done = true
      @frames.delete(frame)
    end

    # a method written in C, between a stepped frame and a block it calls
    def with_cfunc(name)
      frame = push_frame(:cfunc, name, nil, nil, nil, nil)
      yield
    ensure
      pop_frame(frame) if frame
    end

    def run_block(block, args)
      seq = block.seq
      lead = seq.params[:lead_num].to_i
      args = args.first if args.size == 1 && args.first.is_a?(Array) && (lead > 1 || seq.params[:ambiguous_param0] == false && lead > 1)
      frame = push_frame(:block, seq.name, seq, block.frame.self_obj, block.frame, nil)
      assign_params(frame, Array(args).dup, nil)
      execute(frame)
    end

    def run_method(seq, self_obj, args, block)
      frame = push_frame(:method, seq.name, seq, self_obj, nil, block)
      assign_params(frame, args.dup, block)
      execute(frame)
    end

    def assign_params(frame, args, _block)
      params = frame.seq.params
      names = frame.seq.locals
      lead = params[:lead_num].to_i
      opt = params[:opt] ? params[:opt].size - 1 : 0
      if (params[:kwbits] || params[:keyword]) && frame.kind == :method
        raise Unsupported, "keyword parameters"
      end
      lead.times { |i| frame.locals[names[i]] = args.shift }
      given = [[args.size, opt].min, 0].max
      given.times { |i| frame.locals[names[lead + i]] = args.shift }
      frame.pc = frame.seq.labels[params[:opt][given]] if opt.positive?
      if params[:rest_start]
        frame.locals[names[params[:rest_start]]] = args
      end
      frame.locals[names[params[:block_start]]] = frame.block&.to_proc if params[:block_start] && frame.block
    end

    # ---------- the loop ----------

    def execute(frame)
      loop do
        insn = frame.seq.insns[frame.pc]
        raise Unsupported, "fell off the end" unless insn

        record(frame, insn)
        name, *ops = insn
        frame.pc += 1
        value = step(frame, name, ops)
        if value.is_a?(Array) && value.first == :leave
          pop_frame(frame)
          return value[1]
        end
      end
    end

    def push(frame, value) = frame.ops.push(value)

    def pop(frame)
      raise Unsupported, "stack underflow" if frame.ops.empty?

      frame.ops.pop
    end

    def popn(frame, n)
      return [] if n.zero?

      frame.ops.pop(n)
    end

    def env_at(frame, level)
      env = frame
      level.times { env = env.parent }
      env
    end

    def jump(frame, label) = frame.pc = frame.seq.labels.fetch(label)

    # executes one instruction (insns.def); :leave ends the frame
    def step(frame, name, ops)
      case name
      when :nop then nil
      when :putnil then push(frame, nil)
      when :putself then push(frame, frame.self_obj)
      when :putobject then push(frame, ops[0])
      when :putobject_INT2FIX_0_ then push(frame, 0)
      when :putobject_INT2FIX_1_ then push(frame, 1)
      when :putstring, :putchilledstring then push(frame, ops[0].dup)
      when :duparray, :duphash then push(frame, ops[0].dup)
      when :newarray then push(frame, popn(frame, ops[0]))
      when :newhash then push(frame, popn(frame, ops[0]).each_slice(2).to_h)
      when :newrange
        low, high = popn(frame, 2)
        push(frame, Range.new(low, high, ops[0] == 1))
      when :concatstrings then push(frame, popn(frame, ops[0]).join)
      when :objtostring
        obj = pop(frame)
        push(frame, obj.is_a?(String) ? obj : obj.to_s)
      when :anytostring
        str = pop(frame)
        obj = pop(frame)
        push(frame, str.is_a?(String) ? str : Kernel.instance_method(:to_s).bind_call(obj))
      when :intern then push(frame, pop(frame).to_sym)
      when :toregexp then push(frame, Regexp.new(popn(frame, ops[1]).join, ops[0]))
      when :dup then push(frame, frame.ops.last)
      when :dupn then frame.ops.concat(frame.ops.last(ops[0]))
      when :pop then pop(frame)
      when :swap
        a = pop(frame)
        b = pop(frame)
        push(frame, a)
        push(frame, b)
      when :topn then push(frame, frame.ops[-1 - ops[0]])
      when :setn then frame.ops[-1 - ops[0]] = frame.ops.last
      when :adjuststack then popn(frame, ops[0])
      when :getlocal, :getlocal_WC_0, :getlocal_WC_1
        level = local_level(name, ops)
        env = env_at(frame, level)
        push(frame, env.locals[env.seq.local_name(ops[0])])
      when :setlocal, :setlocal_WC_0, :setlocal_WC_1
        level = local_level(name, ops)
        env = env_at(frame, level)
        env.locals[env.seq.local_name(ops[0])] = pop(frame)
      when :getblockparam, :getblockparamproxy
        env = env_at(frame, ops[1].to_i)
        push(frame, env.locals[env.seq.local_name(ops[0])] || env.block&.to_proc)
      when :getinstancevariable then push(frame, frame.self_obj.instance_variable_get(ops[0]))
      when :setinstancevariable then frame.self_obj.instance_variable_set(ops[0], pop(frame))
      when :getglobal then push(frame, TOPLEVEL_BINDING.eval(ops[0].to_s))
      when :opt_getconstant_path
        push(frame, ops[0].inject(Object) { |mod, sym| mod.const_get(sym) })
      when :branchif then jump(frame, ops[0]) if pop(frame)
      when :branchunless then jump(frame, ops[0]) unless pop(frame)
      when :branchnil then jump(frame, ops[0]) if pop(frame).nil?
      when :jump then jump(frame, ops[0])
      when :leave then [:leave, pop(frame)]
      when :opt_case_dispatch
        key = pop(frame)
        if [Integer, Float, Symbol, String, NilClass, TrueClass, FalseClass].any? { |c| key.is_a?(c) }
          key = key.to_i if key.is_a?(Float) && key.finite? && key == key.floor
          target = ops[0].each_slice(2).find { |k, _| k.eql?(key) }
          jump(frame, target ? target[1] : ops[1])
        end
      when :checkmatch
        pattern = pop(frame)
        target = pop(frame)
        array = (ops[0] & 4).positive?
        push(frame, array ? pattern.any? { |p| p === target } : pattern === target)
      when :splatarray then push(frame, Array(pop(frame)).then { |a| ops[0] ? a.dup : a })
      when :expandarray
        raise Unsupported, "expandarray #{ops[1]}" unless ops[1].zero?

        ary = Array(pop(frame))
        (ops[0] - 1).downto(0) { |i| push(frame, ary[i]) }
      when :putspecialobject then push(frame, :"<vm special #{ops[0]}>")
      when :definemethod
        define(frame, ops[0], seq_for(ops[1]))
      when :opt_str_freeze then push(frame, ops[0].dup.freeze)
      when :opt_str_uminus then push(frame, -ops[0])
      when :opt_ary_freeze, :opt_hash_freeze then push(frame, ops[0].dup.freeze)
      when :opt_newarray_send
        values = popn(frame, ops[0])
        method = { 1 => :max, 2 => :min, 3 => :hash }[ops[1]]
        raise Unsupported, "opt_newarray_send #{ops[1]}" unless method

        push(frame, values.public_send(method))
      when :opt_duparray_send
        args = popn(frame, ops[2])
        push(frame, ops[0].public_send(ops[1], *args))
      when :opt_new
        argc = ops[0][:orig_argc]
        klass = frame.ops[-1 - argc]
        if klass.is_a?(Class) && klass.method(:new).owner == Class
          obj = klass.allocate
          frame.ops[-1 - argc] = obj
          frame.ops[-2 - argc] = obj
        else
          jump(frame, ops[1])
        end
      when :invokeblock
        args = popn(frame, ops[0][:orig_argc])
        env = frame
        env = env.parent while env.kind == :block
        block = env.block
        raise LocalJumpError, "no block given (yield)" unless block

        push(frame, block.respond_to?(:seq) ? run_block(block, args) : block.call(*args))
      when :send, :opt_send_without_block
        call(frame, ops[0], name == :send ? ops[1] : nil)
      else
        calldata = ops.reverse.find { |op| op.is_a?(Hash) && op.key?(:mid) }
        raise Unsupported, name.to_s unless name.to_s.start_with?("opt_") && calldata

        call(frame, calldata, nil)
      end
    end

    def local_level(name, ops)
      return 0 if name.to_s.end_with?("_WC_0")
      return 1 if name.to_s.end_with?("_WC_1")

      ops[1].to_i
    end

    def define(frame, mid, seq)
      @parents ||= {}
      sim = self
      owner = frame.kind == :top ? Object : frame.self_obj.class
      owner.send(:define_method, mid) do |*args, &blk|
        sim.run_method(seq, self, args, blk && (blk.is_a?(Block) ? blk : blk))
      end
      owner.send(:private, mid) if frame.kind == :top
      nil
    end

    # send / opt_send_without_block / the opt_ arithmetic: a call. The
    # receiver and the arguments come off the stack; a block of the cell's
    # code goes along as a Block (stepped into when the method calls it).
    def call(frame, calldata, block_raw)
      flag = calldata[:flag].to_i
      argc = calldata[:orig_argc].to_i
      raise Unsupported, "splat call" if (flag & 1).positive?

      block_arg = (flag & 2).positive? ? pop(frame) : nil
      args = popn(frame, argc)
      if calldata[:kw_arg]
        keys = calldata[:kw_arg]
        kw = keys.zip(args.pop(keys.size)).to_h
        args << kw
      end
      recv = pop(frame)
      mid = calldata[:mid]
      block = nil
      if block_raw
        seq = seq_for(block_raw)
        @parents ||= {}
        @parents[seq.ref] = frame.seq
        block = Block.new(self, seq, frame)
      end
      block ||= block_arg
      push(frame, dispatch(frame, recv, mid, args, block, kw: !calldata[:kw_arg].nil?))
    end

    def dispatch(_frame, recv, mid, args, block, kw: false)
      own = @methods.include?(mid) || recv.respond_to?(:seq)
      kwargs = kw ? args.pop : {}
      if block.is_a?(Block) && %i[lambda proc].include?(mid) && args.empty?
        mid == :lambda ? block.to_lambda : block.to_proc
      elsif block.is_a?(Block) && !own
        label = "#{recv.is_a?(Module) ? "#{recv}." : "#{recv.class}#"}#{mid}"
        with_cfunc(label) { recv.__send__(mid, *args, **kwargs, &block.to_proc) }
      elsif block.is_a?(Block)
        recv.__send__(mid, *args, **kwargs, &block.to_proc).tap { nil }
      else
        recv.__send__(mid, *args, **kwargs, &block)
      end
    end

    # ---------- what the page draws ----------

    def record(frame, insn)
      raise StepLimit if @steps.size >= MAX_STEPS

      @steps << { "frames" => @frames.map { |f| frame_json(f) }, "seq" => frame.seq.ref, "pc" => frame.pc,
                  "line" => frame.seq.lines[frame.pc], "note" => note(frame, insn), "out" => @out.string.length }
    end

    def record_final(result, error, real, real_error)
      note = if error then error
             elsif real_error then ["realError", "#{real_error.class}: #{real_error.message}"]
             elsif result == real then ["done", Microscope.short(result, 40)]
             else ["differs", Microscope.short(result, 40), Microscope.short(real, 40)]
             end
      @steps << { "frames" => [], "seq" => nil, "pc" => nil, "line" => nil, "note" => note, "out" => @out.string.length }
    end

    def frame_json(frame)
      parent_id = frame.parent&.id
      { "id" => frame.id, "kind" => frame.kind.to_s, "name" => frame.name,
        "seq" => frame.seq&.ref, "pc" => frame.pc,
        "self" => frame.kind == :cfunc ? nil : Microscope.short(frame.self_obj, 18),
        "locals" => frame.locals.map { |n, v| [n.to_s, Microscope.short(v)] },
        "ops" => frame.ops.map { |v| Microscope.short(v) },
        "ep" => parent_id, "epLive" => frame.parent ? !frame.parent.done : nil,
        "epName" => frame.parent&.name }
    end

    FAST = {
      opt_plus: [Integer, Float, String, Array], opt_minus: [Integer, Float], opt_mult: [Integer, Float],
      opt_div: [Integer, Float], opt_mod: [Integer, Float], opt_lt: [Integer, Float], opt_le: [Integer, Float],
      opt_gt: [Integer, Float], opt_ge: [Integer, Float], opt_eq: [Integer, Float, String, Symbol],
      opt_ltlt: [String, Array], opt_aref: [Array, Hash], opt_length: [String, Array, Hash],
      opt_size: [String, Array, Hash], opt_succ: [Integer], opt_empty_p: [String, Array, Hash]
    }.freeze

    def note(frame, insn)
      name, *ops = insn
      top = frame.ops.last
      case name
      when :putobject, :putstring, :putchilledstring, :duparray, :duphash then ["push", Microscope.short(ops[0])]
      when :putobject_INT2FIX_0_ then ["pushInt", "0"]
      when :putobject_INT2FIX_1_ then ["pushInt", "1"]
      when :putnil then ["push", "nil"]
      when :putself then ["self", Microscope.short(frame.self_obj, 18)]
      when :getlocal, :getlocal_WC_0, :getlocal_WC_1
        level = local_level(name, ops)
        env = env_at(frame, level)
        [level.zero? ? "get" : "getOuter", env.seq.local_name(ops[0]).to_s, level.to_s, env.name]
      when :setlocal, :setlocal_WC_0, :setlocal_WC_1
        level = local_level(name, ops)
        env = env_at(frame, level)
        [level.zero? ? "set" : "setOuter", env.seq.local_name(ops[0]).to_s, Microscope.short(top), env.name]
      when :send, :opt_send_without_block
        calldata = ops[0]
        argc = calldata[:orig_argc].to_i
        recv = frame.ops[-1 - argc - ((calldata[:flag].to_i & 2).positive? ? 1 : 0)]
        own = @methods.include?(calldata[:mid]) || recv_defines?(recv, calldata[:mid])
        [ops[1] ? "sendBlock" : (own ? "sendOwn" : "send"), calldata[:mid].to_s, argc.to_s, Microscope.short(recv, 18)]
      when :invokeblock then ["yield", ops[0][:orig_argc].to_s]
      when :leave then ["leave", Microscope.short(top)]
      when :branchunless then ["branchunless", Microscope.short(top), frame.seq.labels[ops[0]].to_s]
      when :branchif then ["branchif", Microscope.short(top), frame.seq.labels[ops[0]].to_s]
      when :branchnil then ["branchnil", Microscope.short(top), frame.seq.labels[ops[0]].to_s]
      when :jump then ["jump", frame.seq.labels[ops[0]].to_s]
      when :dup then ["dup", Microscope.short(top)]
      when :pop then ["pop", Microscope.short(top)]
      when :definemethod then ["def", ops[0].to_s]
      when :newarray then ["newarray", ops[0].to_s]
      when :opt_case_dispatch then ["case", Microscope.short(top)]
      when :opt_new then ["optNew"]
      else
        calldata = ops.reverse.find { |op| op.is_a?(Hash) && op.key?(:mid) }
        if calldata && name.to_s.start_with?("opt_")
          argc = calldata[:orig_argc].to_i
          recv = frame.ops[-1 - argc]
          args = frame.ops.last(argc)
          types = FAST[name]
          fast = types && types.any? { |c| recv.is_a?(c) && args.all? { |a| a.is_a?(c) || name == :opt_aref || name == :opt_ltlt } } &&
                 (recv.instance_of?(recv.class))
          [fast ? "optFast" : "optCall", calldata[:mid].to_s, Microscope.short(recv, 16), args.map { |a| Microscope.short(a, 12) }.join(", ")]
        else
          ["other", name.to_s]
        end
      end
    end

    def recv_defines?(recv, mid)
      method = recv.method(mid)
      method.source_location&.first == __FILE__
    rescue NameError
      false
    end
  end

  # ---------------------------------------------------------------------
  # pictures (SVG)
  # ---------------------------------------------------------------------
  class Svg
    FONT = "font-family='Atkinson Hyperlegible Mono, ui-monospace, monospace'"
    attr_reader :alt

    def initialize(width, height, alt)
      @width = width
      @height = height
      @alt = alt
      @parts = []
    end

    def <<(part)
      @parts << part
      self
    end

    def to_svg
      "<svg xmlns='http://www.w3.org/2000/svg' width='#{@width.round}' height='#{@height.round}' " \
        "viewBox='0 0 #{@width.round} #{@height.round}' font-size='13' #{FONT}>" \
        "<rect width='100%' height='100%' fill='#fbf9f4'/>#{@parts.join}</svg>"
    end

    alias_method :to_s, :to_svg

    def alt_text = @alt
  end

  CHAR_W = 7.9

  def text_w(text, size = 13) = text.to_s.length * CHAR_W * size / 13.0

  TOKEN_COLORS = {
    keyword: "#9b2c8f", identifier: "#1e2229", constant: "#00639a", literal: "#2c7a2c",
    operator: "#bd2d00", punct: "#6b6355", space: "#b6ad98"
  }.freeze

  def token_kind(type)
    s = type.to_s
    return :keyword if s.start_with?("KEYWORD_")
    return :constant if s == "CONSTANT"
    return :identifier if %w[IDENTIFIER METHOD_NAME IVAR GLOBAL_VARIABLE CLASS_VARIABLE LABEL].include?(s)
    return :literal if s.match?(/INTEGER|FLOAT|STRING|SYMBOL|REGEXP|CHARACTER|RATIONAL|IMAGINARY|HEREDOC|WORDS/)
    return :space if s.match?(/NEWLINE|EOF|COMMENT|IGNORED/)
    return :punct if s.match?(/PARENTHESIS|BRACKET|BRACE|COMMA|DOT|SEMICOLON|COLON|PIPE/)

    :operator
  end

  # Prism's tokens: one chip each, the text above, the type below
  def tokens_svg(code)
    require "prism"
    tokens = Prism.lex(code).value.map(&:first).reject { |t| t.type == :EOF }
    x = 10
    y = 12
    max_w = 660
    row_h = 52
    chips = []
    tokens.each do |tok|
      label = tok.type == :NEWLINE ? "⏎" : tok.value
      type = tok.type.to_s
      w = [text_w(label, 15), text_w(type, 10)].max + 14
      if x + w > max_w && x > 10
        x = 10
        y += row_h
      end
      color = TOKEN_COLORS[token_kind(tok.type)]
      chips << "<g><rect x='#{x}' y='#{y}' width='#{w.round(1)}' height='42' rx='6' fill='#fff' stroke='#{color}' stroke-width='1.6'/>" \
               "<text x='#{(x + w / 2).round(1)}' y='#{y + 20}' text-anchor='middle' font-size='15' fill='#{color}' font-weight='bold'>#{esc(label)}</text>" \
               "<text x='#{(x + w / 2).round(1)}' y='#{y + 35}' text-anchor='middle' font-size='10' fill='#6b6355'>#{esc(type)}</text></g>"
      x += w + 6
    end
    alt = "#{t("mscTokensAlt", "Tokens")}: " + tokens.map { |tok| "#{tok.type} #{tok.value.inspect}" }.join(", ")
    Svg.new(max_w + 10, y + row_h, alt).tap { |svg| chips.each { |c| svg << c } }
  end

  AstNode = Struct.new(:label, :detail, :edge, :children, :x, :y, :w, :kind)

  NODE_COLORS = {
    call: "#bd2d00", literal: "#2c7a2c", variable: "#00639a", control: "#9b2c8f", def: "#7a4f00", other: "#4e5560"
  }.freeze

  def ast_kind(node)
    name = node.class.name.to_s
    return :call if name.match?(/Call|Super|Yield/)
    return :literal if name.match?(/Integer|Float|String|Symbol|Array|Hash|Range|Rational|True|False|Nil|Regular/)
    return :variable if name.match?(/Variable|Constant|Parameter|Self/)
    return :control if name.match?(/If|Unless|While|Until|Case|When|For|Return|Break|Next|Begin|Rescue|And|Or/)
    return :def if name.match?(/Def|Class|Module|Block|Lambda/)

    :other
  end

  def ast_detail(node)
    %i[name operator value unescaped].each do |field|
      next unless node.respond_to?(field)

      v = node.public_send(field)
      next if v.nil? || v.is_a?(Prism::Node)

      return v.is_a?(String) ? v.inspect : v.to_s
    end
    nil
  rescue StandardError
    nil
  end

  # Prism's tree for +code+, laid out top-down: a leaf takes the next
  # column, a parent sits over its children; the edge says which field
  def ast_svg(code, max_nodes: 70)
    require "prism"
    result = Prism.parse(code)
    count = 0
    build = lambda do |node, edge|
      count += 1
      return nil if count > max_nodes

      kids = []
      # deconstruct_keys(nil): every field by name, the way pattern
      # matching sees the node
      node.deconstruct_keys(nil).each do |name, value|
        case value
        when Prism::Node then kids << [value, name.to_s]
        when Array then value.each_with_index { |v, i| kids << [v, "#{name}[#{i}]"] if v.is_a?(Prism::Node) }
        end
      end
      label = node.class.name.to_s.split("::").last.sub(/Node\z/, "")
      AstNode.new(label, ast_detail(node), edge, kids.filter_map { |k, e| build.(k, e) }, 0, 0, 0, ast_kind(node))
    end
    root = build.(result.value, "")
    # program → statements is noise for a short snippet: start at the body
    root = root.children.first if root.label == "Program" && root.children.size == 1
    root = root.children.first if root.label == "Statements" && root.children.size == 1
    col = 0
    gap_x = 18
    layout = lambda do |n, depth|
      n.w = [text_w(n.label, 12), text_w(n.detail.to_s, 12)].max + 16
      n.y = 16 + depth * 74
      if n.children.empty?
        n.x = col + n.w / 2
        col += n.w + gap_x
      else
        n.children.each { |c| layout.(c, depth + 1) }
        n.x = (n.children.first.x + n.children.last.x) / 2.0
        if n.x - n.w / 2 < col - (n.children.sum { |c| c.w + gap_x })
          n.x = n.x
        end
      end
    end
    layout.(root, 0)
    nodes = []
    walk = ->(n) { nodes << n; n.children.each { |c| walk.(c) } }
    walk.(root)
    min_x = nodes.map { |n| n.x - n.w / 2 }.min
    shift = 10 - min_x
    nodes.each { |n| n.x += shift }
    width = nodes.map { |n| n.x + n.w / 2 }.max + 10
    height = nodes.map(&:y).max + 52
    svg = Svg.new(width, height, "#{t("mscAstAlt", "Syntax tree")}: #{describe_ast(root)}")
    nodes.each do |n|
      n.children.each do |c|
        svg << "<line x1='#{n.x.round(1)}' y1='#{n.y + 38}' x2='#{c.x.round(1)}' y2='#{c.y}' stroke='#b6ad98' stroke-width='1.4'/>"
        mx = n.x + (c.x - n.x) * 0.7
        my = n.y + 38 + (c.y - n.y - 38) * 0.7
        svg << "<text x='#{mx.round(1)}' y='#{my.round(1)}' font-size='10' fill='#6b6355' text-anchor='middle' " \
               "paint-order='stroke' stroke='#fbf9f4' stroke-width='3'>#{esc(c.edge)}</text>"
      end
    end
    nodes.each do |n|
      color = NODE_COLORS[n.kind]
      h = n.detail ? 38 : 26
      svg << "<rect x='#{(n.x - n.w / 2).round(1)}' y='#{n.y}' width='#{n.w.round(1)}' height='#{h}' rx='6' fill='#fff' stroke='#{color}' stroke-width='1.8'/>"
      svg << "<text x='#{n.x.round(1)}' y='#{n.y + 17}' text-anchor='middle' font-size='12' font-weight='bold' fill='#{color}'>#{esc(n.label)}</text>"
      svg << "<text x='#{n.x.round(1)}' y='#{n.y + 32}' text-anchor='middle' font-size='12' fill='#1e2229'>#{esc(n.detail)}</text>" if n.detail
    end
    svg
  end

  def describe_ast(node)
    inner = node.children.map { |c| describe_ast(c) }.join(", ")
    head = node.detail ? "#{node.label} #{node.detail}" : node.label
    inner.empty? ? head : "#{head} (#{inner})"
  end

  # ---------- VALUE: the 32-bit word behind an object ----------

  # what the word of +obj+ is on this Ruby (wasm32, no flonum:
  # include/ruby/internal/special_consts.h): object_id IS the word for the
  # special constants (gc.c answers LONG2NUM(obj)); a heap object's word is
  # its address (ObjectSpace.dump)
  def value_word(obj)
    require "objspace"
    # a special constant dumps as a bare JSON value, a heap object as a Hash
    dump = JSON.parse(ObjectSpace.dump(obj))
    if dump.is_a?(Hash) && dump["address"]
      [Integer(dump["address"]), "pointer", dump]
    else
      kind = case obj
             when Integer then "fixnum"
             when Symbol then "symbol"
             when Float then "flonum"
             else obj.inspect
             end
      [obj.object_id & WORD_MASK, kind, nil]
    end
  end

  # the width of a VALUE here: 32 bits on wasm32, 64 on a laptop
  WORD_BITS = [0].pack("J").bytesize * 8
  WORD_MASK = (1 << WORD_BITS) - 1

  def value_svg(objects)
    rows = objects.map { |obj| [obj, *value_word(obj)] }
    bits_n = WORD_BITS
    cell = bits_n > 32 ? 10 : 16
    left = 150
    row_h = 74
    width = left + bits_n * cell + 20
    svg = Svg.new(width, rows.size * row_h + 34, "")
    alts = []
    bits_n.times do |i|
      bit = bits_n - 1 - i
      svg << "<text x='#{left + i * cell + cell / 2}' y='16' font-size='9' text-anchor='middle' fill='#6b6355'>#{bit}</text>" if (bit % 8).zero? || bit < 4
    end
    rows.each_with_index do |(obj, word, kind, dump), r|
      y = 24 + r * row_h
      svg << "<text x='8' y='#{y + 15}' font-size='14' font-weight='bold' fill='#1e2229'>#{esc(Microscope.short(obj, 17))}</text>"
      tag_bits = { "fixnum" => 1, "flonum" => 2, "pointer" => 0 }.fetch(kind, 8)
      bits = word.to_s(2).rjust(bits_n, "0")
      bits.each_char.with_index do |b, i|
        bit = bits_n - 1 - i
        tag = bit < tag_bits
        fill = tag ? "#f6c9bd" : (b == "1" ? "#e8e1cf" : "#fff")
        svg << "<rect x='#{left + i * cell}' y='#{y}' width='#{cell}' height='22' fill='#{fill}' stroke='#b6ad98' stroke-width='0.8'/>"
        svg << "<text x='#{left + i * cell + cell / 2.0}' y='#{y + 16}' text-anchor='middle' font-size='#{cell > 12 ? 12 : 10}' fill='#{tag ? "#bd2d00" : "#1e2229"}'>#{b}</text>"
      end
      explain = case kind
                when "fixnum" then format(t("mscValFixnum", "Fixnum: the number shifted left, tag bit 1 → (%d << 1) | 1 = 0x%x"), obj, word)
                when "symbol" then format(t("mscValSymbol", "static Symbol: its ID << 8, tag 0x0e → 0x%x"), word)
                when "flonum" then format(t("mscValFlonum", "Flonum: the Float packed into the word itself, tag bits 10 → 0x%x"), word)
                when "pointer"
                  format(t("mscValPointer", "a pointer to a %s in a %d-byte slot at 0x%x (low bits 0: slots are aligned)"),
                         dump["type"], dump["slot_size"].to_i, word)
                else format(t("mscValSpecial", "%s is a constant word: 0x%02x (special_consts.h)"), obj.inspect, word)
                end
      svg << "<text x='#{left}' y='#{y + 40}' font-size='12' fill='#4e5560'>#{esc(explain)}</text>"
      svg << "<text x='#{left}' y='#{y + 56}' font-size='11' fill='#6b6355'>= 0x#{word.to_s(16).rjust(bits_n / 4, "0")}</text>"
      alts << "#{obj.inspect}: #{explain}"
    end
    svg.instance_variable_set(:@alt, alts.join(". "))
    svg
  end

  # ---------- slots ----------

  def slots_svg(objects)
    require "objspace"
    rows = objects.map { |obj| [obj, JSON.parse(ObjectSpace.dump(obj)), ObjectSpace.memsize_of(obj)] }
    pools = slot_sizes
    scale = 500.0 / pools.max
    row_h = 70
    width = 40 + pools.max * scale + 230
    svg = Svg.new(width, rows.size * row_h + 20, "")
    alts = []
    rows.each_with_index do |(obj, dump, memsize), r|
      y = 12 + r * row_h
      slot = dump["slot_size"].to_i
      embedded = dump["embedded"]
      label = Microscope.short(obj, 30)
      svg << "<text x='10' y='#{y + 12}' font-size='12' font-weight='bold' fill='#1e2229'>#{esc(label)}</text>"
      pools.each do |size|
        svg << "<rect x='10' y='#{y + 18}' width='#{(size * scale).round(1)}' height='24' fill='none' stroke='#d8d1c1' stroke-dasharray='3 3'/>" if size >= slot
      end
      color = embedded == false ? "#00639a" : "#2c7a2c"
      svg << "<rect x='10' y='#{y + 18}' width='#{(slot * scale).round(1)}' height='24' fill='#{color}' fill-opacity='0.18' stroke='#{color}' stroke-width='1.6'/>"
      svg << "<rect x='10' y='#{y + 18}' width='#{(12 * scale).round(1)}' height='24' fill='#{color}' fill-opacity='0.35'/>"
      svg << "<text x='#{(14 + slot * scale).round(1)}' y='#{y + 35}' font-size='11' fill='#1e2229'>#{slot} B</text>"
      heap = memsize - slot
      text = if embedded == false
               format(t("mscSlotHeap", "%s in a %d-byte slot, its contents on the malloc heap: +%d B"), dump["type"], slot, heap)
             elsif heap.positive?
               format(t("mscSlotExtra", "%s in a %d-byte slot, +%d B outside it"), dump["type"], slot, heap)
             else
               format(t("mscSlotEmbedded", "%s embedded: all of it in its %d-byte slot"), dump["type"], slot)
             end
      if embedded == false
        hx = 40 + pools.max * scale
        svg << "<line x1='#{(10 + 6 * scale).round(1)}' y1='#{y + 30}' x2='#{hx}' y2='#{y + 30}' stroke='#00639a' stroke-width='1.4' marker-end='url(#a)'/>"
        svg << "<rect x='#{hx}' y='#{y + 20}' width='#{[[heap / 3.0, 30].max, 200].min.round(1)}' height='20' fill='#00639a' fill-opacity='0.3' stroke='#00639a'/>"
      end
      svg << "<text x='10' y='#{y + 58}' font-size='11' fill='#4e5560'>#{esc(text)}</text>"
      alts << "#{label}: #{text}"
    end
    svg << "<defs><marker id='a' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' markerHeight='7' orient='auto'><path d='M0,0 L10,5 L0,10 z' fill='#00639a'/></marker></defs>"
    svg.instance_variable_set(:@alt, alts.join(". "))
    svg
  end

  # the size pools of this Ruby's heap (gc/default/default.c: HEAP_COUNT
  # pools, each slot twice the last): 24 to 384 bytes on wasm32
  def slot_sizes
    (0...GC::INTERNAL_CONSTANTS[:HEAP_COUNT]).map { |i| GC.stat_heap(i, :slot_size) }
  end

  # ---------- a bar chart ----------

  def bars_svg(data, unit: "B", title: nil)
    data = data.to_a
    max = data.map { |_, v| v.to_f }.max
    max = 1.0 if max.nil? || max.zero?
    bar_w = [[600.0 / [data.size, 1].max - 6, 12].max, 46].min
    height = 220
    width = data.size * (bar_w + 6) + 60
    svg = Svg.new(width, height + (title ? 20 : 0), "#{title} " + data.map { |k, v| "#{k}: #{v} #{unit}" }.join(", "))
    top = title ? 20 : 0
    svg << "<text x='10' y='14' font-size='12' font-weight='bold' fill='#1e2229'>#{esc(title)}</text>" if title
    data.each_with_index do |(k, v), i|
      h = (v.to_f / max * 150).round(1)
      x = 40 + i * (bar_w + 6)
      y = top + 170 - h
      jump = i.positive? && v != data[i - 1][1]
      color = jump ? "#bd2d00" : "#2c7a2c"
      svg << "<rect x='#{x}' y='#{y}' width='#{bar_w.round(1)}' height='#{h}' fill='#{color}' fill-opacity='0.7'/>"
      svg << "<text x='#{(x + bar_w / 2).round(1)}' y='#{y - 4}' font-size='10' text-anchor='middle' fill='#1e2229'>#{v}</text>"
      svg << "<text x='#{(x + bar_w / 2).round(1)}' y='#{top + 186}' font-size='10' text-anchor='middle' fill='#4e5560'>#{esc(k)}</text>"
    end
    svg << "<line x1='36' y1='#{top + 170}' x2='#{width - 10}' y2='#{top + 170}' stroke='#1e2229'/>"
    svg
  end

  # ---------- method lookup, step by step ----------

  # the chain Ruby searches for +obj+.+mid+ (vm_method.c search_method):
  # the singleton class if the object has one of its own, then the
  # ancestors - an included module is an iclass in the chain, a prepended
  # one comes before the class (whose methods move to its origin)
  def lookup_chain(obj)
    # (asking for singleton_class makes one if there was none: a picture
    # leaves it out unless it holds methods or extended modules)
    own = !obj.singleton_methods(false).empty? ||
          (obj.singleton_class.ancestors - obj.class.ancestors - [obj.singleton_class]).any?
    chain = obj.singleton_class.ancestors
    chain = chain.drop(1) unless own || obj.is_a?(Module)
    chain
  end

  def lookup_frames(obj, mid)
    chain = lookup_chain(obj)
    found = chain.index { |m| m.method_defined?(mid, false) || m.private_method_defined?(mid, false) }
    supers = found ? chain.each_index.select { |i| i > found && (chain[i].method_defined?(mid, false) || chain[i].private_method_defined?(mid, false)) } : []
    frames = []
    upto = found || chain.size - 1
    (0..upto).each do |i|
      frames << { "html" => lookup_svg(obj, mid, chain, i, found, supers, i == found).to_svg,
                  "note" => i == found ? ["lookupFound", mid.to_s, label_of(chain[i])] : ["lookupMiss", mid.to_s, label_of(chain[i])] }
    end
    frames << { "html" => lookup_svg(obj, mid, chain, upto, found, supers, true, final: true).to_svg,
                "note" => found ? ["lookupDone", mid.to_s, label_of(chain[found]), supers.map { |s| label_of(chain[s]) }.join(" → ")] :
                                  ["lookupNone", mid.to_s] }
    frames
  end

  def label_of(mod)
    if mod.singleton_class?
      "#<Class:#{Microscope.short(mod.attached_object, 20)}>"
    else
      mod.to_s
    end
  end

  def lookup_svg(obj, mid, chain, at, found, supers, hit, final: false)
    box_w = 300
    row = 50
    width = box_w + 260
    svg = Svg.new(width, 70 + chain.size * row, "")
    svg << "<defs><marker id='m' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' markerHeight='7' orient='auto'><path d='M0,0 L10,5 L0,10 z' fill='#4e5560'/></marker></defs>"
    svg << "<rect x='10' y='8' width='#{box_w}' height='34' rx='6' fill='#fff' stroke='#1e2229' stroke-width='1.8'/>"
    svg << "<text x='20' y='30' font-size='13' font-weight='bold'>#{esc(Microscope.short(obj, 26))}.#{esc(mid)}</text>"
    svg << "<text x='#{box_w + 20}' y='30' font-size='11' fill='#6b6355'>klass →</text>"
    chain.each_with_index do |mod, i|
      y = 56 + i * row
      kind = if mod.singleton_class? then "singleton class"
             elsif mod.is_a?(Class) then "class"
             else "module (iclass)"
             end
      defines = mod.method_defined?(mid, false) || mod.private_method_defined?(mid, false)
      stroke = if final && i == found then "#bd2d00"
               elsif i == at && !final then (hit ? "#bd2d00" : "#e2b034")
               elsif i < at || final && found && i < found then "#b6ad98"
               else "#4e5560"
               end
      fill = if i == found && (final || hit) then "#fde6df"
             elsif supers.include?(i) && final then "#fdf3dc"
             else "#fff"
             end
      svg << "<line x1='40' y1='#{y - 14}' x2='40' y2='#{y}' stroke='#4e5560' stroke-width='1.4' marker-end='url(#m)'/>"
      svg << "<rect x='10' y='#{y}' width='#{box_w}' height='34' rx='5' fill='#{fill}' stroke='#{stroke}' stroke-width='#{i == at ? 2.6 : 1.4}'/>"
      svg << "<text x='20' y='#{y + 15}' font-size='13' font-weight='bold' fill='#1e2229'>#{esc(label_of(mod))}</text>"
      svg << "<text x='20' y='#{y + 29}' font-size='10' fill='#6b6355'>#{kind}#{i.zero? ? "" : " · super"}</text>"
      mark = defines ? "✓ #{mid}" : "–"
      svg << "<text x='#{box_w + 20}' y='#{y + 21}' font-size='12' fill='#{defines ? "#bd2d00" : "#b6ad98"}'>#{esc(mark)}#{final && supers.include?(i) ? "  (super)" : ""}</text>"
    end
    svg
  end

  # ---------- garbage collection, mark and sweep ----------

  GcNode = Struct.new(:id, :obj, :label, :refs, :x, :y)

  # +roots+: names => objects (what the stack and globals hold); +heap+:
  # more objects to show (garbage among them). The edges are
  # ObjectSpace.reachable_objects_from - the GC's own marking function
  # (gc_mark_children) run for one object; classes are left out.
  def gc_frames(roots, heap)
    require "objspace"
    nodes = {}
    order = []
    add = lambda do |obj|
      next nil if obj.is_a?(Module) || obj.nil? || obj == true || obj == false || obj.is_a?(Integer) || obj.is_a?(Symbol)
      # VM-internal objects (shapes, imemos) are left out of the picture
      next nil if defined?(ObjectSpace::InternalObjectWrapper) && obj.is_a?(ObjectSpace::InternalObjectWrapper)
      next nodes[obj.__id__] if nodes.key?(obj.__id__)
      return nil if nodes.size >= 24

      node = GcNode.new(nodes.size, obj, Microscope.short(obj, 16), [], 0, 0)
      nodes[obj.__id__] = node
      order << node
      kids = Array(ObjectSpace.reachable_objects_from(obj))
      node.refs = kids.filter_map { |k| add.(k) }.uniq
      node
    end
    root_nodes = roots.map { |name, obj| [name.to_s, add.(obj)] }
    heap.each { |obj| add.(obj) }
    # layout: columns by depth from the roots, the rest at the right
    depth = {}
    queue = root_nodes.map(&:last).compact
    queue.each { |n| depth[n.id] = 0 }
    marked_order = []
    until queue.empty?
      n = queue.shift
      marked_order << n
      n.refs.each do |k|
        next if depth.key?(k.id)

        depth[k.id] = depth[n.id] + 1
        queue << k
      end
    end
    cols = Hash.new(0)
    garbage = order.reject { |n| depth.key?(n.id) }
    gcol = (depth.values.max || 0) + 1
    # the garbage gets columns of its own, by depth from where it starts
    gdepth = {}
    garbage.each do |start|
      next if gdepth.key?(start.id)

      gdepth[start.id] = 0
      queue = [start]
      until queue.empty?
        n = queue.shift
        n.refs.each do |k|
          next if depth.key?(k.id) || gdepth.key?(k.id)

          gdepth[k.id] = gdepth[n.id] + 1
          queue << k
        end
      end
    end
    last_col = gcol
    order.each do |n|
      d = depth.key?(n.id) ? depth[n.id] : gcol + gdepth[n.id]
      last_col = d if d > last_col
      n.x = 130 + d * 165
      n.y = 20 + cols[d] * 52
      cols[d] += 1
    end
    width = 130 + (last_col + 1) * 165
    height = [cols.values.max.to_i, roots.size].max * 52 + 40
    frames = []
    states = Hash.new(:white)
    snap = lambda do |note, swept: false|
      frames << { "html" => gc_svg(root_nodes, order, states, width, height, swept).to_svg, "note" => note }
    end
    snap.(["gcStart", order.size.to_s, root_nodes.size.to_s])
    marked_order.each do |n|
      states[n.id] = :black
      n.refs.each { |k| states[k.id] = :grey unless states[k.id] == :black }
      snap.(["gcMark", n.label, n.refs.size.to_s])
    end
    snap.(["gcSweep", garbage.size.to_s, garbage.map(&:label).join(", ")], swept: true)
    frames
  end

  def gc_svg(roots, order, states, width, height, swept)
    svg = Svg.new(width, height, "")
    svg << "<defs><marker id='g' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='6' markerHeight='6' orient='auto'><path d='M0,0 L10,5 L0,10 z' fill='#6b6355'/></marker></defs>"
    roots.each_with_index do |(name, node), i|
      y = 20 + i * 52
      svg << "<rect x='8' y='#{y}' width='80' height='32' rx='5' fill='#1e2229'/>"
      svg << "<text x='48' y='#{y + 21}' text-anchor='middle' font-size='12' fill='#f5f1e8'>#{esc(name)}</text>"
      svg << "<line x1='88' y1='#{y + 16}' x2='#{node.x - 2}' y2='#{node.y + 16}' stroke='#1e2229' stroke-width='1.6' marker-end='url(#g)'/>" if node
    end
    order.each do |n|
      n.refs.each do |k|
        svg << "<line x1='#{n.x + 140}' y1='#{n.y + 16}' x2='#{k.x - 2}' y2='#{k.y + 16}' stroke='#6b6355' stroke-width='1.2' marker-end='url(#g)'/>"
      end
    end
    order.each do |n|
      state = states[n.id]
      gone = swept && state == :white
      fill, stroke, text = case state
                           when :black then ["#1e2229", "#1e2229", "#f5f1e8"]
                           when :grey then ["#b6ad98", "#4e5560", "#1e2229"]
                           else ["#fff", "#b6ad98", "#1e2229"]
                           end
      if gone
        svg << "<rect x='#{n.x}' y='#{n.y}' width='140' height='32' rx='5' fill='none' stroke='#bd2d00' stroke-dasharray='4 3'/>"
        svg << "<text x='#{n.x + 70}' y='#{n.y + 14}' text-anchor='middle' font-size='10' fill='#bd2d00'>#{esc(t("mscFreed", "free slot"))}</text>"
        svg << "<text x='#{n.x + 70}' y='#{n.y + 27}' text-anchor='middle' font-size='10' fill='#bd2d00' text-decoration='line-through'>#{esc(n.label)}</text>"
      else
        svg << "<rect x='#{n.x}' y='#{n.y}' width='140' height='32' rx='5' fill='#{fill}' stroke='#{stroke}' stroke-width='1.5'/>"
        svg << "<text x='#{n.x + 70}' y='#{n.y + 21}' text-anchor='middle' font-size='12' fill='#{text}'>#{esc(n.label)}</text>"
      end
    end
    svg
  end
end

module Kernel
  private

  def microscope_show(kind, payload)
    app = defined?(ChunkyApp) && ChunkyApp.respond_to?(:instance) && ChunkyApp.instance
    app.add_microscope(kind, payload) if app && app.respond_to?(:add_microscope)
    $microscope_shown&.push([kind, payload])
  end

  def microscope_picture(svg)
    respond_to?(:show_image, true) ? show_image(svg.to_svg, alt: svg.alt_text) : $microscope_shown&.push([:image, svg])
    nil
  end

  # Prism's tokens of +code+
  def show_tokens(code) = microscope_picture(Microscope.tokens_svg(code))

  # Prism's syntax tree of +code+
  def show_ast(code) = microscope_picture(Microscope.ast_svg(code))

  # the 32-bit VALUE word of each object
  def show_value(*objects) = microscope_picture(Microscope.value_svg(objects))

  # the heap slot of each object
  def show_slots(*objects) = microscope_picture(Microscope.slots_svg(objects))

  # a bar chart: { label => number }
  def show_bars(data, unit: "B", title: nil) = microscope_picture(Microscope.bars_svg(data, unit: unit, title: title))

  # +code+ compiled and run by YARV one instruction at a time, below the cell
  def show_yarv(code)
    data = Microscope::Yarv.new(code).run
    microscope_show(:yarv, data)
    data["same"] ? nil : data["real"]
  end

  # how Ruby finds obj.mid, class by class
  def show_lookup(obj, mid)
    microscope_show(:flip, { "frames" => Microscope.lookup_frames(obj, mid.to_sym), "kind" => "lookup" })
    obj.method(mid).owner
  rescue NameError
    nil
  end

  # mark and sweep: +roots+ (names => objects) and more objects on the heap
  def show_gc(roots, *heap)
    microscope_show(:flip, { "frames" => Microscope.gc_frames(roots, heap), "kind" => "gc" })
    nil
  end
end
