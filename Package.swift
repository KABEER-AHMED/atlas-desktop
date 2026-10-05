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
        .executableTarget(
            name: "AtlasDesktopApp",
            dependencies: ["AtlasDesktopCore"]
        ),
        .testTarget(
            name: "AtlasDesktopCoreTests",
            dependencies: ["AtlasDesktopCore"]
        )
    ]
)
