# Catalog format

The catalog is a static tree of JSON documents hosted on object storage under `https://tiles.openwaters.io/charts/`. There is no API server; the JSON files are the API.

## Why STAC-flavored

The documents use [STAC](https://stacspec.org/)'s shape and field names: `stac_version`, `bbox`, `geometry`, `license`, `providers`, `assets`, `links`. This is a deliberate, documented subset, not a claim of STAC conformance — there's no STAC API, no extension registry, and no validation against the official STAC schemas. Reusing STAC's vocabulary keeps the catalog partially readable by generic STAC tooling and leaves a clear migration path to full STAC conformance later, without forcing that complexity on the catalog now. This mirrors the path Overture Maps took: bespoke release manifests first, STAC once the shape had proven itself.

Fields specific to this catalog use two namespace prefixes:

- `ow:` — catalog-level metadata (version, generation time, tier, cadence, source definition).
- `enc:` — chart-specific metadata carried on items (edition, update, scale, issue date, usage band, tags).

## Document types

The catalog is a three-level tree:

1. **Root catalog** (`catalog.json`) — one per publish, links to every collection.
2. **Collection** (`{collection}/collection.json`) — one per provider/product line (`noaa-enc`, ...), carries license, provider, coverage extent, and the source definition.
3. **Items** (`{collection}/items.json`) — one per collection, a GeoJSON FeatureCollection whose features are every chart cell in that collection, each with real coverage geometry and its own assets.

### Root catalog

```json
{
  "type": "Catalog",
  "stac_version": "1.0.0",
  "id": "openwaters-charts",
  "description": "Freely redistributable ENC coverage, pre-baked as vector tiles.",
  "ow:version": "1.0.0",
  "ow:generated": "2026-08-11T00:00:00Z",
  "links": [
    { "rel": "self", "href": "catalog.json" },
    { "rel": "root", "href": "catalog.json" },
    { "rel": "child", "href": "noaa-enc/collection.json", "title": "NOAA Electronic Navigational Charts" }
  ]
}
```

- `type` is always the literal string `Catalog`.
- `id` identifies this catalog instance.
- `description` is a human-readable summary of the catalog's scope.
- `ow:version` is the schema version of the catalog format itself, as `major.minor.patch`, so consumers can detect breaking changes.
- `ow:generated` is the timestamp of the build that produced this file.
- `links` holds `rel: self` and `rel: root` (both pointing back at the root catalog itself), plus one `rel: child` entry per built collection. A source only gets a `child` entry once its collection has actually been built on disk, so a link never points at something unbuilt.

### Collection

```json
{
  "type": "Collection",
  "stac_version": "1.0.0",
  "id": "noaa-enc",
  "title": "NOAA Electronic Navigational Charts",
  "description": "Official S-57 electronic navigational charts for United States coastal waters and the Great Lakes, produced by the NOAA Office of Coast Survey and updated weekly with Notices to Mariners.",
  "license": "CC0-1.0",
  "providers": [
    { "name": "NOAA Office of Coast Survey", "roles": ["producer", "licensor"], "url": "https://nauticalcharts.noaa.gov" }
  ],
  "extent": {
    "spatial": { "bbox": [[-179.5, 17.5, -65.0, 74.0]] },
    "temporal": { "interval": [["2013-01-01T00:00:00Z", "2026-08-11T00:00:00Z"]] }
  },
  "ow:tier": 1,
  "ow:cadence": "weekly",
  "ow:source": {
    "catalog": "https://www.charts.noaa.gov/ENCs/ENCProdCat.xml",
    "exchange_set": "https://www.charts.noaa.gov/ENCs/All_ENCs.zip",
    "format": "s57"
  },
  "links": [
    { "rel": "self", "href": "collection.json" },
    { "rel": "root", "href": "../catalog.json" },
    { "rel": "parent", "href": "../catalog.json" },
    { "rel": "items", "href": "items.json", "type": "application/geo+json" }
  ]
}
```

- `license` is the SPDX identifier for the source data (a plain string, not an object — the full license record with its URL and attribution text lives in the source definition in `sources/`).
- `providers` is an array of `{ name, roles, url }`; roles are free text (`producer`, `licensor`, `processor`, `host`, and so on).
- `extent.spatial.bbox` is the envelope of every item's `bbox` in the collection; `extent.temporal.interval` is the span from the oldest to the newest `properties.datetime` across those items.
- `ow:tier` is `1` or `2`. Only tier-1 and tier-2 sources get a collection at all — tier 3 is excluded from the catalog entirely and exists only as a `sources/*.json` definition.
- `ow:cadence` is how often the upstream provider issues updates: `daily`, `weekly`, `monthly`, or `irregular`.
- `ow:source` describes how to fetch the raw data yourself: `catalog` is the upstream's machine-readable product catalog URL, `exchange_set` is a bulk archive of every cell when the provider offers one, and `format` is the chart encoding (`s57`, `s101`, `ienc`, `shapefile`, or `raster`).
- `links` holds `rel: self`, `rel: root` and `rel: parent` back to the root catalog, and a single `rel: items` entry pointing at `items.json`, typed `application/geo+json`. There is no `rel: item` link and no per-cell link — a client fetches `items.json` once to get every chart cell in the collection.

### Items

`items.json` is a GeoJSON `FeatureCollection`; each feature is one chart cell:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "stac_version": "1.0.0",
      "id": "US2ATLPD",
      "collection": "noaa-enc",
      "bbox": [-74.7, 39.1, -73.9, 39.6],
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [[[[-74.7, 39.1], [-73.9, 39.1], [-73.9, 39.6], [-74.7, 39.6], [-74.7, 39.1]]]]
      },
      "properties": {
        "title": "Atlantic City to Sandy Hook",
        "datetime": "2026-08-04T00:00:00Z",
        "enc:edition": 1,
        "enc:update": 2,
        "enc:scale": 700000,
        "enc:band": "general",
        "enc:issued": "2026-07-28",
        "enc:tags": ["cgd:5", "state:NJ", "region:Atlantic Coast"]
      },
      "assets": {
        "enc": {
          "href": "https://charts.noaa.gov/ENCs/US2ATLPD.zip",
          "type": "application/zip",
          "roles": ["source"],
          "file:size": 486213
        },
        "pmtiles": {
          "href": "https://tiles.openwaters.io/charts/noaa-enc/US2ATLPD.pmtiles",
          "type": "application/vnd.pmtiles",
          "roles": ["tiles"],
          "file:size": 1258291,
          "file:checksum": "3c9909afec25354d551dae21590bb26e38d53f2173b8d3dc3eee4c047e7ab884"
        }
      }
    }
  ]
}
```

- `id` is the chart cell name as issued by the provider (for NOAA, an S-57 cell name like `US2ATLPD`).
- `collection` is the parent collection's `id`.
- `bbox` and `geometry` describe real coverage, not just the bounding box; `geometry.type` is always `MultiPolygon`.
- `properties.title` is the cell's human-readable name.
- `properties.datetime` is the timestamp of the upstream exchange-set zip that carries this cell's current edition.
- `enc:edition` and `enc:update` are the S-57 edition and update numbers; together they're the version of the cell.
- `enc:scale` is the compilation scale (for example `700000` for 1:700,000); it can be `null` when the upstream catalog doesn't publish one.
- `enc:band` is the usage band (see below).
- `enc:issued` is the upstream issue date for this edition, as an ISO date.
- `enc:tags` is an optional array of free-text tags — Coast Guard district, state, and region — carried through from the upstream catalog.

Every feature has `assets`; none has `links`. There is no per-item self, root, or collection link, because an item is never fetched on its own — it only ever arrives as one feature inside its collection's `items.json`.

## Usage bands

`enc:band` is one of six values, each with a corresponding tile57 zoom range:

| Band | Zoom range | Typical scale |
|---|---|---|
| `overview` | 5-8 | smaller than 1:1,500,000 |
| `general` | 8-10 | 1:1,500,000 to 1:280,000 |
| `coastal` | 10-12 | 1:280,000 to 1:90,000 |
| `approach` | 12-14 | 1:90,000 to 1:22,000 |
| `harbor` | 14-16 | 1:22,000 to 1:4,000 |
| `berthing` | 16-18 | larger than 1:4,000 |

The band is determined by the third character of the cell name (the S-57 usage band digit): `1` is overview, `2` is general, `3` is coastal, `4` is approach, `5` is harbor, `6` is berthing. `US2ATLPD` above has `2` in that position, hence `general`.

These ranges are the band's nominal display range. A cell is baked at its own compilation scale, so an archive can hold a wider or narrower range than its band suggests. A PMTiles archive embeds its own bounds, zoom range, and layer schema, which every PMTiles client reads directly from the file, so that — not the band — is what a renderer should configure the source with. Use the band for choosing between overlapping cells (prefer the more detailed band as a viewport zooms in) rather than for setting zoom limits.

## Asset roles

Assets appear on items as an object keyed by a short name, each with `href`, `type`, and `roles` (the schema reserves the same shape for collections, but the pipeline doesn't populate any there yet). The roles used on items are:

- `enc` carries role `source` — the upstream ENC zip (or other native format archive) as published by the provider. Only present when the provider offers direct download.
- `pmtiles` carries role `tiles` — the baked PMTiles archive for this chart cell. Present once the cell has been baked.

A cell that is listed but not yet baked, or one from a tier-2 source we do not re-host, carries only the `enc` asset.

`file:size` (bytes) and `file:checksum` (a lowercase 64-character hex SHA-256 digest) are present on assets we control the bytes for, so consumers can verify a download before treating it as valid and can plan storage before fetching. The upstream `enc` asset carries `file:size` when the provider publishes it, and no checksum, since we do not hash bytes we do not host.

## Link rules

Links between catalog documents (`rel` values like `self`, `root`, `parent`, `child`, `items`) use paths relative to the linking document's own location in the published tree, matching the directory layout under `charts/`. Asset hrefs (inside `assets`, not `links`) are always absolute URLs, since assets are meant to be fetched directly regardless of where the referencing document came from. Features inside `items.json` carry no `links` at all.

## Change detection

To find out whether a chart cell has a new edition without re-downloading it, fetch the collection's `items.json` and compare `properties["enc:edition"]` and `properties["enc:update"]` for a feature's `id` against the values you stored the last time you fetched it. A change in either means new data is available for that cell; re-fetch its `enc` and/or `pmtiles` asset. Fetching the whole file is cheap: for all 7,048 NOAA cells, `items.json` runs about 10 MB raw and 0.5 MB gzipped.
