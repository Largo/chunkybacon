# Demo: insert a lesson at position 5 and renumber titles only (what a
# careless merge does), then show what the refs group reports.
require_relative "../../test/lint_lessons"
root = File.expand_path("../..", __dir__)
d = LessonLint::Source.new(root).data
extra = Marshal.load(Marshal.dump(d["lessons"][4]))
extra["id"] = "neu"
d["lessons"].insert(4, extra)
d["lessons"].each_with_index do |l, i|
  LessonLint::LANGS.each { |g| l[g]["title"] = l[g]["title"].sub(/\A\d+\./, "#{i + 1}.") }
end
f = LessonLint::Linter.new(root, allow_path: nil, text: LessonLint::Source.dump(d)).run(%w[refs])
f.reject { |x| x.severity == "INFO" }.each { |x| puts "#{x.severity} #{x.where}: #{x.message}" }
total = f.find { |x| x.code.start_with?("ref-table") }
puts f.select { |x| x.code.start_with?("ref-table") }.map(&:message)
