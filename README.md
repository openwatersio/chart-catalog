# chart-catalog

An open-source catalog of freely redistributable ENC (Electronic Navigational Chart) data, published as pre-baked vector tiles and a machine-readable index of source coverage, licensing, and update state.

The published catalog lives at [https://tiles.openwaters.io/charts/catalog.json](https://tiles.openwaters.io/charts/catalog.json).

## Who this is for

Chart plotter apps that want ready-to-render vector tiles without touching raw ENC data: fetch the catalog, pick a collection, fetch its `items.json` for every chart cell's coverage and metadata in one request, download the PMTiles archives you need, and render with MapLibre via the pmtiles protocol.

Apps that want to process raw ENCs themselves: each collection's `ow:source` field points at the upstream provider's own catalog endpoints, and each item's `enc` asset links directly to the upstream ENC zip, so you can bypass our tiles entirely and still get the coverage and licensing metadata for free.

This repo does not ship a map renderer or a chart plotter. It ships data and the pipeline that produces it.

## Not for navigation

Charts published here are not a substitute for official, up-to-date navigational products. Always cross-check with current government charts and Notices to Mariners before using any data from this catalog for actual navigation.

## Documentation

- [docs/format.md](docs/format.md) — the catalog format: root catalog, collections, items, fields, asset roles.
- [docs/licensing.md](docs/licensing.md) — licensing policy, source tiers, and the current tier-1/2/3 source lists.
- [docs/consumers.md](docs/consumers.md) — a guide for app developers consuming the catalog.

## Local development

The pipeline is plain shell — `bash`, `curl`, `jq`, [`yq`](https://github.com/mikefarah/yq), and `unzip` — driven by a `Makefile`. Baking needs the [tile57](https://github.com/beetlebugorg/tile57) CLI, publishing needs `rclone` with R2 credentials for the `tiles.openwaters.io` bucket, and validation needs `uvx`, which runs `check-jsonschema` on demand.

Every one of those is pinned in `mise.toml`, so the whole toolchain is one command:

```sh
mise install
```

Homebrew users can run `brew bundle` against the `Brewfile` instead. Installing by hand works too, with one caveat: `yq` must be the mikefarah Go implementation, since the fetch step reads NOAA's product catalog through its XML support. A same-named Python tool packaged by some distributions will not work.

Build the catalog for one source (`SOURCE=noaa-enc` by default):

```sh
make
```

Individual stages:

```sh
make fetch      # download the product catalog and exchange set
make bake       # bake every cell to PMTiles
make catalog    # build catalog.json, collection.json, and items.json
make validate   # schema-check source definitions and, if built, the catalog tree
make publish    # push the built catalog to R2
make test       # run the fixture-based test suite
make clean      # remove work/ and out/
```

`catalog`, `validate`, and `publish` don't depend on `bake`: run `make bake` first if you want items to carry a `pmtiles` asset, otherwise the catalog still lists every chart cell with a link to its upstream ENC zip.

## Contributing a new source

Add a `sources/<id>.json` file conforming to `schema/source.schema.json`: provider info, an SPDX license identifier and URL, the format (`s57`, `s101`, `ienc`, `shapefile`, or `raster`), update cadence, and an `upstream` object with the provider's machine-readable product catalog URL and, when the provider offers one, a bulk exchange-set URL apps can use to self-process the raw data.

Every source gets a `tier`:

- **Tier 1** — redistributable. We pre-bake and host PMTiles for it.
- **Tier 2** — listed in the catalog with its source definition, but we don't re-host tiles because redistribution terms aren't confirmed.
- **Tier 3** — excluded from the catalog entirely.

Tier 1 requires evidence that redistribution is permitted: a published open license, an explicit public domain dedication, or a statutory basis such as 17 U.S.C. §105 for US federal works. Where a provider's terms are silent or ambiguous, get written confirmation and record it in the source definition. See [docs/licensing.md](docs/licensing.md) for the current source lists and the caveats attached to each.

## License

The code and catalog format in this repository are MIT licensed; see [LICENSE](LICENSE). The chart data itself is not ours to relicense: every collection carries its source's own license (SPDX id and URL), and published tiles mirror that license rather than the repo's.
