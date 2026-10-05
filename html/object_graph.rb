# frozen_string_literal: true

# show_objects: the object graph of some values as boxes and arrows, in the
# style of Python Tutor - names on the left, objects on the right, an arrow
# for every reference. Pure Ruby, no JS: the walk builds a graph
# description (ObjectGraph::Graph), the layout and the SVG are Ruby too, so
# the picture goes through the existing show_image path (to_data_url).
#
#   a = [1, "x"]; b = a
#   show_objects(a: a, b: b)              # names => values
#   show_objects(binding)                 # every local variable
#   show_objects({ a: a }, max_depth: 2)  # roots as a Hash, then options
#
# What is drawn as a box: every object that can change or hold references -
# Strings, Arrays, Hashes, Structs, Data, Sets, your own objects. Numbers,
# Symbols, nil, true and false are written into the slot that holds them
# (they are objects too, but immutable and shared; boxes for them would
# only be noise).
#
# The course page (html/main.rb), the check harness and the companion gem
# (gem/chunky_bacon/lib/chunky_bacon/object_graph.rb, a copy of this file -
# test/object_graph_test.rb keeps the two equal) all load this file.
module ObjectGraph
  OPTIONS = { max_depth: 6, max_nodes: 40, max_items: 10, max_text: 28 }.freeze

  # one line in a box: a label (index, key, @ivar, variable name) and either
  # an inline value (text) or a reference to another node (ref)
  Slot = Struct.new(:label, :text, :ref, :cut)

  # kind: :string, :array, :hash, :struct, :object, :set, :leaf
  Node = Struct.new(:nid, :oid, :title, :kind, :body, :slots, :more, :frozen, :depth,
                    :x, :y, :w, :h, :label_w)

  Graph = Struct.new(:roots, :nodes) do
    def to_svg = Svg.new(self).render

    # The picture in words, for the <img>'s alt (a screen reader cannot
    # follow arrows): "a → #1, b → #1. #1 Array: 0 → 1, 1 → #2. #2 String "x"."
    def describe
      names = roots.map { |s| "#{s.label} → #{slot_text(s)}" }.join(", ")
      boxes = nodes.map do |n|
        head = "##{n.nid + 1} #{n.title}#{n.frozen ? ' ❄' : ''}"
        rows = n.slots.map { |s| s.label.empty? ? slot_text(s) : "#{s.label} → #{slot_text(s)}" }
        rows << "… #{n.more} more" if n.more.positive?
        if rows.any? then "#{head}: #{rows.join(', ')}"
        elsif n.body then "#{head} #{n.body}"
        else head
        end
      end
      ([names] + boxes).reject(&:empty?).map { |part| "#{part}." }.join(" ")
    end

    private

    def slot_text(slot) = slot.ref ? "##{slot.ref + 1}" : slot.text.to_s
  end

  # an SVG that show_image takes as it is (ChunkyApp#image_data_url asks
  # for to_data_url first); alt_text says in words what it shows
  class Picture
    attr_reader :svg, :alt_text

    def initialize(svg, alt_text = "")
      @svg = svg
      @alt_text = alt_text
    end

    def to_s = @svg
    def to_data_url = "data:image/svg+xml;base64,#{[@svg.b].pack('m0')}"
    def inspect = "#<ObjectGraph::Picture #{@svg.bytesize} bytes>"
  end

  module_function

  # hide: names of a Binding's variables to leave out
  def graph(roots, hide: [], **options)
    Walker.new(roots_of(roots, hide), **OPTIONS, **options).call
  end

  def svg(roots, **options) = graph(roots, **options).to_svg

  # picture(a: a, max_depth: 2): without a Hash or Binding first, the
  # keywords are the names - except the options' own
  def picture(roots = nil, **options)
    if roots.nil?
      keys = OPTIONS.keys + [:hide]
      roots, options = options.except(*keys), options.slice(*keys)
    end
    graph = graph(roots, **options)
    Picture.new(graph.to_svg, graph.describe)
  end

  def roots_of(roots, hide = [])
    case roots
    when Binding
      names = roots.local_variables - hide
      names.reject { |n| n.start_with?("_") }.to_h { |n| [n, roots.local_variable_get(n)] }
    when Hash then roots
    else { "obj" => roots }
    end
  end

  # ---------------------------------------------------------------- walk
  class Walker
    def initialize(roots, max_depth:, max_nodes:, max_items:, max_text:)
      @roots = roots
      @max_depth = max_depth
      @max_nodes = max_nodes
      @max_items = max_items
      @max_text = max_text
      @nodes = []
      @by_oid = {}
      @queue = []
    end

    def call
      root_slots = @roots.map { |name, value| slot_for(name.to_s, value, 0) }
      until @queue.empty?
        node, obj = @queue.shift
        fill(node, obj)
      end
      Graph.new(root_slots, @nodes)
    end

    private

    # Numbers, Symbols, nil, true, false: written into the slot
    def inline?(obj)
      case obj
      when nil, true, false, Integer, Float, Symbol, Rational, Complex then true
      else false
      end
    rescue StandardError
      false
    end

    def slot_for(label, obj, depth)
      return Slot.new(label, short(safe_inspect(obj))) if inline?(obj)

      oid = obj.__id__
      if (node = @by_oid[oid])
        return Slot.new(label, nil, node.nid)
      end
      return Slot.new(label, "…", nil, true) if @nodes.size >= @max_nodes || depth >= @max_depth

      node = Node.new(@nodes.size, oid, class_name(obj), nil, nil, [], 0, frozen?(obj), depth)
      @nodes << node
      @by_oid[oid] = node
      @queue << [node, obj]
      Slot.new(label, nil, node.nid)
    end

    def fill(node, obj)
      d = node.depth + 1
      case obj
      when String
        node.kind = :string
        node.body = short(obj.inspect)
      when Array
        node.kind = :array
        items(obj.each_with_index, obj.size, node) { |(v, i)| slot_for(i.to_s, v, d) }
      when Hash
        node.kind = :hash
        items(obj.each_pair, obj.size, node) { |(k, v)| slot_for(key_label(k), v, d) }
      when Struct
        node.kind = :struct
        items(obj.each_pair, obj.size, node) { |(k, v)| slot_for(k.to_s, v, d) }
      when defined?(Data) && Data
        node.kind = :struct
        h = obj.to_h
        items(h.each_pair, h.size, node) { |(k, v)| slot_for(k.to_s, v, d) }
      when defined?(Set) && Set
        node.kind = :set
        items(obj.each, obj.size, node) { |v| slot_for("", v, d) }
      when Module, Range, Regexp, Proc, Method, Exception, IO, Time
        leaf(node, obj)
      else
        ivars = ivars_of(obj)
        if ivars.empty?
          leaf(node, obj)
        else
          node.kind = :object
          items(ivars.each, ivars.size, node) { |iv| slot_for(iv.to_s, ivar_get(obj, iv), d) }
        end
      end
    rescue StandardError => e
      node.kind = :leaf
      node.body = short("(#{e.class})")
    end

    def items(enum, size, node)
      enum.first(@max_items).each { |item| node.slots << yield(item) }
      node.more = [size - @max_items, 0].max
    end

    def leaf(node, obj)
      node.kind = :leaf
      text = safe_inspect(obj)
      node.body = short(text) unless text == "#<#{node.title}>"
    end

    def key_label(key)
      inline?(key) || key.is_a?(String) ? short(key.inspect, 14) : "#<#{class_name(key)}>"
    end

    def short(text, max = @max_text)
      text = text.to_s.gsub(/\s+/, " ")
      text.length > max ? "#{text[0, max - 1]}…" : text
    end

    # user classes may override these (or be a BasicObject), so the walk
    # asks Kernel directly
    KERNEL = %i[class frozen? inspect instance_variables instance_variable_get]
             .to_h { |m| [m, ::Kernel.instance_method(m)] }.freeze

    def kcall(name, obj, *args) = KERNEL[name].bind_call(obj, *args)

    def class_name(obj)
      kcall(:class, obj).name || kcall(:class, obj).inspect
    rescue StandardError
      "BasicObject"
    end

    def frozen?(obj)
      kcall(:frozen?, obj)
    rescue StandardError
      false
    end

    def ivars_of(obj)
      kcall(:instance_variables, obj)
    rescue StandardError
      []
    end

    def ivar_get(obj, name) = kcall(:instance_variable_get, obj, name)

    def safe_inspect(obj)
      obj.inspect.to_s
    rescue StandardError
      "#<#{class_name(obj)}>"
    end
  end

  # -------------------------------------------------------------- layout + SVG
  class Svg
    CHAR = 7.4        # width of one monospace character at 12px, a bit generous
    ROW = 22          # height of a slot row
    HEAD = 22         # height of a box's title bar
    PAD = 8
    COL_GAP = 70      # between columns: room for the arrows
    BOX_GAP = 16      # between boxes in one column
    DOT = 22          # width of a value cell that only holds an arrow's dot
    MARGIN = 12

    INK = "#1a1208"
    INK_SOFT = "#5f5247"
    RULE = "#c9d1da"
    HEAD_FILL = "#fdeee3"     # bacon fat
    STRING_FILL = "#eef2f6"   # code background
    FROZEN_FILL = "#dceaf8"
    FROZEN_LINE = "#2f6db5"
    ARROW = "#c14a2e"         # bacon
    FONT = "'Atkinson Hyperlegible Mono', ui-monospace, Consolas, Menlo, monospace"

    WIDE = /[ᄀ-ᅟ⺀-꓏가-힣豈-﫿︰-﹏＀-｠￠-￦\u{1F300}-\u{1FAFF}]/

    def initialize(graph)
      @g = graph
      @nodes = graph.nodes
    end

    def render
      layout
      out = +""
      out << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" ) <<
             %(viewBox="0 0 #{@width} #{@height}" font-family="#{FONT}" font-size="12">)
      out << %(<defs><marker id="og-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" ) <<
             %(orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#{ARROW}"/></marker></defs>)
      out << %(<rect width="100%" height="100%" fill="#fff"/>)
      out << frame_svg
      @nodes.each { |n| out << node_svg(n) }
      edges.each { |e| out << e }
      out << "</svg>"
    end

    private

    def tw(text) = text.to_s.each_char.sum { |c| c.match?(WIDE) ? CHAR * 2 : CHAR }

    def esc(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")

    def fmt(num) = (num.round(1) % 1).zero? ? num.round.to_s : num.round(1).to_s

    # ---- sizes
    def value_w(slot) = slot.ref ? DOT : [tw(slot.text) + 2 * PAD, DOT].max

    def size_slots(slots)
      label_w = slots.map { |s| tw(s.label) }.max.to_i
      label_w += 2 * PAD if label_w.positive?
      value_w = slots.map { |s| value_w(s) }.max.to_i
      [label_w, value_w]
    end

    def size_node(n)
      title_w = tw(n.title) + tw(id_text(n)) + (n.frozen ? 16 : 0) + 3 * PAD
      rows = n.slots.size + (n.more.positive? ? 1 : 0)
      if n.slots.empty?
        n.label_w = 0
        body_w = n.body ? tw(n.body) + 2 * PAD : 0
        n.w = [title_w, body_w, 60].max
        n.h = HEAD + (n.body ? ROW : 0) + (n.more.positive? ? ROW : 0)
        n.h = HEAD + 10 if n.h == HEAD && n.kind != :leaf   # an empty Array or Hash
      else
        lw, vw = size_slots(n.slots)
        more_w = n.more.positive? ? tw("… #{n.more} more") + 2 * PAD : 0
        n.label_w = lw
        n.w = [title_w, lw + vw, more_w, 60].max
        n.h = HEAD + rows * ROW
      end
    end

    def id_text(n) = "##{n.nid + 1}"

    # Columns by distance from the names (the walk is breadth-first, so a
    # node's depth is its shortest path). In a column, every box wants to sit
    # level with the first slot pointing at it; boxes never overlap.
    def layout
      @nodes.each { |n| size_node(n) }
      fl, fv = size_slots(@g.roots)
      @frame = { x: MARGIN, y: MARGIN, w: [fl + [fv, 40].max, 60].max, label_w: fl }
      @frame[:h] = [@g.roots.size, 1].max * ROW
      @slot_pos = {} # [owner, index] => [x_dot, y]
      @g.roots.each_with_index do |_s, i|
        @slot_pos[[:frame, i]] = [@frame[:x] + @frame[:label_w] + DOT / 2.0, @frame[:y] + i * ROW + ROW / 2.0]
      end
      x = @frame[:x] + @frame[:w] + COL_GAP
      incoming = Hash.new { |h, k| h[k] = [] }
      @g.roots.each_with_index { |s, i| incoming[s.ref] << @slot_pos[[:frame, i]][1] if s.ref }

      max_y = @frame[:y] + @frame[:h]
      @nodes.group_by(&:depth).sort.each do |_depth, column|
        column.each { |n| n.x = x }
        cursor = MARGIN
        column.sort_by { |n| [incoming[n.nid].min || Float::INFINITY, n.nid] }.each do |n|
          want = (incoming[n.nid].min || cursor + HEAD / 2.0) - HEAD / 2.0
          n.y = [want, cursor].max
          cursor = n.y + n.h + BOX_GAP
          max_y = [max_y, n.y + n.h].max
          n.slots.each_with_index do |s, i|
            pos = [n.x + n.label_w + DOT / 2.0, n.y + HEAD + i * ROW + ROW / 2.0]
            @slot_pos[[n.nid, i]] = pos
            incoming[s.ref] << pos[1] if s.ref
          end
        end
        x += column.map(&:w).max + COL_GAP
      end
      @width = (x - COL_GAP + MARGIN).ceil
      @width = (@frame[:x] + @frame[:w] + MARGIN).ceil if @nodes.empty?
      @height = (max_y + MARGIN + 6).ceil
    end

    # ---- drawing
    def frame_svg
      f = @frame
      out = +%(<g class="frame">)
      out << %(<rect x="#{f[:x]}" y="#{f[:y]}" width="#{fmt f[:w]}" height="#{f[:h]}" fill="#fff" stroke="#{INK}" stroke-width="1.5" rx="3"/>)
      @g.roots.each_with_index do |s, i|
        y = f[:y] + i * ROW
        out << hline(f[:x], y, f[:w]) if i.positive?
        out << %(<text x="#{fmt f[:x] + f[:label_w] - PAD}" y="#{fmt y + 15}" text-anchor="end" fill="#{INK}" font-weight="bold">#{esc s.label}</text>)
        out << value_svg(s, f[:x] + f[:label_w], y)
      end
      out << vline(f[:x] + f[:label_w], f[:y], f[:h]) if @g.roots.any?
      out << "</g>"
    end

    def node_svg(n)
      fill = n.frozen ? FROZEN_FILL : (n.kind == :string ? STRING_FILL : HEAD_FILL)
      line = n.frozen ? FROZEN_LINE : INK
      out = +%(<g class="obj #{n.kind}">)
      out << %(<rect x="#{fmt n.x}" y="#{fmt n.y}" width="#{fmt n.w}" height="#{fmt n.h}" fill="#fff" stroke="#{line}" stroke-width="1.5" rx="3"/>)
      out << %(<path d="M#{fmt n.x + 0.75},#{fmt n.y + HEAD} v#{-HEAD + 3.75} q0,-3 3,-3 h#{fmt n.w - 7.5} q3,0 3,3 v#{HEAD - 3.75} z" fill="#{fill}"/>)
      out << hline(n.x, n.y + HEAD, n.w, line)
      title = n.frozen ? "#{n.title} ❄" : n.title
      out << %(<text x="#{fmt n.x + PAD}" y="#{fmt n.y + 15}" fill="#{n.frozen ? FROZEN_LINE : INK}" font-weight="bold">#{esc title}</text>)
      out << %(<text x="#{fmt n.x + n.w - PAD}" y="#{fmt n.y + 15}" text-anchor="end" fill="#{INK_SOFT}" font-size="10">#{id_text(n)}</text>)
      if n.slots.empty?
        out << %(<text x="#{fmt n.x + PAD}" y="#{fmt n.y + HEAD + 15}" fill="#{INK}">#{esc n.body}</text>) if n.body
      else
        n.slots.each_with_index do |s, i|
          y = n.y + HEAD + i * ROW
          out << hline(n.x, y, n.w) if i.positive?
          if n.label_w.positive?
            out << %(<text x="#{fmt n.x + n.label_w - PAD}" y="#{fmt y + 15}" text-anchor="end" fill="#{INK_SOFT}">#{esc s.label}</text>)
          end
          out << value_svg(s, n.x + n.label_w, y)
        end
        out << vline(n.x + n.label_w, n.y + HEAD, n.slots.size * ROW) if n.label_w.positive?
      end
      if n.more.positive?
        y = n.y + HEAD + n.slots.size * ROW
        out << hline(n.x, y, n.w)
        out << %(<text x="#{fmt n.x + PAD}" y="#{fmt y + 15}" fill="#{INK_SOFT}" font-style="italic">… #{n.more} more</text>)
      end
      out << "</g>"
    end

    def value_svg(slot, x, y)
      if slot.ref
        %(<circle cx="#{fmt x + DOT / 2.0}" cy="#{fmt y + ROW / 2.0}" r="3.5" fill="#{ARROW}"/>)
      else
        color = slot.cut ? INK_SOFT : INK
        %(<text x="#{fmt x + PAD}" y="#{fmt y + 15}" fill="#{color}">#{esc slot.text}</text>)
      end
    end

    def hline(x, y, w, color = RULE) = %(<path d="M#{fmt x},#{fmt y} h#{fmt w}" stroke="#{color}"/>)
    def vline(x, y, h) = %(<path d="M#{fmt x},#{fmt y} v#{fmt h}" stroke="#{RULE}"/>)

    # A forward reference (to a column further right) ends on the target's
    # left edge, level with its title. A reference back (a cycle, or to a
    # box in the same or an earlier column) leaves to the right and comes
    # back into the target's right edge.
    def edges
      out = []
      owners = [[:frame, @g.roots]] + @nodes.map { |n| [n.nid, n.slots] }
      owners.each do |owner, slots|
        src_x_edge = owner == :frame ? @frame[:x] + @frame[:w] : @nodes[owner].x + @nodes[owner].w
        slots.each_with_index do |s, i|
          next unless s.ref

          sx, sy = @slot_pos[[owner, i]]
          t = @nodes[s.ref]
          ty = t.y + HEAD / 2.0
          if t.x > src_x_edge
            ex = t.x - 1
            dx = [(ex - sx) / 2.0, 40].max
            d = "M#{fmt sx},#{fmt sy} C#{fmt sx + dx},#{fmt sy} #{fmt ex - dx},#{fmt ty} #{fmt ex},#{fmt ty}"
          else
            ex = t.x + t.w + 1
            out_x = [src_x_edge, ex].max + 46
            d = "M#{fmt sx},#{fmt sy} C#{fmt out_x},#{fmt sy} #{fmt out_x},#{fmt ty} #{fmt ex},#{fmt ty}"
          end
          out << %(<path d="#{d}" fill="none" stroke="#{ARROW}" stroke-width="1.6" marker-end="url(#og-arrow)" opacity="0.9"/>)
        end
      end
      out
    end
  end
end

# Wherever there is a show_image - the course's cells (html/main.rb), the
# check harness, the companion gem - the picture goes the way of any other
# image; in plain Ruby show_objects returns it.
module Kernel
  def show_objects(roots = nil, **options)
    picture = ObjectGraph.picture(roots, **options)
    return picture unless respond_to?(:show_image, true)

    show_image(picture)
    nil
  end
end
