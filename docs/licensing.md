# Licensing policy

## Not for navigation

Every published surface, including every collection and item in the catalog, every rendered style, and any browse UI built on top of this data, carries a not-for-navigation disclaimer. This data is not a substitute for official, up-to-date navigational products; always cross-check with current government charts and Notices to Mariners.

## Outputs mirror source licenses

The chart-catalog repository's code is MIT licensed (see [LICENSE](../LICENSE)), but that license does not extend to the chart data itself. Each collection carries the SPDX identifier of its source's license, and the source's attribution text is recorded alongside it in `sources/<id>.json`, so downstream consumers can see and honor the actual license for the data they're using rather than assuming the repo's own license applies.

## Tiers

Every entry in `sources/` is assigned a tier, which determines whether we re-host tiles for it:

- **Tier 1 — redistributable, pre-baked.** The license is confirmed to permit redistribution. The pipeline downloads the raw data, bakes PMTiles, and publishes them alongside the source's collection document.
- **Tier 2 — listed, source-only.** The source has a collection document with coverage, cadence, and upstream fetch endpoints, but no re-hosted tiles, because redistribution terms aren't confirmed. Apps can still self-process from the upstream catalogs.
- **Tier 3 — excluded.** The source has a `sources/*.json` definition for reference, but no collection is published and nothing is fetched by the pipeline.

Tier 1 requires evidence that redistribution is permitted: a published open license, an explicit public domain dedication, or a statutory basis such as 17 U.S.C. §105 for works of the US federal government. Where the provider's terms are silent or ambiguous, that evidence means written confirmation from the provider, recorded in the source's `sources/<id>.json` definition before the catalog build treats the source as tier 1.

## License identifiers

Every source records an SPDX identifier in `license.spdx`, and each collection carries it through to the published catalog.

SPDX has no generic identifier for the public domain, on the reasoning that public domain is a legal status rather than a license, and one that varies by jurisdiction. Its identifiers name specific instruments instead: `CC0-1.0` for a rights holder dedicating a work, and one identifier per agency notice for the agencies that have published one, such as `NIST-PD`.

For works that are in the public domain by operation of law rather than by anyone's dedication, this catalog uses `CC-PDM-1.0`, the Creative Commons Public Domain Mark, which labels a work already in the public domain instead of claiming a dedication the agency never made. US federal works under 17 U.S.C. §105 take this identifier, with `license.url` pointing at the agency's own terms page.

## Current sources

The licensing research behind this list landed on a hard pattern: nearly all coastal ENCs worldwide flow through the commercial RENC system (PRIMAR/IC-ENC, S-63 encrypted), so freely redistributable sources are the exception, not the rule. The open exceptions are the US, New Zealand's derivative products, and a handful of European inland waterway authorities.

### Tier 1: redistributable, pre-baked

| Source | Coverage | License |
|---|---|---|
| NOAA ENC | US coastal + Great Lakes | CC0 (explicit dedication) |
| USACE IENC | US inland rivers | `CC-PDM-1.0`, public domain as a US federal work (17 U.S.C. §105) |
| WSV/ELWIS Inland ENC | German waterways | DL-DE-BY-2.0 (attribution) |
| Rijkswaterstaat Inland ENC | Dutch waterways | CC0 (confirmed on data.overheid.nl) |
| LINZ hydrographic vectors | New Zealand | CC BY 3.0 NZ (shapefile derivative of S-57, needs a not-current disclaimer) |
| GEBCO / EMODnet bathymetry | Global / Europe | CC BY 4.0 (adjacent layer, not ENC) |
| NOAA BlueTopo / S-102 | US coastal | Open (attribution requested) |

LINZ's shapefile derivative of S-57 is not guaranteed current with the latest Notices to Mariners, so any consumer-facing surface using it needs an explicit not-current disclaimer in addition to the standard not-for-navigation one.

### Tier 2: listed as source-only

- France VNF and Belgium/Flanders inland ENCs — free to download, but redistribution terms are unconfirmed.
- CHS NONNA bathymetry — licensed for non-navigational use only.
- Norway Kartverket depth data — CC BY 4.0, but the ENC itself is unconfirmed.
- Brazil/Argentina free raster charts.

### Tier 3: excluded

- CHS ENCs.
- Austria via.donau — explicit no-commercial-use terms.
- All PRIMAR/IC-ENC-gated coastal ENCs: the Nordics, Croatia, Japan, Korea, Australia, South America.
- Denmark — perpetual state copyright, and the subject of active litigation.

The RENC (Regional ENC Coordinating Center) system is the reason most national coastal ENCs are tier 3: PRIMAR and IC-ENC distribute S-63 encrypted charts on behalf of member hydrographic offices under commercial terms, which is incompatible with open redistribution regardless of the underlying data's public-sector origin.

### OpenSeaMap / OSM seamark data

Licensed ODbL, which would make it tier 1, but it's OSM data, not S-57, so it needs a different bake pipeline than tile57 produces. It's deferred rather than tier-3-excluded; the catalog format already supports adding it once a pipeline exists.
