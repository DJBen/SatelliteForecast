// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SolarSystem",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SolarSystem",
            targets: ["SolarSystem"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SolarSystem",
            dependencies: [
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
