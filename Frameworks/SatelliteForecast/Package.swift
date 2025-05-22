// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SatelliteForecastPackage", // Renamed to avoid conflict with target names
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SatelliteForecast",
            targets: ["SatelliteForecast"]),
        .library(
            name: "SatelliteForecastImpl",
            targets: ["SatelliteForecastImpl"]),
        .library(
            name: "SatelliteForecastImplWiring",
            targets: ["SatelliteForecastImplWiring"])
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BTree", from: "4.1.0"),
        .package(url: "https://github.com/SwiftRex/SwiftRex", from: "0.8.12"),
        .package(url: "https://github.com/SwiftRex/CombineRextensions", branch: "master"),
        .package(path: "../ActivityView"),
        .package(path: "../SatelliteKit"),
        .package(path: "../StarryNight"),
        .package(path: "../QSMag"),
        .package(path: "../SolarSystem"),
        .package(path: "../SwiftUIVisualEffects"),
        .package(name: "SatelliteCatalogPackage", path: "../SatelliteCatalog")
    ],
    targets: [
        .target(
            name: "SatelliteForecast",
            dependencies: [
                "BTree",
                "StarryNight"
            ],
            path: "Public/Sources"
        ),
        .target(
            name: "SatelliteForecastImpl",
            dependencies: [
                "SatelliteForecast",
                .product(name: "CombineRex", package: "SwiftRex"),
                "CombineRextensions",
                "ActivityView",
                "SwiftUIVisualEffects",
                .product(name: "SatelliteKit", package: "SatelliteKit"),
                .product(name: "StarryNight", package: "StarryNight"),
                .product(name: "QSMag", package: "QSMag"),
                .product(name: "SolarSystem", package: "SolarSystem"),
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage")
            ],
            path: "Impl/Sources",
            resources: [.process("Resources")]
        ),
        .target(
            name: "SatelliteForecastImplWiring",
            dependencies: [
                "SatelliteForecast",
                "SatelliteForecastImpl",
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage"),
                .product(name: "SatelliteCatalogImpl_SQLite", package: "SatelliteCatalogPackage")
            ],
            path: "ImplWiring/Sources"
        )
    ]
)
