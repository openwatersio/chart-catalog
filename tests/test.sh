#!/usr/bin/env bash
# Build a catalog from a fixture and assert the things that would silently go wrong:
# coordinate order, panel and tag shapes, the antimeridian shift, and cancelled cells.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
OUT="$WORK/out"
export WORK OUT SOURCE=noaa-enc BASE_URL=https://tiles.example.test/charts
trap 'rm -rf "$WORK"' EXIT

fails=0
check() {
  if jq -e "$2" "$3" >/dev/null; then
    echo "  ok: $1"
  else
    echo "  FAIL: $1" >&2
    fails=$((fails + 1))
  fi
}

yq -p=xml -o=json tests/fixtures/prodcat-sample.xml > "$WORK/prodcat.json"
jq '[.EncProductCatalog.cell[] | select(.status == "Active")]' "$WORK/prodcat.json" > "$WORK/cells.json"

# Pretend one cell baked, so both asset shapes get exercised. tile57 gives each chart its
# own directory beside the partition file, and the catalog publishes that layout as-is.
mkdir -p "$OUT/noaa-enc/US1GLBAA"
printf 'not a real archive' > "$OUT/noaa-enc/US1GLBAA/US1GLBAA.pmtiles"
printf 'partition' > "$OUT/noaa-enc/partition.tpart"
printf '[{"id":"US1GLBAA","checksum":"%s","size":18}]' "$(printf '%064d' 0)" > "$WORK/archives.json"

scripts/catalog.sh >/dev/null
items="$OUT/noaa-enc/items.json"

echo "items.json"
check "cancelled cells are excluded" '[.features[].id] | index("US1EEZ1M") == null' "$items"
check "active cells are present" '.features | length == 3' "$items"
check "coordinates are [lon, lat]" \
  '[.features[].geometry.coordinates[][][] | select(.[0] < -180 or .[0] > 180 or .[1] < -90 or .[1] > 90)] | length == 0' "$items"
check "antimeridian panels shifted east" \
  '[.features[] | select(.id == "US1GLBCR") | .bbox[0]] | .[0] > 0' "$items"
check "multi-panel cell keeps both panels" \
  '[.features[] | select(.id == "US3TC300") | .geometry.coordinates | length] | .[0] == 2' "$items"
check "rings are closed" \
  '[.features[].geometry.coordinates[][] | select(.[0] != .[-1])] | length == 0' "$items"
check "edition and update are numbers" \
  '[.features[] | select((.properties["enc:edition"] | type) != "number")] | length == 0' "$items"
check "band comes from the cell name" \
  '[.features[] | select(.id == "US3TC300") | .properties["enc:band"]] | .[0] == "coastal"' "$items"
check "tags carry district and state" \
  '[.features[] | select(.id == "US1GLBAA") | .properties["enc:tags"]] | .[0] | index("cgd:14") != null' "$items"
check "baked cell advertises tiles with a checksum" \
  '[.features[] | select(.id == "US1GLBAA") | .assets.pmtiles["file:checksum"] | length] | .[0] == 64' "$items"
check "unbaked cells carry only the upstream zip" \
  '[.features[] | select(.id == "US1GLBCR") | .assets | keys] | .[0] == ["enc"]' "$items"

echo "collection.json"
collection="$OUT/noaa-enc/collection.json"
check "license is the SPDX id" '.license == "CC0-1.0"' "$collection"
check "extent covers every item" \
  '.extent.spatial.bbox[0] | (.[0] >= -180 and .[2] <= 180)' "$collection"
check "links to its items document" \
  '[.links[] | select(.rel == "items")] | length == 1' "$collection"
check "publishes the compositor's partition" \
  '.assets.partition.href | endswith("/noaa-enc/partition.tpart")' "$collection"
check "archive href points inside the chart's directory" \
  '[.features[] | select(.id == "US1GLBAA") | .assets.pmtiles.href] | .[0] | endswith("/noaa-enc/US1GLBAA/US1GLBAA.pmtiles")' "$items"

echo "catalog.json"
check "root links the built collection" \
  '[.links[] | select(.rel == "child") | .href] == ["noaa-enc/collection.json"]' "$OUT/catalog.json"

if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
