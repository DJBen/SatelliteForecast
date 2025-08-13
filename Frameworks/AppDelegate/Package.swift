// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "AppDelegatePackage",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "AppDelegate",
            targets: ["AppDelegate"])
    ],
    dependencies: [
        .package(url: "https://github.com/DJBen/SatelliteKit.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "AppDelegate",
            dependencies: [
                .product(name: "SatelliteKit", package: "SatelliteKit")
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
