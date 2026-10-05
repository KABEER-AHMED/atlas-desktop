# Geographic Data, Provenance, and Licensing

Everything the globe draws is bundled with the app. Nothing is fetched at
runtime, and the app works with networking disabled.

There are two kinds of asset, and they are kept separate on purpose:

- **Geographic data** — boundaries, names, capitals, identifiers. Every
  fact the UI states comes from here.
- **Surface imagery** — a photograph-derived texture. Nothing is measured
  from it and no fact comes from it; it is a rendering asset.

## Pinned sources

### Boundaries — Natural Earth, Admin 0 Countries, 1:110m

| | |
|---|---|
| Dataset | `ne_110m_admin_0_countries.geojson` |
| Release | `natural-earth-vector` v5.1.2 |
| Scale | 1:110 000 000 |
| Source URL | https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/geojson/ne_110m_admin_0_countries.geojson |
| Licence | Public domain (Natural Earth terms of use) |
| SHA-256 | `6866c877d39cba9c357620878839b336d569f8c662d3cfab4cb1dbe2d39c977f` |
| Retrieved | 2026-10-05 |
| Features | 177 |

### Names and capitals — Natural Earth, Populated Places, 1:110m

| | |
|---|---|
| Dataset | `ne_110m_populated_places.geojson` |
| Release | `natural-earth-vector` v5.1.2 |
| Source URL | https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/geojson/ne_110m_populated_places.geojson |
| Licence | Public domain (Natural Earth terms of use) |
| SHA-256 | `a86028b083182b68c7620fc6e1a8a47ee547cb9cd2fb62ccbb78bea786440899` |
| Retrieved | 2026-10-05 |

Country names, long names, continent, region, subregion and ISO codes
come from the countries file; capitals come from the places file.

### Surface imagery — NASA Blue Marble: Next Generation

| | |
|---|---|
| Dataset | `world.topo.bathy.200412.3x5400x2700.jpg` (December 2004, topography and bathymetry) |
| Source URL | https://visibleearth.nasa.gov/images/73909/december-blue-marble-next-generation-w-topography-and-bathymetry |
| Licence | Public domain under NASA's media usage guidelines; credit requested |
| Credit | NASA Earth Observatory, *Blue Marble: Next Generation*, by Reto Stöckli |
| SHA-256 | `a9f0088972dee0254610af851c4d6838ca3f2cf79176987e0a5713e2c15ec042` |
| Retrieved | 2026-10-05 |

NASA asks that its imagery be credited rather than implying endorsement.
The credit appears in Settings ▸ Data & Credits and in the app bundle's
copyright string. December was chosen because its single composite shows
both hemispheres in plausible seasonal cover; the app does not change
imagery with the date and does not claim to show current conditions.

## Reproducing the bundled assets

```bash
Tools/fetch-source-data.sh   # downloads Data/source, verifies every SHA-256
swift run AtlasDataTool      # regenerates both runtime assets, then verifies them
```

The fetch script fails loudly on a checksum mismatch rather than carrying
on with different data. `AtlasDataTool` re-decodes what it wrote through
the app's own decoder and exits non-zero if the result would not load,
so a broken asset cannot be committed silently.

Outputs:

| Path | Contents | Size |
|---|---|---|
| `Sources/AtlasGeographyData/Resources/atlas-countries.json` | 177 countries, 10 364 vertices, facts, provenance | 248 KB |
| `Sources/AtlasGlobeRendering/Resources/atlas-earth.jpg` | 4096×2048 surface imagery | 2.1 MB |

Source files live in `Data/source/` and are kept separate from these
generated runtime assets. The 2.5 MB source image is committed alongside
the vector data; all three are public domain and redistributable.

### Why these sizes

The runtime JSON stores ring coordinates as a flat `[lon, lat, lon, …]`
array with no repeated closing vertex, which roughly halves the file
against nested pairs and decodes in one pass. The imagery is downsampled
from 5400×2700 to 4096×2048 — 32 MB of video memory instead of 58 MB,
and still finer than the globe's on-screen size at the closest zoom.

### Transformations applied

1. Selected `ADM0_A3`, `NAME`, `NAME_LONG`, `ISO_A2_EH`/`ISO_A2`,
   `ISO_A3_EH`/`ISO_A3`, `CONTINENT`, `REGION_UN`, `SUBREGION`,
   `LABEL_X`, `LABEL_Y`.
2. Joined Admin-0 capitals on `ADM0_A3` where `FEATURECLA` is
   `Admin-0 capital` **and** `ADM0CAP = 1`.
3. Where that join found nothing, retried on the place record's
   `ADM0NAME` against the country's `ADMIN` name.
4. Flattened `Polygon`/`MultiPolygon` rings to interleaved `[lon, lat]`
   arrays and dropped the repeated closing vertex.
5. Dropped rings with fewer than three distinct points.
6. Normalized `-99` and empty-string placeholders to absent values.
7. Downsampled the surface imagery and re-encoded it as JPEG. No colour
   change, no reprojection.

No simplification, reprojection or coordinate rounding is applied to the
geometry: what ships is Natural Earth's own 1:110m vertices.

## Identifiers

`ADM0_A3` is the primary key, not `ISO_A3`. Natural Earth sets `ISO_A3`
to `-99` for several features — including France and Norway — while
`ADM0_A3` is present for all 177. `ISO_A3_EH`/`ISO_A2_EH` are Natural
Earth's corrected ISO columns and are preferred where they carry a code.

The app displays a real ISO code when the dataset has one, and otherwise
shows the dataset's own key labelled *no ISO code assigned*.

## Known gaps in the data

These are properties of the source, verified against it, and the app
surfaces them rather than filling them in.

**No capital in the dataset (9):** Antarctica, Falkland Is., Fr. S.
Antarctic Lands, Greenland, N. Cyprus, New Caledonia, Palestine, Puerto
Rico, W. Sahara.

**No assigned ISO code (3):** Kosovo, Somaliland, N. Cyprus.

**One repaired key:** Natural Earth v5.1.2 keys South Sudan's country
feature as `SDS` but Juba's place record as `SSD` with `ADM0CAP = 0`, so
the primary join misses a capital the dataset does contain. The name
fallback in step 3 above repairs exactly this case. `AtlasDataTool`
reports every use of that fallback — currently one — so it stays
auditable.

**Multiple capitals are real.** South Africa has three (Bloemfontein,
Cape Town, Pretoria) and Bolivia two (La Paz, Sucre). The `ADM0CAP`
filter exists because the feature class alone also matches Johannesburg,
which is not a capital.

## Scale limitations

At 1:110m, coastlines are simplified by tens of kilometres. A point on a
coast can therefore fall on the wrong side of a border: McMurdo Station
and Davis Station both sit marginally outside Antarctica's polygon, for
instance. This is the dataset's resolution, not a defect in the lookup —
`BundledGeographyTests` pins the behaviour with interior points and
documents the coastal cases.

Disputed and dependent territories follow Natural Earth's own treatment.
The app takes no position of its own and renames nothing.

## Geometry edge cases covered by tests

Ring closure and degenerate rings, holes (Lesotho inside South Africa),
multipolygons (Indonesia, Japan), antimeridian crossings (Fiji, Russia,
New Zealand), the pole-closing polygon (Antarctica, whose main ring runs
along latitude −90 from longitude 180 to −180), out-of-range coordinates,
truncated coordinate arrays, missing capitals, missing ISO codes, and
failed metadata joins. See `Tests/AtlasGeographyDataTests`.

## Dependency audit

The app has **no third-party code dependencies**. Everything outside the
Swift standard library is an Apple system framework: SwiftUI, AppKit,
SceneKit, Metal, Foundation, Observation, `os.log`, and the testing
library. The only third-party material is the data above, all public
domain.

The star field behind the globe is generated procedurally from a seeded
generator rather than taken from a star catalogue, so there is no further
dataset to license and nothing claims to show real constellations.

## Release checklist

- [x] Exact geometry source, release and checksum recorded.
- [x] Exact metadata source, release and checksum recorded.
- [x] Exact imagery source, release and checksum recorded.
- [x] Licences verified against the primary sources.
- [x] Required credits present in the app and in this repository.
- [x] Data conversion reproducible from a clean checkout and verified by
      the tool that performs it.
- [x] No runtime network dependency for any feature.
- [x] Offline load and representative country selection covered by tests.
