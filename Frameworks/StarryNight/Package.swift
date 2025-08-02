// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "StarryNight",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "StarryNight",
            targets: ["StarryNight"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(path: "../SatelliteKit"),
    ],
    targets: [
        .target(
            name: "StarryNight",
            dependencies: [
                "SatelliteKit",
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "StarryNightTests",
            dependencies: ["StarryNight"],
            path: "Tests"
        )
    ]
)
