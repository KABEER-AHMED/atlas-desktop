# Architecture

## Goals

Atlas Desktop is a local-first native macOS app. Product state and geographic correctness should remain independent of the renderer. Minimize runtime dependencies and allow future data/rendering changes without a rewrite.

## Proposed boundaries

- **AppShell:** app lifecycle, main window, settings, menu-bar commands, and presentation-mode entry/exit.
- **UI:** globe screen, country facts panel, accessible controls, empty/error/loading states.
- **Domain:** typed geographic coordinates, country IDs, country metadata, camera state, interaction state, and preferences.
- **GeographyData:** bundled-data repository, geometry decoder, metadata join, validation, and structured errors.
- **GlobeRendering:** renderer interface, camera/projection, geometry preparation, borders, highlighting, labels, and day/night model.
- **Resources:** licensed source/derived data, metadata, and required attribution notices.

These are responsibility boundaries, not a requirement to create a separate framework for every box. Use a small number of targets/modules where they improve ownership or testing.

## Native stack

- **Swift:** default language for app, data, domain, and orchestration.
- **SwiftUI:** app composition, settings, information panel, accessible controls.
- **AppKit:** menu-bar extra, native window behavior, lifecycle hooks, input, and presentation mode.
- **Renderer:** select one backend after a representative prototype. SceneKit may reduce implementation effort; Metal may offer more explicit rendering control. Evaluate SDK availability/support, startup, geometry pipeline, labels, hit-testing, frame pacing, lifecycle, and maintenance. Do not maintain two renderers in V1.
- **Foundation/Codable:** appropriate for local metadata and preferences.
- **os.Logger:** local diagnostics without telemetry.
- **XCTest/XCUITest:** automated tests.

Check current Apple SDK availability and deprecation status during implementation. Choose and document a minimum macOS deployment target based on actual API needs and CI availability.

## Suggested interfaces

Adapt names to the implementation, but preserve the boundaries:

- **GeographyRepository:** loads local country geometry and metadata, validates IDs, exposes lookup methods, and reports structured errors.
- **GlobeRenderer:** receives validated geometry, camera state, selection, labels/learning state, rotation state, and rendering options; exposes interaction mapping where appropriate.
- **CountrySelectionService:** maps pointer input to a country using the same coordinate transforms as rendering.
- **PreferencesStore:** loads/saves a versioned preferences model with safe defaults and migration.
- **GlobeSessionModel:** coordinates UI actions and state without owning GPU resources or parsing raw datasets.
- **PresentationModeController:** isolates public-API window behavior and provides a reliable exit/fallback path.

Avoid generic frameworks and protocol hierarchies without a concrete testability or replacement benefit.

## Geographic data pipeline

1. Pin the exact source dataset, release/version, scale, official source URL, license, and download date in docs/DATA_AND_LICENSES.md.
2. Preserve source files and notices where redistribution terms require it.
3. Provide a reproducible conversion/loading step from source polygons to runtime geometry.
4. Validate coordinate ranges, polygon rings, holes, multipolygons, invalid rings, antimeridian crossings, country IDs, and metadata joins.
5. Separate source data from generated runtime assets.
6. Ensure runtime never depends on a download.
7. Document simplification/triangulation tolerances and test representative country shapes.

## Coordinate/rendering conventions

- Use a canonical domain convention: latitude/longitude in degrees; convert explicitly to renderer units.
- Document sphere orientation, prime meridian, north pole, camera up vector, coordinate handedness, and transforms.
- Handle the antimeridian explicitly to prevent long erroneous triangles or borders across the globe.
- Ensure selection mapping matches the rendered geometry and current globe orientation.
- Use stable source-backed identifiers, not display names, as keys.
- Label placement must consider curvature, far-side occlusion, zoom, overlap, and contrast. Start with deterministic placement and modest level-of-detail rules rather than recomputing expensive layouts each frame.
- Separate day/night rendering from country geometry and document the accuracy of the sun model.

## State and concurrency

- UI state updates are main-actor isolated.
- Dataset decoding, validation, projection preprocessing, and triangulation run off the main thread.
- GPU resources have a clear owner and lifecycle.
- Prepared geometry should be immutable after loading where practical.
- Cancel obsolete loading/preprocessing when the relevant view disappears or work is superseded.
- Persist durable user preferences only; never persist transient pointer deltas or GPU resources.

## Performance strategy

Measure before optimizing. Inspect dataset decode, triangulation, label layout, hit-testing, draw submission, and unnecessary rendering while hidden. Use Instruments and signposts where helpful.

- Preprocess static geometry once.
- Avoid per-frame allocations and full-dataset scans.
- Add spatial indexing only if profiling justifies it.
- Use simplification/LOD where necessary without obvious border distortion.
- Use display-synchronized frame pacing.
- Suspend or reduce rendering when invisible, occluded, static, or paused.
- Avoid frequent SwiftUI invalidation for frame-by-frame state.
- Clean up resources on close, hide, display change, and sleep/wake.

## Desktop presentation

macOS does not offer a universal guarantee that any third-party app can behave exactly like the system wallpaper beneath every icon across every Space and OS configuration. Use supported public APIs only. Keep window-level and collection behavior isolated in PresentationModeController. Never use private APIs, Accessibility automation, injection, or screen capture as a workaround. Normal-window mode must always remain usable.

## Architecture decision record template

For renderer, data format, deployment target, and desktop presentation, record:
- Decision.
- Alternatives considered.
- Evidence: prototype, tests, benchmarks, SDK/API constraints.
- Trade-offs: performance, complexity, accessibility, maintenance.
- Trigger that would justify revisiting the decision.
