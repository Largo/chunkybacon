#!/bin/sh
# What a deploy builds that is not in git. The host's deploy hook runs this
# after it has moved the checkout to origin/main (docs/HANDOVER.md §1):
#
#   sh tools/after_deploy.sh
#
# Today that is Spinel for lesson 45 (tools/build_spinel.rb into
# html/assets/spinel/): a no-op while tools/spinel.json and the tool are
# unchanged, a few minutes when they changed (downloads, the wasmtime gem and
# compiled objects are kept in .cache/spinel/). With Ruby 3.3 or later on the
# host it runs there, otherwise in a ruby:4.0 container (docker-compose.yml,
# profile "build").
#
# A failed build does not undo the deploy: the rest of the course is served
# as it is, and lesson 45 says that Spinel could not be loaded - so this
# exits with the build's status, for the hook's log, and changes nothing else.
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
exit "$status"
