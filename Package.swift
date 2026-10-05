// swift-tools-version: 6.0
//
// Test targets use XCTest, which the Command Line Tools alone do not
// provide; running `swift test` needs a full Xcode installation (see
// README.md § Building). `swift build` and `swift run` work with the
// Command Line Tools.
import PackageDescription

let package = Package(
    name: "AtlasDesktop",
    platforms: [
        // macOS 14 is the floor: SwiftUI's Settings scene, the
        // Observation framework used by GlobeSession, and
        // NSWindow.CollectionBehavior used by presentation mode are all
        // available there, and macos-14/15 runners exist for CI.
        .macOS(.v14)
    ],
    products: [
        .library(name: "AtlasDesktopCore", targets: ["AtlasDesktopCore"]),
        .library(name: "AtlasGeographyData", targets: ["AtlasGeographyData"]),
        .library(name: "AtlasGlobeRendering", targets: ["AtlasGlobeRendering"]),
        .executable(name: "AtlasDesktopApp", targets: ["AtlasDesktopApp"]),
        .executable(name: "AtlasDataTool", targets: ["AtlasDataTool"]),
        .executable(name: "AtlasRenderCheck", targets: ["AtlasRenderCheck"])
    ],
    targets: [
        // Domain: coordinates, geometry, countries, camera, solar
        // position, preferences, session state. No AppKit, no SceneKit.
        .target(name: "AtlasDesktopCore"),

        // Bundled dataset plus its decoder and repository.
        .target(
            name: "AtlasGeographyData",
            dependencies: ["AtlasDesktopCore"],
            resources: [.copy("Resources/atlas-countries.json")]
        ),

        // SceneKit renderer: geometry preparation, labels, day/night,
        // interaction mapping.
        .target(
            name: "AtlasGlobeRendering",
            dependencies: ["AtlasDesktopCore"],
            // The surface imagery is a rendering asset, so it lives with
            // the renderer rather than with the geography data.
            resources: [.copy("Resources/atlas-earth.jpg")]
        ),

        // SwiftUI/AppKit shell.
        .executableTarget(
            name: "AtlasDesktopApp",
            dependencies: ["AtlasDesktopCore", "AtlasGeographyData", "AtlasGlobeRendering"]
        ),

        // Development-time tool: Data/source/*.geojson -> runtime asset.
        // Not part of the app.
        .executableTarget(
            name: "AtlasDataTool",
            dependencies: ["AtlasDesktopCore", "AtlasGeographyData"]
        ),

        // Offscreen rendering smoke check; see docs/TESTING.md.
        .executableTarget(
            name: "AtlasRenderCheck",
            dependencies: ["AtlasDesktopCore", "AtlasGeographyData", "AtlasGlobeRendering"]
        ),

        .testTarget(
            name: "AtlasDesktopCoreTests",
            dependencies: ["AtlasDesktopCore"]
        ),
        .testTarget(
            name: "AtlasGeographyDataTests",
            dependencies: ["AtlasGeographyData", "AtlasDesktopCore"]
        ),
        .testTarget(
            name: "AtlasGlobeRenderingTests",
            dependencies: ["AtlasGlobeRendering", "AtlasDesktopCore"]
        )
    ]
)
