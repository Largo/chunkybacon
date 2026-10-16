# Lessons are numbered by their place in lessons.js, not in their text. A
# title has no number ("Methoden"), and a reference to another lesson names
# its id where the number goes: "lesson {{nr:methoden}}", "aus Lektion
# {{nr:methoden}}", "レッスン{{nr:methoden}}". The number is filled in when
# the course is loaded, so a lesson put in between renumbers nothing in the
# text. The page does the same in shell/bridge.js (resolveLessonNumbers);
# this one serves the server (server/course.rb), the linter
# (test/lint_lessons.rb) and the shell tests' page (test/shell/stubs/js.rb).
module LessonRefs
  TOKEN = /\{\{nr:([\w-]+)\}\}/

  module_function

  # id => its number (1-based)
  def numbers(lessons) = lessons.each_with_index.to_h { |lesson, idx| [lesson["id"], idx + 1] }

  # The course (lessons.js's {ui, lessons}) with every token replaced by its
  # lesson's number. A token naming no lesson stays as written - the linter
  # reports it, and on the page it shows instead of a wrong number.
  def resolve(data)
    numbers = numbers(data["lessons"])
    walk = lambda do |value|
      case value
      when String then value.gsub(TOKEN) { numbers[$1]&.to_s || $& }
      when Array then value.map(&walk)
      when Hash then value.transform_values(&walk)
      else value
      end
    end
    data.merge("lessons" => walk.call(data["lessons"]))
  end

  # "9. Methoden", as the sidebar, the tab and link previews show a title
  def numbered(number, title) = "#{number}. #{title}"
end
