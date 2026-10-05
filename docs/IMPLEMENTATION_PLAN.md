# V1 Implementation Plan

The agent must execute this sequence through release verification. Planning and renderer spikes are not deliverables by themselves.

## Status

All ten milestones are implemented. What remains open is verification
that needs a person at a real Mac — hand-driven input, presentation mode
across Stage Manager and multiple displays, sleep/wake, VoiceOver, and
frame-rate profiling — all listed explicitly in
[TESTING.md](TESTING.md#still-to-do-on-a-real-mac).

| Milestone | State |
|---|---|
| 0 — Inspect and establish the build | Done. Five targets plus two development tools; macOS 14 deployment target; CI builds and tests. |
| 1 — Renderer decision | Done. SceneKit, carried from spike to shipped renderer; spike code removed. [ADR 0002](adr/0002-renderer-choice.md). |
| 2 — Data and geography domain | Done. Natural Earth v5.1.2 pinned by checksum, reproducible conversion, 34 data tests covering holes, multipolygons, the antimeridian, the pole and malformed input. |
| 3 — Interactive globe | Done. Drag, bounded zoom, reset; camera state survives resize and relaunch. |
| 4 — Selection and labels | Done. Exact point-in-polygon hit-testing, three selection cues, deterministic label layout with level of detail, learning mode. |
| 5 — Motion, day/night, lifecycle | Done. Display-link pacing, Reduce Motion support, real subsolar lighting, rendering suspended when not visible. |
| 6 — Native UX | Done. Window, panel, menu bar, status-bar item, settings, keyboard access, accessibility labels, generated app icon, actionable error states. |
| 7 — Desktop presentation | Done within what public APIs allow, and documented honestly. [ADR 0005](adr/0005-desktop-presentation.md). |
| 8 — Hardening and performance | Partly done. 138 automated tests plus an offscreen render check; startup, memory and idle CPU measured; frame rate and input latency **not** measured. |
| 9 — Release readiness | Done apart from the open manual checks above. |

## Milestone 0 — Inspect and establish the build
- Inspect repository contents, branch state, project/package setup, deployment target, and current conventions.
- Choose a supported minimum macOS version based on required APIs and CI.
- Establish the Xcode project or Swift Package structure appropriate for the native app.
- Add a minimal launching app target, test target, and macOS CI.
- Verify clean build/test commands.
**Exit gate:** app shell launches; CI builds and tests.

## Milestone 1 — Renderer decision
- Build a small scene with actual geographic outlines.
- Compare viable native approaches where the choice is uncertain.
- Evaluate implementation complexity, geometry, labels, interaction, lifecycle, frame pacing, and SDK support.
- Record the decision and evidence in docs/ARCHITECTURE.md.
- Remove unused spike code.
**Exit gate:** one backend selected and real country outlines visible.

## Milestone 2 — Data and geography domain
- Select and pin a licensed country polygon dataset.
- Record exact source/version/license/attribution and redistribution rights.
- Implement reproducible offline conversion/loading.
- Add typed coordinate, country ID, geometry, metadata, and validation models.
- Cover holes, multipolygons, antimeridian crossings, missing facts, and malformed input.
- Add deterministic fixture tests.
**Exit gate:** bundled data loads offline and exposes valid representative country geometry/facts.

## Milestone 3 — Interactive globe
- Render country geometry with documented transforms and correct orientation.
- Implement drag rotation, bounded scroll/pinch zoom, and reset/home view.
- Preserve camera state across resizing and ordinary lifecycle events.
- Test coordinate transforms and camera bounds.
**Exit gate:** usable globe with correctly aligned borders.

## Milestone 4 — Selection and labels
- Implement hit-testing consistent with renderer transforms.
- Highlight the selected country.
- Render readable labels with deterministic overlap/LOD behavior.
- Show country name, capital when available, region/continent, and identifier when available.
- Implement learning mode while preserving interaction.
- Test selection, missing facts, and geographic edge cases.
**Exit gate:** real country selection and facts work.

## Milestone 5 — Motion, day/night, and lifecycle
- Implement gentle auto-rotation and pause/resume.
- Define manual-interaction behavior while rotating.
- Respect reduced-motion settings.
- Implement the documented day/night model.
- Reduce rendering when hidden, minimized, occluded, or paused/static.
- Verify sleep/wake and display changes where possible.
**Exit gate:** passive mode is calm and lifecycle-aware.

## Milestone 6 — Native UX
- Complete SwiftUI/AppKit shell, information panel, menu-bar controls, settings, keyboard shortcuts, accessibility names, and app icon.
- Persist preferences and handle invalid/old values.
- Add useful loading and error states.
- Polish spacing, contrast, resizing, and empty states.
**Exit gate:** core actions are discoverable and settings survive relaunch.

## Milestone 7 — Desktop presentation
- Implement the safest reliable public-API presentation mode.
- Provide menu-bar and keyboard escape routes.
- Preserve normal-window mode.
- Test multiple displays, Spaces, Mission Control, Stage Manager, full-screen apps, and desktop icon interaction on real macOS.
- Document verified behavior and limitations.
**Exit gate:** mode can be entered/exited reliably and is described accurately.

## Milestone 8 — Hardening and performance
- Run unit, integration, UI, and regression tests.
- Test offline launch, missing/corrupt data, invalid preferences, selection, camera bounds, repeated open/close, and lifecycle behavior.
- Profile startup, frame pacing, memory, idle CPU, and hidden/occluded behavior on the reference Mac when available.
- Fix high-impact allocations, repeated geometry processing, unnecessary redraws, and main-thread work.
- Record actual measurements and method in docs/TESTING.md.
**Exit gate:** targets measured or deviations documented honestly.

## Milestone 9 — Release readiness
- Map all P0 requirements to implementation and verification.
- Verify all data/software licenses and notices.
- Verify clean-checkout build/test instructions.
- Update README with features, requirements, exact commands, data credits, keyboard controls, offline behavior, and presentation limitations.
- Ensure CI is green and no demo-only data or placeholder controls remain.
- Produce a final report listing exact tests, results, manual checks still requiring a real Mac, and known limitations.
**Exit gate:** PRD Definition of Done is met or remaining blockers are explicit and evidenced.

## Execution rules

- Keep the app buildable throughout.
- Run tests after meaningful changes, not only at the end.
- Do not substitute a mock globe, hard-coded sample country, or screenshot for the real data pipeline.
- If macOS execution is unavailable, continue coding and portable validation while marking macOS-only checks unverified.
- A spike is a decision tool, never the final deliverable.
