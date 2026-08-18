#!/usr/bin/env bash
# Build the published catalog tree: root catalog, the source's collection, and its items.
#
# Tiles are optional: without a bake, items still list every chart and link the upstream ENC
# zips, which is all a self-processing app needs.
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
need jq

dir="$OUT/$SOURCE"
mkdir -p "$dir"

archives="$WORK/archives.json"
if [ ! -s "$archives" ]; then
  archives="$WORK/archives-none.json"
  echo '[]' > "$archives"
fi

jq --argjson source "$(cat "$SOURCE_DEF")" \
   --slurpfile archives "$archives" \
   --arg base_url "$BASE_URL" \
   -f scripts/catalog.jq "$WORK/cells.json" > "$dir/items.json"

count=$(jq '.features | length' "$dir/items.json")
tiled=$(jq '[.features[] | select(.assets.pmtiles)] | length' "$dir/items.json")

# Collection extent is the envelope of everything it holds, and the span of upstream
# publication dates. items.json is read as a file: it is far too large for an argument.
partition=$([ -f "$dir/partition.tpart" ] && echo true || echo false)

jq -n --argjson source "$(cat "$SOURCE_DEF")" --slurpfile items "$dir/items.json" \
      --argjson partition "$partition" --arg base_url "$BASE_URL" '
  ($items[0].features | map(.bbox)) as $b
  | ($items[0].features | map(.properties.datetime) | sort) as $d
  | {
      type: "Collection",
      stac_version: "1.0.0",
      id: $source.id,
      title: $source.title,
      description: $source.description,
      license: $source.license.spdx,
      providers: [{ name: $source.provider.name, roles: ["producer", "licensor"], url: $source.provider.url }],
      extent: {
        spatial: { bbox: [[([$b[][0]] | min), ([$b[][1]] | min), ([$b[][2]] | max), ([$b[][3]] | max)]] },
        temporal: { interval: [[$d[0], $d[-1]]] }
      },
      "ow:tier": $source.tier,
      "ow:cadence": $source.cadence,
      "ow:source": ($source.upstream + { format: $source.format }),
      assets: (if $partition then {
        # The compositor reads this to decide which chart owns each tile.
        partition: {
          href: "\($base_url)/\($source.id)/partition.tpart",
          type: "application/octet-stream",
          title: "Chart ownership partition",
          roles: ["metadata"]
        }
      } else {} end),
      links: [
        { rel: "self", href: "collection.json" },
        { rel: "root", href: "../catalog.json" },
        { rel: "parent", href: "../catalog.json" },
        { rel: "items", href: "items.json", type: "application/geo+json" }
      ]
    }' > "$dir/collection.json"

# The root links only collections that exist on disk: it is the one entry point readers
# have, so a child link to something unbuilt is a dead end.
built=$(for c in "$OUT"/*/collection.json; do
          [ -e "$c" ] && basename "$(dirname "$c")"
        done | jq -R . | jq -sc '.')

jq -n --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson sources "$(jq -s '.' sources/*.json)" \
      --argjson built "$built" '
  {
    type: "Catalog",
    stac_version: "1.0.0",
    id: "openwaters-charts",
    description: "Open Waters chart catalog: freely redistributable electronic navigational charts, as upstream source definitions and pre-baked vector tiles. Not for navigation.",
    "ow:version": "0.1.0",
    "ow:generated": $generated,
    links: ([
      { rel: "self", href: "catalog.json" },
      { rel: "root", href: "catalog.json" }
    ] + [
      $sources[] | select(.tier <= 2) | select(.id | IN($built[]))
      | { rel: "child", href: "\(.id)/collection.json", title: .title }
    ])
  }' > "$OUT/catalog.json"

echo "  $count items ($tiled with tiles) in $dir/items.json"
