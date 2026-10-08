# Writes html/offline-files.txt: what the offline copy holds (html/sw.js,
# docs/HANDOVER.md §6c) - every file the page may load, i.e. everything
# under html/ but the .gz copies (nginx serves them in place of the file),
# notices and the worker's own files. Only adding, renaming or deleting a
# file changes the list; an edited file is noticed by its ETag.
#
#   ruby tools/offline_files.rb           # rewrite the list
#   ruby tools/offline_files.rb --check   # exit 1 if it is out of date
HTML = File.expand_path("../html", __dir__)
LIST = File.join(HTML, "offline-files.txt")
SKIP = /\.(gz|md)$|^(sw\.js|offline-files\.txt)$|^compile\/toolchain\//

HEADER = <<~TEXT
  # The files the offline copy holds (html/sw.js): written by
  # tools/offline_files.rb - rerun it after adding, renaming or deleting a
  # file under html/. Paths are relative to this file.
TEXT

files = Dir.chdir(HTML) { `git ls-files -co --exclude-standard`.split("\n") }
           .reject { |path| path.match?(SKIP) || !File.file?(File.join(HTML, path)) }
           .sort
text = HEADER + files.join("\n") + "\n"

if ARGV.include?("--check")
  current = File.exist?(LIST) && File.read(LIST) == text
  puts current ? "current html/offline-files.txt (#{files.size} files)" : "STALE   html/offline-files.txt: run ruby tools/offline_files.rb"
  exit(current ? 0 : 1)
end
File.write(LIST, text)
puts "wrote   html/offline-files.txt (#{files.size} files)"
