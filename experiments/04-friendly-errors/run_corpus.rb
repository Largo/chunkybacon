# Runs every corpus entry like a notebook cell and prints FriendlyErrors'
# explanation in German, English and Japanese, then a coverage summary.
#
#   ruby experiments/04-friendly-errors/run_corpus.rb              # all, 3 languages
#   ruby experiments/04-friendly-errors/run_corpus.rb --lang ja    # one language
#   ruby experiments/04-friendly-errors/run_corpus.rb --only else  # ids containing "else"
#   ruby experiments/04-friendly-errors/run_corpus.rb --summary    # just the table
#   ruby experiments/04-friendly-errors/run_corpus.rb --html       # also writes preview.html
require "stringio"
require_relative "friendly_errors"
require_relative "corpus"

ROOT = File.expand_path("../..", __dir__)
# the real time limit of live runs (AutoRun::Stopped), read-only
load File.join(ROOT, "html", "autorun.rb")

FILE = "chunky.rb" # html/main.rb EVAL_FILE

opts = { langs: FriendlyErrors::LANGS, only: nil, summary: false, html: false }
args = ARGV.dup
until args.empty?
  case (a = args.shift)
  when "--lang" then opts[:langs] = [args.shift]
  when "--only" then opts[:only] = args.shift
  when "--summary" then opts[:summary] = true
  when "--html" then opts[:html] = true
  else abort "unknown option #{a}"
  end
end

def fresh_binding
  eval("proc { binding }.call", TOPLEVEL_BINDING)
end

# runs +code+ as a cell; returns [error, binding]
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
  [error, bind, -> {
    (Object.constants - consts).each { |c| Object.send(:remove_const, c) }
    (Object.private_instance_methods(false) - meths).each { |m| Object.send(:remove_method, m) }
  }]
end

rows = []
html = []
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

  unless opts[:summary]
    puts "=" * 76
    puts "#{item[:id]}  (lesson #{item[:lesson]}#{item[:lang] ? ", #{item[:lang]} code" : ''})"
    puts item[:code].lines.each_with_index.map { |l, i| "  #{(i + 1).to_s.rjust(2)}  #{l.chomp}" }.join("\n")
    puts "  Ruby: #{error ? "#{error.class}: #{error.message.lines.first.to_s.strip}" : '(no error)'}"
    results.each do |lang, r|
      puts "\n[#{lang}]"
      puts r ? r.to_text : "(no friendly explanation - Ruby's message stays)"
    end
  end
  next unless opts[:html]

  html << "<section><h2>#{FriendlyErrors.escape(item[:id])}</h2><pre class=\"code\">#{FriendlyErrors.escape(item[:code])}</pre>"
  results.each do |lang, r|
    html << "<div lang=\"#{lang}\">#{r ? r.to_html : "<p class=\"none\">#{FriendlyErrors.escape(error ? "#{error.class}: #{error.message}" : '(no error)')}</p>"}</div>"
  end
  html << "</section>"
end

puts "\n#{'=' * 76}\nSUMMARY"
w = rows.map { |r| r[0].length }.max
rows.each do |id, klass, rule, expect, ok|
  puts "#{ok ? 'ok  ' : 'MISS'} #{id.ljust(w)}  #{klass.ljust(24)} #{rule.to_s.ljust(18)} (expected #{expect})"
end
explained = rows.count { |r| r[2] != "-" }
puts "\n#{rows.length} cases, #{explained} explained, #{rows.count { |r| r[4] }} as expected"

if opts[:html]
  css = File.read(File.join(__dir__, "friendly_errors.css"))
  page = <<~HTML
    <!doctype html><html><head><meta charset="utf-8"><title>FriendlyErrors corpus</title>
    <style>body{font-family:system-ui,sans-serif;max-width:1500px;margin:2em auto;padding:0 1em}
    section{border-top:2px solid #ddd;padding:1em 0;display:grid;grid-template-columns:repeat(4,1fr);gap:1em}
    section h2{grid-column:1/-1;margin:0;font-size:1rem}.code{background:#f6f3ee;padding:.5em;margin:0;font-size:.8rem}
    .none{color:#888;font-family:monospace;font-size:.8rem}#{css}</style></head><body>
    <h1>FriendlyErrors – corpus preview</h1>#{html.join("\n")}</body></html>
  HTML
  File.write(File.join(__dir__, "preview.html"), page)
  puts "wrote #{File.join(__dir__, 'preview.html')}"
end
exit 1 unless rows.all? { |r| r[4] } # a MISS fails the run
