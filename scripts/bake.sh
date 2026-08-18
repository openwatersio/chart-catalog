#!/usr/bin/env bash
# Bake the whole exchange set, then record each archive's size and hash.
#
# tile57 walks the ENC_ROOT itself and writes a live-composite structure: one directory per
# chart holding its archive and the text notes it references, plus the ownership partition
# the compositor needs to stitch charts by tile. That structure is published as-is, so a
# client can point at the prefix and compose from it. Baking straight into the published
# directory also keeps tile57's own skip working: an archive newer than its input is left
# alone, so a rerun over an unchanged set costs nothing.
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
need "$TILE57" jq

tiles="$OUT/$SOURCE"
mkdir -p "$tiles"

"$TILE57" bake "$WORK/ENC_ROOT" -o "$tiles" ${BAKE_JOBS:+-j "$BAKE_JOBS"}

echo "hashing archives"
# One sha256 call over the whole glob: a process per archive would dominate the runtime.
sha256 "$tiles"/*/*.pmtiles | while read -r hash path; do
  name=$(basename "$path" .pmtiles)
  printf '{"id":"%s","checksum":"%s","size":%s}\n' \
    "$name" "$hash" "$(wc -c < "$path" | tr -d ' ')"
done | jq -s '.' > "$WORK/archives.json"

echo "  $(jq length "$WORK/archives.json") archives in $tiles"
