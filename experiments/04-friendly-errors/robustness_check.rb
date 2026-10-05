# FriendlyErrors must never break a cell's output. Feeds it every corpus
# error with wrong or missing sources, odd languages, a different file name
# and no binding, and checks that explain only ever returns nil or a Result
# whose texts have no unfilled %{...}.
#   ruby experiments/04-friendly-errors/robustness_check.rb
#   ruby --disable-did_you_mean experiments/04-friendly-errors/robustness_check.rb
require "stringio"
require_relative "friendly_errors"
require_relative "corpus"
load File.expand_path("../../html/autorun.rb", __dir__)

errors = FriendlyErrors::CORPUS.filter_map do |item|
  bind = eval("proc { binding }.call", TOPLEVEL_BINDING)
  old = $stdout
  $stdout = StringIO.new
  begin
    eval(item[:setup], bind, "setup.rb") if item[:setup]
    if item[:live]
      AutoRun.with_time_limit(["chunky.rb"], 0.2) { eval(item[:code], bind, "chunky.rb") }
    else
      eval(item[:code], bind, "chunky.rb")
    end
    nil
  rescue Exception => e # rubocop:disable Lint/RescueException
    [item, e]
  ensure
    $stdout = old
  end
end

variants = [
  ->(item) { { source: item[:code], lang: "ja" } },
  ->(_) { { source: "", lang: "de" } },
  ->(_) { { source: "x = 1\n" * 3, lang: "fr" } },
  ->(item) { { source: item[:code], lang: nil, file: "other.rb" } },
  ->(item) { { source: item[:code].lines.first.to_s, lang: "en" } }
]

problems = 0
checked = 0
errors.each do |item, e|
  variants.each do |v|
    checked += 1
    r = FriendlyErrors.explain(e, **v.call(item))
    next if r.nil?

    texts = [r.title, r.body, r.to_text, r.to_html]
    next unless texts.any? { |t| t.include?("%{") } || r.title.to_s.strip.empty?

    problems += 1
    puts "PROBLEM #{item[:id]} #{v.call(item).except(:source)}: #{r.title}"
  end
end
puts "#{checked} explain calls on #{errors.length} errors, #{problems} problems, no exception escaped"
puts "did_you_mean loaded: #{defined?(DidYouMean) ? 'yes' : 'no'}"
