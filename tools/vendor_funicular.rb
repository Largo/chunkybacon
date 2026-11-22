# Puts Funicular's runtime (the picoruby-funicular mrbgem's mrblib/*.rb,
# https://github.com/picoruby/funicular) into html/funicular/vendor/,
# unchanged, at the commit that PicoRuby.wasm's tag pins as its submodule
# (html/assets/picoruby/PICORUBY_VERSION.txt). That wasm has Funicular
# compiled in: it runs the apps of lesson `funicular` in the preview below
# each cell. These Ruby files are the same framework for CRuby: the kernel
# loads them (html/funicular_cells.rb) to run a cell's code once without a
# browser, the way Funicular's own SSR does (lib/funicular/ssr/runtime.rb),
# so errors are explained and the exercise is checked headless.
#
#   ruby tools/vendor_funicular.rb             # fetch the files again (same bytes)
#   ruby tools/vendor_funicular.rb --from DIR  # from a checkout of funicular at that commit
#   ruby tools/vendor_funicular.rb --check     # offline: are the files the ones VENDOR.txt records?
#
# After a new PicoRuby.wasm (tools/vendor_picoruby.rb): set COMMITS below to
# the submodule pointer of the new tag (GitHub: picoruby/picoruby, tree
# mrbgems/picoruby-funicular at the tag), run this, then ruby
# test/funicular_test.rb and node test/funicular_test.mjs.
require "net/http"
require "uri"
require "digest"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
TARGET = File.join(ROOT, "html/funicular/vendor")
RECORD = File.join(TARGET, "VENDOR.txt")
WASM_RECORD = File.join(ROOT, "html/assets/picoruby/PICORUBY_VERSION.txt")
SOURCE = "https://raw.githubusercontent.com/picoruby/funicular/%<commit>s/mrblib/%<file>s"

# the picoruby-funicular submodule pointer of each PicoRuby tag
COMMITS = { "4.0.3" => "86bb29b44cadd10c1e5613abe05f4cc7ddc0101e" }.freeze

# The order Funicular's SSR loads them in (lib/funicular/ssr/runtime.rb,
# LOAD_ORDER): by what a class body needs when it is evaluated.
FILES = %w[
  0_tags environment_inquirer vdom html_serializer differ patcher styles
  runtime view_context debug component error_boundary router 0_validations
  1_validators db relation model store store_singleton store_collection
  form_builder http cable file_upload funicular
].map { |name| "#{name}.rb" }.freeze

def wasm_version
  File.read(WASM_RECORD)[/^version=(.+)$/, 1] or abort "#{WASM_RECORD}: no version="
end

def commit
  COMMITS[wasm_version] or abort "no Funicular commit known for PicoRuby #{wasm_version}: add it to COMMITS"
end

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
  record = File.exist?(RECORD) ? File.read(RECORD) : abort("#{RECORD} is missing: run tools/vendor_funicular.rb")
  problems = []
  vendored = record[/^commit=(.+)$/, 1]
  problems << "vendored #{vendored}, but PicoRuby #{wasm_version} pins #{commit} (run tools/vendor_funicular.rb)" if vendored != commit
  FILES.each do |file|
    line = record[/^file=#{Regexp.escape(file)} (\d+) (\h+)$/]
    path = File.join(TARGET, file)
    if line.nil?
      problems << "#{file}: not in VENDOR.txt"
    elsif !File.exist?(path)
      problems << "#{file}: missing"
    elsif Digest::SHA256.file(path).hexdigest != Regexp.last_match(2)
      problems << "#{file}: changed since it was vendored"
    end
  end
  if problems.empty?
    puts "html/funicular/vendor: Funicular #{commit[0, 7]} (PicoRuby #{wasm_version}), #{FILES.size} files as recorded"
  else
    puts problems
    exit 1
  end
end

def vendor(from)
  FileUtils.mkdir_p(TARGET)
  lines = ["source=#{format(SOURCE, commit: commit, file: '<file>')}", "commit=#{commit}",
           "picoruby=#{wasm_version}",
           "license=MIT, (c) 2025 HASUMI Hitoshi (see THIRD_PARTY_NOTICES.md)",
           "installed_by=tools/vendor_funicular.rb (unchanged copies, in load order)"]
  FILES.each do |file|
    body = from ? File.binread(File.join(from, "mrblib", file)) : get(format(SOURCE, commit: commit, file: file))
    File.binwrite(File.join(TARGET, file), body)
    lines << "file=#{file} #{body.bytesize} #{Digest::SHA256.hexdigest(body)}"
    puts "#{file} (#{body.bytesize} bytes)"
  end
  File.write(RECORD, lines.join("\n") + "\n")
end

if ARGV.first == "--check"
  check
else
  from = ARGV[0] == "--from" ? ARGV[1] : nil
  vendor(from)
end
