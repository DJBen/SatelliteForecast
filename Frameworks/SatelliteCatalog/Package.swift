// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SatelliteCatalogPackage",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "SatelliteCatalog",
            targets: ["SatelliteCatalog"]),
        .library(
            name: "SatelliteCatalogImpl_SQLite",
            targets: ["SatelliteCatalogImpl_SQLite"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "SatelliteCatalog",
            dependencies: [],
            path: "Public/Sources"
        ),
        .target(
            name: "SatelliteCatalogImpl_SQLite",
            dependencies: [
                "SatelliteCatalog",
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Impl_SQLite/Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SatelliteCatalogImpl_SQLiteTests",
            dependencies: ["SatelliteCatalogImpl_SQLite"],
            path: "Impl_SQLite/Tests"
        )
    ]
)
