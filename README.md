# Atlas Desktop

**Native, offline-first 3D Earth globe and geography-learning companion for macOS.**

Atlas Desktop is designed to combine a calm, polished globe with useful geography interactions: rotate and zoom Earth, inspect country facts, hide labels to quiz yourself, and enable gentle automatic rotation. A desktop presentation mode will use supported macOS behavior and document its limitations.

> **Project status:** Product specification and implementation contract are established. Update feature, build, and performance status only after actual implementation and verification.

## Product principles

- Native macOS app using Swift, SwiftUI, and AppKit.
- One evidence-selected rendering backend; choose Metal or SceneKit from a documented prototype.
- Local-first and offline-capable with bundled, licensed geographic data.
- No account, backend, telemetry, API key, or runtime map-download requirement.
- Modular, testable code with measured performance and lifecycle-aware rendering.
- No private APIs or system modifications to imitate wallpaper behavior.

## Planned V1 features

See [PRD.md](PRD.md) for requirements and acceptance criteria.

- Interactive 3D globe with country borders and labels.
- Mouse/trackpad rotation and bounded zoom.
- Country selection with name, capital, region/continent, and identifier when available.
- Passive automatic rotation with pause/resume.
- Learning mode that hides labels but preserves selection.
- Day/night terminator.
- Native settings and menu-bar controls.
- Optional desktop presentation mode within supported public macOS API constraints.
- Offline operation, accessibility, automated tests, and performance verification.

## Documentation

- [Product requirements](PRD.md)
- [AI agent instructions](AGENTS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Testing and verification](docs/TESTING.md)
- [Data and licensing](docs/DATA_AND_LICENSES.md)

## Requirements

A Mac with a supported macOS version, Xcode/Command Line Tools, and the Swift toolchain compatible with the selected deployment target. The exact minimum macOS and Xcode versions must be selected during implementation and documented after CI verification.

## Build, test, and run

The canonical commands depend on whether the project uses an Xcode project or Swift Package Manager. The implementation agent must establish one workflow and replace this section with verified commands for building, testing, launching, and regenerating bundled geographic assets. Do not label a command verified until it has actually run successfully. CI should build and test on a macOS runner.

## Performance

Targets to measure on the M1 Pro reference Mac: smooth 60 FPS visible interaction, under-50-ms perceived input response, warm startup under 2 seconds, and under 300 MB resident memory for the normal scene. These are targets, not current benchmark claims. See [docs/TESTING.md](docs/TESTING.md).

## Desktop presentation caveat

A third-party app cannot safely assume it can behave exactly like system wallpaper beneath every desktop icon and across every Space, display, and macOS release. Implementation must use public APIs, provide a reliable way back to normal-window mode, and describe tested behavior accurately.

## Privacy

Core features are intended to work on-device. No account, analytics, or runtime network access is required for core features. Any future change must be documented and justified.

## License

The software license and data licenses must be chosen and audited before distribution. The software license does not automatically cover bundled geography data or other assets. See [docs/DATA_AND_LICENSES.md](docs/DATA_AND_LICENSES.md).
