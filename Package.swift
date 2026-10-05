// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AtlasDesktop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AtlasDesktopApp", targets: ["AtlasDesktopApp"])
    ],
    targets: [
        // Domain: typed geographic coordinates, country IDs, validation.
        // No GPU/UI dependencies, per docs/ARCHITECTURE.md boundaries.
        .target(
            name: "AtlasDesktopCore",
            path: "Sources/AtlasDesktopCore"
        ),
        // AppShell + UI: app lifecycle, main window, SwiftUI composition.
        .executableTarget(
            name: "AtlasDesktopApp",
            dependencies: ["AtlasDesktopCore"],
            path: "Sources/AtlasDesktopApp"
        ),
        .testTarget(
            name: "AtlasDesktopCoreTests",
            dependencies: ["AtlasDesktopCore"],
            path: "Tests/AtlasDesktopCoreTests"
        )
    ]
)
