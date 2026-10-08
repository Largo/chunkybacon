#!/usr/bin/env bash
# Copies the toolchain built on this machine (tools/compile/build.sh) to the
# host. The host never builds it - that takes half an hour and 10 GB, and the
# deploy hook (tools/after_deploy.sh) only builds lesson 45's own Spinel. The
# toolchain is not in git, so a push to main does not carry it: run this
# once after building, and again whenever build.sh produced new files.
#
#   tools/compile/publish.sh user@host:/path/to/chunkybacon/html/compile/toolchain
#   tools/compile/publish.sh --dry-run user@host:/path/...     # what would be copied
#
# The host's address and paths are kept outside the repository (HANDOVER §1),
# so the target is an argument (or CHUNKY_TOOLCHAIN_TARGET). Before anything
# is sent, every file is checked against the hashes in toolchain/ready.json.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../html/compile/toolchain"
RSYNC_FLAGS=()
if [ "${1:-}" = "--dry-run" ]; then RSYNC_FLAGS+=(--dry-run); shift; fi
TARGET="${1:-${CHUNKY_TOOLCHAIN_TARGET:-}}"
[ -n "$TARGET" ] || { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ -f "$SRC/ready.json" ] || { echo "publish.sh: no $SRC/ready.json - run tools/compile/build.sh first" >&2; exit 1; }

echo "== checking the build against ready.json"
( cd "$SRC" && ruby -rjson -e 'JSON.parse(File.read("ready.json"))["files"].each { |f, h| puts "#{h}  #{f}" }' | sha256sum -c --quiet - ) \
  || { echo "publish.sh: files differ from ready.json - rebuild" >&2; exit 1; }
# the .gz copies nginx serves must be the files' own
for f in "$SRC"/*.wasm "$SRC"/*.js; do
  [ -f "$f.gz" ] && [ "$(gzip -dc "$f.gz" | sha256sum)" = "$(sha256sum < "$f")" ] || { echo "publish.sh: $f.gz is missing or stale - rebuild" >&2; exit 1; }
done

echo "== copying to $TARGET"
# ready.json goes last: the page offers the button only when it is there, so
# a copy cut short shows no button instead of a broken one
rsync -rtvz "${RSYNC_FLAGS[@]}" --exclude ready.json --delete-after "$SRC/" "$TARGET/"
rsync -tv "${RSYNC_FLAGS[@]}" "$SRC/ready.json" "$TARGET/ready.json"
echo "done. Check: the 📦 button in lesson 45 (a normal reload picks up ready.json)"
