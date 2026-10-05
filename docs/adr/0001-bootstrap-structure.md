# ADR 0001: Milestone 0 bootstrap structure

## Decision
Use a Swift Package (not an .xcodeproj) as the project structure for V1
bootstrap, with three targets:
- `AtlasDesktopCore` (library): Domain layer, no UI/GPU dependencies.
- `AtlasDesktopApp` (executable): SwiftUI app shell, depends on Core.
- `AtlasDesktopCoreTests` (test target): unit tests for Core.

Minimum deployment target: macOS 14 (Sonoma).

## Alternatives considered
- **.xcodeproj from the start:** more natural home for app icon,
  Info.plist, entitlements, and later menu-bar/presentation-mode work.
  Rejected for *this* milestone only because it's harder to generate
  and diff outside Xcode itself; the existing CI workflow
  (`.github/workflows/macos.yml`) already auto-detects either a
  Package.swift or an .xcodeproj, so switching later is low-cost.

## Evidence
- `swift build` / `swift test` are reproducible from the command line
  and in CI (macos-15 runner) without Xcode project-file churn.
- This repo's CI workflow already branches on `Package.swift` presence
  and runs `swift test` in that case — no CI changes needed.
- This agent's working environment cannot run macOS/Xcode locally, so
  anything requiring interactive Xcode project generation could not be
  authored or sanity-checked here. A plain-text Package.swift could be.

## Trade-offs
- SwiftUI `App`/`WindowGroup` launched via `swift run` behaves slightly
  differently from an app launched from a signed .app bundle (no
  Info.plist-driven app name/icon, no sandbox entitlements). This is
  acceptable for Milestone 0 (app shell launches) but must be revisited
  before Milestone 7 (desktop presentation) and Milestone 9 (release),
  which need a real app bundle, icon, and entitlements.
- No renderer, no data pipeline, no menu-bar extra yet — intentionally
  out of scope for Milestone 0 per docs/IMPLEMENTATION_PLAN.md.

## Trigger to revisit
When presentation-mode work (Milestone 7) or notarization/distribution
(Milestone 9) begins, convert to (or generate) an .xcodeproj /
.xcworkspace so Info.plist, entitlements, and code signing have a
proper home. The module boundaries above should carry over unchanged.

## Verification status
**Unverified on real macOS/Xcode** — this bootstrap was authored in a
Linux sandbox with no Swift/macOS toolchain available. It has not been
built or run locally by the authoring agent. Verification relies on:
1. GitHub Actions CI (`macos-15` runner) building/testing this branch.
2. The repo owner building and running it locally in Xcode or via
   `swift build` / `swift run` on an actual Mac.

Both must pass before this ADR's decision is considered validated.
