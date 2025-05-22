// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SolarSystem",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SolarSystem",
            targets: ["SolarSystem"])
    ],
    dependencies: [
        .package(path: "../SatelliteKit"),
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
