// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SatelliteForecastPackage", // Renamed to avoid conflict with target names
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
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
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "11.14.0")
        ),
        .package(url: "https://github.com/nh7a/Geohash.git", branch: "main"),
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
            path: "Public/Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "SatelliteForecastImpl",
            dependencies: [
                "SatelliteForecast",
                .product(name: "CombineRex", package: "SwiftRex"),
                "CombineRextensions",
                "ActivityView",
                "SwiftUIVisualEffects",
                "Geohash",
                .product(name: "SatelliteKit", package: "SatelliteKit"),
                .product(name: "StarryNight", package: "StarryNight"),
                .product(name: "QSMag", package: "QSMag"),
                .product(name: "SolarSystem", package: "SolarSystem"),
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage"),
                .product(name: "SatelliteCatalogImpl_SQLite", package: "SatelliteCatalogPackage"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ],
            path: "Impl/Sources",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "SatelliteForecastImplWiring",
            dependencies: [
                "SatelliteForecast",
                "SatelliteForecastImpl",
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage"),
            ],
            path: "ImplWiring/Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ],
)
