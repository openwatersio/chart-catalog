#!/usr/bin/env bash
# Fetch a source's product catalog and its full exchange set.
#
# NOAA publishes one catalog covering every cell and one zip containing every cell, so
# there is nothing to shard or diff: each run takes the current state of both.
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
need curl yq jq unzip

catalog_url=$(jq -r '.upstream.catalog' "$SOURCE_DEF")
exchange_url=$(jq -r '.upstream.exchange_set' "$SOURCE_DEF")
mkdir -p "$WORK"

echo "fetching $catalog_url"
curl -fsSL --retry 3 --retry-delay 5 -o "$WORK/prodcat.xml" "$catalog_url"
yq -p=xml -o=json "$WORK/prodcat.xml" > "$WORK/prodcat.json"
jq '[.EncProductCatalog.cell[] | select(.status == "Active")]' "$WORK/prodcat.json" > "$WORK/cells.json"
echo "  $(jq length "$WORK/cells.json") active cells (of $(jq '.EncProductCatalog.cell | length' "$WORK/prodcat.json"))"

echo "fetching $exchange_url"
# -z: skip the download when our copy is already as new as the server's.
curl -fsSL --retry 3 --retry-delay 5 -o "$WORK/exchange.zip" \
  ${SKIP_IF_FRESH:+-z "$WORK/exchange.zip"} "$exchange_url"

echo "unpacking exchange set"
rm -rf "$WORK/ENC_ROOT"
unzip -q -o "$WORK/exchange.zip" -d "$WORK/unzip"
# The zip's ENC_ROOT can sit at any depth; normalize it to one known path.
root=$(find "$WORK/unzip" -type d -name ENC_ROOT -print -quit)
[ -n "$root" ] || { echo "no ENC_ROOT in $exchange_url" >&2; exit 1; }
mv "$root" "$WORK/ENC_ROOT"
rm -rf "$WORK/unzip"
echo "  $(find "$WORK/ENC_ROOT" -name '*.000' | wc -l | tr -d ' ') base cells unpacked"
