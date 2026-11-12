# Writes nginx/embed-frame-ancestors.inc, the host's list of the sites that
# may put embed.html in an iframe (docs/HANDOVER.md §6k, §7). Not in git:
# like the runtimes under html/assets/, it belongs to the deploy, and
# tools/after_deploy.sh runs this (and reloads nginx when the file changed).
#
#   EMBED_FRAME_ANCESTORS="https://idogawa.com https://blog.example.org" \
#     ruby tools/embed_frame_ancestors.rb
#
# The list comes from $EMBED_FRAME_ANCESTORS, else from the line
# EMBED_FRAME_ANCESTORS=... in the checkout's .env (docker compose's file,
# not in git), else it is https://idogawa.com - never "*". Its format and
# what is allowed: tools/frame_ancestors.rb. A wrong entry changes nothing
# (the old file stays, so does nginx's policy) and exits 1.
#
# Prints "current" or "wrote"; exit 0 either way.
require_relative "frame_ancestors"

ROOT = File.expand_path("..", __dir__)
OUT = File.join(ROOT, "nginx", "embed-frame-ancestors.inc")

def setting
  from_env = ENV["EMBED_FRAME_ANCESTORS"].to_s.strip
  return from_env unless from_env.empty?

  env_file = File.join(ROOT, ".env")
  return "" unless File.exist?(env_file)

  line = File.foreach(env_file).map(&:strip).find { |l| l.start_with?("EMBED_FRAME_ANCESTORS=") }
  line.to_s.sub("EMBED_FRAME_ANCESTORS=", "").delete_prefix('"').delete_suffix('"')
       .delete_prefix("'").delete_suffix("'")
end

begin
  text = FrameAncestors.nginx_include(setting)
rescue FrameAncestors::Invalid => e
  abort "embed_frame_ancestors: #{e.message} (#{OUT} left as it was)"
end

if File.exist?(OUT) && File.read(OUT) == text
  puts "current #{OUT}"
else
  File.write(OUT, text)
  puts "wrote   #{OUT}: #{FrameAncestors.parse(setting)}"
end
