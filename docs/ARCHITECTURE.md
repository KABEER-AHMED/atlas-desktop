# Architecture

Atlas Desktop is a local-first native macOS app with no third-party code
dependencies. Product state and geographic correctness are kept
independent of the renderer, so the globe's behaviour can be reasoned
about and tested without a window on screen.

## Modules

Five Swift targets, plus two development tools.

| Target | Responsibility | Depends on |
|---|---|---|
| `AtlasDesktopCore` | Domain: coordinates, geometry, countries, camera, solar position, preferences, session state | Foundation only |
| `AtlasGeographyData` | The bundled vector dataset, its decoder, and the repository that loads it | Core |
| `AtlasGlobeRendering` | SceneKit scene, textures, border geometry, labels, input mapping, surface imagery | Core |
| `AtlasDesktopApp` | SwiftUI/AppKit shell: window, panel, menus, settings, menu-bar item, presentation mode | Core, Data, Rendering |
| `AtlasDataTool` | Development tool: source GeoJSON and imagery → runtime assets | Core, Data |
| `AtlasRenderCheck` | Development tool: offscreen render smoke check | Core, Data, Rendering |

`AtlasDesktopCore` imports no AppKit and no SceneKit. That is what lets
the domain tests — 75 of them — run without a display.

The renderer depends on the domain but not on the data module: the
geography repository hands it validated domain objects. Surface imagery
is a *rendering* resource and lives with the renderer; vector data and
facts live with the data module.

## Key types

- **`GeographyRepository`** — loads and validates the bundled dataset;
  reports `GeographyError` with a description, a reason and a recovery
  suggestion. `StaticGeographyRepository` injects fixtures and
  deliberate failures in tests.
- **`CountryLookup`** — maps a coordinate to a country. A flat scan with
  a bounding-box prefilter over 177 countries; where geometries overlap,
  the **smaller country wins**, so enclaves stay selectable.
- **`CameraState`** — the globe's orientation and the camera's distance,
  with all bounds enforced in the type. A value, not an object.
- **`GlobeSession`** — `@MainActor @Observable` product state: what is
  loaded, what is selected, where the camera points, which preferences
  are in force. Owns no GPU resources and parses no datasets.
- **`GlobeSceneController`** — owns the SceneKit node graph. Holds no
  product state; everything it draws is pushed in through `apply(...)`.
- **`PresentationModeController`** — isolates every window-level and
  collection-behaviour decision in one file.
- **`PreferencesStore`** — a protocol with a `UserDefaults` implementation
  and an in-memory one, so tests never touch real user defaults.

## Coordinate and rendering conventions

A single projection, `SphereProjection`, is the only lat/lon-to-3D
conversion in the project. Selection reuses its exact inverse, so a click
travels back through the same transform chain the geometry was built
with.

- Right-handed coordinate system; **+Y is the north pole**.
- **Longitude 0 at the equator points toward +Z** — toward the camera,
  which sits on +Z looking at the origin.
- **Longitude increases eastward, rotating +Z toward +X**, so east
  appears on the **right** of the screen.

That last point is the one worth stating explicitly: sending east toward
+Z instead produces a globe that passes every round-trip test and renders
mirrored. `SphereProjectionTests.eastRunsTowardPositiveX` exists to catch
exactly that, and it caught it once already.

Rotation lives on the globe, not the camera: the camera stays at +Z with
+Y up and never rolls. `CameraState`'s two angles are directly meaningful
— `yawDegrees` is the longitude at the centre of the view and
`pitchDegrees` is the latitude — and because longitude 0 sits on +Z, the
model rotation about Y is `-yaw`. That sign lives in exactly one place,
`CameraState.modelEulerAngles`, used by both the renderer and hit-testing.

Pitch is clamped to ±85° so the view never passes vertical. Distance is
clamped to 1.35–6.0 globe radii.

### Layer stack

Radii come from `GlobeTheme` so nothing z-fights at the zoom limits:

| Layer | Radius | Notes |
|---|---|---|
| Surface | 1.0 | Blue Marble imagery, lambert-lit |
| Selection tint | 1.0015 | Overlay texture, one country |
| Borders | 1.003 | Line geometry, constant lighting, depth-tested |
| Selected border | 1.0042 | Brighter outline for the selection |
| Selection marker | 1.006 | Billboarded ring — a non-colour selection cue |
| Labels | 1.02 | Billboarded planes |
| Atmosphere | 1.09 | Additive billboard, no depth interaction |

Borders read from the depth buffer but do not write to it, so the sphere
occludes the far side's lines while the near side's stay crisp.

### Antimeridian and poles

Natural Earth already splits its polygons at ±180, but every outline is
passed through `Antimeridian.split` before it becomes geometry anyway: a
single ring containing both +179.9 and −179.9 would otherwise be drawn as
a line straight across the globe. Antarctica's main polygon closes across
the pole, running along latitude −90 from longitude 180 to −180; the
even-odd point-in-polygon test handles it without a special case, and a
test pins that.

### Fill without triangulation

Land fill and the selection highlight come from an **equirectangular
raster** of the country polygons rather than from triangulated meshes.
Scanline even-odd filling across a polygon's outer ring and its holes in
one intersection list makes holes come out as holes with no special case,
and it avoids an ear-clipping implementation entirely. Countries are
rasterized largest-first so smaller ones land on top — the same rule
`CountryLookup` applies, so what is drawn and what is clicked agree.
`AtlasRenderCheck` asserts that agreement on real coordinates.

Hit-testing does *not* use the raster: a click runs exact
point-in-polygon arithmetic through `CountryLookup`, which is both more
accurate and independent of raster resolution.

### Labels

A deterministic greedy pass, not an optimiser. Candidates are sorted by
relative size, and a label is kept when it is front-facing, fully on
screen, large enough at the current zoom, and not overlapping a label
already kept. Equal priorities break by identifier, so the same camera
always yields the same labels and nothing flickers. The selected
country's label is exempt from the size threshold but never from
occlusion.

Layout is skipped entirely when the camera has barely moved, so a static
globe does no label work at all.

### Day and night

There is no terminator geometry. A directional light is pointed along the
real subsolar direction, so the terminator is simply where the lambertian
falloff lands. `SolarPosition` uses the low-precision algorithm from the
Astronomical Almanac — about 0.01° in declination — and says so in its
documentation rather than implying an ephemeris.

## State and concurrency

- UI state is main-actor isolated: `GlobeSession`, `GlobeSceneController`
  and `GlobeInteractionView` are all `@MainActor`.
- Dataset decoding runs in a detached task.
- Rasterizing the dataset and building the land texture — the one
  genuinely expensive startup step — runs in a detached task, as does
  rebuilding the selection overlay when the selection changes, so
  selecting a country never costs a dropped frame.
- Prepared geometry is immutable after loading.
- Only durable preferences are persisted; no pointer deltas, no GPU
  resources.

## Frame pacing and idle behaviour

Rendering is driven by a `CADisplayLink`, so frames land on the display's
refresh rather than on a timer. The link runs only while something is
actually moving: auto-rotation, a drag, or a short burst of frames after
a one-off change such as a new selection. Otherwise it is invalidated and
`rendersContinuously` is off.

It is also stopped when the window is occluded, miniaturized, hidden, or
off screen — observed through `NSWindow.didChangeOcclusionState` and the
application hide notifications rather than polled. There is no
unconditional busy loop anywhere in the app.

## Desktop presentation

macOS has no public API that makes a third-party app the wallpaper, and
this app will not use private APIs, injection, Accessibility automation
or screen recording to imitate one. `PresentationModeController` uses a
borderless window one level below `CGWindowLevelForKey(.desktopIconWindow)`,
joining all Spaces, excluded from cycling, one per display. Desktop icons
stay clickable because they are above it; the globe stays interactive
because the window does accept mouse events. It never becomes main and is
never activated on entry, so it cannot steal focus, and the normal window
is always available.

## Performance strategy

Measure before optimizing. The deliberate choices so far are: preprocess
static geometry once, put all borders in a single draw call rather than
177, skip label layout when the camera is static, and stop rendering when
nothing is visible or moving. A spatial index for hit-testing was
*rejected* as premature — 177 bounding boxes is not a bottleneck.

Measured results and the targets they are measured against are in
[TESTING.md](TESTING.md).

## Decision records

- [0002 — Renderer choice: SceneKit](adr/0002-renderer-choice.md)
- [0003 — Runtime data format](adr/0003-runtime-data-format.md)
- [0004 — Surface imagery](adr/0004-surface-imagery.md)
- [0005 — Desktop presentation mode](adr/0005-desktop-presentation.md)
