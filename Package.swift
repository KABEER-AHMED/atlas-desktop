// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtlasDesktop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AtlasDesktopCore", targets: ["AtlasDesktopCore"]),
        .executable(name: "AtlasDesktopApp", targets: ["AtlasDesktopApp"])
    ],
    targets: [
        .target(name: "AtlasDesktopCore"),
        // Milestone 1 renderer-decision spike only. Not a final
        // GlobeRendering module — see docs/adr/0002-renderer-choice.md.
        // Deleted/replaced once the renderer decision ships for real.
        .target(
            name: "GlobeRenderingSpike",
            dependencies: ["AtlasDesktopCore"]
        ),
        .executableTarget(
            name: "AtlasDesktopApp",
            dependencies: ["AtlasDesktopCore", "GlobeRenderingSpike"]
        ),
        .testTarget(
            name: "AtlasDesktopCoreTests",
            dependencies: ["AtlasDesktopCore"]
        ),
        .testTarget(
            name: "GlobeRenderingSpikeTests",
            dependencies: ["GlobeRenderingSpike", "AtlasDesktopCore"]
        )
    ]
)
