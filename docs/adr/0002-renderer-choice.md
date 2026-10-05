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
**Partially unverified.** This decision and the spike code were
authored with no Swift/macOS toolchain available — see
docs/adr/0001-bootstrap-structure.md for why. Confirm before treating
this ADR as settled:
1. The spike actually compiles and runs on a real Mac (`swift run
   AtlasDesktopApp` should show a dark sphere with two yellow outline
   shapes, draggable with the mouse).
2. The two outlines are **not** real country borders — see the
   warning in `PlaceholderOutlines.swift`. They exist only to give the
   pipeline a non-trivial shape to push through; do not judge
   geographic accuracy from this spike.
