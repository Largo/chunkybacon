# Size and token counts for docs/PICORUBY_SHELL.md: the frontend before and
# after the PicoRuby shell, and the shell with and without its jsg-style
# sugar. There is no model tokenizer offline, so it reports bytes, lines, a
# lexical token count (Prism.lex for Ruby, a regex split for JavaScript) and
# an estimate of model tokens at 3.5 bytes each - for code with and
# without comments.
#
#   ruby tools/shell_metrics.rb                 # tables (markdown) on stdout
#   ruby tools/shell_metrics.rb --desugar DIR   # also write the sugar-free shell to DIR
#   BASE_REV=<commit> ruby tools/shell_metrics.rb   # "before" = that commit (default:
#                                                   # the parent of the commit that added html/shell/)
#
# The desugared shell is the same program in PicoRuby's plain interop:
# el.x = v -> el[:x] = v, JSG.w -> JS.global, JSG.d -> JS.document,
# JSG.q(s) -> JS.document.querySelectorAll(s), JSG.w.Name -> JS.global[:Name].
# Reads without brackets (el.textContent) stay: PicoRuby does those itself.
# test/shell/ runs against it (SHELL_DIR=DIR) to show it is the same program.
require "prism"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
BYTES_PER_TOKEN = 3.5

def git_show(rev, path)
  IO.popen(["git", "-C", ROOT, "show", "#{rev}:#{path}"], &:read)
end

# "before" is the commit just before the shell arrived (html/shell/ added)
def base_rev
  return ENV["BASE_REV"] if ENV["BASE_REV"]

  added = IO.popen(["git", "-C", ROOT, "log", "--diff-filter=A", "--format=%H", "--", "html/shell/manifest.txt"], &:read)
  first = added.split.last or abort "html/shell/manifest.txt is not in the history - set BASE_REV"
  IO.popen(["git", "-C", ROOT, "rev-parse", "#{first}^"], &:read).strip
end

def lf(text) = text.gsub("\r\n", "\n")

# ---------- Ruby ----------

def ruby_code_only(source)
  result = Prism.parse(source)
  code = source.b   # Prism's offsets count bytes
  result.comments.each do |comment|
    loc = comment.location
    code[loc.start_offset...loc.end_offset] = " " * (loc.end_offset - loc.start_offset)
  end
  code.force_encoding(Encoding::UTF_8).lines.map(&:rstrip).reject(&:empty?).join("\n") + "\n"
end

def ruby_tokens(source)
  skip = %i[COMMENT NEWLINE IGNORED_NEWLINE EOF EMBDOC_BEGIN EMBDOC_LINE EMBDOC_END __END__ WORDS_SEP]
  Prism.lex(source).value.count { |token, _state| !skip.include?(token.type) }
end

# ---------- JavaScript ----------

JS_TOKEN = %r{
  (?<comment>//[^\n]*|/\*.*?\*/)
  |(?<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)
  |(?<word>[A-Za-z_$][\w$]*|\d+(?:\.\d+)?)
  |(?<space>\s+)
  |(?<punct>===|!==|==|!=|<=|>=|&&|\|\||=>|\+\+|--|[-+*/%=<>!&|?:;,.(){}\[\]^~])
}mx

# a regex literal where an expression starts ("/\.rb(\?|#|$)/")
JS_REGEX = %r{\A/(?:\\.|\[(?:\\.|[^\]])*\]|[^/\\\n])+/[gimsuy]*}

def js_scan(source)
  tokens = []
  pos = 0
  last = nil
  while pos < source.length
    if source[pos] == "/" && (last.nil? || last.match?(/\A[(,=:\[!&|?{};]\z|\A(return|typeof)\z/)) && (m = JS_REGEX.match(source[pos..]))
      tokens << [:regex, m[0]]
      last = m[0]
      pos += m[0].length
      next
    end
    m = JS_TOKEN.match(source, pos)
    break unless m && m.begin(0) == pos

    kind = %i[comment string word space punct].find { |k| m[k] }
    tokens << [kind, m[0]]
    last = m[0] unless %i[comment space].include?(kind)
    pos = m.end(0)
  end
  tokens
end

def js_tokens(source) = js_scan(source).count { |kind, _| !%i[comment space].include?(kind) }

def js_code_only(source)
  text = js_scan(source).reject { |kind, _| kind == :comment }.map(&:last).join
  text.lines.map(&:rstrip).reject(&:empty?).join("\n") + "\n"
end

# index.html: only what is inside <script> without src
def inline_js(html) = html.scan(%r{<script>(.*?)</script>}m).map(&:first).join("\n")

# ---------- measuring ----------

Measure = Struct.new(:bytes, :lines, :tokens, :code_bytes, :code_tokens) do
  def +(other) = Measure.new(*to_a.zip(other.to_a).map(&:sum))
  def est = (bytes / BYTES_PER_TOKEN).round
  def code_est = (code_bytes / BYTES_PER_TOKEN).round
end

def measure(source, lang)
  source = lf(source)
  code = lang == :ruby ? ruby_code_only(source) : js_code_only(source)
  tokens = lang == :ruby ? ruby_tokens(source) : js_tokens(source)
  code_tokens = lang == :ruby ? ruby_tokens(code) : js_tokens(code)
  Measure.new(source.bytesize, source.lines.count, tokens, code.bytesize, code_tokens)
end

def sum(parts) = parts.map(&:last).reduce(Measure.new(0, 0, 0, 0, 0), :+)

def row(name, m)
  "| #{name} | #{m.bytes} | #{m.lines} | #{m.tokens} | #{m.est} | #{m.code_bytes} | #{m.code_tokens} | #{m.code_est} |"
end

HEADER = "| | bytes | lines | lexical tokens | est. tokens (bytes/3.5) | code bytes (no comments) | code lexical tokens | code est. tokens |\n|---|---|---|---|---|---|---|---|"

def percent(before, after) = format("%+.0f%%", (after - before) * 100.0 / before)

# ---------- desugaring ----------

# Rewrites jsg-style calls into PicoRuby's plain interop (see the top).
def desugar(source)
  edits = []
  visit = lambda do |node|
    return unless node

    if node.is_a?(Prism::CallNode)
      recv = node.receiver
      name = node.name.to_s
      if recv&.slice == "JSG" && %w[w d q window document querySelectorAll].include?(name)
        replacement = { "w" => "JS.global", "window" => "JS.global", "d" => "JS.document", "document" => "JS.document" }[name]
        if replacement
          edits << [node.location.start_offset, node.location.end_offset, replacement]
        else
          arg = node.arguments.arguments.first.slice
          edits << [node.location.start_offset, node.location.end_offset, "JS.document.querySelectorAll(#{arg})"]
        end
        return
      elsif node.attribute_write? && recv && !recv.is_a?(Prism::SelfNode) && name.end_with?("=") && name != "[]="
        # recv.prop = value  ->  recv[:prop] = value
        edits << [node.call_operator_loc.start_offset, node.arguments.location.start_offset, "[:#{name.chomp('=')}] = "]
      elsif recv && node.arguments.nil? && node.block.nil? && name.match?(/\A[A-Z]/) && node.call_operator_loc
        # JSG.w.Object -> JS.global[:Object]: a capitalized property, not a call
        edits << [node.call_operator_loc.start_offset, node.message_loc.end_offset, "[:#{name}]"]
      end
    end
    node.compact_child_nodes.each { |child| visit.call(child) }
  end
  visit.call(Prism.parse(source).value)
  # Prism's offsets count bytes: edit the bytes, from the back
  out = source.b
  edits.sort_by { |start, _stop, _text| -start }.each do |start, stop, text|
    out[start...stop] = text.b
  end
  out.force_encoding(Encoding::UTF_8)
end

# ---------- the tables ----------

rev = base_rev
old_main = git_show(rev, "html/main.rb")
old_index = git_show(rev, "html/index.html")
shell_files = File.readlines(File.join(ROOT, "html/shell/manifest.txt"), chomp: true)
                  .map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
read = ->(path) { File.read(File.join(ROOT, path)) }

old_parts = [
  ["main.rb (all of it: page + kernel)", measure(old_main, :ruby)],
  ["storage.js", measure(git_show(rev, "html/storage.js"), :js)],
  ["workspace_ui.js", measure(git_show(rev, "html/workspace_ui.js"), :js)],
  ["index.html inline JS", measure(inline_js(old_index), :js)]
]
shell_parts = shell_files.map { |f| ["shell/#{f}", measure(read.("html/shell/#{f}"), :ruby)] }
new_parts = [
  ["main.rb (kernel)", measure(read.("html/main.rb"), :ruby)],
  ["shell/*.rb (#{shell_files.size} files)", sum(shell_parts)],
  ["shell/bridge.js + loader.js", measure(read.("html/shell/bridge.js"), :js) + measure(read.("html/shell/loader.js"), :js)],
  ["storage.js", measure(read.("html/storage.js"), :js)],
  ["workspace_ui.js", measure(read.("html/workspace_ui.js"), :js)],
  ["index.html inline JS", measure(inline_js(read.("html/index.html")), :js)]
]

old_main_m = old_parts.first.last
new_main_m = new_parts.first.last
moved = Measure.new(*old_main_m.to_a.zip(new_main_m.to_a).map { |a, b| a - b })

puts "## Before (#{rev[0, 7]}) and after\n\n#{HEADER}"
old_parts.each { |name, m| puts row(name, m) }
puts row("**before, total**", sum(old_parts))
new_parts.each { |name, m| puts row(name, m) }
puts row("**after, total**", sum(new_parts))
puts
puts "## The page code: what left main.rb vs the shell that does it now\n\n#{HEADER}"
puts row("main.rb before - main.rb after (moved out)", moved)
puts row("shell/*.rb", sum(shell_parts))
puts row("shell/*.rb + bridge.js + loader.js", sum(new_parts[1, 2]))
puts
puts "## Shell files\n\n#{HEADER}"
shell_parts.each { |name, m| puts row(name, m) }

# Like for like: the methods that did the page's work in the old main.rb
# (CRuby, js gem: el[:x], .to_s, js_null?) and the ones that do it now,
# under the same names, plus the View helpers they call.
def defs(source, names)
  found = []
  walk = lambda do |node|
    return unless node

    found << node.slice if node.is_a?(Prism::DefNode) && names.include?(node.name.to_s)
    node.compact_child_nodes.each { |child| walk.call(child) }
  end
  walk.call(Prism.parse(source).value)
  found.join("\n\n") + "\n"
end

SAME_JOB = %w[render_all render_nav render_lesson render_workshop render_gems_panel show_bubble select_lesson
              go_to_next_lesson switch_lang reset_lesson route_from_hash hash_lesson_id set_lesson_hash current_index
              open_workshop start_cell_run settle_cell replay show_run_time cell_parts].freeze
VIEW_HELPERS = %w[nav_html lesson_html cell_html workshop_html gems_html running_label run_time set_code current_lesson_id current_cells].freeze
app_src = lf(read.("html/shell/app.rb")) + lf(read.("html/shell/view.rb"))
old_same = measure(defs(lf(old_main), SAME_JOB), :ruby)
new_same = measure(defs(app_src, SAME_JOB + VIEW_HELPERS), :ruby)
plain_same = measure(defs(desugar(lf(read.("html/shell/app.rb"))) + desugar(lf(read.("html/shell/view.rb"))), SAME_JOB + VIEW_HELPERS), :ruby)
puts
puts "## Like for like: #{SAME_JOB.size} methods with the same job, old and new\n\n#{HEADER}"
puts row("main.rb before (CRuby, js gem)", old_same)
puts row("shell, PicoRuby plain interop (desugared)", plain_same)
puts row("shell, with the jsg-style sugar (as shipped)", new_same)
puts
puts "Old to shipped: #{percent(old_same.code_bytes, new_same.code_bytes)} code bytes, " \
     "#{percent(old_same.code_tokens, new_same.code_tokens)} lexical tokens"

# the shell with and without the sugar (jsg.rb itself left out of both)
sugared = shell_parts.reject { |name, _| name.end_with?("jsg.rb") }
plain = shell_files.reject { |f| f == "jsg.rb" }.map { |f| [f, measure(desugar(lf(read.("html/shell/#{f}"))), :ruby)] }
s = sum(sugared)
p_ = sum(plain)
puts
puts "## jsg-style sugar: the shell (without jsg.rb) as written vs desugared\n\n#{HEADER}"
puts row("desugared (PicoRuby's plain interop)", p_)
puts row("with the sugar (as shipped)", s)
puts row("jsg.rb (the sugar itself)", shell_parts.find { |name, _| name.end_with?("jsg.rb") }.last)
puts
puts "Sugar saves #{p_.code_bytes - s.code_bytes} code bytes (#{percent(p_.code_bytes, s.code_bytes)}), " \
     "#{p_.code_tokens - s.code_tokens} lexical tokens (#{percent(p_.code_tokens, s.code_tokens)}), " \
     "~#{p_.code_est - s.code_est} est. tokens"

if (i = ARGV.index("--desugar"))
  dir = File.expand_path(ARGV[i + 1] || "tmp/desugared_shell", ROOT)
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  kept = shell_files.reject { |f| f == "jsg.rb" }
  kept.each { |f| File.binwrite(File.join(dir, f), desugar(lf(read.("html/shell/#{f}")))) }
  File.binwrite(File.join(dir, "manifest.txt"), "# desugared by tools/shell_metrics.rb\n" + kept.join("\n") + "\n")
  puts "\nwrote the desugared shell to #{dir}"

  # the same program? the shell's tests (all but jsg_test.rb) on the copy
  require "rbconfig"
  %w[app_test course_store_view_test portability_test].each do |test|
    ok = system({ "SHELL_DIR" => dir }, RbConfig.ruby, File.join(ROOT, "test/shell/#{test}.rb"), out: File::NULL)
    puts "test/shell/#{test}.rb on the desugared shell: #{ok ? 'pass' : 'FAIL'}"
  end
end
