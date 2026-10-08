# Prism's error types for typical beginner syntax errors.
#   ruby experiments/04-friendly-errors/tools/probe_syntax.rb
require "prism"

SNIPPETS = [
  "if n > 5\n  'big'\nelse if n < 0\n  'neg'\nend",
  "def foo():\n  1\nend",
  "x = 1\nx++",
  "for i in range(5):\n  puts i",
  "fox = { name: 'Chunky', food: 'bacon'",
  "fox = { name 'Chunky' }",
  "\"I love \#{favorite_food!\"",
  "class Fox\n  def shout\n    'x'\nend",
  "breakfast = ['egg', 'toast'\nbreakfast << 'bacon'",
  "def square(n)\n  n * n\nend\nend",
  "5.times do\n  puts 'x'\n",
  "5.times {\n  puts 'x'\n",
  "x = 5\nif x = > 3\n  1\nend",
  "puts 'Hello, World!",
  "name = \"Kaz\nage = 7",
  "h = {:a => 1, :b => }",
  "def add(a, b)\n  a + b\nend\nadd(1,, 2)",
  "case x\nwhen 1\n  'a'\n",
  "while i < 3\n  i += 1\n",
  "module Loud\n  def shout\n    'X'\n  end\n",
  "fox.each do |a, b\n  a\nend",
  "x = [1, 2, 3].map { |n| n * 2 ",
  "puts(\"a\"",
  "if x > 3 {\n  1\n}",
]
SNIPPETS.each do |code|
  puts "=" * 50
  puts code
  Prism.parse(code).errors.each do |err|
    puts "  #{err.type} #{err.location.start_line}:#{err.location.start_column} #{err.message}"
  end
end
