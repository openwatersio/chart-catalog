# Build one collection's items from NOAA's product catalog.
#
# Input: the active cells array. Args: $source (source definition), $archives (slurped
# baked-archive stats), $base_url. Output: a GeoJSON FeatureCollection of STAC-flavored items.

# yq gives a bare object where the XML had one child and an array where it had several.
def list($x): if ($x | type) == "array" then $x elif $x == null then [] else [$x] end;

# The navigational purpose digit is the third character of every ENC cell name.
def band($name): {
  "1": "overview", "2": "general", "3": "coastal",
  "4": "approach", "5": "harbor",  "6": "berthing"
}[$name[2:3]] // "coastal";

def ring($panel):
  [list($panel.vertex)[] | [(.long | tonumber), (.lat | tonumber)]]
  | if .[0] != .[-1] then . + [.[0]] else . end;

# NOAA writes Pacific panels as negative offsets past -180 (131.05E as -228.95). Panels are
# cut at the antimeridian rather than crossing it, so shifting a whole panel by +360 restores
# real longitudes and leaves its -180 edge at +180.
def unwrap($r): if ([$r[][0]] | min) < -180 then [$r[] | [(.[0] + 360), .[1]]] else $r end;

def polygons($cell): [list($cell.cov.panel)[] | [unwrap(ring(.))]];

def bbox($polys):
  [$polys[][][][0]] as $lon | [$polys[][][][1]] as $lat
  | [($lon | min), ($lat | min), ($lon | max), ($lat | max)];

def tags($cell): [
  (list($cell.coast_guard_districts.coast_guard_district)[] | "cgd:\(.)"),
  (list($cell.states.state)[] | "state:\(.)"),
  (list($cell.regions.region)[] | "region:\(.)")
];

(($archives[0] // []) | map({key: .id, value: .}) | from_entries) as $archive
| {
    type: "FeatureCollection",
    features: [
      .[]
      | polygons(.) as $polys
      | .name as $name
      | {
          type: "Feature",
          stac_version: "1.0.0",
          id: $name,
          collection: $source.id,
          bbox: bbox($polys),
          geometry: { type: "MultiPolygon", coordinates: $polys },
          properties: ({
            title: .lname,
            datetime: .zipfile_datetime_iso8601,
            "enc:edition": (.edtn | tonumber),
            "enc:update": (.updn | tonumber),
            "enc:scale": (.cscale | tonumber),
            "enc:band": band($name),
            "enc:issued": .isdt
          } + (tags(.) | if length > 0 then {"enc:tags": .} else {} end)),
          assets: ({
            enc: {
              href: .zipfile_location,
              type: "application/zip",
              roles: ["source"],
              "file:size": (.zipfile_size | tonumber)
            }
          } + (if $archive[$name] then {
            pmtiles: {
              # tile57's layout: each chart owns a directory beside the partition file.
              href: "\($base_url)/\($source.id)/\($name)/\($name).pmtiles",
              type: "application/vnd.pmtiles",
              roles: ["tiles"],
              "file:size": $archive[$name].size,
              "file:checksum": $archive[$name].checksum
            }
          } else {} end))
        }
    ]
  }
