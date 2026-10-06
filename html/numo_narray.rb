# Numo::NArray in pure Ruby, for the browser. Numo (numo-narray-alt) is
# Ruby's NumPy: n-dimensional arrays of numbers, written in C - which
# ruby.wasm cannot load. Rumale (lesson 29) is pure Ruby on top of it, so
# this file stands in for the C: the same classes, methods and printing,
# for what Rumale's estimators and the lesson use, so that the lesson's code
# runs unchanged with the real gem on a computer.
#
#   a = Numo::DFloat[[1, 2], [3, 4]]
#   a[true, 1]            # => Numo::DFloat#shape=[2] [2, 4]
#   (a * 2).sum(axis: 0)  # => Numo::DFloat#shape=[2] [8, 12]
#
# The data is a flat Ruby Array in row-major order plus a shape. What is
# missing next to the real thing: views (a[0, true] is a copy - writing into
# it does not change a; a[0, true] = ... does), complex numbers, NaN
# handling, and speed - a dot product of a 100x64 and a 64x1500 matrix takes
# about a second here, a millisecond in C.
#
# main.rb serves it for require "numo/narray" and "numo/narray/alt", and
# BrowserGems counts both numo gems as built in, so a gem depending on them
# (rumale-core) installs without them.
module Numo
  class NArray
    class CastError < StandardError; end
    class ShapeError < StandardError; end
    class DimensionError < StandardError; end

    # for printing: how many characters a line may have, how many rows
    INSPECT_COLS = 80
    INSPECT_ROWS = 20

    attr_reader :shape

    class << self
      # the result type of mixing two types: the later one in this list
      def rank = 0
      def float? = false
      def integer? = false

      def upcast(other)
        other.rank > rank ? other : self
      end

      # one element, as this type stores it
      def cast_value(value) = value

      # the type a Ruby value asks for, as Numo::NArray[] infers it
      def type_for(values)
        types = values.map do |v|
          case v
          when NArray then v.class
          when Integer then Int32
          when Float then DFloat
          when true, false then Bit
          else RObject
          end
        end
        return DFloat if types.empty?

        types.reduce { |a, b| a.upcast(b) }
      end

      # Numo::DFloat[[1, 2], [3, 4]], Numo::DFloat[narray, narray]
      def [](*values)
        build(values)
      end

      def cast(obj)
        case obj
        when NArray
          return obj if obj.instance_of?(self)

          from_flat(obj.shape, obj.flat)
        when Array then build(obj)
        when Range then build(obj.to_a)
        else from_flat([], [obj])
        end
      end

      def asarray(obj)
        return obj if obj.is_a?(NArray) && (self == NArray || obj.instance_of?(self))

        obj = obj.to_a if obj.is_a?(Range)
        obj = [obj] unless obj.is_a?(Array) || obj.is_a?(NArray)
        self == NArray ? build(obj) : cast(obj)
      end

      def build(values)
        values = values.map { |v| v.is_a?(Range) ? v.to_a : v }
        target = self == NArray ? type_for(flatten_values(values)) : self
        shape = shape_of(values)
        flat = flatten_values(values)
        raise ShapeError, "the rows are not all the same length" unless flat.size == shape.reduce(1, :*)

        target.from_flat(shape, flat)
      end

      def from_flat(shape, flat, view: false)
        a = allocate
        a.send(:init, shape.dup, flat.map { |v| cast_value(v) }, view)
        a
      end

      # internal: flat data already of this type
      def wrap(shape, flat, view: false)
        a = allocate
        a.send(:init, shape, flat, view)
        a
      end

      def zeros(*shape) = new(*shape).fill(0)
      def ones(*shape) = new(*shape).fill(1)

      def new(*shape)
        shape = shape.flatten
        wrap(shape, Array.new(shape.reduce(1, :*), cast_value(0)))
      end

      def eye(n, m = n)
        a = zeros(n, m)
        [n, m].min.times { |i| a.flat[i * m + i] = cast_value(1) }
        a
      end

      def linspace(start, stop, num = 100)
        return wrap([1], [cast_value(start)]) if num == 1

        step = (stop - start).fdiv(num - 1)
        wrap([num], Array.new(num) { |i| cast_value(i == num - 1 ? stop : start + step * i) })
      end

      def arange(*args) = cast(Range.new(*args, true).to_a)

      def maximum(a, b) = elementwise(a, b) { |x, y| x >= y ? x : y }
      def minimum(a, b) = elementwise(a, b) { |x, y| x <= y ? x : y }

      def concatenate(arrays, axis: 0)
        arrays = arrays.map { |a| a.is_a?(NArray) ? a : NArray.asarray(a) }
        first, *rest = arrays
        first.concatenate(*rest, axis: axis)
      end

      def vstack(arrays)
        arrays = arrays.map { |a| a.ndim == 1 ? a.reshape(1, a.size) : a }
        cast(concatenate(arrays, axis: 0))
      end

      def hstack(arrays)
        axis = arrays.first.ndim == 1 ? 0 : 1
        cast(concatenate(arrays, axis: axis))
      end

      def dstack(arrays)
        arrays = arrays.map { |a| a.ndim == 1 ? a.reshape(1, a.size, 1) : a.expand_dims(2) }
        cast(concatenate(arrays, axis: 2))
      end

      def srand(seed = Random.new_seed)
        @random = Random.new(seed)
        seed
      end

      def random
        NArray.instance_variable_get(:@random) || NArray.instance_variable_set(:@random, Random.new)
      end

      private

      def shape_of(values)
        return [] unless values.is_a?(Array)
        return [0] if values.empty?

        first = values.first
        inner = first.is_a?(NArray) ? first.shape : shape_of(first)
        [values.size, *inner]
      end

      def flatten_values(values)
        values.flat_map do |v|
          case v
          when NArray then v.flat
          when Array then flatten_values(v)
          else [v]
          end
        end
      end

      def elementwise(a, b, &block)
        a = NArray.asarray(a) unless a.is_a?(NArray)
        b = b.is_a?(NArray) ? b : (b.is_a?(Array) ? NArray.asarray(b) : b)
        type = b.is_a?(NArray) ? a.class.upcast(b.class) : a.class.upcast(scalar_type(b))
        type = self if self != NArray && rank > type.rank
        a.send(:broadcast_with, b, type, &block)
      end

      def scalar_type(value)
        case value
        when Integer then Int32
        when Float then DFloat
        when true, false then Bit
        else RObject
        end
      end
    end

    def initialize(*shape)
      init(shape.flatten, Array.new(shape.flatten.reduce(1, :*), self.class.cast_value(0)), false)
    end

    # the flat data, row-major (not Numo's API: the stand-in's own methods
    # share it)
    def flat = @data

    def ndim = @shape.size
    def size = @data.size
    alias length size
    alias total size
    def empty? = @data.empty?

    def dup = self.class.wrap(@shape.dup, @data.dup)
    alias clone dup
    alias copy dup
    def inplace = self

    def view? = @view

    def to_a
      return @data.first if ndim.zero?

      nest(@data, @shape)
    end

    def to_f = @data.first.to_f
    def to_i = @data.first.to_i

    def coerce(other)
      [self.class.upcast(self.class.send(:scalar_type, other)).wrap([], [other]), self]
    end

    def fill(value)
      v = self.class.cast_value(value)
      @data.fill(v)
      self
    end

    # Numo::DFloat.new(5).seq => [0, 1, 2, 3, 4]
    def seq(start = 0, step = 1)
      @data.size.times { |i| @data[i] = self.class.cast_value(start + step * i) }
      self
    end
    alias indgen seq

    def rand(low = nil, high = nil)
      low, high = 0, low if high.nil? && !low.nil?
      low ||= 0
      high ||= 1
      rng = NArray.random
      @data.size.times do |i|
        @data[i] = self.class.cast_value(self.class.integer? ? rng.rand(low...high) : low + rng.rand * (high - low))
      end
      self
    end

    # normal distribution (Box-Muller)
    def rand_norm(mu = 0.0, sigma = 1.0)
      rng = NArray.random
      @data.size.times do |i|
        u = 1.0 - rng.rand
        @data[i] = self.class.cast_value(mu + sigma * Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math::PI * rng.rand))
      end
      self
    end

    # ---------- shape ----------

    def reshape(*new_shape)
      new_shape = new_shape.flatten
      unknown = new_shape.index { |d| d.nil? || d == -1 }
      if unknown
        known = new_shape.each_with_index.reject { |_, i| i == unknown }.map(&:first).reduce(1, :*)
        new_shape[unknown] = known.zero? ? 0 : size / known
      end
      raise ShapeError, "total size must be the same: #{size} vs #{new_shape.reduce(1, :*)}" unless new_shape.reduce(1, :*) == size

      self.class.wrap(new_shape, @data.dup)
    end

    def flatten = self.class.wrap([size], @data.dup, view: true)
    alias ravel flatten

    def expand_dims(axis)
      axis += ndim + 1 if axis.negative?
      self.class.wrap(@shape.dup.insert(axis, 1), @data.dup, view: true)
    end

    def squeeze(*axes)
      keep = @shape.each_with_index.reject { |d, i| d == 1 && (axes.empty? || axes.include?(i)) }.map(&:first)
      self.class.wrap(keep, @data.dup)
    end

    def transpose(*axes)
      return self.class.wrap(@shape.dup, @data.dup, view: true) if ndim < 2

      axes = (0...ndim).to_a.reverse if axes.empty?
      if ndim == 2
        rows, cols = @shape
        out = Array.new(size)
        i = 0
        while i < rows
          j = 0
          base = i * cols
          while j < cols
            out[j * rows + i] = @data[base + j]
            j += 1
          end
          i += 1
        end
        return self.class.wrap([cols, rows], out, view: true)
      end
      new_shape = axes.map { |a| @shape[a] }
      old_strides = strides
      out = []
      each_index_of(new_shape) do |idx|
        offset = 0
        idx.each_with_index { |v, k| offset += v * old_strides[axes[k]] }
        out << @data[offset]
      end
      self.class.wrap(new_shape, out, view: true)
    end

    # the array repeated: [1, 2].tile(2, 2) => [[1, 2, 1, 2], [1, 2, 1, 2]]
    def tile(*reps)
      n = [reps.size, ndim].max
      src = Array.new(n - ndim, 1) + @shape
      reps = Array.new(n - reps.size, 1) + reps
      new_shape = src.zip(reps).map { |d, r| d * r }
      src_strides = strides_of(src)
      out = []
      each_index_of(new_shape) do |idx|
        o = 0
        idx.each_with_index { |v, k| o += (v % src[k]) * src_strides[k] }
        out << @data[o]
      end
      self.class.wrap(new_shape, out)
    end

    def swapaxes(a, b)
      axes = (0...ndim).to_a
      axes[a], axes[b] = axes[b], axes[a]
      transpose(*axes)
    end

    def concatenate(*others, axis: 0)
      arrays = [self, *others.map { |o| o.is_a?(NArray) ? o : NArray.asarray(o) }]
      axis += ndim if axis.negative?
      type = arrays.map(&:class).reduce { |a, b| a.upcast(b) }
      outer = @shape[0...axis].reduce(1, :*)
      out = []
      outer.times do |o|
        arrays.each do |a|
          chunk = a.shape[axis..].reduce(1, :*)
          out.concat(a.flat[o * chunk, chunk])
        end
      end
      new_shape = @shape.dup
      new_shape[axis] = arrays.sum { |a| a.shape[axis] }
      type.from_flat(new_shape, out)
    end

    # flat positions of the diagonal of a square matrix
    def diag_indices
      n = @shape.min
      Int32.wrap([n], Array.new(n) { |i| i * @shape[1] + i })
    end

    def diagonal
      n = @shape.min
      self.class.wrap([n], Array.new(n) { |i| @data[i * @shape[1] + i] })
    end

    def trace = diagonal.sum

    # ---------- elements ----------

    def [](*index)
      if ndim == 2 && index.size == 2
        i, j = index
        if i.is_a?(Integer) && j.is_a?(Integer)
          return @data[norm(i, @shape[0]) * @shape[1] + norm(j, @shape[1])]
        elsif i.is_a?(Integer) && j == true
          cols = @shape[1]
          return self.class.wrap([cols], @data[norm(i, @shape[0]) * cols, cols], view: true)
        end
      end
      return @data[norm(index.first, size)] if index.size == 1 && index.first.is_a?(Integer)

      offsets, result_shape = locate(index)
      return @data[offsets.first] if result_shape.nil?

      self.class.wrap(result_shape, offsets.map { |o| @data[o] }, view: true)
    end

    def []=(*index, value)
      if index.size == ndim && index.all?(Integer)
        offset = 0
        index.each_with_index { |v, k| offset = offset * @shape[k] + norm(v, @shape[k]) }
        @data[offset] = self.class.cast_value(value)
        return
      end
      offsets, result_shape = locate(index)
      if value.is_a?(NArray) || value.is_a?(Array)
        value = NArray.asarray(value) if value.is_a?(Array)
        values = value.send(:broadcast_to, result_shape || [])
        offsets.each_with_index { |o, k| @data[o] = self.class.cast_value(values[k]) }
      else
        v = self.class.cast_value(value)
        offsets.each { |o| @data[o] = v }
      end
    end

    def each(&block)
      return to_enum(:each) unless block

      @data.each(&block)
      self
    end

    def each_with_index
      return to_enum(:each_with_index) unless block_given?

      i = 0
      each_index_of(@shape) do |idx|
        yield @data[i], *idx
        i += 1
      end
      self
    end

    def map(&block)
      return to_enum(:map) unless block

      self.class.from_flat(@shape, @data.map(&block))
    end
    alias collect map

    def map_with_index
      out = []
      each_with_index { |v, *idx| out << yield(v, *idx) }
      self.class.from_flat(@shape, out)
    end

    # ---------- arithmetic ----------

    { :+ => :+, :- => :-, :* => :*, :** => :**, :% => :% }.each do |op, ruby|
      define_method(op) { |other| binary(other) { |x, y| x.send(ruby, y) } }
    end

    def /(other)
      binary(other) do |x, y|
        if x.is_a?(Integer) && y.is_a?(Integer)
          y.zero? ? 0 : (x.fdiv(y)).truncate   # C division: toward zero
        else
          x / y
        end
      end
    end

    def -@ = self.class.wrap(@shape.dup, @data.map(&:-@))
    def +@ = self
    def abs = self.class.wrap(@shape.dup, @data.map(&:abs))
    def floor = self.class.wrap(@shape.dup, @data.map(&:floor).map { |v| self.class.cast_value(v) })
    def ceil = self.class.wrap(@shape.dup, @data.map(&:ceil).map { |v| self.class.cast_value(v) })
    def round = self.class.wrap(@shape.dup, @data.map(&:round).map { |v| self.class.cast_value(v) })
    def square = self * self
    def reciprocal = DFloat.cast(1.0) / self

    def clip(min, max)
      self.class.wrap(@shape.dup, @data.map { |v| v < min ? self.class.cast_value(min) : (v > max ? self.class.cast_value(max) : v) })
    end

    # ---------- comparing ----------

    { eq: :==, ne: :!=, gt: :>, ge: :>=, lt: :<, le: :<= }.each do |name, ruby|
      define_method(name) do |other|
        broadcast_with(other, Bit) { |x, y| x.send(ruby, y) ? 1 : 0 }
      end
    end
    alias > gt
    alias >= ge
    alias < lt
    alias <= le

    def ==(other)
      other.is_a?(NArray) && other.shape == @shape && @data == other.flat.map { |v| v }
    end

    def nearly_eq(other) = broadcast_with(other, Bit) { |x, y| (x - y).abs <= 1e-12 * [x.abs, y.abs, 1].max ? 1 : 0 }
    alias close_to nearly_eq

    def isnan = Bit.wrap(@shape.dup, @data.map { |v| v.is_a?(Float) && v.nan? ? 1 : 0 })
    def isinf = Bit.wrap(@shape.dup, @data.map { |v| v.is_a?(Float) && v.infinite? ? 1 : 0 })

    # ---------- reductions ----------

    def sum(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, sum_type) { |vals| vals.sum }
    end

    def prod(*axes, axis: nil, keepdims: false)
      reduce_axes(axes, axis, keepdims, sum_type) { |vals| vals.reduce(1, :*) }
    end

    def mean(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, float_type) { |vals| vals.sum.fdiv(vals.size) }
    end

    # unbiased, like Numo's: divided by n - 1
    def var(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, float_type) do |vals|
        m = vals.sum.fdiv(vals.size)
        vals.sum { |v| (v - m)**2 }.fdiv(vals.size - 1)
      end
    end

    def stddev(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, float_type) do |vals|
        m = vals.sum.fdiv(vals.size)
        Math.sqrt(vals.sum { |v| (v - m)**2 }.fdiv(vals.size - 1))
      end
    end

    def rms(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, float_type) { |vals| Math.sqrt(vals.sum { |v| v * v }.fdiv(vals.size)) }
    end

    def max(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, self.class) { |vals| vals.max }
    end

    def min(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, self.class) { |vals| vals.min }
    end

    def ptp(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, self.class) { |vals| vals.max - vals.min }
    end

    def minmax(*axes, axis: nil) = [min(*axes, axis: axis), max(*axes, axis: axis)]

    def median(*axes, axis: nil, keepdims: false, nan: false)
      reduce_axes(axes, axis, keepdims, float_type) do |vals|
        s = vals.sort
        n = s.size
        n.odd? ? s[n / 2].to_f : (s[n / 2 - 1] + s[n / 2]).fdiv(2)
      end
    end

    # flat positions, as Numo's max_index gives them (argmax: along the axis)
    def max_index(axis: nil) = index_by(axis, flat: true) { |vals| best_index(vals, :>) }
    def min_index(axis: nil) = index_by(axis, flat: true) { |vals| best_index(vals, :<) }
    def argmax(axis: nil) = index_by(axis, flat: false) { |vals| best_index(vals, :>) }
    def argmin(axis: nil) = index_by(axis, flat: false) { |vals| best_index(vals, :<) }

    def cumsum(axis: nil)
      if axis.nil? || ndim == 1
        total = sum_type.cast_value(0)
        return sum_type.wrap([size], @data.map { |v| total += v })
      end
      along(axis) { |vals| t = 0; vals.map { |v| t += v } }
    end

    def sort(axis: nil)
      return self.class.wrap(@shape.dup, @data.sort) if ndim <= 1

      along(axis || ndim - 1, &:sort)
    end

    def sort_index(axis: nil)
      raise NotImplementedError, "sort_index of a #{ndim}-d array" if ndim > 1

      Int32.wrap([size], @data.each_with_index.sort_by { |v, i| [v, i] }.map(&:last))
    end

    def dot(other)
      other = NArray.asarray(other) unless other.is_a?(NArray)
      type = self.class.upcast(other.class)
      a = ndim == 1 ? reshape(1, size) : self
      b = other.ndim == 1 ? other.reshape(other.size, 1) : other
      m, k = a.shape
      k2, n = b.shape
      raise ShapeError, "shape1[1](=#{k}) != shape2[0](=#{k2})" unless k == k2

      # each row of a against each column of b, skipping a's zeros (pictures
      # and counts are mostly zeros)
      cols = k.zero? ? Array.new(n) { [] } : b.transpose.flat.each_slice(k).to_a
      zero = type.float? ? 0.0 : 0
      out = []
      m.times do |i|
        nz = []
        vals = []
        a.flat[i * k, k].each_with_index do |v, t|
          next if v.zero?

          nz << t
          vals << v
        end
        nnz = nz.size
        cols.each do |c|
          s = zero
          t = 0
          while t < nnz
            s += vals[t] * c[nz[t]]
            t += 1
          end
          out << s
        end
      end
      result = type.wrap([m, n], type.float? ? out.map!(&:to_f) : out)
      return result.flat.first if ndim == 1 && other.ndim == 1
      return result.reshape(n) if ndim == 1
      return result.reshape(m) if other.ndim == 1

      result
    end

    # ---------- printing ----------

    def inspect
      head = "#{self.class.name}#{'(view)' if @view}#shape=#{@shape.inspect.delete(' ')}"
      return "#{head}\n#{format_value(@data.first)}" if ndim.zero?

      "#{head}\n#{inspect_level(0, 0, 0)}"
    end

    def to_s = inspect

    def format_value(v)
      return v.inspect unless v.is_a?(Float)
      return "nan" if v.nan?
      return (v.positive? ? "inf" : "-inf") if v.infinite?

      Kernel.format("%g", v)
    end

    def format(fmt = nil)
      RObject.wrap(@shape.dup, @data.map { |v| fmt ? Kernel.format(fmt, v) : format_value(v) })
    end

    def format_to_a(fmt = nil) = format(fmt).to_a

    protected

    def broadcast_to(target_shape)
      return @data if @shape == target_shape
      return Array.new(target_shape.reduce(1, :*), @data.first) if size == 1

      src_shape = Array.new(target_shape.size - ndim, 1) + @shape
      if target_shape.size == 2
        rows, cols = target_shape
        return @data * rows if src_shape == [1, cols]                          # a row, repeated down
        return @data.flat_map { |v| Array.new(cols, v) } if src_shape == [rows, 1]   # a column, across
      end
      src_strides = strides_of(src_shape).each_with_index.map { |s, i| src_shape[i] == 1 ? 0 : s }
      out = []
      each_index_of(target_shape) do |idx|
        o = 0
        idx.each_with_index { |v, k| o += v * src_strides[k] }
        out << @data[o]
      end
      out
    end

    def broadcast_with(other, type, &block)
      if other.is_a?(NArray)
        if other.shape == @shape
          od = other.flat
          return type.wrap(@shape.dup, Array.new(size) { |i| type.cast_value(yield(@data[i], od[i])) })
        end
        if other.size == 1
          y = other.flat.first
          return type.wrap(@shape.dup, @data.map { |x| type.cast_value(yield(x, y)) }) if other.ndim <= ndim
        end
        if size == 1 && ndim <= other.ndim
          x = @data.first
          return type.wrap(other.shape.dup, other.flat.map { |y| type.cast_value(yield(x, y)) })
        end
        target = broadcast_shape(@shape, other.shape)
        a = broadcast_to(target)
        b = other.broadcast_to(target)
        return type.wrap(target, Array.new(a.size) { |i| type.cast_value(yield(a[i], b[i])) })
      end
      other = other.to_a if other.is_a?(Range)
      return broadcast_with(NArray.asarray(other), type, &block) if other.is_a?(Array)

      type.wrap(@shape.dup, @data.map { |x| type.cast_value(yield(x, other)) })
    end

    private

    def init(shape, data, view)
      @shape = shape
      @data = data
      @view = view
    end

    def binary(other, &block)
      type = if other.is_a?(NArray) then self.class.upcast(other.class)
             elsif other.is_a?(Array) then self.class.upcast(NArray.asarray(other).class)
             else self.class.upcast(self.class.send(:scalar_type, other))
             end
      type = Int32 if type == Bit
      if type.float?
        broadcast_with(other, type) { |x, y| block.call(x.to_f, y.to_f) }
      else
        broadcast_with(other, type, &block)
      end
    end

    def sum_type = self.class.float? || self.class == RObject ? self.class : Int64
    def float_type = self.class.float? ? self.class : DFloat

    def strides = strides_of(@shape)

    def strides_of(shape)
      s = 1
      shape.reverse.map { |d| (s, d = s * d, s).last }.reverse
    end

    def norm(i, n)
      j = i.negative? ? i + n : i
      raise IndexError, "index=#{i} out of shape[0]=#{n}" if j.negative? || j >= n

      j
    end

    def nest(data, shape)
      return data.dup if shape.size == 1

      step = shape[1..].reduce(1, :*)
      Array.new(shape.first) { |i| nest(data[i * step, step], shape[1..]) }
    end

    def each_index_of(shape)
      return yield([]) if shape.empty?
      return if shape.include?(0)

      idx = Array.new(shape.size, 0)
      loop do
        yield idx.dup
        k = shape.size - 1
        while k >= 0
          idx[k] += 1
          break if idx[k] < shape[k]

          idx[k] = 0
          k -= 1
        end
        break if k.negative?
      end
    end

    def broadcast_shape(a, b)
      n = [a.size, b.size].max
      a = Array.new(n - a.size, 1) + a
      b = Array.new(n - b.size, 1) + b
      a.zip(b).map do |x, y|
        raise ShapeError, "shape1=#{a} and shape2=#{b} cannot be broadcast" unless x == y || x == 1 || y == 1

        [x, y].max
      end
    end

    # positions for one dimension's index: [positions, keep the dimension?]
    def positions(index, n)
      case index
      when Integer then [[norm(index, n)], false]
      when true then [(0...n).to_a, true]
      when Range
        first = index.begin.nil? ? 0 : index.begin
        first += n if first.negative?
        last = index.end.nil? ? n - 1 : index.end
        last += n if last.negative?
        last -= 1 if index.exclude_end? && !index.end.nil?
        [(first..[last, n - 1].min).to_a, true]
      when Enumerator::ArithmeticSequence
        first = index.begin || 0
        first += n if first.negative?
        last = index.end.nil? ? n - 1 : index.end
        last += n if last.negative?
        last -= 1 if index.exclude_end? && !index.end.nil?
        [(first..[last, n - 1].min).step(index.step).to_a, true]
      when Bit then [index.where.flat, true]
      when NArray then [index.flat.map { |i| norm(i, n) }, true]
      when Array then [index.map { |i| norm(i, n) }, true]
      else raise IndexError, "cannot index with #{index.inspect}"
      end
    end

    # flat offsets and the result's shape (nil: a single element)
    def locate(index)
      if index.size == 1 && ndim != 1
        # one index into a many-dimensional array counts on the flat data
        pos, keep = positions(index.first, size)
        return [pos, keep ? [pos.size] : nil]
      end
      raise DimensionError, "#{index.size} indices for a #{ndim}-dimensional array" unless index.size == ndim

      per_dim = index.each_with_index.map { |ix, k| positions(ix, @shape[k]) }
      result_shape = per_dim.select(&:last).map { |pos, _| pos.size }
      s = strides
      offsets = [0]
      per_dim.each_with_index do |(pos, _), k|
        stride = s[k]
        offsets = offsets.flat_map { |o| pos.map { |p| o + p * stride } }
      end
      all_scalar = per_dim.none?(&:last)
      [offsets, all_scalar ? nil : result_shape]
    end

    def axes_from(axes, axis)
      list = axes.empty? ? axis : axes
      return nil if list.nil?

      Array(list).flatten.map { |a| a.negative? ? a + ndim : a }
    end

    # applies the block to each group of values that the axes collapse
    def reduce_axes(axes, axis, keepdims, type)
      list = axes_from(axes, axis)
      if list.nil? || list.sort == (0...ndim).to_a
        value = yield(@data)
        return type.wrap(Array.new(ndim, 1), [type.cast_value(value)]) if keepdims

        return type.cast_value(value)
      end
      kept = (0...ndim).reject { |k| list.include?(k) }
      out_shape = kept.map { |k| @shape[k] }
      groups = if ndim == 2 && @shape.all?(&:positive?)
                 # rows (axis 1) or columns (axis 0) of a table
                 list == [1] ? @data.each_slice(@shape[1]) : transpose.flat.each_slice(@shape[0])
               else
                 by_key = Hash.new { |h, key| h[key] = [] }
                 i = 0
                 each_index_of(@shape) do |idx|
                   by_key[kept.map { |k| idx[k] }] << @data[i]
                   i += 1
                 end
                 by_key.values
               end
      values = groups.map { |vals| type.cast_value(yield(vals)) }
      shape = keepdims ? @shape.each_with_index.map { |d, k| list.include?(k) ? 1 : d } : out_shape
      type.wrap(shape, values)
    end

    # the position of the first largest (:>) or smallest (:<) value; a NaN
    # never wins, as in C
    def best_index(vals, op)
      best = 0
      vals.each_with_index { |v, i| best = i if v.send(op, vals[best]) || (vals[best].is_a?(Float) && vals[best].nan?) }
      best
    end

    def index_by(axis, flat:)
      return yield(@data) if axis.nil?

      axis += ndim if axis.negative?
      kept = (0...ndim).reject { |k| k == axis }
      groups = Hash.new { |h, key| h[key] = [[], []] }
      i = 0
      each_index_of(@shape) do |idx|
        g = groups[kept.map { |k| idx[k] }]
        g[0] << @data[i]
        g[1] << i
        i += 1
      end
      Int32.wrap(kept.map { |k| @shape[k] }, groups.values.map { |vals, offs| (flat ? offs : (0...vals.size).to_a)[yield(vals)] })
    end

    # applies the block (Array -> Array) along one axis
    def along(axis)
      axis += ndim if axis.negative?
      moved = (0...ndim).to_a
      moved.delete(axis)
      moved << axis
      t = transpose(*moved)
      n = @shape[axis]
      data = t.flat.each_slice(n).flat_map { |vals| yield(vals) }
      back = Array.new(ndim)
      moved.each_with_index { |a, i| back[a] = i }
      self.class.from_flat(t.shape, data).transpose(*back).then { |r| self.class.wrap(r.shape, r.flat) }
    end

    def inspect_level(depth, offset, indent)
      n = @shape[depth]
      step = @shape[(depth + 1)..].reduce(1, :*)
      if depth == ndim - 1
        line = +"["
        n.times do |i|
          piece = format_value(@data[offset + i])
          if line.size + piece.size + 5 > INSPECT_COLS
            line << "..."
            break
          end
          line << piece << (i == n - 1 ? "" : ", ")
        end
        return line << "]"
      end
      rows = []
      n.times do |i|
        if i == INSPECT_ROWS
          rows << "#{' ' * (indent + 1)}..."
          break
        end
        rows << inspect_level(depth + 1, offset + i * step, indent + 1)
      end
      "[" + rows.each_with_index.map { |r, i| i.zero? ? r : (" " * (indent + 1)) + r }.join(", \n") + "]"
    end
  end

  # the element types: how each stores a value
  class Bit < NArray
    def self.rank = 1
    def self.integer? = true
    def self.cast_value(v) = (v == true || (v.is_a?(Numeric) && v != 0)) ? 1 : 0

    def where = Int32.wrap([count_true], @data.each_index.select { |i| @data[i] == 1 })

    def where2
      yes, no = @data.each_index.partition { |i| @data[i] == 1 }
      [Int32.wrap([yes.size], yes), Int32.wrap([no.size], no)]
    end

    def count_true(axis: nil) = axis.nil? ? @data.count(1) : sum(axis: axis)
    alias count count_true
    def count_false = @data.count(0)
    def all? = @data.all? { |v| v == 1 }
    def any? = @data.any? { |v| v == 1 }
    def none? = !any?
    def mask(narray) = narray[self]
    def ~ = Bit.wrap(@shape.dup, @data.map { |v| 1 - v })
    def &(other) = broadcast_with(other, Bit) { |x, y| x & y }
    def |(other) = broadcast_with(other, Bit) { |x, y| x | y }
    def ^(other) = broadcast_with(other, Bit) { |x, y| x ^ y }
  end

  class Int8 < NArray
    def self.rank = 2
    def self.integer? = true
    def self.cast_value(v) = v.to_i
  end

  class UInt8 < Int8
    def self.rank = 3
  end

  class Int16 < Int8
    def self.rank = 4
  end

  class UInt16 < Int8
    def self.rank = 5
  end

  class Int32 < Int8
    def self.rank = 6

    # how often each number occurs: [0, 1, 1, 3] => [1, 2, 0, 1]
    def bincount(weights = nil, minlength: 0)
      n = [@data.max.to_i + 1, minlength].max
      counts = Array.new(n, 0)
      @data.each_with_index { |v, i| counts[v] += weights ? weights[i] : 1 }
      weights ? DFloat.wrap([n], counts.map(&:to_f)) : UInt32.wrap([n], counts)
    end
  end

  class UInt32 < Int32
    def self.rank = 7
  end

  class Int64 < Int32
    def self.rank = 8
  end

  class UInt64 < Int32
    def self.rank = 9
  end

  class SFloat < NArray
    def self.rank = 10
    def self.float? = true

    def self.cast_value(v)
      v.is_a?(Float) ? v : Float(v)
    end
  end

  class DFloat < NArray
    def self.rank = 11
    def self.float? = true
    def self.cast_value(v) = v.is_a?(Float) ? v : Float(v)
    EPSILON = Float::EPSILON
    MAX = Float::MAX
    MIN = Float::MIN
    NAN = Float::NAN
    INFINITY = Float::INFINITY
  end

  class RObject < NArray
    def self.rank = 12
  end

  Int8::MAX = 127
  Int32::MAX = 2**31 - 1
  Int32::MIN = -2**31

  # math on whole arrays: Numo::NMath.sqrt(a), Numo::NMath.exp(a)
  module NMath
    module_function

    %i[sqrt exp log log2 log10 sin cos tan asin acos atan sinh cosh tanh asinh acosh atanh erf erfc cbrt].each do |name|
      define_method(name) do |x|
        if x.is_a?(NArray)
          type = x.class.float? ? x.class : DFloat
          type.wrap(x.shape.dup, x.flat.map { |v| Math.send(name, v.to_f) })
        else
          DFloat.wrap([], [Math.send(name, x.to_f)])
        end
      end
    end

    def log1p(x) = log(x + 1)
    def expm1(x) = exp(x) - 1

    def atan2(y, x)
      y = DFloat.cast(y) unless y.is_a?(NArray)
      y.send(:broadcast_with, x, DFloat) { |a, b| Math.atan2(a.to_f, b.to_f) }
    end
  end
end
