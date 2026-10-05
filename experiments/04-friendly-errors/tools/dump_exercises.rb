# Prints the exercise cells (code, check, hint) of html/lessons.js, to mine
# realistic beginner mistakes for the corpus. Read-only.
#   ruby experiments/04-friendly-errors/tools/dump_exercises.rb [lang] [id-filter]
require "json"

ROOT = File.expand_path("../../..", __dir__)

def load_lessons
  src = File.read(File.join(ROOT, "html", "lessons.js"), encoding: "UTF-8")
  start = src.index("JSON.stringify(") + "JSON.stringify(".length
  stop = src.rindex(");")
  JSON.parse(src[start...stop])
end

if $PROGRAM_NAME == __FILE__
  lang = ARGV[0] || "en"
  filter = ARGV[1]
  data = load_lessons
  data["lessons"].each do |lesson|
    next if filter && !lesson["id"].include?(filter)
    body = lesson[lang] or next
    puts "=" * 70
    puts "#{lesson["id"]}: #{body["title"]}"
    body["cells"].each do |cell|
      case cell["t"]
      when "c" then puts "--- demo\n#{cell["code"]}"
      when "x" then puts "--- EXERCISE\n#{cell["code"]}\n--- check: #{cell["check"]}\n--- hint: #{cell["hint"]}"
      end
    end
  end
  puts "\nUI keys (#{lang}): #{data["ui"][lang].keys.join(", ")}" unless filter
end
