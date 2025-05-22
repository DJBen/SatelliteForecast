// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SatelliteKit",
    platforms: [
        .iOS(.v16)
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
