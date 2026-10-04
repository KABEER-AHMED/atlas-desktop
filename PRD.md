# Atlas Desktop — Product Requirements Document

**Status:** V1 implementation contract  
**Product:** Native interactive 3D Earth globe and geography-learning companion for macOS  
**Primary reference device:** Apple Silicon MacBook Pro M1 Pro, 32 GB RAM  
**Principle:** Local-first, native, responsive, polished, and complete—not demo-only.

## 1. Product summary

Atlas Desktop brings a beautiful, interactive Earth globe to macOS. Users can rotate and zoom the globe, inspect a country and its available facts, hide labels to test their geography knowledge, and leave the globe slowly rotating as a calm visual presence. The app must work as a conventional native window and offer a desktop presentation mode using supported public macOS APIs, with its limitations honestly documented.

V1 must be a working application, not a static mockup, browser wrapper, remote dashboard, or proof of concept. It must build from source, include tests, persist preferences, and run without network access after installation and bundled data are present.

## 2. Goals

1. Deliver a native macOS experience with appropriate menus, keyboard access, settings, accessibility, and window behavior.
2. Render a real 3D globe with country borders, readable labels, selection highlighting, and a day/night terminator.
3. Support drag rotation, bounded zoom, country facts, passive auto-rotation, and learning mode.
4. Bundle openly licensed geographic data and work offline for core functionality.
5. Keep code modular, testable, maintainable, and measurable for performance.
6. Optimize from profiling evidence, not from language hype or premature low-level rewrites.

## 3. Non-goals for V1

- Accounts, cloud sync, backend services, telemetry, ads, subscriptions, API keys, or mandatory network access.
- Runtime map-tile downloads, live weather, live clouds, satellite imagery, live political data, photorealistic terrain, 3D buildings, flight tracking, or route planning.
- Cross-platform Electron or web-shell architecture.
- A guarantee that an ordinary third-party app can sit beneath desktop icons on every macOS version, Space, display, or Stage Manager configuration.
- Rust, C, or Java by default. Swift is the baseline; other languages require a measured, documented benefit.

## 4. Target users and core jobs

The primary user wants a calm and attractive globe for exploration and desktop ambience, values local operation, and expects smooth interactions.

Core jobs:
- Glance at a polished globe that remains unobtrusive.
- Rotate and zoom Earth naturally with mouse or trackpad.
- Select a country and see its name, capital when known, continent/region, and identifier.
- Hide labels and recall country locations.
- Pause or resume slow rotation immediately.
- Use core functionality without an internet connection.

## 5. Functional requirements

Priority: **P0** is release-blocking; **P1** is desired but may be deferred only with a documented rationale.

### FR-01 — Native application shell (P0)
- Implement in Swift. Use SwiftUI for UI composition and AppKit where native windows, menu-bar behavior, lifecycle, or input require it.
- Provide a conventional app window with a globe canvas, compact country-information panel, and restrained controls.
- Provide menu-bar access to Show/Hide Window, Pause/Resume Rotation, Toggle Learning Mode, Desktop Presentation when available, Settings, and Quit.
- Support keyboard focus, accessible control names, standard window behavior, and a meaningful app name/icon.
- No webview/browser runtime for the core UI.

### FR-02 — Real 3D globe (P0)
- Render a sphere with geographic country geometry, country borders, dark space/background styling, and a restrained atmospheric rim.
- Correctly handle polygons, multipolygons, holes, high latitudes, and antimeridian crossings from the selected data source.
- Labels must be readable, appropriately occluded or hidden on the far side, and not excessively overlapping at ordinary zoom.
- Keep rendering behind a small interface so product state and geography logic do not depend on one renderer.
- Evaluate viable native approaches with a small representative real-data scene. Select one backend, record the reasoning and evidence in the architecture document, and remove unused spike code. SceneKit may accelerate implementation; Metal may provide more explicit control. Choose based on SDK support, measured behavior, label strategy, hit-testing, lifecycle, and maintainability.

### FR-03 — Navigation and input (P0)
- Drag rotates the globe predictably.
- Scroll/pinch zoom changes camera distance or scale within defined minimum and maximum bounds.
- Provide a reset/home-view action.
- Clicking a country selects it; clicking empty space clears selection or follows a consistent documented behavior.
- Input must not interfere with adjacent controls or ordinary macOS interaction.
- Selection and rotation controls must feel immediate.

### FR-04 — Country selection and facts (P0)
- Highlight the selected country without obscuring its borders.
- Display country/common name, capital when available, continent/region, and ISO identifier when source data provides it.
- Missing facts must be omitted or explicitly marked unavailable; never invent them.
- Hit-testing must use coordinate transforms consistent with rendered geometry.
- Selection must work in normal-window mode and in presentation mode where interaction is supported.

### FR-05 — Passive mode (P0)
- Provide gentle automatic rotation with a sensible default speed.
- Provide pause/resume in the main UI and menu-bar controls.
- Define how manual interaction interacts with auto-rotation and test it.
- Respect reduced-motion preferences by disabling or minimizing automatic motion by default.
- Reduce or stop rendering work when hidden, minimized, occluded, or not visibly animating.

### FR-06 — Learning mode (P0)
- Hide country labels while keeping borders and interaction enabled.
- Selecting a country reveals its available facts.
- Provide an explicit way to hide the answer again or continue exploring.
- Persist the learning-mode preference.

### FR-07 — Day/night terminator (P1)
- Render a subtle day/night boundary using a documented, deterministic lighting model.
- If solar position is approximate, describe it as an approximation; do not claim astronomical precision.
- No network access is allowed for this feature.
- If the accurate model would jeopardize delivery, ship a coherent documented approximation or record a specific deferral rather than silently leaving a fake control.

### FR-08 — Desktop presentation mode (P0, with platform caveat)
- Provide an optional desktop-style presentation mode using supported public macOS APIs.
- Investigate window level, collection behavior, Spaces, Stage Manager, Mission Control, full-screen applications, multiple displays, and desktop icon interaction.
- Provide a reliable escape route through menu-bar controls and a keyboard shortcut.
- Never steal focus unexpectedly, intercept clicks meant for other apps, or make desktop icons inaccessible.
- Do not use private APIs, injection, system modifications, Accessibility permissions, or Screen Recording permissions to imitate wallpaper behavior.
- If true wallpaper-under-icons behavior cannot be implemented reliably, deliver the closest stable native desktop companion mode, label it honestly, and preserve normal-window mode as the supported fallback.

### FR-09 — Preferences (P0)
Persist user-visible preferences locally using appropriate native mechanisms. At minimum persist auto-rotation, learning mode, and any exposed speed/label preferences. Persist camera/home view only if stable and useful. Invalid or old values must recover to safe defaults. Settings should apply without restart unless a documented platform constraint prevents it.

### FR-10 — Offline data (P0)
- Bundle required country geometry and essential metadata, or provide a deterministic documented local setup step.
- First launch with networking disabled must still render the globe and allow selection.
- No runtime map API, tile download, login, or remote service for core features.
- Document exact dataset source/version, license, attribution, transformation steps, and update process.
- Clearly separate source data from derived runtime assets.

### FR-11 — Accessibility and usability (P0)
- Give controls accessible names and keyboard focus.
- Make pause/resume, learning mode, reset view, and return from presentation mode available without pointer gestures.
- Do not convey country selection through color alone.
- Respect reduced-motion preferences where feasible.
- Ensure sufficient contrast and graceful layouts at common window sizes.

### FR-12 — Errors and diagnostics (P0)
- Missing/corrupt bundled data must produce an actionable error rather than a crash or unexplained blank window.
- Use Apple unified logging without personal data.
- Keep diagnostics local; no telemetry or log uploads.
- Do not silently swallow errors that disable a core feature.

## 6. Information architecture and visual direction

Main window:
1. Globe canvas as the primary visual area.
2. Compact country panel with a useful empty state.
3. Minimal controls for rotation, learning mode, reset, and presentation.
4. Native settings UI rather than a permanently crowded toolbar.

Visual direction: calm, premium, dark-first, inspired by astronomical atlases. Use deep navy/near-black space, restrained ocean colors, crisp borders, legible labels, native system typography, and a restrained selection accent. Animation must be deliberate, smooth, and interruptible. Avoid dashboard clutter and ornamental UI that competes with the globe.

Every state-changing control must visibly reflect its state. Add tooltips and keyboard shortcuts for important actions. Resize, display changes, sleep/wake, and Space switching must not corrupt camera state or leave render loops running.

## 7. Performance and quality budgets

These are targets to measure on the M1 Pro, not results that can be claimed without profiling.

- **Input response:** target input-to-visible response under 50 ms in ordinary scenes.
- **Frame rate:** target stable 60 FPS during normal visible interaction at a defined reference window size.
- **Warm startup:** target first usable globe within 2 seconds.
- **Memory:** target under 300 MB resident memory for the normal V1 scene.
- **Idle CPU:** approach negligible usage when paused and not visibly rendering.
- **Lifecycle:** no unconditional busy loop or full-rate offscreen rendering.
- **Data:** no runtime map-network traffic; justify bundled asset size.
- **Battery/thermal:** use native frame pacing and avoid unnecessary rendering; do not claim measured energy results without measuring them.

Record device, OS, build, scene size, method, actual results, and deviations. Profile before optimizing. Prioritize data preprocessing, geometry complexity, label layout, hit-testing, redraw frequency, and lifecycle correctness before low-level language rewrites.

## 8. Architecture and engineering principles

- Swift-first. Use SwiftUI/AppKit and one evidence-selected renderer.
- Separate domain models, geography loading, rendering, input/state, preferences, and UI.
- Use typed models for geographic coordinates, country identifiers, camera state, selection, and preferences.
- Use dependency injection at testable boundaries such as the data repository, renderer, and preferences store.
- Keep UI state on the main actor; move parsing and expensive geometry preprocessing off the main actor.
- Use immutable prepared geometry where practical and define ownership of GPU resources.
- Avoid global mutable state, giant view files, duplicated sources of truth, needless abstraction, and hidden singleton dependencies.
- Add third-party dependencies only for a concrete need, after maintenance and license review.
- Rust/C are permitted only for a measured hotspot where Swift is inadequate. Keep FFI narrow, documented, and tested. Java is not a default candidate.
- Keep the architecture proportional to a small native app; do not turn it into a distributed system.

## 9. Data correctness and licensing

- Evaluate a stable permissively licensed source such as Natural Earth, verify the exact asset and terms, and record the selected version.
- Audit geometry and metadata licenses independently.
- Use stable ISO identifiers where available and document handling of dependent/disputed territories according to the chosen source.
- Document the source for capitals and country names.
- Include tests for antimeridian polygons, holes, multipolygons, missing capitals, and failed metadata joins.

## 10. Security and privacy

No accounts, analytics, ad SDKs, crash-report uploads, or background network activity. Core V1 must not request location, contacts, microphone, camera, screen recording, Accessibility, or unrelated permissions. Validate bundled data and keep logs free of sensitive information. Never use private APIs or runtime injection.

## 11. Testing and definition of done

Automated tests:
- Coordinate transforms, ring/polygon processing, country lookup, metadata joins, camera limits, and selection mapping.
- Preferences defaults, persistence, invalid values, and migration.
- Data loading and representative country facts.
- State transitions for rotation, learning mode, and lifecycle.
- UI tests for startup, selection, toggles, settings persistence, and keyboard access where supported.
- macOS CI that builds and runs tests on pushes and pull requests.

Manual tests on real macOS:
- Drag/zoom/selection/labels/learning mode/auto-rotation.
- Offline launch with network disabled.
- Multiple displays, Spaces, Mission Control, Stage Manager, full-screen apps, sleep/wake, and minimize/hide.
- Presentation-mode escape path.
- Startup, frame pacing, memory, idle CPU, and hidden/occluded behavior.

V1 is done only when all P0 requirements are implemented, tests pass, the app builds from a clean checkout, licensing/attribution is present, performance checks are measured or deviations documented, and README instructions are reproducible. A mockup or screenshot is not completion.

## 12. Acceptance checklist

- [ ] Native macOS app launches into a functioning 3D globe.
- [ ] Country borders align correctly with geographic regions.
- [ ] Drag rotation, bounded zoom, and reset work.
- [ ] Selection highlights the correct country and shows available facts.
- [ ] Auto-rotation is gentle and can be paused/resumed.
- [ ] Learning mode hides labels while preserving selection.
- [ ] Day/night terminator is implemented or explicitly deferred with rationale.
- [ ] Desktop presentation works within documented public API limits and has an immediate exit path.
- [ ] Preferences persist and invalid values recover safely.
- [ ] Core functionality works offline.
- [ ] Key controls have accessible names and keyboard access.
- [ ] Automated tests and macOS CI pass.
- [ ] Performance measurements and platform limitations are documented.
- [ ] Data licenses and attribution are verified.
- [ ] No mandatory backend, analytics, accounts, or sensitive permissions.
- [ ] README explains setup, build, test, run, data credits, and limitations.

## 13. AI-agent delivery policy

The agent must inspect the repository, plan briefly, and then implement through verification. It must not stop at a plan, scaffold, visual mockup, or renderer spike. At every milestone, run relevant tests and fix regressions. If a requirement cannot safely or reliably be delivered, record evidence, attempted approaches, platform constraints, and the best implemented fallback. Never claim tests, benchmarks, or manual checks passed unless actually run.
