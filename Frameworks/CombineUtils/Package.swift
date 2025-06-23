// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "CombineUtils",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CombineUtils",
            targets: ["CombineUtils"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "CombineUtils",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "CombineUtilsTests",
            dependencies: ["CombineUtils"],
            path: "Tests"
        )
    ]
)
