// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SolarSystem",
    platforms: [
        .iOS(.v18),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SolarSystem",
            targets: ["SolarSystem"])
    ],
    dependencies: [
        .package(url: "https://github.com/DJBen/SatelliteKit.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "SolarSystem",
            dependencies: [
                "SatelliteKit",
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SolarSystemTests",
            dependencies: ["SolarSystem"],
            path: "Tests"
        )
    ]
)
