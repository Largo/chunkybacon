# frozen_string_literal: true

# Content linter for html/lessons.js - catches what test/check_harness.rb
# does not: translation drift between de/en/ja, stale "lesson N" references
# after renumbering, the mechanical half of the Japanese rules (HANDOVER §3),
# Ruby that does not parse or warns, gems the cache does not have, and
# lesson counts in the docs that went stale.
#
#   ruby lint_lessons.rb                 # errors + warnings, grouped
#   ruby lint_lessons.rb --verbose       # also INFO (reference table, ...)
#   ruby lint_lessons.rb --only=refs,ja  # some groups
#   ruby lint_lessons.rb --json          # machine-readable
#   ruby lint_lessons.rb --net           # also HEAD every external link
#   ruby lint_lessons.rb --root=PATH     # another checkout
#
# Accepted findings go into lint_allow.txt (next to this file): one key glob per
# line, "# reason" after it. Exit status 1 when an ERROR is not allowed.

require "json"
require "prism"
require "rubygems/package"
require "optparse"
require "set"

module LessonLint
  LANGS = %w[de en ja].freeze
  SEVERITIES = %w[ERROR WARN INFO].freeze
  GROUPS = %w[structure parity html refs ja ruby gems counts links].freeze

  Finding = Struct.new(:group, :severity, :code, :where, :line, :message, :detail, :key, :allowed,
                       keyword_init: true)

  # ---------------------------------------------------------------- helpers
  module Text
    ENTITIES = { "&lt;" => "<", "&gt;" => ">", "&amp;" => "&", "&quot;" => '"', "&#39;" => "'",
                 "&apos;" => "'", "&nbsp;" => " " }.freeze

    module_function

    def decode(str)
      str.gsub(/&(?:lt|gt|amp|quot|#39|apos|nbsp);/) { |e| ENTITIES[e] }
         .gsub(/&#(\d+);/) { [$1.to_i].pack("U") }
    end

    def code_spans(html)
      html.scan(%r{<code>(.*?)</code>}m).map { |(s)| decode(s.gsub(/<[^>]+>/, "")) }
    end

    # visible prose: tags out, <code>/<pre> out (replaced by a marker)
    def prose(html, code_marker: " ")
      s = html.gsub(%r{<pre>.*?</pre>}m, code_marker).gsub(%r{<code>.*?</code>}m, code_marker)
      decode(s.gsub(/<[^>]+>/, " "))
    end

    def plain(html)
      decode(html.gsub(/<[^>]+>/, " "))
    end

    WIDE = /[ᄀ-ᅟ⺀-꓏가-힣豈-﫿︰-﹏＀-｠￠-￦\u{1F300}-\u{1FAFF}]/

    def width(line)
      line.length + line.scan(WIDE).size
    end

    def snippet(str, max = 90)
      s = str.gsub(/\s+/, " ").strip
      s.length > max ? "#{s[0, max - 1]}…" : s
    end

    def slug(str)
      str.to_s.gsub(/[^\p{Word}]+/, "_")[0, 40]
    end
  end

  # ---------------------------------------------------------------- source
  # Loads html/lessons.js (JSON inside JSON.stringify(...)) and maps every
  # lesson/lang/cell and ui key to its line number.
  class Source
    attr_reader :root, :data, :path

    # text: the contents of a lessons.js (tests pass a mutated one)
    def initialize(root, text: nil)
      @root = root
      @path = File.join(root, "html", "lessons.js")
      text ||= File.read(@path, encoding: "UTF-8")
      json = text[/JSON\.stringify\((.*)\);\s*\z/m, 1] or abort "lessons.js: no JSON.stringify(...) found"
      @data = JSON.parse(json)
      index_lines(text)
    end

    def self.dump(data)
      "window.LESSONS_JSON = JSON.stringify(#{JSON.pretty_generate(data)});\n"
    end

    def ui = data["ui"]
    def lessons = data["lessons"]

    def cell_line(id, lang, idx) = @cells[[id, lang, idx]]
    def lesson_line(id) = @lesson_lines[id]
    def ui_line(lang, key) = @ui_lines[[lang, key]]

    private

    def index_lines(text)
      @cells = {}
      @lesson_lines = {}
      @ui_lines = {}
      in_lessons = false
      id = lang = nil
      idx = -1
      text.each_line.with_index(1) do |line, n|
        if line.start_with?('  "lessons": [')
          in_lessons = true
        elsif !in_lessons
          if (m = line.match(/\A    "(\w+)": \{/)) then lang = m[1]
          elsif lang && (m = line.match(/\A      "(\w+)": /)) then @ui_lines[[lang, m[1]]] = n
          end
        elsif (m = line.match(/\A      "id": "([^"]+)"/))
          id = m[1]
          @lesson_lines[id] = n
        elsif (m = line.match(/\A      "(\w\w)": \{/))
          lang = m[1]
          idx = -1
        elsif line.start_with?('            "t": ')
          idx += 1
          @cells[[id, lang, idx]] = n
        end
      end
    end
  end

  # ---------------------------------------------------------------- gem cache
  class GemCache
    attr_reader :manifest, :dir, :provides, :substitutes, :native, :optional

    def initialize(root)
      @dir = File.join(root, "html", "gems", "cache")
      mpath = File.join(@dir, "manifest.json")
      @manifest = File.exist?(mpath) ? JSON.parse(File.read(mpath)) : {}
      loader = File.read(File.join(root, "html", "browser_gems.rb"))
      @substitutes = loader[/SUBSTITUTES = (\{[^}]*\})/, 1].to_s.scan(/"([^"]+)" => "([^"]+)"/).to_h
      @native = loader[/NATIVE_GEMS = %w\[(.*?)\]/m, 1].to_s.split
      @optional = loader[/OPTIONAL_NATIVE_DEPS = (\{[^}]*\})/, 1].to_s
                        .scan(/"([^"]+)" => %w\[([^\]]*)\]/).to_h { |k, v| [k, v.split] }
      @provides = {} # "sinatra/base" => "sinatra"
      @manifest.each do |name, entry|
        file = File.join(@dir, entry["file"].to_s)
        next unless File.exist?(file)
        begin
          spec = Gem::Package.new(file).spec
          paths = spec.require_paths
          spec.files.each do |f|
            paths.each do |rp|
              next unless f.start_with?("#{rp}/") && f.end_with?(".rb")
              @provides[f.delete_prefix("#{rp}/").delete_suffix(".rb")] ||= name
            end
          end
        rescue StandardError => e
          warn "gem cache: cannot read #{entry["file"]}: #{e.message}"
        end
      end
    end

    def deps_closure(name, seen = Set.new)
      name = substitutes.fetch(name, name)
      return seen if seen.include?(name)
      seen << name
      (manifest.dig(name, "deps") || []).each { |d| deps_closure(d, seen) }
      seen
    end
  end

  # ---------------------------------------------------------------- linter
  class Linter
    attr_reader :findings

    STOP_EN = %w[the a an is are to of and with you your this that it in for on not be we can what here
                 now then so if or as by from at was were will would should have has use uses make
                 makes one two only all each its our same more than into out up down get gets just
                 like when which there they them their how why first last next new also but].to_set

    # base_text: an older lessons.js (--base=GITREF) to check references against
    def initialize(root, allow_path:, net: false, text: nil, gems: nil, base_text: nil)
      @root = root
      @src = Source.new(root, text: text)
      @base = base_text && Source.new(root, text: base_text).data
      @gems = gems || GemCache.new(root)
      @net = net
      @findings = []
      @allow = load_allow(allow_path)
    end

    def run(groups)
      groups.each { |g| send("check_#{g}") }
      @findings.each { |f| f.allowed = allowed?(f.key) }
      @findings
    end

    # ------------------------------------------------------------ plumbing
    def add(group, severity, code, where:, message:, line: nil, detail: nil, extra: nil)
      key = [code, where.gsub(/\s+/, ""), extra && Text.slug(extra)].compact.join("@")
      @findings << Finding.new(group: group, severity: severity, code: code, where: where, line: line,
                               message: message, detail: detail, key: key)
    end

    def load_allow(path)
      return [] unless path && File.exist?(path)
      File.readlines(path, encoding: "UTF-8").filter_map do |l|
        pat = l.sub(/#.*/, "").strip
        pat.empty? ? nil : pat
      end
    end

    def allowed?(key) = @allow.any? { |pat| File.fnmatch?(pat, key, File::FNM_EXTGLOB) }

    def lessons = @src.lessons

    def where(lesson, lang = nil, idx = nil)
      s = lesson["id"].dup
      s << "[#{lang}]" if lang
      s << " cell #{idx}" if idx
      s
    end

    def line_of(lesson, lang = nil, idx = nil)
      n = idx ? @src.cell_line(lesson["id"], lang, idx) : @src.lesson_line(lesson["id"])
      n && "lessons.js:#{n}"
    end

    def cells(lesson, lang) = lesson.dig(lang, "cells") || []

    def each_cell
      lessons.each_with_index do |lesson, li|
        LANGS.each do |lang|
          cells(lesson, lang).each_with_index { |cell, ci| yield lesson, li, lang, cell, ci }
        end
      end
    end

    # code with comments removed and blank/trailing whitespace normalised -
    # what "ja runs the English code" means
    def strip_comments(code)
      result = Prism.parse(code)
      out = code.b.dup
      result.comments.reverse_each do |c|
        loc = c.location
        out[loc.start_offset...loc.end_offset] = ""
      end
      out.force_encoding("UTF-8").lines.map(&:rstrip).reject(&:empty?).join("\n")
    end

    def comments(code)
      Prism.parse(code).comments.map { |c| c.location.slice.force_encoding("UTF-8").sub(/\A#\s?/, "") }
    end

    # ------------------------------------------------------------ structure
    def check_structure
      ids = lessons.map { |l| l["id"] }
      ids.tally.each { |id, n| add("structure", "ERROR", "dup-id", where: id, message: "id used #{n} times") if n > 1 }
      lessons.each_with_index do |lesson, li|
        LANGS.each do |lang|
          unless lesson[lang].is_a?(Hash)
            add("structure", "ERROR", "missing-lang", where: where(lesson, lang), message: "no #{lang} version")
            next
          end
          title = lesson[lang]["title"].to_s
          num = title[/\A(\d+)\. /, 1]&.to_i
          if num != li + 1
            add("structure", "ERROR", "title-number", where: where(lesson, lang), line: line_of(lesson),
                message: "title #{title.inspect} but the lesson is number #{li + 1}")
          end
          (lesson[lang].keys - %w[title cells]).each do |k|
            add("structure", "WARN", "unknown-key", where: where(lesson, lang), message: "unknown key #{k.inspect}")
          end
          xs = cells(lesson, lang).each_index.select { |i| cells(lesson, lang)[i]["t"] == "x" }
          if xs.size != 1
            add("structure", "WARN", "exercise-count", where: where(lesson, lang),
                message: "#{xs.size} exercise (x) cells, the format expects exactly one")
          end
          cells(lesson, lang).each_with_index do |c, ci|
            need = { "h" => %w[html], "c" => %w[code], "x" => %w[check hint] }[c["t"]] # an empty starter is fine
            if need.nil?
              add("structure", "ERROR", "cell-type", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                  message: "unknown cell type #{c["t"].inspect}")
              next
            end
            need.each do |f|
              next unless c[f].to_s.strip.empty?
              add("structure", "ERROR", "cell-field", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                  message: "#{c["t"]} cell without #{f}")
            end
          end
          tasks = cells(lesson, lang).sum { |c| c["html"].to_s.scan("<div class='task'>").size }
          if tasks != 1
            add("structure", "WARN", "task-count", where: where(lesson, lang),
                message: "#{tasks} <div class='task'> blocks (expected 1)")
          end
        end
        if (sec = lesson["section"])
          missing = LANGS.reject { |g| sec[g].to_s.strip != "" }
          add("structure", "ERROR", "section-lang", where: where(lesson), message: "section lacks #{missing.join(", ")}") if missing.any?
        end
        (lesson["files"] || {}).each do |name, path|
          next if File.exist?(File.join(@root, "html", path))
          add("structure", "ERROR", "missing-file", where: where(lesson), message: "files: #{name} -> html/#{path} does not exist")
        end
      end
      check_harness_solutions(ids)
    end

    def check_harness_solutions(ids)
      path = File.join(@root, "test", "check_harness.rb")
      return unless File.exist?(path)
      text = File.read(path, encoding: "UTF-8")
      block = text[/^SOLUTIONS = \{\n(.*?)^\}/m, 1] or return
      sol = block.scan(/^  "([^"]+)" => \{/).flatten
      sol += text[/BROWSER_ONLY = %w\[(.*?)\]/m, 1].to_s.split # skipped on purpose
      (ids - sol).each { |id| add("structure", "ERROR", "no-solution", where: id, message: "no SOLUTIONS entry in test/check_harness.rb") }
      (sol - ids).each { |id| add("structure", "WARN", "stale-solution", where: id, message: "SOLUTIONS entry for an id that is not a lesson") }
    end

    # ------------------------------------------------------------ parity
    def check_parity
      check_ui_parity
      lessons.each do |lesson|
        next unless LANGS.all? { |g| lesson[g].is_a?(Hash) }
        types = LANGS.to_h { |g| [g, cells(lesson, g).map { |c| c["t"] }.join] }
        if types.values.uniq.size > 1
          add("parity", "ERROR", "cell-sequence", where: where(lesson), line: line_of(lesson),
              message: "cell types differ: " + types.map { |g, t| "#{g}=#{t}" }.join(" "))
          next # cell-by-cell comparisons would be noise
        end
        cells(lesson, "en").each_with_index do |en, ci|
          ja = cells(lesson, "ja")[ci]
          de = cells(lesson, "de")[ci]
          case en["t"]
          when "c", "x" then compare_code(lesson, ci, en, ja, de)
          when "h" then compare_html(lesson, ci, { "de" => de, "en" => en, "ja" => ja })
          end
          if en["t"] == "x"
            compare_spans(lesson, ci, "hint", { "de" => de["hint"], "en" => en["hint"], "ja" => ja["hint"] })
          end
        end
        compare_gem_usage(lesson)
      end
    end

    def check_ui_parity
      ui = @src.ui
      keys = LANGS.to_h { |g| [g, (ui[g] || {}).keys] }
      all = keys.values.flatten.uniq
      all.each do |k|
        missing = LANGS.reject { |g| ui.dig(g, k) }
        if missing.any?
          add("parity", "ERROR", "ui-missing", where: "ui.#{k}", line: (l = @src.ui_line("en", k)) && "lessons.js:#{l}",
              message: "ui string missing in #{missing.join(", ")}")
          next
        end
        vals = LANGS.to_h { |g| [g, ui[g][k]] }
        if vals.values.map(&:class).uniq.size > 1
          add("parity", "ERROR", "ui-type", where: "ui.#{k}", message: "different types: #{vals.transform_values(&:class)}")
        elsif vals["en"].is_a?(Array)
          sizes = vals.transform_values(&:size)
          add("parity", "INFO", "ui-array-size", where: "ui.#{k}", message: "array sizes #{sizes}") if sizes.values.uniq.size > 1
        else
          vals.each { |g, v| add("parity", "ERROR", "ui-empty", where: "ui.#{k}[#{g}]", message: "empty string") if v.to_s.strip.empty? }
          placeholders = vals.transform_values { |v| v.to_s.scan(/%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdifx%]|%\{\w+\}|%<\w+>[a-z]/).reject { |p| p == "%%" }.sort }
          if placeholders.values.uniq.size > 1
            add("parity", "ERROR", "ui-placeholder", where: "ui.#{k}", line: (l = @src.ui_line("en", k)) && "lessons.js:#{l}",
                message: "format placeholders differ: #{placeholders}")
          end
          tags = vals.transform_values { |v| v.to_s.scan(%r{</?([a-z][a-z0-9]*)}).flatten.sort }
          if tags.values.uniq.size > 1
            add("parity", "WARN", "ui-tags", where: "ui.#{k}", line: (l = @src.ui_line("en", k)) && "lessons.js:#{l}",
                message: "HTML tags differ", detail: tags.map { |g, t| "#{g}: #{t.tally.map { |n, c| c > 1 ? "#{n}×#{c}" : n }.join(" ")}" })
          end
          if vals["ja"] == vals["en"] && vals["en"] =~ /[a-z]{3,} [a-z]{3,} [a-z]{3,}/i && vals["en"] !~ /\A[A-Z][\w ]+\z/
            add("parity", "WARN", "ui-untranslated", where: "ui.#{k}[ja]", message: "ja string equals en: #{Text.snippet(vals["en"])}")
          end
          if vals["de"] == vals["en"] && vals["en"] =~ /\b(the|you|your|and|is|to)\b/i
            add("parity", "WARN", "ui-untranslated", where: "ui.#{k}[de]", message: "de string equals en: #{Text.snippet(vals["en"])}")
          end
        end
      end
    end

    def compare_code(lesson, ci, en, ja, de)
      # Japanese runs the English code: same code once comments are gone
      a = strip_comments(en["code"].to_s)
      b = strip_comments(ja["code"].to_s)
      if a != b
        add("parity", "ERROR", "ja-code", where: where(lesson, "ja", ci), line: line_of(lesson, "ja", ci),
            message: "ja code differs from en (comments ignored)", detail: first_diff(a, b))
      end
      if en["t"] == "x" && en["check"] != ja["check"]
        add("parity", "ERROR", "ja-check", where: where(lesson, "ja", ci), line: line_of(lesson, "ja", ci),
            message: "ja check is not byte-identical to en", detail: first_diff(en["check"].to_s, ja["check"].to_s))
      end
      # comments left in English
      en_comments = comments(en["code"].to_s).to_set
      { "ja" => ja, "de" => de }.each do |lang, cell|
        comments(cell["code"].to_s).each do |c|
          next unless en_comments.include?(c) && english_prose?(c)
          add("parity", "WARN", "untranslated-comment", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
              message: "comment still in English: # #{Text.snippet(c, 70)}", extra: c)
        end
      end
      # the same number of comment lines is a cheap drift signal for de
      ne = comments(en["code"].to_s).size
      { "de" => de, "ja" => ja }.each do |lang, cell|
        n = comments(cell["code"].to_s).size
        next if n == ne
        add("parity", "INFO", "comment-count", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
            message: "#{n} comments vs #{ne} in en")
      end
      # de: same shape (non-blank, non-comment lines), names may differ
      sd = strip_comments(de["code"].to_s).lines.size
      se = a.lines.size
      if (sd - se).abs > [2, se / 5].max
        add("parity", "WARN", "de-code-shape", where: where(lesson, "de", ci), line: line_of(lesson, "de", ci),
            message: "de code has #{sd} code lines, en #{se}")
      end
      # numbers in the code (literals) should match between de and en
      nd = Prism.lex(strip_comments(de["code"].to_s)).value.filter_map { |t, _| t.value if %i[INTEGER FLOAT].include?(t.type) }.sort
      ne2 = Prism.lex(a).value.filter_map { |t, _| t.value if %i[INTEGER FLOAT].include?(t.type) }.sort
      if nd != ne2
        add("parity", "INFO", "de-code-numbers", where: where(lesson, "de", ci), line: line_of(lesson, "de", ci),
            message: "number literals differ from en", detail: ["de only: #{(nd - ne2).uniq.first(8).join(" ")}", "en only: #{(ne2 - nd).uniq.first(8).join(" ")}"])
      end
    end

    def english_prose?(text)
      words = text.downcase.scan(/[a-z']+/)
      return false if words.size < 4
      # commented-out code (starters) is not prose
      return false if text =~ /[(){}\[\]=|]|\.\w|::|\A\s*(def|end|class|module|if|require|puts)\b/
      words.count { |w| STOP_EN.include?(w) } >= 2 && text !~ /[^\x00-\x7F]/
    end

    def first_diff(a, b)
      la = a.lines
      lb = b.lines
      i = (0...[la.size, lb.size].max).find { |k| la[k] != lb[k] } || 0
      ["line #{i + 1}", "en: #{Text.snippet(la[i].to_s, 110)}", "ja: #{Text.snippet(lb[i].to_s, 110)}"]
    end

    BLOCK_TAGS = %w[h2 h3 h4 p ul ol li pre table tr img hr div figure details summary].freeze

    def compare_html(lesson, ci, by_lang)
      html = by_lang.transform_values { |c| c["html"].to_s }
      # block structure
      blocks = html.transform_values do |h|
        h.scan(/<(#{BLOCK_TAGS.join("|")})\b([^>]*)>/).map { |tag, attrs| attrs =~ /class='(\w+)'/ ? "#{tag}.#{$1}" : tag }
      end
      %w[div.task div.offweb pre table img h2 h3].each do |t|
        counts = blocks.transform_values { |b| b.count(t) }
        next if counts.values.uniq.size == 1
        add("parity", "WARN", "block-#{t}", where: where(lesson, nil, ci), line: line_of(lesson, "en", ci),
            message: "<#{t.sub(".", " class=")}> count differs: #{counts}")
      end
      %w[li p].each do |t|
        counts = blocks.transform_values { |b| b.count(t) }
        next if counts.values.uniq.size == 1
        add("parity", "INFO", "block-#{t}", where: where(lesson, nil, ci), line: line_of(lesson, "en", ci),
            message: "<#{t}> count differs: #{counts}")
      end
      # links: the same targets (language variants of a URL count as one)
      links = html.transform_values { |h| h.scan(/href=['"]([^'"]+)['"]/).flatten.map { |u| normalize_url(u) }.sort }
      if links.values.uniq.size > 1
        # the same sites, other pages: a language's own docs (docs.ruby-lang.org/ja
        # is a different manual with other paths) - worth a look, not a warning
        hosts = links.transform_values { |l| l.map { |u| u[%r{\A\w+://([^/]+)}, 1] || u }.uniq.sort }
        same_sites = hosts.values.uniq.size == 1
        add("parity", same_sites ? "INFO" : "WARN", "links", where: where(lesson, nil, ci), line: line_of(lesson, "en", ci),
            message: "link targets differ", detail: LANGS.map { |g| "#{g} only: #{(links[g] - LANGS.flat_map { |o| o == g ? [] : links[o] }).uniq.join(" ")}" }.reject { |s| s.end_with?(": ") })
      end
      # <pre> blocks: identical en/ja once comments are left aside
      pre = html.transform_values { |h| h.scan(%r{<pre>(.*?)</pre>}m).flatten.map { |p| Text.decode(p.gsub(/<[^>]+>/, "")) } }
      pre["en"].zip(pre["ja"]).each_with_index do |(e, j), k|
        next if j.nil? || e == j
        next if (e.lines.reject { |l| l =~ /#/ }) == (j.lines.reject { |l| l =~ /#/ })
        add("parity", "WARN", "pre-block", where: where(lesson, "ja", ci), line: line_of(lesson, "ja", ci),
            message: "<pre> block #{k + 1} differs from en", detail: first_diff(e, j))
      end
      compare_spans(lesson, ci, "html", html)
    end

    def normalize_url(url) = url.sub(%r{/deed\.(de|ja|en)\z}, "/").sub(%r{/(de|en|ja)/}, "/*/")

    # inline `code`: ja runs the English code, so its spans match en's;
    # de has its own names, so only spans that also occur in en count
    def compare_spans(lesson, ci, field, by_lang)
      spans = by_lang.transform_values { |h| Text.code_spans(h.to_s).map { |s| s.strip } }
      en = spans["en"].tally
      ja = spans["ja"].tally
      only_en = en.filter_map { |s, n| s if ja.fetch(s, 0) < n }
      only_ja = ja.filter_map { |s, n| s if en.fetch(s, 0) < n }
      # spans with Japanese placeholders ("sp.solve(式, x)") match their en span
      # with any word in that place; other Japanese spans are translated output
      jp = /[\p{Hiragana}\p{Katakana}\p{Han}ー]+/
      only_ja.select { |s| s =~ jp }.each do |s|
        re = Regexp.new("\\A" + s.split(jp, -1).map { |part| Regexp.escape(part) }.join("[\\w ]+?") + "\\z")
        if (hit = only_en.find { |e| e.match?(re) })
          only_en.delete_at(only_en.index(hit))
        end
      end
      only_ja.reject! { |s| s =~ jp }
      only_en.reject! { |s| s.match?(/\A(Task|Hint)\z/) }
      if only_en.any? || only_ja.any?
        add("parity", "WARN", "code-spans-ja", where: where(lesson, "ja", ci) + (field == "hint" ? " hint" : ""),
            line: line_of(lesson, "ja", ci), message: "inline <code> differs from en",
            detail: ["en only: #{only_en.map(&:inspect).join(", ")}", "ja only: #{only_ja.map(&:inspect).join(", ")}"].reject { |s| s.end_with?(": ") },
            extra: (only_en + only_ja).join("|"))
      end
      # de: language-neutral spans (present in de and en somewhere in the lesson)
      de = spans["de"].tally
      lesson_de = lesson_spans(lesson, "de")
      lesson_en = lesson_spans(lesson, "en")
      neutral = lesson_de & lesson_en
      miss_de = en.filter_map { |s, n| s if neutral.include?(s) && de.fetch(s, 0) < n && s.length > 2 }
      miss_en = de.filter_map { |s, n| s if neutral.include?(s) && en.fetch(s, 0) < n && s.length > 2 }
      return unless miss_de.any? || miss_en.any?
      add("parity", "INFO", "code-spans-de", where: where(lesson, "de", ci) + (field == "hint" ? " hint" : ""),
          line: line_of(lesson, "de", ci), message: "neutral inline <code> differs from en",
          detail: ["en only: #{miss_de.map(&:inspect).join(", ")}", "de only: #{miss_en.map(&:inspect).join(", ")}"].reject { |s| s.end_with?(": ") })
    end

    def lesson_spans(lesson, lang)
      @lesson_spans ||= {}
      @lesson_spans[[lesson["id"], lang]] ||= cells(lesson, lang).flat_map do |c|
        Text.code_spans(c["html"].to_s) + Text.code_spans(c["hint"].to_s) + (c["code"] ? [c["code"].strip] : [])
      end.map(&:strip).to_set
    end

    def gem_usage(code)
      installs = code.scan(/install_gem[ (]\s*["']([^"']+)["']/).flatten
      requires = code.scan(/^\s*require[ (]\s*["']([^"']+)["']/).flatten
      [installs, requires]
    end

    def compare_gem_usage(lesson)
      use = LANGS.to_h do |g|
        all = cells(lesson, g).map { |c| c["code"].to_s }.join("\n")
        [g, gem_usage(all).map(&:sort)]
      end
      return if use.values.uniq.size == 1
      add("parity", "ERROR", "gem-usage", where: where(lesson), line: line_of(lesson),
          message: "install_gem/require differ between languages",
          detail: use.map { |g, (i, r)| "#{g}: install_gem #{i.join(",")} | require #{r.join(",")}" })
    end

    # ------------------------------------------------------------ html
    LEGACY_ENTITIES = %w[amp lt gt quot copy reg not nbsp times divide para sect deg micro cent pound yen
                         shy uml macr ordf ordm laquo raquo acute cedil middot plusmn curren brvbar iexcl
                         iquest frac14 frac12 frac34 sup1 sup2 sup3 szlig auml ouml uuml].join("|")
    VOID = %w[br img hr input meta link wbr].to_set
    KNOWN_TAGS = (VOID.to_a + %w[a abbr b blockquote caption cite code dd del details div dl dt em figcaption figure
                                  h1 h2 h3 h4 h5 h6 i ins kbd li mark ol p pre q s samp small span strong sub summary
                                  sup table tbody td tfoot th thead tr u ul var ruby rt rp svg path button label
                                  input select option textarea canvas video audio source iframe nav section
                                  article header footer aside main time output progress meter]).to_set

    def check_html
      each_cell do |lesson, _li, lang, cell, ci|
        %w[html hint].each do |field|
          h = cell[field] or next
          balance(h).each do |problem|
            add("html", "ERROR", "unbalanced", where: where(lesson, lang, ci) + (field == "hint" ? " hint" : ""),
                line: line_of(lesson, lang, ci), message: problem, extra: problem)
          end
          # a raw < that is not a tag (e.g. "<%=" or "a < b") in prose
          h.scan(/<(?![a-zA-Z\/!])(.{0,15})/) do |(after)|
            # "< " is text to an HTML parser; "<foo" would be eaten as a tag (unknown-tag)
            add("html", "INFO", "raw-lt", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                message: "unescaped '<' before #{after.inspect} - use &lt;", extra: after)
          end
          # browsers decode a few legacy entities even without ";":
          # "&notice" shows as "¬ice", "&copy_file" as "©_file"
          h.scan(/&(#{LEGACY_ENTITIES})(?![;a-zA-Z0-9]*;)(.{0,10})/o) do |ent, after|
            add("html", "ERROR", "legacy-entity", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                message: "'&#{ent}#{after}' renders as an entity (&#{ent} needs no ';') - write &amp;#{ent}", extra: ent + after)
          end
          h.scan(/&(?!(?:[a-z]+|#\d+|#x[0-9a-f]+);)(.{0,10})/i) do |(after)|
            next if after =~ /\A(#{LEGACY_ENTITIES})/o
            add("html", "INFO", "raw-amp", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                message: "unescaped '&' before #{after.inspect}", extra: after)
          end
        end
      end
    end

    def balance(html)
      stack = []
      problems = []
      html.scan(%r{<(/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*?(/?)>}) do |close, tag, self_close|
        tag = tag.downcase
        unless KNOWN_TAGS.include?(tag)
          problems << "<#{tag}> is no HTML tag - an unescaped '<' in text? (the browser hides it)"
          next
        end
        next if VOID.include?(tag) || self_close == "/"
        if close.empty?
          stack << tag
        elsif stack.last == tag
          stack.pop
        elsif (i = stack.rindex(tag))
          problems << "<#{stack[(i + 1)..].join("><")}> not closed before </#{tag}>"
          stack = stack[0...i]
        else
          problems << "stray </#{tag}>"
        end
      end
      problems << "unclosed <#{stack.join("><")}>" if stack.any?
      problems
    end

    # ------------------------------------------------------------ refs
    REF = {
      "de" => /Lektion(?:en)?\s*(\d+)(?:\s*(?:[–-]|bis)\s*(\d+))?/,
      "en" => /\b[Ll]essons?\s+(\d+)(?:\s*(?:[–-]|to)\s*(\d+))?/,
      "ja" => /レッスン\s*(\d+)(?:\s*[〜~～–-]\s*(\d+))?/
    }.freeze

    def check_refs
      count = lessons.size
      keywords = distinctive_keywords
      all_refs = {}
      each_cell do |lesson, li, lang, cell, ci|
        texts = []
        texts << ["html", Text.plain(cell["html"])] if cell["html"]
        texts << ["hint", Text.plain(cell["hint"])] if cell["hint"]
        texts << ["code", comments(cell["code"]).join("\n")] if cell["code"]
        refs = []
        texts.each do |field, text|
          text.scan(REF[lang]) do
            m = Regexp.last_match
            nums = [m[1].to_i, m[2]&.to_i].compact
            refs.concat(nums)
            loc = where(lesson, lang, ci)
            nums.each do |n|
              if n < 1 || n > count
                add("refs", "ERROR", "ref-range", where: loc, line: line_of(lesson, lang, ci),
                    message: "#{m[0].inspect} - there are only #{count} lessons", extra: m[0])
                next
              end
              next if m[2] # ranges: checked by the counts group
              ctx = sentence_around(text, m.begin(0), m.end(0))
              near = text[[m.begin(0) - 30, 0].max...[m.end(0) + 30, text.length].min]
              verdict = judge_context(ctx, near, n, keywords, li)
              target = lessons[n - 1]
              row = "#{lesson["id"]}[#{lang}] -> #{n} (#{target["id"]}) #{verdict[:status]}#{verdict[:via] ? " (#{verdict[:via].join(", ")})" : ""}: …#{Text.snippet(ctx, 100)}…"
              (all_refs[verdict[:status]] ||= []) << row
              next unless verdict[:status] == :suspect
              add("refs", "WARN", "ref-context", where: loc, line: line_of(lesson, lang, ci),
                  message: "#{m[0].inspect} points at #{target["id"]} (#{target.dig(lang, "title")}), " \
                           "but the sentence names #{verdict[:other].map { |k, i| "#{k} (lesson #{i + 1}, #{lessons[i]["id"]})" }.join(", ")}",
                  detail: ["…#{Text.snippet(ctx, 140)}…"], extra: m[0])
            end
            if nums.first && nums.first == li + 1 && field != "code"
              add("refs", "INFO", "ref-self", where: loc, message: "#{m[0].inspect} refers to its own lesson", extra: m[0])
            end
          end
        end
        (@refs_by_cell ||= {})[[lesson["id"], ci, lang]] = refs.sort
      end
      # the same references in all three languages
      lessons.each do |lesson|
        cells(lesson, "en").each_index do |ci|
          per = LANGS.to_h { |g| [g, @refs_by_cell.fetch([lesson["id"], ci, g], [])] }
          next if per.values.uniq.size == 1
          add("refs", "WARN", "ref-parity", where: where(lesson, nil, ci), line: line_of(lesson, "en", ci),
              message: "lesson references differ between languages: #{per.map { |g, r| "#{g}=#{r.inspect}" }.join(" ")}")
        end
      end
      @ref_table = all_refs
      all_refs.each do |status, rows|
        next if status == :suspect
        add("refs", "INFO", "ref-table-#{status}", where: "(all)", message: "#{rows.size} references #{status}", detail: rows)
      end
      check_anchors
      check_against_base if @base
    end

    # numbers referenced in one cell, in order
    def cell_refs(lang, cell)
      text = [cell["html"], cell["hint"]].compact.map { |h| Text.plain(h) }.join("\n")
      text += "\n" + comments(cell["code"]).join("\n") if cell["code"]
      text.scan(REF[lang]).flat_map { |a, b| [a.to_i, b&.to_i].compact }
    end

    # --base=GITREF: a reference that pointed at lesson X in the base version
    # must still point at X. Catches renumbering exactly (no keywords needed).
    def check_against_base
      base_lessons = @base["lessons"]
      base_by_id = base_lessons.to_h { |l| [l["id"], l] }
      base_num = base_lessons.each_with_index.to_h { |l, i| [i + 1, l["id"]] }
      cur_num = lessons.each_with_index.to_h { |l, i| [i + 1, l["id"]] }
      moved = base_num.select { |n, id| cur_num[n] != id }
      add("refs", "INFO", "base-moved", where: "(all)", message: "#{moved.size} lesson numbers changed since the base",
          detail: moved.map { |n, id| "#{n}: was #{id}, now #{cur_num[n] || "-"}" }) if moved.any?
      lessons.each do |lesson|
        old = base_by_id[lesson["id"]] or next
        LANGS.each do |lang|
          cells(lesson, lang).each_with_index do |cell, ci|
            ocell = old.dig(lang, "cells", ci) or next
            now = cell_refs(lang, cell)
            before = cell_refs(lang, ocell)
            next if now.empty? || now.size != before.size # edited: the keyword check covers it
            now.zip(before).each do |n, b|
              was = base_num[b]
              is = cur_num[n]
              next if was == is
              add("refs", "ERROR", "ref-moved", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                  message: "reference #{n} now points at #{is.inspect}, it meant #{was.inspect} (lesson #{b} in the base; now #{cur_num.key(was) || "gone"})",
                  extra: "#{n}")
            end
          end
        end
      end
    end

    SENTENCE_END = /[.!?](?=\s|\z)|[。！？]/

    def sentence_around(text, from, to)
      start = 0
      text[0...from].to_enum(:scan, SENTENCE_END).each { start = Regexp.last_match.end(0) }
      stop = (m = SENTENCE_END.match(text, to)) ? m.end(0) : text.length
      text[start...stop]
    end

    # words that name exactly one lesson and are rare in the course text:
    # "Roda", "pandas", "Minitest" - not "timesheet" or "own"
    def distinctive_keywords
      stop = STOP_EN | %w[mit und der die das den ein eine aus im von zu dem des fur für auf deine eigene
                          ruby data project projekt timelog finale web parsen parsing text daten building
                          bauen richtig methods methoden properly whole arrays array grundkurs own line
                          genau wenn rechnen code eigene installing installieren]
      owner = Hash.new { |h, k| h[k] = Set.new }
      lessons.each_with_index do |l, i|
        # names survive translation: a word in at least two languages' titles
        # (Roda, pandas, IRB, Minitest) - "ganze" or "command" do not
        per_lang = LANGS.map do |g|
          l.dig(g, "title").to_s.sub(/\A\d+\.\s*/, "").scan(/[A-Za-zÄÖÜäöüß][\w-]{2,}/).map { |w| w.downcase.sub(/-rb\z/, "") }.uniq
        end
        words = per_lang.flatten.tally.select { |_, n| n >= 2 }.keys
        words.each { |w| owner[w] << i unless stop.include?(w) || w.length < 3 }
      end
      texts = lessons.map { |l| %w[de en].map { |g| cells(l, g).map { |c| Text.plain(c["html"].to_s) }.join(" ") }.join(" ").downcase }
      owner.select do |w, s|
        next false unless s.size == 1
        texts.count { |t| t.match?(/(?<![a-z0-9_äöüß-])#{Regexp.escape(w)}(?![a-z0-9_äöüß-])/) } <= 6
      end.transform_values(&:first)
    end

    # :confirmed - the sentence names the target's topic; :suspect - right
    # next to the number stands another lesson's topic ("Roda from lesson 15",
    # "レッスン23のpandas"), not the target's and not the current lesson's;
    # a sentence that merely lists several topics is not suspect
    def judge_context(ctx, near, n, keywords, here)
      own = keyword_hits(ctx, keywords).select { |_, i| i == n - 1 }
      other = keyword_hits(near, keywords).reject { |_, i| i == n - 1 || i == here }
      return { status: :confirmed } if own.any?
      return { status: :suspect, other: other } if other.any?
      # weaker: a rare word or identifier of the sentence occurs in the target
      shared = rare_tokens(ctx).select { |t| lesson_tokens(n - 1).include?(t) }
      return { status: :"confirmed by content", via: shared.first(3) } if shared.any?
      { status: :unverified }
    end

    def keyword_hits(text, keywords)
      low = text.downcase
      # ASCII boundaries: in "レッスン23のpandas" the kana count as \p{Word}
      keywords.select { |w, _| low.match?(/(?<![a-z0-9_äöüß-])#{Regexp.escape(w)}(?![a-z0-9_äöüß-])/) }
    end

    TOKEN = /[a-z_][a-z0-9_?!]{3,}/

    # lowercase words/identifiers of a lesson (de + en prose and code)
    def lesson_tokens(i)
      @lesson_tokens ||= lessons.map do |l|
        %w[de en].flat_map do |g|
          cells(l, g).flat_map { |c| [Text.plain(c["html"].to_s), c["code"].to_s, Text.plain(c["hint"].to_s)] }
        end.join(" ").downcase.scan(TOKEN).to_set
      end
      @lesson_tokens[i]
    end

    def rare_tokens(text)
      @token_df ||= begin
        df = Hash.new(0)
        lessons.each_index { |i| lesson_tokens(i).each { |t| df[t] += 1 } }
        df
      end
      text.downcase.scan(TOKEN).uniq.select { |t| @token_df[t].between?(1, 4) && !STOP_EN.include?(t) }
    end

    def check_anchors
      ids = lessons.map { |l| l["id"] }.to_set
      routes = ids | %w[werkstatt workshop] # non-lesson routes the shell knows
      each_cell do |lesson, _li, lang, cell, ci|
        %w[html hint].each do |f|
          cell[f].to_s.scan(/href=['"](?:\/(?:de|en|ja)\/|\/?#)([\w-]+)['"]/) do |(target)|
            next if routes.include?(target)
            add("refs", "ERROR", "anchor", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                message: "link to ##{target}, which is no lesson id", extra: target)
          end
        end
      end
      %w[README.md docs/HANDOVER.md docs/OPEN_WORK.md docs/PICORUBY_SHELL.md].each do |doc|
        path = File.join(@root, doc)
        next unless File.exist?(path)
        File.readlines(path, encoding: "UTF-8").each_with_index do |line, n|
          line.scan(%r{(?:`|\()/(?:#|(?:de|en|ja)/)([a-z][\w-]*)}) do |(target)|
            next if routes.include?(target)
            add("refs", "WARN", "doc-anchor", where: doc, line: "#{doc}:#{n + 1}",
                message: "/##{target} is no lesson id", extra: target)
          end
        end
      end
    end

    # ------------------------------------------------------------ ja
    POLITE = /(?:ます|ました|ません|ましょう|ませんか|ましょうか|です|でした|でしょう|でしょうか|ください|ですね|ますね|ですよ|ますよ|ません ?ね|か|ね|よ)\z/
    PLAIN = /(?:だ|である|だった|ではない|じゃない|ない|る|た|う|く|す|つ|ぬ|む|ぶ|ぐ|ろ|い)\z/

    def check_ja
      labels = Hash.new { |h, k| h[k] = Hash.new(0) }
      each_cell do |lesson, _li, lang, cell, _ci|
        next unless cell["html"]
        cell["html"].scan(%r{<div class='task'><strong>([^<]*)</strong>}) { |(l)| labels[[lang, "task"]][l] += 1 }
        cell["html"].scan(/<div class='offweb' data-title='([^']*)'/) { |(l)| labels[[lang, "offweb"]][l] += 1 }
      end
      each_cell do |lesson, _li, lang, cell, ci|
        html = cell["html"].to_s
        html.scan(%r{<div class='task'>(?!<strong>)}) do
          add("ja", "WARN", "task-label", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
              message: "task block does not start with <strong>label</strong>")
        end
        { "task" => %r{<div class='task'><strong>([^<]*)</strong>}, "offweb" => /<div class='offweb' data-title='([^']*)'/ }.each do |kind, re|
          html.scan(re) do |(l)|
            common = labels[[lang, kind]].max_by { |_, c| c }&.first
            next if l == common || l.start_with?(common.to_s) # "On your machine: profilers"
            add("ja", kind == "task" ? "WARN" : "INFO", "#{kind}-label", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                message: "#{kind} label #{l.inspect}, elsewhere #{common.inspect}", extra: l)
          end
        end
        next unless lang == "ja"
        check_ja_prose(lesson, ci, cell) if cell["html"]
        check_ja_hint(lesson, ci, cell) if cell["hint"]
      end
      # German or English left in Japanese, German left in English
      each_cell do |lesson, _li, lang, cell, ci|
        next if lang == "de"
        [cell["html"], cell["hint"]].compact.each do |h|
          text = Text.prose(h)
          if (m = text.match(/\b(?:Lektion|Aufgabe|Hinweis|nicht|oder|Beispiel|Schreibe|Zahl|sind)\b|[äöüÄÖÜß]\p{L}*/))
            next if m[0] =~ /\A(Zürich|Jürgen|Ruby|Matz|Jöran|Björn|Möbius|Gödel|Füße)/ # names
            add("ja", "WARN", "german-left", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                message: "German in #{lang} prose? #{m[0].inspect} in …#{Text.snippet(text[[m.begin(0) - 30, 0].max, 80], 80)}…", extra: m[0])
          end
          next unless lang == "ja"
          # a run of English prose (6+ words incl. 2 stop words) outside <code>
          text.scan(/[A-Za-z][A-Za-z',]*(?:\s+[A-Za-z][A-Za-z',]*){5,}/) do
            run = Regexp.last_match(0)
            next unless run.downcase.scan(/[a-z']+/).count { |w| STOP_EN.include?(w) } >= 2
            add("ja", "WARN", "english-left", where: where(lesson, "ja", ci), line: line_of(lesson, "ja", ci),
                message: "English sentence in ja prose: #{Text.snippet(run, 80)}", extra: run)
          end
        end
      end
      check_ja_titles
    end

    def check_ja_prose(lesson, ci, cell)
      html = cell["html"]
      # list items, table cells and headings may end in plain form/nouns
      body = html.gsub(%r{<(li|td|th|h2|h3|summary|figcaption)\b[^>]*>.*?</\1>}m, " ")
      text = Text.prose(body, code_marker: "〔code〕")
      text = text.gsub(/（[^（）]*）/, "〔paren〕") # "（等しい。イコールを2つ！）" is an aside
      text.split(/(?<=[。！？!?])/).each do |sentence|
        s = sentence.strip
        next unless s.end_with?("。")
        core = s.delete_suffix("。").strip
        next if core =~ /[」』）)\]]\z/ # ends in a quote or a parenthesised list: not the predicate
        next if core.empty? || core.end_with?("〔code〕")
        next if core =~ POLITE
        next unless core =~ PLAIN
        next if core =~ /(?:\p{Han}|\p{Katakana}|[A-Za-z0-9])\z/ # noun ending (taigen-dome), fine
        next if core =~ /(?:ひとつ|ふたつ|みっつ|こと|もの|とき|ため|ところ|だけ|など)\z/ # nouns in hiragana
        next if core =~ /(?:\A|[\s、])\d+[.．]\s/ # numbered steps: "1. メッセージを読む。"
        next if core.scan(/、〔code〕/).size >= 2 # an enumeration of operators/methods
        next if core =~ /\A(?:課題|ヒント|例)：/ # a label line
        add("ja", "WARN", "plain-form", where: where(lesson, "ja", ci), line: line_of(lesson, "ja", ci),
            message: "not です・ます: …#{Text.snippet(core[-40..] || core, 50)}。", extra: core[-20..] || core)
      end
    end

    def check_ja_hint(lesson, ci, cell)
      text = Text.prose(cell["hint"], code_marker: "〔code〕")
      polite = text.scan(/(?:です|ます|ました|ましょう|ください)(?=[。！!？?]|\z)/)
      return if polite.empty?
      add("ja", "INFO", "hint-polite", where: where(lesson, "ja", ci) + " hint", line: line_of(lesson, "ja", ci),
          message: "hint uses です・ます (#{polite.uniq.join(", ")}); Chunky's hints are casual",
          detail: [Text.snippet(text, 120)])
    end

    def check_ja_titles
      lessons.each do |lesson|
        en = lesson.dig("en", "title").to_s.sub(/\A\d+\.\s*/, "")
        ja = lesson.dig("ja", "title").to_s.sub(/\A\d+\.\s*/, "")
        next unless ja == en && en =~ /[a-z]{3,}\s+[a-z]{3,}/i && en !~ /Hello, World/
        add("ja", "INFO", "title-untranslated", where: where(lesson, "ja"), message: "ja title equals en: #{ja}")
      end
    end

    # ------------------------------------------------------------ ruby
    LONG = 100 # display columns; at 90 a dozen fine hash/regex lines showed up

    def check_ruby
      lessons.each do |lesson|
        LANGS.each do |lang|
          locals = []
          cells(lesson, lang).each_with_index do |cell, ci|
            loc = where(lesson, lang, ci)
            line = line_of(lesson, lang, ci)
            if (code = cell["code"])
              res = Prism.parse(code, scopes: [locals.dup])
              res.errors.each do |e|
                add("ruby", "ERROR", "syntax", where: loc, line: line,
                    message: "code line #{e.location.start_line}: #{e.message}", extra: e.message)
              end
              res.warnings.each do |w|
                next if w.message =~ /assigned but unused variable/ # the notebook shows it, a later cell uses it
                add("ruby", "WARN", "warning", where: loc, line: line,
                    message: "code line #{w.location.start_line}: #{w.message}", extra: w.message)
              end
              locals |= res.value.locals if res.success?
              long_lines(code, loc, line)
              if code =~ /[ \t]+$/
                add("ruby", "INFO", "trailing-space", where: loc, line: line, message: "trailing whitespace in code")
              end
              add("ruby", "INFO", "tab", where: loc, line: line, message: "tab in code") if code.include?("\t")
            end
            if (check = cell["check"])
              res = Prism.parse(check, scopes: [locals | %i[output result code images downloads]])
              res.errors.each do |e|
                add("ruby", "ERROR", "check-syntax", where: loc, line: line, message: "check: #{e.message}", extra: e.message)
              end
              res.warnings.each do |w|
                add("ruby", "WARN", "check-warning", where: loc, line: line, message: "check: #{w.message}", extra: w.message)
              end
            end
            # Ruby shown in <pre> (not shell sessions)
            cell["html"].to_s.scan(%r{<pre><code>(.*?)</code></pre>}m).each do |(raw)|
              src = Text.decode(raw)
              next if src =~ /\A\s*[$>%]|irb\(main\)|^\s*\$ /
              res = Prism.parse(src)
              next if res.success?
              add("ruby", "INFO", "pre-syntax", where: loc, line: line,
                  message: "<pre> block does not parse as Ruby: #{res.errors.first.message}", extra: res.errors.first.message)
            end
          end
        end
      end
    end

    # cells do not wrap: the 44rem column (app.css --column) at 15px mono
    # shows about 76 columns, a longer line scrolls sideways
    VISIBLE = 76

    def long_lines(code, loc, line)
      code.lines.each_with_index do |l, i|
        w = Text.width(l.chomp)
        next if w <= VISIBLE
        add("ruby", w > LONG ? "WARN" : "INFO", "long-line", where: loc, line: line,
            message: "code line #{i + 1} is #{w} columns wide (#{w > LONG ? "> #{LONG}" : "scrolls sideways beyond ~#{VISIBLE}"})",
            detail: [Text.snippet(l, 110)], extra: "L#{i + 1}")
      end
    end

    # ------------------------------------------------------------ gems
    def check_gems
      m = @gems.manifest
      m.each do |name, entry|
        unless File.exist?(File.join(@gems.dir, entry["file"].to_s))
          add("gems", "ERROR", "cache-file", where: "manifest.#{name}", message: "#{entry["file"]} missing in html/gems/cache")
        end
        (entry["deps"] || []).each do |d|
          next if m.key?(@gems.substitutes.fetch(d, d))
          next if @gems.native.include?(d) || @gems.optional.fetch(name, []).include?(d) # builtin/stand-in/skipped
          add("gems", "WARN", "cache-dep", where: "manifest.#{name}", message: "dependency #{d} is not in the cache (fetched online)")
        end
      end
      listed = m.values.map { |e| e["file"] }.to_set
      Dir.children(@gems.dir).grep(/\.gem\z/).each do |f|
        add("gems", "WARN", "cache-orphan", where: "html/gems/cache/#{f}", message: "not in manifest.json") unless listed.include?(f)
      end
      lessons.each do |lesson|
        LANGS.each do |lang|
          installed = Set.new
          cells(lesson, lang).each_with_index do |cell, ci|
            code = cell["code"] or next
            code.each_line do |l|
              if (g = l[/^\s*install_gem[ (]\s*["']([^"']+)["']/, 1])
                name = @gems.substitutes.fetch(g, g)
                if @gems.native.include?(g)
                  add("gems", "WARN", "native", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                      message: "install_gem #{g.inspect}: a native gem (works only if built into the wasm image)", extra: g)
                elsif !m.key?(name)
                  add("gems", "WARN", "not-cached", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                      message: "install_gem #{g.inspect} is not in html/gems/cache: needs the network, fails offline and in live runs", extra: g)
                end
                installed |= @gems.deps_closure(g)
              elsif (feat = l[/^\s*require[ (]\s*["']([^"']+)["']/, 1])
                owner = @gems.provides[feat]
                next if owner.nil? || installed.include?(owner)
                first = feat.split("/").first
                next if m.key?(@gems.substitutes.fetch(first, first)) # auto_install_feature covers it
                add("gems", "WARN", "require-before-install", where: where(lesson, lang, ci), line: line_of(lesson, lang, ci),
                    message: "require #{feat.inspect} needs the gem #{owner}, but no install_gem #{owner.inspect} comes before it in this lesson " \
                             "(auto-install only works when the feature starts with the gem name)", extra: feat)
              end
            end
          end
        end
      end
    end

    # ------------------------------------------------------------ counts
    COUNT_FILES = %w[README.md docs/*.md test/*.mjs test/*.rb test/shell/**/*.rb html/index.html
                     html/shell/**/*.{rb,js,html} server/**/*.rb gem/**/README.md].freeze

    def check_counts
      count = lessons.size
      files = COUNT_FILES.flat_map { |g| Dir.glob(File.join(@root, g)) }.uniq
      files.each do |path|
        rel = path.delete_prefix("#{@root}/")
        File.readlines(path, encoding: "UTF-8").each_with_index do |text, n|
          text.scan(/(?<![§\d.])(\d+)\s*(lessons|Lektionen|レッスン)(?!\s*\d)/) do |num, word|
            k = num.to_i
            next if k == count || k < 5 # "3 lessons" style small numbers are rarely the total
            add("counts", "WARN", "stale-count", where: rel, line: "#{rel}:#{n + 1}",
                message: "\"#{num} #{word}\" but there are #{count} lessons", detail: [Text.snippet(text, 120)], extra: "#{num}#{word}")
          end
          text.scan(/(\d+)\s*(?:lessons|Lektionen)\s*[x×]\s*3/) do |(num)|
            next if num.to_i == count
            add("counts", "WARN", "stale-count", where: rel, line: "#{rel}:#{n + 1}",
                message: "\"#{num} lessons × 3\" but there are #{count} lessons", extra: "#{num}x3")
          end
        end
      end
      @src.ui.each do |lang, strings|
        strings.each do |k, v|
          Array(v).each do |s|
            s.to_s.scan(/(\d+)\s*(lessons|Lektionen|レッスン)/) do |num, _|
              next if num.to_i == count
              add("counts", "ERROR", "ui-count", where: "ui.#{k}[#{lang}]", message: "says #{num} lessons, there are #{count}")
            end
          end
        end
      end
      check_section_ranges
    end

    # "side trips, 19-30" in the docs vs the sections in lessons.js
    def check_section_ranges
      starts = lessons.each_index.select { |i| lessons[i]["section"] }
      ranges = starts.each_with_index.map do |s, k|
        last = (starts[k + 1] || lessons.size) - 1
        [lessons[s]["section"], s + 1, last + 1]
      end
      %w[README.md docs/HANDOVER.md].each do |doc|
        path = File.join(@root, doc)
        next unless File.exist?(path)
        File.readlines(path, encoding: "UTF-8").each_with_index do |line, n|
          ranges.each do |names, first, last|
            pat = names.values.map { |v| Regexp.escape(v) }.join("|")
            pat += "|side trips" if names["de"] == "Ausflüge"
            line.scan(/(?:#{pat})[^0-9\n]{0,25}(\d+)\s*[-–]\s*(\d+)/i) do |a, b|
              next if [a.to_i, b.to_i] == [first, last]
              add("counts", "WARN", "section-range", where: doc, line: "#{doc}:#{n + 1}",
                  message: "#{names["en"]} is given as #{a}-#{b}, lessons.js has #{first}-#{last}", extra: "#{a}-#{b}")
            end
          end
        end
      end
    end

    # ------------------------------------------------------------ links
    def check_links
      urls = Hash.new { |h, k| h[k] = [] }
      each_cell do |lesson, _li, lang, cell, ci|
        [cell["html"], cell["hint"]].compact.each do |h|
          h.scan(/href=['"]([^'"]+)['"]/) { |(u)| urls[Text.decode(u)] << where(lesson, lang, ci) }
        end
      end
      urls.each do |u, places|
        next if u.start_with?("http")
        next if u.start_with?("#") || u.start_with?("mailto:")
        rel = u.sub(%r{\A\./}, "").sub(/[?#].*/, "")
        next if rel.empty? || rel.start_with?("/") # app routes inside code demos
        next if File.exist?(File.join(@root, "html", rel))
        add("links", "ERROR", "local-link", where: places.first, message: "link #{u} has no file in html/", extra: u)
      end
      return unless @net
      require "net/http"
      urls.keys.grep(%r{\Ahttps?://}).sort.each do |u|
        status = head(u)
        next if status.is_a?(Integer) && status < 400
        add("links", "WARN", "dead-link", where: urls[u].first,
            message: "#{u} -> #{status} (#{urls[u].size} places)", extra: u)
      end
    end

    def head(url, limit = 4)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 8, read_timeout: 8) do |http|
        req = Net::HTTP::Head.new(uri)
        req["User-Agent"] = "chunkybacon-lesson-lint"
        res = http.request(req)
        if res.is_a?(Net::HTTPRedirection) && limit.positive?
          return head(URI.join(url, res["location"]).to_s, limit - 1)
        end
        if [403, 405].include?(res.code.to_i) # some hosts refuse HEAD
          res = http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-lesson-lint", "Range" => "bytes=0-0"))
        end
        res.code.to_i
      end
    rescue StandardError => e
      e.class.name
    end
  end

  # ---------------------------------------------------------------- report
  class Report
    def initialize(findings, verbose:, color:)
      @findings = findings
      @verbose = verbose
      @color = color
    end

    def paint(s, c) = @color ? "\e[#{c}m#{s}\e[0m" : s

    def print
      shown = @findings.reject(&:allowed)
      shown = shown.reject { |f| f.severity == "INFO" } unless @verbose
      GROUPS.each do |g|
        fs = shown.select { |f| f.group == g }
        next if fs.empty?
        counts = SEVERITIES.filter_map { |s| (n = fs.count { |f| f.severity == s }).positive? ? "#{n} #{s.downcase}" : nil }
        puts paint("== #{g} (#{counts.join(", ")})", "1")
        fs.sort_by { |f| [SEVERITIES.index(f.severity), f.code, f.where] }.each do |f|
          sev = paint(f.severity.ljust(5), { "ERROR" => "31", "WARN" => "33", "INFO" => "36" }[f.severity])
          puts "  #{sev} #{f.where}#{f.line ? "  (#{f.line})" : ""}  [#{f.code}]"
          puts "        #{f.message}"
          Array(f.detail).first(@verbose ? 200 : 6).each { |d| puts "          #{d}" }
          puts "        key: #{f.key}" if @verbose
        end
        puts
      end
      summary
    end

    def summary
      live = @findings.reject(&:allowed)
      t = SEVERITIES.to_h { |s| [s, live.count { |f| f.severity == s }] }
      allowed = @findings.count(&:allowed)
      puts "#{t["ERROR"]} errors, #{t["WARN"]} warnings, #{t["INFO"]} info" \
           "#{allowed.positive? ? ", #{allowed} allowed (lint_allow.txt)" : ""}" \
           "#{@verbose ? "" : " (--verbose shows info)"}"
    end
  end

  def self.main(argv)
    opts = { root: File.expand_path("..", __dir__), verbose: false, json: false, net: false,
             only: GROUPS, allow: File.join(__dir__, "lint_allow.txt"), color: $stdout.tty? }
    OptionParser.new do |o|
      o.on("--root=PATH") { |v| opts[:root] = File.expand_path(v) }
      # a typo must not narrow the run to nothing and still report "0 errors"
      o.on("--only=GROUPS") do |v|
        want = v.split(",")
        unknown = want - GROUPS
        abort "--only: unknown group(s) #{unknown.join(", ")} (known: #{GROUPS.join(", ")})" if unknown.any? || want.empty?
        opts[:only] = want
      end
      o.on("--verbose", "-v") { opts[:verbose] = true }
      o.on("--json") { opts[:json] = true }
      o.on("--net") { opts[:net] = true }
      o.on("--base=GITREF", "compare references with lessons.js at GITREF (e.g. origin/main)") { |v| opts[:base] = v }
      o.on("--allow=FILE") { |v| opts[:allow] = v }
      o.on("--no-allow") { opts[:allow] = nil }
      o.on("--[no-]color") { |v| opts[:color] = v }
    end.parse!(argv)
    $stdout.set_encoding("UTF-8")
    base_text = nil
    if opts[:base]
      require "open3"
      # read-only: git show prints the file at that revision
      base_text, status = Open3.capture2("git", "-C", opts[:root], "show", "#{opts[:base]}:html/lessons.js")
      abort "--base: git show #{opts[:base]}:html/lessons.js failed" unless status.success?
      base_text.force_encoding("UTF-8")
    end
    linter = Linter.new(opts[:root], allow_path: opts[:allow], net: opts[:net], base_text: base_text)
    findings = linter.run(opts[:only])
    if opts[:json]
      puts JSON.pretty_generate(findings.map(&:to_h))
    else
      Report.new(findings, verbose: opts[:verbose], color: opts[:color]).print
    end
    findings.any? { |f| f.severity == "ERROR" && !f.allowed } ? 1 : 0
  end
end

exit LessonLint.main(ARGV) if $PROGRAM_NAME == __FILE__
