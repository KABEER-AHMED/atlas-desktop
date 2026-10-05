# ADR 0002: Renderer choice — SceneKit for V1

## Decision
Use SceneKit (not raw Metal) as the single V1 rendering backend.

## Alternatives considered
- **Metal (raw):** full explicit control over the render loop, buffers,
  and shaders. More code to own for the same result, and no built-in
  solution for camera controls, lighting, or scene graph — all of
  which this app needs (sphere + borders + labels + hit-testing).
- **SceneKit (chosen):** scene graph, built-in camera/lighting,
  `SCNGeometry` with custom vertex/index data (used here for the line
  outlines), and built-in hit-testing (`SCNView.hitTest`) that can sit
  directly on top of `SphereProjection` — the same transform used to
  build the geometry, satisfying the architecture doc's requirement
  that "selection mapping matches the rendered geometry."

## Evidence
- `Sources/GlobeRenderingSpike/` builds a sphere plus two line-geometry
  outlines (`SceneKitGlobeSceneBuilder`), going through the real
  pipeline shape: coordinates → `SphereProjection` → `SCNGeometrySource`
  → `SCNGeometryElement(primitiveType: .line)`.
- SceneKit's `SCNGeometry` accepts arbitrary vertex/index buffers, so
  the "custom geometry from decoded polygon data" requirement (needed
  either way for Milestone 2's real dataset) is not actually easier in
  raw Metal — both require the same decode → triangulate/line-strip →
  upload step. SceneKit adds camera, lighting, and hit-testing for
  free on top of that; Metal would require hand-writing those.
- **Not yet evidenced on real hardware:** frame pacing, startup time,
  and label rendering at scale (hundreds of countries, not two) still
  need to be measured on an actual Mac. This spike only establishes
  that the geometry pipeline is viable in SceneKit, not that it meets
  the 60 FPS / <2s startup / <300MB targets in docs/PRD.md.

## Trade-offs
- SceneKit is a higher-level API; if a specific performance ceiling is
  hit later (e.g., per-frame label layout at full country count),
  dropping to a custom Metal shader for just that piece is still
  possible without abandoning the scene graph for everything else.
- Day/night shading (Milestone 5) and label LOD (Milestone 4) are
  easier to prototype in SceneKit via custom `SCNProgram`/shader
  modifiers than to hand-roll in Metal, at the cost of being one layer
  further from the GPU than raw Metal would be.

## Trigger to revisit
If profiling on the reference Mac (Milestone 8) shows SceneKit's
overhead (not the data/label logic) is the actual bottleneck for the
60 FPS target with the full real dataset, re-evaluate a Metal-based
renderer for just the globe draw call, keeping SwiftUI/AppKit for
everything else.

## Verification status

**Verified.** The decision was originally recorded from an unbuilt spike;
it has since been carried through to the shipped renderer and checked:

1. `swift build` and `swift test` pass on macOS 26 with Swift 6.4.
2. The app runs and draws the real dataset — 177 countries, ~10 400
   vertices of border geometry in a single draw call — over NASA Blue
   Marble imagery, with labels, selection highlighting, a day/night
   terminator and an atmospheric rim.
3. `SCNGeometry` with custom vertex and index buffers carried the real
   border data without trouble, as this ADR predicted.
4. `SCNRenderer` renders the same scene offscreen with no window, which
   is what `AtlasRenderCheck` is built on — an unplanned benefit of the
   scene-graph API that raw Metal would not have given for free.

Two things this ADR expected to use turned out not to be needed:

- **`SCNView.hitTest` is not used.** Selection runs the renderer's own
  inverse projection and an analytic ray/sphere intersection instead,
  then exact point-in-polygon arithmetic. SceneKit's hit test would
  answer against the *tessellated sphere*, not the geographic surface,
  and its accuracy would depend on `segmentCount`. The current path is
  independent of tessellation and shares its transforms with the geometry.
- **No shader modifiers were needed.** Day/night is a directional light
  pointed at the real subsolar position, which is simpler than a custom
  shader and needs no per-frame uniform updates.

Still unmeasured: frame rate and frame pacing with the full dataset — see
docs/TESTING.md. The trigger to revisit this decision is unchanged.
