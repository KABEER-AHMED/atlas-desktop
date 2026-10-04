# Geographic Data, Provenance, and Licensing

## Requirements

The globe's essential geometry and metadata must be bundled or installed through a deterministic documented local step. Rendering and country selection must work offline. Every distributed asset must have an identified source, version, license, and attribution treatment.

## Candidate source: Natural Earth

Natural Earth is the first candidate for country boundaries because it offers geographic datasets at multiple scales and is commonly distributed as public-domain data. Before implementation, verify the exact official source page, release, scale, archive, and license statement. Do not infer provenance from a filename.

- **Dataset:** implementation agent must pin the exact asset.
- **Release/version:** record the selected release.
- **Scale/resolution:** choose a scale that gives acceptable country borders at ordinary globe zoom.
- **Official source URL:** record the exact download/source URL.
- **License/public-domain statement:** verify against the source and retain the relevant notice/reference.
- **Download date:** record the actual date.
- **Modifications:** document reprojection, filtering, simplification, triangulation, and format conversion.
- **Attribution:** include source credit here and in the app credits/about surface where appropriate.

These fields must be completed using the actual asset before shipping; do not invent specific versions or licensing facts.

## Country facts and metadata

Country names, capital cities, continent/region, and ISO identifiers may come from a source separate from geometry. Audit them independently.

- Pin source, version, license, attribution, and retrieval date.
- Record the join key and behavior for unmatched records.
- Use ISO 3166-1 identifiers where available; document source-specific exceptions and treatment of dependent/disputed territories.
- Missing capitals must remain missing. Do not infer them from nearby cities or other records.
- Normalize text encoding consistently and preserve a stable display-name source.
- Distinguish source fields from derived fields.

## Reproducible pipeline

1. Obtain source assets during development, not at runtime.
2. Commit only source files that may legally be redistributed; otherwise document deterministic retrieval and verification steps.
3. Validate archive integrity and required source fields.
4. Convert source data into the runtime format using a documented script or command.
5. Run geometry validation and metadata join checks.
6. Emit compact runtime assets and a machine-readable summary where practical.
7. Verify a clean build packages assets and the app works with networking disabled.
8. Record generation steps and non-default parameters.

## Geometry edge cases

Tests must cover polygon ring closure, holes, multipolygons, antimeridian crossings, malformed or degenerate geometry, coordinate bounds, small island states, high-latitude regions, and identifiers missing from either side of a metadata join. Simplification must not produce obvious distortion at ordinary zoom.

## Dependency and license audit

For every third-party library and bundled data source, record name/version, purpose, maintenance status, license, required notices, redistribution terms, and any obligations for derived assets. Prefer system frameworks and a small dependency surface. Do not copy map tiles, textures, fonts, icons, or datasets from unclear sources.

## Release checklist

- [ ] Exact geometry source/version recorded.
- [ ] Exact metadata source/version recorded.
- [ ] License and attribution verified against primary sources.
- [ ] Required notices included in repository/app.
- [ ] Data conversion is reproducible and documented.
- [ ] Core geography has no runtime network dependency.
- [ ] Offline startup and representative country selection tested.
