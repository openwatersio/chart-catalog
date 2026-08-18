#!/usr/bin/env bash
# Validate source definitions and, when a build is present, the catalog tree.
#
# Schema checking runs through check-jsonschema (fetched on demand by uvx); the jq
# assertions afterwards cover invariants a schema can't express.
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
need jq uvx

# Schemas $ref each other by relative filename; the base URI resolves those against the
# local directory rather than fetching the published copies.
check() {
  uvx --quiet check-jsonschema --base-uri "file://$PWD/schema/" --schemafile "$1" "${@:2}"
}

check schema/source.schema.json sources/*.json

if [ ! -f "$OUT/catalog.json" ]; then
  echo "sources valid (no build to check)"
  exit 0
fi

check schema/catalog.schema.json "$OUT/catalog.json"
check schema/collection.schema.json "$OUT"/*/collection.json
check schema/items.schema.json "$OUT"/*/items.json

fail() { echo "invariant failed: $1" >&2; exit 1; }

for items in "$OUT"/*/items.json; do
  jq -e '.features | length > 0' "$items" >/dev/null || fail "$items has no features"
  # An item without coverage can't be placed on a map or matched to a route.
  jq -e '[.features[] | select((.geometry.coordinates | length) == 0)] | length == 0' "$items" \
    >/dev/null || fail "$items has items with empty geometry"
  # Every archive the catalog advertises must be a file we actually built.
  dir=$(dirname "$items")
  missing=$(jq -r '.features[] | select(.assets.pmtiles) | .id' "$items" | while read -r id; do
      [ -f "$dir/$id/$id.pmtiles" ] || echo "$id"
    done | head -5)
  [ -z "$missing" ] || fail "$items advertises tiles with no archive: $missing"
done

echo "valid: $(jq -r '[.features[]] | length' "$OUT"/*/items.json | paste -sd+ - | bc) items"
