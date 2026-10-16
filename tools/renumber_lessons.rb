# Numbers the lessons in html/lessons.js by their place in the course again:
# every title gets its position ("17. Gems installieren"), and every
# reference in the texts ("Lektion 13", "lessons 13 and 14", "レッスン13")
# moves along with the lesson it pointed to. Run it after inserting,
# moving or removing lessons - or after merging two branches that both
# did - instead of renumbering by hand (docs/HANDOVER.md §3).
#
# A lesson's old number is the one its title carries. A new lesson goes in
# with "0. " (or no number) in front of its titles: it gets its number, and
# its own texts are taken to use the new numbering already - they are listed
# for a look. Two lessons with the same old number cannot be told apart and
# stop the tool (give the new one "0. ").
#
#   ruby tools/renumber_lessons.rb           # rewrites html/lessons.js
#   ruby tools/renumber_lessons.rb --check   # numbered by position? (exit 1 if not)
#   ruby tools/renumber_lessons.rb path/to/lessons.js   # another copy
require "json"

FILE = ARGV.find { |arg| arg.end_with?(".js") } || File.expand_path("../html/lessons.js", __dir__)
START = "window.LESSONS_JSON = JSON.stringify("
# "Lektion 9", "Lektionen 13 und 14", "lessons 13 and 14", "Lesson 9", "レッスン13と14"
REF = /(Lektion(?:en)? |[Ll]essons? |レッスン)(\d+(?:(?:, | und | and |と|、)\d+)*)/
TITLE = /\A(\d+)\. /

raw = File.binread(FILE).force_encoding("UTF-8")
eol = raw.include?("\r\n") ? "\r\n" : "\n"
source = raw.gsub("\r\n", "\n")
head = source[0, source.index(START) + START.length]
data = JSON.parse(source[/JSON\.stringify\((.*)\);\s*\z/m, 1])
langs = data["ui"].keys
lessons = data["lessons"]

# the number each lesson's titles carry - the same in every language
old = lessons.map do |lesson|
  numbers = langs.map { |lang| lesson.dig(lang, "title").to_s[TITLE, 1]&.to_i }.uniq
  abort "#{lesson["id"]}: the titles disagree about the number (#{numbers.inspect})" if numbers.size > 1
  numbers.first.to_i
end

if ARGV.include?("--check")
  wrong = lessons.each_index.reject { |i| old[i] == i + 1 }
  wrong.each { |i| puts "#{lessons[i]["id"]}: titled #{old[i]}, is lesson #{i + 1}" }
  puts wrong.empty? ? "numbered by position (#{lessons.size} lessons)" : "#{wrong.size} lesson(s) out of place"
  exit(wrong.empty? ? 0 : 1)
end

fresh = lessons.each_index.select { |i| old[i].zero? }
taken = old.reject(&:zero?)
twice = taken.select { |n| taken.count(n) > 1 }.uniq
abort "lessons share the number(s) #{twice.join(", ")} - give the new one \"0. \"" if twice.any?

moves = lessons.each_index.reject { |i| old[i].zero? }.to_h { |i| [old[i], i + 1] }
missing = []
renumber = lambda do |text, lesson|
  text.gsub(REF) do
    word = Regexp.last_match(1)
    list = Regexp.last_match(2).gsub(/\d+/) do |n|
      moves.fetch(n.to_i) { missing << "#{lesson}: #{word}#{n}"; n.to_i }.to_s
    end
    "#{word}#{list}"
  end
end

lessons.each_with_index do |lesson, i|
  langs.each do |lang|
    part = lesson[lang]
    part["title"] = "#{i + 1}. #{part["title"].sub(TITLE, "")}"
    next if fresh.include?(i)   # a new lesson's texts use the new numbers

    part["cells"].each do |cell|
      cell.each_key { |key| cell[key] = renumber.call(cell[key], lesson["id"]) if %w[html hint].include?(key) }
    end
  end
end

File.binwrite(FILE, "#{head}#{JSON.pretty_generate(data)});\n".gsub("\n", eol))
changed = lessons.each_index.count { |i| old[i] != i + 1 }
puts "renumbered: #{changed} of #{lessons.size} lessons have a new number"
fresh.each do |i|
  refs = langs.flat_map { |lang| lessons[i][lang]["cells"].flat_map { |c| [c["html"], c["hint"]].compact.flat_map { |t| t.scan(REF).map(&:join) } } }
  puts "new: #{lessons[i]["id"]} is lesson #{i + 1}#{refs.empty? ? "" : " - check its references: #{refs.uniq.join(", ")}"}"
end
missing.uniq.each { |m| puts "warning: no lesson has the old number in #{m}" }
