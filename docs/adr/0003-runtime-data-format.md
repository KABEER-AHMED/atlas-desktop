# ADR 0003: Runtime data format — generated JSON with flat coordinate arrays

## Decision

Ship the geography as a single generated JSON file,
`atlas-countries.json`, with ring coordinates stored as flat
`[lon, lat, lon, lat, …]` arrays. Generate it from the pinned source
GeoJSON with `AtlasDataTool`, and commit both the source and the
generated asset.

## Alternatives considered

- **Bundle the source GeoJSON directly.** No conversion step, but 839 KB
  instead of 248 KB, 168 unused property columns per feature to parse at
  launch, and the capital join — which needs a second file and two
  non-obvious filter rules — would have to run on every launch instead of
  once at build time.
- **A binary format (`Data` of packed floats, or Protocol Buffers).**
  Smaller and faster still, but the dataset is 10 364 vertices; decoding
  measures 9 ms as JSON, so the saving would be invisible. It would also
  make the shipped asset unreviewable in a diff and, in the Protocol
  Buffers case, add the project's only third-party dependency.
- **SQLite.** Useful if the app needed partial or indexed loading. It
  loads everything at startup and keeps it in memory, so an embedded
  database would be infrastructure with no job.
- **Nested `[[lon, lat], …]` pairs.** The natural GeoJSON shape, but
  roughly twice the file size and an allocation per coordinate pair
  during decoding.

## Evidence

- Generated asset: 248 KB, 177 countries, 10 364 vertices.
- Decode through `GeographyDecoder`: **9 ms** (release build, measured by
  `AtlasRenderCheck`), off the main actor.
- The conversion is reproducible: `Tools/fetch-source-data.sh` verifies
  three SHA-256 checksums, and `AtlasDataTool` re-decodes what it wrote
  through the app's own decoder and exits non-zero if the result would
  not load.
- `generatedAt` is pinned to the source release rather than the wall
  clock, so regenerating from the same inputs produces identical output.

## Trade-offs

- A build step exists that did not have to. It is run rarely — only when
  the pinned sources change — and it is where the capital join, the
  placeholder normalization and the `ADM0CAP` filter live, which is the
  right place for rules that depend on quirks of a specific release.
- The generated asset is committed, so a change to the tool shows up as a
  diff in a 248 KB JSON file. Acceptable: it also means the exact bytes
  that ship are reviewable, and `sortedKeys` keeps the diff meaningful.
- The format version is checked strictly on load. A newer asset than the
  app understands is a hard error rather than a partial read.

## Trigger to revisit

If the dataset moves to 1:50m or finer (roughly an order of magnitude
more vertices), re-measure the decode time. If it exceeds a frame or two,
move to a packed binary layout — the decoder is already behind
`GeographyRepository`, so nothing above it would change.
