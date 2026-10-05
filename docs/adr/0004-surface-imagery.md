# ADR 0004: Surface imagery — NASA Blue Marble, downsampled at build time

## Decision

Draw the globe's surface with NASA's *Blue Marble: Next Generation*
composite (December 2004, topography and bathymetry), downsampled from
5400×2700 to 4096×2048 by `AtlasDataTool` and bundled as a 2.1 MB JPEG.
Keep the generated land/ocean texture as a fallback for when the imagery
is unavailable.

## Context

The first working build drew flat ocean and land colours from the
country raster, with vector borders on top. It was geographically correct
and looked like a wireframe outline map rather than the Earth. The
product direction asked for the look of a real globe.

This is a deliberate departure from the PRD's non-goals, which list
"satellite imagery" and "photorealistic terrain" as out of scope for V1,
and from AGENTS.md's instruction to defer photorealistic textures. The
change was made on an explicit instruction from the project owner, and it
is recorded here rather than left as an unexplained contradiction.

## Alternatives considered

- **Natural Earth raster (`HYP_50M_SR_W`, `NE2_50M_SR_W`).** The obvious
  match for data already sourced from Natural Earth, and public domain.
  Rejected on practicality: the archives are 102 MB and 89 MB and
  downloaded at well under 1 MB/s from the S3 mirror, which makes the
  documented fetch step unreasonable for anyone reproducing the build.
  The cartographic hypsometric look is also further from the satellite
  appearance that was asked for.
- **Procedural colouring from latitude and biome bands.** No download at
  all, but it would mean *inventing* terrain — the one thing the data
  rules forbid. Rejected outright.
- **Bundling the 5400×2700 source directly.** No conversion step, but
  58 MB of video memory instead of 32 MB, against a 300 MB total budget
  that already measures 250 MB.
- **Downloading imagery at runtime.** Forbidden: core features must work
  offline with no network access.

## Evidence

- Source: 2.5 MB, public domain under NASA's media usage guidelines,
  checksum pinned in `Tools/fetch-source-data.sh`.
- Generated texture: 2.1 MB in the bundle, decodes in **5 ms**.
- Measured resident memory after the change: 250 MB, inside the 300 MB
  target.
- Verified by screenshot that borders align with the imagery's coastlines
  at high zoom.

## Trade-offs

- The app bundle grows by 2.1 MB.
- Memory sits closer to its budget. The texture is the first thing to
  reduce if that becomes a problem; 2048×1024 would quarter it.
- The imagery is a single December composite. It does not change with the
  date and shows December's snow and vegetation year-round. The app does
  not claim otherwise, and does not pretend to show current conditions.
- NASA asks for credit. The credit appears in Settings ▸ Data & Credits
  and in the bundle's copyright string.

## Boundary this does not cross

The imagery is a **rendering asset**. No fact the app states comes from
it: borders, names, capitals and identifiers all come from Natural Earth
vector data, and selection is point-in-polygon arithmetic on that vector
data, never a lookup against pixels. That is why the imagery lives in the
renderer's resources rather than in the geography module.

## Trigger to revisit

If the memory budget tightens, or if a comparable public-domain
cartographic raster becomes practical to fetch, re-evaluate. The loader
is a single call behind `EarthImagery`, and the fallback path is already
implemented and exercised.
