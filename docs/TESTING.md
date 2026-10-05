# Testing and Verification

Tests are deterministic, local, and offline. No test needs an API key, an
account, a network connection, or a display.

## Running them

```bash
swift test                   # 138 tests, three suites
swift run AtlasRenderCheck   # offscreen rendering smoke check (needs a GPU)
```

On a machine with only the Command Line Tools, add
`$(Tools/toolchain-flags.sh)` — see the README.

## What is covered

### `AtlasDesktopCoreTests` — 75 tests

| Area | Covers |
|---|---|
| `Coordinate` | Range validation, NaN and infinity rejection, longitude normalization |
| `CountryID` | Alpha-2 and alpha-3 codes, normalization, rejection of malformed codes |
| `SphereProjection` | Pole and prime-meridian placement, **east-is-right orientation**, round trip through the inverse, ray/sphere intersection including grazing and missing rays |
| `CameraState` | Yaw/pitch as the centre coordinate, transform round trip, pitch and distance clamping, yaw wrapping, **drag direction on both axes**, distance-scaled drag, zoom bounds, rejection of non-finite input, auto-rotation stepping, `Codable` round trip |
| Geometry | Ring closure, degenerate rings, even-odd containment, bounding boxes, winding-independent area, holes, multipolygons, largest-polygon selection |
| `Antimeridian` | Splitting, crossing detection, runs too short to draw |
| `SolarPosition` | Solstice and equinox declinations, subsolar longitude at noon UTC, rotation rate over six hours, unit direction vector, determinism |
| `Preferences` | Defaults, JSON round trip, clamping of out-of-range and non-finite values, re-applied camera bounds, rejection of a newer version, `UserDefaults` round trip and recovery from a corrupt payload |
| `GlobeSession` | Load success and failure, selection, smaller-country-wins, clearing on open ocean, the full learning-mode flow, interaction pausing rotation, Reduce Motion suppression, reset, focus, immediate persistence, camera restoration |

### `AtlasGeographyDataTests` — 34 tests

Decoder tests use hand-built payloads so malformed input can be
exercised deliberately: unsupported format version, empty dataset,
garbage, invalid identifier, odd coordinate counts, out-of-range
coordinates, degenerate rings, missing geometry, placeholder
normalization, label-anchor fallback, and that every error carries a
description and a recovery suggestion.

Integration tests run against the asset that actually ships: all 177
countries load; identifiers are unique; France has the ISO code Natural
Earth's `ISO_A3` column omits; South Africa has exactly its three real
capitals and not Johannesburg; Bolivia has both; South Sudan gets Juba
through the documented name fallback; the nine territories with no
capital have none and the three with no ISO code are marked as such;
Fiji, Russia and New Zealand decode and split at the antimeridian;
Indonesia and Japan keep all their parts; Lesotho is selectable inside
South Africa; nine real cities resolve to their countries; open ocean
resolves to nothing; Antarctica's pole-closing polygon resolves from
interior points; and every label anchor for a country of any size falls
inside its own geometry.

### `AtlasGlobeRenderingTests` — 29 tests

Rasterization (fill, holes, smaller-countries-on-top, sub-cell
countries, pixel mapping), texture generation (dimensions, selection
overlay only for a country that is present, **star-field determinism**,
atmosphere gradient transparent at the centre and at the quad's edge),
label layout (collision rejection, far-side rejection, viewport clipping,
size threshold, the selected country's exemption from the threshold but
not from occlusion, the label budget, determinism for equal priorities),
and border geometry (subdivision of long segments, meridian convergence,
interpolated points staying on the path, line primitive construction).

### `AtlasRenderCheck`

Builds the real scene offscreen with `SCNRenderer` and writes five PNGs
(home view, a selection, a zoomed view, learning mode, day/night off).
It fails if the data does not load, if the surface imagery is missing,
if the raster and the selection lookup disagree at real coordinates, or
if a render comes out blank.

This is what catches a globe that is black, mirrored, or drawing land
where there is ocean — none of which a unit test can see.

## Results

**Environment:** MacBook Pro, Apple M-series, macOS 26 (build 26A428),
Swift 6.4 (Command Line Tools) with Xcode 16 macro plugins, debug
configuration unless stated.

| Command | Result |
|---|---|
| `swift test` | **138 passed, 0 failed** |
| `swift run AtlasRenderCheck` | **passed**; all five renders produced, raster and lookup agreed at all five probes |
| `Tools/fetch-source-data.sh` | **passed**; all three sources matched their pinned SHA-256 |
| `swift run AtlasDataTool` | **passed**; regenerated both assets and verified them through the app's decoder |
| `Tools/make-app-bundle.sh release` | **passed** |

### Measured performance

Measured with the release build of `AtlasRenderCheck` and `ps`/`top` on
the running app.

| Target | Measured | Status |
|---|---|---|
| Warm startup under 2 s | Data load 9 ms, rasterize + land texture 7 ms, imagery decode 5 ms — about 21 ms of work between launch and a drawable globe, before window setup | Met with room to spare |
| Resident memory under 300 MB | 250 MB RSS shortly after launch (`ps`); 151 MB private (`top`) | Met, but not by much |
| Negligible idle CPU | 0.0–0.2% sustained while the window was not visible, sampled every 2 s for 16 s | Met |
| Stable 60 FPS while interacting | **Not measured** | See below |
| Input-to-visible response under 50 ms | **Not measured** | See below |

The memory figure is dominated by the 4096×2048 surface texture (32 MB
as GPU data, more once mipmapped) plus the 2048×1024 index map and its
derived textures. It sits inside the budget but is the first thing to
look at if that budget tightens.

The idle-CPU figure was taken while the display was asleep, which is
exactly the condition the lifecycle logic is meant to handle: the display
link is invalidated and `rendersContinuously` is off, so nothing renders.
It confirms the suspension path works, but it is **not** a measurement of
a visible, paused globe.

### Not measured

- **Frame rate and frame pacing.** Needs Instruments. Xcode is present on
  the development machine but its licence has not been accepted, so no
  profiling run was made. Nothing in this repository claims a frame rate.
- **Input-to-visible latency.** Same reason.
- **Energy and thermal behaviour.** Not measured; no claim is made.
- **Cold startup.** Only warm starts were timed.

## Manual verification

### Done

| Scenario | Result |
|---|---|
| App launches to a working globe | Verified by screenshot: globe, borders, labels, facts panel, controls all present |
| Country borders align with the imagery | Verified by screenshot at high zoom — coastlines, Lake Victoria and Lake Tanganyika all line up |
| Orientation | Verified: east is to the right, north is up. An earlier build rendered mirrored; `SphereProjectionTests.eastRunsTowardPositiveX` now guards it |
| Selection highlight | Verified in `AtlasRenderCheck` output: tint, brighter outline and ring marker on the selected country |
| Day/night terminator | Verified in screenshots and renders |
| Labels | Verified: placed, readable, occluded on the far side, thinning out when zoomed out |
| Desktop presentation mode | Verified by screenshot: the globe renders full-screen at desktop level, behind Finder windows and the Dock, on macOS 26 |
| Offline operation | Structural: nothing in the app opens a network connection, and the whole dataset is bundled. Tests load it from the bundle with no network |

### Still to do on a real Mac

These need a person at the keyboard and have **not** been done:

| Scenario | Why it is still open |
|---|---|
| Drag, zoom and click by hand | Automating them would need Accessibility permission, which the app must not request |
| Presentation mode across Stage Manager, multiple displays, Mission Control, and full-screen apps | Needs those configurations set up by hand |
| Desktop icons still clickable with presentation mode active | Needs a real click on an icon |
| Sleep/wake and display changes | Needs the machine put to sleep and woken |
| Reduce Motion | Needs the system setting toggled |
| VoiceOver | Accessibility labels and values are set in code, but no VoiceOver pass has been made |
| Preferences surviving relaunch | Covered by unit tests against the store; not exercised through the real UI |
| Idle CPU with a visible, paused globe | Only the not-visible case was measured |

To exercise presentation mode without the menus:

```bash
"build/Atlas Desktop.app/Contents/MacOS/Atlas Desktop" --enter-presentation
```

## CI

`.github/workflows/macos.yml` builds and tests on a macOS runner for
every push and pull request, and fails on any build or test error. It
does **not** run `AtlasRenderCheck` (the runners' GPU support is not
something to depend on for a gate), and a green run says nothing about
desktop window behaviour or performance on real hardware.

## Reporting rule

Nothing in this document is marked as verified unless it was actually
run. Where a check was not performed, it says so.
