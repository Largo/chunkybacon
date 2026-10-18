# Puts Ruboto's own Ruby into html/ruboto_sim/vendor/ruboto/: base.rb,
# package.rb, activity.rb, widget.rb and toast.rb of Ruboto 2
# (github.com/Largo/ruboto, the gradle-based fork), unchanged, at the commit
# COMMIT names. The Ruboto lesson's simulated phone (docs/HANDOVER.md §6u)
# runs them on JRuby against Java stand-ins for Android's classes - so
# `button text: "Hi", on_click_listener: proc { ... }` goes through Ruboto's
# own set_attribute, as on a phone.
#
#   ruby tools/vendor_ruboto.rb             # fetch the files again (same bytes)
#   ruby tools/vendor_ruboto.rb --from DIR  # from a checkout of Largo/ruboto at COMMIT
#   ruby tools/vendor_ruboto.rb --check     # offline: are the files the ones VENDOR.txt records?
#
# A new commit: change COMMIT, run this, read the diff, then
# node test/ruboto_node.mjs and the lesson's browser test (test/ruboto_test.mjs).
require "net/http"
require "uri"
require "digest"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
TARGET = File.join(ROOT, "html/ruboto_sim/vendor")
RECORD = File.join(TARGET, "VENDOR.txt")
REPO = "Largo/ruboto"
COMMIT = "5cfbee3a3b36515cbfbab40205f8fc5f292307f8"
DIR = "assets/app/src/main/resources/ruboto"
SOURCE = "https://raw.githubusercontent.com/#{REPO}/%<commit>s/#{DIR}/%<file>s"
FILES = %w[base.rb package.rb activity.rb widget.rb toast.rb].freeze

def get(url, limit = 5)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) do |http|
    http.request(Net::HTTP::Get.new(uri, "User-Agent" => "chunkybacon-vendor"))
  end
  return get(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
  raise "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def check
  record = File.exist?(RECORD) ? File.read(RECORD) : abort("#{RECORD} is missing: run tools/vendor_ruboto.rb")
  problems = []
  problems << "vendored from #{record[/^commit=(.+)$/, 1]}, but COMMIT is #{COMMIT}" unless record.include?("commit=#{COMMIT}\n")
  FILES.each do |file|
    line = record[/^file=ruboto\/#{Regexp.escape(file)} (\d+) (\h+)$/]
    path = File.join(TARGET, "ruboto", file)
    if line.nil?
      problems << "#{file}: not in VENDOR.txt"
    elsif !File.exist?(path)
      problems << "#{file}: missing"
    elsif Digest::SHA256.file(path).hexdigest != Regexp.last_match(2)
      problems << "#{file}: changed since it was vendored"
    end
  end
  if problems.empty?
    puts "html/ruboto_sim/vendor: Ruboto #{COMMIT[0, 7]}, #{FILES.size} files as recorded"
  else
    puts problems
    exit 1
  end
end

def vendor(from)
  FileUtils.mkdir_p(File.join(TARGET, "ruboto"))
  lines = ["source=#{format(SOURCE, commit: COMMIT, file: '<file>')}", "commit=#{COMMIT}",
           "license=MIT, (c) 2011 Daniel Jackoway, Charles Nutter, Scott Moyer, Uwe Kubosch (see THIRD_PARTY_NOTICES.md)",
           "installed_by=tools/vendor_ruboto.rb (unchanged copies; html/ruboto_sim/ruboto_sim.rb plays Ruboto's Java side)"]
  FILES.each do |file|
    body = from ? File.binread(File.join(from, DIR, file)) : get(format(SOURCE, commit: COMMIT, file: file))
    File.binwrite(File.join(TARGET, "ruboto", file), body)
    lines << "file=ruboto/#{file} #{body.bytesize} #{Digest::SHA256.hexdigest(body)}"
    puts "ruboto/#{file} (#{body.bytesize} bytes)"
  end
  File.write(RECORD, lines.join("\n") + "\n")
end

if ARGV.first == "--check"
  check
else
  vendor(ARGV[0] == "--from" ? ARGV[1] : nil)
end
