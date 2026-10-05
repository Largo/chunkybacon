# Prints the code cells of a few basics lessons (German), to pick samples.
require "json"
data = JSON.parse(File.read(File.join(__dir__, "lessons.json")))
ids = ARGV.empty? ? %w[schleifen arrays methoden] : ARGV
data["lessons"].select { |l| ids.include?(l["id"]) }.each do |lesson|
  lesson["de"]["cells"].each_with_index do |cell, i|
    next unless %w[c x].include?(cell["t"])
    puts "=== #{lesson['id']} ##{i} (#{cell['t']})"
    puts cell["code"]
    puts "--- solution:\n#{cell['solution']}" if cell["solution"]
  end
end
