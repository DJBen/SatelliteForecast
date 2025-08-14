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
