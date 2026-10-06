#!/bin/sh
# What a deploy builds that is not in git. The host's deploy hook runs this
# after it has moved the checkout to origin/main (docs/HANDOVER.md §1):
#
#   sh tools/after_deploy.sh
#
# Today that is Spinel for lesson 39 (tools/build_spinel.mjs into
# html/assets/spinel/): a no-op while tools/spinel.json and the tool are
# unchanged, a few minutes when they changed (downloads and compiled objects
# are kept in .cache/spinel/). With Node 22 on the host it runs there,
# otherwise in a node:22 container (docker-compose.yml, profile "build").
#
# A failed build does not undo the deploy: the rest of the course is served
# as it is, and lesson 39 says that Spinel could not be loaded - so this
# exits with the build's status, for the hook's log, and changes nothing else.
set -u
cd "$(dirname "$0")/.." || exit 1

node_major=$(node --version 2>/dev/null | sed -n 's/^v\([0-9]*\)\..*/\1/p')
if [ -n "$node_major" ] && [ "$node_major" -ge 22 ]; then
  node tools/build_spinel.mjs
else
  docker compose --profile build run --rm spinel-build
fi
status=$?
[ "$status" -eq 0 ] || echo "after_deploy: the Spinel build failed (status $status); lesson 39 cannot compile until it succeeds" >&2
exit "$status"
