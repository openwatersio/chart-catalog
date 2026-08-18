# Chart Catalog Plan

An open-source catalog of freely redistributable vector nautical charts. This repo curates ENC sources, pre-bakes vector tiles with [tile57](https://github.com/beetlebugorg/tile57), publishes them to tiles.openwaters.io, and maintains a machine-readable catalog that chart plotter apps (lookout-marine, Open Waters Boating, others) consume. Apps can use the catalog two ways: download pre-baked PMTiles, or read the source definitions and process the raw ENCs themselves.

## Catalog format

A static, STAC-flavored JSON catalog hosted on object storage. Not full STAC conformance — a documented subset using STAC's shape and field names (`bbox`, `geometry`, `license`, `providers`, `assets`, `links`), so it stays migratable to real STAC and partially readable by STAC tooling without dragging in the extension registry or API spec. This mirrors the path Overture Maps took (they migrated their bespoke release manifests to STAC in 2026).

Three tiers:

1. **Root catalog** (`catalog.json`) — lists collections, schema version, generation timestamp.
2. **Collection per provider/product line** (`noaa-enc`, `usace-ienc`, `wsv-ienc`, `rws-ienc`, ...) — carries the license (SPDX id + URL), provider info, coverage extent, update cadence, and the *source definition*: how to fetch the raw data (a product catalog URL and, when the provider offers one, a bulk exchange-set URL), so apps that self-process never need our tiles.
3. **Items document per collection** (`items.json`) — a single GeoJSON `FeatureCollection` holding every chart cell in the collection, each feature carrying real coverage geometry (not just bbox) plus properties from the upstream catalog: cell name, edition, update number, issue date, compilation scale, usage band. One request gets a client every chart's coverage and metadata. Assets on each feature point at both the upstream ENC zip and our baked PMTiles; features carry no `links`.

A PMTiles archive embeds its own bounds, zoom range, and layer schema, which every PMTiles client reads directly, so there is no sidecar metadata document to generate or keep in sync.

Sketch of a feature in `items.json`:

```json
{
  "type": "Feature",
  "stac_version": "1.0.0",
  "id": "US5MD1MC",
  "collection": "noaa-enc",
  "bbox": [-76.61, 38.97, -76.36, 39.29],
  "geometry": { "type": "MultiPolygon", "coordinates": ["..."] },
  "properties": {
    "title": "Baltimore Harbor",
    "datetime": "2026-08-11T00:00:00Z",
    "enc:edition": 42,
    "enc:update": 3,
    "enc:scale": 20000,
    "enc:band": "harbor",
    "enc:issued": "2026-08-04"
  },
  "assets": {
    "enc": { "href": "https://charts.noaa.gov/ENCs/US5MD1MC.zip", "type": "application/zip", "roles": ["source"], "file:size": 486213 },
    "pmtiles": { "href": "https://tiles.openwaters.io/charts/noaa-enc/US5MD1MC.pmtiles", "type": "application/vnd.pmtiles", "roles": ["tiles"], "file:size": 1258291, "file:checksum": "3c9909afec25354d551dae21590bb26e38d53f2173b8d3dc3eee4c047e7ab884" }
  }
}
```

Design notes carried over from the SeaScape catalog review:

- Everything is declarative JSON. SeaScape's non-serializable `resolve()` hook becomes a normal upstream catalog URL in the collection's source definition.
- SPDX license identifiers plus a license URL, never free-text strings.
- Provider is a structured first-class field, not baked into attribution prose.
- Schema version on the root so the format can evolve.
- Coverage is real geometry; SeaScape's bbox-only tuples lose the polygon NOAA already publishes.
- SHA-256 checksums and byte sizes on the assets we host, so apps can verify downloads and plan storage. Upstream assets carry the size the provider publishes and no checksum, since we never see those bytes.

Usage bands map from compilation scale exactly as tile57 already documents (Overview 5–8, General 8–10, Coastal 10–12, Approach 12–14, Harbor 14–16, Berthing 16–18). The `tile57 cells` and `tile57 catalog` JSON output is the vocabulary baseline, so catalog generation is largely a passthrough. The band is guidance for choosing between overlapping cells, not a source of zoom limits — the PMTiles archive itself carries the real zoom range a renderer should use.

## Tile publishing model

tile57 bakes **per-cell PMTiles**; a runtime compositor stitches archives by tile coordinate. The catalog therefore publishes per-cell archives, matching how lookout-marine already consumes charts locally. Apps select cells (by region tap, bbox, or usage band), download the archives, and compose locally.

Still to add: the collection-level rendering assets tile57 generates, meaning `partition.tpart` for the compositor plus `style.json` per scheme (day/dusk/night) pointed at the hosted tile URLs via `tile57 style --pmtiles-url`, sprite/pattern atlases, and glyphs. The format reserves collection `assets` for them so an app can eventually render with zero local portrayal work.

## Sources

The licensing research landed on a hard pattern: nearly all coastal ENCs worldwide flow through the commercial RENC system (PRIMAR/IC-ENC, S-63 encrypted), so open sources are the exception — US, NZ derivatives, and European inland waterways.

**Tier 1 — redistributable, pre-bake tiles:**

| Source | Coverage | License |
|---|---|---|
| NOAA ENC | US coastal + Great Lakes | CC0 (explicit dedication) |
| USACE IENC | US inland rivers | US federal work, presumptive public domain — confirm in writing before publishing |
| WSV/ELWIS Inland ENC | German waterways | DL-DE-BY-2.0 (attribution) |
| Rijkswaterstaat Inland ENC | Dutch waterways | CC0 (confirmed on data.overheid.nl) |
| LINZ hydrographic vectors | New Zealand | CC BY 3.0 NZ (shapefile derivative of S-57, needs a not-current disclaimer) |
| GEBCO / EMODnet bathymetry | Global / Europe | CC BY 4.0 (adjacent layer, not ENC) |
| NOAA BlueTopo / S-102 | US coastal | Open (attribution requested) |

**Tier 2 — listed in catalog as source-only, no re-hosted tiles:** France VNF and Belgium/Flanders inland ENCs (free download, redistribution terms unconfirmed), CHS NONNA bathymetry (non-navigational-use license), Norway Kartverket depth data (CC BY 4.0, but ENC itself unconfirmed), Brazil/Argentina free raster charts.

**Tier 3 — excluded:** CHS ENCs, Austria via.donau (explicit no-commercial-use), all PRIMAR/IC-ENC-gated coastal ENCs (Nordics, Croatia, Japan, Korea, Australia, South America), Denmark (perpetual state copyright, actively litigated).

OpenSeaMap/OSM seamark data (ODbL) is Tier 1 by license but is not S-57, so it needs a different bake pipeline than tile57. Deferred; the catalog format supports it whenever a pipeline exists.

Each source lives in `sources/<id>.json`: an `upstream` object with the provider's product catalog URL and, when it offers one, a bulk exchange-set URL, plus license, cadence, and tier. The catalog build only re-hosts tiles for tier 1.

## Pipeline

Pure shell — `bash`, `curl`, `jq`, `yq`, `unzip`, `tile57`, `rclone` — driven by a `Makefile`, run by GitHub Actions on a weekly schedule (NOAA's cadence) plus manual dispatch. Every run does a full rebuild: there is no diff step, no reading of the previously published catalog, and no per-cell edition comparison in the pipeline. A full bake is cheap enough that tracking what changed would cost more complexity than it saves; consumers still detect changes for themselves by comparing `enc:edition`/`enc:update` between fetches.

1. **Fetch** (`scripts/fetch.sh`) — download the source's product catalog (one flat XML document covering every cell) and convert it to JSON with `yq`, then download its exchange set (a single zip containing every cell) and unpack it. Active cells are filtered from the catalog with `jq`; NOAA marks 196 of 7,244 cells `Cancelled` (retired or superseded products), leaving 7,048 Active ones. Every active cell has coverage.
2. **Bake** (`scripts/bake.sh`) — run `tile57 bake` over the whole unpacked exchange set, producing one PMTiles archive per cell, then hash and size every archive.
3. **Catalog** (`scripts/catalog.sh`, `scripts/catalog.jq`) — build `items.json` (a GeoJSON `FeatureCollection` of every active cell), `collection.json`, and the root `catalog.json`, entirely from the fetched product catalog plus whatever archives exist. Tiles are optional here: without a bake, `items.json` still lists every cell and links its upstream ENC zip.
4. **Validate** (`scripts/validate.sh`) — schema-check every source definition and, once built, every catalog document, via `check-jsonschema` (run on demand through `uvx`), plus jq-based invariants a schema can't express (non-empty geometry, every advertised archive actually on disk).
5. **Publish** (`scripts/publish.sh`) — push the built tree to R2 with `rclone`. Archives go first, then each collection's own documents, then the root catalog last, so a reader never sees a document pointing at something not yet there.

`.github/workflows/publish.yml` (named "Publish") runs fetch, bake, catalog, validate, and publish in that order on its weekly schedule and on manual dispatch. `.github/workflows/ci.yml` runs the fixture-based test suite, schema validation, and `shellcheck` on every push and pull request; it never fetches an exchange set, bakes tiles, or touches R2.

## Repo layout

```
Makefile             fetch, bake, catalog, validate, publish, test, clean targets
scripts/             lib.sh, fetch.sh, bake.sh, catalog.sh, catalog.jq, validate.sh, publish.sh
sources/             one JSON definition per provider
schema/              JSON Schema for catalog, collection, items, source definition
tests/               test.sh + fixtures
.github/workflows/   publish.yml (cron + dispatch), ci.yml (tests + schema validation)
docs/                format spec, consumer guide, licensing policy
```

Outputs go to the existing tiles.openwaters.io R2 bucket, which already serves other prefixes (seascape, seamap, fonts). Everything from this repo lives under a `charts/` prefix to stay out of their way: `charts/catalog.json`, `charts/{collection}/collection.json`, `charts/{collection}/items.json`, `charts/{collection}/{CELL}.pmtiles`.

## Licensing policy

Outputs mirror their source license: each collection carries the SPDX id, and the source's attribution text lives alongside it in the source definition. The repo itself is a permissive license (MIT or Apache-2.0). Every published surface carries a not-for-navigation disclaimer. Tier promotions (e.g. VNF from 2 to 1) require a written license confirmation recorded in the source definition.

## Browse UI

The catalog JSON is the API; the UI is a consumer like any app. Where it lives (this repo vs the openwaters.io site) is open — leaning toward the site, keeping this repo data-and-pipeline only. The format already supports what list pages, detail pages, and coverage maps need: geometry, thumbnails can come later as a rendered `tile57 png` asset per item.

## Phases

- [x] **1. Format + NOAA end-to-end:** JSON Schemas, `sources/noaa-enc.json`, `scripts/fetch.sh` against NOAA's product catalog XML and exchange set, `scripts/bake.sh` baking every cell, publish tiles + catalog to tiles.openwaters.io, a cell renders in a MapLibre page from the hosted PMTiles.
- [x] **2. Automation:** `.github/workflows/publish.yml` (weekly cron + manual dispatch) runs the full pipeline end to end; `.github/workflows/ci.yml` runs the test suite, schema validation, and shellcheck on every push and pull request.
- [ ] **3. More tier-1 sources:** USACE IENC (after written license confirmation), WSV, Rijkswaterstaat, LINZ. Each is a new `sources/*.json` plus whatever upstream-catalog handling it needs.
- [ ] **4. Consumers:** lookout-marine first-run chart picker against the catalog; SeaScape/Open Waters Boating adapter; browse UI on openwaters.io.

## Open questions

- Per-cell vs regional bundling: per-cell matches tile57's compositor, but a "download all of Chesapeake Bay" UX may want server-side region manifests (a list of cell ids per named region) — cheap to add as a collection asset later.
- USACE IENC license confirmation: who sends the email.
- MLT vs MVT tile encoding for published archives (tile57 defaults to MLT; MVT is more broadly compatible with third-party clients). tile57 0.3.0's `bake` CLI exposes no encoding flag, so dual-encoding needs a tile57 change first.
