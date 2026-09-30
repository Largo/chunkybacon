# The page shell's tests, under CRuby (no browser):
#   node test/make_lessons_json.js   # once, for the course data
#   ruby test/shell/run.rb
Dir[File.join(__dir__, "*_test.rb")].sort.each { |file| require file }
