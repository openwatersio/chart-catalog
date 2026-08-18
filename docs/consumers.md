# Consumer guide

This is a guide for app developers building against the published catalog at `https://tiles.openwaters.io/charts/catalog.json`. See [docs/format.md](format.md) for the full field reference and [docs/licensing.md](licensing.md) for what you're allowed to do with each source's data.

## Walking the catalog

Fetch `catalog.json`, then follow its `rel: child` links to fetch each collection's `collection.json`. Filter collections by whatever matters to your app: `license` (the SPDX id) if you only want certain licenses, `ow:tier` if you only want pre-baked tiles (tier 1) versus source-only listings (tier 2), or `providers` if you want a specific issuing authority.

From a collection, follow its single `rel: items` link to fetch `items.json`, a GeoJSON `FeatureCollection` holding every chart cell in that collection — one request gets you every cell's coverage and metadata, not just a page of them. Links between catalog documents are relative to the document that contains them, so resolve them against the URL you fetched that document from, not against the root catalog's URL. Features inside `items.json` carry no links of their own.

## Finding items near a location

Each item's `bbox` is a real bounding box (not padded to the collection extent), so a straightforward point-in-bbox or bbox-intersection check against a location or viewport is enough for a first pass. For a tighter check, use the item's `geometry`, a `MultiPolygon` of actual coverage, since chart cells are rarely rectangular in practice.

Collections also carry a coverage `extent.spatial.bbox`, useful for deciding whether a collection is worth walking at all before you fetch every item in it.

## Downloading tile assets

An item's `assets.pmtiles` is the PMTiles archive for that cell. Download the archive, then verify it against the asset's `file:size` and `file:checksum` (a lowercase hex SHA-256 digest) before treating it as good — a mismatch means a partial download or a stale cache and should be retried, not trusted. A PMTiles archive carries its own bounds, zoom range, and layer schema, so there's no separate sidecar to fetch or keep in sync with it.

Chart cells are published individually, matching how tile57 bakes them. If your app needs a larger area, download every cell whose bbox or geometry intersects it and compose them locally; tile57's compositor is built for exactly this.

## Handling usage bands

`properties["enc:band"]` tells you which cells are meant for which zoom range (see the table in [docs/format.md](format.md#usage-bands)), but it's guidance for choosing between overlapping cells, not a source of zoom limits. When several cells cover the same area at different bands, prefer the more detailed band (harbor over approach, approach over coastal, and so on) as the viewport zooms in, and fall back to a coarser band when zoomed out past a detailed cell's intended range. Configure the actual zoom range a cell renders at from the `pmtiles` archive itself.

## Rendering with MapLibre

Register the [pmtiles](https://github.com/protomaps/PMTiles) protocol handler, then point a MapLibre vector source at an item's `assets.pmtiles` href using a `pmtiles://` URL. The archive supplies its own bounds, zoom range, and layer schema, so there is no TileJSON to fetch or configure separately.

## Self-processing from raw ENCs

If you'd rather work from raw chart data than pre-baked tiles, use a collection's `ow:source` field: `catalog` is the upstream provider's machine-readable product catalog URL, `exchange_set` is a bulk archive of every cell when the provider offers one, and `format` tells you what encoding to expect (`s57`, `s101`, `ienc`, `shapefile`, or `raster`). Fetch and parse that catalog yourself, then download the raw archives from each item's `assets.enc` href, which points directly at the provider's own copy (for example NOAA's ENC zip), not at anything we host.

This path works for tier-2 collections too, which carry only the `enc` asset, and for tier-1 cells that haven't been baked yet.

## Staying up to date

To check whether a chart cell has changed, re-fetch the collection's `items.json` and compare `properties["enc:edition"]` and `properties["enc:update"]` for that cell's `id` against the values you stored the last time you downloaded it. If either has increased, the cell has a new edition or update; re-download its `enc` and/or `pmtiles` asset and replace what you have. There's no separate changelog or diff endpoint: the catalog itself is always current as of `ow:generated` on the root, and comparing edition/update numbers is the whole mechanism.
