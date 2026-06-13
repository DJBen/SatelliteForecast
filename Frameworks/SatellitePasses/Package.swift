// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SatellitePasses",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SatellitePasses",
            targets: ["SatellitePasses"])
    ],
    dependencies: [
        .package(path: "../SatelliteKit"),
        .package(path: "../QSMag"),
        .package(path: "../SolarSystem"),
        .package(name: "SatelliteCatalogPackage", path: "../SatelliteCatalog")
    ],
    targets: [
        .target(
            name: "SatellitePasses",
            dependencies: [
                .product(name: "SatelliteKit", package: "SatelliteKit"),
                .product(name: "QSMag", package: "QSMag"),
                .product(name: "SolarSystem", package: "SolarSystem"),
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SatellitePassesTests",
            dependencies: ["SatellitePasses"],
            path: "Tests"
        )
    ]
)
