# AI Coding Agent Instructions

## Mission

Implement Atlas Desktop V1 end to end according to PRD.md. The goal is a working, polished native macOS app—not a proposal, skeleton, screenshot, or static mockup. Continue through implementation, tests, and documentation until V1 is complete or a genuine blocker is evidenced.

## Before editing

1. Read PRD.md and every document under docs.
2. Inspect the complete repository, branch, current project/package setup, deployment target, conventions, and CI.
3. Identify the real app entry point and exact build/test commands.
4. Preserve existing work; never overwrite user code or assets without inspecting them.
5. Make a concise checklist, then proceed without asking the user to approve routine choices already covered by the PRD.

## Engineering rules

- Swift is the default language. Use SwiftUI for composition and AppKit for native macOS behavior.
- Select one rendering backend based on a representative real-data prototype and documented evidence.
- Do not introduce Electron, a webview shell, a backend, required API keys, runtime tile downloads, analytics, accounts, or cloud services.
- Do not introduce Rust, C, Java, or a large dependency merely because it is available. Require measured benefit and document any FFI boundary.
- Separate app shell, geographic domain/data, renderer, interaction/state, preferences, and presentation-mode behavior. Keep the design proportional to V1.
- Use explicit typed models, clear ownership, testable boundaries, and structured errors.
- Keep UI state updates main-actor isolated. Move expensive parsing, validation, triangulation, and preprocessing off the main actor.
- Do not use unconditional busy loops or full-rate rendering when hidden, minimized, occluded, paused, or otherwise invisible.
- Use public, supported macOS APIs only. No private APIs, process injection, privileged helpers, system modifications, or unrelated permissions.
- Every control must perform its advertised action. No placeholder buttons, hard-coded demo-only country selection, fake country facts, or inert menus.
- Missing data must be represented honestly, never invented.
- Do not disable tests, globally silence warnings, lower quality gates to pass CI, or claim verification that did not happen.
- Review third-party dependencies and assets for maintenance, license compatibility, and redistribution requirements.
- Respect accessibility, keyboard, reduced-motion, offline, and licensing requirements.
- Prefer readable code over cleverness.

## Required execution sequence

1. **Reconnaissance:** document what exists and determine the true build/test commands.
2. **Renderer decision:** implement a representative globe with real geographic data, compare native options if appropriate, record evidence and select one backend. A spike is not the final deliverable.
3. **Data pipeline:** pin a licensed source, record provenance, implement deterministic local conversion/loading, and test geographic edge cases.
4. **Domain:** implement coordinate, country ID, geometry, metadata join, camera constraints, selection mapping, and preferences with tests.
5. **Renderer:** implement actual country geometry/borders, labels, highlighting, atmosphere/background, bounded zoom, and rotation.
6. **UX:** implement native shell, country facts panel, menu-bar controls, learning mode, settings, keyboard access, accessibility, and actionable errors.
7. **Lifecycle/presentation:** implement safe public-API desktop presentation with a reliable escape path; document limitations.
8. **Hardening:** test offline launch, corrupt/missing data, invalid preferences, sleep/wake, display changes, and hidden/occluded behavior.
9. **Verification:** run formatting/lint checks if configured, unit/integration/UI tests, clean build, and performance checks available in the environment.
10. **Documentation:** update README and testing notes with actual commands, outcomes, measured performance, and known limitations.
11. **Final report:** list implemented features, architecture decisions, exact commands, test outcomes, manual checks not performed, and known limitations.

## Quality gates

- Every P0 requirement maps to implementation plus a test or explicit manual verification procedure.
- Add regression tests for discovered bugs.
- Tests should be deterministic and local; no live network dependency.
- Keep main buildable throughout development.
- CI must run on macOS and fail on build/test errors.
- A successful CI run is not proof of desktop window behavior or M1 performance.
- Do not claim wallpaper behavior, performance, accessibility, or offline operation has been verified without actually checking it.

## Completion behavior

Do not stop after routine choices, a scaffold, a design spike, or an incomplete app. Make reasonable decisions within the PRD, document them, and continue. If macOS execution is unavailable, continue implementation and any portable validation; clearly mark macOS-only verification as unverified. Ask the user only for a genuinely blocking decision that cannot be resolved safely from the requirements.

## Scope discipline

V1 should be compact and complete. Defer live data, photorealistic textures, cloud sync, plugins, and unrelated features. Prioritize a reliable real-data globe over scope expansion.
