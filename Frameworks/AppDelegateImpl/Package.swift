// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "AppDelegateImplPackage",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "AppDelegateImpl",
            targets: ["AppDelegateImpl"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftRex/SwiftRex", from: "0.8.12"),
        .package(url: "https://github.com/SwiftRex/CombineRextensions", branch: "master"),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "12.0.0")
        ),
        .package(url: "https://github.com/nh7a/Geohash.git", branch: "main"),
        .package(path: "../AppDelegate"),
        .package(path: "../SatelliteKit"),
        .package(path: "../SatelliteForecast")
    ],
    targets: [
        .target(
            name: "AppDelegateImpl",
            dependencies: [
                "AppDelegate",
                .product(name: "CombineRex", package: "SwiftRex"),
                "CombineRextensions",
                "Geohash",
                .product(name: "SatelliteKit", package: "SatelliteKit"),
                .product(name: "SatelliteForecast", package: "SatelliteForecast"),
                .product(name: "SatelliteForecastImpl", package: "SatelliteForecast"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
