# Two Rubies share this page: CRuby (ruby.wasm, browser.script.iife.js) runs
# the lessons' code, PicoRuby.wasm runs the page itself (html/shell/). Both
# loaders run every <script type="text/ruby"> they find, so main.rb would be
# fed to PicoRuby too. This rewrites PicoRuby's loader to look for
# <script type="text/picoruby"> instead - the tag shell/loader.js writes.
#
#   ruby tools/patch_picoruby_loader.rb           # patch html/assets/picoruby/init.iife.js
#   ruby tools/patch_picoruby_loader.rb --check   # exit 1 unless it is patched
#
# Installing or updating the runtime (html/assets/picoruby/, see
# docs/PICORUBY_SHELL.md) writes the upstream loader again: run this after.
# Like tools/update_ruby_wasm.rb it refuses to guess: if the upstream line is
# not there exactly once, the loader changed shape and this script aborts.
LOADER = File.expand_path("../html/assets/picoruby/init.iife.js", __dir__)
UPSTREAM = %q{document.querySelectorAll('script[type="text/ruby"]')}
PATCHED = %q{document.querySelectorAll('script[type="text/picoruby"]')}

abort "no PicoRuby loader at #{LOADER} - install the runtime first" unless File.file?(LOADER)
source = File.read(LOADER)
upstream = source.scan(UPSTREAM).size
patched = source.scan(PATCHED).size

if ARGV.include?("--check")
  ok = upstream.zero? && patched == 1
  puts ok ? "patched: #{LOADER}" : "NOT patched (#{upstream} upstream, #{patched} patched selectors): #{LOADER}"
  exit(ok ? 0 : 1)
end

if upstream.zero? && patched == 1
  puts "already patched: #{LOADER}"
  exit 0
end
abort "expected the upstream selector exactly once, found #{upstream} (and #{patched} patched) - loader changed shape, adjust this script" unless upstream == 1 && patched.zero?

File.write(LOADER, source.sub(UPSTREAM, PATCHED))
puts "patched #{LOADER}: text/ruby -> text/picoruby"
