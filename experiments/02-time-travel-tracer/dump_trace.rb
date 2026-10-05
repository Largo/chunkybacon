# Prints one sample's steps compactly: ruby dump_trace.rb <id>...
require "json"
samples = JSON.parse(File.read(File.join(__dir__, "samples.json")))
samples.select { |s| ARGV.empty? || ARGV.include?(s["id"]) }.each do |s|
  t = s["trace"]
  puts "### #{s['id']}  result=#{t['result'].inspect} error=#{t['error'].inspect} truncated=#{t['truncated']} frames=#{t['frames'].length}"
  t["steps"].each_with_index do |st, i|
    frames = (st["f"] || []).map do |fi|
      f = t["frames"][fi]
      vars = (f["vars"] || []).map { |n, v, e| "#{n}=#{v}#{e == 1 ? '*' : ''}" }.join(" ")
      "#{f['kind']}:#{f['name']}#{f['iter'] ? "##{f['iter']}" : ''}{#{vars}}"
    end
    puts format("%3d %-7s L%-3s hit%-2s out%-3s %s %s", i, st["event"], st["line"], st["hit"], st["out"], frames.join(" | "), st["value"] ? "-> #{st['value']}" : "")
  end
end
