#!/bin/sh
# What a deploy builds that is not in git. The host's deploy hook runs this
# after it has moved the checkout to origin/main (docs/HANDOVER.md §1):
#
#   sh tools/after_deploy.sh
#
# First Spinel for lesson 45 (tools/build_spinel.rb into
# html/assets/spinel/): a no-op while tools/spinel.json and the tool are
# unchanged, a few minutes when they changed (downloads, the wasmtime gem and
# compiled objects are kept in .cache/spinel/). With Ruby 3.3 or later on the
# host it runs there, otherwise in a ruby:4.0 container (docker-compose.yml,
# profile "build").
#
# A failed build does not undo the deploy: the rest of the course is served
# as it is, and lesson 45 says that Spinel could not be loaded - so this
# exits with the build's status, for the hook's log, and changes nothing else.
#
# Then the JRuby lesson's runtimes (docs/HANDOVER.md §6r), nothing built:
# tools/vendor_jruby.rb (TeaVM JRuby + the USGS data, html/assets/jruby/)
# and tools/vendor_jruby_swing.rb (the bonus's jars, html/assets/jruby-swing/)
# copy pinned, SHA-256-checked files into place - no-ops while they are
# current. They take TeaVM's build and two jruby-cheerpj jars from this
# host's .cache/ (stocked once with --from), so they cannot fail by
# themselves later; when they do, the lesson says JRuby could not be loaded
# and the rest is unaffected - a warning, not this script's status (a retry
# would not stock the cache, and Spinel's publishing must not wait on it).
set -u
cd "$(dirname "$0")/.." || exit 1

# the wasmtime gem comes prebuilt for Ruby 3.3, 3.4 and 4.0
ruby_version=$(ruby -v 2>/dev/null | sed -n 's/^ruby \([0-9]*\)\.\([0-9]*\).*/\1\2/p')
if [ -n "$ruby_version" ] && [ "$ruby_version" -ge 33 ]; then
  ruby tools/build_spinel.rb
else
  docker compose --profile build run --rm spinel-build
fi
status=$?
[ "$status" -eq 0 ] || echo "after_deploy: the Spinel build failed (status $status); lesson 45 cannot compile until it succeeds" >&2

for tool in vendor_jruby vendor_jruby_swing; do
  if command -v ruby >/dev/null 2>&1; then
    ruby "tools/$tool.rb" || echo "after_deploy: tools/$tool.rb failed; the JRuby lesson cannot load that part until it succeeds" >&2
  else
    docker compose --profile build run --rm spinel-build ruby "tools/$tool.rb" ||
      echo "after_deploy: tools/$tool.rb failed; the JRuby lesson cannot load that part until it succeeds" >&2
  fi
done
exit "$status"
