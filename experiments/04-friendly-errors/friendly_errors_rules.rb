# The rule table of FriendlyErrors, in order: the first rule that returns a
# Finding wins. Each block gets a Context (friendly_errors.rb) and returns
# nil ("not mine") or find(message_key, values, at: [line, col, len], label:).
module FriendlyErrors
  class Context
    def word_at(n, name)
      t = text(n) or return [n, nil, nil]
      m = t.match(/(?<![\w@$.])#{Regexp.escape(name.to_s)}(?![\w?!])/) || t.match(Regexp.new(Regexp.escape(name.to_s)))
      m ? [n, m.begin(0), name.to_s.length] : [n, nil, nil]
    end

    def bare_call?(n, name)
      t = text(n) or return true
      t.match?(/(?<![\w@$.:])#{Regexp.escape(name.to_s)}(?![\w?!])/)
    end

    # the receiver expression of the failing call +meth+ on line n:
    # [start, length, expr] - for `.meth`, `x[...]` and operators
    def receiver_of(n, meth)
      t = text(n) or return nil
      meth = meth.to_s
      if meth.match?(/\A\w/)
        site = call_site(n, meth) or return nil
        start, dot, expr = site
        return [start, dot - start, expr]
      end
      cands = []
      if meth == "[]" || meth == "[]="
        t.enum_for(:scan, /\[/).each do
          p = Regexp.last_match.begin(0)
          next unless p.positive? && t[p - 1].match?(/[\w\])]/)

          s = receiver_start(t, p)
          cands << [s, p - s, t[s...p]]
        end
        return cands.find { |c| c[2].include?("[") } || cands.first
      end
      t.enum_for(:scan, /\s#{Regexp.escape(meth)}=?\s/).each do
        p = Regexp.last_match.begin(0)
        s = receiver_start(t, p)
        cands << [s, p - s, t[s...p]] if p > s
      end
      cands.first
    end

    # the value of a hash or array named +base+: from the binding, or the
    # literal it was assigned in this cell
    def collection(base)
      if (v = local(base))
        return v.first if v.first.is_a?(Hash) || v.first.is_a?(Array)
      end
      i = lines.rindex { |l| l.match?(/^\s*#{Regexp.escape(base)}\s*=\s*[{\[]/) } or return nil
      chunk = lines[i..].join("\n")
      if chunk.match?(/=\s*\{/)
        literal = chunk[/\{.*?\}/m].to_s
        keys = literal.scan(/(?<![:\w])(\w+):\s/).flatten.map(&:to_sym) +
               literal.scan(/:(\w+)\s*=>/).flatten.map(&:to_sym) +
               literal.scan(/"([^"]*)"\s*=>/).flatten
        keys.uniq.to_h { |k| [k, :literal] }
      else
        :array
      end
    end
  end

  # the top level of a cell is "main", an Object - for a learner that is
  # just "Ruby"
  def self.class_word(obj, lang = "en")
    return t_raw(:w_main, lang) if obj.equal?(TOPLEVEL_BINDING.receiver)

    obj.class.name || obj.class.to_s
  end

  # "list.find { |p| p.x }" -> "list.find" (block and argument contents out)
  def self.without_groups(expr)
    s = expr.dup
    nil while s.gsub!(/\{[^{}]*\}|\([^()]*\)/, "")
    s.strip
  end

  def self.args_expected(m, lang)
    if m[3]
      format(t_raw(:w_args, lang)[2], n: "#{m[2]}–#{m[3]}")
    elsif m[4]
      t(:w_min_args, lang, n: args_words(m[2], lang))
    else
      args_words(m[2], lang)
    end
  end

  def self.label_name(label)
    label.to_s.sub(/\A(block|rescue|ensure) in /, "").split(/[#.]/).last.to_s
  end

  # ================================================================ syntax
  rule :syn_interpolation, SyntaxError do |c|
    next unless c.diag(/embedded expression/)

    o = c.scan[:open].reverse.find { |b| b[:char] == "\#{" } or next
    find(:syn_interpolation_open, { line: o[:line] }, at: [o[:line], o[:col], 2], label: :lbl_open)
  end

  rule :syn_string, SyntaxError do |c|
    next unless c.diag(/unterminated (string|list|regexp)|meets end of file/)

    s = c.scan[:string] or next
    find(:syn_unterminated_string, { line: s[:line], quote: s[:quote] }, at: [s[:line], s[:col], 1], label: :lbl_open)
  end

  rule :syn_python_for, SyntaxError do |c|
    i = c.lines.index { |l| l.match?(/^\s*for\s+\w+\s+in\s+range\s*\(/) } or next
    col, len = c.column_of(i + 1, /for\s+\w+\s+in\s+range\s*\([^)]*\)/)
    find(:syn_python_for, {}, at: [i + 1, col, len])
  end

  rule :syn_python_colon, SyntaxError do |c|
    d = c.diag(/unexpected ':'/) or next
    t = c.text(d[:line]).to_s.rstrip
    next unless t.end_with?(":") && t.match?(/^\s*(def|if|elsif|else|while|until|for|class|module|unless)\b/)

    find(:syn_python_colon, { line: d[:line] }, at: [d[:line], t.length - 1, 1], label: :lbl_here)
  end

  rule :syn_plusplus, SyntaxError do |c|
    i = c.lines.index { |l| c.strip_comment(l).match?(/[\w\]]\s*(\+\+|--)\s*$/) } or next
    m = c.text(i + 1).match(/([\w@\[\]:]+)\s*(\+\+|--)/)
    find(:syn_plusplus, { var: m[1] }, at: [i + 1, m.begin(2), 2])
  end

  rule :syn_if_brace, SyntaxError do |c|
    i = c.lines.index { |l| l.match?(/^\s*(if|unless|while|until|elsif)\b.*\{\s*$/) } or next
    t = c.text(i + 1)
    find(:syn_if_brace, { kw: t[/\w+/] }, at: [i + 1, t.rindex("{"), 1], label: :lbl_here)
  end

  rule :syn_eq_gt, SyntaxError do |c|
    i = c.lines.index { |l| c.strip_comment(l).match?(/[^=!<>]=\s+[<>](?![<>=])/) } or next
    m = c.text(i + 1).match(/=(\s+)([<>])/)
    find(:syn_eq_gt, { line: i + 1, ch: m[2], op: "#{m[2]}=" }, at: [i + 1, m.begin(0), m[0].length], label: :lbl_here)
  end

  rule :syn_else_if, SyntaxError do |c|
    next unless c.diag(/expected an `end`/)

    i = c.lines.index { |l| l.match?(/^\s*else\s+if\b/) } or next
    col, len = c.column_of(i + 1, /else\s+if/)
    find(:syn_else_if, { line: i + 1 }, at: [i + 1, col, len], label: :lbl_here)
  end

  rule :syn_class_name, SyntaxError do |c|
    i = c.lines.index { |l| l.match?(/^\s*(class|module)\s+[a-z_]/) } or next
    m = c.text(i + 1).match(/(class|module)\s+([a-z_]\w*)/)
    cap = m[2].split("_").map(&:capitalize).join
    find(:syn_class_name, { kw: m[1], name: m[2], cap: cap }, at: [i + 1, m.begin(2), m[2].length], label: :lbl_here)
  end

  rule :syn_hash_rocket, SyntaxError do |c|
    d = c.diag(/between the hash key and value/) or next
    find(:syn_hash_rocket, { line: d[:line] }, at: [d[:line], d[:col], d[:len]], label: :lbl_here)
  end

  rule :syn_block_pipe, SyntaxError do |c|
    next unless c.diag(/block parameters to end with `\|`/)

    i = c.lines.index { |l| l.count("|").odd? && l.match?(/(\bdo|\{)\s*\|/) } or next
    find(:syn_block_pipe, { line: i + 1 }, at: [i + 1, c.text(i + 1).index("|"), 1], label: :lbl_open)
  end

  CLOSE_OF = { "(" => ")", "[" => "]", "{" => "}" }.freeze

  rule :syn_times_x, SyntaxError do |c|
    i = c.lines.index { |l| c.strip_comment(l).match?(/\d\s*[xX]\s*\d/) } or next
    m = c.text(i + 1).match(/([\w.]+)\s*([xX])\s*([\w.]+)/) or next
    find(:syn_times_x, { a: m[1], b: m[3] }, at: [i + 1, m.begin(2), 1], label: :lbl_here)
  end

  rule :syn_bracket, SyntaxError do |c|
    o = c.scan[:open].reject { |b| b[:char] == "\#{" }.last or next
    find(:syn_missing_close, { open: o[:char], close: CLOSE_OF[o[:char]], line: o[:line] },
         at: [o[:line], o[:col], 1], label: :lbl_open)
  end

  rule :syn_comma, SyntaxError do |c|
    d = c.diag(/`,` separator/) or next
    find(:syn_missing_comma, { line: d[:line] }, at: [d[:line], d[:col], 1], label: :lbl_here)
  end

  rule :syn_missing_end, SyntaxError do |c|
    d = c.diag(/expected an `end`|to end with `end`/) or next
    if (o = c.unclosed_openers.first)
      find(:syn_missing_end, { kw: o[:kw], line: o[:line] }, at: [o[:line], o[:col], o[:kw].length], label: :lbl_open)
    else
      kw = c.text(d[:line]).to_s[d[:col].to_i..].to_s[/\A\w+/] || "do"
      find(:syn_missing_end, { kw: kw, line: d[:line] }, at: [d[:line], d[:col], d[:len]], label: :lbl_open)
    end
  end

  rule :syn_extra_end, SyntaxError do |c|
    d = c.diag(/unexpected 'end'/) or next
    find(:syn_extra_end, { line: d[:line] }, at: [d[:line], d[:col], 3], label: :lbl_here)
  end

  rule :syn_generic, SyntaxError do |c|
    ds = c.diagnostics.reject { |d| d[:msg].include?("assuming it is closing the parent") }
    d = ds.min_by { |x| [x[:line], x[:col].to_i] } || c.diagnostics.first or next
    find(:syn_generic, { line: d[:line], msg: d[:msg] }, at: [d[:line], d[:col], d[:len]], label: :lbl_here)
  end

  # ================================================================ names
  PY_WORDS = { "True" => "true", "False" => "false", "TRUE" => "true", "FALSE" => "false", "None" => "nil",
               "Null" => "nil", "NULL" => "nil", "Nil" => "nil", "null" => "nil", "none" => "nil" }.freeze

  rule :name_python_kw, NameError do |c|
    name = c.error.name.to_s
    ruby = PY_WORDS[name] or next
    find(:name_python_kw, { name: name, ruby: ruby }, at: c.word_at(c.line, name), label: :lbl_unknown)
  end

  rule :name_elseif, NameError do |c|
    name = c.error.name.to_s
    next unless %w[elseif elif elsf elsif? else_if].include?(name)

    find(:name_elseif, { name: name }, at: c.word_at(c.line, name), label: :lbl_unknown)
  end

  rule :plusplus_runtime, NoMethodError do |c|
    next unless %w[+@ -@].include?(c.error.name.to_s)

    m = c.text(c.line).to_s.match(/([\w@\[\]:]+)\s*(\+\+|--)/) or next
    find(:syn_plusplus, { var: m[1] }, at: [c.line, m.begin(2), 2])
  end

  rule :constant, NameError do |c|
    e = c.error
    next if e.is_a?(NoMethodError)

    name = e.name.to_s
    next unless name.match?(/\A[A-Z]/)

    at = c.word_at(c.line, name)
    locals = c.assignments.keys + c.binding_locals
    if (s = locals.find { |l| l.casecmp?(name) })
      next find(:const_case, { name: name, suggestion: s }, at: at, label: :lbl_unknown)
    end
    corrections = e.respond_to?(:corrections) ? e.corrections.map(&:to_s) : []
    known = c.constants + Object.constants.map(&:to_s).select { |k| k.match?(/\A[A-Z][a-z]/) }
    if (s = corrections.first || similar(name, known))
      next find(:const_typo, { name: name, suggestion: s }, at: at, label: :lbl_unknown)
    end
    find(:const_unknown, { name: name }, at: at, label: :lbl_unknown)
  end

  # an unknown lower-case name: `nmae`, or a bare call `square(9)`
  rule :name_lower, NameError do |c|
    e = c.error
    name = e.name.to_s
    next unless name.match?(/\A[a-z_]/)

    n = c.line
    next if e.is_a?(NoMethodError) && !c.bare_call?(n, name)

    at = c.word_at(n, name)
    seen = c.assignments[name]
    if n && seen.any? && seen.none? { |l| l <= n } && !c.enclosing_def(n)
      next find(:name_later, { name: name, line: n, def_line: seen.min }, at: at, label: :lbl_unknown)
    end
    d = c.defs.find { |x| x[:name] == name }
    if d && n && d[:line] > n
      next find(:method_before_def, { meth: name, line: n, def_line: d[:line] }, at: at, label: :lbl_unknown)
    end
    encl = n && c.enclosing_def(n)
    if encl && seen.any? { |l| l < encl[:line] || l > encl[:end_line] } && !encl[:params].match?(/\b#{name}\b/)
      next find(:name_in_def, { name: name, meth: encl[:name] }, at: at, label: :lbl_unknown)
    end
    corrections = e.respond_to?(:corrections) ? e.corrections.map(&:to_s) : []
    params = encl ? encl[:params].scan(/[a-z_]\w*/) : []
    pool = (encl ? params : c.assignments.keys + c.binding_locals) + c.defs.map { |x| x[:name] }
    if (s = corrections.first || similar(name, pool))
      next find(:name_typo, { name: name, suggestion: s }, at: at, label: :lbl_unknown)
    end
    next find(:method_unknown, { meth: name }, at: at, label: :lbl_unknown) if e.is_a?(NoMethodError)

    find(:name_unknown, { name: name }, at: at, label: :lbl_unknown)
  end

  # ================================================================ nil
  BANG_NIL = %w[uniq! compact! flatten! reject! select! filter! strip! lstrip! rstrip! chomp! chop! squeeze!
                gsub! sub! upcase! downcase! capitalize! swapcase! delete! tr! slice!].freeze
  FINDERS = %w[find detect match find_index index first last min max min_by max_by bsearch dig].freeze

  rule :nil_receiver, NoMethodError do |c|
    e = c.error
    next unless e.receiver.nil?

    n = c.line or next
    meth = e.name.to_s
    start, len, expr = c.receiver_of(n, meth)
    expr ||= "…"
    at = start ? [n, start, len] : [n, nil, nil]
    base = { expr: expr, meth: meth }

    # @nmae.upcase
    if expr.match?(/\A@\w+\z/)
      if (s = similar(expr, c.ivars_assigned))
        next find(:nil_ivar_typo, { ivar: expr, suggestion: s }, at: at, label: :lbl_nil)
      end
      next find(:nil_ivar, { ivar: expr }, at: at, label: :lbl_nil)
    end

    # fox[:nme].upcase, list[5].upcase
    if (m = expr.match(/\A(@?[a-z_]\w*)\[(.+)\]\z/))
      coll = c.collection(m[1])
      key = m[2].strip
      if coll == :array || coll.is_a?(Array)
        next find(:nil_index, base.merge(idx: key), at: at, label: :lbl_nil) if key.match?(/\A-?\d+\z/)
      elsif coll.is_a?(Hash) || key.match?(/\A[:"']/)
        keys = coll.is_a?(Hash) ? coll.keys : []
        # hours[project] += 1 on an empty hash: Hash.new(0)
        compound = meth == "<<" ? "<<" : "#{Regexp.escape(meth)}="
        if %w[+ - * <<].include?(meth) && c.text(n).to_s.match?(/#{Regexp.escape(expr)}\s*#{compound}/)
          fix = meth == "<<" ? "Hash.new { |h, k| h[k] = [] }" : "Hash.new(0)"
          next find(:nil_hash_default, base.merge(hash: m[1], fix: fix), at: at, label: :lbl_nil)
        end
        sym_fix = key.match?(/\A["']/) && keys.include?(key[1..-2].to_sym)
        sentence = if sym_fix
                     c.t(:keys_are_symbols, list: keys.map(&:inspect).join(", "), fix: "#{m[1]}[:#{key[1..-2]}]", expr: expr)
                   elsif keys.any?
                     c.t(:keys_are, list: keys.map(&:inspect).join(", "))
                   else
                     c.t(:keys_maybe)
                   end
        next find(:nil_hash_key, base.merge(hash: m[1], key: key, keys: sentence), at: at, label: :lbl_nil)
      end
    end

    # x = puts "..." / x = list.uniq! / x = list.find { ... }
    if expr.match?(/\A[a-z_]\w*\z/)
      assigned = c.assignments[expr].select { |l| l <= n }.max
      line = assigned && c.strip_comment(c.text(assigned).to_s)
      if line && (m = line.match(/\b#{expr}\s*=\s*(puts|print)\b/))
        next find(:nil_puts, { var: expr, call: m[1] }, at: at, label: :lbl_nil)
      end
      if line && (m = line.match(/\b#{expr}\s*=.*\.(#{BANG_NIL.map { |b| Regexp.escape(b) }.join('|')})(?![\w])/))
        next find(:nil_bang, { var: expr, bang: m[1], plain: m[1].chomp("!") }, at: at, label: :lbl_nil)
      end
      if line&.match?(/\b#{expr}\s*=.*(\.match\b|=~)/)
        next find(:nil_match, { var: expr }, at: at, label: :lbl_nil)
      end
      if line && (m = without_groups(line).match(/\b#{expr}\s*=.*\.(#{FINDERS.join('|')})\s*\z/))
        next find(:nil_find, base.merge(expr: expr, finder: m[1]), at: at, label: :lbl_nil)
      end
    end

    # list.find { ... }.upcase
    if (m = without_groups(expr).match(/\.(#{FINDERS.join('|')})\s*\z/))
      next find(:nil_find, base.merge(finder: m[1]), at: at, label: :lbl_nil)
    end

    find(:nil_generic, base, at: at, label: :lbl_nil)
  end

  # ================================================================ methods
  CORE = [String, Array, Hash, Integer, Float, Symbol].freeze

  # age = "7"; age + 1  (TypeError)  /  age - 1  (NoMethodError on String)
  rule :str_numeric, TypeError, NoMethodError do |c|
    e = c.error
    next if e.is_a?(TypeError) && !e.message.match?(/no implicit conversion of (Integer|Float) into String/)
    next if e.is_a?(NoMethodError) && !(e.receiver.is_a?(String) && %w[- * / % ** < > <= >=].include?(e.name.to_s))

    n = c.line
    m = c.text(n).to_s.match(%r{([a-z_]\w*)\s*([-+*/%<>]=?|\*\*)\s*([\w.]+)}) or next
    var, op, operand = m[1], m[2], m[3]
    value = c.local(var)&.first
    if value.nil?
      assigned = c.assignments[var].select { |l| l <= n }.max or next
      lit = c.text(assigned)[/\b#{var}\s*=\s*(["'])(-?\d+(?:\.\d+)?)\1/, 2] or next
      value = lit
    end
    next unless value.is_a?(String) && value.match?(/\A-?\d+(\.\d+)?\z/)

    find(:str_numeric, { var: var, value: value.inspect, bare: value, op: op, operand: operand },
         at: [n, m.begin(1), var.length], label: :lbl_type, label_vars: { klass: "String" })
  end

  rule :method_wrong_type, NoMethodError do |c|
    e = c.error
    r = e.receiver
    meth = e.name.to_s
    next unless CORE.any? { |k| k === r }

    owner = CORE.find { |k| !(k === r) && k.public_method_defined?(meth) } or next
    n = c.line
    start, len, expr = c.receiver_of(n, meth)
    expr ||= FriendlyErrors.short(r)
    fix = if r.is_a?(Numeric) && owner == String then c.t(:fix_to_s, expr: expr, meth: meth)
          elsif r.is_a?(String) && owner <= Numeric then c.t(:fix_to_i, expr: expr)
          elsif r.is_a?(Array) && !r.empty? && r.first.respond_to?(meth) then c.t(:fix_map, expr: expr, meth: meth)
          else ""
          end
    klass = class_word(r)
    article = c.lang == "en" ? (klass.match?(/\A[AEIOU]/) ? "an" : "a") : t_raw(:w_article, c.lang)
    owner_word = t_raw(:w_owner, c.lang)[owner.name] || owner.name
    find(:method_wrong_type, { meth: meth, owner: owner_word, klass: klass, expr: expr, value: short(r), article: article, fix: fix },
         at: start ? [n, start, len] : [n, nil, nil], label: :lbl_type, label_vars: { klass: klass })
  end

  rule :attr_missing, NoMethodError do |c|
    e = c.error
    meth = e.name.to_s
    klass = e.receiver.class.name.to_s
    next unless c.constants.include?(klass) && c.source.match?(/@#{Regexp.escape(meth)}\b/)

    site = c.call_site(c.line, meth)
    at = site ? [c.line, site[1] + 1, meth.length] : c.word_at(c.line, meth)
    find(:attr_missing, { klass: klass, meth: meth }, at: at, label: :lbl_unknown)
  end

  rule :method_typo, NoMethodError do |c|
    e = c.error
    meth = e.name.to_s
    corrections = e.respond_to?(:corrections) ? e.corrections.map(&:to_s) : []
    pool = begin
      # a call without a receiver (`Puts "x"`) may also mean a private one
      (e.receiver.public_methods + (c.bare_call?(c.line, meth) ? e.receiver.private_methods : [])).map(&:to_s)
    rescue StandardError
      []
    end
    s = corrections.first || similar(meth, pool) or next
    site = c.call_site(c.line, meth)
    at = site ? [c.line, site[1] + 1, meth.length] : c.word_at(c.line, meth)
    find(:method_typo, { suggestion: s, meth: meth, klass: class_word(e.receiver, c.lang) }, at: at, label: :lbl_unknown)
  end

  # ================================================================ arguments
  rule :arity, ArgumentError do |c|
    m = c.error.message.match(/wrong number of arguments \(given (\d+), expected (\d+)(?:\.\.(\d+)|(\+))?[);]/) or next
    given = args_words(m[1], c.lang)
    expected = args_expected(m, c.lang)
    callee_line, label = c.frames.first
    next unless callee_line

    meth = label_name(label)
    d = c.defs.find { |x| x[:line] == callee_line && x[:name] == meth }
    call_line = c.frames[1]&.first || callee_line
    # add_entry("X", "08:30") for def add_entry(project:, from:)
    if (kw = c.error.message[/required keywords?: ([^)]+)/, 1])
      kws = kw.split(/,\s*/)
      list = list_join(kws.map { |k| "`#{k}:`" }, c.lang)
      next find(:kw_positional, { meth: meth, kws: list, example: kws.map { |k| "#{k}: …" }.join(", ") },
                at: c.word_at(call_line, meth), label: :lbl_call)
    end
    # square = ->(x) { ... }; square.call(2, 3)
    if label.to_s.start_with?("block") && (cm = c.text(call_line).to_s.match(/([a-z_]\w*)\s*(?:\.call\b|\.\(|\[)/))
      next find(:arity_lambda, { name: cm[1], expected: expected, given: given, def_line: callee_line, line: call_line },
                at: [call_line, cm.begin(1), cm[1].length], label: :lbl_call)
    end
    if d
      call_line = c.frames[1]&.first || callee_line
      klass = label.to_s[/(\w+)#initialize/, 1]
      shown = klass ? "#{klass}.new" : meth
      sig = d[:params].empty? ? d[:name] : "#{d[:name]}(#{d[:params]})"
      find(:arity, { meth: shown, expected: expected, given: given, sig: sig, def_line: d[:line], line: call_line },
           at: c.word_at(call_line, klass ? "new" : meth), label: :lbl_call)
    else
      find(:arity_nodef, { meth: meth, expected: expected, given: given, line: callee_line },
           at: c.word_at(callee_line, meth), label: :lbl_call)
    end
  end

  rule :keywords, ArgumentError do |c|
    m = c.error.message.match(/(missing|unknown) keywords?: (.+)/) or next
    kws = m[2].scan(/:?(\w+)/).flatten
    callee_line, label = c.frames.first
    meth = label_name(label)
    call_line = c.frames[1]&.first || callee_line
    d = c.defs.find { |x| x[:name] == meth }
    all = d ? d[:params].scan(/(\w+):/).flatten : []
    required = d ? d[:params].scan(/(\w+):\s*(?=,|\z)/).flatten : kws
    list = ->(names) { list_join(names.map { |k| "`#{k}:`" }, c.lang) }
    at = c.word_at(call_line, meth)
    if m[1] == "missing"
      example = (required.empty? ? kws : required).map { |k| "#{k}: …" }.join(", ")
      find(:missing_kw, { meth: meth, kws: list.(kws), example: example }, at: at, label: :lbl_call)
    else
      known = all.empty? ? "" : c.t(:known_kws, list: list.(all))
      find(:unknown_kw, { meth: meth, kws: list.(kws), known: known }, at: at, label: :lbl_call)
    end
  end

  rule :int_parse, ArgumentError do |c|
    m = c.error.message.match(/invalid value for (Integer|Float)\(\): (.+)/) or next
    find(:int_parse, { fn: m[1], text: m[2] }, at: c.word_at(c.line, m[1]), label: :lbl_here)
  end

  rule :comparison, ArgumentError do |c|
    m = c.error.message.match(/comparison of (\w+) with (.+?) failed/) or next
    b = m[2]
    b = case b
        when /\A[A-Z]\w*\z/ then b
        when /\A-?\d+\z/ then "Integer"
        when /\A-?\d+\.\d+\z/ then "Float"
        when /\A["']/ then "String"
        when "nil" then "nil"
        else b
        end
    at = c.column_of(c.line, /\b(sort_by|sort|max_by|min_by|max|min|minmax)\b|<=>/)
    find(:comparison, { a: m[1], b: b }, at: at ? [c.line, *at] : [c.line, nil, nil], label: :lbl_here)
  end

  # ================================================================ types
  rule :str_plus, TypeError do |c|
    m = c.error.message.match(/no implicit conversion of (\w+) into String/) or next
    n = c.line
    t = c.text(n).to_s
    next unless t.include?("+") || t.include?("<<")

    if m[1] == "nil"
      next find(:nil_operand, { op: t.include?("<<") ? "<<" : "+", line: n }, at: c.column_of(n, /\+|<</)&.then { |col, len| [n, col, len] }, label: :lbl_here)
    end
    om = t.match(/(?:\+|<<)\s*(?!["'])([\w@.\[\]:()]+)/)
    operand = om ? om[1] : "x"
    klass = { "Integer" => "Integer", "Float" => "Float", "Array" => "Array", "Hash" => "Hash", "Symbol" => "Symbol" }[m[1]] || m[1]
    other = t_raw(:w_other, c.lang)[klass] || klass
    other_a = t_raw(:w_other_a, c.lang)[klass] || other
    at = om ? [n, om.begin(1), om[1].length] : [n, nil, nil]
    find(:str_plus, { other: other, other_a: other_a, operand: operand, line: n }, at: at,
         label: :lbl_type, label_vars: { klass: klass })
  end

  rule :num_plus_str, TypeError do |c|
    m = c.error.message.match(/(\w+) can't be coerced into (Integer|Float)/) or next
    n = c.line
    t = c.text(n).to_s
    if m[1] == "nil"
      col, len = c.column_of(n, %r{\s[-+*/]\s})
      next find(:nil_operand, { op: t[%r{\s([-+*/])\s}, 1] || "+", line: n }, at: [n, col && col + 1, 1], label: :lbl_here)
    end
    next unless m[1] == "String"

    om = t.match(%r{[-+*/]\s*([\w@.\[\]:()"']+)})
    operand = om ? om[1] : "x"
    find(:num_plus_str, { operand: operand, line: n }, at: om ? [n, om.begin(1), om[1].length] : [n, nil, nil],
         label: :lbl_type, label_vars: { klass: "String" })
  end

  rule :array_key, TypeError do |c|
    next unless c.error.message.match?(/no implicit conversion of (Symbol|String) into Integer/)

    n = c.line
    m = c.text(n).to_s.match(/([\w@]+(?:\[[^\]]*\])*)\[(:\w+|"[^"]*"|'[^']*')\]/) or next
    find(:array_key, { expr: m[1], key: m[2] }, at: [n, m.begin(2) - 1, m[2].length + 2], label: :lbl_here)
  end

  rule :type_generic, TypeError do |c|
    m = c.error.message.match(/no implicit conversion (?:of|from) (\w+)(?: into|to) (\w+)/) or next
    find(:type_generic, { want: "`#{m[2]}`", got: "`#{m[1]}`", line: c.line }, at: [c.line, nil, nil])
  end

  # ================================================================ others
  rule :zero_div, ZeroDivisionError do |c|
    n = c.line
    t = c.text(n).to_s
    if (m = t.match(%r{[/%]\s*\(?\s*(([\w@.\[\]:]+?)\.(length|size|count))\b}))
      next find(:zero_div, { line: n, extra: c.t(:zero_div_empty, expr: m[1], list: m[2]) }, at: [n, m.begin(1), m[1].length], label: :lbl_here)
    end
    col, = c.column_of(n, %r{\s[/%]\s|[/%]})
    find(:zero_div, { line: n, extra: c.t(:zero_div_plain) }, at: [n, col && (t[col] == " " ? col + 1 : col), 1], label: :lbl_here)
  end

  rule :frozen, FrozenError do |c|
    r = c.error.receiver
    at = c.column_of(c.line, /<<|\.(\w+!|push|append|prepend|concat|insert|delete\w*|clear|replace|store|unshift|pop|shift|update|merge!|\[\]=)/)
    find(:frozen, { value: short(r), klass: class_word(r) }, at: at ? [c.line, *at] : [c.line, nil, nil], label: :lbl_here)
  end

  rule :no_pattern, NoMatchingPatternError do |c|
    value = c.error.message.sub(/: .*\z/m, "")
    value = "#{value[0, 59]}…" if value.length > 60
    n = c.line
    find(:no_pattern, { value: value, line: n }, at: c.word_at(n, "case"), label: :lbl_here)
  end

  rule :key_error, KeyError do |c|
    e = c.error
    keys = e.receiver.respond_to?(:keys) ? e.receiver.keys : []
    sentence = keys.any? ? c.t(:keys_are, list: keys.map(&:inspect).join(", ")) : ""
    site = c.call_site(c.line, "fetch")
    at = site ? [c.line, site[1] + 1, 5] : [c.line, nil, nil]
    find(:key_error, { key: e.key.inspect, keys: sentence }, at: at, label: :lbl_here)
  end

  rule :index_error, IndexError do |c|
    m = c.error.message.match(/index (-?\d+) outside of array bounds: -?\d+\.\.\.(\d+)/) or next
    size = m[2].to_i
    find(:index_error, { idx: m[1], size: size, last: size - 1 }, at: [c.line, nil, nil])
  end

  rule :stack, SystemStackError do |c|
    labels = c.frames.map { |_, l| label_name(l) }.reject(&:empty?)
    meth = labels.tally.max_by { |_, k| k }&.first or next
    d = c.defs.find { |x| x[:name] == meth }
    at = d ? c.word_at(d[:line], meth) : [nil, nil, nil]
    find(:stack, { meth: meth }, at: at, label: :lbl_here)
  end

  # a live run's time limit (html/autorun.rb): only when a loop looks endless
  rule :endless_loop, "AutoRun::Stopped" do |c|
    found = nil
    c.lines.each_with_index do |l, i|
      code = c.strip_comment(l)
      indent = code[/^\s*/].length
      if (m = code.match(/^\s*(while|until)\s+(.+?)(\s+do)?\s*$/))
        body = c.lines[(i + 1)...(c.end_of(i, indent) - 1)].to_a.map { |x| c.strip_comment(x) }.join("\n")
        vars = m[2].scan(/(?<![.:@\w])([a-z_]\w*)(?![\w(?!])/).flatten - %w[true false nil and or not]
        vars.select! { |v| c.assignments.key?(v) }
        stuck = vars.find do |v|
          !body.match?(/\b#{v}\s*([-+*\/|&]?=(?!=)|<<)|\b#{v}\.(\w+!|push|pop|shift|unshift|delete|clear|concat)/)
        end
        if stuck && vars.all? { |v| v == stuck || !body.match?(/\b#{v}\s*[-+*\/]?=(?!=)/) }
          found = find(:loop_var, { kw: m[1], line: i + 1, var: stuck }, at: c.word_at(i + 1, stuck), label: :lbl_loop)
        elsif vars.empty? && m[2].strip.match?(/\A(true|1)\z/) && !body.match?(/\b(break|return|raise|exit)\b/)
          found = find(:loop_no_break, { line: i + 1 }, at: c.word_at(i + 1, m[1]), label: :lbl_here)
        end
      elsif code.match?(/\bloop\s+(do|\{)/)
        body = c.lines[(i + 1)...(c.end_of(i, indent) - 1)].to_a.join("\n")
        found = find(:loop_no_break, { line: i + 1 }, at: c.word_at(i + 1, "loop"), label: :lbl_here) unless body.match?(/\b(break|return|raise|exit|throw)\b/)
      end
      break if found
    end
    found
  end

  rule :own_error, StandardError do |c|
    klass = c.error.class.name.to_s
    next unless c.source.match?(/^\s*class\s+#{Regexp.escape(klass.split('::').last)}\s*<\s*\w*(Error|Exception)\b/) ||
                c.source.match?(/\bclass\s+#{Regexp.escape(klass.split('::').last)}\s*<\s*Error\b/)

    find(:own_error, { klass: klass, line: c.line }, at: c.word_at(c.line, "raise"), label: :lbl_here)
  end

  rule :load_error, LoadError do |c|
    m = c.error.message.match(/cannot load such file -- (\S+)/) or next
    find(:load_error, { name: m[1] }, at: c.word_at(c.line, m[1]), label: :lbl_here)
  end
end
