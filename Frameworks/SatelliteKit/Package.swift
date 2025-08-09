// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SatelliteKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SatelliteKit",
            targets: ["SatelliteKit"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "SatelliteKit",
            dependencies: [],
            path: "Classes",
        ),
        .testTarget(
            name: "SatelliteKitTests",
            dependencies: ["SatelliteKit"],
            path: "Tests"
        )
    ]
)
