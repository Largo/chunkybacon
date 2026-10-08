# FriendlyErrors: a kind explanation of an exception from a notebook cell,
# in German, English or Japanese, with a pointer into the cell's code -
# in the spirit of Elm's and Rust's compiler messages.
#
#   result = FriendlyErrors.explain(error, source: code, lang: "de",
#                                   file: "chunky.rb", binding: @bind)
#   result&.to_text  /  result&.to_html
#
# The course's kernel loads it on a cell's first error (main.rb,
# friendly_error); test/friendly_errors_harness.rb runs it over a corpus of
# beginner mistakes.
#
# +explain+ returns nil when no rule knows the error (the cell then shows
# Ruby's own message as before), and never raises.
#
# How it works: RULES is an ordered table; each rule names the exception
# classes it looks at and a block that inspects a Context (the error, the
# cell's source, its lines, optionally the binding) and either returns nil
# (not mine) or a Finding: which message, the values to fill in, and where
# in the code to point. The first rule that answers wins. Texts live in
# friendly_errors_messages.rb.
#
# Pure Ruby, stdlib only, no Prism needed: syntax errors are read from the
# SyntaxError's message (Prism's own diagnostics, with line and column),
# plus a small scanner over the source for strings, brackets and `end`s.
#
# Three files: this one, the texts and the rules. On a computer this one
# requires the other two; the kernel fetches and evals all three itself, in
# the order messages, this, rules (a cell runs synchronously, and
# require_relative's fetch from the page cannot), and sets FETCHED first.
require_relative "friendly_errors_messages" unless defined?(FriendlyErrors::MESSAGES)

module FriendlyErrors
  Finding = Struct.new(:msg, :vars, :line, :col, :len, :label, :label_vars, keyword_init: true)

  # What explain returns.
  class Result
    attr_reader :rule, :title, :body, :line, :col, :len, :label, :snippet, :original, :lang

    def initialize(rule:, title:, body:, line:, col:, len:, label:, snippet:, original:, lang:)
      @rule, @title, @body, @line, @col, @len = rule, title, body, line, col, len
      @label, @snippet, @original, @lang = label, snippet, original, lang
    end

    def to_text
      out = +"-- #{title} "
      out << "-" * [4, 72 - out.length].max
      out << "\n\n"
      out << snippet << "\n" if snippet
      out << FriendlyErrors.wrap(body) << "\n"
      out
    end

    # +brief+: only the headline shows (app.css .friendly-brief) - for live runs
    def to_html(brief: false)
      html = +"<div class=\"friendly-error#{brief ? ' friendly-brief' : ''}\" lang=\"#{lang}\">"
      html << "<div class=\"friendly-title\">#{FriendlyErrors.inline_html(title)}</div>"
      html << "<pre class=\"friendly-snippet\">#{FriendlyErrors.escape(snippet)}</pre>" if snippet
      html << "<p class=\"friendly-body\">#{FriendlyErrors.inline_html(body)}</p>"
      html << "<details class=\"friendly-original\"><summary>#{FriendlyErrors.escape(FriendlyErrors.t_raw(:w_original, lang))}</summary>" \
              "<pre>#{FriendlyErrors.escape(original)}</pre></details>"
      html << "</div>"
    end
  end

  Rule = Struct.new(:name, :classes, :block)
  RULES = []

  def self.rule(name, *classes, &block)
    RULES << Rule.new(name, classes, block)
  end

  LANGS = %w[de en ja].freeze

  class << self
    def explain(error, source:, lang: "en", file: "chunky.rb", binding: nil)
      lang = LANGS.include?(lang.to_s) ? lang.to_s : "en"
      ctx = Context.new(error, source.to_s, lang, file, binding)
      RULES.each do |r|
        next unless r.classes.empty? || r.classes.any? { |k| k === error || k == error.class.name }
        finding = begin
          r.block.call(ctx)
        rescue StandardError => e
          warn "FriendlyErrors rule #{r.name}: #{e.class}: #{e.message}" if $DEBUG
          nil
        end
        return build(r.name, finding, ctx) if finding
      end
      nil
    rescue StandardError => e
      warn "FriendlyErrors: #{e.class}: #{e.message}" if $DEBUG
      nil
    end

    def build(rule_name, f, ctx)
      title, body = t(f.msg, ctx.lang, f.vars || {}).split("\n", 2)
      label = f.label && t(f.label, ctx.lang, f.label_vars || {})
      snippet = f.line && ctx.snippet(f.line, f.col, f.len, label)
      Result.new(rule: rule_name, title: title, body: body.to_s.strip, line: f.line, col: f.col, len: f.len,
                 label: label, snippet: snippet, original: ctx.original, lang: ctx.lang)
    end

    def t_raw(key, lang)
      entry = MESSAGES.fetch(key)
      entry[lang] || entry["en"]
    end

    def t(key, lang, vars = {})
      format(t_raw(key, lang), **vars)
    end

    def escape(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end

    def inline_html(text)
      escape(text).gsub(/`([^`]+)`/) { "<code>#{Regexp.last_match(1)}</code>" }
    end

    # wraps prose at 76 columns for the terminal (not Japanese: no spaces)
    def wrap(text, width = 76)
      return text if text.match?(/\p{Han}|\p{Hiragana}|\p{Katakana}/)

      # code in backticks is never broken: its spaces are hidden while wrapping
      glued = text.gsub(/`[^`]*`/) { |code| code.tr(" ", "\u00A0") }
      glued.split("\n").map { |para| para.gsub(/(.{1,#{width}})( +|\z)/, "\\1\n").rstrip }.join("\n").tr("\u00A0", " ")
    end

    # "a, b and c" / "a, b und c" / "a、b、c"
    def list_join(items, lang)
      return items.join("、") if lang == "ja"
      return items.first.to_s if items.length < 2

      "#{items[0..-2].join(', ')}#{t_raw(:w_and, lang)}#{items.last}"
    end

    # "1 argument", "2 Argumente", "引数2個"
    def args_words(n, lang)
      forms = t_raw(:w_args, lang)
      n = n.to_i
      return format(forms[2], n: 0) if n.zero? && lang == "ja"

      format(forms[[n, 2].min], n: n)
    end

    def similar(name, candidates)
      name = name.to_s
      return nil if name.length < 2

      best = nil
      best_d = nil
      candidates.map(&:to_s).uniq.each do |c|
        next if c == name || c.empty?

        d = c.casecmp?(name) ? 0 : levenshtein(name.downcase, c.downcase)
        limit = name.length <= 4 ? 1 : 2
        next if d > limit

        if best_d.nil? || d < best_d
          best = c
          best_d = d
        end
      end
      best
    end

    # edit distance where swapping two neighbours counts once ("Fxo" -> "Fox")
    def levenshtein(a, b)
      d = Array.new(a.length + 1) { |i| Array.new(b.length + 1) { |j| i.zero? ? j : (j.zero? ? i : 0) } }
      (1..a.length).each do |i|
        (1..b.length).each do |j|
          cost = a[i - 1] == b[j - 1] ? 0 : 1
          d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].min
          if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]
            d[i][j] = [d[i][j], d[i - 2][j - 2] + 1].min
          end
        end
      end
      d[a.length][b.length]
    end

    def short(value, max = 40)
      text = begin
        value.inspect
      rescue StandardError
        value.class.to_s
      end
      text.length > max ? "#{text[0, max - 1]}…" : text
    end
  end

  # ------------------------------------------------------------------
  # What the rules look at.
  class Context
    attr_reader :error, :source, :lang, :file, :lines

    def initialize(error, source, lang, file, binding)
      @error = error
      @source = source
      @lang = lang
      @file = file
      @binding = binding
      @lines = source.split("\n", -1)
    end

    def original
      "#{error.class}: #{message}"
    end

    # the error's message without terminal colours: ruby.wasm's Prism
    # colours a SyntaxError's code frame ("\e[1;31m> \e[m\e[2m5 | \e[m"),
    # which a Ruby in a pipe does not
    def message
      @message ||= error.message.to_s.gsub(/\e\[[\d;]*m/, "")
    end

    def t(key, vars = {}) = FriendlyErrors.t(key, lang, vars)

    def text(n) = (n && n >= 1 ? lines[n - 1] : nil)

    # the line numbers of the cell's own frames, innermost first
    def frames
      @frames ||= begin
        locs = error.backtrace_locations
        if locs
          locs.select { |l| l.path == file }.map { |l| [l.lineno, l.label.to_s] }
        else
          (error.backtrace || []).filter_map do |s|
            m = s.match(/\A#{Regexp.escape(file)}:(\d+):in '?([^']*)'?/) and [m[1].to_i, m[2]]
          end
        end.select { |n, _| n >= 1 && n <= lines.length }
      end
    end

    def line = frames.first&.first

    # --- the binding, read only: local_variable_get, never eval
    def local(name)
      return nil unless @binding && name.to_s.match?(/\A[a-z_]\w*\z/)
      return nil unless @binding.local_variable_defined?(name.to_sym)

      [@binding.local_variable_get(name.to_sym)]
    rescue NameError
      nil
    end

    def binding_locals = @binding ? @binding.local_variables.map(&:to_s) : []

    # --- what the source assigns and defines (by line)
    def assignments
      @assignments ||= begin
        found = Hash.new { |h, k| h[k] = [] }
        lines.each_with_index do |l, i|
          code = strip_comment(l)
          code.scan(/(?:^|[;(]|\bthen)\s*((?:[a-z_]\w*\s*,\s*)*[a-z_]\w*)\s*(?:[-+*\/|&]{1,2})?=(?![=~>])/) do |m|
            m[0].split(",").each { |n| found[n.strip] << i + 1 }
          end
          code.scan(/\|([^|]*)\|/) { |m| m[0].scan(/[a-z_]\w*/) { |n| found[n] << i + 1 } }
          code.scan(/\bfor\s+([a-z_]\w*)\s+in\b/) { |m| found[m[0]] << i + 1 }
          code.scan(/=>\s*([a-z_]\w*)/) { |m| found[m[0]] << i + 1 }
        end
        found
      end
    end

    def defs
      @defs ||= lines.each_with_index.filter_map do |l, i|
        m = l.match(/^(\s*)def\s+(?:self\.)?([\w]+[?!=]?)\s*(\(([^)]*)\)|([^=\n]*))?/) or next
        params = (m[4] || m[5]).to_s
        endless = l.match?(/def\s+[\w.?!]+\s*(\([^)]*\))?\s*=[^=]/)
        { name: m[2], line: i + 1, indent: m[1].length, params: params.strip,
          end_line: endless ? i + 1 : end_of(i, m[1].length) }
      end
    end

    def end_of(start, indent)
      ((start + 1)...lines.length).each do |j|
        return j + 1 if lines[j].match?(/^\s{#{indent}}end\b/)
      end
      lines.length
    end

    def enclosing_def(n)
      defs.select { |d| n > d.fetch(:line) && n <= d.fetch(:end_line) }.max_by { |d| d.fetch(:line) }
    end

    def constants
      @constants ||= source.scan(/^\s*(?:class|module)\s+([A-Z]\w*)|^\s*([A-Z]\w*)\s*=[^=]/).flatten.compact
    end

    def ivars_assigned
      @ivars_assigned ||= source.scan(/(@\w+)\s*(?:[-+*\/|&]{1,2})?=(?![=~>])/).flatten.uniq +
                          source.scan(/attr_(?:accessor|writer)\s+(.*)/).flatten.flat_map { |s| s.scan(/:(\w+)/).flatten.map { |n| "@#{n}" } }
    end

    def strip_comment(l) = l.sub(/(^|\s)#(?!\{).*$/, "\\1")

    # --- finding things on a line
    def column_of(n, pattern)
      t = text(n) or return nil
      m = t.match(pattern) or return nil
      [m.begin(0), m[0].length]
    end

    # "h[:nme].upcase" -> the dot before +meth+ and where its receiver starts
    def call_site(n, meth)
      t = text(n) or return nil
      m = t.match(/(&?\.)\s*#{Regexp.escape(meth.to_s)}(?![\w?!])/) or return nil
      dot = m.begin(0)
      start = receiver_start(t, dot)
      [start, dot, t[start...dot]]
    end

    PAIRS = { ")" => "(", "]" => "[", "}" => "{" }.freeze

    def receiver_start(t, idx)
      i = idx - 1
      while i >= 0
        ch = t[i]
        if PAIRS.key?(ch) || ch == '"' || ch == "'"
          j = matching_open(t, i)
          break unless j

          i = j - 1
          i -= 1 while ch == "}" && i >= 0 && t[i] == " "
        elsif ch.match?(/[\w@$?!]/)
          i -= 1 while i >= 0 && t[i].match?(/[\w@$?!]/)
          if i >= 1 && t[i] == ":" && t[i - 1] == ":"
            i -= 2
          elsif i >= 0 && t[i] == "."
            i -= 1
            i -= 1 if i >= 0 && t[i] == "&"
          else
            break
          end
        else
          break
        end
      end
      i + 1
    end

    def matching_open(t, i)
      close = t[i]
      open = PAIRS[close] || close
      depth = 0
      i.downto(0) do |j|
        next if j == i && (close == '"' || close == "'")
        return j if (close == '"' || close == "'") && t[j] == close

        depth += 1 if t[j] == close
        depth -= 1 if t[j] == open
        return j if depth.zero?
      end
      nil
    end

    # --- the source as tokens: an unclosed string, unbalanced brackets
    def scan
      @scan ||= begin
        stack = []
        extra = []
        string = nil
        interp = []
        lines.each_with_index do |l, li|
          ci = 0
          while ci < l.length
            ch = l[ci]
            if string
              if ch == "\\"
                ci += 1
              elsif string[:quote] == '"' && ch == "#" && l[ci + 1] == "{"
                interp << { string: string, line: li + 1, col: ci }
                string = nil
                stack << { char: "\#{", line: li + 1, col: ci }
                ci += 1
              elsif ch == string[:quote]
                string = nil
              end
            elsif ch == "#"
              break
            elsif ch == '"' || ch == "'"
              string = { quote: ch, line: li + 1, col: ci }
            elsif ch == "?" && l[ci + 1] && ci > 0 && l[ci - 1] =~ /[\s(,]/ && l[ci + 2].to_s !~ /\w/
              ci += 1 # ?( character literal
            elsif "([{".include?(ch)
              stack << { char: ch, line: li + 1, col: ci }
            elsif ")]}".include?(ch)
              if stack.last && stack.last[:char] == "\#{" && ch == "}"
                stack.pop
                string = interp.pop[:string]
              elsif stack.last && stack.last[:char] == PAIRS[ch]
                stack.pop
              else
                extra << { char: ch, line: li + 1, col: ci }
              end
            end
            ci += 1
          end
        end
        { string: string, open: stack, extra: extra }
      end
    end

    # --- `end`s by indentation: the opener that lost its `end`
    OPENER = /^(\s*)(?:(def|class|module|if|unless|while|until|case|begin|for)\b|.*?=\s*(if|unless|case|begin)\b|.*\b(do)\s*(?:\|[^|]*\|)?\s*$)/

    def unclosed_openers
      stack = []
      suspects = []
      lines.each_with_index do |raw, i|
        l = strip_comment(raw)
        next if l.strip.empty?

        indent = l[/^\s*/].length
        if l.match?(/^\s*end\b/)
          k = stack.rindex { |o| o[:indent] == indent }
          if k
            suspects.concat(stack[(k + 1)..])
            stack = stack[0...k]
          else
            stack.pop
          end
          next
        end
        m = l.match(OPENER) or next
        kw = m[2] || m[3] || m[4]
        next if kw == "def" && l.match?(/def\s+[\w.?!]+\s*(\([^)]*\))?\s*=[^=]/) # endless def
        next if l.match?(/\bend\b\s*$/) && kw != "do" # one-liner
        next if kw == "do" && l.match?(/\b(while|until|for)\b/) && stack.last && stack.last[:line] == i + 1

        col = kw == "do" ? l.rindex(/\bdo\b/) : (m[2] ? indent : l.index(/\b#{kw}\b/))
        stack << { kw: kw, indent: indent, line: i + 1, col: col }
      end
      # an opener skipped by a later `end` first, else the innermost open one
      suspects + stack.reverse
    end

    # Prism's diagnostics from the SyntaxError's message:
    #   "> 3 | def foo\n    | ^~~ expected an `end` ..."
    def diagnostics
      @diagnostics ||= begin
        out = []
        current = nil
        message.each_line do |l|
          if (m = l.match(/^[> ] *(\d+) \| /))
            current = m[1].to_i
          elsif current && (m = l.match(/^ +\| ( *)(\^~*) (.*)$/))
            out << { line: current, col: m[1].length, len: m[2].length, msg: m[3].strip }
          end
        end
        if out.empty? && (m = message.match(/:(\d+): (.*)/))
          out << { line: m[1].to_i, col: nil, len: nil, msg: m[2] }
        end
        out
      end
    end

    def diag(pattern) = diagnostics.find { |d| d[:msg].match?(pattern) }

    # the cell's code around line +n+, with a caret
    def snippet(n, col, len, label)
      return nil unless text(n)

      # up to two lines of context, not across a blank line
      first = n
      first -= 1 while first > [n - 2, 1].max && !text(first - 1).to_s.strip.empty?
      shown = (first..n).to_a
      width = n.to_s.length
      out = shown.map { |k| "#{k == n ? '>' : ' '} #{k.to_s.rjust(width)} | #{text(k)}" }
      if col
        len = [len.to_i, 1].max
        out << "  #{' ' * width} | #{' ' * display_width(text(n)[0, col])}#{'^' * len}#{label ? " #{label}" : ''}"
      end
      out.join("\n") + "\n"
    end

    def display_width(s) = s.each_char.sum { |c| c.match?(/[\p{Han}\p{Hiragana}\p{Katakana}\uFF00-\uFFEF]/) ? 2 : 1 }
  end

  def self.find(msg, vars = {}, at: nil, label: nil, label_vars: nil)
    line, col, len = at
    Finding.new(msg: msg, vars: vars, line: line, col: col, len: len, label: label, label_vars: label_vars)
  end
end

require_relative "friendly_errors_rules" unless FriendlyErrors.const_defined?(:FETCHED, false)
