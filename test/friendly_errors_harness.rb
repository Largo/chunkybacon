# Offline harness for the friendly error explanations (html/friendly_errors.rb):
# runs every beginner mistake of friendly_errors_corpus.rb like a notebook
# cell - in a fresh binding, as chunky.rb, a live one under the live-run time
# limit - and checks that the rule it expects explains it (or none, where
# Ruby's own message is meant to stay). Prints each explanation in German,
# English and Japanese, then a table; exits 1 on a MISS.
#
#   ruby friendly_errors_harness.rb               # all, 3 languages
#   ruby friendly_errors_harness.rb --lang ja     # one language
#   ruby friendly_errors_harness.rb --only else   # ids containing "else"
#   ruby friendly_errors_harness.rb --summary     # just the table
#
# Also with `ruby --disable-did_you_mean`: the rules have their own
# spelling suggestions, as ruby.wasm may come without did_you_mean.
require "stringio"
require_relative "../html/friendly_errors"
require_relative "friendly_errors_corpus"
# the real time limit of live runs (AutoRun::Stopped)
require_relative "../html/autorun"

FILE = "chunky.rb" # html/main.rb EVAL_FILE

opts = { langs: FriendlyErrors::LANGS, only: nil, summary: false }
args = ARGV.dup
until args.empty?
  case (a = args.shift)
  when "--lang" then opts[:langs] = [args.shift]
  when "--only" then opts[:only] = args.shift
  when "--summary" then opts[:summary] = true
  else abort "unknown option #{a}"
  end
end

def fresh_binding
  eval("proc { binding }.call", TOPLEVEL_BINDING)
end

# runs +code+ as a cell; returns [error, binding, cleanup]
def run_cell(item)
  bind = fresh_binding
  consts = Object.constants
  meths = Object.private_instance_methods(false)
  out = StringIO.new
  old = $stdout
  $stdout = out
  error = nil
  begin
    eval(item[:setup], bind, "setup.rb") if item[:setup]
    if item[:live]
      AutoRun.with_time_limit([FILE], 0.2) { eval(item[:code], bind, FILE) }
    else
      eval(item[:code], bind, FILE)
    end
  rescue Exception => e # rubocop:disable Lint/RescueException - like main.rb
    error = e
  ensure
    $stdout = old
  end
  [error, bind, lambda {
    (Object.constants - consts).each { |c| Object.send(:remove_const, c) }
    (Object.private_instance_methods(false) - meths).each { |m| Object.send(:remove_method, m) }
  }]
end

# A SyntaxError's message as ruby.wasm has it: there Prism colours its code
# frame, as for a terminal (seen in the browser), here it does not
def wasm_colours(message)
  message.lines.map do |l|
    l.sub(/\A> (\d+ \| )/) { "\e[1;31m> \e[m\e[2m#{$1}\e[m" }
     .sub(/\A  (\d+ \| )/) { "  \e[2m#{$1}\e[m" }
     .sub(/\A    \| ( *)(\^~*)/) { "  \e[2m  | \e[m#{$1}\e[1;31m#{$2}\e[m" }
  end.join
end

rows = []
FriendlyErrors::CORPUS.each do |item|
  next if opts[:only] && !item[:id].include?(opts[:only])

  error, bind, cleanup = run_cell(item)
  results = opts[:langs].to_h do |lang|
    [lang, error && FriendlyErrors.explain(error, source: item[:code], lang: lang, file: FILE, binding: bind)]
  end
  cleanup.call
  first = results.values.first
  ok = first ? first.rule == item[:expect] : item[:expect].nil?
  rows << [item[:id], error ? error.class.name : "-", first&.rule || "-", item[:expect] || "-", ok]
  if error.is_a?(SyntaxError)
    coloured = FriendlyErrors.explain(error.exception(wasm_colours(error.message)), source: item[:code],
                                                                                    lang: opts[:langs].first, file: FILE)
    same = coloured&.rule == first&.rule && !coloured&.to_html.to_s.include?("\e")
    rows << ["#{item[:id]} (wasm)", error.class.name, coloured&.rule || "-", item[:expect] || "-", same]
  end
  next if opts[:summary]

  puts "=" * 76
  puts "#{item[:id]}  (lesson #{item[:lesson]}#{item[:lang] ? ", #{item[:lang]} code" : ''})"
  puts item[:code].lines.each_with_index.map { |l, i| "  #{(i + 1).to_s.rjust(2)}  #{l.chomp}" }.join("\n")
  puts "  Ruby: #{error ? "#{error.class}: #{error.message.lines.first.to_s.strip}" : '(no error)'}"
  results.each do |lang, r|
    puts "\n[#{lang}]"
    puts r ? r.to_text : "(no friendly explanation - Ruby's message stays)"
  end
end

puts "\n#{'=' * 76}\nSUMMARY"
w = rows.map { |r| r[0].length }.max
rows.each do |id, klass, rule, expect, ok|
  puts "#{ok ? 'ok  ' : 'MISS'} #{id.ljust(w)}  #{klass.ljust(24)} #{rule.to_s.ljust(18)} (expected #{expect})"
end
cases, wasm = rows.partition { |r| !r[0].end_with?(" (wasm)") }
explained = cases.count { |r| r[2] != "-" }
puts "\n#{cases.length} cases, #{explained} explained, #{cases.count { |r| r[4] }} as expected; " \
     "#{wasm.count { |r| r[4] }} of #{wasm.length} syntax errors the same with ruby.wasm's colours"
exit 1 unless rows.all? { |r| r[4] } # a MISS fails the run
