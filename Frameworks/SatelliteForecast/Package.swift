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
        .package(url: "https://github.com/markiv/SwiftUI-Shimmer.git", from: "1.5.1"),
        .package(url: "https://github.com/attaswift/BTree", from: "4.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.3.3"),
        .package(url: "https://github.com/DJBen/BTreeCustomDump.git", from: "1.0.0"),
        .package(url: "https://github.com/SwiftRex/SwiftRex", from: "0.8.12"),
        .package(url: "https://github.com/SwiftRex/CombineRextensions", branch: "master"),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "12.0.0")
        ),
        .package(url: "https://github.com/nh7a/Geohash.git", branch: "main"),
        .package(path: "../ActivityView"),
        .package(path: "../AppDelegate"),
        .package(url: "https://github.com/DJBen/SatelliteKit.git", from: "3.0.0"),
        .package(url: "https://github.com/DJBen/StarryNight.git", from: "1.0.0"),
        .package(path: "../QSMag"),
        .package(path: "../SolarSystem"),
        .package(path: "../SwiftUIVisualEffects"),
        .package(name: "SatelliteCatalogPackage", path: "../SatelliteCatalog"),
    ],
    targets: [
        .target(
            name: "SatelliteForecast",
            dependencies: [
                "BTree",
                "StarryNight",
                "AppDelegate",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
            path: "Public/Sources",
            resources: [.process("Resources")],
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
                "BTreeCustomDump",
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
                .product(name: "SatelliteKit", package: "SatelliteKit"),
                .product(name: "StarryNight", package: "StarryNight"),
                .product(name: "QSMag", package: "QSMag"),
                .product(name: "SolarSystem", package: "SolarSystem"),
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage"),
                .product(name: "SatelliteCatalogImpl_SQLite", package: "SatelliteCatalogPackage"),
                .product(name: "AppDelegate", package: "AppDelegate"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
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
                .product(name: "AppDelegate", package: "AppDelegate"),
                .product(name: "SatelliteCatalog", package: "SatelliteCatalogPackage"),
            ],
            path: "ImplWiring/Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ],
)
