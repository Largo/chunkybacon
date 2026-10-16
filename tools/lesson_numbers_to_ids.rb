# Converts a lessons.js that still has its numbers in the text to the form
# that numbers lessons by their place (html/lesson_refs.rb): "9. Methoden"
# becomes "Methoden", and "lesson 9" / "Lektion 9" / "レッスン9" become
# "lesson {{nr:methoden}}" - by the numbering of the file as it is, so run it
# before moving lessons around. Ranges and pairs ("lessons 30-32",
# "Lektionen 13 und 14", "レッスン13と14") convert every number. A branch
# from before the change runs it once, on its own lessons.js:
#
#   ruby tools/lesson_numbers_to_ids.rb [path/to/lessons.js]
#
# It prints what it changed; a second run changes nothing.
require "json"

path = ARGV[0] || File.expand_path("../html/lessons.js", __dir__)
source = File.binread(path).force_encoding("UTF-8")
eol = source.include?("\r\n") ? "\r\n" : "\n"
source = source.gsub("\r\n", "\n")
start = "window.LESSONS_JSON = JSON.stringify("
at = source.index(start) or abort "#{path}: no #{start}"
head = source[0, at + start.length]
data = JSON.parse(source[head.length..][/\A(.*)\);\s*\z/m, 1])

ids = data["lessons"].map { |lesson| lesson["id"] }
WORD = {
  "de" => /(Lektion(?:en)?\s*)(\d+)/,
  "en" => /(\b[Ll]essons?\s+)(\d+)/,
  "ja" => /(レッスン\s*)(\d+)/
}.freeze
# what joins a second number to the first: "30-32", "13 und 14", "13と14"
MORE = /\A(\s*(?:[–-]|bis|to|und|and|or|oder|と|、|,|〜|~|～)\s*)(\d+)/
changes = Hash.new(0)

token = lambda do |number, where|
  id = ids[number.to_i - 1]
  abort "#{where}: lesson #{number} - there are only #{ids.size}" unless id
  "{{nr:#{id}}}"
end

convert_text = lambda do |text, lang, where|
  out = +""
  rest = text
  while (m = WORD.fetch(lang).match(rest))
    out << m.pre_match << m[1] << token.call(m[2], where)
    changes[where] += 1
    rest = m.post_match
    while (more = MORE.match(rest))
      out << more[1] << token.call(more[2], where)
      changes[where] += 1
      rest = more.post_match
    end
  end
  out << rest
end

walk = lambda do |value, lang, where|
  case value
  when String then convert_text.call(value, lang, where)
  when Array then value.map { |v| walk.call(v, lang, where) }
  when Hash then value.transform_values { |v| walk.call(v, lang, where) }
  else value
  end
end

data["lessons"].each do |lesson|
  %w[de en ja].each do |lang|
    next unless lesson[lang]
    title = lesson[lang]["title"]
    if title&.match?(/\A\d+\.\s+/)
      lesson[lang]["title"] = title.sub(/\A\d+\.\s+/, "")
      changes["#{lesson["id"]} titles"] += 1
    end
    lesson[lang]["cells"] = walk.call(lesson[lang]["cells"], lang, "#{lesson["id"]}[#{lang}]")
  end
  # a lesson's sidebar heading ("section") is prose too
  lesson["section"] = lesson["section"].to_h { |lang, text| [lang, convert_text.call(text, lang, "#{lesson["id"]} section")] } if lesson["section"]
end

File.binwrite(path, (head + JSON.pretty_generate(data) + ");\n").gsub("\n", eol))
puts changes.empty? ? "nothing to change" : changes.map { |where, n| "#{where}: #{n}" }
